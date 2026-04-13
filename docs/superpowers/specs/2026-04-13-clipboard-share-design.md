# Clipboard Share — Design Spec

Cross-OS clipboard sharing between Mac and Windows via HTTP over local network with mDNS discovery.

## Problem

Two machines (Mac + Windows) on the same local network. No native way to copy text or files from one and paste on the other without cloud services or third-party apps.

## Solution

Each machine runs a lightweight HTTP server (Node.js) that receives clipboard data from the other. Hotkeys trigger send/receive. mDNS resolves hostnames so no IP configuration needed.

## Architecture

```
Mac (Cmd+Shift+C)                              Windows (Ctrl+Shift+V)
┌──────────────┐     POST /clip          ┌──────────────┐
│  Hammerspoon │ ──────────────────────► │  Clip Server  │
│  hotkey      │     text or file        │  (background) │
│  → read clip │     via HTTP            │  → save temp  │
│  → POST      │                         │  → inject clip│
└──────────────┘                         └──────────────┘

Windows (Ctrl+Shift+C)                         Mac (Cmd+Shift+V)
┌──────────────┐     POST /clip          ┌──────────────┐
│  PowerShell  │ ──────────────────────► │  Clip Server  │
│  hotkey      │     text or file        │  (background) │
│  → read clip │     via HTTP            │  → save temp  │
│  → POST      │                         │  → inject clip│
└──────────────┘                         └──────────────┘
```

Each machine is both a **server** (receives from remote) and a **sender** (hotkey triggers POST to remote).

## Hotkeys

| Action | Mac | Windows |
|--------|-----|---------|
| Send clipboard to other PC | Cmd+Shift+C | Ctrl+Shift+C |
| Paste from other PC | Cmd+Shift+V | Ctrl+Shift+V |

## API

### `POST /clip`

Receives clipboard content from the remote machine.

**Text:**
```
Content-Type: application/json
{ "type": "text", "data": "clipboard content" }
```

**File:**
```
Content-Type: multipart/form-data
Field: file (the file binary)
Field: filename (original filename)
```

Server stores received content in memory (text) or temp dir (file) and injects into native clipboard.

### `GET /health`

Returns `200 OK` with `{ "status": "ok", "hostname": "..." }`. Used to verify the other machine is reachable.

## Flows

### Text Flow
1. User presses hotkey → read local clipboard text
2. POST JSON to remote `http://<remote>:9876/clip`
3. Remote server receives → stores text → injects into native clipboard via OS command
4. User presses paste hotkey on remote → text is already in clipboard, pastes normally

### File Flow
1. User presses hotkey → detect clipboard has file path(s)
2. Read file binary → POST multipart to remote `http://<remote>:9876/clip`
3. Remote server receives → save to `~/clipboard-share-temp/<filename>` → inject file path into native clipboard
4. User presses Ctrl+V / Cmd+V → file pastes from clipboard (Explorer/Finder)

### Clipboard Injection (per OS)

**Mac (receive side):**
- Text: `pbcopy` via stdin
- File: `osascript` to set clipboard to file reference (POSIX file)

**Windows (receive side):**
- Text: `Set-Clipboard` PowerShell cmdlet
- File: PowerShell `Set-Clipboard -Path` to place file in clipboard

## Config

File: `clipboard-share/config.json`

```json
{
  "port": 9876,
  "remote_host": "MacBook-Pro-de-Marco.local",
  "temp_dir": "~/clipboard-share-temp",
  "max_file_size_mb": 50
}
```

Each machine points `remote_host` to the **other** machine's mDNS hostname. The `setup.sh`/`setup.ps1` detects the local hostname and prompts for the remote one (or auto-discovers).

## mDNS

- **Mac:** Native Bonjour. Hostname: `MacBook-Pro-de-Marco.local`
- **Windows:** Bonjour service (bundled with iTunes/iCloud, or standalone install). Hostname: `<COMPUTERNAME>.local`

If mDNS isn't working, fallback to manual IP in config.json.

## Autostart

**Mac:** LaunchAgent plist in `~/Library/LaunchAgents/com.workspace.clipboard-share.plist`
- Runs `node server.js` at login
- `KeepAlive: true` for auto-restart on crash
- Registered by `setup.sh`

**Windows:** Startup folder shortcut in `shell:startup`
- Runs `start-server.bat` (which calls `node server.js`) minimized
- Registered by `setup.ps1`

## Project Structure

```
workspace/clipboard-share/
├── config.json          # Remote host, port, temp dir
├── server.js            # HTTP server (runs on both OS)
├── send.sh              # Mac: read clipboard + POST to remote
├── send.ps1             # Windows: read clipboard + POST to remote
├── receive-clip.sh      # Mac: inject received content into clipboard
├── receive-clip.ps1     # Windows: inject received content into clipboard
├── setup.sh             # Mac: install deps, register LaunchAgent + Hammerspoon hotkeys
├── setup.ps1            # Windows: install deps, register startup + hotkeys
├── package.json         # Node.js dependencies (express, multer)
└── README.md            # Docs
```

## Stack

- **Node.js** — server runtime (cross-platform, already installed on both machines)
- **express** — HTTP server
- **multer** — multipart file upload handling
- Dependencies installed via `npm install` in setup

## Hotkey Integration

**Mac:** Hammerspoon bindings added by `setup.sh` (same pattern as switch-station):
- `Cmd+Shift+C` → `hs.task.new("/bin/bash", nil, {sendScript}):start()`
- `Cmd+Shift+V` → triggers paste of whatever was last received (already in clipboard)

**Windows:** Start Menu shortcuts with hotkeys (same pattern as switch-station):
- `Ctrl+Shift+C` → `send.bat` launcher
- `Ctrl+Shift+V` → native paste (clipboard already injected by server)

Note: `Cmd+Shift+V` / `Ctrl+Shift+V` may not need a custom action if the server injects into clipboard immediately on receive. The user just does normal Cmd+V / Ctrl+V. But keeping dedicated hotkeys gives the option to fetch on demand if we change to pull-based later.

## Simplification

On receive, the server **immediately injects into native clipboard**. This means:
- Only the **send** hotkey is custom (Cmd+Shift+C / Ctrl+Shift+C)
- **Paste** uses normal Cmd+V / Ctrl+V — no custom hotkey needed
- Simpler implementation, fewer moving parts

## Security

- Server binds to `0.0.0.0:9876` (local network only)
- No auth (trusted home network)
- Max file size: 50MB (configurable)
- Temp files cleaned on server restart

## Error Handling

- Remote not reachable → macOS notification / Windows toast: "Outro PC não encontrado"
- File too large → notification with size limit
- Server crash → LaunchAgent/Startup auto-restarts
