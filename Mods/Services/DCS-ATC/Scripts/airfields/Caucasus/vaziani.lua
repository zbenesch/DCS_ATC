ATC.runways["Vaziani"] = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=117.60, patternAlt=3023,
    frequencies = {
        ground   = { mhz=121.700, hz=121699997 },
        tower    = { mhz=120.500, hz=120500000 },
        approach = { mhz=123.400, hz=123400002 },
        departure= { mhz=124.000, hz=124000000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Vaziani North", seq=1, lat=41.810100, lon=45.148300 },
        { name="Vaziani East", seq=2, lat=41.677000, lon=45.326200 },
        { name="Vaziani South", seq=3, lat=41.543900, lon=45.148300 },
        { name="Vaziani West", seq=4, lat=41.677000, lon=44.970400 },
    }
}
