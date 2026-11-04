<#
.SYNOPSIS
Validate a multi-phase / multi-PR plan file against playbooks/multi-phase-plan.md.
Mirrors check-plan.mjs for Windows PowerShell environments where standalone node is not in PATH.
Usage: powershell -NoProfile -ExecutionPolicy Bypass -File check-plan.ps1 <plan.md>
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$File
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $File)) {
    [Console]::Error.WriteLine("Usage: check-plan.ps1 <plan.md> (file not found: $File)")
    exit 2
}

$RULE = "Tests alone are not sufficient verification. A PR is verified only when its unit, live, and perf boxes are all checked."
$SUB_BLOCKS = @(
    "Depends on.",
    "Files.",
    "Build.",
    "You see.",
    "Verify, unit.",
    "Verify, live.",
    "Verify, perf.",
    "Review gate.",
    "Merge."
)
$PROGRAM_H3 = @("Arm the program", "Spawn owners", "PR mechanics", "Verdict and merge", "Boot recipe")
$PROGRAM_MARKERS = @("git show origin/main:", "status message")
$HOW_TO_READ_MARKERS = @(
    "One box is one unit of work",
    "names the evidence",
    "Check a box only when its evidence exists",
    "playbooks/",
    $RULE
)
$PERF_ITEMS = @("Metric.", "Probe.", "Baseline.", "Rule.")

$raw = [System.IO.File]::ReadAllLines((Resolve-Path -LiteralPath $File).Path)
$problems = New-Object System.Collections.Generic.List[string]
function Add-Fail([int]$line, [string]$msg) {
    $problems.Add("${File}:${line}: ${msg}")
}

$start = 0
if ($raw.Count -gt 0 -and $raw[0] -eq "---") {
    for ($j = 1; $j -lt $raw.Count; $j++) {
        if ($raw[$j] -eq "---") { $start = $j + 1; break }
    }
}

$lines = New-Object System.Collections.Generic.List[object]
$fenceChar = ""
$fenceLen = 0

for ($i = $start; $i -lt $raw.Count; $i++) {
    $text = $raw[$i]
    $n = $i + 1
    $code = ($fenceLen -gt 0)
    if ($fenceLen -gt 0) {
        if ($text -match "^ {0,3}(`+|~+)[ \t]*$" -and $Matches[1][0] -eq $fenceChar -and $Matches[1].Length -ge $fenceLen) {
            $code = $false
            $fenceChar = ""
            $fenceLen = 0
        }
    } else {
        if ($text -match "^ {0,3}(`{3,}|~{3,})(.*)$") {
            if (-not ($Matches[1][0] -eq '`' -and $Matches[2].Contains('`'))) {
                $fenceChar = $Matches[1][0]
                $fenceLen = $Matches[1].Length
                $code = $true
            }
        }
    }
    $lines.Add([PSCustomObject]@{ n = $n; text = $text; code = $code })
    if ($code) { continue }
    $prose = [regex]::Replace($text, '(?<!`)(`+)(?!`)(.*?)(?<!`)\1(?!`)', '`')
    $prose = [regex]::Replace($prose, '!\[[^\]]*\]\([^)]*\)', '')
    $prose = [regex]::Replace($prose, '\]\([^)]*\)', ']')
    if ($prose -match "[\u2013\u2014]") { Add-Fail $n "long dash" }
    if ($prose -match "[\u2018\u2019\u201c\u201d]") { Add-Fail $n "curly quote" }
    if ($prose -match ": \S") { Add-Fail $n "mid-sentence colon" }
}

$sections = New-Object System.Collections.Generic.List[object]
foreach ($l in $lines) {
    if (-not $l.code -and $l.text.StartsWith("## ")) {
        $sections.Add([PSCustomObject]@{
            title = $l.text.Substring(3).Trim()
            n     = $l.n
            body  = New-Object System.Collections.Generic.List[object]
        })
    } elseif ($sections.Count -gt 0) {
        $sections[$sections.Count - 1].body.Add($l)
    }
}

function Find-Section([string]$title) {
    foreach ($s in $sections) { if ($s.title -eq $title) { return $s } }
    return $null
}

$h1Idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if (-not $lines[$i].code -and $lines[$i].text.StartsWith("# ")) { $h1Idx = $i; break }
}
if ($h1Idx -eq -1) { Add-Fail 1 "no H1 title" }

$howToRead = Find-Section "How to read this"
if (-not $howToRead) { Add-Fail 1 'no "## How to read this" section' }
if ($h1Idx -ne -1 -and $howToRead) {
    $introCount = 0
    for ($i = $h1Idx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].n -lt $howToRead.n -and $lines[$i].text.Trim() -ne "") { $introCount++ }
    }
    if ($introCount -ge 10) { Add-Fail $lines[$h1Idx].n "intro is $introCount lines, under ten required" }
    $htrBody = ($howToRead.body | ForEach-Object { $_.text }) -join "`n"
    foreach ($m in $HOW_TO_READ_MARKERS) {
        if (-not $htrBody.Contains($m)) { Add-Fail $howToRead.n "How to read this lacks `"$m`"" }
    }
}

$program = Find-Section "Program checklist"
if (-not $program) { Add-Fail 1 'no "## Program checklist" section' }
else {
    $h3s = @($program.body | Where-Object { -not $_.code -and $_.text.StartsWith("### ") } | ForEach-Object { $_.text.Substring(4).Trim() })
    $cursor = 0
    foreach ($name in $PROGRAM_H3) {
        $found = -1
        for ($i = $cursor; $i -lt $h3s.Count; $i++) {
            if ($h3s[$i].StartsWith($name)) { $found = $i; break }
        }
        if ($found -eq -1) { Add-Fail $program.n "Program checklist lacks `"### $name`" in order" }
        else { $cursor = $found + 1 }
    }
    $progBody = ($program.body | ForEach-Object { $_.text }) -join "`n"
    foreach ($m in $PROGRAM_MARKERS) {
        if (-not $progBody.Contains($m)) { Add-Fail $program.n "Program checklist lacks `"$m`"" }
    }
}

$close = Find-Section "Close the program"
if (-not $close) { Add-Fail 1 'no "## Close the program" section' }

$programIdx = $sections.IndexOf($program)
$closeIdx = $sections.IndexOf($close)
$prSections = @()
if ($programIdx -ge 0 -and $closeIdx -gt $programIdx) {
    for ($i = $programIdx + 1; $i -lt $closeIdx; $i++) { $prSections += $sections[$i] }
}
if ($prSections.Count -eq 0) { Add-Fail 1 "no PR sections between Program checklist and Close the program" }

Write-Output "$($prSections.Count) PR sections, $($problems.Count) problems"
foreach ($p in $problems) { [Console]::Error.WriteLine($p) }
exit $(if ($problems.Count -gt 0) { 1 } else { 0 })
