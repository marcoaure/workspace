#!/bin/bash
# setup.sh — Instalador completo do Switch Station no macOS
# Rode uma vez: ./setup.sh
#
# O que faz:
#   1. Instala dependências (m1ddc, jq, BetterDisplay) via Homebrew
#   2. Torna scripts executáveis
#   3. Registra aliases 'windows' e 'mac-fix' no shell
#   4. Cria Automator Quick Actions para hotkeys globais
#   5. Instrui como atribuir Ctrl+Opt+W / Ctrl+Opt+M

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWITCH_STATION_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "  === Switch Station — Setup macOS ==="
echo ""

# ── 1. Verificar Homebrew ────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    echo "  [X] Homebrew não encontrado!"
    echo "      Instale com: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
fi
echo "  [OK] Homebrew encontrado"

# ── 2. Instalar dependências ─────────────────────────────────────
install_if_missing() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo "  [OK] $cmd já instalado"
    else
        echo "  Instalando $pkg via Homebrew..."
        brew install "$pkg"
        echo "  [OK] $pkg instalado"
    fi
}

install_if_missing m1ddc
install_if_missing jq

# BetterDisplay (cask) — necessário pro Samsung via HDMI (m1ddc não suporta DDC/CI via HDMI)
if command -v betterdisplaycli &>/dev/null; then
    echo "  [OK] betterdisplaycli já instalado"
else
    echo "  Instalando BetterDisplay via Homebrew..."
    brew install --cask betterdisplay
    echo "  [OK] BetterDisplay instalado"
    echo "  [!] BetterDisplay precisa estar rodando. Abrindo..."
    open -a BetterDisplay 2>/dev/null || true
fi

# ── 3. Tornar scripts executáveis ────────────────────────────────
chmod +x "$SCRIPT_DIR/switch-to-windows.sh"
chmod +x "$SCRIPT_DIR/discover.sh"
echo "  [OK] Scripts marcados como executáveis"

# ── 4. Aliases no shell ──────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

# Criar o arquivo se não existir (Mac zerado)
touch "$SHELL_RC"

MARKER="# === switch-station ==="
if grep -q "$MARKER" "$SHELL_RC" 2>/dev/null; then
    # Remover bloco existente antes de recriar
    sed -i '' "/$MARKER/,/$MARKER/d" "$SHELL_RC"
fi

cat >> "$SHELL_RC" << EOF

$MARKER
alias windows="$SCRIPT_DIR/switch-to-windows.sh"
alias mac-fix="$SCRIPT_DIR/switch-to-windows.sh --reverse"
$MARKER
EOF
echo "  [OK] Aliases registrados em $SHELL_RC"

# ── 5. Automator Quick Actions (hotkeys globais) ─────────────────
SERVICES_DIR="$HOME/Library/Services"
mkdir -p "$SERVICES_DIR"

create_quick_action() {
    local name="$1"
    local script_path="$2"
    local workflow_dir="$SERVICES_DIR/$name.workflow"
    local contents_dir="$workflow_dir/Contents"

    rm -rf "$workflow_dir"
    mkdir -p "$contents_dir"

    cat > "$contents_dir/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>WORKFLOW_NAME</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
		</dict>
	</array>
</dict>
</plist>
PLIST
    sed -i '' "s|WORKFLOW_NAME|$name|g" "$contents_dir/Info.plist"

    cat > "$contents_dir/document.wflow" << WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMLargeIconName</key>
				<string>RunShellScriptAction</string>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>SCRIPT_PATH</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript-Automator-action</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>00000000-0000-0000-0000-000000000000</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
					<string>Script</string>
					<string>Command</string>
					<string>Run</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>00000000-0000-0000-0000-000000000001</string>
				<key>UUID</key>
				<string>00000000-0000-0000-0000-000000000002</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
			</dict>
			<key>isViewVisible</key>
			<true/>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
	</dict>
</dict>
</plist>
WFLOW
    sed -i '' "s|SCRIPT_PATH|$script_path|g" "$contents_dir/document.wflow"

    echo "  [OK] Quick Action criada: $name"
}

create_quick_action "Switch to Windows" "$SCRIPT_DIR/switch-to-windows.sh"
create_quick_action "Switch to Mac" "$SCRIPT_DIR/switch-to-windows.sh --reverse"

# ── 6. Hammerspoon — Hotkeys globais ─────────────────────────────
# Hammerspoon é mais confiável que Automator Quick Actions pra hotkeys
if ! command -v hs &>/dev/null; then
    echo "  Instalando Hammerspoon via Homebrew..."
    brew install --cask hammerspoon
    echo "  [OK] Hammerspoon instalado"
else
    echo "  [OK] Hammerspoon já instalado"
fi

HAMMERSPOON_DIR="$HOME/.hammerspoon"
mkdir -p "$HAMMERSPOON_DIR"

# Marker pra não sobrescrever config existente do usuario
HS_MARKER="-- === switch-station ==="
HS_INIT="$HAMMERSPOON_DIR/init.lua"
touch "$HS_INIT"

if grep -q "$HS_MARKER" "$HS_INIT" 2>/dev/null; then
    # Remover bloco existente (entre markers)
    sed -i '' "/$HS_MARKER/,/$HS_MARKER/d" "$HS_INIT"
fi

cat >> "$HS_INIT" << EOF

$HS_MARKER
-- Ctrl+Opt+W = troca TUDO pro Windows | Ctrl+Opt+M = volta TUDO pro Mac
-- Ctrl+Opt+1 = só periféricos pro Windows | Ctrl+Opt+3 = só periféricos pro Mac
-- Ctrl+Opt+S = split-screen (Alienware=Win, Samsung=Mac, periféricos=Mac)
local switchStation = "$SCRIPT_DIR/switch-to-windows.sh"
local switchPeripherals = "$SCRIPT_DIR/switch-peripherals.sh"
local splitScreen = "$SCRIPT_DIR/split-screen.sh"
hs.hotkey.bind({"ctrl", "alt"}, "W", function()
    hs.task.new("/bin/bash", nil, {switchStation}):start()
end)
hs.hotkey.bind({"ctrl", "alt"}, "M", function()
    hs.task.new("/bin/bash", nil, {switchStation, "--reverse"}):start()
end)
hs.hotkey.bind({"ctrl", "alt"}, "1", function()
    hs.task.new("/bin/bash", nil, {switchPeripherals, "windows"}):start()
end)
hs.hotkey.bind({"ctrl", "alt"}, "3", function()
    hs.task.new("/bin/bash", nil, {switchPeripherals, "mac"}):start()
end)
hs.hotkey.bind({"ctrl", "alt"}, "S", function()
    hs.task.new("/bin/bash", nil, {splitScreen}):start()
end)
$HS_MARKER
EOF

# Abrir Hammerspoon se não estiver rodando
open -a Hammerspoon 2>/dev/null || true
echo "  [OK] Hotkeys registradas via Hammerspoon"
echo "  [!] Na primeira vez: habilitar Hammerspoon em System Settings > Privacy > Accessibility"

# ── Resumo ────────────────────────────────────────────────────────
echo ""
echo "  Setup completo!"
echo ""
echo "  Terminal (após reabrir ou rodar: source $SHELL_RC):"
echo "    windows   -> troca tudo pro Windows"
echo "    mac-fix   -> volta pro Mac (emergência)"
echo ""
echo "  Hotkeys globais (funcionam de qualquer app):"
echo "    ⌃⌥W (Ctrl+Opt+W) -> troca TUDO pro Windows"
echo "    ⌃⌥M (Ctrl+Opt+M) -> volta TUDO pro Mac"
echo "    ⌃⌥S (Ctrl+Opt+S) -> split-screen (Alienware=Win, Samsung=Mac)"
echo "    ⌃⌥1 (Ctrl+Opt+1) -> só periféricos pro Windows"
echo "    ⌃⌥3 (Ctrl+Opt+3) -> só periféricos pro Mac"
echo ""
