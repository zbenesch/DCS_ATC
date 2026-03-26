ATC.runways["Kobuleti"] = { hdg=70, reciprocal=250, elevation=59, ILSfreq=111.50, patternAlt=1559,
    frequencies = {
        ground   = { mhz=122.000, hz=122000000 },
        tower    = { mhz=119.000, hz=119000000 },
        approach = { mhz=123.700, hz=123700000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Kobuleti CRP1", seq=1, x=-312480.01100295, y=624023.9075728, radius=3703.9296 },
        { name="Kobuleti CRP2", seq=2, x=-309130.64035787, y=637788.01385558, radius=2777.3376 },
        { name="Kobuleti CRP3", seq=3, x=-320881.67485087, y=644232.59311434, radius=2777.3376 },
        { name="Kobuleti CRP4", seq=4, x=-325973.99913089, y=631228.80860755, radius=2777.3376 },
        { name="Kobuleti CRP5", seq=5, x=-322389.2208359, y=627697.94320208, radius=1388.6688 },
        { name="Kobuleti CRP6", seq=6, x=-316176.03, y=644537.48, radius=1388.6688 },
    },
    rwy = {
        { x=-318391.96, y=634531.99 },
        { x=-317572.33, y=636794.16 },
        { x=-317525.49, y=636768.4 },
        { x=-318342.78, y=634510.91 },
    },
}
