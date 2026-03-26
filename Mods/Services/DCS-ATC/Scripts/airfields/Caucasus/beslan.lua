ATC.runways["Beslan"] = {
    icao = "URMS",
    iata = "OGZ",
    patternAlt = 3171, -- elevation 1671 + 1500
    runways = {
        ["09/27"] = {
            length_m = 3000, width_m = 44, surface = "Hard",
            ends = {
                ["09"] = { hdg = 90, elevation = 1671, lat = "N43°12.97'", lon = "E44°36.97'" },
                ["27"] = { hdg = 270, elevation = 1671, lat = "N43°12.97'", lon = "E44°36.97'" }
            }
        }
    },
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Beslan CRP1", seq=1, x=-138503.36205044, y=835797.00254322, radius=3703.9296 },
        { name="Beslan CRP2", seq=2, x=-142540.95651036, y=850483.75397445, radius=2777.3376 },
        { name="Beslan CRP3", seq=3, x=-155018.8661703, y=850105.39003629, radius=2777.3376 },
        { name="Beslan CRP4", seq=4, x=-153788.52539848, y=836119.64815202, radius=2777.3376 },
        { name="Beslan CRP5", seq=5, x=-149963.13489821, y=834686.57363717, radius=1388.6688 },
        { name="Beslan CRP6", seq=6, x=-151451.57700516, y=852233.49691924, radius=1388.6688 },
    },
}
