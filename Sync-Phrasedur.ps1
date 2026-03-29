<#
.SYNOPSIS
    Copies the freshly-generated ATC._phraseDur table from ATC_Script.lua
    into controllers/phrasedur.lua, keeping PSUBS / WSET / DWORDS / NATO intact.

.DESCRIPTION
    Run this after Generate-Phrases.ps1 has finished and patched ATC_Script.lua.
    It writes phrasedur.lua WITHOUT a UTF-8 BOM (bare UTF-8) so that DCS can
    load it via net.dostring_in without a Lua syntax error.

.EXAMPLE
    .\Sync-Phrasedur.ps1
#>

$scriptDir  = $PSScriptRoot
$atcScript  = Join-Path $scriptDir "Mods\Services\DCS-ATC\Scripts\ATC_Script.lua"
$phrasedur  = Join-Path $scriptDir "Mods\Services\DCS-ATC\Scripts\controllers\phrasedur.lua"
$savedGames = Join-Path $env:USERPROFILE "Saved Games\DCS\Mods\Services\DCS-ATC\Scripts\controllers\phrasedur.lua"

if (-not (Test-Path $atcScript))  { Write-Error "Not found: $atcScript";  exit 1 }
if (-not (Test-Path $phrasedur))  { Write-Error "Not found: $phrasedur";  exit 1 }

# ── 1. Extract the ATC._phraseDur block from ATC_Script.lua ─────────────────
$atcLines = Get-Content $atcScript -Encoding UTF8
$startIdx = $null
$endIdx   = $null
for ($i = 0; $i -lt $atcLines.Count; $i++) {
    if ($atcLines[$i] -match 'PHRASE_DUR_START') { $startIdx = $i + 1 }  # line AFTER marker
    if ($atcLines[$i] -match 'PHRASE_DUR_END')   { $endIdx   = $i - 1; break }  # line BEFORE marker
}
if ($null -eq $startIdx -or $null -eq $endIdx) {
    Write-Error "Could not find PHRASE_DUR_START / PHRASE_DUR_END in $atcScript"
    exit 1
}
$phraseDurBlock = $atcLines[$startIdx..$endIdx]
Write-Host "Extracted $($phraseDurBlock.Count) lines from ATC_Script.lua"

# ── 2. Extract the tail of phrasedur.lua (PSUBS onward) ─────────────────────
$pdLines  = Get-Content $phrasedur -Encoding UTF8
$tailIdx  = $null
for ($i = 0; $i -lt $pdLines.Count; $i++) {
    if ($pdLines[$i] -match '^ATC\._PSUBS\s*=') { $tailIdx = $i; break }
}
if ($null -eq $tailIdx) {
    Write-Error "Could not find ATC._PSUBS in $phrasedur"
    exit 1
}
$tail = $pdLines[$tailIdx..($pdLines.Count - 1)]
Write-Host "Tail starts at line $($tailIdx + 1), $($tail.Count) lines"

# ── 3. Assemble new phrasedur.lua ────────────────────────────────────────────
$newLines  = @("ATC = ATC or {}") + $phraseDurBlock + @("") + $tail

# ── 4. Write WITHOUT BOM (bare UTF-8) ────────────────────────────────────────
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($phrasedur, $newLines, $utf8NoBom)
Write-Host "Written: $phrasedur ($($newLines.Count) lines)"

# ── 5. Copy to Saved Games ────────────────────────────────────────────────────
if (Test-Path (Split-Path $savedGames)) {
    [System.IO.File]::WriteAllLines($savedGames, $newLines, $utf8NoBom)
    Write-Host "Copied:  $savedGames"
} else {
    Write-Warning "Saved Games path not found, skipping copy: $savedGames"
}

Write-Host "`nDone. Run Inject-Mission.ps1 next."
