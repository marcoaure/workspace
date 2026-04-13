# split-screen.ps1 — Modo dividido: Alienware=Windows, Samsung=Mac
# Troca monitores pra posicao split + perifericos
#
# Uso: .\split-screen.ps1                (split + perifericos pro Windows)
#      .\split-screen.ps1 -Peripherals mac  (split + perifericos pro Mac)

param(
    [ValidateSet("windows","mac")]
    [string]$Peripherals = "windows"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\DDC.psm1" -Force
Import-Module "$scriptDir\lib\HIDSwitch.psm1" -Force

$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  config.json nao encontrado!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "  Split Screen: Alienware=Windows | Samsung=Mac" -ForegroundColor Cyan
Write-Host "  Perifericos -> $($Peripherals.ToUpper())" -ForegroundColor Cyan
Write-Host ""

# ── 1. Monitores — cada um pro seu lado ───────────────────────────
Write-Host "  -- Monitores --" -ForegroundColor DarkGray
$monitors = [DDCMonitor]::GetAll()

foreach ($entry in $config.monitors) {
    # Alienware → Windows, Samsung → Mac
    if ($entry.name -match "Alienware") {
        $inputValue = $entry.windows_input
        $dest = "Windows"
    } else {
        $inputValue = $entry.mac_input
        $dest = "Mac"
    }

    $matched = $false
    for ($i = 0; $i -lt $monitors.Length; $i++) {
        if ($monitors[$i].szPhysicalMonitorDescription -match $entry.match_windows) {
            $ok = [DDCMonitor]::SetVCP($monitors[$i].hPhysicalMonitor, 0x60, [uint32]$inputValue)
            if ($ok) {
                Write-Host "  [OK] $($entry.name) -> $dest (input $inputValue)" -ForegroundColor Green
            } else {
                Write-Host "  [X]  $($entry.name) -> FALHOU" -ForegroundColor Red
            }
            $matched = $true
            break
        }
    }
    if (-not $matched) {
        Write-Host "  [X]  $($entry.name) -> NAO ENCONTRADO" -ForegroundColor Red
    }
}

foreach ($m in $monitors) { [DDCMonitor]::Release($m.hPhysicalMonitor) }

# ── 2. Perifericos ────────────────────────────────────────────────
Write-Host ""
Write-Host "  -- Perifericos --" -ForegroundColor DarkGray
$channelKey = "${Peripherals}_channel"

if ($config.peripherals -and $config.peripherals.Count -gt 0) {
    foreach ($periph in $config.peripherals) {
        $channel = $periph.$channelKey
        $devVid = [Convert]::ToUInt16($periph.vid, 16)
        $devPid = [Convert]::ToUInt16($periph.pid, 16)
        $featureIndex = [byte]$periph.change_host_feature_index
        $hostIndex = [byte]$channel

        try {
            $ok = [HIDSwitch]::ChangeHost($devVid, $devPid, $featureIndex, $hostIndex)
            if ($ok) {
                Write-Host "  [OK] $($periph.name) -> $($Peripherals.ToUpper()) (canal $($channel + 1))" -ForegroundColor Green
            } else {
                Write-Host "  [X]  $($periph.name) -> FALHOU" -ForegroundColor Red
            }
        } catch {
            Write-Host "  [X]  $($periph.name) -> ERRO: $_" -ForegroundColor Red
        }
    }
}

Write-Host ""
