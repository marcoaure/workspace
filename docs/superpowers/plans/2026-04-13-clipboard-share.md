# Clipboard Share Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Share clipboard (text + files up to 50MB) between Mac and Windows over local network with one hotkey.

**Architecture:** Node.js HTTP server on each machine receives clipboard data via POST. Sender scripts read native clipboard and POST to the remote. mDNS resolves hostnames. Server injects received content into native clipboard immediately.

**Tech Stack:** Node.js, Express, Multer, Hammerspoon (Mac hotkeys), PowerShell (Windows hotkeys/clipboard)

---

## File Structure

```
workspace/clipboard-share/
├── package.json            # Dependencies: express, multer
├── config.json             # Port, remote host, temp dir, max file size
├── server.js               # HTTP server (cross-platform, runs on both OS)
├── lib/
│   ├── clipboard-mac.sh    # Mac: inject text/file into native clipboard
│   └── clipboard-win.ps1   # Windows: inject text/file into native clipboard
├── send.sh                 # Mac: read clipboard + POST to remote
├── send.ps1                # Windows: read clipboard + POST to remote
├── send.bat                # Windows: .bat launcher for send.ps1
├── start-server.bat        # Windows: .bat launcher for server
├── setup.sh                # Mac: npm install, LaunchAgent, Hammerspoon hotkeys
├── setup.ps1               # Windows: npm install, startup shortcut, hotkeys
└── README.md               # Docs
```

---

### Task 1: Project Scaffold + Config

**Files:**
- Create: `clipboard-share/package.json`
- Create: `clipboard-share/config.json`

- [ ] **Step 1: Create package.json**

```json
{
  "name": "clipboard-share",
  "version": "1.0.0",
  "private": true,
  "description": "Cross-OS clipboard sharing via HTTP + mDNS",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.21.0",
    "multer": "^1.4.5-lts.1"
  }
}
```

- [ ] **Step 2: Create config.json**

```json
{
  "port": 9876,
  "remote_host": "CHANGE_ME.local",
  "temp_dir": "clipboard-share-temp",
  "max_file_size_mb": 50
}
```

- [ ] **Step 3: Install dependencies**

Run: `cd clipboard-share && npm install`
Expected: `node_modules/` created, `package-lock.json` generated.

- [ ] **Step 4: Add node_modules to .gitignore**

Append to `clipboard-share/.gitignore`:
```
node_modules/
```

- [ ] **Step 5: Commit**

```bash
git add clipboard-share/package.json clipboard-share/config.json clipboard-share/package-lock.json clipboard-share/.gitignore
git commit -m "feat(clipboard-share): project scaffold and config"
```

---

### Task 2: Clipboard Injection Scripts

Platform-specific scripts that inject text or file into the native clipboard. These are called by the server after receiving data.

**Files:**
- Create: `clipboard-share/lib/clipboard-mac.sh`
- Create: `clipboard-share/lib/clipboard-win.ps1`

- [ ] **Step 1: Create Mac clipboard injection script**

`clipboard-share/lib/clipboard-mac.sh`:
```bash
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
```

- [ ] **Step 2: Create Windows clipboard injection script**

`clipboard-share/lib/clipboard-win.ps1`:
```powershell
# clipboard-win.ps1 — Inject text or file into Windows clipboard
# Usage: powershell -File clipboard-win.ps1 -Type text -Content "hello"
#        powershell -File clipboard-win.ps1 -Type file -Content "C:\path\to\file"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("text","file")]
    [string]$Type,

    [Parameter(Mandatory=$true)]
    [string]$Content
)

switch ($Type) {
    "text" {
        Set-Clipboard -Value $Content
        Write-Host "Clipboard set: text ($($Content.Length) chars)"
    }
    "file" {
        if (-not (Test-Path $Content)) {
            Write-Error "File not found: $Content"
            exit 1
        }
        Set-Clipboard -Path $Content
        Write-Host "Clipboard set: file ($Content)"
    }
}
```

- [ ] **Step 3: Make Mac script executable**

Run: `chmod +x clipboard-share/lib/clipboard-mac.sh`

- [ ] **Step 4: Test Mac clipboard injection manually**

Run: `./clipboard-share/lib/clipboard-mac.sh text "hello from clipboard-share"`
Then: `pbpaste` should output `hello from clipboard-share`

- [ ] **Step 5: Commit**

```bash
git add clipboard-share/lib/
git commit -m "feat(clipboard-share): clipboard injection scripts (Mac + Windows)"
```

---

### Task 3: HTTP Server

The core server that runs on both OS. Receives text/file via POST, injects into native clipboard.

**Files:**
- Create: `clipboard-share/server.js`

- [ ] **Step 1: Create server.js**

```javascript
const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync, execFile } = require('child_process');

// Load config
const configPath = path.join(__dirname, 'config.json');
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

const PORT = config.port || 9876;
const MAX_SIZE = (config.max_file_size_mb || 50) * 1024 * 1024;

// Resolve temp dir
const tempDir = config.temp_dir.startsWith('~')
  ? path.join(os.homedir(), config.temp_dir.slice(1))
  : path.resolve(config.temp_dir);

// Ensure temp dir exists, clean on start
if (fs.existsSync(tempDir)) {
  fs.rmSync(tempDir, { recursive: true });
}
fs.mkdirSync(tempDir, { recursive: true });

// Detect platform
const isMac = process.platform === 'darwin';
const isWin = process.platform === 'win32';

const libDir = path.join(__dirname, 'lib');

function injectClipboard(type, content) {
  if (isMac) {
    execFile('bash', [path.join(libDir, 'clipboard-mac.sh'), type, content], (err, stdout) => {
      if (err) console.error('Clipboard inject error:', err.message);
      else console.log(stdout.trim());
    });
  } else if (isWin) {
    execFile('powershell', [
      '-ExecutionPolicy', 'Bypass', '-NoProfile', '-File',
      path.join(libDir, 'clipboard-win.ps1'),
      '-Type', type, '-Content', content
    ], (err, stdout) => {
      if (err) console.error('Clipboard inject error:', err.message);
      else console.log(stdout.trim());
    });
  }
}

function notify(message) {
  if (isMac) {
    try {
      execSync(`osascript -e 'display notification "${message}" with title "Clipboard Share"'`);
    } catch {}
  } else if (isWin) {
    // Windows toast via PowerShell
    try {
      execSync(`powershell -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms'); [System.Windows.Forms.MessageBox]::Show('${message}','Clipboard Share')" `, { timeout: 1000 });
    } catch {}
  }
}

// Express app
const app = express();
app.use(express.json({ limit: '1mb' }));

// Multer for file uploads
const storage = multer.diskStorage({
  destination: tempDir,
  filename: (req, file, cb) => {
    cb(null, file.originalname);
  }
});
const upload = multer({ storage, limits: { fileSize: MAX_SIZE } });

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', hostname: os.hostname(), platform: process.platform });
});

// Receive clipboard
app.post('/clip', upload.single('file'), (req, res) => {
  // File upload
  if (req.file) {
    const filePath = path.resolve(req.file.path);
    console.log(`Received file: ${req.file.originalname} (${req.file.size} bytes)`);
    injectClipboard('file', filePath);
    notify(`Arquivo recebido: ${req.file.originalname}`);
    return res.json({ ok: true, type: 'file', filename: req.file.originalname });
  }

  // Text
  if (req.body && req.body.type === 'text' && req.body.data) {
    const text = req.body.data;
    console.log(`Received text: ${text.length} chars`);
    injectClipboard('text', text);
    notify('Texto recebido');
    return res.json({ ok: true, type: 'text', length: text.length });
  }

  res.status(400).json({ error: 'No text or file provided' });
});

// Error handler for multer
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: `File too large. Max: ${config.max_file_size_mb}MB` });
  }
  next(err);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Clipboard Share server running on port ${PORT}`);
  console.log(`Platform: ${process.platform} | Hostname: ${os.hostname()}`);
  console.log(`Temp dir: ${tempDir}`);
  console.log(`Max file size: ${config.max_file_size_mb}MB`);
});
```

- [ ] **Step 2: Test server starts**

Run: `cd clipboard-share && node server.js`
Expected: `Clipboard Share server running on port 9876`

Kill with Ctrl+C.

- [ ] **Step 3: Test health endpoint**

Run server in background: `cd clipboard-share && node server.js &`
Run: `curl http://localhost:9876/health`
Expected: `{"status":"ok","hostname":"MacBook-Pro-de-Marco","platform":"darwin"}`

Kill: `kill %1`

- [ ] **Step 4: Test text receive**

Run server: `cd clipboard-share && node server.js &`
Run: `curl -X POST http://localhost:9876/clip -H "Content-Type: application/json" -d '{"type":"text","data":"hello from curl"}'`
Expected: `{"ok":true,"type":"text","length":15}`
Verify: `pbpaste` should output `hello from curl`

Kill: `kill %1`

- [ ] **Step 5: Test file receive**

Run server: `cd clipboard-share && node server.js &`
Create test file: `echo "test content" > /tmp/test-clip.txt`
Run: `curl -X POST http://localhost:9876/clip -F "file=@/tmp/test-clip.txt"`
Expected: `{"ok":true,"type":"file","filename":"test-clip.txt"}`

Kill: `kill %1`

- [ ] **Step 6: Commit**

```bash
git add clipboard-share/server.js
git commit -m "feat(clipboard-share): HTTP server with text and file receive"
```

---

### Task 4: Mac Sender Script

Reads the Mac clipboard (text or file) and POSTs to the remote server.

**Files:**
- Create: `clipboard-share/send.sh`

- [ ] **Step 1: Create send.sh**

```bash
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
```

- [ ] **Step 2: Make executable**

Run: `chmod +x clipboard-share/send.sh`

- [ ] **Step 3: Test text send (to local server)**

Run server: `cd clipboard-share && node server.js &`
Copy text: `echo "test send" | pbcopy`
Run: `./clipboard-share/send.sh`
Expected: macOS notification "Texto enviado (9 chars)"

Kill: `kill %1`

- [ ] **Step 4: Commit**

```bash
git add clipboard-share/send.sh
git commit -m "feat(clipboard-share): Mac sender script (text + file)"
```

---

### Task 5: Windows Sender Script

**Files:**
- Create: `clipboard-share/send.ps1`
- Create: `clipboard-share/send.bat`

- [ ] **Step 1: Create send.ps1**

```powershell
# send.ps1 — Read Windows clipboard and POST to remote machine

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$remoteHost = $config.remote_host
$port = if ($config.port) { $config.port } else { 9876 }
$url = "http://${remoteHost}:${port}/clip"

# Check if clipboard has files
$files = Get-Clipboard -Format FileDropList -ErrorAction SilentlyContinue

if ($files -and $files.Count -gt 0) {
    # Send first file
    $filePath = $files[0].FullName
    $fileName = $files[0].Name

    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
            "Content-Type: application/octet-stream",
            "",
            ""
        )
        $bodyEnd = "$LF--$boundary--$LF"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($bodyLines -join $LF))
        $endBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyEnd)

        $body = New-Object byte[] ($headerBytes.Length + $fileBytes.Length + $endBytes.Length)
        [System.Buffer]::BlockCopy($headerBytes, 0, $body, 0, $headerBytes.Length)
        [System.Buffer]::BlockCopy($fileBytes, 0, $body, $headerBytes.Length, $fileBytes.Length)
        [System.Buffer]::BlockCopy($endBytes, 0, $body, $headerBytes.Length + $fileBytes.Length, $endBytes.Length)

        $response = Invoke-WebRequest -Uri $url -Method POST -Body $body `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -TimeoutSec 10 -ErrorAction Stop

        Write-Host "[OK] Arquivo enviado: $fileName"
    } catch {
        Write-Host "[X] Falha ao enviar arquivo: $_" -ForegroundColor Red
    }
} else {
    # Send text
    $text = Get-Clipboard -Format Text -ErrorAction SilentlyContinue
    if (-not $text) {
        Write-Host 'Clipboard vazio'
        exit 0
    }

    $textJoined = if ($text -is [array]) { $text -join "`n" } else { $text }

    try {
        $jsonBody = @{ type = 'text'; data = $textJoined } | ConvertTo-Json -Compress
        $response = Invoke-WebRequest -Uri $url -Method POST -Body $jsonBody `
            -ContentType 'application/json; charset=utf-8' `
            -TimeoutSec 10 -ErrorAction Stop

        Write-Host "[OK] Texto enviado ($($textJoined.Length) chars)"
    } catch {
        Write-Host "[X] Falha ao enviar. Outro PC ligado?" -ForegroundColor Red
    }
}
```

- [ ] **Step 2: Create send.bat**

```batch
@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0send.ps1"
timeout /t 2
```

- [ ] **Step 3: Commit**

```bash
git add clipboard-share/send.ps1 clipboard-share/send.bat
git commit -m "feat(clipboard-share): Windows sender script (text + file)"
```

---

### Task 6: Windows Server Launcher

**Files:**
- Create: `clipboard-share/start-server.bat`

- [ ] **Step 1: Create start-server.bat**

```batch
@echo off
cd /d "%~dp0"
node server.js
```

- [ ] **Step 2: Commit**

```bash
git add clipboard-share/start-server.bat
git commit -m "feat(clipboard-share): Windows server launcher bat"
```

---

### Task 7: Mac Setup (npm install + LaunchAgent + Hammerspoon)

**Files:**
- Create: `clipboard-share/setup.sh`

- [ ] **Step 1: Create setup.sh**

```bash
#!/bin/bash
# setup.sh — Setup clipboard-share no macOS
# Rode uma vez: ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "  === Clipboard Share — Setup macOS ==="
echo ""

# ── 1. Verificar Node.js ─────────────────────────────────────────
if ! command -v node &>/dev/null; then
    echo "  [X] Node.js não encontrado! Instale via: brew install node"
    exit 1
fi
echo "  [OK] Node.js $(node --version)"

# ── 2. npm install ───────────────────────────────────────────────
cd "$SCRIPT_DIR"
if [[ ! -d "node_modules" ]]; then
    echo "  Instalando dependências..."
    npm install --production
fi
echo "  [OK] Dependências instaladas"

# ── 3. Tornar scripts executáveis ────────────────────────────────
chmod +x "$SCRIPT_DIR/send.sh"
chmod +x "$SCRIPT_DIR/lib/clipboard-mac.sh"
echo "  [OK] Scripts executáveis"

# ── 4. Criar temp dir ───────────────────────────────────────────
TEMP_DIR="$HOME/clipboard-share-temp"
mkdir -p "$TEMP_DIR"
echo "  [OK] Temp dir: $TEMP_DIR"

# ── 5. Configurar remote_host ───────────────────────────────────
CONFIG="$SCRIPT_DIR/config.json"
CURRENT_REMOTE=$(jq -r '.remote_host' "$CONFIG")
if [[ "$CURRENT_REMOTE" == "CHANGE_ME.local" ]]; then
    echo ""
    echo "  Qual o hostname do WINDOWS? (ex: DESKTOP-ABC123)"
    echo "  Dica: no Windows, rode 'hostname' no terminal"
    read -rp "  > " WIN_HOSTNAME
    if [[ -n "$WIN_HOSTNAME" ]]; then
        # Append .local if not present
        if [[ "$WIN_HOSTNAME" != *.local ]]; then
            WIN_HOSTNAME="${WIN_HOSTNAME}.local"
        fi
        jq --arg h "$WIN_HOSTNAME" '.remote_host = $h' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
        echo "  [OK] remote_host = $WIN_HOSTNAME"
    fi
fi

# ── 6. LaunchAgent (autostart) ───────────────────────────────────
PLIST_NAME="com.workspace.clipboard-share"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which node)</string>
        <string>${SCRIPT_DIR}/server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/clipboard-share.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/clipboard-share.log</string>
</dict>
</plist>
PLIST

# Load the agent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"
echo "  [OK] LaunchAgent registrado (autostart no login)"

# ── 7. Hammerspoon hotkey ────────────────────────────────────────
HS_INIT="$HOME/.hammerspoon/init.lua"
HS_MARKER="-- === clipboard-share ==="

if [[ -f "$HS_INIT" ]]; then
    if grep -q "$HS_MARKER" "$HS_INIT" 2>/dev/null; then
        sed -i '' "/$HS_MARKER/,/$HS_MARKER/d" "$HS_INIT"
    fi
fi

cat >> "$HS_INIT" << EOF

$HS_MARKER
-- Cmd+Shift+C = send clipboard to other PC
hs.hotkey.bind({"cmd", "shift"}, "C", function()
    hs.task.new("/bin/bash", nil, {"$SCRIPT_DIR/send.sh"}):start()
end)
$HS_MARKER
EOF

echo "  [OK] Hotkey registrada: Cmd+Shift+C (envia clipboard)"

# ── Resumo ────────────────────────────────────────────────────────
echo ""
echo "  Setup completo!"
echo ""
echo "  Server: roda automaticamente no login (porta $(jq -r '.port' "$CONFIG"))"
echo "  Hotkey: Cmd+Shift+C → envia clipboard pro Windows"
echo "  Paste:  Cmd+V normal (clipboard já injetado ao receber)"
echo ""
echo "  Logs:   /tmp/clipboard-share.log"
echo "  Config: $CONFIG"
echo ""
```

- [ ] **Step 2: Make executable**

Run: `chmod +x clipboard-share/setup.sh`

- [ ] **Step 3: Commit**

```bash
git add clipboard-share/setup.sh
git commit -m "feat(clipboard-share): Mac setup (npm, LaunchAgent, Hammerspoon)"
```

---

### Task 8: Windows Setup (npm install + Startup + Hotkeys)

**Files:**
- Create: `clipboard-share/setup.ps1`

- [ ] **Step 1: Create setup.ps1**

```powershell
# setup.ps1 — Setup clipboard-share no Windows

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '  === Clipboard Share — Setup Windows ===' -ForegroundColor Cyan
Write-Host ''

# ── 1. Verificar Node.js ─────────────────────────────────────────
$nodeVersion = & node --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host '  [X] Node.js nao encontrado! Instale: https://nodejs.org' -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Node.js $nodeVersion" -ForegroundColor Green

# ── 2. npm install ───────────────────────────────────────────────
Push-Location $scriptDir
if (-not (Test-Path 'node_modules')) {
    Write-Host '  Instalando dependencias...'
    & npm install --production
}
Pop-Location
Write-Host '  [OK] Dependencias instaladas' -ForegroundColor Green

# ── 3. Criar temp dir ───────────────────────────────────────────
$tempDir = Join-Path $env:USERPROFILE 'clipboard-share-temp'
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}
Write-Host "  [OK] Temp dir: $tempDir" -ForegroundColor Green

# ── 4. Configurar remote_host ───────────────────────────────────
$configPath = Join-Path $scriptDir 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

if ($config.remote_host -eq 'CHANGE_ME.local') {
    Write-Host ''
    Write-Host '  Qual o hostname do MAC? (ex: MacBook-Pro-de-Marco)'
    Write-Host '  Dica: no Mac, rode "hostname" no terminal'
    $macHostname = Read-Host '  '
    if ($macHostname) {
        if (-not $macHostname.EndsWith('.local')) {
            $macHostname = "$macHostname.local"
        }
        $config.remote_host = $macHostname
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Host "  [OK] remote_host = $macHostname" -ForegroundColor Green
    }
}

# ── 5. Startup (autostart) ──────────────────────────────────────
$startupDir = [System.Environment]::GetFolderPath('Startup')
$startupLink = Join-Path $startupDir 'Clipboard Share Server.lnk'

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($startupLink)
$lnk.TargetPath = Join-Path $scriptDir 'start-server.bat'
$lnk.WorkingDirectory = $scriptDir
$lnk.WindowStyle = 7  # Minimized
$lnk.Description = 'Clipboard Share Server'
$lnk.Save()
Write-Host '  [OK] Autostart registrado (Startup folder)' -ForegroundColor Green

# ── 6. Hotkey (Ctrl+Shift+C) ────────────────────────────────────
$startMenu = [System.Environment]::GetFolderPath('Programs')
if (-not $startMenu) {
    $startMenu = $env:APPDATA + '\Microsoft\Windows\Start Menu\Programs'
}

$sendLink = Join-Path $startMenu 'Clipboard Share Send.lnk'
$lnk2 = $ws.CreateShortcut($sendLink)
$lnk2.TargetPath = Join-Path $scriptDir 'send.bat'
$lnk2.WorkingDirectory = $scriptDir
$lnk2.WindowStyle = 7
$lnk2.Hotkey = 'Ctrl+Shift+C'
$lnk2.Description = 'Envia clipboard pro outro PC'
$lnk2.Save()
Write-Host '  [OK] Hotkey: Ctrl+Shift+C -> envia clipboard' -ForegroundColor Green

# ── Resumo ────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  Setup completo!' -ForegroundColor Green
Write-Host ''
Write-Host "  Server: roda automaticamente no login (porta $($config.port))" -ForegroundColor White
Write-Host '  Hotkey: Ctrl+Shift+C -> envia clipboard pro Mac' -ForegroundColor White
Write-Host '  Paste:  Ctrl+V normal (clipboard ja injetado ao receber)' -ForegroundColor White
Write-Host ''
Write-Host "  Config: $configPath" -ForegroundColor DarkGray
Write-Host ''
```

- [ ] **Step 2: Commit**

```bash
git add clipboard-share/setup.ps1
git commit -m "feat(clipboard-share): Windows setup (npm, startup, hotkeys)"
```

---

### Task 9: README + Workspace Integration

**Files:**
- Create: `clipboard-share/README.md`
- Modify: `README.md` (workspace root)

- [ ] **Step 1: Create clipboard-share README**

```markdown
# Clipboard Share

Compartilha clipboard (texto + arquivos) entre Mac e Windows via rede local.

## Setup

### Mac
```bash
cd ~/workspace/clipboard-share
./setup.sh
```

### Windows
```powershell
cd ~\workspace\clipboard-share
.\setup.ps1
```

O setup instala dependências, configura autostart e registra hotkeys.

## Uso

| Ação | Mac | Windows |
|------|-----|---------|
| Enviar clipboard pro outro PC | **Cmd+Shift+C** | **Ctrl+Shift+C** |
| Colar | Cmd+V (normal) | Ctrl+V (normal) |

O server roda em background e injeta automaticamente no clipboard ao receber.

## Config

Edite `config.json` em cada máquina:

```json
{
  "port": 9876,
  "remote_host": "HOSTNAME-DO-OUTRO-PC.local",
  "temp_dir": "clipboard-share-temp",
  "max_file_size_mb": 50
}
```

## Troubleshooting

- **"Outro PC não encontrado"**: Verifique se o server está rodando (`curl http://HOSTNAME.local:9876/health`)
- **mDNS não resolve**: Use IP direto no `remote_host` (ex: `192.168.1.100`)
- **Windows mDNS**: Precisa do Bonjour service (vem com iTunes/iCloud)
```

- [ ] **Step 2: Add clipboard-share to workspace README**

Add to the modules section of `README.md`:

```markdown
### [`clipboard-share/`](clipboard-share/)
Clipboard compartilhado entre Mac e Windows via rede local. Texto e arquivos até 50MB.

```bash
# No Mac — enviar pro Windows
Cmd+Shift+C

# No Windows — enviar pro Mac
Ctrl+Shift+C

# Colar: Cmd+V / Ctrl+V normal
```
```

- [ ] **Step 3: Commit**

```bash
git add clipboard-share/README.md README.md
git commit -m "docs(clipboard-share): README and workspace integration"
```

---

### Task 10: End-to-End Test (Mac)

- [ ] **Step 1: Run setup**

Run: `cd clipboard-share && ./setup.sh`
Enter Windows hostname when prompted.

- [ ] **Step 2: Verify server is running**

Run: `curl http://localhost:9876/health`
Expected: `{"status":"ok",...}`

- [ ] **Step 3: Test send to self (text)**

Copy text: `echo "e2e test" | pbcopy`
Run: Config temporarily with `remote_host: "localhost"` then `./send.sh`
Verify: `pbpaste` outputs the text, notification appears.

- [ ] **Step 4: Test send to self (file)**

Copy a file in Finder (Cmd+C on a file).
Run: `./send.sh`
Verify: Notification shows filename, file appears in `~/clipboard-share-temp/`.

- [ ] **Step 5: Restore config and push**

Restore `remote_host` to Windows hostname.

```bash
git add -A clipboard-share/
git commit -m "feat(clipboard-share): complete implementation"
git push
```
