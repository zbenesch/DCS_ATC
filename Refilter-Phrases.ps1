#Requires -Version 5.1
<#
.SYNOPSIS
  Re-applies the radio filter to existing OGG clips without calling ElevenLabs.
  Use this to hear the improved filter before doing a full regeneration.

.PARAMETER Voice
  Process only this voice folder.  Omit to process all voices.

.PARAMETER FFmpeg
  Path to ffmpeg.exe.

.PARAMETER PhrasesDir
  Root phrases directory (contains adam/, alice/, ... sub-folders).

.PARAMETER Filter
  Full FFmpeg -af filter string.  Defaults to the current production filter.

.PARAMETER Force
  Overwrite in-place even if a .bak already exists.
#>
param(
    [string]   $Voice      = "",
    [string]   $FFmpeg     = "E:\downloader\ffmpeg.exe",
    [string]   $PhrasesDir = "K:\DCS_ATC\Mods\Services\DCS-ATC\phrases",
    [string]   $Filter     = "",
    [switch]   $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Default filter matches Generate-Phrases.ps1 production filter
if ($Filter -eq "") {
    $SilenceTrim = "silenceremove=start_periods=1:start_threshold=-55dB:start_duration=0.005"
    $Filter = "$SilenceTrim," +
        "acompressor=threshold=-25dB:ratio=4:attack=5:release=80:knee=2:makeup=5," +
        "highpass=f=300:poles=2,highpass=f=300:poles=2," +
        "lowpass=f=3000:poles=2,lowpass=f=3000:poles=2," +
        "equalizer=f=1200:t=o:w=2:g=4," +
        "volume=1.5"
}

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
    return @{ ExitCode=$proc.ExitCode; Output=($stdout+$stderr) }
}

$voiceDirs = if ($Voice -ne "") {
    @(Join-Path $PhrasesDir $Voice)
} else {
    @(Get-ChildItem $PhrasesDir -Directory | Select-Object -ExpandProperty FullName)
}

Write-Host ""
Write-Host "Re-filter: $($voiceDirs.Count) voice folder(s)" -ForegroundColor Cyan
Write-Host "Filter   : $Filter" -ForegroundColor DarkGray
Write-Host ""

$total = 0; $ok = 0; $fail = 0

foreach ($dir in $voiceDirs) {
    if (-not (Test-Path $dir)) { Write-Warning "Not found: $dir"; continue }
    $vname = Split-Path $dir -Leaf
    $oggs  = @(Get-ChildItem $dir -Filter "*.ogg" | Where-Object { $_.Name -notmatch '\.bak\.ogg$' })
    Write-Host "  $vname : $($oggs.Count) clips" -ForegroundColor Yellow

    foreach ($f in $oggs) {
        $bak = $f.FullName -replace '\.ogg$', '.bak.ogg'
        $tmp = $f.FullName -replace '\.ogg$', '.tmp.ogg'

        # Back up original on first run
        if (-not (Test-Path $bak)) {
            Copy-Item $f.FullName $bak
        } elseif (-not $Force) {
            # Already re-filtered once — re-filter FROM the backup so we don't chain filters
        }

        # Always filter from the backup (clean ElevenLabs audio)
        $src = if (Test-Path $bak) { $bak } else { $f.FullName }

        $r = Invoke-FFmpeg -ArgList @(
            "-hide_banner", "-loglevel", "error", "-y",
            "-i", "`"$src`"",
            "-af", "`"$Filter`"",
            "-ar", "44100", "-ac", "1",
            "-c:a", "libvorbis", "-q:a", "4",
            "`"$tmp`""
        )

        if ($r.ExitCode -ne 0 -or -not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 500) {
            Write-Warning "    FAIL $($f.Name): $($r.Output.Trim())"
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            $fail++
        } else {
            Move-Item $tmp $f.FullName -Force
            $ok++
        }
        $total++
    }
}

Write-Host ""
Write-Host "Done.  $ok / $total re-filtered  ($fail failures)" -ForegroundColor $(if ($fail -eq 0) {"Green"} else {"Yellow"})
Write-Host "Originals backed up as *.bak.ogg alongside each clip." -ForegroundColor DarkGray
Write-Host "To revert: rename *.bak.ogg back to *.ogg  (or re-run Generate-Phrases.ps1 -Force)" -ForegroundColor DarkGray
