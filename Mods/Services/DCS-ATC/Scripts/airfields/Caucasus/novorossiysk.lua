ATC.runways["Novorossiysk"] = { hdg=40, reciprocal=220, elevation=131, ILSfreq=0, patternAlt=1631,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=119.900, hz=119900000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Novorossiysk North", seq=1, lat=44.825700, lon=37.751800 },
        { name="Novorossiysk East", seq=2, lat=44.692600, lon=37.938600 },
        { name="Novorossiysk South", seq=3, lat=44.559500, lon=37.751800 },
        { name="Novorossiysk West", seq=4, lat=44.692600, lon=37.565000 },
    }
}
