ATC.runways["Sochi-Adler"] = { hdg=60, reciprocal=240, elevation=98, ILSfreq=111.10, patternAlt=1598, patternDir="R",
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Sochi-Adler North", seq=1, lat=43.602500, lon=39.961500 },
        { name="Sochi-Adler East", seq=2, lat=43.469400, lon=40.146200 },
        { name="Sochi-Adler South", seq=3, lat=43.336300, lon=39.961500 },
        { name="Sochi-Adler West", seq=4, lat=43.469400, lon=39.776700 },
    }
}
