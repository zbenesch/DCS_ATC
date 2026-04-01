ATC.runways["Sukhumi"]  = { hdg=120, reciprocal=300, elevation=43, ILSfreq=0, patternAlt=1543,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=120.300, hz=120300000 },
        approach = { mhz=123.200, hz=123200000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Sukhumi CRP1", seq=1, x=-207841.39908372, y=565138.31804697, radius=3703.9296 },
        { name="Sukhumi CRP2", seq=2, x=-218331.80708509, y=573191.11294347, radius=2777.3376 },
        { name="Sukhumi CRP3", seq=3, x=-229539.59733626, y=566248.49187235, radius=2777.3376 },
        { name="Sukhumi CRP4", seq=4, x=-222765.53043191, y=555448.98498153, radius=2777.3376 },
        { name="Sukhumi CRP5", seq=5, x=-218531.083, y=555467.542, radius=1388.6688 },
        { name="Sukhumi CRP6", seq=6, x=-227513.926, y=569966.591, radius=1388.6688 },
    },
    rwy = {
        { x=-219776.47, y=562701.93 },
        { x=-221419.78, y=566005.15 },
        { x=-221378.29, y=566024.51 },
        { x=-219718.38, y=562726.83 },
    },
}
