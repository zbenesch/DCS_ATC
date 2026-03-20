ATC.runways["Krasnodar-Center"] = { hdg=90, reciprocal=270, elevation=98, ILSfreq=0, patternAlt=1598,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Krasnodar-Center West", seq=1, lat=45.080617, lon=38.758150 },
        { name="Krasnodar-Center North", seq=2, lat=45.183950, lon=38.951967 },
        { name="Krasnodar-Center Bridge", seq=3, lat=44.997200, lon=38.954883 },
        { name="Krasnodar-Center Lake", seq=4, lat=45.008700, lon=38.857917 },
    }
}
