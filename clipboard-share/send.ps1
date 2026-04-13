# send.ps1 — Read Windows clipboard and POST to remote machine

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$remoteHost = $config.remote_host
$port = if ($config.port) { $config.port } else { 9876 }
$url = "http://${remoteHost}:${port}/clip"

# Check if clipboard has files
$files = Get-Clipboard -Format FileDropList -ErrorAction SilentlyContinue

if ($files -and $files.Count -gt 0) {
    # Send first file
    $filePath = $files[0].FullName
    $fileName = $files[0].Name

    try {
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"

        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
            "Content-Type: application/octet-stream",
            "",
            ""
        )
        $bodyEnd = "$LF--$boundary--$LF"

        $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($bodyLines -join $LF))
        $endBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyEnd)

        $body = New-Object byte[] ($headerBytes.Length + $fileBytes.Length + $endBytes.Length)
        [System.Buffer]::BlockCopy($headerBytes, 0, $body, 0, $headerBytes.Length)
        [System.Buffer]::BlockCopy($fileBytes, 0, $body, $headerBytes.Length, $fileBytes.Length)
        [System.Buffer]::BlockCopy($endBytes, 0, $body, $headerBytes.Length + $fileBytes.Length, $endBytes.Length)

        $response = Invoke-WebRequest -Uri $url -Method POST -Body $body `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -TimeoutSec 10 -ErrorAction Stop

        Write-Host "[OK] Arquivo enviado: $fileName"
    } catch {
        Write-Host "[X] Falha ao enviar arquivo: $_" -ForegroundColor Red
    }
} else {
    # Send text
    $text = Get-Clipboard -Format Text -ErrorAction SilentlyContinue
    if (-not $text) {
        Write-Host 'Clipboard vazio'
        exit 0
    }

    $textJoined = if ($text -is [array]) { $text -join "`n" } else { $text }

    try {
        $jsonBody = @{ type = 'text'; data = $textJoined } | ConvertTo-Json -Compress
        $response = Invoke-WebRequest -Uri $url -Method POST -Body $jsonBody `
            -ContentType 'application/json; charset=utf-8' `
            -TimeoutSec 10 -ErrorAction Stop

        Write-Host "[OK] Texto enviado ($($textJoined.Length) chars)"
    } catch {
        Write-Host "[X] Falha ao enviar. Outro PC ligado?" -ForegroundColor Red
    }
}
