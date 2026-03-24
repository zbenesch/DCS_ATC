<#
.SYNOPSIS
    Injects the ATC script and phrase library into a DCS .miz mission file.

.DESCRIPTION
    A .miz is a ZIP archive.  This script:
      1. Merges airfields.lua + ATC_Script.lua into a single combined script
         and injects it as l10n/DEFAULT/ATC_Script.lua inside the archive.
      2. Adds all OGG files from the phrase library under AUDIO/atc/<voice>/.

.PARAMETER MizPath
    Path to the .miz file to patch (required).

.PARAMETER ScriptsDir
    Root folder containing ATC_Script.lua and airfields.lua.
    Default: <script dir>\Scripts

.PARAMETER PhrasesDir
    Root folder that contains voice sub-folders (mark/).
    Default: <script dir>\phrases

.EXAMPLE
    .\Inject-Mission.ps1 -MizPath "C:\...\MyMission.miz"
#>
param(
    [Parameter(Mandatory)][string]$MizPath,
    [string]$ScriptsDir  = "$PSScriptRoot\Scripts",
    [string]$PhrasesDir  = "$PSScriptRoot\phrases"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $MizPath))    { Write-Error "Mission file not found: $MizPath"; exit 1 }
if (-not (Test-Path $PhrasesDir)) { Write-Error "Phrases directory not found: $PhrasesDir"; exit 1 }

$airfieldsPath  = Join-Path $ScriptsDir "airfields.lua"
$atcScriptPath  = Join-Path $ScriptsDir "ATC_Script.lua"

if (-not (Test-Path $airfieldsPath)) { Write-Error "airfields.lua not found: $airfieldsPath"; exit 1 }
if (-not (Test-Path $atcScriptPath)) { Write-Error "ATC_Script.lua not found: $atcScriptPath"; exit 1 }

$MizPath = (Resolve-Path $MizPath).Path

Write-Host "Opening: $MizPath" -ForegroundColor Cyan

$zip = [System.IO.Compression.ZipFile]::Open($MizPath, 'Update')
try {
    # Script injection is skipped in OGG-only mode; only audio assets are updated.
    Write-Host "Skipping ATC_Script.lua + airfields.lua injection (OGG-only mode)." -ForegroundColor Cyan

    # ── 2. Inject OGG phrase files ────────────────────────────────────────────
    $oggFiles = Get-ChildItem $PhrasesDir -Recurse -Filter "*.ogg"
    $added   = 0
    $skipped = 0

    foreach ($file in $oggFiles) {
        $voiceFolder = $file.Directory.Name
        $entryPath   = "AUDIO/atc/$voiceFolder/$($file.Name)"

        $existingOgg = $zip.GetEntry($entryPath)
        if ($existingOgg) { $existingOgg.Delete(); $skipped++ }

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entryPath,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
        $added++
    }

    if ($added -gt 0) {
        Write-Host "Added $added OGG files ($skipped replaced)." -ForegroundColor Green
    } else {
        Write-Host "No OGG files found under '$PhrasesDir' (skipped audio injection)." -ForegroundColor Yellow
    }
}
finally {
    $zip.Dispose()
}

Write-Host "Done.  Mission ready: $MizPath" -ForegroundColor Yellow
