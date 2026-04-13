# setup.ps1 — Instalador completo do Switch Station no Windows
# Rode uma vez (como admin nao necessario):
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# O que faz:
#   1. Registra aliases 'mac' e 'windows' no PowerShell $PROFILE
#   2. Cria atalhos no Start Menu com hotkeys globais (Ctrl+Alt+M / Ctrl+Alt+W)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  === Switch Station — Setup Windows ===" -ForegroundColor Cyan
Write-Host ""

# ── 1. PowerShell aliases ──────────────────────────────────────────
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$marker = "# === switch-station ==="
$block = @"

$marker
function mac { & "$scriptDir\switch-to-mac.ps1" @args }
function windows { & "$scriptDir\switch-to-mac.ps1" -Reverse @args }
$marker
"@

$aliasExists = $false
if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    if ($content -match [regex]::Escape($marker)) {
        $aliasExists = $true
    }
}

if ($aliasExists) {
    # Atualizar bloco existente (caso o path tenha mudado)
    $pattern = "(?s)$([regex]::Escape($marker)).*?$([regex]::Escape($marker))"
    $newBlock = "$marker`nfunction mac { & `"$scriptDir\switch-to-mac.ps1`" @args }`nfunction windows { & `"$scriptDir\switch-to-mac.ps1`" -Reverse @args }`n$marker"
    $content = [regex]::Replace($content, $pattern, $newBlock)
    Set-Content -Path $PROFILE -Value $content.TrimEnd() -Encoding UTF8
    Write-Host "  [OK] Aliases atualizados no PowerShell profile" -ForegroundColor Green
} else {
    Add-Content -Path $PROFILE -Value $block -Encoding UTF8
    Write-Host "  [OK] Aliases registrados no PowerShell profile" -ForegroundColor Green
}

# ── 2. Start Menu shortcuts + hotkeys ──────────────────────────────
$ws = New-Object -ComObject WScript.Shell
$startMenu = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"

# Switch to Mac — Ctrl+Alt+M
$lnk = $ws.CreateShortcut("$startMenu\Switch to Mac.lnk")
$lnk.TargetPath = "$scriptDir\switch-to-mac.bat"
$lnk.WorkingDirectory = $scriptDir
$lnk.WindowStyle = 7  # Minimized
$lnk.Hotkey = "Ctrl+Alt+M"
$lnk.Description = "Troca monitores para o Mac (DDC/CI)"
$lnk.Save()
Write-Host "  [OK] Atalho criado: Ctrl+Alt+M -> Switch to Mac" -ForegroundColor Green

# Switch to Windows — Ctrl+Alt+W
$lnk2 = $ws.CreateShortcut("$startMenu\Switch to Windows.lnk")
$lnk2.TargetPath = "$scriptDir\switch-to-windows.bat"
$lnk2.WorkingDirectory = $scriptDir
$lnk2.WindowStyle = 7  # Minimized
$lnk2.Hotkey = "Ctrl+Alt+W"
$lnk2.Description = "Volta monitores para o Windows (DDC/CI)"
$lnk2.Save()
Write-Host "  [OK] Atalho criado: Ctrl+Alt+W -> Switch to Windows" -ForegroundColor Green

# ── Resumo ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup completo!" -ForegroundColor Green
Write-Host ""
Write-Host "  Hotkeys globais (funcionam de qualquer lugar):" -ForegroundColor Cyan
Write-Host "    Ctrl+Alt+M  -> troca tudo pro Mac" -ForegroundColor White
Write-Host "    Ctrl+Alt+W  -> volta tudo pro Windows" -ForegroundColor White
Write-Host ""
Write-Host "  Terminal (apos reabrir):" -ForegroundColor Cyan
Write-Host "    mac          -> troca tudo pro Mac" -ForegroundColor White
Write-Host "    windows      -> volta tudo pro Windows" -ForegroundColor White
Write-Host ""
Write-Host "  Profile: $PROFILE" -ForegroundColor DarkGray
Write-Host "  Atalhos: $startMenu" -ForegroundColor DarkGray
Write-Host ""
