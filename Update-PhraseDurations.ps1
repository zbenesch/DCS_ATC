#Requires -Version 5.1
<#
.SYNOPSIS
  Rescans all OGG clips and patches phrasedur.lua with their actual durations.
  Run this after Refilter-Phrases.ps1 (or any time you modify OGGs outside of
  Generate-Phrases.ps1) so the in-game scheduler uses accurate clip timings.
#>
param(
    [string] $FFmpeg      = "E:\downloader\ffmpeg.exe",
    [string] $PhrasesDir  = "K:\DCS_ATC\Mods\Services\DCS-ATC\phrases",
    [string] $PhraseDurLua = "K:\DCS_ATC\Mods\Services\DCS-ATC\Scripts\controllers\phrasedur.lua"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

function Invoke-FFmpeg {
    param([string[]]$ArgList)
    $psi                        = [System.Diagnostics.ProcessStartInfo]::new($FFmpeg)
    $psi.Arguments              = $ArgList -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return $stdout + $stderr
}

function Get-ClipDuration {
    param([string]$Path)
    $raw = Invoke-FFmpeg -ArgList @("-hide_banner", "-i", "`"$Path`"")
    if ($raw -match 'Duration:\s*(\d+):(\d+):([\d.]+)') {
        $h = [double]$Matches[1]; $m = [double]$Matches[2]; $s = [double]$Matches[3]
        return [math]::Round($h*3600 + $m*60 + $s, 3)
    }
    return $null
}

Write-Host ""
Write-Host "Scanning OGG durations in $PhrasesDir ..." -ForegroundColor Cyan

$durations = [System.Collections.Generic.SortedDictionary[string,double]]::new()
$voiceDirs = @(Get-ChildItem $PhrasesDir -Directory | Sort-Object Name)
$total = 0; $idx = 0

foreach ($vDir in $voiceDirs) {
    $vName = $vDir.Name
    # Exclude backup files
    $oggs  = @(Get-ChildItem $vDir.FullName -Filter "*.ogg" |
               Where-Object { $_.Name -notmatch '\.bak\.ogg$' } |
               Sort-Object Name)
    Write-Host "  $vName : $($oggs.Count) clips" -ForegroundColor DarkGray
    $total += $oggs.Count

    foreach ($f in $oggs) {
        $token = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $dur   = Get-ClipDuration $f.FullName
        if ($null -ne $dur -and $dur -gt 0) {
            $key = "$vName/$token"
            $durations[$key] = $dur
        }
        $idx++
        if ($idx % 50 -eq 0) {
            Write-Host "  ... $idx / $total" -ForegroundColor DarkGray
        }
    }
}

Write-Host ""
Write-Host "Scanned $($durations.Count) clips.  Patching $PhraseDurLua ..." -ForegroundColor Cyan

# Build the Lua table block
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("ATC = ATC or {}")
$lines.Add("ATC._phraseDur = {")
foreach ($kv in $durations.GetEnumerator()) {
    $lines.Add("    [`"$($kv.Key)`"] = $($kv.Value),")
}
$lines.Add("}")
$lines.Add("")

# Append PSUBS / WSET / DWORDS sections from the existing file (keep everything after the table)
$existing = [System.IO.File]::ReadAllText($PhraseDurLua, [System.Text.Encoding]::UTF8)

# Find where ATC._PSUBS starts (the section after the duration table)
$psubsIdx = $existing.IndexOf("ATC._PSUBS")
if ($psubsIdx -lt 0) {
    # Fallback: find end of table by looking for "}" followed by newline then ATC.
    $psubsIdx = $existing.IndexOf("`nATC.", $existing.IndexOf("ATC._phraseDur"))
}

$tail = if ($psubsIdx -gt 0) { $existing.Substring($psubsIdx) } else { "" }

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$content   = ($lines -join "`n") + "`n" + $tail
[System.IO.File]::WriteAllText($PhraseDurLua, $content, $utf8NoBom)

Write-Host "phrasedur.lua updated with $($durations.Count) entries." -ForegroundColor Green
Write-Host ""

# Quick stats: compare to previous values if available
$newMean = ($durations.Values | Measure-Object -Average).Average
Write-Host ("Mean clip duration: {0:F3} s" -f $newMean)
Write-Host "Done." -ForegroundColor Green
