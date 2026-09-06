ATC.runways["Gelendzhik"] = { hdg=40, reciprocal=220, elevation=82, ILSfreq=0, patternAlt=1582,
    frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=118.800, hz=118800000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.300, hz=124300000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    crps = {
        { name="Gelendzhik CRP1", seq=1, x=-50973.734709297, y=285533.43377942, radius=3703.9296 },
        { name="Gelendzhik CRP2", seq=2, x=-41646.120220449, y=295881.61513512, radius=2777.3376 },
        { name="Gelendzhik CRP3", seq=3, x=-53918.199332409, y=306762.27650162, radius=2777.3376 },
        { name="Gelendzhik CRP4", seq=4, x=-59495.010887119, y=298771.24245889, radius=2777.3376 },
        { name="Gelendzhik CRP5", seq=5, x=-58141.964, y=294850.415, radius=1388.6688 },
        { name="Gelendzhik CRP6", seq=6, x=-49995.83, y=304570.633, radius=1388.6688 },
    },
    rwy = {
        { x=-51104.11, y=297833.04 },
        { x=-49723.99, y=298991.24 },
        { x=-49689.35, y=298949.23 },
        { x=-51068.98, y=297790.65 },
    },
}