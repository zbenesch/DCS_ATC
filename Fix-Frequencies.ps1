# Fix duplicate frequencies in DCS ATC airfield files
# Maps each airfield to unique ground/tower/approach/departure frequencies

$airfieldFrequencies = @{
    "Anapa-Vityazevo"        = @{ ground=121.5; tower=118.5; approach=123.2; departure=124.0 }
    "Batumi"                 = @{ ground=121.6; tower=118.6; approach=123.3; departure=124.1 }
    "Beslan"                 = @{ ground=121.7; tower=118.7; approach=123.4; departure=124.2 }
    "Gelendzhik"             = @{ ground=121.8; tower=118.8; approach=123.5; departure=124.3 }
    "Gudauta"                = @{ ground=121.9; tower=118.9; approach=123.6; departure=124.4 }
    "Kobuleti"               = @{ ground=122.0; tower=119.0; approach=123.7; departure=124.2 }
    "Krasnodar-Center"       = @{ ground=121.5; tower=119.1; approach=123.2; departure=124.1 }
    "Krasnodar-Pashkovsky"   = @{ ground=121.6; tower=119.2; approach=123.3; departure=124.2 }
    "Krymsk"                 = @{ ground=121.7; tower=119.3; approach=123.4; departure=124.3 }
    "Kutaisi"                = @{ ground=121.8; tower=119.4; approach=123.5; departure=124.4 }
    "Maykop-Khanskaya"       = @{ ground=121.9; tower=119.5; approach=123.6; departure=124.0 }
    "Mineralnye Vody"        = @{ ground=122.0; tower=119.6; approach=123.7; departure=124.1 }
    "Mozdok"                 = @{ ground=121.5; tower=119.7; approach=123.2; departure=124.2 }
    "Nalchik"                = @{ ground=121.6; tower=119.8; approach=123.3; departure=124.3 }
    "Novorossiysk"           = @{ ground=121.7; tower=119.9; approach=123.4; departure=124.4 }
    "Senaki-Kolkhi"          = @{ ground=121.8; tower=120.0; approach=123.5; departure=124.0 }
    "Sochi-Adler"            = @{ ground=121.9; tower=120.1; approach=123.6; departure=124.1 }
    "Soganlug"               = @{ ground=122.0; tower=120.2; approach=123.7; departure=124.2 }
    "Sukhumi"                = @{ ground=121.5; tower=120.3; approach=123.2; departure=124.3 }
    "Tbilisi-Lochini"        = @{ ground=121.6; tower=120.4; approach=123.3; departure=124.4 }
    "Vaziani"                = @{ ground=121.7; tower=120.5; approach=123.4; departure=124.0 }
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
        
        # Format with period as decimal separator
        [System.Globalization.CultureInfo]::CurrentCulture = 'en-US'
        
        $groundPattern = 'ground\s*=\s*\{\s*mhz=[\d,.]+,\s*hz=\d+\s*\}'
        $groundReplace = "ground   = { mhz=$($ground.ToString('F3', [System.Globalization.CultureInfo]::InvariantCulture)), hz=$([long]($ground * 1000000)) }"
        $content = $content -replace $groundPattern, $groundReplace
        
        $towerPattern = 'tower\s*=\s*\{\s*mhz=[\d,.]+,\s*hz=\d+\s*\}'
        $towerReplace = "tower    = { mhz=$($tower.ToString('F3', [System.Globalization.CultureInfo]::InvariantCulture)), hz=$([long]($tower * 1000000)) }"
        $content = $content -replace $towerPattern, $towerReplace
        
        $approachPattern = 'approach\s*=\s*\{\s*mhz=[\d,.]+,\s*hz=\d+\s*\}'
        $approachReplace = "approach = { mhz=$($approach.ToString('F3', [System.Globalization.CultureInfo]::InvariantCulture)), hz=$([long]($approach * 1000000)) }"
        $content = $content -replace $approachPattern, $approachReplace
        
        $departurePattern = 'departure\s*=\s*\{\s*mhz=[\d,.]+,\s*hz=\d+\s*\}'
        $departureReplace = "departure= { mhz=$($departure.ToString('F3', [System.Globalization.CultureInfo]::InvariantCulture)), hz=$([long]($departure * 1000000)) }"
        $content = $content -replace $departurePattern, $departureReplace
        
        Set-Content $filepath $content -NoNewline -Encoding UTF8
        return $true
    }
    return $false
}

foreach ($airfield in $airfieldFrequencies.Keys) {
    $frequencies = $airfieldFrequencies[$airfield]
    
    $filename = $airfield.ToLower() -replace " ", "-"
    $filepath = Join-Path $baseFolder "$filename.lua"
    
    if ($airfield -eq "Soganlug") {
        $filepath = Join-Path $baseFolder "tbilisi-soganlug.lua"
    } elseif ($airfield -eq "Sukhumi") {
        $filepath = Join-Path $baseFolder "sukhumi.lua"
    }
    
    try {
        if (Update-LuaFrequencies -filepath $filepath -ground $frequencies.ground -tower $frequencies.tower -approach $frequencies.approach -departure $frequencies.departure) {
            Write-Host ("UPDATED: " + $airfield) -ForegroundColor Green
            $updatedCount++
        } else {
            $errors += ("$airfield : File not found at $filepath")
        }
    }
    catch {
        $errors += ("$airfield - " + $_.Exception.Message)
    }
}

Write-Host "" 
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host ("Updated $updatedCount files") 
if ($errors.Count -gt 0) {
    Write-Host "Errors:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host ("  - $_") }
}

Write-Host "" 
Write-Host "=== FREQUENCY ASSIGNMENT ===" -ForegroundColor Cyan
$airfieldFrequencies.Keys | Sort-Object | ForEach-Object {
    $freq = $airfieldFrequencies[$_]
    $name = $_
    Write-Host ("$name : Ground=$($freq.ground) Tower=$($freq.tower) Approach=$($freq.approach) Departure=$($freq.departure)")
}
