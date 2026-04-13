#!/bin/bash
# setup.sh — Instalador completo do Switch Station no macOS
# Rode uma vez: ./setup.sh
#
# O que faz:
#   1. Instala m1ddc via Homebrew
#   2. Registra aliases 'windows' e 'mac-fix' no shell
#   3. Cria Automator Quick Actions para hotkeys globais
#   4. Instrui como atribuir Ctrl+Opt+W / Ctrl+Opt+M

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  === Switch Station — Setup macOS ==="
echo ""

# ── 1. Instalar m1ddc ──────────────────────────────────────────────
if command -v m1ddc &>/dev/null; then
    echo "  [OK] m1ddc já instalado"
else
    echo "  Instalando m1ddc via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "  [X] Homebrew não encontrado! Instale: https://brew.sh"
        exit 1
    fi
    brew install m1ddc
    echo "  [OK] m1ddc instalado"
fi

# ── 2. Tornar scripts executáveis ──────────────────────────────────
chmod +x "$SCRIPT_DIR/switch-to-windows.sh"
chmod +x "$SCRIPT_DIR/discover.sh"
echo "  [OK] Scripts marcados como executáveis"

# ── 3. Aliases no shell ────────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

MARKER="# === switch-station ==="
if grep -q "$MARKER" "$SHELL_RC" 2>/dev/null; then
    # Atualizar bloco existente
    sed -i '' "/$MARKER/,/$MARKER/d" "$SHELL_RC"
fi

cat >> "$SHELL_RC" << EOF

$MARKER
alias windows="$SCRIPT_DIR/switch-to-windows.sh"
alias mac-fix="$SCRIPT_DIR/switch-to-windows.sh --reverse"
$MARKER
EOF
echo "  [OK] Aliases registrados no $SHELL_RC"

# ── 4. Automator Quick Actions (hotkeys globais) ───────────────────
SERVICES_DIR="$HOME/Library/Services"
mkdir -p "$SERVICES_DIR"

create_quick_action() {
    local name="$1"
    local script_path="$2"
    local workflow_dir="$SERVICES_DIR/$name.workflow"
    local contents_dir="$workflow_dir/Contents"

    # Remover se já existir
    rm -rf "$workflow_dir"
    mkdir -p "$contents_dir"

    # Info.plist — define como Quick Action (Service)
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

    # document.wflow — o workflow Automator que executa o shell script
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

# ── Resumo ──────────────────────────────────────────────────────────
echo ""
echo "  Setup completo!" -e
echo ""
echo "  Terminal (após reabrir):"
echo "    windows   -> troca tudo pro Windows"
echo "    mac-fix   -> volta pro Mac (emergência)"
echo ""
echo "  ┌─────────────────────────────────────────────────────────┐"
echo "  │  PASSO MANUAL — Atribuir hotkeys globais:              │"
echo "  │                                                         │"
echo "  │  1. System Settings > Keyboard > Keyboard Shortcuts     │"
echo "  │  2. Clique em 'Services' (ou 'Serviços')               │"
echo "  │  3. Em 'General', encontre:                             │"
echo "  │     • Switch to Windows -> atribua ⌃⌥W (Ctrl+Opt+W)   │"
echo "  │     • Switch to Mac     -> atribua ⌃⌥M (Ctrl+Opt+M)   │"
echo "  │  4. Pronto! Funciona de qualquer app.                   │"
echo "  └─────────────────────────────────────────────────────────┘"
echo ""
echo "  Próximo passo: rode ./discover.sh para verificar"
echo "  os display numbers e valores de input do m1ddc."
echo ""
