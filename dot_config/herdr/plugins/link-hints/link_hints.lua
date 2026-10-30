-- link-hints: flash.nvim-style URL labels for the focused herdr pane.
--   luajit link_hints.lua open    -- plugin action: pick target pane, open picker overlay
--   luajit link_hints.lua picker  -- overlay entrypoint: draw labels, read keys, open URL
-- Required without arguments it returns the module table (for headless tests).

local M = {}

M.defaults = {
  labels = "asdfghjklqwertyuiopzxcvbnm",
  open_cmd = nil, -- nil = `open` on macOS, `xdg-open` elsewhere
  auto_open_single = false,
  no_links_message = "No links were found",
}

local HERDR = os.getenv("HERDR_BIN_PATH") or "herdr"
local PLUGIN_ID = os.getenv("HERDR_PLUGIN_ID") or "local.link-hints"

local function quote(s)
  return "'" .. (s:gsub("'", "'\\''")) .. "'"
end

local function sh(cmd)
  local p = io.popen(cmd)
  if not p then return "" end
  local out = p:read("*a") or ""
  p:close()
  return out
end

function M.load_config()
  local cfg = {}
  for k, v in pairs(M.defaults) do cfg[k] = v end
  -- Plugin panes don't receive HERDR_PLUGIN_CONFIG_DIR, so ask herdr.
  local dir = os.getenv("HERDR_PLUGIN_CONFIG_DIR")
    or sh(HERDR .. " plugin config-dir " .. quote(PLUGIN_ID) .. " 2>/dev/null"):match("[^\n]+")
  if dir then
    local ok, user = pcall(dofile, dir .. "/config.lua")
    if ok and type(user) == "table" then
      for k, v in pairs(user) do cfg[k] = v end
    end
  end
  if not cfg.open_cmd then
    cfg.open_cmd = sh("uname -s"):match("Darwin") and "open" or "xdg-open"
  end
  return cfg
end

-- Display width ------------------------------------------------------------

local function is_wide(cp)
  return (cp >= 0x1100 and cp <= 0x115F)
    or (cp >= 0x2E80 and cp <= 0xA4CF)
    or (cp >= 0xAC00 and cp <= 0xD7A3)
    or (cp >= 0xF900 and cp <= 0xFAFF)
    or (cp >= 0xFE30 and cp <= 0xFE4F)
    or (cp >= 0xFF00 and cp <= 0xFF60)
    or (cp >= 0xFFE0 and cp <= 0xFFE6)
    or (cp >= 0x1F300 and cp <= 0x1F64F)
    or (cp >= 0x1F900 and cp <= 0x1F9FF)
    or (cp >= 0x20000 and cp <= 0x3FFFD)
end

-- Iterates UTF-8 chars yielding (char, cell width).
local function chars(s)
  local i, n = 1, #s
  return function()
    if i > n then return nil end
    local b = s:byte(i)
    local len = b < 0x80 and 1 or b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    local ch = s:sub(i, i + len - 1)
    local cp = b
    if len == 2 then
      cp = (b % 0x20) * 0x40 + (s:byte(i + 1) or 0) % 0x40
    elseif len == 3 then
      cp = (b % 0x10) * 0x1000 + ((s:byte(i + 1) or 0) % 0x40) * 0x40 + (s:byte(i + 2) or 0) % 0x40
    elseif len == 4 then
      cp = (b % 0x08) * 0x40000 + ((s:byte(i + 1) or 0) % 0x40) * 0x1000
        + ((s:byte(i + 2) or 0) % 0x40) * 0x40 + (s:byte(i + 3) or 0) % 0x40
    end
    i = i + len
    return ch, is_wide(cp) and 2 or 1
  end
end

function M.width(s)
  local w = 0
  for _, cw in chars(s) do w = w + cw end
  return w
end

function M.truncate(s, max)
  local out, w = {}, 0
  for ch, cw in chars(s) do
    if w + cw > max then break end
    out[#out + 1] = ch
    w = w + cw
  end
  return table.concat(out)
end

-- URL scanning -------------------------------------------------------------

local STARTS = { "https?://", "file://", "www%." }
local URL_BODY = "^[%w%-%._~:/%?#%[%]@!%$&'%(%)%*%+,;=%%]+"

local function trim_url(url)
  while true do
    local last = url:sub(-1)
    if last:match("[%.,;:!%?'\"]") then
      url = url:sub(1, -2)
    elseif last == ")" or last == "]" then
      local open = last == ")" and "%(" or "%["
      local close = last == ")" and "%)" or "%]"
      local _, opens = url:gsub(open, "")
      local _, closes = url:gsub(close, "")
      if closes > opens then url = url:sub(1, -2) else break end
    else
      break
    end
  end
  return url
end

-- Returns { {col = display cell (1-based), url = string}, ... } for one line.
function M.scan_line(line)
  local found, pos = {}, 1
  while true do
    local best
    for _, p in ipairs(STARTS) do
      local s = line:find(p, pos)
      if s and (not best or s < best) then best = s end
    end
    if not best then break end
    local raw = line:match(URL_BODY, best) or ""
    local url = trim_url(raw)
    local prev = best > 1 and line:sub(best - 1, best - 1) or ""
    local is_www = url:sub(1, 4) == "www."
    local has_body = url:match("^%a+://.") or (is_www and #url > 4)
    if has_body and not (is_www and prev:match("[%w/%.]")) then
      found[#found + 1] = { col = M.width(line:sub(1, best - 1)) + 1, url = url }
    end
    pos = best + math.max(#raw, 1)
  end
  return found
end

-- Hints ordered bottom-up (most recent output gets the home-row keys first).
function M.scan(lines)
  local hints = {}
  for row = #lines, 1, -1 do
    for _, m in ipairs(M.scan_line(lines[row])) do
      hints[#hints + 1] = { row = row, col = m.col, url = m.url }
    end
  end
  return hints
end

function M.assign_labels(n, alphabet)
  local keys = {}
  for c in alphabet:gmatch(".") do keys[#keys + 1] = c end
  local labels = {}
  if n <= #keys then
    for i = 1, n do labels[i] = keys[i] end
  else
    for _, a in ipairs(keys) do
      for _, b in ipairs(keys) do
        if #labels == n then return labels end
        labels[#labels + 1] = a .. b
      end
    end
  end
  return labels
end

-- herdr helpers ------------------------------------------------------------

function M.focused_pane()
  local id = sh(HERDR .. " pane current 2>/dev/null"):match('"pane_id":"([^"]+)"')
  return id or os.getenv("HERDR_PANE_ID")
end

function M.read_pane(pane_id)
  local text = sh(HERDR .. " pane read " .. quote(pane_id) .. " --source visible --format text 2>/dev/null")
  local lines = {}
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = (line:gsub("\r$", ""))
  end
  if lines[#lines] == "" then lines[#lines] = nil end
  return lines
end

function M.notify(body)
  os.execute(HERDR .. " notification show 'Link hints' --body " .. quote(body)
    .. " --sound none >/dev/null 2>&1")
end

function M.open_url(cfg, url)
  if url:sub(1, 4) == "www." then url = "https://" .. url end
  os.execute(cfg.open_cmd .. " " .. quote(url) .. " >/dev/null 2>&1")
end

-- Picker UI ----------------------------------------------------------------

local ESC = "\27"

local function term_size()
  local rows, cols = sh("stty size </dev/tty 2>/dev/null"):match("(%d+)%s+(%d+)")
  return tonumber(rows) or 24, tonumber(cols) or 80
end

local function render(out, lines, hints, typed, cols)
  out[#out + 1] = ESC .. "[?25l" .. ESC .. "[2J"
  for row, line in ipairs(lines) do
    out[#out + 1] = ESC .. "[" .. row .. ";1H" .. ESC .. "[2m" .. M.truncate(line, cols) .. ESC .. "[0m"
  end
  for _, h in ipairs(hints) do
    if h.label:sub(1, #typed) == typed and h.col <= cols then
      local avail = cols - h.col + 1
      out[#out + 1] = ESC .. "[" .. h.row .. ";" .. h.col .. "H"
        .. ESC .. "[0;4;36m" .. M.truncate(h.url, avail) .. ESC .. "[0m"
      local label = M.truncate(h.label:sub(#typed + 1), avail)
      out[#out + 1] = ESC .. "[" .. h.row .. ";" .. h.col .. "H"
        .. ESC .. "[1;30;45m" .. label .. ESC .. "[0m"
    end
  end
end

local function draw(lines, hints, typed, cols)
  local out = {}
  render(out, lines, hints, typed, cols)
  io.write(table.concat(out))
  io.flush()
end

local function pick(cfg, lines, hints, cols)
  local typed = ""
  while true do
    draw(lines, hints, typed, cols)
    local key = io.read(1)
    if not key or key == ESC or key == "\3" then return nil end
    typed = typed .. key
    local matches = 0
    for _, h in ipairs(hints) do
      if h.label == typed then return h end
      if h.label:sub(1, #typed) == typed then matches = matches + 1 end
    end
    if matches == 0 then return nil end
  end
end

function M.picker(cfg)
  local target = os.getenv("LINK_HINTS_TARGET")
  if not target then return end
  local rows, cols = term_size()
  local lines = M.read_pane(target)
  while #lines > rows do table.remove(lines, 1) end
  local hints = M.scan(lines)
  -- Bail out before drawing anything so the overlay never flashes.
  if #hints == 0 then return M.notify(cfg.no_links_message) end
  local labels = M.assign_labels(#hints, cfg.labels)
  for i, h in ipairs(hints) do h.label = labels[i] end

  local saved = sh("stty -g </dev/tty 2>/dev/null"):gsub("%s+$", "")
  os.execute("stty raw -echo </dev/tty 2>/dev/null")
  local ok, chosen = pcall(pick, cfg, lines, hints, cols)
  os.execute("stty " .. (saved ~= "" and saved or "sane") .. " </dev/tty 2>/dev/null")
  io.write(ESC .. "[0m" .. ESC .. "[2J" .. ESC .. "[?25h")
  io.flush()
  if not ok then error(chosen) end
  if chosen then M.open_url(cfg, chosen.url) end
end

function M.open(cfg)
  local target = M.focused_pane()
  if not target then return end
  local hints = M.scan(M.read_pane(target))
  -- No overlay is opened when nothing matches, so the screen stays untouched.
  if #hints == 0 then return M.notify(cfg.no_links_message) end
  if #hints == 1 and cfg.auto_open_single then
    return M.open_url(cfg, hints[1].url)
  end
  os.execute(HERDR .. " plugin pane open --plugin " .. quote(PLUGIN_ID)
    .. " --entrypoint picker --placement overlay --env " .. quote("LINK_HINTS_TARGET=" .. target) .. " --focus >/dev/null")
end

local mode = arg and arg[1]
if not mode then return M end
if mode == "open" then
  M.open(M.load_config())
elseif mode == "picker" then
  M.picker(M.load_config())
else
  io.stderr:write("usage: link_hints.lua open|picker\n")
  os.exit(2)
end
