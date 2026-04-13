#!/bin/bash
# setup.sh — Instala m1ddc e registra alias 'windows' no Mac
# Rode uma vez: ./setup.sh

set -euo pipefail

echo ""
echo "  === Switch Station — Setup Mac ==="
echo ""

# ── Instalar m1ddc ──────────────────────────────────────────────────
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

# ── Tornar scripts executáveis ──────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$SCRIPT_DIR/switch-to-windows.sh"
chmod +x "$SCRIPT_DIR/discover.sh"
echo "  [OK] Scripts marcados como executáveis"

# ── Adicionar alias no shell ────────────────────────────────────────
SHELL_RC="$HOME/.zshrc"
if [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bashrc"
fi

MARKER="# === switch-station ==="
if grep -q "$MARKER" "$SHELL_RC" 2>/dev/null; then
    echo "  [OK] Aliases já estão no $SHELL_RC"
else
    cat >> "$SHELL_RC" << EOF

$MARKER
alias windows="$SCRIPT_DIR/switch-to-windows.sh"
alias mac-fix="$SCRIPT_DIR/switch-to-windows.sh --reverse"
$MARKER
EOF
    echo "  [OK] Aliases adicionados ao $SHELL_RC"
fi

echo ""
echo "  Comandos disponíveis (após reabrir o terminal):"
echo "    windows   -> troca tudo pro Windows"
echo "    mac-fix   -> volta pro Mac (emergência)"
echo ""
echo "  Próximo passo: rode ./discover.sh para identificar os"
echo "  valores de input e edite switch-to-windows.sh"
echo ""
