local sukhumiRwy = { hdg=120, reciprocal=300, elevation=43, ILSfreq=0, patternAlt=1543,
    frequencies = {
        ground   = { mhz=121.500, hz=121500000 },
        tower    = { mhz=120.300, hz=120300003 },
        approach = { mhz=123.200, hz=123199997 },
        departure= { mhz=124.300, hz=124300003 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Sukhumi North", seq=1, lat=42.980633, lon=40.969017 },
        { name="Sukhumi East", seq=2, lat=42.922683, lon=41.178767 },
        { name="Sukhumi South", seq=3, lat=42.802633, lon=41.278217 },
        { name="Sukhumi West", seq=4, lat=42.786400, lon=41.162683 },
    }
}
ATC.runways["Sukhumi"] = sukhumiRwy
ATC.runways["Sukhumi-Babushara"] = sukhumiRwy
