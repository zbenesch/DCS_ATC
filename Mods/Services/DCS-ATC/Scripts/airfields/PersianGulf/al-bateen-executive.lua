ATC.runways["Al Bateen Executive"] = { hdg=130, reciprocal=310, elevation=16, ILSfreq=0, patternAlt=0,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.300, hz=118300000 },
        approach = { mhz=0, hz=0 },
        departure= { mhz=0, hz=0 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {},
}
ATC.runways["Al Bateen Executive"].icao = "OMAD"
ATC.runways["Al Bateen Executive"].iata = "AZI"
ATC.runways["Al Bateen Executive"].runways = {
    ["13/31"] = {
        length_m = 3202, width_m = 45, surface = "Hard",
        ends = {
            ["13"] = { hdg = 126, elevation = 15, lat = "N24°26.06'", lon = "E54°26.99'" },
            ["31"] = { hdg = 306, elevation = 13, lat = "N24°25.32'", lon = "E54°28.03'" }
        }
    }
}
ATC.runways["Al Bateen Executive"].frequencies = {
    ground   = { mhz = 120.370, hz = 120370000 },
    tower    = { mhz = 119.900, hz = 119900000 },
    approach = { mhz = 124.400, hz = 124400000 },
    departure= { mhz = 0, hz = 0 }
}
ATC.runways["Al Bateen Executive"].controllers = { ground = true, tower = true, approach = true, departure = true }
-- CRPs remain unchanged
