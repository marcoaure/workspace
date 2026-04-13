#!/bin/bash
# split-screen.sh — Modo dividido: Alienware=Windows, Samsung=Mac
# Troca só os monitores pra posição split + periféricos pro Mac
#
# Uso: ./split-screen.sh          (ativa split: Alienware→Win, Samsung→Mac, periféricos→Mac)
#      ./split-screen.sh windows  (split + periféricos pro Windows)

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

# Periféricos: pra onde mandar? Default = Mac (Samsung tá no Mac)
PERIPH_TARGET="mac"
if [[ "${1:-}" == "windows" || "${1:-}" == "win" ]]; then
    PERIPH_TARGET="windows"
fi

echo ""
echo "  Split Screen: Alienware→Windows | Samsung→Mac"
echo "  Periféricos → ${PERIPH_TARGET^^}"
echo ""

# ── 1. Monitores — cada um pro seu lado ───────────────────────────
echo "  ── Monitores ──"
MONITOR_COUNT=$(jq '.monitors | length' "$CONFIG")

for ((i=0; i<MONITOR_COUNT; i++)); do
    NAME=$(jq -r ".monitors[$i].name" "$CONFIG")
    DISPLAY=$(jq -r ".monitors[$i].mac_display" "$CONFIG")
    MATCH_MAC=$(jq -r ".monitors[$i].match_mac" "$CONFIG")
    TOOL=$(jq -r ".monitors[$i].mac_tool // \"m1ddc\"" "$CONFIG")

    # Alienware → Windows input, Samsung → Mac input
    if echo "$NAME" | grep -qi "alienware"; then
        INPUT=$(jq -r ".monitors[$i].windows_input" "$CONFIG")
        DEST="Windows"
    else
        INPUT=$(jq -r ".monitors[$i].mac_input" "$CONFIG")
        DEST="Mac"
    fi

    case "$TOOL" in
        m1ddc)
            m1ddc display "$DISPLAY" set input "$INPUT" 2>/dev/null
            echo "  [OK] $NAME -> $DEST (input $INPUT)"
            ;;
        betterdisplay)
            betterdisplaycli set -name="$MATCH_MAC" -ddc -vcp=inputSelect -value="$INPUT" 2>/dev/null
            echo "  [OK] $NAME -> $DEST (input $INPUT)"
            ;;
    esac
done

echo ""

# ── 2. Periféricos ────────────────────────────────────────────────
echo "  ── Periféricos ──"
PERIPH_COUNT=$(jq '.peripherals // [] | length' "$CONFIG")
CHANNEL_KEY="${PERIPH_TARGET}_channel"

if [[ $PERIPH_COUNT -gt 0 ]]; then
    set +e
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
            echo "  [OK] ${P_NAMES[$i]} -> ${PERIPH_TARGET^^} (canal $((${P_CHANNELS[$i]} + 1)))"
        fi
    done
    set -e
fi

echo ""
osascript -e "display notification \"Alienware→Win | Samsung→Mac | Periféricos→${PERIPH_TARGET^^}\" with title \"Split Screen\"" 2>/dev/null || true
