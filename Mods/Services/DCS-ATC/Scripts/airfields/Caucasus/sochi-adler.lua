ATC.runways["Sochi-Adler"] = { hdg=60, reciprocal=240, elevation=98, ILSfreq=111.10, patternAlt=1598, patternDir="R",
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=120.100, hz=120100000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Sochi-Adler CRP1", seq=1, x=-160945.022381760005, y=450317.497658490029, radius=3703.9296 },
        { name="Sochi-Adler CRP2", seq=2, x=-156835.130336060014, y=463612.494108440005, radius=2777.3376 },
        { name="Sochi-Adler CRP3", seq=3, x=-166015.646317650011, y=470743.508470839995, radius=2777.3376 },
        { name="Sochi-Adler CRP4", seq=4, x=-173739.539199160005, y=460811.749970589997, radius=2777.3376 },
        { name="Sochi-Adler CRP5", seq=5, x=-169962.067477459990, y=455849.200407519995, radius=1388.6688 },
        { name="Sochi-Adler CRP6", seq=6, x=-161754.535036560002, y=467932.807755169983, radius=1388.6688 },
    },
}