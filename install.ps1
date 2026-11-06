<#
.SYNOPSIS
Multi-harness zero-clone installer & uninstaller for pstack-rewire (https://github.com/matthew110703/pstack-rewire).
Supports both local execution (.\install.ps1) and remote one-liner execution:
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
Prompts interactively for Install/Uninstall and Global/Workspace scope unless flags or env vars are provided.
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "antigravity" }),
    [string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "" }),
    [string]$Action = $(if ($env:PSTACK_ACTION) { $env:PSTACK_ACTION } else { "" }),
    [switch]$Uninstall,
    [switch]$Update,
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" }),
    [string]$Branch = $(if ($env:PSTACK_BRANCH) { $env:PSTACK_BRANCH } else { "main" })
)

$ErrorActionPreference = "Stop"
$RepoSlug = "matthew110703/pstack-rewire"
$Target = $Target.ToLowerInvariant()
if ($Uninstall) { $Action = "uninstall" }
if ($Update) { $Action = "install" }

function Get-DestinationPreview([string]$harness, [string]$installScope) {
    if ($installScope -eq "workspace") {
        switch ($harness) {
            "antigravity" { return (Join-Path (Get-Location) ".agents\plugins\pstack") }
            "claude"      { return "Claude Code project scope ($(Get-Location))" }
            "cursor"      { return (Join-Path (Get-Location) ".cursor\plugins\pstack") }
            "codex"       { return (Join-Path (Get-Location) ".codex\plugins\pstack") }
            default       { return (Join-Path (Get-Location) ".$harness\plugins\pstack") }
        }
    }
    switch ($harness) {
        "antigravity" { return (Join-Path $HOME ".gemini\config\plugins\pstack") }
        "claude"      { return "Claude Code user scope" }
        "cursor"      { return (Join-Path $HOME ".cursor\plugins\pstack") }
        "codex"       { return (Join-Path $HOME ".codex\plugins\pstack") }
        default       { return (Join-Path $HOME ".$harness\plugins\pstack") }
    }
}

if (-not $Dest -and -not $Scope) {
    $globalPreview = Get-DestinationPreview -harness $Target -installScope "global"
    $workspacePreview = Get-DestinationPreview -harness $Target -installScope "workspace"
    Write-Host ""
    Write-Host "pstack ($Target) Setup:" -ForegroundColor Cyan
    Write-Host "  [1] Install / Update Global    - All projects on this device ($globalPreview) [default]"
    Write-Host "  [2] Install / Update Workspace - Current folder only ($workspacePreview)"
    Write-Host "  [3] Uninstall Global           - Remove from $globalPreview"
    Write-Host "  [4] Uninstall Workspace        - Remove from $workspacePreview"
    $choice = Read-Host "Select [1-4] (press Enter for 1)"
    switch ($choice.Trim().ToLowerInvariant()) {
        "2"         { $Action = "install";   $Scope = "workspace" }
        "workspace" { $Action = "install";   $Scope = "workspace" }
        "folder"    { $Action = "install";   $Scope = "workspace" }
        "w"         { $Action = "install";   $Scope = "workspace" }
        "3"         { $Action = "uninstall"; $Scope = "global" }
        "4"         { $Action = "uninstall"; $Scope = "workspace" }
        "u"         { $Action = "uninstall"; $Scope = "global" }
        "uninstall" { $Action = "uninstall"; $Scope = "global" }
        default     { if (-not $Action) { $Action = "install" }; $Scope = "global" }
    }
} else {
    if (-not $Action) { $Action = "install" }
    $Action = $Action.ToLowerInvariant()
    if ($Action -in @("remove", "delete", "rm")) { $Action = "uninstall" }
    if ($Action -in @("update", "upgrade")) { $Action = "install" }
    if (-not $Scope) { $Scope = "global" }
    $Scope = $Scope.ToLowerInvariant()
    if ($Scope -eq "folder") { $Scope = "workspace" }
    if ($Scope -notin @("global", "workspace")) {
        throw "Invalid -Scope '$Scope'. Expected 'global' or 'workspace'."
    }
}

# Claude Code loads plugins only from marketplaces, so the claude target installs
# through the `claude plugin` CLI instead of copying files.
if ($Target -eq "claude" -and -not $Dest) {
    $Marketplace = "pstack-rewire"
    $PluginId = "pstack@$Marketplace"
    $ClaudeScope = if ($Scope -eq "workspace") { "project" } else { "user" }
    $LegacyDir = if ($Scope -eq "workspace") { Join-Path (Get-Location) ".claude\plugins\pstack" } else { Join-Path $HOME ".claude\plugins\pstack" }
    if (Test-Path -LiteralPath $LegacyDir) {
        Remove-Item -LiteralPath $LegacyDir -Recurse -Force
        Write-Host "Removed legacy folder copy at $LegacyDir" -ForegroundColor Yellow
    }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
        Write-Host "The claude CLI was not found on PATH. In a Claude Code session, run:" -ForegroundColor DarkYellow
        if ($Action -eq "uninstall") {
            Write-Host "  /plugin uninstall $PluginId"
            Write-Host "  /plugin marketplace remove $Marketplace"
        } else {
            Write-Host "  /plugin marketplace add $RepoSlug"
            Write-Host "  /plugin install $PluginId"
        }
        exit 0
    }
    if ($Action -eq "uninstall") {
        & claude plugin uninstall $PluginId --scope $ClaudeScope *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Uninstalled pstack (claude, $ClaudeScope scope)" -ForegroundColor Yellow
        } else {
            Write-Host "pstack (claude, $ClaudeScope scope) is not installed" -ForegroundColor DarkYellow
        }
        # Drop this scope's marketplace declaration, and the marketplace itself once no scope still has pstack.
        & claude plugin marketplace remove $Marketplace --scope $ClaudeScope *> $null
        $remaining = (& claude plugin list 2>$null) -join "`n"
        if ($remaining -notmatch [regex]::Escape($PluginId)) {
            & claude plugin marketplace remove $Marketplace *> $null
            if ($LASTEXITCODE -eq 0) { Write-Host "Removed marketplace $Marketplace (no pstack install remains)" -ForegroundColor Yellow }
        }
        exit 0
    }
    $Source = $RepoSlug
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".claude-plugin\marketplace.json")) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "claude"))) {
        $Source = $PSScriptRoot
    }
    # `marketplace add` is idempotent and records the declaration in the chosen scope's settings.
    & claude plugin marketplace add $Source --scope $ClaudeScope
    if ($LASTEXITCODE -ne 0) { throw "claude plugin marketplace add failed" }
    & claude plugin marketplace update $Marketplace
    # `plugin install` is idempotent and records enabledPlugins in the chosen scope; `update` then pulls a newer version.
    & claude plugin install $PluginId --scope $ClaudeScope
    if ($LASTEXITCODE -ne 0) { throw "claude plugin install failed" }
    & claude plugin update $PluginId --scope $ClaudeScope
    Write-Host "Installed or updated pstack (claude, $ClaudeScope scope) from $Source. Restart Claude Code or run /reload-plugins, then run /pstack:poteto-help." -ForegroundColor Green
    exit 0
}

$TargetDir = if ($Dest) { $Dest } else { Get-DestinationPreview -harness $Target -installScope $Scope }

if ($Action -eq "uninstall") {
    if (Test-Path -LiteralPath $TargetDir) {
        Remove-Item -LiteralPath $TargetDir -Recurse -Force
        Write-Host "Uninstalled pstack ($Target, $Scope) from $TargetDir" -ForegroundColor Yellow
    } else {
        Write-Host "pstack ($Target, $Scope) is not installed at $TargetDir" -ForegroundColor DarkYellow
    }
    exit 0
}

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
