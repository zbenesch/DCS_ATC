ATC.runways["Abu Dhabi International"] = {
    icao = "OMAA",
    iata = "AUH",
    runways = {
        ["13R/31L"] = {
            length_m = 4106, width_m = 60, surface = "Hard",
            ends = {
                ["13R"] = { hdg = 126, elevation = 78, lat = "N24°26.66'", lon = "E54°38.11'" },
                ["31L"] = { hdg = 306, elevation = 83, lat = "N24°25.30'", lon = "E54°40.03'" }
            }
        },
        ["13L/31R"] = {
            length_m = 4100, width_m = 60, surface = "Unknown",
            ends = {
                ["13L"] = { hdg = 126, elevation = 62, lat = "N24°27.90'", lon = "E54°38.30'" },
                ["31R"] = { hdg = 306, elevation = 72, lat = "N24°26.54'", lon = "E54°40.21'" }
            }
        }
    },
    frequencies = {
        ground   = { mhz = 121.900, hz = 121900000 },
        tower    = { mhz = 118.670, hz = 118670000 },
        approach = { mhz = 118.000, hz = 118000000 },
        departure= { mhz = 0, hz = 0 }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    crps = {}
}
