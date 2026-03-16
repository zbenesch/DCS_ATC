<#
.SYNOPSIS
    Injects the ATC phrase library into a DCS .miz mission file.

.DESCRIPTION
    A .miz is a ZIP archive.  This script adds all OGG files from the phrase
    library under AUDIO/atc/<voice>/ inside the archive, ready for
    trigger.action.radioTransmission calls from ATC_Script.lua.

.PARAMETER MizPath
    Path to the .miz file to patch (required).

.PARAMETER PhrasesDir
    Root folder that contains voice sub-folders (david/, zira/, mark/).
    Default: <script dir>\phrases

.EXAMPLE
    .\Inject-Mission.ps1 -MizPath "C:\...\MyMission.miz"
#>
param(
    [Parameter(Mandatory)][string]$MizPath,
    [string]$PhrasesDir = "$PSScriptRoot\phrases"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $MizPath)) { Write-Error "Mission file not found: $MizPath"; exit 1 }
if (-not (Test-Path $PhrasesDir)) { Write-Error "Phrases directory not found: $PhrasesDir"; exit 1 }

$MizPath = (Resolve-Path $MizPath).Path

$oggFiles = Get-ChildItem $PhrasesDir -Recurse -Filter "*.ogg"
if ($oggFiles.Count -eq 0) {
    Write-Error "No OGG files found under '$PhrasesDir'.  Run Generate-Phrases.ps1 first."
    exit 1
}

Write-Host "Opening: $MizPath" -ForegroundColor Cyan

$zip = [System.IO.Compression.ZipFile]::Open($MizPath, 'Update')
try {
    $added   = 0
    $skipped = 0

    foreach ($file in $oggFiles) {
        # Build archive entry path: AUDIO/atc/<voice>/<token>.ogg
        $voiceFolder = $file.Directory.Name   # "david", "zira", "mark"
        $entryPath   = "AUDIO/atc/$voiceFolder/$($file.Name)"

        # Remove old entry with same path if exists
        $existing = $zip.GetEntry($entryPath)
        if ($existing) { $existing.Delete(); $skipped++ }

        # Add new entry
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entryPath,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
        $added++
    }

    Write-Host "Added $added OGG files ($skipped replaced)." -ForegroundColor Green
}
finally {
    $zip.Dispose()
}

Write-Host "Done.  Mission ready: $MizPath" -ForegroundColor Yellow
