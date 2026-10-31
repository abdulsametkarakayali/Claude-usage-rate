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

## Build

```bash
swift build -c release
```

Binary at `.build/release/ClaudeTokens`.

## Run

```bash
.build/release/ClaudeTokens
```

Appears in the top-right menubar; no Dock icon.

## Install as login item

```bash
mkdir -p ~/Applications/ClaudeTokens
cp .build/release/ClaudeTokens ~/Applications/ClaudeTokens/
cp com.claudetokens.widget.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.claudetokens.widget.plist
```

## Uninstall

```bash
launchctl unload -w ~/Library/LaunchAgents/com.claudetokens.widget.plist
rm ~/Library/LaunchAgents/com.claudetokens.widget.plist
rm -rf ~/Applications/ClaudeTokens
```

## How the window works

The 5-hour window starts at the timestamp of the earliest message found in the last 5 hours across all Claude Code projects. Reset = window start + 5h.

## License

MIT
