ATC.runways["Krymsk"] = { hdg=40, reciprocal=220, elevation=65, ILSfreq=0, patternAlt=1565,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=119.300, hz=119300000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Krymsk CRP1", seq=1, x=-7894.5212075612, y=281623.97372371, radius=3703.9296 },
        { name="Krymsk CRP2", seq=2, x=2521.5175376656, y=293623.05375871, radius=2777.3376 },
        { name="Krymsk CRP3", seq=3, x=-6511.2800715551, y=303454.7172553, radius=2777.3376 },
        { name="Krymsk CRP4", seq=4, x=-15710.443021371, y=294673.39094925, radius=2777.3376 },
        { name="Krymsk CRP5", seq=5, x=-14843.227, y=290548.553, radius=1388.6688 },
        { name="Krymsk CRP6", seq=6, x=-2691.815, y=301706.169, radius=1388.6688 },
    },
    rwy = {
        { x=-7605.54, y=293579.15 },
        { x=-5599.05, y=295232.58 },
        { x=-5561.93, y=295186.81 },
        { x=-7567.19, y=293533.19 },
    },
}
