# discover.ps1 — Descobre monitores e valores de input DDC/CI
# Execute este script para identificar os valores corretos pro config.json

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module "$scriptDir\lib\DDC.psm1" -Force

$monitors = [DDCMonitor]::GetAll()

Write-Host ""
Write-Host "  MONITORES DETECTADOS (DDC/CI)" -ForegroundColor Cyan
Write-Host "  =============================" -ForegroundColor Cyan
Write-Host ""

if ($monitors.Length -eq 0) {
    Write-Host "  Nenhum monitor detectado!" -ForegroundColor Red
    Write-Host "  Verifique se os monitores suportam DDC/CI e se esta ativo no OSD." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

for ($i = 0; $i -lt $monitors.Length; $i++) {
    $m = $monitors[$i]
    $input = [DDCMonitor]::GetInput($m.hPhysicalMonitor)

    Write-Host "  Monitor $i" -ForegroundColor Yellow
    Write-Host "    Descricao : $($m.szPhysicalMonitorDescription)"
    Write-Host "    Input atual: $input  (VCP 0x60 = $('0x{0:X2}' -f $input))"
    Write-Host ""
}

# Cleanup
foreach ($m in $monitors) {
    [DDCMonitor]::Release($m.hPhysicalMonitor)
}

Write-Host "  ============================================" -ForegroundColor DarkGray
Write-Host "  COMO DESCOBRIR OS VALORES CORRETOS:" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  1. Rode este script com os monitores no WINDOWS" -ForegroundColor DarkGray
Write-Host "     e anote os valores de input (ex: 15, 15)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Troque MANUALMENTE ambos monitores pro MAC" -ForegroundColor DarkGray
Write-Host "     (pelo menu OSD de cada monitor)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  3. Troque de volta pro WINDOWS e rode novamente" -ForegroundColor DarkGray
Write-Host "     para ver os valores do Mac (seriam os últimos)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  4. Edite config.json com os valores encontrados" -ForegroundColor DarkGray
Write-Host "  ============================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Valores comuns de input (VCP 0x60):" -ForegroundColor DarkGray
Write-Host "    15 (0x0F) = DisplayPort-1" -ForegroundColor DarkGray
Write-Host "    16 (0x10) = DisplayPort-2 / USB-C" -ForegroundColor DarkGray
Write-Host "    17 (0x11) = HDMI-1" -ForegroundColor DarkGray
Write-Host "    18 (0x12) = HDMI-2" -ForegroundColor DarkGray
Write-Host "    11 (0x0B) = HDMI-1 (alt)" -ForegroundColor DarkGray
Write-Host "    12 (0x0C) = HDMI-2 (alt)" -ForegroundColor DarkGray
Write-Host ""
