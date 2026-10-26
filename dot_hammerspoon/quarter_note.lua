-- Open the quarter note in Obsidian on login, wake and unlock,
-- at most once per window per day.

local vault = "Tuan Anh's Lab"
local note = "10 Planning/Quarters/2026-Q3"

-- { name, startHour, endHour } — endHour is exclusive
local windows = {
    { "morning", 0, 12 },
    { "afternoon", 15, 24 },
}

local settingsKey = "quarterNote.lastOpened"

local function encode(s)
    return (s:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function currentWindow()
    local hour = tonumber(os.date("%H"))
    for _, w in ipairs(windows) do
        if hour >= w[2] and hour < w[3] then
            return os.date("%Y-%m-%d") .. "-" .. w[1]
        end
    end
end

local function maybeOpen()
    local key = currentWindow()
    if not key or hs.settings.get(settingsKey) == key then
        return
    end
    hs.settings.set(settingsKey, key)
    hs.urlevent.openURL("obsidian://open?vault=" .. encode(vault) .. "&file=" .. encode(note))
end

quarterNoteWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake
        or event == hs.caffeinate.watcher.screensDidUnlock then
        maybeOpen()
    end
end):start()

-- Hammerspoon starts at login, so this covers power-on and restart
maybeOpen()
