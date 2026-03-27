# Hammerspoon Config

Hammerspoon scripts for macOS automation:
- **ncspot media keys** — routes headphone and keyboard media buttons to ncspot instead of Apple Music
- **Focus To-Do auto-pause** — pauses Focus To-Do timer on screen lock/sleep
- **Focus To-Do auto-focus** — brings Focus To-Do to the front on screen unlock

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
2. Symlink the config from this repo:

```bash
ln -sf /Users/wmasarczyk/Documents/MyProjects/hammerspoon/init.lua ~/.hammerspoon/init.lua
```

3. Click **Reload Config** from the Hammerspoon menu bar icon

## Caveats

- **Headphone next/previous buttons** (if supported by your headphones) will not work — by the time Apple Music launches, the original button info is lost. Only play/pause is handled for headphones.
- The script assumes ncspot is already running. If ncspot is not running, the `nc` command will silently fail.
- If Hammerspoon is not running, Apple Music will open as usual.
