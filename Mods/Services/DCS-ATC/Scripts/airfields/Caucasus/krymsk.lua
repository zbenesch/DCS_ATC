ATC.runways["Krymsk"] = { hdg=40, reciprocal=220, elevation=65, ILSfreq=0, patternAlt=1565,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=119.300, hz=119300000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Krymsk CRP1", seq=1, x=-7205.835639801700, y=283690.030426990008, radius=3703.9296 },
        { name="Krymsk CRP2", seq=2, x=1552.256368226300, y=293852.615614629991, radius=2777.3376 },
        { name="Krymsk CRP3", seq=3, x=-6613.307563075000, y=304194.416568820016, radius=2777.3376 },
        { name="Krymsk CRP4", seq=4, x=-16144.059860331001, y=295464.104008529976, radius=2777.3376 },
        { name="Krymsk CRP5", seq=5, x=-14755.831557863999, y=290456.711175500008, radius=1388.6688 },
        { name="Krymsk CRP6", seq=6, x=-2452.477815008300, y=300389.073586150014, radius=1388.6688 },
    },
}
