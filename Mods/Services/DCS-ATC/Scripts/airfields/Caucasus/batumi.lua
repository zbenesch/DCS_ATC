ATC.runways["Batumi"] = { hdg=120, reciprocal=300, elevation=33, ILSfreq=110.30, patternAlt=1533,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=118.600, hz=118600000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Batumi CRP1", seq=1, x=-342907.62904603, y=617851.76426052, radius=3703.9296 },
        { name="Batumi CRP2", seq=2, x=-353937.51088995, y=626354.32217532, radius=2777.3376 },
        { name="Batumi CRP3", seq=3, x=-364800.9736339, y=618662.87860759, radius=2777.3376 },
        { name="Batumi CRP4", seq=4, x=-359159.46372704, y=608838.20242946, radius=2777.3376 },
        { name="Batumi CRP5", seq=5, x=-355074.51758461, y=608309.06852688, radius=1388.6688 },
        { name="Batumi CRP6", seq=6, x=-363461.50689943, y=622326.2401277, radius=1388.6688 },
    },
}
