#!/bin/bash
# send.sh — Read Mac clipboard and POST to remote machine
# Usage: ./send.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.json"

if ! command -v jq &>/dev/null; then
    osascript -e 'display notification "jq não encontrado" with title "Clipboard Share" subtitle "Erro"' 2>/dev/null
    exit 1
fi

REMOTE_HOST=$(jq -r '.remote_host' "$CONFIG")
PORT=$(jq -r '.port // 9876' "$CONFIG")
URL="http://${REMOTE_HOST}:${PORT}/clip"

# Check if clipboard has a file (Finder copy)
FILE_PATH=$(osascript -e '
try
    set theFile to the clipboard as «class furl»
    return POSIX path of theFile
on error
    return ""
end try
' 2>/dev/null)

if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    # Send file
    FILENAME=$(basename "$FILE_PATH")
    RESPONSE=$(curl -s -m 10 -X POST "$URL" \
        -F "file=@${FILE_PATH}" \
        -F "filename=${FILENAME}" 2>&1)

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        osascript -e "display notification \"Arquivo enviado: $FILENAME\" with title \"Clipboard Share\"" 2>/dev/null
    else
        osascript -e "display notification \"Falha ao enviar arquivo\" with title \"Clipboard Share\" subtitle \"Erro\"" 2>/dev/null
    fi
else
    # Send text
    TEXT=$(pbpaste 2>/dev/null)
    if [[ -z "$TEXT" ]]; then
        osascript -e 'display notification "Clipboard vazio" with title "Clipboard Share"' 2>/dev/null
        exit 0
    fi

    # Escape text for JSON
    JSON_DATA=$(jq -n --arg t "$TEXT" '{"type":"text","data":$t}')

    RESPONSE=$(curl -s -m 10 -X POST "$URL" \
        -H "Content-Type: application/json" \
        -d "$JSON_DATA" 2>&1)

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        LEN=${#TEXT}
        osascript -e "display notification \"Texto enviado ($LEN chars)\" with title \"Clipboard Share\"" 2>/dev/null
    else
        osascript -e "display notification \"Falha ao enviar. Outro PC ligado?\" with title \"Clipboard Share\" subtitle \"Erro\"" 2>/dev/null
    fi
fi
