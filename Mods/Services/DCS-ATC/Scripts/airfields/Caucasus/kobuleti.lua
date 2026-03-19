ATC.runways["Kobuleti"] = { hdg=70, reciprocal=250, elevation=59, ILSfreq=111.50, patternAlt=1559, patternDir="R",
    ctrlZoneNm  = 8,
    patternAlts = { 4500, 3500, 2500, 1500 },
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Black Sea", seq=1, lat=42.018767, lon=41.752067 },
        { name="NE",        seq=2, lat=42.000733, lon=42.001550 },
        { name="East",      seq=3, lat=41.909883, lon=42.007750 },
        { name="South",     seq=4, lat=41.823583, lon=41.772667 },
    },
    chart = "charts/Caucasus - Aerodrome Charts.pdf"
}
