ATC.runways["Batumi"] = { hdg=120, reciprocal=300, elevation=33, ILSfreq=110.30, patternAlt=1533,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=118.600, hz=118600000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Batumi CRP1", seq=1, x=-345918.424113880028, y=616378.738661400042, radius=3703.9296 },
        { name="Batumi CRP2", seq=2, x=-353478.388546760019, y=627045.671871070052, radius=2777.3376 },
        { name="Batumi CRP3", seq=3, x=-365470.907565650006, y=618969.931659640046, radius=2777.3376 },
        { name="Batumi CRP4", seq=4, x=-357987.079346470011, y=606325.950185379945, radius=2777.3376 },
        { name="Batumi CRP5", seq=5, x=-351770.315725689987, y=608468.849199690041, radius=1388.6688 },
        { name="Batumi CRP6", seq=6, x=-361629.491972939984, y=623499.726962130051, radius=1388.6688 },
    },
}
