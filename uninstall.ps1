<#
.SYNOPSIS
Multi-harness uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
Usage:
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex
  .\uninstall.ps1 [-Target antigravity|claude|cursor|codex|all] [-Scope global|workspace|all]
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "antigravity" }),
    [string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "" }),
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" })
)

$ErrorActionPreference = "Stop"
$Target = $Target.ToLowerInvariant()
$AllTargets = @("antigravity", "claude", "cursor", "codex")

if ($Dest -and $Target -eq "all") { throw "-Dest needs a single -Target, not all" }

function Get-DestinationPreview([string]$harness, [string]$installScope) {
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

function Get-PreviewLabel([string]$harness, [string]$installScope) {
    if ($harness -eq "claude") {
        if ($installScope -eq "workspace") { return "Claude Code project scope ($(Get-Location))" } else { return "Claude Code user scope" }
    }
    if ($harness -eq "all") {
        if ($installScope -eq "workspace") { return "every harness, current folder ($(Get-Location))" } else { return "every harness, this device" }
    }
    return (Get-DestinationPreview -harness $harness -installScope $installScope)
}

# Claude Code loads plugins only from marketplaces, so the claude target uninstalls through the
# `claude plugin` CLI: the plugin, then that scope's marketplace declaration, then the marketplace
# itself once no scope still has pstack installed. It also removes a legacy folder copy.
function Remove-ClaudePlugin([string]$label) {
    $pluginId = "pstack@pstack-rewire"
    $marketplace = "pstack-rewire"
    $claudeScope = if ($label -eq "workspace") { "project" } else { "user" }
    $legacyPath = Get-DestinationPreview -harness "claude" -installScope $label
    if (Test-Path -LiteralPath $legacyPath) {
        Remove-Item -LiteralPath $legacyPath -Recurse -Force
        Write-Host "Removed legacy folder copy at $legacyPath" -ForegroundColor Yellow
    }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "The claude CLI was not found on PATH. In a Claude Code session, run: /plugin uninstall $pluginId, then /plugin marketplace remove $marketplace" -ForegroundColor DarkYellow
        return
    }
    & claude plugin uninstall $pluginId --scope $claudeScope *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Uninstalled pstack (claude, $claudeScope scope)" -ForegroundColor Yellow
    } else {
        Write-Host "pstack (claude, $claudeScope scope) is not installed" -ForegroundColor DarkYellow
    }
    & claude plugin marketplace remove $marketplace --scope $claudeScope *> $null
    $installed = (& claude plugin list 2>$null) -join "`n"
    if ($installed -notmatch [regex]::Escape($pluginId)) {
        & claude plugin marketplace remove $marketplace *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "Removed marketplace $marketplace (no pstack install remains)" -ForegroundColor Yellow }
    }
}

function Remove-Target([string]$harness, [string]$label) {
    if ($harness -eq "claude") {
        Remove-ClaudePlugin -label $label
        return
    }
    $path = Get-DestinationPreview -harness $harness -installScope $label
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Uninstalled pstack ($harness, $label) from $path" -ForegroundColor Yellow
    } else {
        Write-Host "pstack ($harness, $label) not found at $path" -ForegroundColor DarkYellow
    }
}

if ($Dest) {
    if (Test-Path -LiteralPath $Dest) {
        Remove-Item -LiteralPath $Dest -Recurse -Force
        Write-Host "Uninstalled pstack ($Target, custom) from $Dest" -ForegroundColor Yellow
    } else {
        Write-Host "pstack ($Target, custom) not found at $Dest" -ForegroundColor DarkYellow
    }
    exit 0
}

if (-not $Scope) {
    Write-Host ""
    Write-Host "Where would you like to uninstall pstack ($Target) from?" -ForegroundColor Cyan
    Write-Host "  [1] Global    - $(Get-PreviewLabel -harness $Target -installScope 'global') [default]"
    Write-Host "  [2] Workspace - $(Get-PreviewLabel -harness $Target -installScope 'workspace')"
    Write-Host "  [3] Both      - Remove from both Global and Workspace"
    $choice = Read-Host "Select [1/2/3] (press Enter for 1)"
    switch ($choice.Trim().ToLowerInvariant()) {
        "2"         { $Scope = "workspace" }
        "workspace" { $Scope = "workspace" }
        "folder"    { $Scope = "workspace" }
        "3"         { $Scope = "all" }
        "both"      { $Scope = "all" }
        "all"       { $Scope = "all" }
        default     { $Scope = "global" }
    }
} else {
    $Scope = $Scope.ToLowerInvariant()
    if ($Scope -eq "folder") { $Scope = "workspace" }
    if ($Scope -eq "both") { $Scope = "all" }
}

$Labels = switch ($Scope) {
    "all"       { @("global", "workspace") }
    "workspace" { @("workspace") }
    "global"    { @("global") }
    default     { throw "Invalid -Scope '$Scope'. Expected 'global', 'workspace', or 'all'." }
}

$Targets = if ($Target -eq "all") { $AllTargets } else { @($Target) }

foreach ($harness in $Targets) {
    foreach ($label in $Labels) {
        Remove-Target -harness $harness -label $label
    }
}
