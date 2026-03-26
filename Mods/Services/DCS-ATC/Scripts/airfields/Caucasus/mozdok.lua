ATC.runways["Mozdok"] = { hdg=80, reciprocal=260, elevation=507, ILSfreq=0, patternAlt=2007,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=119.700, hz=119700000 },
        approach = { mhz=123.200, hz=123200000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Mozdok CRP1", seq=1, x=-73065.213106631, y=841991.87637166, radius=3703.9296 },
        { name="Mozdok CRP2", seq=2, x=-79561.767415678, y=826104.45383212, radius=2777.3376 },
        { name="Mozdok CRP3", seq=3, x=-90490.262238186, y=828631.6527594, radius=2777.3376 },
        { name="Mozdok CRP4", seq=4, x=-89568.243464114, y=841265.3605041, radius=2777.3376 },
        { name="Mozdok CRP5", seq=5, x=-83785.418163525, y=843585.99506776, radius=1388.6688 },
        { name="Mozdok CRP6", seq=6, x=-86013.52, y=825669.64, radius=1388.6688 },
    },
    rwy = {
        { x=-83775.26, y=832218.65 },
        { x=-83323.35, y=835723.49 },
        { x=-83250.07, y=835710.52 },
        { x=-83705.23, y=832208.87 },
    },
}
