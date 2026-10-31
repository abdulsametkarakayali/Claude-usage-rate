# Claude Token Widget

macOS menubar widget that shows Claude Code token usage, 5-hour rolling window, and reset countdown. Reads local JSONL files from `~/.claude/projects/`. No API key, no network.

## Features

- Menubar icon + live token count
- Dropdown panel: progress bar, countdown to reset, input/output/cache breakdown, per-model usage
- Configurable token limit (persisted via UserDefaults)
- Auto-refresh every 30 seconds

## Requirements

- macOS 14+
- Swift 5.9+
- Claude Code installed (reads its JSONL logs)

## Build and install

```bash
./Scripts/build_app.sh install
```

Builds `build/ClaudeTokens.app` and copies it to `/Applications/ClaudeTokens.app`. Omit `install` to build only.

## Run

```bash
open /Applications/ClaudeTokens.app
```

Shows in the top-right menubar; no Dock icon.

## Start at login

```bash
./Scripts/install_login_item.sh
```

Installs `~/Library/LaunchAgents/com.claudetokens.widget.plist`.

## Icon

Pre-rendered at `Resources/AppIcon.icns`. To regenerate from `cpu.fill` SF Symbol:

```bash
mkdir -p build/AppIcon.iconset
swift Scripts/make_icon.swift build/AppIcon.iconset
iconutil -c icns -o Resources/AppIcon.icns build/AppIcon.iconset
```

## Uninstall

```bash
launchctl unload -w ~/Library/LaunchAgents/com.claudetokens.widget.plist
rm ~/Library/LaunchAgents/com.claudetokens.widget.plist
rm -rf /Applications/ClaudeTokens.app
```

## How the window works

The 5-hour window starts at the timestamp of the earliest message found in the last 5 hours across all Claude Code projects. Reset = window start + 5h.

## License

MIT
