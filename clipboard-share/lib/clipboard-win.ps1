# clipboard-win.ps1 — Inject text or file into Windows clipboard
# Usage: powershell -File clipboard-win.ps1 -Type text -Content "hello"
#        powershell -File clipboard-win.ps1 -Type file -Content "C:\path\to\file"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("text","file")]
    [string]$Type,

    [Parameter(Mandatory=$true)]
    [string]$Content
)

switch ($Type) {
    "text" {
        Set-Clipboard -Value $Content
        Write-Host "Clipboard set: text ($($Content.Length) chars)"
    }
    "file" {
        if (-not (Test-Path $Content)) {
            Write-Error "File not found: $Content"
            exit 1
        }
        Set-Clipboard -Path $Content
        Write-Host "Clipboard set: file ($Content)"
    }
}
