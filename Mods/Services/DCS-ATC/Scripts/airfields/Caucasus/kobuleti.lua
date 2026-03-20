ATC.runways["Kobuleti"] = { hdg=70, reciprocal=250, elevation=59, ILSfreq=111.50, patternAlt=1559, patternDir="R",
    ctrlZoneNm  = 8,
    patternAlts = { 4500, 3500, 2500, 1500 },
    frequencies = {
        ground   = { mhz=122.000, hz=122000000 },
        tower    = { mhz=119.000, hz=119000000 },
        approach = { mhz=123.700, hz=123700000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Kobuleti NW", seq=1, lat=42.018767, lon=41.752067 },
        { name="Kobuleti NE", seq=2, lat=42.000733, lon=42.001550 },
        { name="Kobuleti SE", seq=3, lat=41.909883, lon=42.007750 },
        { name="Kobuleti SW", seq=4, lat=41.823583, lon=41.772667 },
    },
    chart = "Charts/pages/page_14.png"
}
