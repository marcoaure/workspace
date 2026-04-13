#!/bin/bash
# clipboard-mac.sh — Inject text or file into macOS clipboard
# Usage: ./clipboard-mac.sh text "content here"
#        ./clipboard-mac.sh file "/path/to/file"

set -uo pipefail

case "${1:-}" in
    text)
        echo -n "${2:-}" | pbcopy
        echo "Clipboard set: text ($(echo -n "${2:-}" | wc -c | tr -d ' ') bytes)"
        ;;
    file)
        FILE_PATH="${2:-}"
        if [[ ! -f "$FILE_PATH" ]]; then
            echo "File not found: $FILE_PATH" >&2
            exit 1
        fi
        osascript -e "set the clipboard to (POSIX file \"$FILE_PATH\")"
        echo "Clipboard set: file ($FILE_PATH)"
        ;;
    *)
        echo "Usage: $0 <text|file> <content|path>" >&2
        exit 1
        ;;
esac
