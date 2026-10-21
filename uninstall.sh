#!/bin/bash
# claude-speed uninstaller: removes the LaunchAgent, ClaudeSpeed.app and, if it points into
# this directory, the statusline wiring in ~/.claude/settings.json.
# The repo directory itself is left in place — delete it manually if desired.
set -euo pipefail
cd "$(dirname "$0")"
DIR="$(pwd)"
LABEL="com.claude-speed.menubar"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
echo "LaunchAgent removed."
APP="${CLAUDE_SPEED_APP_DIR:-/Applications}/ClaudeSpeed.app"
if [[ -d "$APP" ]]; then
  rm -rf "$APP"
  echo "$APP removed."
fi

python3 - "$DIR" <<'PY'
import json, os, sys
p = os.path.expanduser("~/.claude/settings.json")
if os.path.exists(p):
    with open(p) as f:
        d = json.load(f)
    cmd = (d.get("statusLine") or {}).get("command", "")
    if cmd.startswith(sys.argv[1]):
        del d["statusLine"]
        with open(p, "w") as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
        print("statusLine wiring removed from settings.json.")
PY
echo "Done."
