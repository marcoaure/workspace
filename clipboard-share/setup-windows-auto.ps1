# setup-windows-auto.ps1 — Setup automatico clipboard-share no Windows
# Rode: powershell -ExecutionPolicy Bypass -File .\setup-windows-auto.ps1
# Nao precisa de input interativo — hostname do Mac ja configurado.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '  === Clipboard Share — Setup Windows (Auto) ===' -ForegroundColor Cyan
Write-Host ''

# 1. Verify Node.js
$nodeVersion = & node --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host '  [X] Node.js nao encontrado! Instale: https://nodejs.org' -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Node.js $nodeVersion" -ForegroundColor Green

# 2. npm install
Push-Location $scriptDir
if (-not (Test-Path 'node_modules')) {
    Write-Host '  Instalando dependencias...'
    & npm install --production
}
Pop-Location
Write-Host '  [OK] Dependencias instaladas' -ForegroundColor Green

# 3. Create temp dir
$tempDir = Join-Path $env:USERPROFILE 'clipboard-share-temp'
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}
Write-Host "  [OK] Temp dir: $tempDir" -ForegroundColor Green

# 4. Configure remote_host (Mac hostname)
$configPath = Join-Path $scriptDir 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$config.remote_host = 'MacBook-Pro-de-Marco.local'
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
Write-Host "  [OK] remote_host = MacBook-Pro-de-Marco.local" -ForegroundColor Green

# 5. Startup (autostart on boot)
$startupDir = [System.Environment]::GetFolderPath('Startup')
$startupLink = Join-Path $startupDir 'Clipboard Share Server.lnk'

$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut($startupLink)
$lnk.TargetPath = Join-Path $scriptDir 'start-server.bat'
$lnk.WorkingDirectory = $scriptDir
$lnk.WindowStyle = 7
$lnk.Description = 'Clipboard Share Server'
$lnk.Save()
Write-Host '  [OK] Autostart registrado (Startup folder)' -ForegroundColor Green

# 6. Hotkey (Ctrl+Shift+C)
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

# 7. Start server NOW (dont wait for reboot)
Write-Host ''
Write-Host '  Iniciando server...' -ForegroundColor Yellow
$serverProcess = Start-Process -FilePath 'node' -ArgumentList 'server.js' -WorkingDirectory $scriptDir -WindowStyle Minimized -PassThru
Start-Sleep -Seconds 2

# 8. Test health
try {
    $health = Invoke-WebRequest -Uri 'http://localhost:9876/health' -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  [OK] Server rodando: $($health.Content)" -ForegroundColor Green
} catch {
    Write-Host "  [!] Server pode nao ter iniciado. Verifique manualmente." -ForegroundColor Yellow
}

# Resumo
Write-Host ''
Write-Host '  Setup completo!' -ForegroundColor Green
Write-Host ''
Write-Host '  Server: rodando agora + autostart no boot (porta 9876)' -ForegroundColor White
Write-Host '  Hotkey: Ctrl+Shift+C -> envia clipboard pro Mac' -ForegroundColor White
Write-Host '  Paste:  Ctrl+V normal (clipboard ja injetado ao receber)' -ForegroundColor White
Write-Host ''
Write-Host '  Para testar: copie um texto e aperte Ctrl+Shift+C' -ForegroundColor DarkGray
Write-Host ''
