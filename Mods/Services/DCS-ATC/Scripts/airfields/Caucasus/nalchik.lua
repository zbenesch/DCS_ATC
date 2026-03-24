ATC.runways["Nalchik"] = { hdg=90, reciprocal=270, elevation=1410, ILSfreq=117.60, patternAlt=2910,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=119.800, hz=119800000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Nalchik CRP1", seq=1, x=-126350.419455159994, y=772771.387420500047, radius=3703.9296 },
        { name="Nalchik CRP2", seq=2, x=-133284.684178989992, y=760340.383077210048, radius=2777.3376 },
        { name="Nalchik CRP3", seq=3, x=-122032.906246879997, y=750576.616428110050, radius=2777.3376 },
        { name="Nalchik CRP4", seq=4, x=-114847.629846459997, y=761698.503495589946, radius=2777.3376 },
        { name="Nalchik CRP5", seq=5, x=-117286.442962250003, y=766352.716076669982, radius=1388.6688 },
        { name="Nalchik CRP6", seq=6, x=-126643.768923719996, y=753897.169622519985, radius=1388.6688 },
    },
}

