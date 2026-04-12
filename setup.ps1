# setup.ps1 — Registra aliases 'mac' e 'windows' no PowerShell
# Rode uma vez: .\setup.ps1

$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$marker = "# === switch-station ==="
$block = @"

$marker
function mac { & "$scriptDir\switch-to-mac.ps1" @args }
function windows { & "$scriptDir\switch-to-mac.ps1" -Reverse @args }
$marker
"@

# Verificar se ja existe
if (Test-Path $PROFILE) {
    $content = Get-Content $PROFILE -Raw
    if ($content -match [regex]::Escape($marker)) {
        Write-Host "  Aliases ja estao no profile. Nada a fazer." -ForegroundColor Yellow
        exit 0
    }
}

Add-Content -Path $PROFILE -Value $block -Encoding UTF8

Write-Host ""
Write-Host "  Aliases registrados no PowerShell!" -ForegroundColor Green
Write-Host ""
Write-Host "  Comandos disponiveis (apos reabrir o terminal):" -ForegroundColor Cyan
Write-Host '    mac       -> troca tudo pro Mac' -ForegroundColor White
Write-Host '    windows   -> volta tudo pro Windows' -ForegroundColor White
Write-Host ""
Write-Host "  Profile: $PROFILE" -ForegroundColor DarkGray
Write-Host ""
