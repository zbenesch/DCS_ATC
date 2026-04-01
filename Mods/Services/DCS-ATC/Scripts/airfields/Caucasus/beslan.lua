ATC.runways["Beslan"] = {
    hdg = 90, reciprocal = 270, elevation = 1671,
    patternAlt = 3171,  -- elevation 1671 + 1500
    frequencies = {
        ground   = { mhz = 121.700, hz = 121700000 },
        tower    = { mhz = 118.700, hz = 118700000 },
        approach = { mhz = 123.400, hz = 123400000 },
        departure= { mhz = 124.200, hz = 124200000 }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    crps = {
        { name="Beslan CRP1", seq=1, x=-138503.36205044, y=835797.00254322, radius=3703.9296 },
        { name="Beslan CRP2", seq=2, x=-142540.95651036, y=850483.75397445, radius=2777.3376 },
        { name="Beslan CRP3", seq=3, x=-154867.02191507, y=850196.49658943, radius=2777.3376 },
        { name="Beslan CRP4", seq=4, x=-154547.74667461, y=836787.76287501, radius=2777.3376 },
        { name="Beslan CRP5", seq=5, x=-150751.11, y=835086.796, radius=1388.6688 },
        { name="Beslan CRP6", seq=6, x=-151412.111, y=852406.761, radius=1388.6688 },
    },
    rwy = {
        { x=-148520.77, y=842156.11 },
        { x=-148704.24, y=845161.48 },
        { x=-148658.57, y=845164.76 },
        { x=-148474.14, y=842159.38 },
    },
}
