# setup.ps1 — Instalador completo do Switch Station no Windows
# Rode uma vez (como admin nao necessario):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# O que faz:
#   1. Registra aliases 'mac' e 'windows' no PowerShell $PROFILE
#   2. Cria atalhos no Start Menu com hotkeys globais

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ''
Write-Host '  === Switch Station — Setup Windows ===' -ForegroundColor Cyan
Write-Host ''

# ── 1. PowerShell aliases ──────────────────────────────────────────
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$marker = '# === switch-station ==='
$macFn = 'function mac { & "' + $scriptDir + '\switch-to-mac.ps1" @args }'
$winFn = 'function windows { & "' + $scriptDir + '\switch-to-mac.ps1" -Reverse @args }'
$block = "`n" + $marker + "`n" + $macFn + "`n" + $winFn + "`n" + $marker

$aliasExists = $false
if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    $escapedMarker = [regex]::Escape($marker)
    if ($content -match $escapedMarker) {
        $aliasExists = $true
    }
}

if ($aliasExists) {
    $pattern = '(?s)' + $escapedMarker + '.*?' + $escapedMarker
    $replacement = $marker + "`n" + $macFn + "`n" + $winFn + "`n" + $marker
    $content = [regex]::Replace($content, $pattern, $replacement)
    Set-Content -Path $PROFILE -Value $content.TrimEnd() -Encoding UTF8
    Write-Host '  [OK] Aliases atualizados no PowerShell profile' -ForegroundColor Green
} else {
    Add-Content -Path $PROFILE -Value $block -Encoding UTF8
    Write-Host '  [OK] Aliases registrados no PowerShell profile' -ForegroundColor Green
}

# ── 2. Start Menu shortcuts + hotkeys ──────────────────────────────
$ws = New-Object -ComObject WScript.Shell
$startMenu = [System.Environment]::GetFolderPath('Programs')
if (-not $startMenu) {
    $startMenu = $env:APPDATA + '\Microsoft\Windows\Start Menu\Programs'
}

$shortcuts = @(
    @{ Name = 'Switch to Mac';            Bat = 'switch-to-mac.bat';          Hotkey = 'Ctrl+Alt+M'; Desc = 'Troca tudo pro Mac' },
    @{ Name = 'Switch to Windows';        Bat = 'switch-to-windows.bat';      Hotkey = 'Ctrl+Alt+W'; Desc = 'Volta tudo pro Windows' },
    @{ Name = 'Split Screen';             Bat = 'split-screen.bat';           Hotkey = 'Ctrl+Alt+S'; Desc = 'Alienware=Win, Samsung=Mac' },
    @{ Name = 'Peripherals to Windows';   Bat = 'peripherals-to-windows.bat'; Hotkey = 'Ctrl+Alt+1'; Desc = 'So perifericos pro Windows' },
    @{ Name = 'Peripherals to Mac';       Bat = 'peripherals-to-mac.bat';     Hotkey = 'Ctrl+Alt+3'; Desc = 'So perifericos pro Mac' }
)

foreach ($s in $shortcuts) {
    $lnkPath = $startMenu + '\' + $s.Name + '.lnk'
    $lnk = $ws.CreateShortcut($lnkPath)
    $lnk.TargetPath = $scriptDir + '\' + $s.Bat
    $lnk.WorkingDirectory = $scriptDir
    $lnk.WindowStyle = 7
    $lnk.Hotkey = $s.Hotkey
    $lnk.Description = $s.Desc
    $lnk.Save()
    Write-Host ('  [OK] ' + $s.Hotkey + ' -> ' + $s.Name) -ForegroundColor Green
}

# ── Resumo ──────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  Setup completo!' -ForegroundColor Green
Write-Host ''
Write-Host '  Hotkeys globais (funcionam de qualquer lugar):' -ForegroundColor Cyan
Write-Host '    Ctrl+Alt+M  -> troca TUDO pro Mac' -ForegroundColor White
Write-Host '    Ctrl+Alt+W  -> troca TUDO pro Windows' -ForegroundColor White
Write-Host '    Ctrl+Alt+S  -> split-screen (Alienware=Win, Samsung=Mac)' -ForegroundColor White
Write-Host '    Ctrl+Alt+1  -> so perifericos pro Windows' -ForegroundColor White
Write-Host '    Ctrl+Alt+3  -> so perifericos pro Mac' -ForegroundColor White
Write-Host ''
Write-Host '  Terminal (apos reabrir):' -ForegroundColor Cyan
Write-Host '    mac          -> troca tudo pro Mac' -ForegroundColor White
Write-Host '    windows      -> volta tudo pro Windows' -ForegroundColor White
Write-Host ''
Write-Host ('  Profile: ' + $PROFILE) -ForegroundColor DarkGray
Write-Host ('  Atalhos: ' + $startMenu) -ForegroundColor DarkGray
Write-Host ''
