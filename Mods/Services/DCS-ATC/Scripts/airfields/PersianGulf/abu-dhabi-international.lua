ATC.runways["Abu Dhabi International"] = {
    hdg = 126, reciprocal = 306, elevation = 78,
    patternAlt = 1578,  -- elevation 78 + 1500
    frequencies = {
        ground   = { mhz = 121.900, hz = 121900000 },
        tower    = { mhz = 118.670, hz = 118670000 },
        approach = { mhz = 118.000, hz = 118000000 },
        departure= { mhz = 0,       hz = 0          }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    crps = {},
}
