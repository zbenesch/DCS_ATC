ATC.runways["Mineralnye Vody"] = { hdg=120, reciprocal=300, elevation=1049, ILSfreq=111.10, patternAlt=2549,
    frequencies = {
        ground   = { mhz=122.000, hz=122000000 },
        tower    = { mhz=119.600, hz=119600000 },
        approach = { mhz=123.700, hz=123700000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Mineralnye Vody West", seq=1, lat=44.302350, lon=42.936750 },
        { name="Mineralnye Vody North", seq=2, lat=44.279217, lon=43.166117 },
        { name="Mineralnye Vody East", seq=3, lat=44.153367, lon=43.246683 },
        { name="Mineralnye Vody South", seq=4, lat=44.120150, lon=43.108283 },
    }
}
