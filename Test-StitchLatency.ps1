#Requires -Version 5.1
<#
.SYNOPSIS
  Measures the stitching latency of DCS-ATC's phrase audio system.

.DESCRIPTION
  1. Parses the _phraseDur table from phrasedur.lua (the scheduled durations).
  2. Probes every OGG file's actual duration via FFmpeg.
  3. Reports gap = phraseDur - actualDuration per token.
       Positive gap  -> silence between words (latency / dead air).
       Negative gap  -> clips would overlap (word gets cut off).
  4. Stitches token sequences for representative ATC messages and saves
     WAV files so you can listen to the actual stitching quality.

.PARAMETER Voice
  Which voice subfolder to test (default: adam).

.PARAMETER FFmpeg
  Path to ffmpeg.exe.

.PARAMETER PhrasesDir
  Root phrases directory.

.PARAMETER PhraseDurLua
  Path to controllers/phrasedur.lua.

.PARAMETER OutDir
  Where to write stitched WAVs (default: .\stitch-test\).

.PARAMETER Play
  Automatically open each WAV with the system default audio player.

.PARAMETER MaxProbe
  Cap on how many OGG files to probe in the gap-analysis pass.
  0 = probe all files (default).
#>
param(
    [string] $Voice        = "adam",
    [string] $FFmpeg       = "E:\downloader\ffmpeg.exe",
    [string] $PhrasesDir   = "K:\DCS_ATC\Mods\Services\DCS-ATC\phrases",
    [string] $PhraseDurLua = "K:\DCS_ATC\Mods\Services\DCS-ATC\Scripts\controllers\phrasedur.lua",
    [string] $OutDir       = "K:\DCS_ATC\stitch-test",
    [switch] $Play,
    [int]    $MaxProbe     = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Helper: run ffmpeg via ProcessStartInfo, return combined stdout+stderr.
# Avoids PS 5.1 wrapping native-command stderr as ErrorRecords.
# ---------------------------------------------------------------------------
function Invoke-FFmpeg {
    param([string[]]$ArgList)
    $psi                        = [System.Diagnostics.ProcessStartInfo]::new($FFmpeg)
    $psi.Arguments              = $ArgList -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $proc   = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return $stdout + $stderr
}

# ---------------------------------------------------------------------------
# Helper: probe actual duration (seconds) of one audio file.
# ---------------------------------------------------------------------------
function Measure-AudioDuration {
    param([string]$Path)
    $raw = Invoke-FFmpeg -ArgList @("-hide_banner", "-i", "`"$Path`"")
    if ($raw -match 'Duration:\s*(\d+):(\d+):([\d.]+)') {
        $h = [double]$Matches[1]
        $m = [double]$Matches[2]
        $s = [double]$Matches[3]
        return [math]::Round($h * 3600 + $m * 60 + $s, 4)
    }
    return $null
}

# ---------------------------------------------------------------------------
# Helper: concatenate a list of OGGs into a single WAV.
# ---------------------------------------------------------------------------
function Join-AudioFiles {
    param([string[]]$OggPaths, [string]$OutWav)

    # Write concat list WITHOUT BOM.
    # PS 5.1 Set-Content -Encoding utf8 adds a BOM which ffmpeg concat demuxer
    # rejects with "unknown keyword".
    $tmpList   = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".txt")
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $lines     = $OggPaths | ForEach-Object { "file '$($_ -replace "'", "''")'" }
    [System.IO.File]::WriteAllLines($tmpList, $lines, $utf8NoBom)

    $out = Invoke-FFmpeg -ArgList @(
        "-hide_banner", "-loglevel", "error", "-y",
        "-f", "concat", "-safe", "0", "-i", "`"$tmpList`"",
        "-ar", "44100", "-ac", "1",
        "`"$OutWav`""
    )
    Remove-Item $tmpList -Force -ErrorAction SilentlyContinue

    if ($out -match 'Error|Invalid|No such') {
        Write-Warning "ffmpeg concat problem: $($out.Trim())"
    }
}

# ===========================================================================
# 1. Parse _phraseDur table from Lua
# ===========================================================================
Write-Host ""
Write-Host "Parsing phraseDur from $PhraseDurLua ..." -ForegroundColor Cyan

$luaText   = [System.IO.File]::ReadAllText($PhraseDurLua, [System.Text.Encoding]::UTF8)
$phraseDur = @{}
$rx        = [regex]::new('\["([^/"]+)/([^"]+)"\]\s*=\s*([\d.]+)')

foreach ($m in $rx.Matches($luaText)) {
    $v  = $m.Groups[1].Value
    $tk = $m.Groups[2].Value
    $d  = [double]$m.Groups[3].Value
    if (-not $phraseDur.ContainsKey($v)) { $phraseDur[$v] = @{} }
    $phraseDur[$v][$tk] = $d
}

$voices = @($phraseDur.Keys | Sort-Object)
Write-Host "  Found $($voices.Count) voice(s): $($voices -join ', ')" -ForegroundColor Gray

if (-not $phraseDur.ContainsKey($Voice)) {
    Write-Error "Voice '$Voice' not in phraseDur.  Available: $($voices -join ', ')"
    exit 1
}
$vDur = $phraseDur[$Voice]
Write-Host "  ${Voice}: $($vDur.Count) tokens with recorded durations" -ForegroundColor Gray

# ===========================================================================
# 2. Probe actual OGG durations and compare to phraseDur
# ===========================================================================
$voiceDir = Join-Path $PhrasesDir $Voice
if (-not (Test-Path $voiceDir)) {
    Write-Error "Phrases directory not found: $voiceDir"
    exit 1
}

$allOggs = @(Get-ChildItem $voiceDir -Filter "*.ogg" |
             Where-Object { $_.Name -notmatch '\.bak\.ogg$' } |
             Sort-Object Name)
$subset  = if ($MaxProbe -gt 0) { $allOggs | Select-Object -First $MaxProbe } else { $allOggs }

Write-Host ""
Write-Host "Probing $($subset.Count) / $($allOggs.Count) OGG files in $voiceDir ..." -ForegroundColor Cyan

$probeRows = [System.Collections.Generic.List[PSObject]]::new()
$idx = 0
foreach ($f in $subset) {
    $token    = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $recorded = if ($vDur.ContainsKey($token)) { $vDur[$token] } else { $null }
    $actual   = Measure-AudioDuration $f.FullName
    $gap_ms   = if ($null -ne $recorded -and $null -ne $actual) {
                    [math]::Round(($recorded - $actual) * 1000, 2)
                } else { $null }

    $probeRows.Add([PSCustomObject]@{
        Token  = $token
        Rec_s  = if ($null -ne $recorded) { [math]::Round($recorded, 3) } else { $null }
        Act_s  = if ($null -ne $actual)   { [math]::Round($actual,   3) } else { $null }
        Gap_ms = $gap_ms
        HasRec = ($null -ne $recorded)
        HasAct = ($null -ne $actual)
    })

    $idx++
    if ($idx % 25 -eq 0) {
        Write-Host "  ... $idx / $($subset.Count)" -ForegroundColor DarkGray
    }
}

# --- statistics ---
$matched = @($probeRows | Where-Object { $null -ne $_.Gap_ms })
$noRec   = @($probeRows | Where-Object { -not $_.HasRec })
$noAct   = @($probeRows | Where-Object { -not $_.HasAct })

if ($matched.Count -gt 0) {
    $gapVals  = $matched | ForEach-Object { $_.Gap_ms }
    $mean     = [math]::Round(($gapVals | Measure-Object -Average).Average, 2)
    $maxGap   = ($gapVals | Measure-Object -Maximum).Maximum
    $minGap   = ($gapVals | Measure-Object -Minimum).Minimum
    $variance = ($gapVals | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Sum).Sum
    $stddev   = [math]::Round([math]::Sqrt($variance / [math]::Max(1, $matched.Count - 1)), 2)
} else {
    $mean = $maxGap = $minGap = $stddev = 0
}

$overlaps = @($matched | Where-Object { $_.Gap_ms -lt -20 }).Count
$longGaps = @($matched | Where-Object { $_.Gap_ms -gt  80 }).Count

Write-Host ""
Write-Host ("=" * 57) -ForegroundColor Yellow
Write-Host ("  STITCHING GAP ANALYSIS   voice={0}   n={1} tokens" -f $Voice, $matched.Count) -ForegroundColor Yellow
Write-Host ("=" * 57) -ForegroundColor Yellow
Write-Host ""
Write-Host ("  Mean gap  : {0,7:F2} ms  (avg silence between clips)" -f $mean)
Write-Host ("  Std-dev   : {0,7:F2} ms" -f $stddev)

$maxColor = if ($maxGap -gt 100) { "Red" } elseif ($maxGap -gt 50) { "Yellow" } else { "Green" }
$minColor = if ($minGap -lt -20) { "Red" } elseif ($minGap -lt  0) { "Yellow" } else { "Green" }

Write-Host ("  Max gap   : {0,7:F2} ms  (worst dead-air)"  -f $maxGap) -ForegroundColor $maxColor
Write-Host ("  Min gap   : {0,7:F2} ms  (worst overlap)"   -f $minGap) -ForegroundColor $minColor
Write-Host ("  Overlaps  : {0,7}   (gap < -20 ms; words cut off)"        -f $overlaps) -ForegroundColor $(if ($overlaps -gt 0) {"Yellow"} else {"Green"})
Write-Host ("  Long gaps : {0,7}   (gap >  80 ms; noticeable pause)"     -f $longGaps) -ForegroundColor $(if ($longGaps  -gt 5) {"Red"} elseif ($longGaps -gt 0) {"Yellow"} else {"Green"})
Write-Host ("  No phraseDur : {0,4}   (OGG on disk but no duration entry)"    -f $noRec.Count)
Write-Host ("  No OGG       : {0,4}   (phraseDur entry but file missing)"      -f $noAct.Count)
Write-Host ""

Write-Host "  Top 15 largest gaps (phraseDur > actual -> silence between clips):" -ForegroundColor Cyan
$matched | Sort-Object Gap_ms -Descending | Select-Object -First 15 |
    Format-Table Token, Rec_s, Act_s, Gap_ms -AutoSize

if ($overlaps -gt 0) {
    Write-Host "  Clips that overlap (phraseDur < actual -> word cut off):" -ForegroundColor Yellow
    $matched | Where-Object { $_.Gap_ms -lt -20 } | Sort-Object Gap_ms |
        Format-Table Token, Rec_s, Act_s, Gap_ms -AutoSize
}

if ($noRec.Count -gt 0) {
    Write-Host "  OGGs with no phraseDur entry (DCS uses 0.45 s fallback):" -ForegroundColor DarkYellow
    $noRec | Select-Object -First 20 | Format-Table Token, Act_s -AutoSize
}

# ===========================================================================
# 3. Stitch representative ATC messages
# ===========================================================================
# Token sequences reflect what ATC_Script.textToTokens() produces for
# real ATC transmissions.  Only tokens with confirmed OGG files are used.

$samples = [ordered]@{

    "01_inbound_call" = @(
        # "Batumi Approach,  Colt 11,  for landing"
        "batumi-approach", "colt", "one", "one", "for-landing"
    )

    "02_radar_contact_vectors" = @(
        # "Colt 11, Batumi Approach. Radar contact you are 25 NM north.
        #  Fly heading 1 3 0 for 18 miles, descend to 4 thousand feet."
        "colt", "one", "one", "batumi-approach",
        "radar-contact-you-are", "two", "five", "nautical-miles", "north",
        "fly-heading", "one", "three", "zero",
        "for", "eighteen", "miles",
        "descend-to", "four", "thousand", "feet"
    )

    "03_hold_and_sequence" = @(
        # "Colt 11, maintain 5 thousand feet.
        #  Expect vectors to runway 1 3.  You are number 2."
        "colt", "one", "one",
        "maintain", "five", "thousand", "feet",
        "expect-vectors-to-runway", "one", "three",
        "you-are-number", "two"
    )

    "04_cleared_to_land" = @(
        # "Colt 11, turn final heading 1 3 0.  Cleared to land runway 1 3."
        "colt", "one", "one",
        "turn-final-heading", "one", "three", "zero",
        "cleared-to-land", "runway", "one", "three"
    )

    "05_go_around" = @(
        # "Colt 11, go around go around.  Climb immediately runway heading."
        "colt", "one", "one",
        "go-around-go-around",
        "climb-immediately-runway-heading"
    )

    "06_contact_tower" = @(
        # "Colt 11, contact Batumi Tower on 1 2 0 point 1.  Have a good day."
        "colt", "one", "one",
        "contact", "batumi-tower",
        "one", "two", "zero", "point", "one", "MHz",
        "have-a-good-day"
    )
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

Write-Host ("=" * 57) -ForegroundColor Yellow
Write-Host "  STITCHED MESSAGE PLAYBACK TESTS" -ForegroundColor Yellow
Write-Host ("=" * 57) -ForegroundColor Yellow

$fallbackDur = 0.45   # seconds -- used by DCS when no phraseDur entry exists

foreach ($name in $samples.Keys) {
    $tokens = $samples[$name]
    Write-Host ""
    Write-Host "  [$name]" -ForegroundColor Cyan

    $oggPaths   = [System.Collections.Generic.List[string]]::new()
    $schedTime  = 0.0
    $missingOgg = 0
    $missingDur = 0

    foreach ($tok in $tokens) {
        $oggPath = Join-Path $voiceDir "$tok.ogg"
        $recDur  = if ($vDur.ContainsKey($tok)) { $vDur[$tok] } else { $fallbackDur }
        $hasDur  = $vDur.ContainsKey($tok)
        $hasOgg  = Test-Path $oggPath

        $flag = ""
        if (-not $hasOgg) { $flag += "  [OGG MISSING]";  $missingOgg++ }
        if (-not $hasDur) { $flag += "  [no phraseDur]"; $missingDur++ }

        $color = if (-not $hasOgg) { "DarkRed" } elseif (-not $hasDur) { "DarkYellow" } else { "DarkGray" }
        Write-Host ("    t={0:F3}s  +{1:F3}s  {2}{3}" -f $schedTime, $recDur, $tok, $flag) -ForegroundColor $color

        if ($hasOgg) { $oggPaths.Add($oggPath) }
        $schedTime += $recDur
    }

    Write-Host ("    --- total: {0:F2} s scheduled  |  {1} tokens  |  {2} missing OGG  |  {3} missing dur" `
        -f $schedTime, $tokens.Count, $missingOgg, $missingDur)

    if ($oggPaths.Count -lt 2) {
        Write-Host "    Skipping render -- too many missing clips." -ForegroundColor DarkYellow
        continue
    }

    $outWav = Join-Path $OutDir "$name-${Voice}.wav"
    Write-Host "    Rendering -> $outWav ..." -NoNewline -ForegroundColor DarkCyan

    try {
        Join-AudioFiles -OggPaths $oggPaths.ToArray() -OutWav $outWav

        $actualLen = Measure-AudioDuration $outWav
        if ($null -ne $actualLen) {
            $diffMs  = [math]::Round(($actualLen - $schedTime) * 1000, 1)
            $sign    = if ($diffMs -ge 0) { "+" } else { "" }
            Write-Host (" done.  WAV: {0:F2}s  scheduled: {1:F2}s  diff: {2}{3}ms" -f `
                $actualLen, $schedTime, $sign, $diffMs) -ForegroundColor Green
        } else {
            Write-Host " done (WAV probe failed -- file may not exist)." -ForegroundColor Yellow
        }

        if ($Play -and (Test-Path $outWav)) {
            Start-Process -FilePath $outWav
        }
    } catch {
        Write-Host " FAILED: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done.  Output WAVs saved in: $OutDir" -ForegroundColor Green
if (-not $Play) {
    Write-Host "Tip: re-run with -Play to open each WAV, or browse: explorer `"$OutDir`"" -ForegroundColor DarkGray
}
