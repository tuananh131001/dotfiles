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
    choose = { { "alt", "shift" }, "d" },
    polish = { { "alt", "shift" }, "g" },
})
