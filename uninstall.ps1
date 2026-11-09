<#
.SYNOPSIS
pstack-rewire uninstaller. Kept for existing one-liners; it runs install.ps1 -Uninstall.
With no -Target it lists the agents pstack is installed for and, when there are several, asks which to remove.
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/uninstall.ps1 | iex
  .\uninstall.ps1 [-Target claude,codex|all] [-Scope global|workspace|all]
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "" }),
    [string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "" }),
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" }),
    [switch]$Yes
)

$ErrorActionPreference = "Stop"
$forward = @{ Uninstall = $true }
if ($Target) { $forward.Target = $Target }
if ($Scope) { $forward.Scope = $Scope }
if ($Dest) { $forward.Dest = $Dest }
if ($Yes) { $forward.Yes = $true }

$local = if ($PSScriptRoot) { Join-Path $PSScriptRoot "install.ps1" } else { $null }
if ($local -and (Test-Path -LiteralPath $local)) {
    & $local @forward
    exit $LASTEXITCODE
}
$branch = if ($env:PSTACK_BRANCH) { $env:PSTACK_BRANCH } else { "main" }
$env:PSTACK_ACTION = "uninstall"
if ($Target) { $env:PSTACK_TARGET = $Target }
if ($Scope) { $env:PSTACK_SCOPE = $Scope }
if ($Dest) { $env:PSTACK_DEST = $Dest }
if ($Yes) { $env:PSTACK_YES = "1" }
Invoke-Expression (Invoke-RestMethod -Uri "https://raw.githubusercontent.com/matthew110703/pstack-rewire/$branch/install.ps1")
