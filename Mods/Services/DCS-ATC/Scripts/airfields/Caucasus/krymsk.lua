ATC.runways["Krymsk"] = { hdg=40, reciprocal=220, elevation=65, ILSfreq=0, patternAlt=1565,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Krymsk CRP 1", seq=1, lat=44.941800, lon=37.801333 },
        { name="Krymsk CRP 2", seq=2, lat=45.107650, lon=38.024167 },
        { name="Krymsk CRP 3", seq=3, lat=45.033300, lon=38.208483 },
        { name="Krymsk CRP 4", seq=4, lat=44.834767, lon=37.904267 },
    }
}
