ATC.runways["Nalchik"] = {
    icao = "URMN",
    iata = "NAL",
    runways = {
        ["06/24"] = {
            length_m = 2200, width_m = 42, surface = "Hard",
            ends = {
                ["06"] = { hdg = 60, elevation = 1443, lat = "N43°30.97'", lon = "E43°40.97'" },
                ["24"] = { hdg = 240, elevation = 1443, lat = "N43°30.97'", lon = "E43°40.97'" }
            }
        }
    },
    frequencies = {
        ground   = { mhz = 121.700, hz = 121700000 },
        tower    = { mhz = 118.100, hz = 118100000 },
        approach = { mhz = 123.700, hz = 123700000 },
        departure= { mhz = 0, hz = 0 }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    patternAlt = 2943, -- elevation (1443) + 1500ft
    crps = {
        { name="Nalchik CRP1", seq=1, x=-125470.99429731, y=773195.9374967, radius=3703.9296 },
        { name="Nalchik CRP2", seq=2, x=-133982.15930418, y=759460.95791936, radius=2777.3376 },
        { name="Nalchik CRP3", seq=3, x=-122427.13131764, y=751547.01660229, radius=2777.3376 },
        { name="Nalchik CRP4", seq=4, x=-115909.00503697, y=761486.22845749, radius=2777.3376 },
        { name="Nalchik CRP5", seq=5, x=-117225.79295136, y=765473.29091882, radius=1388.6688 },
        { name="Nalchik CRP6", seq=6, x=-126613.44391828, y=751471.16918707, radius=1388.6688 },
    },
}

