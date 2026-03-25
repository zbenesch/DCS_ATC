ATC.runways["Batumi"] = {
    icao = "UGSB",
    iata = "BUS",
    runways = {
        ["13/31"] = {
            length_m = 2420, width_m = 45, surface = "Hard",
            ends = {
                ["13"] = { hdg = 129, elevation = 37, lat = "N41°36.97'", lon = "E41°36.97'" },
                ["31"] = { hdg = 309, elevation = 57, lat = "N41°36.97'", lon = "E41°36.97'" }
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
    crps = {
        { name="Batumi CRP1", seq=1, x=-342907.62904603, y=617851.76426052, radius=3703.9296 },
        { name="Batumi CRP2", seq=2, x=-353937.51088995, y=626354.32217532, radius=2777.3376 },
        { name="Batumi CRP3", seq=3, x=-364800.9736339, y=618662.87860759, radius=2777.3376 },
        { name="Batumi CRP4", seq=4, x=-359159.46372704, y=608838.20242946, radius=2777.3376 },
        { name="Batumi CRP5", seq=5, x=-355074.51758461, y=608309.06852688, radius=1388.6688 },
        { name="Batumi CRP6", seq=6, x=-363461.50689943, y=622326.2401277, radius=1388.6688 },
    }
}
