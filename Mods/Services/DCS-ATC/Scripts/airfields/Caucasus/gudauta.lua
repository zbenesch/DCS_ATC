ATC.runways["Gudauta"] = { hdg=150, reciprocal=330, elevation=68, ILSfreq=0, patternAlt=1568,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
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
