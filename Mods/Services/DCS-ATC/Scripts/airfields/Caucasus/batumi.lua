ATC.runways["Batumi"] = { hdg=120, reciprocal=300, elevation=33, ILSfreq=110.30, patternAlt=1533,
    frequencies = {
        ground   = { mhz=121.600, hz=121599998 },
        tower    = { mhz=118.600, hz=118599998 },
        approach = { mhz=123.300, hz=123300003 },
        departure= { mhz=124.100, hz=124099998 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Batumi North", seq=1, lat=41.430880, lon=41.434030 },
        { name="Batumi East",  seq=2, lat=41.384870, lon=41.430170 },
        { name="Batumi South", seq=3, lat=41.325090, lon=41.331350 },
        { name="Batumi West",  seq=4, lat=41.368000, lon=41.245000 },
    }
}
