ATC.runways["Gudauta"] = { hdg=150, reciprocal=330, elevation=68, ILSfreq=0, patternAlt=1568,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.900, hz=118900000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    chart = "charts/Caucasus - Aerodrome Charts.pdf",
    crps = {
        { name="Gudauta North", seq=1, lat=43.285400, lon=40.513600 },
        { name="Gudauta East", seq=2, lat=43.152800, lon=40.697400 },
        { name="Gudauta South", seq=3, lat=43.019100, lon=40.513600 },
        { name="Gudauta West", seq=4, lat=43.152800, lon=40.329800 },
    }
}
