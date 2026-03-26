ATC.runways["Al Ain International"] = { hdg=10, reciprocal=190, elevation=866, ILSfreq=110.1, patternAlt=2366,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.350, hz=118350000 },
        approach = { mhz=0, hz=0 },
        departure= { mhz=0, hz=0 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {},
}
ATC.runways["Al Ain International"].icao = "OMAL"
ATC.runways["Al Ain International"].iata = "AAN"
ATC.runways["Al Ain International"].runways = {
    ["01/19"] = {
        length_m = 4005, width_m = 45, surface = "Hard",
        ends = {
            ["01"] = { hdg = 6, elevation = 865, lat = "N24°14.63'", lon = "E55°36.39'" },
            ["19"] = { hdg = 186, elevation = 838, lat = "N24°16.78'", lon = "E55°36.70'" }
        }
    }
}
ATC.runways["Al Ain International"].frequencies = {
    ground   = { mhz = 129.150, hz = 129150000 },
    tower    = { mhz = 119.850, hz = 119850000 },
    approach = { mhz = 132.670, hz = 132670000 },
    departure= { mhz = 0, hz = 0 }
}
ATC.runways["Al Ain International"].controllers = { ground = true, tower = true, approach = true, departure = true }
-- CRPs remain unchanged
