ATC.runways["Beslan"] = { hdg=100, reciprocal=280, elevation=1660, ILSfreq=110.50, patternAlt=3160,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Beslan West",  seq=1, lat=43.144250, lon=44.280410 },
        { name="Beslan North", seq=2, lat=43.167000, lon=44.377520 },
        { name="Beslan East",  seq=3, lat=43.114470, lon=44.450070 },
        { name="Beslan South", seq=4, lat=43.088390, lon=44.348640 },
    }
}
