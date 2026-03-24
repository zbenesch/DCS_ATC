ATC.runways["Nalchik"] = { hdg=90, reciprocal=270, elevation=1410, ILSfreq=117.60, patternAlt=2910,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=119.800, hz=119800000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Nalchik CRP1", seq=1, x=-125470.99429731, y=773195.9374967, radius=3703.9296 },
        { name="Nalchik CRP2", seq=2, x=-133982.15930418, y=759460.95791936, radius=2777.3376 },
        { name="Nalchik CRP3", seq=3, x=-122427.13131764, y=751547.01660229, radius=2777.3376 },
        { name="Nalchik CRP4", seq=4, x=-115909.00503697, y=761486.22845749, radius=2777.3376 },
        { name="Nalchik CRP5", seq=5, x=-117225.79295136, y=765473.29091882, radius=1388.6688 },
        { name="Nalchik CRP6", seq=6, x=-126613.44391828, y=751471.16918707, radius=1388.6688 },
    },
}

