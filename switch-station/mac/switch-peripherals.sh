#!/bin/bash
# switch-peripherals.sh — Troca só teclado + mouse (sem mexer nos monitores)
# Uso no modo split-screen (Alienware=Windows, Samsung=Mac)
#
# Uso: ./switch-peripherals.sh windows   (periféricos pro canal 1)
#      ./switch-peripherals.sh mac       (periféricos pro canal 3)
#      ./switch-peripherals.sh 1         (atalho: canal 1 = Windows)
#      ./switch-peripherals.sh 3         (atalho: canal 3 = Mac)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.json"
HID_SWITCH="$SCRIPT_DIR/hid_switch"

if ! command -v jq &>/dev/null; then
    echo "  jq não encontrado! Rode: ./setup.sh"
    exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "  config.json não encontrado"
    exit 1
fi

# ── Parse args ─────────────────────────────────────────────────────
case "${1:-}" in
    windows|win|1)
        CHANNEL_KEY="windows_channel"
        TARGET="WINDOWS (canal 1)"
        ;;
    mac|3)
        CHANNEL_KEY="mac_channel"
        TARGET="MAC (canal 3)"
        ;;
    *)
        echo "  Uso: $0 <windows|mac|1|3>"
        exit 1
        ;;
esac

# ── Trocar periféricos ────────────────────────────────────────────
PERIPH_COUNT=$(jq '.peripherals // [] | length' "$CONFIG")

if [[ $PERIPH_COUNT -eq 0 ]]; then
    echo "  Nenhum periférico configurado em config.json"
    exit 1
fi

# Pré-carregar config
declare -a P_NAMES P_VIDS P_PIDS P_FEATURES P_CHANNELS
for ((i=0; i<PERIPH_COUNT; i++)); do
    P_NAMES[$i]=$(jq -r ".peripherals[$i].name" "$CONFIG")
    P_VIDS[$i]=$(jq -r ".peripherals[$i].vid" "$CONFIG")
    P_PIDS[$i]=$(jq -r ".peripherals[$i].pid" "$CONFIG")
    P_FEATURES[$i]=$(jq -r ".peripherals[$i].change_host_feature_index" "$CONFIG")
    P_CHANNELS[$i]=$(jq -r ".peripherals[$i].$CHANNEL_KEY" "$CONFIG")
done

for ((i=0; i<PERIPH_COUNT; i++)); do
    FEATURE_HEX=$(printf "%02X" "${P_FEATURES[$i]}")
    CHANNEL_HEX=$(printf "%02X" "${P_CHANNELS[$i]}")
    PACKET="11,01,${FEATURE_HEX},10,${CHANNEL_HEX},00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"

    if [[ -x "$HID_SWITCH" ]]; then
        "$HID_SWITCH" "${P_VIDS[$i]}" "${P_PIDS[$i]}" "$PACKET" >/dev/null 2>&1
        echo "  [OK] ${P_NAMES[$i]} -> $TARGET"
    else
        echo "  [!] hid_switch não encontrado"
    fi
done

osascript -e "display notification \"Periféricos → $TARGET\" with title \"Switch Station\"" 2>/dev/null || true
