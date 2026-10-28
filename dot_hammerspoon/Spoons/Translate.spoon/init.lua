--- === Translate ===
---
--- Translate the current selection between Japanese and English using
--- DeepSeek V4 Flash on the OpenCode Go gateway.
---
--- The translation is shown in a popup and copied to the clipboard.
---
--- Download: https://github.com/anhnt/spoon-translate

local obj = {}
obj.__index = obj

obj.name = "Translate"
obj.version = "2.0"
obj.author = "anh.nt <anh.nt@raksul.com>"
obj.homepage = "https://github.com/anhnt/spoon-translate"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Translate.baseUrl
--- Variable
--- Base URL of the OpenCode Go gateway.
obj.baseUrl = "https://opencode.ai/inference/go/v1"

--- Translate.apiKey
--- Variable
--- OpenCode Go API key. When nil, the key is read from the macOS Keychain item
--- with service name `opencode-go`.
obj.apiKey = nil

--- Translate.thinking
--- Variable
--- Reasoning effort sent to the model: "off", "low", "high" or "max".
obj.thinking = "off"

--- Translate.popupWidth
--- Variable
--- Width of the translation popup, in points.
obj.popupWidth = 380

--- Translate.popupHeight
--- Variable
--- Height of the translation popup, in points.
obj.popupHeight = 260

--- Translate.popupMargin
--- Variable
--- Gap between the popup and the top-right corner of the screen, in points.
obj.popupMargin = 16

--- Translate.timeout
--- Variable
--- Seconds to wait for a translation before giving up.
obj.timeout = 60

--- Translate.copyDelay
--- Variable
--- Seconds to wait for the frontmost app to answer Cmd+C.
obj.copyDelay = 0.12

--- Translate.maxSelectionLength
--- Variable
--- Refuse to translate a selection longer than this many characters.
obj.maxSelectionLength = 20000

local MODEL = "deepseek-v4.1-flash"
local CURL = "/usr/bin/curl"
local KEYCHAIN_SERVICE = "opencode-go"
local SESSION_ID = hs.host.uuid()

local LANGUAGES = {
  ja2en = { from = "Japanese", to = "English", label = "JA → EN" },
  en2ja = { from = "English", to = "Japanese", label = "EN → JA" },
}

local task = nil
local webview = nil
local closeHotkey = nil
local progress = nil

local function escapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function closePopup()
  if closeHotkey then
    closeHotkey:delete()
    closeHotkey = nil
  end
  if webview then
    webview:delete()
    webview = nil
  end
end

local function showPopup(title, source, translation, elapsedText)
  closePopup()

  local screen = hs.screen.mainScreen():frame()
  local width = math.min(obj.popupWidth, screen.w - 2 * obj.popupMargin)
  local height = math.min(obj.popupHeight, screen.h - 2 * obj.popupMargin)
  local frame = {
    x = screen.x + screen.w - width - obj.popupMargin,
    y = screen.y + obj.popupMargin,
    w = width,
    h = height,
  }

  local html = string.format([[
<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
  :root { color-scheme: light dark; }
  body {
    margin: 0; padding: 12px 14px;
    font: 13px/1.5 -apple-system, "Hiragino Sans", sans-serif;
    background: #1e1e21; color: #f2f2f4;
  }
  h1 { margin: 0 0 8px; font-size: 10px; letter-spacing: .08em;
       text-transform: uppercase; color: #8d8d96; font-weight: 600; }
  .source { color: #9a9aa4; font-size: 11px; white-space: pre-wrap;
            word-wrap: break-word; max-height: 4.5em; overflow: hidden;
            padding-bottom: 8px; border-bottom: 1px solid #38383d;
            margin-bottom: 10px; }
  .result { white-space: pre-wrap; word-wrap: break-word; }
  footer { margin-top: 14px; font-size: 10px; color: #6f6f78; }
</style></head>
<body>
  <h1>%s</h1>
  <div class="source">%s</div>
  <div class="result">%s</div>
  <footer>%s · %s thinking · Copied to clipboard · %s · press Esc to close</footer>
</body></html>
]], escapeHtml(title), escapeHtml(source), escapeHtml(translation), escapeHtml(MODEL), escapeHtml(obj.thinking), escapeHtml(elapsedText))

  webview = hs.webview.new(frame)
    :windowStyle({ "titled", "closable", "utility", "HUD" })
    :windowTitle("Translate")
    :shadow(true)
    :level(hs.drawing.windowLevels.modalPanel)
    :allowTextEntry(true)
    :html(html)
    :show()

  closeHotkey = hs.hotkey.bind({}, "escape", closePopup)
end

local function fail(message)
  if progress then
    hs.alert.closeSpecific(progress)
    progress = nil
  end
  hs.alert.show("Translate: " .. message, 3)
end

local function getSelection()
  local previousCount = hs.pasteboard.changeCount()
  hs.eventtap.keyStroke({ "cmd" }, "c", 0)

  local deadline = hs.timer.secondsSinceEpoch() + obj.copyDelay
  repeat
    if hs.pasteboard.changeCount() ~= previousCount then
      return hs.pasteboard.getContents()
    end
  until hs.timer.secondsSinceEpoch() > deadline

  return nil
end

local function getApiKey()
  if obj.apiKey and obj.apiKey ~= "" then
    return obj.apiKey
  end
  local output, ok = hs.execute("/usr/bin/security find-generic-password -s " .. KEYCHAIN_SERVICE .. " -w 2>/dev/null")
  if not ok then return nil end
  local key = trim(output or "")
  if key == "" then return nil end
  return key
end

local function curlQuote(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

local function describeError(status, body)
  local ok, decoded = pcall(hs.json.decode, body)
  local message = ok and type(decoded) == "table" and type(decoded.error) == "table" and decoded.error.message
  if type(message) ~= "string" or message == "" then
    message = trim(body)
  end
  if message == "" then
    return "HTTP " .. status
  end
  return "HTTP " .. status .. ": " .. message
end

local function complete(progressLabel, title, systemPrompt, text)
  if task and task:isRunning() then
    fail("a translation is already running")
    return
  end
  if #text > obj.maxSelectionLength then
    fail("text too long (" .. #text .. " characters)")
    return
  end

  local apiKey = getApiKey()
  if not apiKey then
    fail("no API key; run: security add-generic-password -s " .. KEYCHAIN_SERVICE .. " -a $USER -w")
    return
  end

  closePopup()
  progress = hs.alert.show(progressLabel, 3600)

  local request = {
    model = MODEL,
    messages = {
      { role = "system", content = systemPrompt },
      { role = "user", content = text },
    },
  }
  if obj.thinking == "off" then
    request.thinking = { type = "disabled" }
  else
    request.thinking = { type = "enabled" }
    request.reasoning_effort = obj.thinking
  end
  local body = hs.json.encode(request)

  local config = "header = " .. curlQuote("Authorization: Bearer " .. apiKey) .. "\n"
    .. "data-binary = " .. curlQuote(body) .. "\n"

  local args = {
    "-sS",
    "--max-time", tostring(obj.timeout),
    "-K", "-",
    "-w", "\n%{http_code}",
    "-H", "Content-Type: application/json",
    "-H", "x-opencode-session: " .. SESSION_ID,
    "-H", "User-Agent: Translate.spoon/" .. obj.version,
    obj.baseUrl .. "/chat/completions",
  }

  local startTime = hs.timer.secondsSinceEpoch()

  task = hs.task.new(CURL, function(exitCode, stdout, stderr)
    if progress then
      hs.alert.closeSpecific(progress)
      progress = nil
    end
    task = nil

    if exitCode == 28 then
      fail("timed out after " .. obj.timeout .. "s")
      return
    end
    if exitCode ~= 0 then
      local detail = trim(stderr or "")
      if detail == "" then detail = "curl exited with code " .. tostring(exitCode) end
      fail(detail)
      return
    end

    local responseBody, status = (stdout or ""):match("^(.*)\n(%d+)$")
    if not status then
      fail("unreadable response from gateway")
      return
    end
    if status ~= "200" then
      fail(describeError(status, responseBody))
      return
    end

    local ok, decoded = pcall(hs.json.decode, responseBody)
    local choice = ok and type(decoded) == "table" and type(decoded.choices) == "table" and decoded.choices[1]
    local content = type(choice) == "table" and type(choice.message) == "table" and choice.message.content
    local result = type(content) == "string" and trim(content) or ""
    if result == "" then
      fail("empty response from " .. MODEL)
      return
    end

    local elapsed = hs.timer.secondsSinceEpoch() - startTime
    hs.pasteboard.setContents(result)
    showPopup(title, text, result, string.format("%.2fs", elapsed))
  end, args)

  task:setInput(config)

  if not task:start() then
    task = nil
    fail("could not run " .. CURL)
  end
end

--- Translate:translate(direction)
--- Method
--- Translate the current selection.
---
--- Parameters:
---  * direction - either "ja2en" or "en2ja"
---
--- Returns:
---  * The Translate object
function obj:translate(direction)
  if not LANGUAGES[direction] then
    fail("unknown direction: " .. tostring(direction))
    return self
  end

  if task and task:isRunning() then
    fail("a translation is already running")
    return self
  end

  local text = getSelection()
  if not text or text:match("^%s*$") then
    fail("no text selected")
    return self
  end

  return self:translateText(direction, text)
end

--- Translate:translateText(direction, text)
--- Method
--- Translate a given string, without touching the current selection.
---
--- Parameters:
---  * direction - either "ja2en" or "en2ja"
---  * text - the string to translate
---
--- Returns:
---  * The Translate object
function obj:translateText(direction, text)
  local lang = LANGUAGES[direction]
  if not lang then
    fail("unknown direction: " .. tostring(direction))
    return self
  end

  if type(text) ~= "string" or text:match("^%s*$") then
    fail("nothing to translate")
    return self
  end

  local systemPrompt = string.format(
    "You are a translation engine. Translate the user message from %s to %s. "
      .. "Preserve the original formatting, line breaks and any code or markup verbatim. "
      .. "Output ONLY the translation, with no commentary, no explanation and no surrounding quotes.",
    lang.from, lang.to)

  complete(lang.label .. " translating…", lang.label, systemPrompt, text)
  return self
end

--- Translate:polish()
--- Method
--- Polish the current selection to improve grammar, clarity, and style.
---
--- Returns:
---  * The Translate object
function obj:polish()
  if task and task:isRunning() then
    fail("a translation is already running")
    return self
  end

  local text = getSelection()
  if not text or text:match("^%s*$") then
    fail("no text selected")
    return self
  end

  return self:polishText(text)
end

--- Translate:polishText(text)
--- Method
--- Polish a given string, without touching the current selection.
---
--- Parameters:
---  * text - the string to polish
---
--- Returns:
---  * The Translate object
function obj:polishText(text)
  if type(text) ~= "string" or text:match("^%s*$") then
    fail("nothing to polish")
    return self
  end

  local systemPrompt =
    "You are a writing assistant. Polish the user message to improve grammar, "
      .. "clarity, and style while preserving the original meaning, tone, and formatting. "
      .. "Preserve the original language. "
      .. "Output ONLY the polished text, with no commentary, no explanation and no surrounding quotes."

  complete("Polishing…", "Polish", systemPrompt, text)
  return self
end

--- Translate:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for this spoon.
---
--- Parameters:
---  * mapping - a table containing hotkey objifier/key details for the following items:
---    * ja2en - translate the selection from Japanese to English
---    * en2ja - translate the selection from English to Japanese
---    * polish - polish the current selection to improve grammar and clarity
---
--- Returns:
---  * The Translate object
function obj:bindHotkeys(mapping)
  hs.spoons.bindHotkeysToSpec({
    ja2en = function() self:translate("ja2en") end,
    en2ja = function() self:translate("en2ja") end,
    polish = function() self:polish() end,
  }, mapping)
  return self
end

return obj
