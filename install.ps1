<#
.SYNOPSIS
Multi-harness zero-clone installer for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
Supports both local execution (.\install.ps1) and remote one-liner execution:
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
Configure target/scope remotely via $env:PSTACK_TARGET, $env:PSTACK_SCOPE, $env:PSTACK_DEST, $env:PSTACK_BRANCH.
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "antigravity" }),
    [ValidateSet("global", "workspace")][string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "global" }),
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" }),
    [string]$Branch = $(if ($env:PSTACK_BRANCH) { $env:PSTACK_BRANCH } else { "main" })
)

$ErrorActionPreference = "Stop"
$RepoSlug = "matthew110703/pstack-rewire"
$Target = $Target.ToLowerInvariant()

function Resolve-TargetDestination([string]$harness, [string]$installScope, [string]$customDest) {
    if ($customDest) { return $customDest }
    if ($installScope -eq "workspace") {
        switch ($harness) {
            "antigravity" { return (Join-Path (Get-Location) ".agents\plugins\pstack") }
            "claude"      { return (Join-Path (Get-Location) ".claude\plugins\pstack") }
            "cursor"      { return (Join-Path (Get-Location) ".cursor\plugins\pstack") }
            "codex"       { return (Join-Path (Get-Location) ".codex\plugins\pstack") }
            default       { return (Join-Path (Get-Location) ".$harness\plugins\pstack") }
        }
    }
    switch ($harness) {
        "antigravity" { return (Join-Path $HOME ".gemini\config\plugins\pstack") }
        "claude"      { return (Join-Path $HOME ".claude\plugins\pstack") }
        "cursor"      { return (Join-Path $HOME ".cursor\plugins\pstack") }
        "codex"       { return (Join-Path $HOME ".codex\plugins\pstack") }
        default       { return (Join-Path $HOME ".$harness\plugins\pstack") }
    }
}

$TargetDir = Resolve-TargetDestination -harness $Target -installScope $Scope -customDest $Dest
New-Item -ItemType Directory -Path (Split-Path -Parent $TargetDir) -Force | Out-Null

$LocalSource = if ($PSScriptRoot) { Join-Path $PSScriptRoot $Target } else { $null }
if ($LocalSource -and (Test-Path -LiteralPath $LocalSource)) {
    if (Test-Path -LiteralPath $TargetDir) {
        Remove-Item -LiteralPath $TargetDir -Recurse -Force
    }
    Copy-Item -LiteralPath $LocalSource -Destination $TargetDir -Recurse -Force
    Write-Host "Installed pstack ($Target, $Scope, local checkout) -> $TargetDir" -ForegroundColor Green
} else {
    $ZipUrl = "https://github.com/$RepoSlug/archive/refs/heads/$Branch.zip"
    $TmpZip = Join-Path $env:TEMP "pstack-rewire-$([guid]::NewGuid().ToString('N')).zip"
    $TmpExt = Join-Path $env:TEMP "pstack-rewire-$([guid]::NewGuid().ToString('N'))"
    try {
        Write-Host "Downloading pstack ($Target) from GitHub ($RepoSlug@$Branch)..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $ZipUrl -OutFile $TmpZip -UseBasicParsing
        Expand-Archive -LiteralPath $TmpZip -DestinationPath $TmpExt -Force
        $RootFolder = Get-ChildItem -LiteralPath $TmpExt -Directory | Select-Object -First 1
        $ExtractedHarness = Join-Path $RootFolder.FullName $Target
        if (-not (Test-Path -LiteralPath $ExtractedHarness)) {
            $Available = (Get-ChildItem -LiteralPath $RootFolder.FullName -Directory | Select-Object -ExpandProperty Name) -join ", "
            throw "Harness '$Target' not found in $RepoSlug. Available harnesses: $Available"
        }
        if (Test-Path -LiteralPath $TargetDir) {
            Remove-Item -LiteralPath $TargetDir -Recurse -Force
        }
        Copy-Item -LiteralPath $ExtractedHarness -Destination $TargetDir -Recurse -Force
        Write-Host "Installed pstack ($Target, $Scope) -> $TargetDir" -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $TmpZip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $TmpExt -Recurse -Force -ErrorAction SilentlyContinue
    }
}
