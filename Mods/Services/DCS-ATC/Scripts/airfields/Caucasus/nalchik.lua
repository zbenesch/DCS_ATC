ATC.runways["Nalchik"] = {
    hdg = 60, reciprocal = 240, elevation = 1443,
    patternAlt = 2943,  -- elevation 1443 + 1500
    frequencies = {
        ground   = { mhz = 121.700, hz = 121700000 },
        tower    = { mhz = 118.100, hz = 118100000 },
        approach = { mhz = 123.700, hz = 123700000 },
        departure= { mhz = 0,       hz = 0          }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    crps = {
        { name="Nalchik CRP1", seq=1, x=-125470.99429731, y=773195.9374967, radius=3703.9296 },
        { name="Nalchik CRP2", seq=2, x=-133982.15930418, y=759460.95791936, radius=2777.3376 },
        { name="Nalchik CRP3", seq=3, x=-122427.13131764, y=751547.01660229, radius=2777.3376 },
        { name="Nalchik CRP4", seq=4, x=-115909.00503697, y=761486.22845749, radius=2777.3376 },
        { name="Nalchik CRP5", seq=5, x=-118610.39004772, y=767059.28395647, radius=1388.6688 },
        { name="Nalchik CRP6", seq=6, x=-127922.52, y=751798.44, radius=1388.6688 },
    },
    rwy = {
        { x=-125588.23, y=759518.38 },
        { x=-124333.86, y=761345.36 },
        { x=-124284.16, y=761311.28 },
        { x=-125539.32, y=759485.39 },
    },
}
