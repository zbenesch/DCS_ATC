ATC.runways["Beslan"] = { hdg=100, reciprocal=280, elevation=1660, ILSfreq=110.50, patternAlt=3160,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=118.700, hz=118700000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Beslan CRP1", seq=1, x=-140355.526094119996, y=837113.601080290042, radius=3703.9296 },
        { name="Beslan CRP2", seq=2, x=-142518.641280920012, y=850528.384433330037, radius=2777.3376 },
        { name="Beslan CRP3", seq=3, x=-155108.127088070003, y=850484.748936800053, radius=2777.3376 },
        { name="Beslan CRP4", seq=4, x=-153654.634021829988, y=834624.527779410011, radius=2777.3376 },
        { name="Beslan CRP5", seq=5, x=-148758.112508349994, y=833972.486295029987, radius=1388.6688 },
        { name="Beslan CRP6", seq=6, x=-150201.924156410008, y=851407.833429889986, radius=1388.6688 },
    },
}
