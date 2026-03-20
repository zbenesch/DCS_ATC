ATC.runways["Anapa-Vityazevo"] = { hdg=40, reciprocal=220, elevation=144, ILSfreq=0, patternAlt=1644,
    frequencies = {
        ground   = { mhz=121.900, hz=121900000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.600, hz=123600000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Anapa-Vityazevo West",  seq=1, lat=45.012200, lon=37.222367 },
        { name="Anapa-Vityazevo North", seq=2, lat=45.108217, lon=37.395767 },
        { name="Anapa-Vityazevo East",  seq=3, lat=45.042783, lon=37.493083 },
        { name="Anapa-Vityazevo South", seq=4, lat=44.894700, lon=37.290517 },
    }
}
