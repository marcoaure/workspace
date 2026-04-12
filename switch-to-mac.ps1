# switch-to-mac.ps1 — Troca toda a estacao de trabalho para o Mac
# Uso: .\switch-to-mac.ps1          (muda pro Mac)
#      .\switch-to-mac.ps1 -Reverse  (volta pro Windows)

param(
    [switch]$Reverse
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\DDC.psm1" -Force

# ── Carregar config ─────────────────────────────────────────────────
$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  config.json nao encontrado! Rode discover.ps1 primeiro." -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# ── Detectar monitores ──────────────────────────────────────────────
$monitors = [DDCMonitor]::GetAll()

if ($monitors.Length -eq 0) {
    Write-Host "  Nenhum monitor DDC/CI detectado!" -ForegroundColor Red
    exit 1
}

$target = if ($Reverse) { "WINDOWS" } else { "MAC" }
$errors = @()

Write-Host ""
Write-Host "  Switching to $target..." -ForegroundColor Cyan
Write-Host ""

# ── Trocar inputs ───────────────────────────────────────────────────
foreach ($entry in $config.monitors) {
    $inputValue = if ($Reverse) { $entry.windows_input } else { $entry.mac_input }
    $matched = $false

    for ($i = 0; $i -lt $monitors.Length; $i++) {
        if ($monitors[$i].szPhysicalMonitorDescription -match $entry.match) {
            $ok = [DDCMonitor]::SetVCP(
                $monitors[$i].hPhysicalMonitor,
                0x60,
                [uint32]$inputValue
            )
            if ($ok) {
                Write-Host "  [OK] $($entry.name) -> input $inputValue" -ForegroundColor Green
            } else {
                $errors += "$($entry.name): falhou ao trocar input"
                Write-Host "  [X]  $($entry.name) -> FALHOU" -ForegroundColor Red
            }
            $matched = $true
            break
        }
    }

    if (-not $matched) {
        $errors += "$($entry.name): nao encontrado (match: '$($entry.match)')"
        Write-Host "  [X]  $($entry.name) -> NAO ENCONTRADO" -ForegroundColor Red
    }
}

# ── Cleanup ─────────────────────────────────────────────────────────
foreach ($m in $monitors) {
    [DDCMonitor]::Release($m.hPhysicalMonitor)
}

# ── Resultado ───────────────────────────────────────────────────────
Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "  Monitores trocados!" -ForegroundColor Green
    if (-not $Reverse) {
        Write-Host "  Agora pressione Easy Switch no mouse e teclado (canal 2)." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Problemas encontrados:" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Rode discover.ps1 para verificar os nomes dos monitores" -ForegroundColor DarkGray
    Write-Host "  e ajuste o campo 'match' no config.json." -ForegroundColor DarkGray
}
Write-Host ""
