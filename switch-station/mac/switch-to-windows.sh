#!/bin/bash
# switch-to-windows.sh — Troca toda a estação de trabalho para o Windows
# Executa no Mac. Requer: m1ddc, betterdisplaycli, jq, hid_switch, hidapitester
#
# Uso: ./switch-to-windows.sh          (muda pro Windows)
#      ./switch-to-windows.sh --reverse (volta pro Mac, emergência)
#
# Monitores (DDC/CI VCP 0x60):
#   Alienware AW2725DF: DP-1 (Win) = 15, DP-2 (Mac) = 19       [m1ddc]
#   Samsung UR550:      DP (Win) = 15, HDMI (Mac) = 5           [betterdisplay]
#
# Periféricos (HID++ Change Host):
#   MX Keys:        canal 1 (Win), canal 3 (Mac)   [hid_switch - Swift/IOKit]
#   MX Anywhere 3S: canal 1 (Win), canal 3 (Mac)   [hidapitester]
#
# Tudo em config.json (source of truth).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.json"
HID_SWITCH="$SCRIPT_DIR/hid_switch"
HIDAPITESTER="$SCRIPT_DIR/hidapitester"

# ── Verificar dependências ─────────────────────────────────────────
for cmd in m1ddc jq betterdisplaycli; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "  $cmd não encontrado! Rode: ./setup.sh"
        exit 1
    fi
done

if [[ ! -f "$CONFIG" ]]; then
    echo "  config.json não encontrado em: $CONFIG"
    exit 1
fi

# ── Parse args ─────────────────────────────────────────────────────
REVERSE=false
if [[ "${1:-}" == "--reverse" || "${1:-}" == "-r" ]]; then
    REVERSE=true
fi

if $REVERSE; then
    TARGET="MAC"
    INPUT_KEY="mac_input"
    CHANNEL_KEY="mac_channel"
else
    TARGET="WINDOWS"
    INPUT_KEY="windows_input"
    CHANNEL_KEY="windows_channel"
fi

echo ""
echo "  Switching to $TARGET..."
echo ""

# ── 1. Trocar periféricos PRIMEIRO (antes dos monitores) ──────────
# Na ida (→ Windows): manda periféricos pro canal Windows antes de perder os monitores
# Na volta (→ Mac): periféricos já devem estar no Mac (voltaram via Easy Switch ou script Windows)
PERIPH_COUNT=$(jq '.peripherals // [] | length' "$CONFIG")

if [[ $PERIPH_COUNT -gt 0 && "$REVERSE" == "false" ]]; then
    echo "  ── Periféricos ──"

    # Desabilitar errexit nesta seção — periféricos desconectam ao trocar e causam erros esperados
    set +e

    # Pré-carregar todos os dados dos periféricos antes de enviar comandos
    # (evita falha no jq se o teclado desconectar antes do mouse ser lido)
    declare -a P_NAMES P_VIDS P_PIDS P_FEATURES P_CHANNELS P_TOOLS
    for ((i=0; i<PERIPH_COUNT; i++)); do
        P_NAMES[$i]=$(jq -r ".peripherals[$i].name" "$CONFIG")
        P_VIDS[$i]=$(jq -r ".peripherals[$i].vid" "$CONFIG")
        P_PIDS[$i]=$(jq -r ".peripherals[$i].pid" "$CONFIG")
        P_FEATURES[$i]=$(jq -r ".peripherals[$i].change_host_feature_index" "$CONFIG")
        P_CHANNELS[$i]=$(jq -r ".peripherals[$i].$CHANNEL_KEY" "$CONFIG")
        P_TOOLS[$i]=$(jq -r ".peripherals[$i].mac_hid_tool // \"hid_switch\"" "$CONFIG")
    done

    # Pré-resolver device path do hidapitester (antes de desconectar qualquer coisa)
    declare -a P_DEV_PATHS
    for ((i=0; i<PERIPH_COUNT; i++)); do
        if [[ "${P_TOOLS[$i]}" == "hidapitester" && -x "$HIDAPITESTER" ]]; then
            P_DEV_PATHS[$i]=$("$HIDAPITESTER" --list-detail 2>/dev/null | grep -B5 "${P_VIDS[$i]}/${P_PIDS[$i]}" | grep -B5 "FF43" | grep "path:" | tail -1 | awk '{print $2}')
        else
            P_DEV_PATHS[$i]=""
        fi
    done

    for ((i=0; i<PERIPH_COUNT; i++)); do
        NAME="${P_NAMES[$i]}"
        VID="${P_VIDS[$i]}"
        PID="${P_PIDS[$i]}"
        FEATURE="${P_FEATURES[$i]}"
        CHANNEL="${P_CHANNELS[$i]}"
        TOOL="${P_TOOLS[$i]}"

        if [[ "$CHANNEL" == "null" || "$FEATURE" == "null" ]]; then
            echo "  [!] $NAME -> config incompleto"
            continue
        fi

        FEATURE_HEX=$(printf "%02X" "$FEATURE")
        CHANNEL_HEX=$(printf "%02X" "$CHANNEL")
        PACKET="11,01,${FEATURE_HEX},10,${CHANNEL_HEX},00,00,00,00,00,00,00,00,00,00,00,00,00,00,00"

        case "$TOOL" in
            hid_switch)
                if [[ -x "$HID_SWITCH" ]]; then
                    "$HID_SWITCH" "$VID" "$PID" "$PACKET" >/dev/null 2>&1
                    echo "  [OK] $NAME -> canal $((CHANNEL + 1))"
                else
                    echo "  [!] $NAME -> hid_switch não encontrado"
                fi
                ;;
            hidapitester)
                DEV_PATH="${P_DEV_PATHS[$i]}"
                if [[ -n "$DEV_PATH" && -x "$HIDAPITESTER" ]]; then
                    PACKET_0X=$(echo "$PACKET" | sed 's/\([0-9A-Fa-f]\{2\}\)/0x\1/g')
                    "$HIDAPITESTER" --open-path "$DEV_PATH" --length 20 --send-output "$PACKET_0X" >/dev/null 2>&1
                    echo "  [OK] $NAME -> canal $((CHANNEL + 1))"
                else
                    echo "  [!] $NAME -> device não encontrado no HID"
                fi
                ;;
            *)
                echo "  [!] $NAME -> mac_hid_tool desconhecido: $TOOL"
                ;;
        esac
    done

    set -e
    echo ""
    sleep 0.3
fi

# ── 2. Trocar monitores ───────────────────────────────────────────
echo "  ── Monitores ──"
MONITOR_COUNT=$(jq '.monitors | length' "$CONFIG")
SUCCESS=0
FAIL=0

for ((i=0; i<MONITOR_COUNT; i++)); do
    NAME=$(jq -r ".monitors[$i].name" "$CONFIG")
    DISPLAY=$(jq -r ".monitors[$i].mac_display" "$CONFIG")
    MATCH_MAC=$(jq -r ".monitors[$i].match_mac" "$CONFIG")
    TOOL=$(jq -r ".monitors[$i].mac_tool // \"m1ddc\"" "$CONFIG")
    INPUT=$(jq -r ".monitors[$i].$INPUT_KEY" "$CONFIG")

    if [[ "$INPUT" == "null" ]]; then
        echo "  [!] $NAME -> config incompleto ($INPUT_KEY faltando)"
        FAIL=$((FAIL + 1))
        continue
    fi

    case "$TOOL" in
        m1ddc)
            if m1ddc display "$DISPLAY" set input "$INPUT" 2>/dev/null; then
                echo "  [OK] $NAME -> input $INPUT (m1ddc, display $DISPLAY)"
                SUCCESS=$((SUCCESS + 1))
            else
                echo "  [X]  $NAME -> FALHOU (m1ddc, display $DISPLAY, input $INPUT)"
                FAIL=$((FAIL + 1))
            fi
            ;;
        betterdisplay)
            if betterdisplaycli set -name="$MATCH_MAC" -ddc -vcp=inputSelect -value="$INPUT" 2>/dev/null; then
                echo "  [OK] $NAME -> input $INPUT (betterdisplay, $MATCH_MAC)"
                SUCCESS=$((SUCCESS + 1))
            else
                echo "  [X]  $NAME -> FALHOU (betterdisplay, $MATCH_MAC, input $INPUT)"
                FAIL=$((FAIL + 1))
            fi
            ;;
        *)
            echo "  [!] $NAME -> mac_tool desconhecido: $TOOL"
            FAIL=$((FAIL + 1))
            ;;
    esac
done

echo ""

# ── Notificação macOS ──────────────────────────────────────────────
if [[ $FAIL -eq 0 ]]; then
    if ! $REVERSE; then
        echo "  Tudo trocado pro Windows!"
        osascript -e "display notification \"Monitores + periféricos trocados\" with title \"Switch Station\" subtitle \"→ Windows\"" 2>/dev/null || true
    else
        echo "  Monitores de volta pro Mac!"
        osascript -e "display notification \"Monitores de volta pro Mac\" with title \"Switch Station\" subtitle \"→ Mac\"" 2>/dev/null || true
    fi
else
    echo "  ⚠ $FAIL monitor(es) falharam. Rode ./discover.sh para verificar."
    osascript -e "display notification \"$FAIL monitor(es) falharam\" with title \"Switch Station\" subtitle \"Erro\"" 2>/dev/null || true
fi
echo ""
