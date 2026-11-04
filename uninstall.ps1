<#
.SYNOPSIS
Multi-harness uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
Usage:
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex
  .\uninstall.ps1 [-Target antigravity] [-Scope global|workspace|all]
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "antigravity" }),
    [string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "" }),
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" })
)

$ErrorActionPreference = "Stop"
$Target = $Target.ToLowerInvariant()

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

function Remove-PluginDir([string]$path, [string]$label) {
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Recurse -Force
        Write-Host "Uninstalled pstack ($Target, $label) from $path" -ForegroundColor Yellow
    } else {
        Write-Host "pstack ($Target, $label) not found at $path" -ForegroundColor DarkYellow
    }
}

if ($Dest) {
    Remove-PluginDir -path $Dest -label "custom"
    exit 0
}

$globalPreview = Get-DestinationPreview -harness $Target -installScope "global"
$workspacePreview = Get-DestinationPreview -harness $Target -installScope "workspace"

if (-not $Scope) {
    Write-Host ""
    Write-Host "Where would you like to uninstall pstack ($Target) from?" -ForegroundColor Cyan
    Write-Host "  [1] Global    - $globalPreview [default]"
    Write-Host "  [2] Workspace - $workspacePreview"
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

if ($Scope -eq "all") {
    Remove-PluginDir -path $globalPreview -label "global"
    Remove-PluginDir -path $workspacePreview -label "workspace"
} elseif ($Scope -eq "workspace") {
    Remove-PluginDir -path $workspacePreview -label "workspace"
} else {
    Remove-PluginDir -path $globalPreview -label "global"
}
