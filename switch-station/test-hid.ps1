# test-hid.ps1 — Testa HID++ Change Host no Windows
# Rode: powershell -ExecutionPolicy Bypass -File .\test-hid.ps1

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  === Teste HID++ Change Host ===" -ForegroundColor Cyan
Write-Host ""

# 1. Carregar modulo
Write-Host "  1. Carregando HIDSwitch.psm1..." -ForegroundColor Yellow
try {
    Import-Module "$scriptDir\lib\HIDSwitch.psm1" -Force
    Write-Host "     [OK] Modulo carregado" -ForegroundColor Green
} catch {
    Write-Host "     [X] ERRO ao carregar: $_" -ForegroundColor Red
    exit 1
}

# 2. Testar MX Keys -> canal 3 (Mac = index 2)
Write-Host ""
Write-Host "  2. Testando MX Keys (046D:B35B) -> canal 3 (Mac)..." -ForegroundColor Yellow
try {
    $result = [HIDSwitch]::ChangeHost(0x046D, 0xB35B, 0x09, 0x02)
    if ($result) {
        Write-Host "     [OK] MX Keys trocou pro canal 3!" -ForegroundColor Green
    } else {
        Write-Host "     [X] ChangeHost retornou false (device nao encontrado ou write falhou)" -ForegroundColor Red
    }
} catch {
    Write-Host "     [X] ERRO: $_" -ForegroundColor Red
}

# 3. Testar MX Anywhere 3S -> canal 3 (Mac = index 2)
Write-Host ""
Write-Host "  3. Testando MX Anywhere 3S (046D:B037) -> canal 3 (Mac)..." -ForegroundColor Yellow
try {
    $result = [HIDSwitch]::ChangeHost(0x046D, 0xB037, 0x0B, 0x02)
    if ($result) {
        Write-Host "     [OK] MX Anywhere 3S trocou pro canal 3!" -ForegroundColor Green
    } else {
        Write-Host "     [X] ChangeHost retornou false (device nao encontrado ou write falhou)" -ForegroundColor Red
    }
} catch {
    Write-Host "     [X] ERRO: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "  === Fim do teste ===" -ForegroundColor Cyan
Write-Host ""
