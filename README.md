# ncspot macOS Media Key Integration

Makes macOS headphone and keyboard media buttons (play/pause, next, previous) control **ncspot** instead of Apple Music.

## The Problem

macOS routes media key events through two separate channels:
- **Keyboard media keys** go through the system event tap
- **Headphone buttons** go directly to the Now Playing system, which defaults to Apple Music

Since ncspot is a terminal app, it doesn't register with macOS's Now Playing system, so neither channel works out of the box.

## Solution

Use **Hammerspoon** to intercept both channels:
1. An `eventtap` catches keyboard media keys and forwards them to ncspot via its Unix socket
2. An `application.watcher` detects when Apple Music launches (triggered by headphone buttons), kills it, and sends a `playpause` command to ncspot directly

## Setup

### Prerequisites
- [Hammerspoon](https://www.hammerspoon.org/) installed
- ncspot running (the socket at `/tmp/ncspot-<uid>/ncspot.sock` must exist)

### Steps

1. Open Hammerspoon and go to **System Settings → Privacy & Security → Accessibility** and enable Hammerspoon
2. Place the following script in `~/.hammerspoon/init.lua`:

```lua
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

-- Handle headphone button (bypasses eventtap, triggers Apple Music instead)
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
```

3. Click **Reload Config** from the Hammerspoon menu bar icon

## Caveats

- **Headphone next/previous buttons** (if supported by your headphones) will not work — by the time Apple Music launches, the original button info is lost. Only play/pause is handled for headphones.
- The script assumes ncspot is already running. If ncspot is not running, the `nc` command will silently fail.
- If Hammerspoon is not running, Apple Music will open as usual.
