ATC.runways["Tbilisi-Lochini"] = { hdg=130, reciprocal=310, elevation=1624, ILSfreq=110.30, patternAlt=3124,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=120.400, hz=120400000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Tbilisi-Lochini North", seq=1, lat=41.798100, lon=44.955000 },
        { name="Tbilisi-Lochini East", seq=2, lat=41.665000, lon=45.132900 },
        { name="Tbilisi-Lochini South", seq=3, lat=41.531900, lon=44.955000 },
        { name="Tbilisi-Lochini West", seq=4, lat=41.665000, lon=44.777100 },
    }
}
