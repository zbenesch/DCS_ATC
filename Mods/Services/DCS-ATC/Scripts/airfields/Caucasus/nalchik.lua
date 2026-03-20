ATC.runways["Nalchik"] = { hdg=90, reciprocal=270, elevation=1410, ILSfreq=117.60, patternAlt=2910,
    frequencies = {
        ground   = { mhz=121.600, hz=121600000 },
        tower    = { mhz=119.800, hz=119800000 },
        approach = { mhz=123.300, hz=123300000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Nalchik CRP 1", seq=1, lat=43.537917, lon=43.499400 },
        { name="Nalchik CRP 2", seq=2, lat=43.612267, lon=43.662500 },
        { name="Nalchik CRP 3", seq=3, lat=43.541617, lon=43.790283 },
        { name="Nalchik CRP 4", seq=4, lat=43.437433, lon=43.543100 },
    }
}
