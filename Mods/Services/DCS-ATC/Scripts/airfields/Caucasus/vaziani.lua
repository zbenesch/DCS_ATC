ATC.runways["Vaziani"] = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=117.60, patternAlt=3023,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Vaziani North", seq=1, lat=41.810100, lon=45.148300 },
        { name="Vaziani East", seq=2, lat=41.677000, lon=45.326200 },
        { name="Vaziani South", seq=3, lat=41.543900, lon=45.148300 },
        { name="Vaziani West", seq=4, lat=41.677000, lon=44.970400 },
    }
}
