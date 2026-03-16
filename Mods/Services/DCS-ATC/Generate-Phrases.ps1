<#
.SYNOPSIS
    Generates OGG phrase files for the DCS ATC phrase-stitching audio system.

.DESCRIPTION
    Uses Windows SAPI TTS to synthesise each phrase as a WAV, then converts to OGG
    Vorbis (mono 44100 Hz 48 kbps) using FFmpeg.  Writes a Lua duration manifest
    section back into ATC_Script.lua between its PHRASE_DUR_START / PHRASE_DUR_END markers.

.PARAMETER OutDir
    Root folder to write voice sub-folders into.
    Default: <script dir>\phrases

.PARAMETER ScriptPath
    Path to ATC_Script.lua to patch the duration table.
    Default: <script dir>\..\ATC_Script.lua

.PARAMETER FFmpeg
    Path to ffmpeg.exe.  Defaults to "ffmpeg" (assumes it is in PATH).

.EXAMPLE
    .\Generate-Phrases.ps1
    .\Generate-Phrases.ps1 -FFmpeg "C:\tools\ffmpeg\bin\ffmpeg.exe"
#>
param(
    [string]$OutDir     = "$PSScriptRoot\phrases",
    [string]$ScriptPath = "$PSScriptRoot\Scripts\ATC_Script.lua",
    [string]$FFmpeg     = "ffmpeg"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Verify FFmpeg -------------------------------------------------------------
try { & $FFmpeg -version 2>&1 | Out-Null }
catch {
    Write-Error "FFmpeg not found at '$FFmpeg'.  Install FFmpeg and add it to PATH, or pass -FFmpeg <path>."
    exit 1
}
$FFprobe = $FFmpeg -replace "ffmpeg(\.exe)?$","ffprobe`$1"

# -- Phrases dictionary: token-name → spoken text -----------------------------
# Token name is used as the filename (without .ogg) and as the Lua table key.
$Phrases = [ordered]@{
    # -- Digits (ATC pronunciation) --------------------------------------------
    "zero"   = "zero"
    "one"    = "one"
    "two"    = "two"
    "three"  = "three"
    "four"   = "four"
    "five"   = "five"
    "six"    = "six"
    "seven"  = "seven"
    "eight"  = "eight"
    "niner"  = "niner"

    # -- Units -----------------------------------------------------------------
    "feet"           = "feet"
    "knots"          = "knots"
    "nautical-miles" = "nautical miles"

    # -- Controller roles ------------------------------------------------------
    "approach"  = "approach"
    "tower"     = "tower"
    "ground"    = "ground"
    "departure" = "departure"

    # -- Individual connector words --------------------------------------------
    "contact" = "contact"
    "runway"  = "runway"
    "left"    = "left"
    "right"   = "right"
    "traffic" = "traffic"
    "number"  = "number"
    "speed"   = "speed"
    "out"     = "out"
    "at"      = "at"
    "follow"  = "follow"
    "and"     = "and"
    "for"     = "for"
    "hold"    = "hold"
    "expect"  = "expect"

    # -- Heading instruction chunks ---------------------------------------------
    "fly-heading"         = "fly heading"
    "turn-left-heading"   = "turn left heading"
    "turn-right-heading"  = "turn right heading"
    "maintain"            = "maintain"
    "descend-to"          = "descend to"
    "climb-to"            = "climb to"
    "reduce-speed-to"     = "reduce speed to"
    "increase-speed-to"   = "increase speed to"

    # -- Pattern advisories ----------------------------------------------------
    "abeam-the-threshold"  = "abeam the threshold"
    "on-base-runway"       = "on base, runway"
    "base-heading"         = "base heading"
    "turn-final-heading"   = "turn final heading"
    "established-on-final" = "established on final"
    "continue-approach"    = "continue approach"

    # -- Approach clearance ----------------------------------------------------
    "cleared-for-the-approach"   = "cleared for the approach"
    "runway-clear"               = "runway clear"
    "you-are-number"             = "you are number"
    "report-final"               = "report final"
    "radar-contact"              = "radar contact"
    "expect-vectors-to-runway"   = "expect vectors to runway"

    # -- Tower handoff ---------------------------------------------------------
    "on-this-frequency" = "on this frequency"
    "from-threshold"    = "from threshold"

    # -- Gear / speed reminder -------------------------------------------------
    "slow-to-approach-speed"     = "slow to approach speed"
    "check-gear-down-and-locked" = "check gear down and locked"

    # -- Emergency / go-around -------------------------------------------------
    "go-around-go-around"             = "go around, go around"
    "airspeed-critically-low"         = "airspeed critically low"
    "climb-immediately-runway-heading" = "climb immediately, runway heading"

    # -- NATO phonetic alphabet ------------------------------------------------
    "alpha"    = "alpha"
    "bravo"    = "bravo"
    "charlie"  = "charlie"
    "delta"    = "delta"
    "echo"     = "echo"
    "foxtrot"  = "foxtrot"
    "golf"     = "golf"
    "hotel"    = "hotel"
    "india"    = "india"
    "juliet"   = "juliet"
    "kilo"     = "kilo"
    "lima"     = "lima"
    "mike"     = "mike"
    "november" = "november"
    "oscar"    = "oscar"
    "papa"     = "papa"
    "quebec"   = "quebec"
    "romeo"    = "romeo"
    "sierra"   = "sierra"
    "tango"    = "tango"
    "uniform"  = "uniform"
    "victor"   = "victor"
    "whiskey"  = "whiskey"
    "xray"     = "x-ray"
    "yankee"   = "yankee"
    "zulu"     = "zulu"

    # -- Common DCS player callsign words --------------------------------------
    "enfield"    = "enfield"
    "springfield" = "springfield"
    "uzi"        = "uzi"
    "colt"       = "colt"
    "dodge"      = "dodge"
    "ford"       = "ford"
    "chevy"      = "chevy"
    "pontiac"    = "pontiac"
    "lobo"       = "lobo"
    "hawg"       = "hawg"
    "olds"       = "olds"
    "lincoln"    = "lincoln"
    "jedi"       = "jedi"
    "viper"      = "viper"
    "venom"      = "venom"
    "witch"      = "witch"
    "cobra"      = "cobra"
    "bone"       = "bone"
    "mako"       = "mako"
    "dude"       = "dude"
    "tiger"      = "tiger"
    "wolf"       = "wolf"
    "weasel"     = "weasel"
    "panther"    = "panther"
    "hawk"       = "hawk"
    "reaper"     = "reaper"
    "ghost"      = "ghost"
    "eagle"      = "eagle"
    "shark"      = "shark"
    "sniper"     = "sniper"
    "lancer"     = "lancer"
    "devil"      = "devil"
    "rebel"      = "rebel"
    "storm"      = "storm"
    "talon"      = "talon"

    # -- Caucasus airfield words -----------------------------------------------
    "batumi"       = "batumi"
    "kobuleti"     = "kobuleti"
    "kutaisi"      = "kutaisi"
    "senaki"       = "senaki"
    "kolkhi"       = "kolkhi"
    "sukhumi"      = "sukhumi"
    "gudauta"      = "gudauta"
    "sochi"        = "sochi"
    "adler"        = "adler"
    "gelendzhik"   = "gelendzhik"
    "anapa"        = "anapa"
    "vityazevo"    = "vityazevo"
    "krasnodar"    = "krasnodar"
    "krymsk"       = "krymsk"
    "novorossiysk" = "novorossiysk"
    "tbilisi"      = "tbilisi"
    "lochini"      = "lochini"
    "vaziani"      = "vaziani"
    "soganlug"     = "soganlug"
    "beslan"       = "beslan"
    "mozdok"       = "mozdok"
    "nalchik"      = "nalchik"
    "mineralnye"   = "mineralnye"
    "vody"         = "vody"
    "maykop"       = "maykop"
    "pashkovsky"   = "pashkovsky"

    # -- Persian Gulf airfield words -------------------------------------------
    "abu"      = "abu"
    "dhabi"    = "dhabi"
    "ain"      = "ain"
    "bateen"   = "bateen"
    "al"       = "al"
    "dhafra"   = "dhafra"
    "maktoum"  = "maktoum"
    "minhad"   = "minhad"
    "dubai"    = "dubai"
    "fujairah" = "fujairah"
    "kish"     = "kish"
    "bandar"   = "bandar"
    "abbas"    = "abbas"
    "qeshm"    = "qeshm"
    "lavan"    = "lavan"
    "lar"      = "lar"
    "jiroft"   = "jiroft"
    "kerman"   = "kerman"
    "shiraz"   = "shiraz"
    "sharjah"  = "sharjah"
    "tunb"     = "tunb"
    "sirri"    = "sirri"
    "musa"     = "musa"

    # -- Syria / other theater words -------------------------------------------
    "incirlik"   = "incirlik"
    "akrotiri"   = "akrotiri"
    "hatay"      = "hatay"
    "adana"      = "adana"
    "sakirpasa"  = "sakirpasa"
    "damascus"   = "damascus"
    "beirut"     = "beirut"
    "halab"      = "halab"
    "taftanaz"   = "taftanaz"
    "ramat"      = "ramat"
    "david"      = "david"
    "ovda"       = "ovda"
    "eilat"      = "eilat"
    "haifa"      = "haifa"
    "bagram"     = "bagram"
    "kandahar"   = "kandahar"
    "kabul"      = "kabul"
    "baghdad"    = "baghdad"
    "kirkuk"     = "kirkuk"
    "erbil"      = "erbil"
    "murmansk"   = "murmansk"
    "carpiquet"  = "carpiquet"
    "evreux"     = "evreux"
    "cairo"      = "cairo"
    "normandy"   = "normandy"
}

# -- Voices: folder-name → SAPI display name pattern --------------------------
$Voices = [ordered]@{
    "david" = "Microsoft David"
    "zira"  = "Microsoft Zira"
    "mark"  = "Microsoft Mark"
}

# -- Helper: read WAV duration (seconds) from PCM header ----------------------
function Get-WavDuration([string]$Path) {
    $reader = [System.IO.BinaryReader][System.IO.File]::OpenRead($Path)
    try {
        $reader.BaseStream.Seek(24, 'Begin') | Out-Null  # sample rate field
        $sampleRate = [BitConverter]::ToInt32($reader.ReadBytes(4), 0)
        $reader.BaseStream.Seek(4, 'Current') | Out-Null  # skip ByteRate, BlockAlign
        $reader.BaseStream.Seek(2, 'Current') | Out-Null
        $bitsPerSample = [BitConverter]::ToInt16($reader.ReadBytes(2), 0)
        # Find 'data' chunk (skip any 'fmt ' extension chunks)
        $reader.BaseStream.Seek(12, 'Begin') | Out-Null
        while ($reader.BaseStream.Position -lt ($reader.BaseStream.Length - 8)) {
            $tag  = [System.Text.Encoding]::ASCII.GetString($reader.ReadBytes(4))
            $size = [BitConverter]::ToInt32($reader.ReadBytes(4), 0)
            if ($tag -eq "data") {
                return [double]$size / ($sampleRate * ($bitsPerSample / 8))
            }
            $reader.BaseStream.Seek($size, 'Current') | Out-Null
        }
    } finally { $reader.Close() }
    return 0.5  # fallback
}

# -- Initialise SAPI objects ---------------------------------------------------
$synth  = New-Object -ComObject SAPI.SpVoice
$stream = New-Object -ComObject SAPI.SpFileStream
$fmt    = New-Object -ComObject SAPI.SpAudioFormat
$fmt.Type = 34   # SAFT44kHz16BitMono

$availableVoices = $synth.GetVoices()

# -- Duration accumulator ------------------------------------------------------
# durations["david/zero"] = 0.42
$durations = @{}

$totalFiles = $Voices.Count * $Phrases.Count
$done = 0

foreach ($voiceEntry in $Voices.GetEnumerator()) {
    $folderKey = $voiceEntry.Key       # "david"
    $voicePattern = $voiceEntry.Value  # "Microsoft David"

    # Find matching SAPI voice
    $sapiVoice = $null
    for ($i = 0; $i -lt $availableVoices.Count; $i++) {
        if ($availableVoices.Item($i).GetDescription() -like "*$voicePattern*") {
            $sapiVoice = $availableVoices.Item($i)
            break
        }
    }
    if (-not $sapiVoice) {
        Write-Warning "Voice '$voicePattern' not found on this system - skipping."
        continue
    }
    $synth.Voice = $sapiVoice
    Write-Host "`n=== Voice: $($sapiVoice.GetDescription()) ===" -ForegroundColor Cyan

    $voiceDir = Join-Path $OutDir $folderKey
    New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null

    foreach ($phrase in $Phrases.GetEnumerator()) {
        $token = $phrase.Key    # "turn-left-heading"
        $text  = $phrase.Value  # "turn left heading"

        $wavPath = Join-Path $voiceDir "$token.wav"
        $oggPath = Join-Path $voiceDir "$token.ogg"

        # Generate WAV via SAPI
        $fmt.Type = 34
        try { $stream.Format = $fmt } catch {}
        $stream.Open($wavPath, 3)  # SSFMCreateForWrite
        $synth.AudioOutputStream = $stream
        $synth.Speak($text)
        $stream.Close()

        # Get duration from WAV header
        $dur = Get-WavDuration $wavPath

        # Convert WAV → OGG: mono, 44100 Hz, ~48 kbps.
        # Use Start-Process to avoid $ErrorActionPreference = "Stop" treating
        # FFmpeg's informational stderr output as a PowerShell error.
        $proc = Start-Process -FilePath $FFmpeg `
            -ArgumentList "-y -i `"$wavPath`" -ar 44100 -ac 1 -c:a libvorbis -q:a 3 `"$oggPath`"" `
            -Wait -PassThru -NoNewWindow `
            -RedirectStandardOutput "$env:TEMP\ffmpeg_stdout.txt" `
            -RedirectStandardError  "$env:TEMP\ffmpeg_stderr.txt"
        if ($proc.ExitCode -ne 0) {
            $errText = Get-Content "$env:TEMP\ffmpeg_stderr.txt" -Raw -ErrorAction SilentlyContinue
            Write-Warning "FFmpeg failed for $token (exit $($proc.ExitCode)): $errText"
        }

        # Keep WAV? No - delete to save space
        Remove-Item $wavPath -Force

        $durations["$folderKey/$token"] = [Math]::Round($dur, 3)
        $done++
        Write-Progress -Activity "Generating phrases" `
            -Status "$folderKey/$token ($done/$totalFiles)" `
            -PercentComplete ([int](100 * $done / $totalFiles))
    }
}

Write-Progress -Activity "Generating phrases" -Completed
Write-Host "`nGenerated $($durations.Count) clips into: $OutDir" -ForegroundColor Green

# -- Build Lua duration table --------------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- PHRASE_DUR_START (auto-generated by Generate-Phrases.ps1 - do not edit manually)")
$lines.Add("ATC._phraseDur = {")
foreach ($kv in ($durations.GetEnumerator() | Sort-Object Key)) {
    $lines.Add("    [`"$($kv.Key)`"] = $($kv.Value),")
}
$lines.Add("}")
$lines.Add("-- PHRASE_DUR_END")

$manifest = $lines -join "`n"

# -- Patch ATC_Script.lua ------------------------------------------------------
if (Test-Path $ScriptPath) {
    $src = [System.IO.File]::ReadAllText($ScriptPath)
    if ($src -match '(?s)-- PHRASE_DUR_START.*?-- PHRASE_DUR_END') {
        $src = $src -replace '(?s)-- PHRASE_DUR_START.*?-- PHRASE_DUR_END', $manifest
        [System.IO.File]::WriteAllText($ScriptPath, $src)
        Write-Host "Duration table patched into: $ScriptPath" -ForegroundColor Green
    } else {
        Write-Warning "Markers not found in '$ScriptPath'.  Writing manifest to: $PSScriptRoot\ATC_phrase_dur.lua"
        Set-Content -Path "$PSScriptRoot\ATC_phrase_dur.lua" -Value $manifest
    }
}

Write-Host "`nDone.  Phrases are in: $OutDir" -ForegroundColor Yellow
