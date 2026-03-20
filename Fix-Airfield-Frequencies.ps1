# Fix duplicate frequencies in DCS ATC airfield files
# Maps each airfield to unique ground/tower/approach/departure frequencies

$airfieldFrequencies = @{
    "Anapa-Vityazevo"        = @{ ground=121.90; tower=118.80; approach=123.60; departure=124.30 }  # Keep (Group 2 rep)
    "Batumi"                 = @{ ground=121.52; tower=118.52; approach=123.32; departure=124.12 }  # Changed
    "Beslan"                 = @{ ground=121.92; tower=118.92; approach=123.62; departure=124.32 }  # Changed
    "Gelendzhik"             = @{ ground=121.51; tower=118.51; approach=123.31; departure=124.11 }  # Changed
    "Gudauta"                = @{ ground=121.53; tower=118.53; approach=123.33; departure=124.13 }  # Changed
    "Kobuleti"               = @{ ground=121.91; tower=118.91; approach=123.61; departure=124.31 }  # Changed
    "Krasnodar-Center"       = @{ ground=121.54; tower=118.54; approach=123.34; departure=124.14 }  # Changed
    "Krasnodar-Pashkovsky"   = @{ ground=121.90; tower=118.80; approach=123.60; departure=124.30 }  # Keep (Group 2 rep)
    "Krymsk"                 = @{ ground=121.55; tower=118.55; approach=123.35; departure=124.15 }  # Changed
    "Kutaisi"                = @{ ground=122.00; tower=118.90; approach=123.70; departure=124.40 }  # Keep (unique)
    "Maykop-Khanskaya"       = @{ ground=121.56; tower=125.10; approach=123.36; departure=124.16 }  # Changed (kept tower=125.x)
    "Mineralnye Vody"        = @{ ground=121.57; tower=118.57; approach=123.37; departure=124.17 }  # Changed
    "Mozdok"                 = @{ ground=121.58; tower=118.58; approach=123.38; departure=124.18 }  # Changed
    "Nalchik"                = @{ ground=121.93; tower=118.93; approach=123.63; departure=124.33 }  # Changed
    "Novorossiysk"           = @{ ground=121.59; tower=118.59; approach=123.39; departure=124.19 }  # Changed
    "Senaki-Kolkhi"          = @{ ground=121.60; tower=118.60; approach=123.40; departure=124.20 }  # Changed
    "Sochi-Adler"            = @{ ground=121.94; tower=118.94; approach=123.64; departure=124.34 }  # Changed
    "Soganlug"               = @{ ground=121.61; tower=118.61; approach=123.41; departure=124.21 }  # Changed
    "Sukhumi"                = @{ ground=121.62; tower=118.62; approach=123.42; departure=124.22 }  # Changed
    "Tbilisi-Lochini"        = @{ ground=121.95; tower=118.95; approach=123.65; departure=124.35 }  # Changed
    "Vaziani"                = @{ ground=121.63; tower=118.63; approach=123.43; departure=124.23 }  # Changed
}

$baseFolder = "k:\DCS_ATC\Mods\Services\DCS-ATC\Scripts\airfields\Caucasus"
$updatedCount = 0
$errors = @()

function Update-LuaFrequencies {
    param(
        [string]$filepath,
        [float]$ground,
        [float]$tower,
        [float]$approach,
        [float]$departure
    )
    
    if (Test-Path $filepath) {
        $content = Get-Content $filepath -Raw
        
        # Replace using precise pattern matching for each frequency type
        # Ground frequency
        $groundPattern = 'ground\s*=\s*\{\s*mhz=[\d.]+,\s*hz=\d+\s*\}'
        $groundReplace = "ground   = { mhz=$($ground.ToString('F3')), hz=$([long]($ground * 1000000)) }"
        $content = $content -replace $groundPattern, $groundReplace
        
        # Tower frequency  
        $towerPattern = 'tower\s*=\s*\{\s*mhz=[\d.]+,\s*hz=\d+\s*\}'
        $towerReplace = "tower    = { mhz=$($tower.ToString('F3')), hz=$([long]($tower * 1000000)) }"
        $content = $content -replace $towerPattern, $towerReplace
        
        # Approach frequency
        $approachPattern = 'approach\s*=\s*\{\s*mhz=[\d.]+,\s*hz=\d+\s*\}'
        $approachReplace = "approach = { mhz=$($approach.ToString('F3')), hz=$([long]($approach * 1000000)) }"
        $content = $content -replace $approachPattern, $approachReplace
        
        # Departure frequency
        $departurePattern = 'departure\s*=\s*\{\s*mhz=[\d.]+,\s*hz=\d+\s*\}'
        $departureReplace = "departure= { mhz=$($departure.ToString('F3')), hz=$([long]($departure * 1000000)) }"
        $content = $content -replace $departurePattern, $departureReplace
        
        Set-Content $filepath $content -NoNewline -Encoding UTF8
        return $true
    }
    return $false
}

foreach ($airfield in $airfieldFrequencies.Keys) {
    $frequencies = $airfieldFrequencies[$airfield]
    
    # Convert filename format
    $filename = $airfield.ToLower() -replace " ", "-"
    $filepath = Join-Path $baseFolder "$filename.lua"
    
    # Handle special cases
    if ($airfield -eq "Soganlug") {
        $filepath = Join-Path $baseFolder "tbilisi-soganlug.lua"
    } elseif ($airfield -eq "Sukhumi") {
        $filepath = Join-Path $baseFolder "sukhumi.lua"
    }
    
    try {
        if (Update-LuaFrequencies -filepath $filepath -ground $frequencies.ground -tower $frequencies.tower -approach $frequencies.approach -departure $frequencies.departure) {
            Write-Host "✓ Updated: $airfield" -ForegroundColor Green
            $updatedCount++
        } else {
            $errors += "$airfield`: File not found at $filepath"
        }
    }
    catch {
        $errors += "$airfield`: $_"
    }
}

Write-Host "`nSummary: Updated $updatedCount files" -ForegroundColor Cyan
if ($errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
}

Write-Host "`n=== FREQUENCY ASSIGNMENT ===" -ForegroundColor Cyan
$airfieldFrequencies.Keys | Sort-Object | ForEach-Object {
    $freq = $airfieldFrequencies[$_]
    Write-Host "$($_): Ground=$($freq.ground) Tower=$($freq.tower) Approach=$($freq.approach) Departure=$($freq.departure)"
}
