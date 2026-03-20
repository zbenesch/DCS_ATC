# Sync DCS-ATC mod to DCS SavedGames folder

$sourceDir = "k:\DCS_ATC\Mods\Services\DCS-ATC"
$destDir = "c:\Users\benes\Saved Games\DCS\Mods\Services\DCS-ATC"

Write-Host "=== DCS-ATC SavedGames Sync ===" -ForegroundColor Cyan
Write-Host "Source: $sourceDir"
Write-Host "Target: $destDir"
Write-Host ""

# Check if source exists
if (-not (Test-Path $sourceDir)) {
    Write-Host "ERROR: Source directory not found: $sourceDir" -ForegroundColor Red
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $destDir)) {
    Write-Host "Creating destination directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

# Sync using robocopy for better control
Write-Host "Syncing files..." -ForegroundColor Yellow
robocopy "$sourceDir" "$destDir" /E /IS /IT /PURGE /NP /NFL /NDL

if ($LASTEXITCODE -lt 8) {
    Write-Host "SYNC COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host ""
    Write-Host "Synced items:" -ForegroundColor Cyan
    Get-ChildItem -Path $destDir -Recurse -File | Measure-Object | ForEach-Object { Write-Host ("  Total files: " + $_.Count) }
} else {
    Write-Host ("SYNC FAILED with error code: " + $LASTEXITCODE) -ForegroundColor Red
    exit 1
}
