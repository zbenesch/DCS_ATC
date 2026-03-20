ATC.runways["Senaki-Kolkhi"] = { hdg=90, reciprocal=270, elevation=43, ILSfreq=108.90, patternAlt=1543,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=120.000, hz=120000000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.000, hz=124000000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Senaki-Kolkhi West", seq=1, lat=42.315067, lon=41.911783 },
        { name="Senaki-Kolkhi North", seq=2, lat=42.283100, lon=42.144483 },
        { name="Senaki-Kolkhi East", seq=3, lat=42.164217, lon=42.170200 },
        { name="Senaki-Kolkhi South", seq=4, lat=42.191433, lon=41.921933 },
    }
}
