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
        { name="Krymsk CRP5", seq=5, x=-15036.407159544, y=290992.35550598, radius=1388.6688 },
        { name="Krymsk CRP6", seq=6, x=-2554.5053065282, y=302480.63716231, radius=1388.6688 },
    },
}
