#!/bin/bash
# switch-to-windows.sh — Troca toda a estação de trabalho para o Windows
# Executa no Mac. Requer: brew install m1ddc
#
# Uso: ./switch-to-windows.sh          (muda pro Windows)
#      ./switch-to-windows.sh --reverse (volta pro Mac, emergência)

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
# Edite estes valores após rodar ./discover.sh no Mac
# Para descobrir os display numbers: m1ddc display list

ALIENWARE_DISPLAY=1          # Número do display m1ddc (1-based)
ALIENWARE_WIN_INPUT=15       # DP-1 (Windows)
ALIENWARE_MAC_INPUT=19       # DP-2 (Mac)

SAMSUNG_DISPLAY=2            # Número do display m1ddc (1-based)
SAMSUNG_WIN_INPUT=15         # DP (Windows)
SAMSUNG_MAC_INPUT=5          # HDMI (Mac) — Samsung usa valor não-padrão!
# ────────────────────────────────────────────────────────────────────

# Verificar m1ddc
if ! command -v m1ddc &>/dev/null; then
    echo "  m1ddc não encontrado! Instale com: brew install m1ddc"
    exit 1
fi

REVERSE=false
if [[ "${1:-}" == "--reverse" || "${1:-}" == "-r" ]]; then
    REVERSE=true
fi

if $REVERSE; then
    TARGET="MAC"
    ALIENWARE_INPUT=$ALIENWARE_MAC_INPUT
    SAMSUNG_INPUT=$SAMSUNG_MAC_INPUT
else
    TARGET="WINDOWS"
    ALIENWARE_INPUT=$ALIENWARE_WIN_INPUT
    SAMSUNG_INPUT=$SAMSUNG_WIN_INPUT
fi

echo ""
echo "  Switching to $TARGET..."
echo ""

# ── Trocar Alienware ────────────────────────────────────────────────
if m1ddc set input "$ALIENWARE_INPUT" -d "$ALIENWARE_DISPLAY" 2>/dev/null; then
    echo "  [OK] Alienware AW2725DF -> input $ALIENWARE_INPUT"
else
    echo "  [X]  Alienware AW2725DF -> FALHOU"
fi

# ── Trocar Samsung ──────────────────────────────────────────────────
if m1ddc set input "$SAMSUNG_INPUT" -d "$SAMSUNG_DISPLAY" 2>/dev/null; then
    echo "  [OK] Samsung UR550 -> input $SAMSUNG_INPUT"
else
    echo "  [X]  Samsung UR550 -> FALHOU"
fi

echo ""
if ! $REVERSE; then
    echo "  Monitores trocados!"
    echo "  Agora pressione Easy Switch no mouse e teclado (canal 1)."
else
    echo "  Monitores trocados de volta pro Mac!"
fi
echo ""
