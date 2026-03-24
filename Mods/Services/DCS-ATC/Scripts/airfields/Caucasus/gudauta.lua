ATC.runways["Gudauta"] = { hdg=330, reciprocal=150, elevation=68, ILSfreq=0, patternAlt=1568,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.900, hz=118900000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.400, hz=124400000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    chart = "charts/Caucasus - Aerodrome Charts.pdf",
    
    crps = {
        { name="Gudauta CRP1", seq=1, x=-205863.651172100013, y=513969.605325959972, radius=3703.9296 },
        { name="Gudauta CRP2", seq=2, x=-195963.175832250010, y=507883.024768120027, radius=2777.3376 },
        { name="Gudauta CRP3", seq=3, x=-187307.978363780014, y=518245.532721269992, radius=2777.3376 },
        { name="Gudauta CRP4", seq=4, x=-198262.854949989996, y=525672.276305670035, radius=2777.3376 },
        { name="Gudauta CRP5", seq=5, x=-202336.153203149996, y=522034.436097819998, radius=1388.6688 },
        { name="Gudauta CRP6", seq=6, x=-191085.929611730011, y=513565.320712359971, radius=1388.6688 },
    },
}

