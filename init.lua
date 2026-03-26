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

-- Handle keyboard media keys
local tap = hs.eventtap.new({ hs.eventtap.event.types.systemDefined }, function(e)
	local s = e:systemKey()
	local cmd = KEY_COMMAND_MAP[s.key]
	if not cmd or not s.down then
		return false
	end

	ncspot_command(cmd)
	return true
end)
tap:start()

-- Handle headphone button (which triggers Apple Music instead of going through eventtap)
local function killAppleMusic()
	local music = hs.application.get("Music")
	if music then
		music:kill()
	end
end

local appWatcher = hs.application.watcher.new(function(name, event, app)
	if name == "Music" and event == hs.application.watcher.launched then
		killAppleMusic()
		ncspot_command("playpause")
	end
end)
appWatcher:start()



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
        for _, child in ipairs(children) do
            findPause(child)
        end
    end

    findPause(ui)
    return pauseGroup
end

-- Poll every 5 seconds to keep the cache fresh
local cacheTimer = hs.timer.new(5, function()
    cachedPauseGroup = findPauseGroup()
    if cachedPauseGroup then
        print("cache: pause group found and cached")
    end
end)
cacheTimer:start()

local function pauseFocusToDo()
    -- Try cached first, fall back to live search
    local pauseGroup = cachedPauseGroup or findPauseGroup()
    if pauseGroup then
        print("pauseFocusToDo: clicking pause")
        pauseGroup:performAction("AXPress")
    else
        print("pauseFocusToDo: pause group NOT found")
    end
end

local sleepWatcher = hs.caffeinate.watcher.new(function(event)
    print("caffeinate event: " .. event)
    local triggerEvents = {
        [hs.caffeinate.watcher.systemWillSleep] = true,
        [hs.caffeinate.watcher.systemWillPowerOff] = true,
        [hs.caffeinate.watcher.screensDidLock] = true,
    }
    if triggerEvents[event] then
        pauseFocusToDo()
    end
end)

sleepWatcher:start()

hs.hotkey.bind({"cmd", "shift"}, "P", pauseFocusToDo)
