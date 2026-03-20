ATC.runways["Anapa-Vityazevo"] = { hdg=40, reciprocal=220, elevation=144, ILSfreq=0, patternAlt=1644,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=118.500, hz=118500000 },
        approach = { mhz=123.200, hz=123199997 },
        departure= { mhz=124.000, hz=124000000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Anapa-Vityazevo West",  seq=1, lat=45.012200, lon=37.222367 },
        { name="Anapa-Vityazevo North", seq=2, lat=45.108217, lon=37.395767 },
        { name="Anapa-Vityazevo East",  seq=3, lat=45.042783, lon=37.493083 },
        { name="Anapa-Vityazevo South", seq=4, lat=44.894700, lon=37.290517 },
    }
}
