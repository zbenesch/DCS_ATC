ATC.runways["Batumi"] = { hdg=120, reciprocal=300, elevation=33, ILSfreq=110.30, patternAlt=1533,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Batumi North", seq=1, lat=41.430880, lon=41.434030 },
        { name="Batumi East",  seq=2, lat=41.384870, lon=41.430170 },
        { name="Batumi South", seq=3, lat=41.325090, lon=41.331350 },
    }
}
