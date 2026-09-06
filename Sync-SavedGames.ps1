# Sync DCS-ATC mod to DCS SavedGames folder
#
# Two different strategies, deliberately:
#
#   Mods\Services\DCS-ATC\  -> mirrored with /PURGE. That folder belongs
#                              entirely to this mod, so deleting strays is safe.
#
#   Scripts\...             -> copied file by file, never mirrored.
#                              Scripts\Hooks is SHARED with SRS, DCS-BIOS,
#                              Tacview and others. A /PURGE there would delete
#                              their hooks. Do not "simplify" this into a second
#                              robocopy /PURGE.
#
# The hook used to be missed entirely, so a stale DCS-ATC-hook.lua could sit in
# Saved Games for months while the scripts beside it were current.

$repoRoot  = $PSScriptRoot
$savedRoot = Join-Path $env:USERPROFILE "Saved Games\DCS"

$sourceDir = Join-Path $repoRoot  "Mods\Services\DCS-ATC"
$destDir   = Join-Path $savedRoot "Mods\Services\DCS-ATC"
$looseTree = Join-Path $repoRoot  "Scripts"

Write-Host "=== DCS-ATC SavedGames Sync ===" -ForegroundColor Cyan
Write-Host "Source: $repoRoot"
Write-Host "Target: $savedRoot"
Write-Host ""

if (-not (Test-Path $sourceDir)) {
    Write-Host "ERROR: Source directory not found: $sourceDir" -ForegroundColor Red
    exit 1
}

# --- 1. Mirror the mod folder -------------------------------------------------
if (-not (Test-Path $destDir)) {
    Write-Host "Creating destination directory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

Write-Host "Mirroring mod folder..." -ForegroundColor Yellow
robocopy "$sourceDir" "$destDir" /E /IS /IT /PURGE /NP /NFL /NDL
$roboExit = $LASTEXITCODE
# robocopy: 0-7 are success (1 = files copied, 2 = extras removed, ...), 8+ real failures
if ($roboExit -ge 8) {
    Write-Host ("SYNC FAILED - robocopy exit code " + $roboExit) -ForegroundColor Red
    exit 1
}

# --- 2. Copy loose files that live outside the mod folder ---------------------
$copied = 0
$failed = @()
$looseFiles = @()
if (Test-Path $looseTree) {
    $looseFiles = @(Get-ChildItem -Path $looseTree -Recurse -File)
}

if ($looseFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Copying loose files (no purge - shared directories)..." -ForegroundColor Yellow
    foreach ($f in $looseFiles) {
        $rel       = $f.FullName.Substring($repoRoot.Length).TrimStart('\')
        $target    = Join-Path $savedRoot $rel
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        try {
            Copy-Item -Path $f.FullName -Destination $target -Force -ErrorAction Stop
            $copied = $copied + 1
            Write-Host ("  " + $rel)
        } catch {
            $failed += $rel
            Write-Host ("  FAILED: " + $rel + " - " + $_.Exception.Message) -ForegroundColor Red
        }
    }

    # Verify by hash - a silently stale hook is the exact bug this guards against.
    Write-Host ""
    Write-Host "Verifying loose files..." -ForegroundColor Yellow
    foreach ($f in $looseFiles) {
        $rel    = $f.FullName.Substring($repoRoot.Length).TrimStart('\')
        $target = Join-Path $savedRoot $rel
        if (-not (Test-Path $target)) {
            Write-Host ("  MISSING: " + $rel) -ForegroundColor Red
            $failed += $rel
        } else {
            $srcHash = (Get-FileHash $f.FullName -Algorithm SHA256).Hash
            $dstHash = (Get-FileHash $target     -Algorithm SHA256).Hash
            if ($srcHash -ne $dstHash) {
                Write-Host ("  MISMATCH: " + $rel) -ForegroundColor Red
                $failed += $rel
            } else {
                Write-Host ("  ok  " + $rel) -ForegroundColor Green
            }
        }
    }
}

# --- 3. Summary ---------------------------------------------------------------
Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host ("SYNC FAILED - " + $failed.Count + " loose file(s) did not sync:") -ForegroundColor Red
    foreach ($x in $failed) { Write-Host ("  " + $x) -ForegroundColor Red }
    exit 1
}

Write-Host "SYNC COMPLETED SUCCESSFULLY" -ForegroundColor Green
$modFiles = (Get-ChildItem -Path $destDir -Recurse -File | Measure-Object).Count
Write-Host ("  Mod files:   " + $modFiles) -ForegroundColor Cyan
Write-Host ("  Loose files: " + $copied)   -ForegroundColor Cyan

# Explicit success: robocopy leaves a non-zero $LASTEXITCODE on a normal run
# (1 = files were copied), which otherwise makes this script look like it failed.
exit 0
