ATC.runways["Krymsk"] = { hdg=40, reciprocal=220, elevation=65, ILSfreq=0, patternAlt=1565,
    frequencies = {
        ground   = { mhz=121.700, hz=121699997 },
        tower    = { mhz=119.300, hz=119300003 },
        approach = { mhz=123.400, hz=123400002 },
        departure= { mhz=124.300, hz=124300003 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Krymsk CRP 1", seq=1, lat=44.941800, lon=37.801333 },
        { name="Krymsk CRP 2", seq=2, lat=45.107650, lon=38.024167 },
        { name="Krymsk CRP 3", seq=3, lat=45.033300, lon=38.208483 },
        { name="Krymsk CRP 4", seq=4, lat=44.834767, lon=37.904267 },
    }
}
