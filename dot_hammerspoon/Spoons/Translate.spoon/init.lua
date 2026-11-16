--- === Translate ===
---
--- Translate the current selection between Japanese and English using
--- DeepSeek V4.1 Flash on OpenCode Zen (default) or OpenCode Go.
--- Pick the gateway with `spoon.Translate.provider = "zen"` or `"go"`.
---
--- The translation is shown in a popup and copied to the clipboard.
---
--- Download: https://github.com/anhnt/spoon-translate

local obj = {}
obj.__index = obj

obj.name = "Translate"
obj.version = "2.1"
obj.author = "anh.nt <anh.nt@raksul.com>"
obj.homepage = "https://github.com/anhnt/spoon-translate"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Translate.provider
--- Variable
--- Which OpenCode gateway to use: "zen" (pay-as-you-go, billed from the
--- workspace balance) or "go" (needs an active OpenCode Go subscription).
obj.provider = "zen"

--- Translate.model
--- Variable
--- Model ID to request. When nil, the provider's default model is used.
obj.model = nil

--- Translate.baseUrl
--- Variable
--- Override the provider's base URL. When nil, the provider's default is used.
obj.baseUrl = nil

--- Translate.apiKey
--- Variable
--- OpenCode API key. When nil, the key is read from the macOS Keychain: first
--- the provider's own item (`opencode-zen` or `opencode-go`), then the other one,
--- since a workspace key works on both gateways.
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

local CURL = "/usr/bin/curl"
local SESSION_ID = hs.host.uuid()

-- thinkingToggle: whether the model accepts `thinking = { type = "disabled" }`
-- (from the `capabilities.reasoning.toggle` field of each gateway's /v1/models).
local PROVIDERS = {
  zen = {
    label = "OpenCode Zen",
    baseUrl = "https://opencode.ai/inference/v1",
    model = "deepseek-v4.1-flash",
    keychain = { "opencode-zen", "opencode-go" },
    thinkingToggle = true,
  },
  go = {
    label = "OpenCode Go",
    baseUrl = "https://opencode.ai/inference/go/v1",
    model = "deepseek-v4.1-flash",
    keychain = { "opencode-go", "opencode-zen" },
    thinkingToggle = false,
  },
}

local function currentProvider()
  return PROVIDERS[obj.provider]
end

local function currentModel()
  local provider = currentProvider()
  return obj.model or (provider and provider.model) or "?"
end

local LANGUAGES = {
  ja2en = { from = "Japanese", to = "English", label = "JA → EN" },
  en2ja = { from = "English", to = "Japanese", label = "EN → JA" },
  auto2vi = { from = nil, to = "Vietnamese (Tiếng Việt)", label = "Auto → VI" },
}

local task = nil
local chooserModal = nil
local chooserAlert = nil
local chooserTimer = nil
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
]], escapeHtml(title), escapeHtml(source), escapeHtml(translation), escapeHtml(currentModel() .. " via " .. currentProvider().label), escapeHtml(obj.thinking), escapeHtml(elapsedText))

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

local function getApiKey(provider)
  if obj.apiKey and obj.apiKey ~= "" then
    return obj.apiKey
  end
  for _, service in ipairs(provider.keychain) do
    local output, ok = hs.execute("/usr/bin/security find-generic-password -s " .. service .. " -w 2>/dev/null")
    local key = ok and trim(output or "") or ""
    if key ~= "" then return key end
  end
  return nil
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

  local provider = currentProvider()
  if not provider then
    fail("unknown provider: " .. tostring(obj.provider) .. " (use \"zen\" or \"go\")")
    return
  end
  local model = currentModel()

  local apiKey = getApiKey(provider)
  if not apiKey then
    fail("no API key; run: security add-generic-password -s " .. provider.keychain[1] .. " -a $USER -w")
    return
  end

  closePopup()
  progress = hs.alert.show(progressLabel, 3600)

  local request = {
    model = model,
    messages = {
      { role = "system", content = systemPrompt },
      { role = "user", content = text },
    },
  }
  if obj.thinking == "off" then
    -- Models without a reasoning toggle reject the `thinking` field; leave it out.
    if provider.thinkingToggle then
      request.thinking = { type = "disabled" }
    end
  else
    if provider.thinkingToggle then
      request.thinking = { type = "enabled" }
    end
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
    (obj.baseUrl or provider.baseUrl) .. "/chat/completions",
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
      fail("unreadable response from " .. provider.label)
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
      fail("empty response from " .. model)
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
---  * direction - "ja2en", "en2ja" or "auto2vi"
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
---  * direction - "ja2en", "en2ja" or "auto2vi"
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

  local instruction
  if lang.from then
    instruction = string.format("Translate the user message from %s to %s. ", lang.from, lang.to)
  else
    instruction = string.format(
      "The user message may be written in any language (Japanese, Chinese, English, etc.). "
        .. "Translate it into %s. Your output MUST be written in %s, never in the source language "
        .. "or any other language. ", lang.to, lang.to)
  end
  local systemPrompt = "You are a translation engine. " .. instruction
    .. "Preserve the original formatting, line breaks and any code or markup verbatim. "
    .. "Output ONLY the translation, with no commentary, no explanation and no surrounding quotes."

  complete(lang.label .. " translating…", lang.label, systemPrompt, text)
  return self
end

--- Translate.chooseTimeout
--- Variable
--- Seconds to wait for 1, 2 or 3 after the choose hotkey before cancelling.
obj.chooseTimeout = 5

local function exitChooser()
  if chooserTimer then
    chooserTimer:stop()
    chooserTimer = nil
  end
  if chooserAlert then
    hs.alert.closeSpecific(chooserAlert)
    chooserAlert = nil
  end
  if chooserModal then
    chooserModal:exit()
    chooserModal:delete()
    chooserModal = nil
  end
end

--- Translate:chooseAndTranslate()
--- Method
--- Copy the current selection, then ask for the direction:
--- press 1 for Japanese → English, 2 for English → Japanese,
--- 3 for auto-detect → Vietnamese, Esc to cancel.
---
--- Returns:
---  * The Translate object
function obj:chooseAndTranslate()
  exitChooser()

  if task and task:isRunning() then
    fail("a translation is already running")
    return self
  end

  local text = getSelection()
  if not text or text:match("^%s*$") then
    fail("no text selected")
    return self
  end

  chooserModal = hs.hotkey.modal.new()
  local function pick(direction)
    return function()
      exitChooser()
      self:translateText(direction, text)
    end
  end
  chooserModal:bind({}, "1", pick("ja2en"))
  chooserModal:bind({}, "2", pick("en2ja"))
  chooserModal:bind({}, "pad1", pick("ja2en"))
  chooserModal:bind({}, "pad2", pick("en2ja"))
  chooserModal:bind({}, "3", pick("auto2vi"))
  chooserModal:bind({}, "pad3", pick("auto2vi"))
  chooserModal:bind({}, "escape", exitChooser)
  chooserModal:enter()

  chooserAlert = hs.alert.show("Translate:  1 = JA → EN    2 = EN → JA    3 = Auto → VI    Esc = cancel", obj.chooseTimeout)
  chooserTimer = hs.timer.doAfter(obj.chooseTimeout, exitChooser)
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
---    * auto2vi - translate the selection from any language (auto-detected) to Vietnamese
---    * choose - ask for the direction (1 = JA → EN, 2 = EN → JA, 3 = Auto → VI), then translate the selection
---    * polish - polish the current selection to improve grammar and clarity
---
--- Returns:
---  * The Translate object
function obj:bindHotkeys(mapping)
  hs.spoons.bindHotkeysToSpec({
    ja2en = function() self:translate("ja2en") end,
    en2ja = function() self:translate("en2ja") end,
    auto2vi = function() self:translate("auto2vi") end,
    choose = function() self:chooseAndTranslate() end,
    polish = function() self:polish() end,
  }, mapping)
  return self
end

return obj
