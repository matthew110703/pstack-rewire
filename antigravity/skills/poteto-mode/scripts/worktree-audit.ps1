<#
.SYNOPSIS
Read-only worktree prune audit for Windows PowerShell. Classifies every git worktree by size, merge
state, uncommitted work, remote/PR state, and the most recent Antigravity chat that operated in it.
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File worktree-audit.ps1 [-Base <ref>] [-Repo <path>]
#>
param(
    [Alias("b")][string]$Base = "",
    [Parameter(Position = 0)][string]$Repo = ""
)

$ErrorActionPreference = "Continue"

if (-not $Repo) {
    $Repo = (git rev-parse --show-toplevel 2>$null)
}
if (-not $Repo) {
    [Console]::Error.WriteLine("not in a git repo; pass -Repo <path>")
    exit 1
}
Set-Location -LiteralPath $Repo

$porcelainList = git worktree list --porcelain 2>$null
if ($LASTEXITCODE -ne 0) {
    [Console]::Error.WriteLine("error: not a git repo: $Repo")
    exit 1
}

$worktrees = @()
foreach ($line in $porcelainList) {
    if ($line -match "^worktree\s+(.+)$") {
        $worktrees += $Matches[1]
    }
}
if ($worktrees.Count -eq 0) { exit 0 }
$mainWt = $worktrees[0]

if (-not $Base) {
    $candidates = @(
        (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null),
        "origin/main",
        "origin/master"
    )
    foreach ($cand in $candidates) {
        if ($cand) {
            git rev-parse --verify --quiet "$cand^{commit}" >$null 2>$null
            if ($LASTEXITCODE -eq 0) {
                $Base = $cand
                break
            }
        }
    }
    if (-not $Base) {
        [Console]::Error.WriteLine("error: no base ref; pass -Base <ref>")
        exit 1
    }
    [Console]::Error.WriteLine("warn: no -Base given; MERGED checks against $Base")
}

$brainDir = if ($env:AGY_BRAIN_DIR) { $env:AGY_BRAIN_DIR } else { Join-Path $HOME ".gemini\antigravity\brain" }
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

Write-Output "# base: $Base"
Write-Output "SIZE`tAGE`tMERGED`tDIRTY`tREMOTE`tPR`tLAST_CHAT`tBUCKET`tWORKTREE"

foreach ($wt in $worktrees | Select-Object -Skip 1) {
    $bytes = (Get-ChildItem -LiteralPath $wt -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $bytes) { $bytes = 0 }
    $size = if ($bytes -ge 1GB) { "{0:N1}G" -f ($bytes / 1GB) } elseif ($bytes -ge 1MB) { "{0:N1}M" -f ($bytes / 1MB) } else { "{0:N0}K" -f ($bytes / 1KB) }

    $head = git -C $wt rev-parse HEAD 2>$null
    $headTs = [long](git -C $wt log -1 --format='%ct' HEAD 2>$null)
    $age = if ($headTs -gt 0) { "$([math]::Floor(($now - $headTs) / 86400))d" } else { "?" }

    git merge-base --is-ancestor $head $Base 2>$null
    $merged = if ($LASTEXITCODE -eq 0) { "YES" } else { "no" }

    $statusLines = @(git -C $wt status --porcelain 2>$null)
    if ($statusLines.Count -eq 0) {
        $dirty = "clean"
    } else {
        $tracked = @($statusLines | Where-Object { $_ -notmatch "^\?\?" })
        if ($tracked.Count -gt 0) {
            $dirty = "wip:$($tracked.Count)"
        } else {
            $dirty = "scratch:$($statusLines.Count)"
        }
    }

    $branch = git -C $wt symbolic-ref --quiet --short HEAD 2>$null
    if (-not $branch) {
        $remote = "detached"
    } else {
        git -C $wt show-ref --verify --quiet "refs/remotes/origin/$branch" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $origHead = git -C $wt rev-parse "origin/$branch" 2>$null
            if ($origHead -eq $head) { $remote = "pushed" }
            else {
                $ahead = git -C $wt rev-list --count "origin/$branch..HEAD" 2>$null
                $remote = "ahead$ahead"
            }
        } else {
            $remote = "no-remote"
        }
    }

    $pr = "-"
    $last = "-"
    $recent = "no"
    if (Test-Path -LiteralPath $brainDir) {
        $escapedWt = [regex]::Escape($wt)
        $matches = Get-ChildItem -LiteralPath $brainDir -Filter "transcript*.jsonl" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { Select-String -LiteralPath $_.FullName -Pattern "$escapedWt[/\\""]" -Quiet } |
            Sort-Object LastWriteTimeUtc -Descending
        if ($matches -and $matches.Count -gt 0) {
            $latest = $matches[0].LastWriteTimeUtc
            $last = $latest.ToString("yyyy-MM-dd")
            if ((([DateTime]::UtcNow - $latest).TotalDays) -le 4) { $recent = "yes" }
        }
    }

    $bucket = if ($dirty -like "wip:*") { "hold-wip" }
    elseif ($recent -eq "yes") { "verify-recent-chat" }
    elseif ($merged -eq "YES" -or $pr -ne "-") { "safe" }
    else { "review" }

    Write-Output "$size`t$age`t$merged`t$dirty`t$remote`t$pr`t$last`t$bucket`t$wt"
}
