ATC.runways["Gelendzhik"] = { hdg=40, reciprocal=220, elevation=82, ILSfreq=0, patternAlt=1582,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    crps = {
        { name="Gelendzhik CRP1", seq=1, x=-50243.091434866998, y=286975.709827689978, radius=3703.9296 },
        { name="Gelendzhik CRP2", seq=2, x=-43367.369122538999, y=296637.677736970014, radius=2777.3376 },
        { name="Gelendzhik CRP3", seq=3, x=-51195.599280795002, y=305696.911264029972, radius=2777.3376 },
        { name="Gelendzhik CRP4", seq=4, x=-59045.190009026002, y=298842.266808059998, radius=2777.3376 },
        { name="Gelendzhik CRP5", seq=5, x=-56178.608720816002, y=295055.553461630014, radius=1388.6688 },
        { name="Gelendzhik CRP6", seq=6, x=-47648.586015658002, y=302345.144738339994, radius=1388.6688 },
    },
}
