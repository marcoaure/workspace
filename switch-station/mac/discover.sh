#!/bin/bash
# discover.sh — Descobre monitores e valores de input DDC/CI no Mac
# Requer: brew install m1ddc

set -euo pipefail

if ! command -v m1ddc &>/dev/null; then
    echo "  m1ddc não encontrado! Instale com: brew install m1ddc"
    exit 1
fi

echo ""
echo "  MONITORES DETECTADOS (DDC/CI via m1ddc)"
echo "  ======================================="
echo ""

# Listar displays
m1ddc display list 2>/dev/null || true
echo ""

# Tentar ler input de cada display (até 4)
for i in 1 2 3 4; do
    INPUT=$(m1ddc get input -d "$i" 2>/dev/null || echo "N/A")
    if [[ "$INPUT" != "N/A" ]]; then
        echo "  Display $i: input atual = $INPUT"
    fi
done

echo ""
echo "  ============================================"
echo "  COMO DESCOBRIR OS VALORES CORRETOS:"
echo ""
echo "  1. Com monitores no MAC, rode este script"
echo "     e anote os valores de input"
echo ""
echo "  2. Troque manualmente pro WINDOWS (menu OSD)"
echo "     e rode novamente para ver os valores Windows"
echo ""
echo "  3. Edite switch-to-windows.sh com os valores"
echo "  ============================================"
echo ""
echo "  Valores comuns de input (VCP 0x60):"
echo "    15 (0x0F) = DisplayPort-1"
echo "    16 (0x10) = DisplayPort-2 / USB-C"
echo "    17 (0x11) = HDMI-1"
echo "    18 (0x12) = HDMI-2"
echo ""
