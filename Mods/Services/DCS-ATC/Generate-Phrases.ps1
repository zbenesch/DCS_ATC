<#
.SYNOPSIS
    Generates OGG phrase files for the DCS ATC phrase-stitching audio system
    using the ElevenLabs text-to-speech API.

.DESCRIPTION
    Calls the ElevenLabs API for each phrase × voice combination, retrieves MP3
    audio, applies a narrow-band radio effect via FFmpeg (300-3400 Hz bandpass),
    converts to OGG Vorbis (mono 44100 Hz), and patches the Lua duration manifest
    back into ATC_Script.lua between PHRASE_DUR_START / PHRASE_DUR_END markers.

.PARAMETER ApiKey
    ElevenLabs API key.  Required.

.PARAMETER OutDir
    Root folder to write voice sub-folders into.
    Default: <script dir>\phrases

.PARAMETER ScriptPath
    Path to ATC_Script.lua to patch the duration table.
    Default: <script dir>\Scripts\ATC_Script.lua

.PARAMETER FFmpeg
    Path to ffmpeg.exe.  Defaults to "ffmpeg" (assumes it is in PATH).

.PARAMETER NoRadioEffect
    Skip the radio bandpass filter - output clean TTS audio.

.EXAMPLE
    .\Generate-Phrases.ps1 -ApiKey "sk_..."
    .\Generate-Phrases.ps1 -ApiKey "sk_..." -FFmpeg "E:\downloader\ffmpeg.exe"
#>
param(
    [Parameter(Mandatory)][string]$ApiKey,
    [string]$OutDir     = "$PSScriptRoot\phrases",
    [string]$ScriptPath = "$PSScriptRoot\Scripts\ATC_Script.lua",
    [string]$FFmpeg     = "ffmpeg",
    [switch]$NoRadioEffect
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Verify FFmpeg / FFprobe ---------------------------------------------------
try { Start-Process -FilePath $FFmpeg -ArgumentList "-version" `
        -Wait -NoNewWindow `
        -RedirectStandardOutput "$env:TEMP\ffver.txt" `
        -RedirectStandardError  "$env:TEMP\ffver_err.txt" | Out-Null }
catch {
    Write-Error "FFmpeg not found at '$FFmpeg'.  Pass -FFmpeg <path>."
    exit 1
}

# -- Radio effect filter chain -------------------------------------------------
# Narrow-band AM radio: 300-3400 Hz bandpass + slight treble clarity boost.
# This is applied during MP3 -> OGG conversion.
$RadioFilter = "highpass=f=300,lowpass=f=3400,treble=g=5,volume=1.4"

# -- ElevenLabs voice definitions ----------------------------------------------
# folder-key must match the voice folder names referenced in ATC_Script.lua
$Voices = [ordered]@{
    "daniel" = "onwK4e9ZLuTAKqWW03F9"   # Daniel - British male, broadcaster
    "adam"   = "pNInz6obpgDQGcFmaJgB"   # Adam   - American male, firm
    "alice"  = "Xb7hH8MSUJpSbSDYk0k2"   # Alice  - British female, professional
}

# Phrase frequency mapping: token-name -> frequency
$PhraseFrequency = [ordered]@{
    # Approach
    "approach" = "approach"
    "continue-approach" = "approach"
    "expect-vectors-to-runway" = "approach"
    "radar-contact" = "approach"
    "descend-to" = "approach"
    "climb-to" = "approach"
    "report-final" = "approach"
    "cleared-for-the-approach" = "approach"
    "established-on-final" = "approach"
    "turn-final-heading" = "approach"
    "base-heading" = "approach"
    "abeam-the-threshold" = "approach"
    "on-base-runway" = "approach"
    "maintain" = "approach"
    # Tower
    "tower" = "tower"
    "request-takeoff" = "tower"
    "ready-for-departure" = "tower"
    "request-landing" = "tower"
    "on-this-frequency" = "tower"
    "from-threshold" = "tower"
    "runway-clear" = "tower"
    "you-are-number" = "tower"
    "slow-to-approach-speed" = "tower"
    "check-gear-down-and-locked" = "tower"
    "go-around-go-around" = "tower"
    "airspeed-critically-low" = "tower"
    "climb-immediately-runway-heading" = "tower"
    # Ground
    "ground" = "ground"
    "request-startup" = "ground"
    "request-taxi" = "ground"
    "hold" = "ground"
    "expect" = "ground"
    # Add more mappings as needed
}

# Voice assignment by frequency
$FrequencyVoice = [ordered]@{
    "approach" = "daniel"
    "tower" = "adam"
    "ground" = "alice"
}

# -- Phrases dictionary: token-name -> spoken text ----------------------------
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

    # -- Heading instruction chunks --------------------------------------------
    "fly-heading"         = "fly heading"
    "turn-left-heading"   = "turn left heading"
    "turn-right-heading"  = "turn right heading"
    "maintain"            = "maintain"
    "descend-to"          = "descend to"
    "climb-to"            = "climb to"
    "reduce-speed-to"     = "reduce speed to"
    "increase-speed-to"   = "increase speed to"

    # -- Pattern advisories ---------------------------------------------------
    "abeam-the-threshold"  = "abeam the threshold"
    "on-base-runway"       = "on base, runway"
    "base-heading"         = "base heading"
    "turn-final-heading"   = "turn final heading"
    "established-on-final" = "established on final"
    "continue-approach"    = "continue approach"

    # -- Approach clearance ---------------------------------------------------
    "cleared-for-the-approach"   = "cleared for the approach"
    "runway-clear"               = "runway clear"
    "you-are-number"             = "you are number"
    "report-final"               = "report final"
    "radar-contact"              = "radar contact"
    "expect-vectors-to-runway"   = "expect vectors to runway"

    # -- Tower handoff --------------------------------------------------------
    "on-this-frequency" = "on this frequency"
    "from-threshold"    = "from threshold"

    # -- Gear / speed reminder ------------------------------------------------
    "slow-to-approach-speed"     = "slow to approach speed"
    "check-gear-down-and-locked" = "check gear down and locked"

    # -- Emergency / go-around ------------------------------------------------
    "go-around-go-around"             = "go around, go around"
    "airspeed-critically-low"         = "airspeed critically low"
    "climb-immediately-runway-heading" = "climb immediately, runway heading"

    # -- NATO phonetic alphabet -----------------------------------------------
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

    # -- Common DCS player callsign words -------------------------------------
    "enfield"     = "enfield"
    "springfield" = "springfield"
    "uzi"         = "uzi"
    "colt"        = "colt"
    "dodge"       = "dodge"
    "ford"        = "ford"
    "chevy"       = "chevy"
    "pontiac"     = "pontiac"
    "lobo"        = "lobo"
    "hawg"        = "hawg"
    "olds"        = "olds"
    "lincoln"     = "lincoln"
    "jedi"        = "jedi"
    "viper"       = "viper"
    "venom"       = "venom"
    "witch"       = "witch"
    "cobra"       = "cobra"
    "bone"        = "bone"
    "mako"        = "mako"
    "dude"        = "dude"
    "tiger"       = "tiger"
    "wolf"        = "wolf"
    "weasel"      = "weasel"
    "panther"     = "panther"
    "hawk"        = "hawk"
    "reaper"      = "reaper"
    "ghost"       = "ghost"
    "eagle"       = "eagle"
    "shark"       = "shark"
    "sniper"      = "sniper"
    "lancer"      = "lancer"
    "devil"       = "devil"
    "rebel"       = "rebel"
    "storm"       = "storm"
    "talon"       = "talon"

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

    # -- Persian Gulf airfield words ------------------------------------------
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

    # -- Syria / other theater words ------------------------------------------
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

# -- Helper: get audio duration using ffmpeg -i (no ffprobe needed) ------------
function Get-AudioDuration([string]$Path) {
    $tmpErr = "$env:TEMP\ffmpeg_info_err.txt"
    # ffmpeg -i <file> with no output file always exits 1, but writes
    # stream metadata (including Duration) to stderr.
    Start-Process -FilePath $FFmpeg `
        -ArgumentList "-i `"$Path`"" `
        -Wait -NoNewWindow `
        -RedirectStandardOutput "$env:TEMP\ffmpeg_info_out.txt" `
        -RedirectStandardError  $tmpErr | Out-Null
    try {
        $info = Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue
        if ($info -match 'Duration:\s*(\d+):(\d+):([0-9.]+)') {
            return ([int]$Matches[1] * 3600) + ([int]$Matches[2] * 60) + [double]$Matches[3]
        }
    } catch {}
    return 0.5
}

# -- Helper: call ElevenLabs TTS with retry on rate-limit ---------------------
function Invoke-ElevenLabsTTS {
    param([string]$Text, [string]$VoiceId, [string]$OutPath)

    $body = @{
        text       = $Text
        model_id   = "eleven_turbo_v2_5"
        voice_settings = @{
            stability        = 0.75
            similarity_boost = 0.85
            style            = 0.0   # no style exaggeration for clean ATC delivery
            use_speaker_boost = $true
        }
    } | ConvertTo-Json -Depth 5

    $headers = @{
        "xi-api-key"   = $ApiKey
        "Content-Type" = "application/json"
    }

    $uri = "https://api.elevenlabs.io/v1/text-to-speech/$VoiceId" +
           "?output_format=mp3_44100_128"

    $attempts = 0
    while ($true) {
        $attempts++
        try {
            Invoke-RestMethod -Uri $uri -Method POST `
                -Headers $headers -Body $body -OutFile $OutPath
            return
        } catch {
            $status = $_.Exception.Response.StatusCode.Value__
            if ($status -eq 429 -and $attempts -lt 4) {
                Write-Warning "  Rate limited - waiting 10 s (attempt $attempts)"
                Start-Sleep -Seconds 10
            } else {
                throw
            }
        }
    }
}

# -- Main generation loop ------------------------------------------------------
$durations  = @{}
$totalFiles = $Voices.Count * $Phrases.Count
$done       = 0

$radioNote = if ($NoRadioEffect) { "(no radio effect)" } else { "(radio effect ON)" }
Write-Host "`nGenerating $totalFiles clips for $($Voices.Count) voices $radioNote" -ForegroundColor Cyan

foreach ($phrase in $Phrases.GetEnumerator()) {
    $token   = $phrase.Key
    $text    = $phrase.Value
    $frequency = $PhraseFrequency[$token]
    if (-not $frequency) { continue }
    $voiceKey = $FrequencyVoice[$frequency]
    $voiceId = $Voices[$voiceKey]
    $voiceDir = Join-Path $OutDir $voiceKey
    New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null
    $mp3Path = Join-Path $voiceDir "$token.mp3"
    $oggPath = Join-Path $voiceDir "$token.ogg"

    # Skip if OGG already exists and is non-empty (resume support)
    if ((Test-Path $oggPath) -and (Get-Item $oggPath).Length -gt 1000) {
        $dur = Get-AudioDuration $oggPath
        $durations["$voiceKey/$token"] = [Math]::Round($dur, 3)
        $done++
        continue
    }

    # Call ElevenLabs API
    try {
        Invoke-ElevenLabsTTS -Text $text -VoiceId $voiceId -OutPath $mp3Path
    } catch {
        Write-Warning "  ElevenLabs failed for '$token': $_"
        $done++
        continue
    }

    # Get duration from the MP3
    $dur = Get-AudioDuration $mp3Path

    # Build FFmpeg argument list
    if ($NoRadioEffect) {
        $afArgs = "-ar 44100 -ac 1 -c:a libvorbis -q:a 4"
    } else {
        $afArgs = "-af `"$RadioFilter`" -ar 44100 -ac 1 -c:a libvorbis -q:a 4"
    }

    $proc = Start-Process -FilePath $FFmpeg `
        -ArgumentList "-y -i `"$mp3Path`" $afArgs `"$oggPath`"" `
        -Wait -PassThru -NoNewWindow `
        -RedirectStandardOutput "$env:TEMP\ffmpeg_stdout.txt" `
        -RedirectStandardError  "$env:TEMP\ffmpeg_stderr.txt"

    if ($proc.ExitCode -ne 0) {
        $errText = Get-Content "$env:TEMP\ffmpeg_stderr.txt" -Raw -ErrorAction SilentlyContinue
        Write-Warning "  FFmpeg failed for '$token' (exit $($proc.ExitCode)): $errText"
    }

    Remove-Item $mp3Path -Force -ErrorAction SilentlyContinue

    $durations["$voiceKey/$token"] = [Math]::Round($dur, 3)
    $done++

    Write-Progress -Activity "Generating phrases" `
        -Status "$voiceKey/$token  ($done / $totalFiles)" `
        -PercentComplete ([int](100 * $done / $totalFiles))

    # Small pause to be polite to the API
    Start-Sleep -Milliseconds 150
}

Write-Progress -Activity "Generating phrases" -Completed

# -- Scan all existing OGGs for durations (covers tokens skipped by frequency filter) --
foreach ($vk in $Voices.Keys) {
    $vDir = Join-Path $OutDir $vk
    if (-not (Test-Path $vDir)) { continue }
    foreach ($ogg in (Get-ChildItem $vDir -Filter "*.ogg")) {
        $key = "$vk/$($ogg.BaseName)"
        if (-not $durations.ContainsKey($key)) {
            $durations[$key] = [Math]::Round((Get-AudioDuration $ogg.FullName), 3)
        }
    }
}

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
        Write-Warning "Markers not found in '$ScriptPath'.  Writing to: $PSScriptRoot\ATC_phrase_dur.lua"
        Set-Content -Path "$PSScriptRoot\ATC_phrase_dur.lua" -Value $manifest
    }
}

Write-Host "`nDone." -ForegroundColor Yellow
