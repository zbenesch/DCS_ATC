ATC.runways["Gelendzhik"] = { hdg=40, reciprocal=220, elevation=82, ILSfreq=0, patternAlt=1582,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Gelendzhik West", seq=1, lat=44.37652, lon=37.56277 },
        { name="Gelendzhik East", seq=2, lat=44.32109, lon=38.06589 },
    },
    chart = "charts/Caucasus - Aerodrome Charts.pdf"
}
