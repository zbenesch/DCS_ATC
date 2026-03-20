ATC.runways["Soganlug"] = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=0, patternAlt=3023,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Soganlug North", seq=1, lat=41.753500, lon=44.887100 },
        { name="Soganlug East", seq=2, lat=41.620400, lon=45.065000 },
        { name="Soganlug South", seq=3, lat=41.487300, lon=44.887100 },
        { name="Soganlug West", seq=4, lat=41.620400, lon=44.709100 },
    }
}
