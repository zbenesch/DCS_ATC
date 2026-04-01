ATC.runways["Senaki-Kolkhi"] = { 
hdg=90,
reciprocal=270,
elevation=43,
ILSfreq=108.90,
patternAlt=1543,
frequencies = {
        ground   = { mhz=121.800, hz=121800000 },
        tower    = { mhz=120.000, hz=120000000 },
        approach = { mhz=123.500, hz=123500000 },
        departure= { mhz=124.000, hz=124000000 }
    },
controllers = { ground=true, tower=true, approach=true, departure=true },


    crps = {
        { name="Senaki-Kolkhi CRP1", seq=1, x=-272049.75462929, y=639112.02830567, radius=3703.9296 },
        { name="Senaki-Kolkhi CRP2", seq=2, x=-275970.40293118, y=654294.08822111, radius=2777.3376 },
        { name="Senaki-Kolkhi CRP3", seq=3, x=-288594.38661958, y=653382.99218414, radius=2777.3376 },
        { name="Senaki-Kolkhi CRP4", seq=4, x=-286870.35946978, y=639702.81771637, radius=2777.3376 },
        { name="Senaki-Kolkhi CRP5", seq=5, x=-283107.878, y=637839.099, radius=1388.6688 },
        { name="Senaki-Kolkhi CRP6", seq=6, x=-285043.109, y=655608.034, radius=1388.6688 },
    },
    rwy = {
        { x=-281703.07, y=646068.49 },
        { x=-281905.28, y=648426.54 },
        { x=-281856.15, y=648428.03 },
        { x=-281650.12, y=646071.6 },
    },
}
