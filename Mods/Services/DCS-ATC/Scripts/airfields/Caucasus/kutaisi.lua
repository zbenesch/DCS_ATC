ATC.runways["Kutaisi"] = { hdg=80, reciprocal=260, elevation=147, ILSfreq=109.75, patternAlt=1647,
    frequencies = {
        ground   = { mhz=122.000, hz=122000000 },
        tower    = { mhz=118.900, hz=118900000 },
        approach = { mhz=123.700, hz=123700000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Kutaisi CRP 1", seq=1, lat=42.130067, lon=42.300300 },
        { name="Kutaisi CRP 2", seq=2, lat=42.265400, lon=42.501433 },
        { name="Kutaisi CRP 3", seq=3, lat=42.202883, lon=42.652417 },
        { name="Kutaisi CRP 4", seq=4, lat=42.104617, lon=42.530400 },
    }
}
