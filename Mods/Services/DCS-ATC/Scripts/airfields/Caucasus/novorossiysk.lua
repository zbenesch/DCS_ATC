ATC.runways["Novorossiysk"] = { hdg=40, reciprocal=220, elevation=131, ILSfreq=0, patternAlt=1631,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=119.900, hz=119900000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Novorossiysk CRP1", seq=1, x=-40513.601063613, y=266367.78484166, radius=3703.9296 },
        { name="Novorossiysk CRP2", seq=2, x=-32398.91181857, y=275926.45153113, radius=2777.3376 },
        { name="Novorossiysk CRP3", seq=3, x=-40876.226062179, y=288412.01315987, radius=2777.3376 },
        { name="Novorossiysk CRP4", seq=4, x=-49665.357579912, y=281116.982491, radius=2777.3376 },
        { name="Novorossiysk CRP5", seq=5, x=-49431.396, y=276860.967, radius=1388.6688 },
        { name="Novorossiysk CRP6", seq=6, x=-37677.415, y=285708.539, radius=1388.6688 },
    },
    rwy = {
        { x=-41610.54, y=278673.84 },
        { x=-40268.6, y=279878.13 },
        { x=-40231.09, y=279839.03 },
        { x=-41570.53, y=278632.36 },
    },
}
