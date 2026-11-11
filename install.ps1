<#
.SYNOPSIS
pstack-rewire installer, updater, and uninstaller for every supported agent
(https://github.com/matthew110703/pstack-rewire).

With no -Target it detects the agents on this machine and asks which to use:
  irm https://raw.githubusercontent.com/matthew110703/pstack-rewire/main/install.ps1 | iex
  .\install.ps1 -Target claude,codex -Scope global
  .\install.ps1 -Uninstall
  .\install.ps1 -List
#>
param(
    [string]$Target = $(if ($env:PSTACK_TARGET) { $env:PSTACK_TARGET } else { "" }),
    [string]$Scope = $(if ($env:PSTACK_SCOPE) { $env:PSTACK_SCOPE } else { "" }),
    [string]$Action = $(if ($env:PSTACK_ACTION) { $env:PSTACK_ACTION } else { "" }),
    [switch]$Uninstall,
    [switch]$Update,
    [switch]$Force,
    [switch]$Yes,
    [switch]$List,
    [string]$Dest = $(if ($env:PSTACK_DEST) { $env:PSTACK_DEST } else { "" }),
    [string]$Branch = $(if ($env:PSTACK_BRANCH) { $env:PSTACK_BRANCH } else { "main" })
)

$ErrorActionPreference = "Stop"
$RepoSlug = "matthew110703/pstack-rewire"
$Harnesses = @("claude", "codex", "antigravity", "cursor", "default")
if ($Uninstall) { $Action = "uninstall" }
if ($Update) { $Action = "install" }
if ($env:PSTACK_FORCE) { $Force = $true }
if ($env:PSTACK_YES) { $Yes = $true }
$Action = $Action.ToLowerInvariant()
if ($Action -in @("remove", "delete", "rm")) { $Action = "uninstall" }
if ($Action -in @("update", "upgrade")) { $Action = "install" }
$Scope = $Scope.ToLowerInvariant()
if ($Scope -eq "folder") { $Scope = "workspace" }
if ($Scope -eq "both") { $Scope = "all" }
$Ws = (Get-Location).Path

function Test-Interactive { return (-not $Yes) -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected }
function Test-OnPath([string]$name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# ---------------------------------------------------------------------------
# Harness registry: label, detection, and install status.
# ---------------------------------------------------------------------------
function Get-Label([string]$h) {
    switch ($h) {
        "claude"      { "Claude Code" }
        "codex"       { "OpenAI Codex" }
        "antigravity" { "Google Antigravity" }
        "cursor"      { "Cursor" }
        "default"     { "Other agents via .agents/skills" }
    }
}

function Get-Evidence([string]$h) {
    $found = @()
    switch ($h) {
        "claude" { if (Test-OnPath claude) { $found += "claude" }; if (Test-Path (Join-Path $HOME ".claude")) { $found += "~/.claude" } }
        "codex"  { if (Test-OnPath codex) { $found += "codex" }; if (Test-Path (Join-Path $HOME ".codex")) { $found += "~/.codex" } }
        "antigravity" {
            foreach ($c in @("agy", "antigravity")) { if (Test-OnPath $c) { $found += $c } }
            if (Test-Path (Join-Path $HOME ".gemini\antigravity")) { $found += "~/.gemini/antigravity" }
            if ($env:LOCALAPPDATA -and (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\Antigravity"))) { $found += "Antigravity app" }
        }
        "cursor" {
            if (Test-OnPath cursor) { $found += "cursor" }
            if (Test-Path (Join-Path $HOME ".cursor")) { $found += "~/.cursor" }
            if ($env:LOCALAPPDATA -and (Test-Path (Join-Path $env:LOCALAPPDATA "Programs\cursor"))) { $found += "Cursor app" }
        }
        "default" {
            foreach ($c in @("gemini", "opencode", "copilot", "amp", "goose", "droid", "junie", "kiro")) { if (Test-OnPath $c) { $found += $c } }
            if (Test-Path (Join-Path $HOME ".agents\skills")) { $found += "~/.agents/skills" }
        }
    }
    return ($found -join ", ")
}

function Get-FolderDest([string]$h, [string]$sc) {
    if ($sc -eq "workspace") {
        switch ($h) { "antigravity" { return (Join-Path $Ws ".agents\plugins\pstack") } "cursor" { return (Join-Path $Ws ".cursor\plugins\pstack") } default { return (Join-Path $Ws ".$h\plugins\pstack") } }
    }
    switch ($h) { "antigravity" { return (Join-Path $HOME ".gemini\config\plugins\pstack") } "cursor" { return (Join-Path $HOME ".cursor\plugins\pstack") } default { return (Join-Path $HOME ".$h\plugins\pstack") } }
}

function Test-InstalledAt([string]$h, [string]$sc) {
    switch ($h) {
        "claude" {
            if ($sc -eq "workspace") {
                if (Test-Path (Join-Path $Ws ".claude\plugins\pstack")) { return $true }
                $s = Join-Path $Ws ".claude\settings.json"
                return ((Test-Path $s) -and ((Get-Content -Raw $s) -match "pstack@pstack-rewire"))
            }
            if (Test-Path (Join-Path $HOME ".claude\plugins\pstack")) { return $true }
            if (Test-OnPath claude) { return (((& claude plugin list 2>$null) -join "`n") -match "pstack@pstack-rewire\s*\n\s*Version:.*\n\s*Scope: user") }
            return $false
        }
        "codex" {
            if ($sc -eq "workspace") { return (Test-Path (Join-Path $Ws ".agents\.pstack-manifest-codex")) }
            return ((Test-Path (Join-Path $HOME ".codex\plugins\cache\pstack-rewire-codex\pstack")) -or (Test-Path (Join-Path $HOME ".codex\plugins\pstack")))
        }
        "default" {
            $base = if ($sc -eq "workspace") { $Ws } else { $HOME }
            return (Test-Path (Join-Path $base ".agents\.pstack-manifest-default"))
        }
        default { return (Test-Path (Get-FolderDest $h $sc)) }
    }
}

function Get-WhereInstalled([string]$h) {
    $w = @()
    if (Test-InstalledAt $h "global") { $w += "global" }
    if (Test-InstalledAt $h "workspace") { $w += "workspace" }
    return ($w -join " + ")
}

if ($List) {
    "{0,-4} {1,-44} {2,-20} {3}" -f "", "agent", "pstack", "detected via"
    $i = 0
    foreach ($h in $Harnesses) {
        $i++
        $ev = Get-Evidence $h; $inst = Get-WhereInstalled $h
        "{0,-4} {1,-44} {2,-20} {3}" -f $i, "$(Get-Label $h) ($h)", $(if ($inst) { $inst } else { "-" }), $(if ($ev) { $ev } else { "not found" })
    }
    exit 0
}

# ---------------------------------------------------------------------------
# Choose the action, the agents, and the scope.
# ---------------------------------------------------------------------------
if (-not $Action) {
    $Action = "install"
    if (-not $Target -and -not $Dest -and (Test-Interactive)) {
        $reply = Read-Host "`npstack: [1] Install / update  [2] Uninstall  (Enter = 1)"
        switch ($reply.Trim().ToLowerInvariant()) { { $_ -in @("2", "u", "uninstall", "remove") } { $Action = "uninstall" } { $_ -in @("q", "quit") } { exit 0 } }
    }
}

$Selected = @()
if ($Target) {
    if ($Target.ToLowerInvariant() -eq "all") { $Selected = $Harnesses }
    else {
        foreach ($h in ($Target.ToLowerInvariant() -split "[,\s]+" | Where-Object { $_ })) {
            if ($Harnesses -notcontains $h) { throw "Unknown target '$h'. Valid targets: $($Harnesses -join ', '), all" }
            if ($Selected -notcontains $h) { $Selected += $h }
        }
    }
} else {
    $candidates = @(); $checked = @()
    foreach ($h in $Harnesses) {
        if ($Action -eq "uninstall") {
            if (-not (Get-WhereInstalled $h)) { continue }
            $candidates += $h; $checked += $h
        } else {
            $candidates += $h
            if (Get-Evidence $h) { $checked += $h }
        }
    }
    if ($Action -eq "uninstall" -and $candidates.Count -eq 0) { Write-Host "pstack is not installed for any agent (global or in $Ws)."; exit 0 }
    if ($Action -eq "install" -and $checked.Count -eq 0 -and -not (Test-Interactive)) {
        Write-Host "No supported agent was detected. Pick one explicitly, for example: .\install.ps1 -Target claude" -ForegroundColor DarkYellow
        exit 0
    }
    if ($Action -eq "uninstall" -and $candidates.Count -eq 1) {
        $Selected = $candidates
    } elseif (Test-Interactive) {
        Write-Host ""
        if ($Action -eq "uninstall") { Write-Host "pstack is installed for these agents (all checked):" -ForegroundColor Cyan }
        else { Write-Host "pstack: choose agents (detected ones are checked)" -ForegroundColor Cyan }
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            $h = $candidates[$i]
            $mark = if ($checked -contains $h) { "x" } else { " " }
            $info = if ($Action -eq "uninstall") { Get-WhereInstalled $h } else { $e = Get-Evidence $h; if ($e) { $e } else { "not found" } }
            Write-Host ("  [{0}] {1,-2} {2,-34} {3}" -f $mark, ($i + 1), (Get-Label $h), $info)
        }
        $reply = (Read-Host 'Enter = checked ones, or type numbers (e.g. 1,3), "a" = all, "q" = quit').Trim().ToLowerInvariant() -replace "\s", ""
        if ($reply -in @("q", "quit")) { Write-Host "Nothing changed."; exit 0 }
        elseif ($reply -eq "") { $Selected = $checked }
        elseif ($reply -in @("a", "all")) { $Selected = $candidates }
        else {
            foreach ($n in ($reply -split ",")) {
                $k = 0
                if (-not [int]::TryParse($n, [ref]$k) -or $k -lt 1 -or $k -gt $candidates.Count) { throw "'$n' is not a number from the list" }
                if ($Selected -notcontains $candidates[$k - 1]) { $Selected += $candidates[$k - 1] }
            }
        }
    } else {
        $Selected = $checked
        if ($Action -eq "uninstall") { Write-Host "pstack: uninstalling from every agent it is installed for: $($Selected -join ' ')" }
        else { Write-Host "pstack: installing for detected agents: $($Selected -join ' ')" }
    }
    if ($Selected.Count -eq 0) { Write-Host "No agents selected. Nothing changed."; exit 0 }
}

if ($Dest -and $Selected.Count -ne 1) { throw "-Dest needs exactly one -Target" }

if (-not $Scope -and -not $Dest) {
    if (Test-Interactive) {
        if ($Action -eq "uninstall") {
            $reply = Read-Host "Remove from: [1] Global  [2] This folder ($Ws)  [3] Both  (Enter = 3)"
            switch ($reply.Trim().ToLowerInvariant()) { { $_ -in @("1", "global", "g") } { $Scope = "global" } { $_ -in @("2", "workspace", "folder", "w") } { $Scope = "workspace" } default { $Scope = "all" } }
        } else {
            $reply = Read-Host "Install for: [1] All projects on this device (global)  [2] This folder only ($Ws)  (Enter = 1)"
            switch ($reply.Trim().ToLowerInvariant()) { { $_ -in @("2", "workspace", "folder", "w") } { $Scope = "workspace" } default { $Scope = "global" } }
        }
    } elseif ($Action -eq "uninstall") { $Scope = "all" } else { $Scope = "global" }
}
if (-not $Scope) { $Scope = "global" }
if ($Scope -eq "all" -and $Action -ne "uninstall") { throw "-Scope all only applies to -Uninstall" }
if ($Scope -notin @("global", "workspace", "all")) { throw "Invalid -Scope '$Scope'. Expected 'global' or 'workspace' (or 'all' for -Uninstall)." }

# ---------------------------------------------------------------------------
# Shared helpers.
# ---------------------------------------------------------------------------
$script:RepoRoot = $null
$script:TempDirs = @()

function Resolve-RepoRoot([string[]]$need) {
    if ($PSScriptRoot -and -not ($need | Where-Object { -not (Test-Path (Join-Path $PSScriptRoot $_)) })) { $script:RepoRoot = $PSScriptRoot; return }
    $zip = Join-Path ([System.IO.Path]::GetTempPath()) "pstack-rewire-$([guid]::NewGuid().ToString('N')).zip"
    $ext = Join-Path ([System.IO.Path]::GetTempPath()) "pstack-rewire-$([guid]::NewGuid().ToString('N'))"
    $script:TempDirs += $ext
    Write-Host "Downloading pstack from GitHub ($RepoSlug@$Branch)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://github.com/$RepoSlug/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $ext -Force
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    $script:RepoRoot = (Get-ChildItem -LiteralPath $ext -Directory | Select-Object -First 1).FullName
}

function Get-ManifestSkills([string]$manifest) {
    if (-not (Test-Path -LiteralPath $manifest)) { return @() }
    return @(Get-Content -LiteralPath $manifest | Where-Object { $_ -like "skill=*" } | ForEach-Object { $_.Substring(6) })
}

# True when the skills-CLI lock file next to the skills folder attributes $name to this repo,
# i.e. the skills CLI installed it and owns its updates.
function Test-LockOwned([string]$dest, [string]$name) {
    $lock = Join-Path (Split-Path -Parent $dest) ".skill-lock.json"
    if (-not (Test-Path -LiteralPath $lock)) { return $false }
    try {
        $entry = (Get-Content -Raw -LiteralPath $lock | ConvertFrom-Json).skills.$name
        return ($null -ne $entry -and $entry.source -eq $RepoSlug)
    } catch { return $false }
}

function Get-TreeSignature([string]$root) {
    Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object {
        [PSCustomObject]@{
            Path = $_.FullName.Substring($root.Length).TrimStart('\', '/')
            Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    }
}

# True when the folder trees $a and $b have identical contents.
function Test-TreesIdentical([string]$a, [string]$b) {
    $diff = @(Compare-Object (Get-TreeSignature $a) (Get-TreeSignature $b) -Property Path, Hash)
    return ($diff.Count -eq 0)
}

# Copies every skill folder from $src into $dest, tracking ownership in $manifest.
# A same-named skill pstack did not install aborts unless -Force, which backs it up first.
# Exception: skills the skills CLI installed from this same repo (per .skill-lock.json)
# are left untouched while they match the repo copy, so the CLI keeps managing them.
function Install-FlatSkills([string]$src, [string]$dest, [string]$manifest, [string]$label) {
    $script:FlatNoop = $false
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $owned = Get-ManifestSkills $manifest
    $names = @(Get-ChildItem -LiteralPath $src -Directory | Select-Object -ExpandProperty Name)
    $collisions = @()
    $cliManaged = @()
    $current = 0
    foreach ($n in $names) {
        if ((Test-Path -LiteralPath (Join-Path $dest $n)) -and ($owned -notcontains $n)) {
            if (Test-LockOwned $dest $n) {
                if (Test-TreesIdentical (Join-Path $src $n) (Join-Path $dest $n)) { $current++ }
                else { $collisions += $n; $cliManaged += $n }
            } else { $collisions += $n }
        }
    }
    # Every skill is already present, installed by the skills CLI from this same repo,
    # and identical to the repo copy: leave it (and its lock file) alone.
    if ($names.Count -gt 0 -and $current -eq $names.Count) {
        $script:FlatNoop = $true
        Write-Host "pstack: all $($names.Count) skills are already installed and current via the skills CLI; nothing to do."
        return
    }
    if ($collisions.Count -gt 0) {
        $list = $collisions -join ', '
        if (-not $Force) {
            if ($cliManaged.Count -gt 0) {
                throw "These skills already exist in $dest and were not installed by pstack: $list. Some of these are managed by the skills CLI but differ from this repo; update them with the skills CLI, or rerun with -Force to have pstack take over (backs them up)."
            }
            throw "These skills already exist in $dest and were not installed by pstack: $list. Rerun with -Force to back them up and replace them."
        }
        $backup = Join-Path (Split-Path -Parent $dest) ".pstack-backup-$(Get-Date -Format yyyyMMddHHmmss)"
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        foreach ($n in $collisions) { Move-Item -LiteralPath (Join-Path $dest $n) -Destination (Join-Path $backup $n) }
        Write-Host "Backed up $($collisions -join ', ') to $backup" -ForegroundColor Yellow
    }
    foreach ($n in $owned) { $p = Join-Path $dest $n; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
    foreach ($n in $names) { Copy-Item -LiteralPath (Join-Path $src $n) -Destination (Join-Path $dest $n) -Recurse -Force }
    $version = ((Get-Content -Raw -LiteralPath (Join-Path (Split-Path -Parent $src) "plugin.json")) | ConvertFrom-Json).version
    $lines = @("target=$label", "version=$version", "installed_at=$((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))") + ($names | ForEach-Object { "skill=$_" })
    Set-Content -LiteralPath $manifest -Value $lines
}

function Uninstall-FlatSkills([string]$dest, [string]$manifest, [string]$label) {
    if (-not (Test-Path -LiteralPath $manifest)) { Write-Host "pstack ($label) is not installed in $dest" -ForegroundColor DarkYellow; return }
    $owned = Get-ManifestSkills $manifest
    foreach ($n in $owned) { $p = Join-Path $dest $n; if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
    Remove-Item -LiteralPath $manifest -Force
    Write-Host "Uninstalled pstack ($label): removed $($owned.Count) skills from $dest" -ForegroundColor Yellow
    Get-ChildItem -LiteralPath (Split-Path -Parent $dest) -Directory -Filter ".pstack-backup-*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "Skills pstack replaced are backed up in $($_.FullName). Move them back into $dest to restore them." -ForegroundColor DarkYellow
    }
}

function Install-CodexAgents([string]$src, [string]$dest) {
    $files = @(Get-ChildItem -LiteralPath $src -Filter "*.toml" -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) { return }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    foreach ($f in $files) {
        $t = Join-Path $dest $f.Name
        if ((Test-Path -LiteralPath $t) -and -not ((Get-Content -LiteralPath $t -TotalCount 1) -match "managed-by: pstack-rewire")) { Write-Host "Kept your edited $t (no pstack header)" -ForegroundColor DarkYellow; continue }
        Copy-Item -LiteralPath $f.FullName -Destination $t -Force
    }
    Write-Host "Installed Codex agents (poteto-agent, comment-sicko) -> $dest" -ForegroundColor Green
}

function Remove-CodexAgents([string]$dest) {
    foreach ($n in @("poteto-agent.toml", "comment-sicko.toml")) {
        $p = Join-Path $dest $n
        if ((Test-Path -LiteralPath $p) -and ((Get-Content -LiteralPath $p -TotalCount 1) -match "managed-by: pstack-rewire")) { Remove-Item -LiteralPath $p -Force }
    }
}

# Offers [agents] max_depth = 2 so pstack delegates can spawn helpers on multi-agent v1 models.
function Set-CodexMaxDepth([string]$cfg, [string]$record) {
    if (-not (Test-Interactive)) { return }
    $text = if (Test-Path -LiteralPath $cfg) { Get-Content -Raw -LiteralPath $cfg } else { "" }
    if ($text -match "(?m)^\s*max_depth\s*=\s*[2-9]") { return }
    $answer = Read-Host "Allow pstack subagents to spawn their own helpers? Sets [agents] max_depth = 2 in $cfg [y/N]"
    if ($answer -notmatch "^(y|yes)$") { return }
    New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
    $previous = "absent"
    if ($text -match "(?m)^\[agents\]") {
        $m = [regex]::Match($text, "(?ms)^\[agents\][^\[]*?^\s*max_depth\s*=\s*(\S+)")
        if ($m.Success) { $previous = $m.Groups[1].Value; $text = [regex]::Replace($text, "(?ms)(^\[agents\][^\[]*?^\s*)max_depth\s*=\s*\S+", '${1}max_depth = 2') }
        else { $text = [regex]::Replace($text, "(?m)^\[agents\]\s*$", "[agents]`nmax_depth = 2") }
    } else { $text = $text.TrimEnd() + "`n`n[agents]`nmax_depth = 2`n" }
    Set-Content -LiteralPath $cfg -Value $text -NoNewline
    Set-Content -LiteralPath $record -Value @("max_depth_set=1", "max_depth_previous=$previous")
    Write-Host "Set [agents] max_depth = 2 in $cfg" -ForegroundColor Green
}

function Restore-CodexMaxDepth([string]$cfg, [string]$record) {
    if (-not (Test-Path -LiteralPath $record)) { return }
    $rec = Get-Content -LiteralPath $record
    if (($rec -contains "max_depth_set=1") -and (Test-Path -LiteralPath $cfg)) {
        $previous = (($rec | Where-Object { $_ -like "max_depth_previous=*" }) -replace "^max_depth_previous=", "")
        $text = Get-Content -Raw -LiteralPath $cfg
        if ($text -match "(?ms)^\[agents\][^\[]*?^\s*max_depth\s*=\s*2\s*$") {
            if ($previous -eq "absent") { $text = [regex]::Replace($text, "(?ms)(^\[agents\][^\[]*?)^\s*max_depth\s*=\s*2\s*\r?\n?", '${1}') }
            else { $text = [regex]::Replace($text, "(?ms)(^\[agents\][^\[]*?^\s*)max_depth\s*=\s*2", "`${1}max_depth = $previous") }
            Set-Content -LiteralPath $cfg -Value $text -NoNewline
            Write-Host "Restored [agents] max_depth in $cfg" -ForegroundColor Yellow
        }
    }
    Remove-Item -LiteralPath $record -Force
}

function Remove-ModelsBlock {
    foreach ($f in @((Join-Path $HOME ".codex\AGENTS.md"), (Join-Path $HOME ".codex\AGENTS.override.md"))) {
        if (-not (Test-Path -LiteralPath $f)) { continue }
        $text = Get-Content -Raw -LiteralPath $f
        if ($text -notmatch "pstack-models:begin") { continue }
        $text = [regex]::Replace($text, "(?s)<!-- pstack-models:begin -->.*?<!-- pstack-models:end -->\r?\n?", "")
        Set-Content -LiteralPath $f -Value $text -NoNewline
        Write-Host "Removed the pstack-models block from $f" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Per-harness actions.
# ---------------------------------------------------------------------------
function Invoke-Claude([string]$act, [string]$sc) {
    $marketplace = "pstack-rewire"; $pluginId = "pstack@pstack-rewire"
    $claudeScope = if ($sc -eq "workspace") { "project" } else { "user" }
    $legacy = if ($sc -eq "workspace") { Join-Path $Ws ".claude\plugins\pstack" } else { Join-Path $HOME ".claude\plugins\pstack" }
    if (Test-Path -LiteralPath $legacy) { Remove-Item -LiteralPath $legacy -Recurse -Force; Write-Host "Removed legacy folder copy at $legacy" -ForegroundColor Yellow }
    if (-not (Test-OnPath claude)) {
        Write-Host "The claude CLI was not found on PATH. In a Claude Code session, run:" -ForegroundColor DarkYellow
        if ($act -eq "uninstall") { Write-Host "  /plugin uninstall $pluginId"; Write-Host "  /plugin marketplace remove $marketplace" }
        else { Write-Host "  /plugin marketplace add $RepoSlug"; Write-Host "  /plugin install $pluginId" }
        $script:Skipped = $true
        return
    }
    if ($act -eq "uninstall") {
        & claude plugin uninstall $pluginId --scope $claudeScope *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "Uninstalled pstack (claude, $claudeScope scope)" -ForegroundColor Yellow } else { Write-Host "pstack (claude, $claudeScope scope) is not installed" -ForegroundColor DarkYellow }
        & claude plugin marketplace remove $marketplace --scope $claudeScope *> $null
        if (((& claude plugin list 2>$null) -join "`n") -notmatch [regex]::Escape($pluginId)) { & claude plugin marketplace remove $marketplace *> $null; if ($LASTEXITCODE -eq 0) { Write-Host "Removed marketplace $marketplace (no pstack install remains)" -ForegroundColor Yellow } }
        return
    }
    $source = $RepoSlug
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".claude-plugin\marketplace.json")) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "claude"))) { $source = $PSScriptRoot }
    & claude plugin marketplace add $source --scope $claudeScope; if ($LASTEXITCODE -ne 0) { throw "claude plugin marketplace add failed" }
    & claude plugin marketplace update $marketplace
    & claude plugin install $pluginId --scope $claudeScope; if ($LASTEXITCODE -ne 0) { throw "claude plugin install failed" }
    & claude plugin update $pluginId --scope $claudeScope
    Write-Host "Installed or updated pstack (claude, $claudeScope scope). Restart Claude Code or run /reload-plugins, then run /pstack:poteto-help." -ForegroundColor Green
}

function Invoke-Codex([string]$act, [string]$sc) {
    $marketplace = "pstack-rewire-codex"; $pluginId = "pstack@pstack-rewire-codex"
    $legacy = Join-Path $HOME ".codex\plugins\pstack"
    if (Test-Path -LiteralPath $legacy) { Remove-Item -LiteralPath $legacy -Recurse -Force; Write-Host "Removed legacy folder copy at $legacy" -ForegroundColor Yellow }
    if ($sc -eq "workspace") {
        if ($act -eq "uninstall") {
            Uninstall-FlatSkills (Join-Path $Ws ".agents\skills") (Join-Path $Ws ".agents\.pstack-manifest-codex") "codex, workspace"
            Remove-CodexAgents (Join-Path $Ws ".codex\agents")
            Restore-CodexMaxDepth (Join-Path $Ws ".codex\config.toml") (Join-Path $Ws ".codex\.pstack-install")
            return
        }
        Install-FlatSkills (Join-Path $script:RepoRoot "codex\skills") (Join-Path $Ws ".agents\skills") (Join-Path $Ws ".agents\.pstack-manifest-codex") "codex"
        Install-CodexAgents (Join-Path $script:RepoRoot "codex\agents") (Join-Path $Ws ".codex\agents")
        Set-CodexMaxDepth (Join-Path $Ws ".codex\config.toml") (Join-Path $Ws ".codex\.pstack-install")
        if (-not $script:FlatNoop) {
            Write-Host "Installed pstack (codex, workspace) -> $(Join-Path $Ws '.agents\skills'). Trust this project in Codex, then type `$poteto-help." -ForegroundColor Green
        }
        return
    }
    if (-not (Test-OnPath codex)) {
        Write-Host "The codex CLI was not found on PATH. Install it with npm i -g @openai/codex, or run:" -ForegroundColor DarkYellow
        if ($act -eq "uninstall") { Write-Host "  codex plugin remove $pluginId"; Write-Host "  codex plugin marketplace remove $marketplace" }
        else { Write-Host "  codex plugin marketplace add $RepoSlug"; Write-Host "  codex plugin add $pluginId" }
        $script:Skipped = $true
        return
    }
    if ($act -eq "uninstall") {
        & codex plugin remove $pluginId *> $null
        if ($LASTEXITCODE -eq 0) { Write-Host "Uninstalled pstack (codex plugin $pluginId)" -ForegroundColor Yellow } else { Write-Host "pstack (codex plugin $pluginId) is not installed" -ForegroundColor DarkYellow }
        if (((& codex plugin list 2>$null) -join "`n") -notmatch [regex]::Escape($pluginId)) { & codex plugin marketplace remove $marketplace *> $null; if ($LASTEXITCODE -eq 0) { Write-Host "Removed marketplace $marketplace" -ForegroundColor Yellow } }
        Remove-CodexAgents (Join-Path $HOME ".codex\agents")
        Remove-ModelsBlock
        Restore-CodexMaxDepth (Join-Path $HOME ".codex\config.toml") (Join-Path $HOME ".codex\.pstack-install")
        return
    }
    $source = $RepoSlug
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot ".agents\plugins\marketplace.json")) -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "codex"))) { $source = $PSScriptRoot }
    & codex plugin marketplace add $source; if ($LASTEXITCODE -ne 0) { throw "codex plugin marketplace add failed" }
    & codex plugin marketplace upgrade $marketplace *> $null
    & codex plugin add $pluginId; if ($LASTEXITCODE -ne 0) { throw "codex plugin add failed" }
    $cache = Get-ChildItem -LiteralPath (Join-Path $HOME ".codex\plugins\cache\$marketplace\pstack") -Directory -ErrorAction SilentlyContinue | Sort-Object { [version]($_.Name -replace '[^0-9.].*$', '') } | Select-Object -Last 1
    if (-not $cache -or -not (Test-Path -LiteralPath (Join-Path $cache.FullName ".codex-plugin\plugin.json"))) { throw "Codex did not install the codex/ bundle (no .codex-plugin\plugin.json in the plugin cache)" }
    Install-CodexAgents (Join-Path $cache.FullName "agents") (Join-Path $HOME ".codex\agents")
    Set-CodexMaxDepth (Join-Path $HOME ".codex\config.toml") (Join-Path $HOME ".codex\.pstack-install")
    Write-Host "Installed or updated pstack (codex plugin $pluginId). Start a new Codex session and type `$pstack:poteto-help." -ForegroundColor Green
}

function Invoke-Default([string]$act, [string]$sc) {
    $base = if ($sc -eq "workspace") { $Ws } else { $HOME }
    $manifest = Join-Path $base ".agents\.pstack-manifest-default"
    if ($act -eq "uninstall") {
        Uninstall-FlatSkills (Join-Path $base ".agents\skills") $manifest "default, $sc"
        $models = Join-Path $HOME ".agents\pstack-models.md"
        if ($sc -eq "global" -and (Test-Path -LiteralPath $models)) { Write-Host "Kept your model roles file $models. Delete it by hand if you no longer want it." -ForegroundColor DarkYellow }
        return
    }
    Install-FlatSkills (Join-Path $script:RepoRoot "default\skills") (Join-Path $base ".agents\skills") $manifest "default"
    if ($script:FlatNoop) { return }
    if (Test-Path -LiteralPath (Join-Path $HOME ".codex\plugins\cache\pstack-rewire-codex\pstack")) { Write-Host "Note: the pstack Codex plugin is also installed, so Codex will list both pstack:<name> and <name> skills." -ForegroundColor DarkYellow }
    Write-Host "Installed or updated pstack (default, $sc) -> $(Join-Path $base '.agents\skills'). Start a new agent session and ask for the poteto-help skill." -ForegroundColor Green
}

function Invoke-Folder([string]$h, [string]$act, [string]$sc) {
    $d = if ($Dest) { $Dest } else { Get-FolderDest $h $sc }
    if ($act -eq "uninstall") {
        if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force; Write-Host "Uninstalled pstack ($h, $sc) from $d" -ForegroundColor Yellow }
        else { Write-Host "pstack ($h, $sc) is not installed at $d" -ForegroundColor DarkYellow }
        return
    }
    $src = Join-Path $script:RepoRoot $h
    if (-not (Test-Path -LiteralPath $src)) { throw "Harness '$h' not found in $RepoSlug" }
    New-Item -ItemType Directory -Path (Split-Path -Parent $d) -Force | Out-Null
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    Copy-Item -LiteralPath $src -Destination $d -Recurse -Force
    Write-Host "Installed pstack ($h, $sc) -> $d" -ForegroundColor Green
}

function Invoke-Harness([string]$h, [string]$act, [string]$sc) {
    if ($Dest) { Invoke-Folder $h $act $sc; return }
    switch ($h) {
        "claude"  { Invoke-Claude $act $sc }
        "codex"   { Invoke-Codex $act $sc }
        "default" { Invoke-Default $act $sc }
        default   { Invoke-Folder $h $act $sc }
    }
}

# ---------------------------------------------------------------------------
# Run.
# ---------------------------------------------------------------------------
if ($Action -eq "install") {
    $need = @($Selected | Where-Object { $_ -ne "claude" -and ($_ -ne "codex" -or $Scope -eq "workspace") })
    if ($need.Count -gt 0) { Resolve-RepoRoot $need }
}

$scopes = if ($Scope -eq "all") { @("global", "workspace") } else { @($Scope) }
$summary = @()
$failed = $false
try {
    foreach ($h in $Selected) {
        foreach ($sc in $scopes) {
            if ($Action -eq "uninstall" -and -not $Dest -and $h -notin @("claude", "codex") -and -not (Test-InstalledAt $h $sc)) { continue }
            Write-Host ""
            Write-Host "== $(Get-Label $h) ($Action, $sc)" -ForegroundColor Cyan
            try {
                $script:Skipped = $false
                Invoke-Harness $h $Action $sc
                if ($script:Skipped) { $summary += "  skipped $(Get-Label $h) ($sc): its CLI is not on PATH, run the commands printed above" }
                else { $summary += "  ok      $(Get-Label $h) ($sc)" }
            } catch {
                Write-Host "error: $($_.Exception.Message)" -ForegroundColor Red
                $summary += "  FAILED  $(Get-Label $h) ($sc)"
                $failed = $true
            }
        }
    }
} finally {
    foreach ($t in $script:TempDirs) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
Write-Host "pstack $Action summary:"
if ($summary.Count -eq 0) { Write-Host "  nothing to do" } else { $summary | ForEach-Object { Write-Host $_ } }
if ($failed) { exit 1 }
exit 0
