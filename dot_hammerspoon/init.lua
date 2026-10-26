require("hs.ipc")

local persistentApps = {
    -- "com.eyebreak.app",
}

persistentAppTimer = hs.timer.doEvery(10, function()
    for _, bundleID in ipairs(persistentApps) do
        if not hs.application.get(bundleID) then
            hs.application.launchOrFocusByBundleID(bundleID)
        end
    end
end)

require("quarter_note")

hs.alert.show("Hammerspoon loaded")

hs.loadSpoon("Translate")
spoon.Translate:bindHotkeys({
    ja2en  = { { "alt", "shift" }, "d" },
    en2ja  = { { "alt", "shift" }, "e" },
    polish = { { "alt", "shift" }, "g" },
})
