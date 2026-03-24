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
        { name="Kobuleti CRP1", seq=1, x=-312731.049518799991, y=626199.574710189947, radius=3703.9296 },
        { name="Kobuleti CRP2", seq=2, x=-309353.785705289978, y=637369.616329160053, radius=2777.3376 },
        { name="Kobuleti CRP3", seq=3, x=-320630.636335020012, y=645683.037872600020, radius=2777.3376 },
        { name="Kobuleti CRP4", seq=4, x=-326755.007846880006, y=630475.693059989950, radius=2777.3376 },
        { name="Kobuleti CRP5", seq=5, x=-322120.473888119974, y=627590.896073860000, radius=1388.6688 },
        { name="Kobuleti CRP6", seq=6, x=-315935.397207310016, y=643390.919436909957, radius=1388.6688 },
    },
}
