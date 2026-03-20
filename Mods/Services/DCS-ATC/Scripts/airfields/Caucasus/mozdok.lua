ATC.runways["Mozdok"] = { hdg=80, reciprocal=260, elevation=507, ILSfreq=0, patternAlt=2007,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Mozdok CRP 1", seq=1, lat=43.819600, lon=44.421367 },
        { name="Mozdok CRP 2", seq=2, lat=43.864450, lon=44.750700 },
        { name="Mozdok CRP 3", seq=3, lat=43.744133, lon=44.772083 },
        { name="Mozdok CRP 4", seq=4, lat=43.712400, lon=44.496583 },
    }
}
