# switch-peripherals.ps1 — Troca so teclado + mouse (sem mexer nos monitores)
# Uso no modo split-screen (Alienware=Windows, Samsung=Mac)
#
# Uso: .\switch-peripherals.ps1 -Target mac       (perifericos pro canal 3)
#      .\switch-peripherals.ps1 -Target windows    (perifericos pro canal 1)

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("windows","mac","win","1","3")]
    [string]$Target
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\HIDSwitch.psm1" -Force

$configPath = Join-Path $scriptDir "config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "  config.json nao encontrado!" -ForegroundColor Red
    exit 1
}
$config = Get-Content $configPath -Raw | ConvertFrom-Json

# Parse target
$channelKey = switch ($Target) {
    { $_ -in "windows","win","1" } { "windows_channel" }
    { $_ -in "mac","3" }          { "mac_channel" }
}
$label = switch ($Target) {
    { $_ -in "windows","win","1" } { "WINDOWS (canal 1)" }
    { $_ -in "mac","3" }          { "MAC (canal 3)" }
}

if (-not $config.peripherals -or $config.peripherals.Count -eq 0) {
    Write-Host "  Nenhum periferico configurado" -ForegroundColor Red
    exit 1
}

foreach ($periph in $config.peripherals) {
    $channel = $periph.$channelKey
    $devVid = [Convert]::ToUInt16($periph.vid, 16)
    $devPid = [Convert]::ToUInt16($periph.pid, 16)
    $featureIndex = [byte]$periph.change_host_feature_index
    $hostIndex = [byte]$channel

    try {
        $ok = [HIDSwitch]::ChangeHost($devVid, $devPid, $featureIndex, $hostIndex)
        if ($ok) {
            Write-Host "  [OK] $($periph.name) -> $label" -ForegroundColor Green
        } else {
            Write-Host "  [X]  $($periph.name) -> FALHOU" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [X]  $($periph.name) -> ERRO: $_" -ForegroundColor Red
    }
}
