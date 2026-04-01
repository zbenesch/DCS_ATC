ATC.runways["Batumi"] = { hdg=130, reciprocal=310, elevation=98, ILSfreq=111.10, patternAlt=1598, patternDir="R",
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=120.100, hz=120100000 },
        approach = { mhz=123.900, hz=123900000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Batumi CRP1", seq=1, x=-342907.62904603, y=617851.76426052, radius=3703.9296 },
        { name="Batumi CRP2", seq=2, x=-353937.51088995, y=626354.32217532, radius=2777.3376 },
        { name="Batumi CRP3", seq=3, x=-364800.9736339, y=618662.87860759, radius=2777.3376 },
        { name="Batumi CRP4", seq=4, x=-359159.46372704, y=608838.20242946, radius=2777.3376 },
        { name="Batumi CRP5", seq=5, x=-354944.867, y=609455.313, radius=1388.6688 },
        { name="Batumi CRP6", seq=6, x=-362274.914, y=622063.386, radius=1388.6688 },
    },
    rwy = {
        { x=-355148.51, y=616408.07 },
        { x=-356570.31, y=618397.65 },
        { x=-356511.95, y=618436.55 },
        { x=-355103.94, y=616448.59 },
    },
}
