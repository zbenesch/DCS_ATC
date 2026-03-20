ATC.runways["Tbilisi-Lochini"] = { hdg=130, reciprocal=310, elevation=1624, ILSfreq=110.30, patternAlt=3124,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Tbilisi-Lochini North", seq=1, lat=41.798100, lon=44.955000 },
        { name="Tbilisi-Lochini East", seq=2, lat=41.665000, lon=45.132900 },
        { name="Tbilisi-Lochini South", seq=3, lat=41.531900, lon=44.955000 },
        { name="Tbilisi-Lochini West", seq=4, lat=41.665000, lon=44.777100 },
    }
}
