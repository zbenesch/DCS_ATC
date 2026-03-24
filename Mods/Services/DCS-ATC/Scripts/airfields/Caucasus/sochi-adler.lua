ATC.runways["Sochi-Adler"] = { hdg=60, reciprocal=240, elevation=98, ILSfreq=111.10, patternAlt=1598, patternDir="R",
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=120.100, hz=120100000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Sochi-Adler CRP1", seq=1, x=-160840.64229029, y=449952.16733834, radius=3703.9296 },
        { name="Sochi-Adler CRP2", seq=2, x=-155504.28416981, y=463821.25429138, radius=2777.3376 },
        { name="Sochi-Adler CRP3", seq=3, x=-166250.50152346, y=471187.12385959, radius=2777.3376 },
        { name="Sochi-Adler CRP4", seq=4, x=-173582.96906195, y=461333.65042794, radius=2777.3376 },
        { name="Sochi-Adler CRP5", seq=5, x=-172329.96887656, y=457641.23322671, radius=1388.6688 },
        { name="Sochi-Adler CRP6", seq=6, x=-162320.70541097, y=471217.4600837, radius=1388.6688 },
    },
}