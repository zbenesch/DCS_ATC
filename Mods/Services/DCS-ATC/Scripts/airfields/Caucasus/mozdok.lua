ATC.runways["Mozdok"] = { hdg=80, reciprocal=260, elevation=507, ILSfreq=0, patternAlt=2007,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=119.700, hz=119700000 },
        approach = { mhz=123.200, hz=123200000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Mozdok CRP1", seq=1, x=-73006.935823148, y=842224.98550559, radius=3703.9296 },
        { name="Mozdok CRP2", seq=2, x=-79561.767415678, y=826104.45383212, radius=2777.3376 },
        { name="Mozdok CRP3", seq=3, x=-90431.984954703, y=828602.51411766, radius=2777.3376 },
        { name="Mozdok CRP4", seq=4, x=-88898.05470406, y=841673.30148848, radius=2777.3376 },
        { name="Mozdok CRP5", seq=5, x=-85154.934325374, y=843440.30185905, radius=1388.6688 },
        { name="Mozdok CRP6", seq=6, x=-87091.645351715, y=826019.30633471, radius=1388.6688 },
    },
}