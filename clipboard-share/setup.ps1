# setup.ps1 — Setup clipboard-share no Windows

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '  === Clipboard Share — Setup Windows ===' -ForegroundColor Cyan
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

# 4. Configure remote_host
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

# 5. Startup (autostart)
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

# Resumo
Write-Host ''
Write-Host '  Setup completo!' -ForegroundColor Green
Write-Host ''
Write-Host "  Server: roda automaticamente no login (porta $($config.port))" -ForegroundColor White
Write-Host '  Hotkey: Ctrl+Shift+C -> envia clipboard pro Mac' -ForegroundColor White
Write-Host '  Paste:  Ctrl+V normal (clipboard ja injetado ao receber)' -ForegroundColor White
Write-Host ''
Write-Host "  Config: $configPath" -ForegroundColor DarkGray
Write-Host ''
