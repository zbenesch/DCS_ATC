ATC.runways["Mozdok"] = { hdg=80, reciprocal=260, elevation=507, ILSfreq=0, patternAlt=2007,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=119.700, hz=119700000 },
        approach = { mhz=123.200, hz=123200000 },
        departure= { mhz=124.200, hz=124200000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Mozdok CRP1", seq=1, x=-75102.864364088993, y=839783.845204959973, radius=3703.9296 },
        { name="Mozdok CRP2", seq=2, x=-78057.630462767003, y=826474.323574639973, radius=2777.3376 },
        { name="Mozdok CRP3", seq=3, x=-91073.092508403002, y=827986.064546789974, radius=2777.3376 },
        { name="Mozdok CRP4", seq=4, x=-89292.582429414004, y=842684.278784699971, radius=2777.3376 },
        { name="Mozdok CRP5", seq=5, x=-84513.826771673994, y=843464.959841880016, radius=1388.6688 },
        { name="Mozdok CRP6", seq=6, x=-86351.905866677000, y=825254.908866839949, radius=1388.6688 },
    },
}