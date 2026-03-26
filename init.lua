-- NCSpot media key handling
local KEY_COMMAND_MAP = {
    PLAY = "playpause",
    FAST = "next",
    REWIND = "previous",
}

local handle = io.popen("id -u")
local uid = handle:read("*l")
handle:close()
local ncspot_sock_path = string.format("/tmp/ncspot-%s/ncspot.sock", uid)

local function ncspot_command(cmd)
    local sh = string.format([[echo "%s" | /usr/bin/nc -U %s]], cmd, ncspot_sock_path)
    hs.execute(sh, true)
end

local tap = hs.eventtap.new({ hs.eventtap.event.types.systemDefined }, function(e)
    local s = e:systemKey()
    local cmd = KEY_COMMAND_MAP[s.key]
    if not cmd or not s.down then return false end
    ncspot_command(cmd)
    return true
end)
tap:start()

local appWatcher = hs.application.watcher.new(function(name, event, app)
    if name == "Music" and event == hs.application.watcher.launched then
        local music = hs.application.get("Music")
        if music then music:kill() end
        ncspot_command("playpause")
    end
end)
appWatcher:start()

-- Focus To-Do: pause on screen lock/sleep
local axuielement = require("hs.axuielement")
local cachedPauseGroup = nil

local function findPauseGroup()
    local app = hs.application.get("com.macpomodoro")
    if not app then return nil end
    local win = app:mainWindow()
    if not win then return nil end
    local ui = axuielement.windowElement(win)
    local pauseGroup = nil
    local function findPause(element)
        if pauseGroup then return end
        local role = element:attributeValue("AXRole")
        local value = element:attributeValue("AXValue") or ""
        if role == "AXStaticText" and value == "Pause" then
            pauseGroup = element:attributeValue("AXParent")
            return
        end
        local children = element:attributeValue("AXChildren") or {}
        for _, child in ipairs(children) do findPause(child) end
    end
    findPause(ui)
    return pauseGroup
end

local cacheTimer = hs.timer.new(30, function()
    cachedPauseGroup = findPauseGroup()
end)
cacheTimer:start()

local function pauseFocusToDo()
    local pauseGroup = cachedPauseGroup or findPauseGroup()
    if pauseGroup then
        pauseGroup:performAction("AXPress")
    end
end

local sleepWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.screensDidLock
    or event == hs.caffeinate.watcher.systemWillSleep
    or event == hs.caffeinate.watcher.systemWillPowerOff then
        cacheTimer:stop()
        pauseFocusToDo()
    elseif event == hs.caffeinate.watcher.screensDidUnlock
        or event == hs.caffeinate.watcher.systemDidWake then
        -- Restart everything that may have stopped
        cacheTimer:start()
        tap:start()
        appWatcher:start()
        print("watchers restarted after unlock/wake")
    end
end)
sleepWatcher:start()

hs.hotkey.bind({"cmd", "shift"}, "P", pauseFocusToDo)
