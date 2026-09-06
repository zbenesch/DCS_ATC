<#
.SYNOPSIS
    Generates OGG phrase files for the DCS ATC phrase-stitching audio system.
    Supports ElevenLabs (online) or Piper (offline, local) as the TTS backend.

.DESCRIPTION
    For each phrase x voice combination: synthesises audio, applies a narrow-band
    radio effect via FFmpeg (300-3400 Hz bandpass), converts to OGG Vorbis
    (mono 44100 Hz), and patches the Lua duration manifest back into ATC_Script.lua
    between PHRASE_DUR_START / PHRASE_DUR_END markers.

.PARAMETER ApiKey
    ElevenLabs API key.  Required when not using -Piper.

.PARAMETER Piper
    Path to piper.exe.  When supplied, Piper is used instead of ElevenLabs.
    -ApiKey is not required in this mode.

.PARAMETER PiperVoices
    Hashtable mapping voice key -> path to .onnx model file.
    Example: @{ ground="k:\piper\voices\en_US-lessac-high.onnx" }
    Defaults to a set of bundled voices when not specified.

.PARAMETER NoiseScale
    Piper noise_scale parameter (expressiveness). Default 1.0.

.PARAMETER NoiseW
    Piper noise_w parameter (timing variation). Default 1.0.

.PARAMETER LengthScale
    Piper length_scale parameter (speed; lower = faster). Default 0.85.

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
    # ElevenLabs (online)
    .\Generate-Phrases.ps1 -ApiKey "sk_..." -FFmpeg "E:\downloader\ffmpeg.exe"

.EXAMPLE
    # Piper (offline)
    .\Generate-Phrases.ps1 -Piper "k:\piper\piper.exe" -FFmpeg "E:\downloader\ffmpeg.exe"
#>
param(
    [string]$ApiKey      = "",
    [string]$Piper       = "",       # Path to piper.exe; activates Piper backend
    [hashtable]$PiperVoices = @{},   # voice key -> .onnx path (optional override)
    [double]$NoiseScale  = 1.0,      # Piper: expressiveness
    [double]$NoiseW      = 1.0,      # Piper: timing variation
    [double]$LengthScale = 0.85,     # Piper: speed (lower = faster)
    [string]$OutDir      = "$PSScriptRoot\phrases",
    [string]$ScriptPath  = "$PSScriptRoot\Scripts\ATC_Script.lua",
    [string]$FFmpeg      = "ffmpeg",
    [switch]$NoRadioEffect,
    [switch]$Force,                  # Re-generate even if OGG already exists
    [double]$TtsSpeed    = 1.15,     # ElevenLabs speaking rate
    [double]$Atempo      = 1.0,      # FFmpeg post-process speed (1.0 = off)
    [string[]]$VoiceFilter = @()     # If non-empty, only generate for these voice keys
)

# -- Validate backend --------------------------------------------------------
$UsePiper = ($Piper -ne "")
if (-not $UsePiper -and $ApiKey -eq "") {
    Write-Error "Provide either -ApiKey (ElevenLabs) or -Piper <path to piper.exe>."
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# -- Verify FFmpeg -----------------------------------------------------------
try { Start-Process -FilePath $FFmpeg -ArgumentList "-version" `
        -Wait -NoNewWindow `
        -RedirectStandardOutput "$env:TEMP\ffver.txt" `
        -RedirectStandardError  "$env:TEMP\ffver_err.txt" | Out-Null }
catch {
    Write-Error "FFmpeg not found at '$FFmpeg'.  Pass -FFmpeg <path>."
    exit 1
}

# -- Radio effect filter chain -----------------------------------------------
# Narrow-band AM radio: 300-3400 Hz bandpass + slight treble clarity boost.
# Silence trim (remove leading/trailing silence from TTS clips) + narrow-band AM radio effect.
# The double silenceremove+areverse removes both leading AND trailing silence.
# -55dB threshold is conservative enough to not eat trailing consonants (e.g. "approach" -> "appro").
# apad=pad_dur=0.05 adds 50 ms of padding after trim so final consonants are never clipped.
$SilenceTrim  = "silenceremove=start_periods=1:start_threshold=-55dB:start_duration=0.005"
$AtempoFilter = if ($Atempo -ne 1.0) { ",atempo=$Atempo" } else { "" }
# Radio filter chain:
#   acompressor  - heavy AGC/squelch compression (the biggest "radio" cue missing before)
#                  threshold=-25dB, ratio=4:1, 5ms attack / 80ms release, 5dB makeup gain
#   Double highpass/lowpass at 12dB/oct -> 24dB/oct roll-off for sharper band edges
#   equalizer    - +4dB presence boost at 1.2 kHz (speech intelligibility sweet spot on radio)
#   volume       - final normalisation
$RadioFilter  = "$SilenceTrim$AtempoFilter," +
    "acompressor=threshold=-25dB:ratio=4:attack=5:release=80:knee=2:makeup=5," +
    "highpass=f=300:poles=2,highpass=f=300:poles=2," +
    "lowpass=f=3000:poles=2,lowpass=f=3000:poles=2," +
    "equalizer=f=1200:t=o:w=2:g=4," +
    "volume=1.5"

# -- Piper voice definitions (folder name -> .onnx path) ---------------------
# Default Piper voice map — override with -PiperVoices @{ key="path.onnx" }
$DefaultPiperVoices = [ordered]@{
    "lessac"  = "k:\piper\voices\en_US-lessac-high.onnx"   # American male, high quality
    "cori"    = "k:\piper\voices\en_GB-cori-high.onnx"     # British female, high quality
    "john"    = "k:\piper\voices\en_US-john-medium.onnx"   # American male, medium quality
    "amy"     = "k:\piper\voices\en_US-amy-low.onnx"       # American female, low quality
}
if ($UsePiper) {
    if ($PiperVoices.Count -gt 0) {
        $Voices = [ordered]@{}
        foreach ($kv in $PiperVoices.GetEnumerator()) { $Voices[$kv.Key] = $kv.Value }
    } else {
        $Voices = $DefaultPiperVoices
    }
}

# -- Piper TTS helper --------------------------------------------------------
function Invoke-PiperTTS {
    param([string]$Text, [string]$OnnxPath, [string]$OutWav)
    $tmpIn = "$env:TEMP\piper_input.txt"
    $Text | Out-File -FilePath $tmpIn -Encoding ascii -NoNewline
    $proc = Start-Process -FilePath $Piper `
        -ArgumentList '--model', $OnnxPath,
                      '--noise_scale',  $NoiseScale,
                      '--noise_w',      $NoiseW,
                      '--length_scale', $LengthScale,
                      '--output_file',  $OutWav `
        -RedirectStandardInput  $tmpIn `
        -RedirectStandardError  "$env:TEMP\piper_err.txt" `
        -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        $err = Get-Content "$env:TEMP\piper_err.txt" -Raw -ErrorAction SilentlyContinue
        throw "Piper failed (exit $($proc.ExitCode)): $err"
    }
}

# -- ElevenLabs voice definitions (folder name -> voice ID) ------------------
# Folder names must match the values in _ROLE_VOICE in ATC_Script.lua.
if (-not $UsePiper) {
    $Voices = [ordered]@{
        "daniel" = "onwK4e9ZLuTAKqWW03F9"   # Daniel  - British male, calm broadcaster  -> Approach
        "adam"   = "pNInz6obpgDQGcFmaJgB"   # Adam    - American male, firm authority   -> Tower
        "alice"  = "Xb7hH8MSUJpSbSDYk0k2"   # Alice   - British female, professional    -> Ground
        "gary"   = "QLOrGSLtlFUlfQRSaOtQ"   # Gary    - Australian male, narrator       -> Departure
        "david"  = "FmJ4FDkdrYIKzBTruTkV"   # David
        "diane"  = "VdlAJiY20k9brfuVL9hQ"   # Diane
        "olivia" = "GsjQ0ydx7QzhDLqInGtT"   # Olivia
        "brad"   = "MYiFAKeVwcvm4z9VsFAR"   # Brad
    }
}

# -- Phrases dictionary: token-name -> spoken text ---------------------------
# ALL tokens are generated for ALL voices (any controller may say any token).
$Phrases = [ordered]@{
    # -- Digits (ATC pronunciation) ------------------------------------------
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

    # -- Units ---------------------------------------------------------------
    "feet"           = "feet"
    "knots"          = "knots"
    "nautical-miles" = "nautical miles"
    "point"          = "point"
    "thousand"       = "thousand"
    "hundred"        = "hundred"
    "landing"        = "landing"

    # -- Time-of-day greetings -----------------------------------------------
    "good-morning"   = "good morning"
    "good-afternoon" = "good afternoon"
    "good-evening"   = "good evening"

    # -- Controller role names -----------------------------------------------
    "approach"  = "approach"
    "tower"     = "tower"
    "ground"    = "ground"
    "departure" = "departure"

    # -- Connector words -----------------------------------------------------
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
    "climb"   = "climb"
    "descend" = "descend"
    "to"      = "to"
    "you"     = "you"
    "are"     = "are"
    "on"      = "on"
    "of"      = "of"
    "from"    = "from"
    "with"    = "with"
    "MHz"       = "megahertz"
    "north"     = "north"
    "south"     = "south"
    "east"      = "east"
    "west"      = "west"
    "northeast" = "northeast"
    "northwest" = "northwest"
    "southeast" = "southeast"
    "southwest" = "southwest"

    # -- Heading instruction chunks ------------------------------------------
    "fly-heading"         = "fly heading"
    "turn-left-heading"   = "turn left heading"
    "turn-right-heading"  = "turn right heading"
    "maintain"            = "maintain"
    "descend-to"          = "descend to"
    "climb-to"            = "climb to"
    "reduce-speed-to"     = "reduce speed to"
    "increase-speed-to"   = "increase speed to"

    # -- Pattern advisories -------------------------------------------------
    "abeam-the-threshold"  = "abeam the threshold"
    "on-base-runway"       = "on base, runway"
    "base-heading"         = "base heading"
    "turn-final-heading"   = "turn final heading"
    "established-on-final" = "established on final"
    "continue-approach"    = "continue approach"
    "initial"              = "initial"
    "straight-in"          = "straight in"
    "on-downwind"          = "on downwind"
    "crosswind"            = "crosswind"

    # -- Approach clearance / vectors ---------------------------------------
    "cleared-for-the-approach"   = "cleared for the approach"
    "runway-clear"               = "runway clear"
    "you-are-number"             = "you are number"
    "report-final"               = "report final"
    "radar-contact"              = "radar contact"
    "expect-vectors-to-runway"   = "expect vectors to runway"
    "report-15-NM"               = "report fifteen nautical miles"

    # -- Tower handoff / check-in ------------------------------------------
    "on-this-frequency"  = "on this frequency"
    "from-threshold"     = "from threshold"
    "contact-tower"      = "contact tower"

    # -- Landing / ground ops ----------------------------------------------
    "cleared-to-land"            = "cleared to land"
    "wind"                       = "wind"
    "slow-to-approach-speed"     = "slow to approach speed"
    "check-gear-down-and-locked" = "check gear down and locked"
    "runway-occupied"            = "runway occupied"
    "return-to-pattern"          = "return to pattern and await clearance"
    "vacate-runway"              = "vacate runway and contact ground"

    # -- Departure / startup -----------------------------------------------
    "startup-clearance"          = "startup clearance granted"
    "contact-ground"             = "contact ground when ready to taxi"
    "fly-heading-climb"          = "fly heading"
    "climb-to-5000"              = "climb to five thousand feet"
    "cleared-for-takeoff"        = "cleared for takeoff"
    "wind-calm"                  = "wind calm"
    "cleared-to-taxi"            = "cleared to taxi"
    "hold-short"                 = "hold short"
    "via"                        = "via"
    "taxi-to-parking"            = "taxi to parking"
    "welcome-to"                 = "welcome to"
    "spot"                       = "spot"

    # -- Emergency / go-around --------------------------------------------
    "go-around-go-around"             = "go around, go around"
    "airspeed-critically-low"         = "airspeed critically low"
    "climb-immediately-runway-heading" = "climb immediately, runway heading"
    "missed-approach"                 = "missed approach"
    "correct-approach"                = "correct your approach, deviation from glideslope"

    # -- NATO phonetic alphabet -------------------------------------------
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

    # -- Common DCS player callsign words ---------------------------------
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

    # -- Caucasus airfield words ------------------------------------------
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

    # -- Persian Gulf airfield words --------------------------------------
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

    # -- Syria / other theater words --------------------------------------
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

    # -- Number words (for spoken distances 1-20 as single clips) -----------
    "nine"       = "nine."         # word-form (vs "niner" = ICAO digit)
    "ten"        = "ten."
    "eleven"     = "eleven."
    "twelve"     = "twelve."
    "thirteen"   = "thirteen."
    "fourteen"   = "fourteen."
    "fifteen"    = "fifteen."
    "sixteen"    = "sixteen."
    "seventeen"  = "seventeen."
    "eighteen"   = "eighteen."
    "nineteen"   = "nineteen."
    "twenty"     = "twenty."

    # -- Tens (for QFE/distance compound numbers 21-99) ----------------------
    "thirty"     = "thirty."
    "forty"      = "forty."
    "fifty"      = "fifty."
    "sixty"      = "sixty."
    "seventy"    = "seventy."
    "eighty"     = "eighty."
    "ninety"     = "ninety."

    # -- QFE / altimeter ----------------------------------------------------
    "decimal"    = "decimal."
    "qfe"        = "Q.F.E."

    # -- Distance unit (short form for vectors) -----------------------------
    "miles"      = "miles."

    # -- Outside-airspace (single clip, >50 NM) -----------------------------
    "outside-my-airspace" = "You are outside my airspace. Contact me again within 50 miles."

    # -- Compound phrase starters -------------------------------------------
    "radar-contact-you-are" = "Radar contact. You are"
    "for-landing"           = "for landing."

    # -- Time-of-day farewells (replace 'report final' from approach) --------
    "have-a-good-morning"   = "Have a good morning."
    "have-a-good-afternoon" = "Have a good afternoon."
    "have-a-good-day"       = "Have a good day."
    "have-a-good-evening"   = "Have a good evening."

    # -- Compound airport + role phrases (Caucasus) -------------------------
    "batumi-approach"        = "Batumi approach."
    "of-batumi"              = "of Batumi."
    "batumi-tower"           = "Batumi tower."
    "kobuleti-approach"      = "Kobuleti approach."
    "of-kobuleti"            = "of Kobuleti."
    "kobuleti-tower"         = "Kobuleti tower."
    "kutaisi-approach"       = "Kutaisi approach."
    "of-kutaisi"             = "of Kutaisi."
    "kutaisi-tower"          = "Kutaisi tower."
    "senaki-approach"        = "Senaki approach."
    "of-senaki"              = "of Senaki."
    "senaki-tower"           = "Senaki tower."
    "sukhumi-approach"       = "Sukhumi approach."
    "of-sukhumi"             = "of Sukhumi."
    "sukhumi-tower"          = "Sukhumi tower."
    "gudauta-approach"       = "Gudauta approach."
    "of-gudauta"             = "of Gudauta."
    "gudauta-tower"          = "Gudauta tower."
    "sochi-approach"         = "Sochi approach."
    "of-sochi"               = "of Sochi."
    "sochi-tower"            = "Sochi tower."
    "tbilisi-approach"       = "Tbilisi approach."
    "of-tbilisi"             = "of Tbilisi."
    "tbilisi-tower"          = "Tbilisi tower."
    "vaziani-approach"       = "Vaziani approach."
    "of-vaziani"             = "of Vaziani."
    "vaziani-tower"          = "Vaziani tower."
    "krasnodar-approach"     = "Krasnodar approach."
    "of-krasnodar"           = "of Krasnodar."
    "krasnodar-tower"        = "Krasnodar tower."
    "krymsk-approach"        = "Krymsk approach."
    "of-krymsk"              = "of Krymsk."
    "krymsk-tower"           = "Krymsk tower."
    "novorossiysk-approach"  = "Novorossiysk approach."
    "of-novorossiysk"        = "of Novorossiysk."
    "novorossiysk-tower"     = "Novorossiysk tower."
    "anapa-approach"         = "Anapa approach."
    "of-anapa"               = "of Anapa."
    "anapa-tower"            = "Anapa tower."
    "maykop-approach"        = "Maykop approach."
    "of-maykop"              = "of Maykop."
    "maykop-tower"           = "Maykop tower."
    "beslan-approach"        = "Beslan approach."
    "of-beslan"              = "of Beslan."
    "beslan-tower"           = "Beslan tower."
    "mozdok-approach"        = "Mozdok approach."
    "of-mozdok"              = "of Mozdok."
    "mozdok-tower"           = "Mozdok tower."
    "nalchik-approach"       = "Nalchik approach."
    "of-nalchik"             = "of Nalchik."
    "nalchik-tower"          = "Nalchik tower."
    "gelendzhik-approach"    = "Gelendzhik approach."
    "of-gelendzhik"          = "of Gelendzhik."
    "gelendzhik-tower"       = "Gelendzhik tower."

    # -- Compound airport + role phrases (Persian Gulf) ---------------------
    "dubai-approach"         = "Dubai approach."
    "of-dubai"               = "of Dubai."
    "dubai-tower"            = "Dubai tower."
    "fujairah-approach"      = "Fujairah approach."
    "of-fujairah"            = "of Fujairah."
    "fujairah-tower"         = "Fujairah tower."
    "kish-approach"          = "Kish approach."
    "of-kish"                = "of Kish."
    "kish-tower"             = "Kish tower."
    "sharjah-approach"       = "Sharjah approach."
    "of-sharjah"             = "of Sharjah."
    "sharjah-tower"          = "Sharjah tower."
    "kerman-approach"        = "Kerman approach."
    "of-kerman"              = "of Kerman."
    "kerman-tower"           = "Kerman tower."
    "shiraz-approach"        = "Shiraz approach."
    "of-shiraz"              = "of Shiraz."
    "shiraz-tower"           = "Shiraz tower."
    "khasab-approach"        = "Khasab approach."
    "of-khasab"              = "of Khasab."
    "khasab-tower"           = "Khasab tower."

    # -- Compound airport + role phrases (Syria / Med) ----------------------
    "incirlik-approach"      = "Incirlik approach."
    "of-incirlik"            = "of Incirlik."
    "incirlik-tower"         = "Incirlik tower."
    "akrotiri-approach"      = "Akrotiri approach."
    "of-akrotiri"            = "of Akrotiri."
    "akrotiri-tower"         = "Akrotiri tower."
    "hatay-approach"         = "Hatay approach."
    "of-hatay"               = "of Hatay."
    "hatay-tower"            = "Hatay tower."
    "adana-approach"         = "Adana approach."
    "of-adana"               = "of Adana."
    "adana-tower"            = "Adana tower."
    "beirut-approach"        = "Beirut approach."
    "of-beirut"              = "of Beirut."
    "beirut-tower"           = "Beirut tower."
    "damascus-approach"      = "Damascus approach."
    "of-damascus"            = "of Damascus."
    "damascus-tower"         = "Damascus tower."
}

# -- Helper: get audio duration using ffmpeg -i -----------------------------
function Get-AudioDuration([string]$Path) {
    $tmpErr = "$env:TEMP\ffmpeg_info_err.txt"
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

# -- Helper: call ElevenLabs TTS with retry on rate-limit ------------------
function Invoke-ElevenLabsTTS {
    param([string]$Text, [string]$VoiceId, [string]$OutPath)

    $body = @{
        text       = $Text
        # eleven_multilingual_v2  = highest quality; slower + ~2x cost vs turbo
        # eleven_turbo_v2_5       = fast, good quality, lower cost (original)
        model_id   = "eleven_multilingual_v2"
        voice_settings = @{
            # stability:        0.55 = slight natural variation per clip (was 0.92 = monotone)
            # similarity_boost: 0.85 = strong speaker identity without over-enunciation
            # style:            0.20 = mild prosodic expressiveness (was 0.0 = flat)
            # use_speaker_boost: $true = adds presence/character to the voice
            stability         = 0.55
            similarity_boost  = 0.85
            style             = 0.20
            use_speaker_boost = $true
            speed             = $TtsSpeed
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

# -- Main generation loop: ALL voices x ALL phrases ------------------------
$durations  = @{}
$totalFiles = $Voices.Count * $Phrases.Count
$done       = 0

$radioNote = if ($NoRadioEffect) { "(no radio effect)" } else { "(radio effect ON)" }
Write-Host "`nGenerating $totalFiles clips ($($Voices.Count) voices x $($Phrases.Count) phrases) $radioNote" -ForegroundColor Cyan

foreach ($voiceEntry in $Voices.GetEnumerator()) {
    $voiceKey = $voiceEntry.Key
    $voiceId  = $voiceEntry.Value
    if ($VoiceFilter.Count -gt 0 -and $voiceKey -notin $VoiceFilter) {
        # Load existing durations for skipped voices so the manifest stays complete
        $vDir = Join-Path $OutDir $voiceKey
        if (Test-Path $vDir) {
            foreach ($ogg in (Get-ChildItem $vDir -Filter "*.ogg" | Where-Object { $_.Name -notmatch '\.bak\.ogg$' })) {
                $key = "$voiceKey/$($ogg.BaseName)"
                if (-not $durations.ContainsKey($key)) {
                    $durations[$key] = [Math]::Round((Get-AudioDuration $ogg.FullName), 3)
                }
            }
        }
        continue
    }
    $voiceDir = Join-Path $OutDir $voiceKey
    New-Item -ItemType Directory -Force -Path $voiceDir | Out-Null

    Write-Host "`n  Voice: $voiceKey" -ForegroundColor Yellow

    foreach ($phrase in $Phrases.GetEnumerator()) {
        $token   = $phrase.Key
        $text    = $phrase.Value
        $oggPath = Join-Path $voiceDir "$token.ogg"

        # Skip if OGG already exists and is non-empty (resume support); -Force overrides
        if (-not $Force -and (Test-Path $oggPath) -and (Get-Item $oggPath).Length -gt 1000) {
            $dur = Get-AudioDuration $oggPath
            $durations["$voiceKey/$token"] = [Math]::Round($dur, 3)
            $done++
            continue
        }

        if ($UsePiper) {
            # --- Piper backend: synthesise WAV then FFmpeg WAV -> OGG ----------
            $wavPath = Join-Path $voiceDir "$token.wav"
            try {
                Invoke-PiperTTS -Text $text -OnnxPath $voiceId -OutWav $wavPath
            } catch {
                Write-Warning "  Piper failed for '$voiceKey/$token': $_"
                $done++
                continue
            }
            $dur = Get-AudioDuration $wavPath
            if ($NoRadioEffect) {
                $afArgs = @('-ar','44100','-ac','1','-c:a','libvorbis','-q:a','4')
            } else {
                $afArgs = @('-af',$RadioFilter,'-ar','44100','-ac','1','-c:a','libvorbis','-q:a','4')
            }
            $proc = Start-Process -FilePath $FFmpeg `
                -ArgumentList (@('-y','-i',$wavPath) + $afArgs + @($oggPath)) `
                -Wait -PassThru -NoNewWindow `
                -RedirectStandardOutput "$env:TEMP\ffmpeg_stdout.txt" `
                -RedirectStandardError  "$env:TEMP\ffmpeg_stderr.txt"
            if ($proc.ExitCode -ne 0) {
                $errText = Get-Content "$env:TEMP\ffmpeg_stderr.txt" -Raw -ErrorAction SilentlyContinue
                Write-Warning "  FFmpeg failed for '$voiceKey/$token' (exit $($proc.ExitCode)): $errText"
            }
            Remove-Item $wavPath -Force -ErrorAction SilentlyContinue
        } else {
            # --- ElevenLabs backend: API -> MP3 -> FFmpeg MP3 -> OGG ----------
            $mp3Path = Join-Path $voiceDir "$token.mp3"
            try {
                Invoke-ElevenLabsTTS -Text $text -VoiceId $voiceId -OutPath $mp3Path
            } catch {
                Write-Warning "  ElevenLabs failed for '$voiceKey/$token': $_"
                $done++
                continue
            }
            $dur = Get-AudioDuration $mp3Path
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
                Write-Warning "  FFmpeg failed for '$voiceKey/$token' (exit $($proc.ExitCode)): $errText"
            }
            Remove-Item $mp3Path -Force -ErrorAction SilentlyContinue
            # Small pause to be polite to the API
            Start-Sleep -Milliseconds 150
        }

        $durations["$voiceKey/$token"] = [Math]::Round($dur, 3)
        $done++

        Write-Progress -Activity "Generating phrases" `
            -Status "$voiceKey/$token  ($done / $totalFiles)" `
            -PercentComplete ([int](100 * $done / $totalFiles))
    }
}

Write-Progress -Activity "Generating phrases" -Completed

# -- Scan all existing OGGs for any missed durations -----------------------
foreach ($vk in $Voices.Keys) {
    $vDir = Join-Path $OutDir $vk
    if (-not (Test-Path $vDir)) { continue }
    foreach ($ogg in (Get-ChildItem $vDir -Filter "*.ogg" | Where-Object { $_.Name -notmatch '\.bak\.ogg$' })) {
        $key = "$vk/$($ogg.BaseName)"
        if (-not $durations.ContainsKey($key)) {
            $durations[$key] = [Math]::Round((Get-AudioDuration $ogg.FullName), 3)
        }
    }
}

Write-Host "`nGenerated $($durations.Count) clips into: $OutDir" -ForegroundColor Green

# -- Build Lua duration table ----------------------------------------------
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("-- PHRASE_DUR_START (auto-generated by Generate-Phrases.ps1 - do not edit manually)")
$lines.Add("ATC._phraseDur = {")
foreach ($kv in ($durations.GetEnumerator() | Sort-Object Key)) {
    $lines.Add("    [`"$($kv.Key)`"] = $($kv.Value),")
}
$lines.Add("}")
$lines.Add("-- PHRASE_DUR_END")

$manifest = $lines -join "`n"

# -- Patch ATC_Script.lua --------------------------------------------------
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

Write-Host "`nDone.  Run Inject-Mission.ps1 to embed OGGs into your .miz file." -ForegroundColor Yellow
