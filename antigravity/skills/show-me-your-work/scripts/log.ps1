<#
.SYNOPSIS
Append a well-formed row to a show-me-your-work decision log (TSV).
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File log.ps1 <logfile> <phase> <decision> <why> <evidence> <result>
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$LogFile,
    [Parameter(Mandatory = $true, Position = 1)][string]$Phase,
    [Parameter(Mandatory = $true, Position = 2)][string]$Decision,
    [Parameter(Mandatory = $true, Position = 3)][string]$Why,
    [Parameter(Mandatory = $true, Position = 4)][string]$Evidence,
    [Parameter(Mandatory = $true, Position = 5)][string]$Result
)

$ErrorActionPreference = "Stop"

$logDir = Split-Path -Parent $LogFile
if ($logDir -and $logDir -ne "." -and -not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath $LogFile) -or (Get-Item -LiteralPath $LogFile).Length -eq 0) {
    [System.IO.File]::AppendAllText($LogFile, "ts`tphase`tdecision`twhy`tevidence`tresult`n", $utf8NoBom)
}

function Clean-Cell([string]$val) {
    $v = $val -replace "[\t\r\n]", " "
    if ($v -match "^[=+\-@]") {
        return "'$v"
    }
    return $v
}

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$row = "{0}`t{1}`t{2}`t{3}`t{4}`t{5}`n" -f `
    $ts, `
    (Clean-Cell $Phase), `
    (Clean-Cell $Decision), `
    (Clean-Cell $Why), `
    (Clean-Cell $Evidence), `
    (Clean-Cell $Result)

[System.IO.File]::AppendAllText($LogFile, $row, $utf8NoBom)
