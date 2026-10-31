#!/bin/bash
# Install LaunchAgent so the app starts at every login.
# Prerequisite: /Applications/ClaudeTokens.app exists (run build_app.sh install first).
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/com.claudetokens.widget.plist"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.claudetokens.widget</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ClaudeTokens.app/Contents/MacOS/ClaudeTokens</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key><false/>
        <key>Crashed</key><true/>
    </dict>
    <key>ProcessType</key><string>Interactive</string>
    <key>StandardOutPath</key><string>/tmp/claudetokens.log</string>
    <key>StandardErrorPath</key><string>/tmp/claudetokens.err</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"
echo "LaunchAgent installed and loaded: $PLIST"
