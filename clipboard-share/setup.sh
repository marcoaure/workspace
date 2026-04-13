#!/bin/bash
# setup.sh — Setup clipboard-share no macOS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  === Clipboard Share — Setup macOS ==="
echo ""

# 1. Verify Node.js
if ! command -v node &>/dev/null; then
    echo "  [X] Node.js não encontrado! Instale via: brew install node"
    exit 1
fi
echo "  [OK] Node.js $(node --version)"

# 2. npm install
cd "$SCRIPT_DIR"
if [[ ! -d "node_modules" ]]; then
    echo "  Instalando dependências..."
    npm install --production
fi
echo "  [OK] Dependências instaladas"

# 3. Make scripts executable
chmod +x "$SCRIPT_DIR/send.sh"
chmod +x "$SCRIPT_DIR/lib/clipboard-mac.sh"
echo "  [OK] Scripts executáveis"

# 4. Create temp dir
TEMP_DIR="$HOME/clipboard-share-temp"
mkdir -p "$TEMP_DIR"
echo "  [OK] Temp dir: $TEMP_DIR"

# 5. Configure remote_host (prompt if not set)
CONFIG="$SCRIPT_DIR/config.json"
CURRENT_REMOTE=$(jq -r '.remote_host' "$CONFIG")
if [[ "$CURRENT_REMOTE" == "CHANGE_ME.local" ]]; then
    echo ""
    echo "  Qual o hostname do WINDOWS? (ex: DESKTOP-ABC123)"
    echo "  Dica: no Windows, rode 'hostname' no terminal"
    read -rp "  > " WIN_HOSTNAME
    if [[ -n "$WIN_HOSTNAME" ]]; then
        if [[ "$WIN_HOSTNAME" != *.local ]]; then
            WIN_HOSTNAME="${WIN_HOSTNAME}.local"
        fi
        jq --arg h "$WIN_HOSTNAME" '.remote_host = $h' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
        echo "  [OK] remote_host = $WIN_HOSTNAME"
    fi
fi

# 6. LaunchAgent (autostart)
PLIST_NAME="com.workspace.clipboard-share"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which node)</string>
        <string>${SCRIPT_DIR}/server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/clipboard-share.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clipboard-share.log</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "  [OK] LaunchAgent registrado (autostart no login)"

# 7. Hammerspoon hotkey
HS_INIT="$HOME/.hammerspoon/init.lua"
HS_MARKER="-- === clipboard-share ==="

if [[ -f "$HS_INIT" ]]; then
    if grep -q "$HS_MARKER" "$HS_INIT" 2>/dev/null; then
        sed -i '' "/$HS_MARKER/,/$HS_MARKER/d" "$HS_INIT"
    fi
fi

cat >> "$HS_INIT" << EOF

$HS_MARKER
-- Cmd+Shift+C = send clipboard to other PC
hs.hotkey.bind({"cmd", "shift"}, "C", function()
    hs.task.new("/bin/bash", nil, {"$SCRIPT_DIR/send.sh"}):start()
end)
$HS_MARKER
EOF

echo "  [OK] Hotkey registrada: Cmd+Shift+C (envia clipboard)"

# Resumo
echo ""
echo "  Setup completo!"
echo ""
echo "  Server: roda automaticamente no login (porta $(jq -r '.port' "$CONFIG"))"
echo "  Hotkey: Cmd+Shift+C → envia clipboard pro Windows"
echo "  Paste:  Cmd+V normal (clipboard já injetado ao receber)"
echo ""
echo "  Logs:   /tmp/clipboard-share.log"
echo "  Config: $CONFIG"
echo ""
