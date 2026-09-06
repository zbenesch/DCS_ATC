#Requires -Version 5.1
<#
.SYNOPSIS
  Strips trailing silence from digit/number OGG clips so consecutive numbers
  like "one one" or "two five zero" play tight instead of spread apart.

  Uses the double-reverse silenceremove trick:
    silenceremove (leading) -> areverse -> silenceremove (trailing) -> areverse -> apad 25ms

  Only touches digit tokens; all other clips are left unchanged.
  Backs up originals as *.num.bak.ogg before first run.

.PARAMETER FFmpeg
.PARAMETER PhrasesDir
.PARAMETER Voice
  Re-process only this voice.  Omit for all voices.
.PARAMETER PadMs
  Silence pad added after trim (default 25 ms).  Lower = tighter.  0 = no gap.
#>
param(
    [string] $FFmpeg     = "E:\downloader\ffmpeg.exe",
    [string] $PhrasesDir = "K:\DCS_ATC\Mods\Services\DCS-ATC\phrases",
    [string] $PhraseDurLua = "K:\DCS_ATC\Mods\Services\DCS-ATC\Scripts\controllers\phrasedur.lua",
    [string] $Voice      = "",
    [int]    $PadMs      = 25
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Tokens that need tight trailing trim:  ICAO digits + spoken number words
$NumberTokens = @(
    # ICAO ATC digits (headings, frequencies, callsigns)
    "zero","one","two","three","four","five","six","seven","eight","niner",
    # Spoken word numbers (distances, QFE compound numbers)
    "nine","ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen",
    "seventeen","eighteen","nineteen","twenty","thirty","forty","fifty",
    "sixty","seventy","eighty","ninety"
)

function Invoke-FFmpeg {
    param([string[]]$ArgList)
    $psi                        = [System.Diagnostics.ProcessStartInfo]::new($FFmpeg)
    $psi.Arguments              = $ArgList -join ' '
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $out  = $proc.StandardOutput.ReadToEnd() + $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return @{ ExitCode=$proc.ExitCode; Output=$out }
}

function Get-ClipDuration {
    param([string]$Path)
    $raw = (Invoke-FFmpeg -ArgList @("-hide_banner","-i","`"$Path`"")).Output
    if ($raw -match 'Duration:\s*(\d+):(\d+):([\d.]+)') {
        return [math]::Round([double]$Matches[1]*3600 + [double]$Matches[2]*60 + [double]$Matches[3], 3)
    }
    return $null
}

# Build filter:
#   1. Remove leading silence
#   2. Reverse -> remove leading (= trailing of original) -> reverse back
#   3. Pad with PadMs of silence so digits don't completely run together
#   4. Full radio filter chain
# Leading silence: -55 dB (aggressive, safe — dead air before the word)
# Trailing silence: -40 dB with 10 ms hold (conservative — avoids eating quiet phoneme endings)
$SilLead = "silenceremove=start_periods=1:start_threshold=-55dB:start_duration=0.003"
$SilTail = "silenceremove=start_periods=1:start_threshold=-40dB:start_duration=0.01"
$padSec  = $PadMs / 1000.0
$Filter  = "$SilLead,areverse,$SilTail,areverse,apad=pad_dur=$padSec," +
           "acompressor=threshold=-25dB:ratio=4:attack=5:release=80:knee=2:makeup=5," +
           "highpass=f=300:poles=2,highpass=f=300:poles=2," +
           "lowpass=f=3000:poles=2,lowpass=f=3000:poles=2," +
           "equalizer=f=1200:t=o:w=2:g=4," +
           "volume=1.5"

$voiceDirs = if ($Voice -ne "") {
    @(Join-Path $PhrasesDir $Voice)
} else {
    @(Get-ChildItem $PhrasesDir -Directory |
      Where-Object { $_.Name -notmatch '\.bak' } |
      Select-Object -ExpandProperty FullName)
}

Write-Host ""
Write-Host "Tightening $($NumberTokens.Count) number tokens across $($voiceDirs.Count) voice(s)  (pad=${PadMs}ms)" -ForegroundColor Cyan
Write-Host "Filter: $Filter" -ForegroundColor DarkGray
Write-Host ""

$total = 0; $ok = 0; $fail = 0
$newDurations = @{}

foreach ($dir in $voiceDirs) {
    if (-not (Test-Path $dir)) { Write-Warning "Not found: $dir"; continue }
    $vName = Split-Path $dir -Leaf
    Write-Host "  $vName" -ForegroundColor Yellow

    foreach ($token in $NumberTokens) {
        $oggPath = Join-Path $dir "$token.ogg"
        if (-not (Test-Path $oggPath)) { continue }

        $bakPath = $oggPath -replace '\.ogg$', '.num.bak.ogg'
        $tmpPath = $oggPath -replace '\.ogg$', '.num.tmp.ogg'

        # Back up the clean (radio-filtered) version on first run
        if (-not (Test-Path $bakPath)) {
            Copy-Item $oggPath $bakPath
        }

        # Always process from the backup so we don't chain filters
        $src = if (Test-Path $bakPath) { $bakPath } else { $oggPath }

        $r = Invoke-FFmpeg -ArgList @(
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", "`"$src`"",
            "-af", "`"$Filter`"",
            "-ar", "44100", "-ac", "1",
            "-c:a", "libvorbis", "-q:a", "4",
            "`"$tmpPath`""
        )

        $total++
        $tmpDur  = if (Test-Path $tmpPath) { Get-ClipDuration $tmpPath } else { $null }
        $tooShort = ($null -eq $tmpDur) -or ($tmpDur -lt 0.12)   # < 120 ms = filter ate the speech

        if ($r.ExitCode -ne 0 -or $tooShort) {
            if ($tooShort) {
                Write-Warning "    REVERTED $vName/$token (output was ${tmpDur}s -- trailing threshold too aggressive, using backup)"
            } else {
                Write-Warning "    FAIL $vName/$token : $($r.Output.Trim())"
            }
            Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
            # Restore from backup so the clip is at least the radio-filtered version
            if (Test-Path $bakPath) {
                Copy-Item $bakPath $oggPath -Force
                $dur = Get-ClipDuration $oggPath
                if ($null -ne $dur) { $newDurations["$vName/$token"] = $dur }
                Write-Host ("    {0,-10}  {1:F3}s  [backup restored]" -f $token, $dur) -ForegroundColor DarkYellow
            }
            $fail++
        } else {
            Move-Item $tmpPath $oggPath -Force
            $dur = Get-ClipDuration $oggPath
            if ($null -ne $dur) { $newDurations["$vName/$token"] = $dur }
            Write-Host ("    {0,-10}  {1:F3}s" -f $token, $dur) -ForegroundColor DarkGray
            $ok++
        }
    }
}

Write-Host ""
Write-Host "$ok / $total clips re-filtered  ($fail failures)" -ForegroundColor $(if ($fail -eq 0) {"Green"} else {"Yellow"})

# Patch phrasedur.lua with updated durations for number tokens only
if ($newDurations.Count -gt 0 -and (Test-Path $PhraseDurLua)) {
    Write-Host "Patching phrasedur.lua ($($newDurations.Count) updated entries) ..." -ForegroundColor Cyan
    $lua = [System.IO.File]::ReadAllText($PhraseDurLua, [System.Text.Encoding]::UTF8)
    foreach ($kv in $newDurations.GetEnumerator()) {
        $key = [regex]::Escape($kv.Key)
        $lua = [regex]::Replace($lua, "(\[`"$key`"\]\s*=\s*)[\d.]+", "`${1}$($kv.Value)")
    }
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($PhraseDurLua, $lua, $utf8NoBom)
    Write-Host "Done." -ForegroundColor Green
}

Write-Host ""
Write-Host "Tip: re-run with -PadMs 15 (tighter) or -PadMs 40 (more space) to tune the gap." -ForegroundColor DarkGray
Write-Host "To revert: rename *.num.bak.ogg back to *.ogg  then run .\Update-PhraseDurations.ps1" -ForegroundColor DarkGray
