# switch-to-mac.ps1 — Troca toda a estacao de trabalho para o Mac
# Troca perifericos (HID++ Change Host) + monitores (DDC/CI)
#
# Uso: .\switch-to-mac.ps1          (muda pro Mac)
#      .\switch-to-mac.ps1 -Reverse  (volta pro Windows)

param(
    [switch]$Reverse
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\DDC.psm1" -Force
Import-Module "$scriptDir\lib\HIDSwitch.psm1" -Force

# ── Carregar config ─────────────────────────────────────────────────
$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  config.json nao encontrado! Rode discover.ps1 primeiro." -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$target = if ($Reverse) { "WINDOWS" } else { "MAC" }
$errors = @()

Write-Host ""
Write-Host "  Switching to $target..." -ForegroundColor Cyan
Write-Host ""

# ── 1. Trocar perifericos PRIMEIRO ─────────────────────────────────
if ($config.peripherals -and $config.peripherals.Count -gt 0) {
    Write-Host "  -- Perifericos --" -ForegroundColor DarkGray

    foreach ($periph in $config.peripherals) {
        $channel = if ($Reverse) { $periph.windows_channel } else { $periph.mac_channel }
        $vid = [Convert]::ToUInt16($periph.vid, 16)
        $pid = [Convert]::ToUInt16($periph.pid, 16)
        $featureIndex = [byte]$periph.change_host_feature_index
        $hostIndex = [byte]$channel

        try {
            $ok = [HIDSwitch]::ChangeHost($vid, $pid, $featureIndex, $hostIndex)
            if ($ok) {
                Write-Host "  [OK] $($periph.name) -> canal $($channel + 1)" -ForegroundColor Green
            } else {
                Write-Host "  [X]  $($periph.name) -> FALHOU" -ForegroundColor Red
                $errors += "$($periph.name): falhou ao trocar canal"
            }
        } catch {
            Write-Host "  [X]  $($periph.name) -> ERRO: $_" -ForegroundColor Red
            $errors += "$($periph.name): $_"
        }
    }

    Write-Host ""
    # Delay pra perifericos desconectarem antes de trocar monitores
    Start-Sleep -Milliseconds 300
}

# ── 2. Trocar monitores ────────────────────────────────────────────
Write-Host "  -- Monitores --" -ForegroundColor DarkGray

$monitors = [DDCMonitor]::GetAll()

if ($monitors.Length -eq 0) {
    Write-Host "  Nenhum monitor DDC/CI detectado!" -ForegroundColor Red
    exit 1
}

foreach ($entry in $config.monitors) {
    $inputValue = if ($Reverse) { $entry.windows_input } else { $entry.mac_input }
    $matched = $false

    for ($i = 0; $i -lt $monitors.Length; $i++) {
        if ($monitors[$i].szPhysicalMonitorDescription -match $entry.match_windows) {
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
        $errors += "$($entry.name): nao encontrado (match_windows: '$($entry.match_windows)')"
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
    Write-Host "  Tudo trocado!" -ForegroundColor Green
} else {
    Write-Host "  Problemas encontrados:" -ForegroundColor Yellow
    $errors | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Rode discover.ps1 para verificar" -ForegroundColor DarkGray
}
Write-Host ""
