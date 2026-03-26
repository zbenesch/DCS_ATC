ATC.runways["Anapa-Vityazevo"] = {
    hdg = 40, reciprocal = 220, elevation = 49,
    patternAlt = 1549,  -- elevation 49 + 1500
    frequencies = {
        ground   = { mhz = 121.500, hz = 121500000 },
        tower    = { mhz = 118.500, hz = 118500000 },
        approach = { mhz = 123.200, hz = 123200000 },
        departure= { mhz = 124.000, hz = 124000000 }
    },
    controllers = { ground = true, tower = true, approach = true, departure = true },
    crps = {
        { name="Anapa-Vityazevo CRP1", seq=1, x=-7328.8028747164, y=230385.14223174, radius=3703.9296 },
        { name="Anapa-Vityazevo CRP2", seq=2, x=3658.293721895, y=242550.73944302, radius=2777.3376 },
        { name="Anapa-Vityazevo CRP3", seq=3, x=-5633.1317919856, y=252262.65360192, radius=2777.3376 },
        { name="Anapa-Vityazevo CRP4", seq=4, x=-14428.722830973, y=244513.77026443, radius=2777.3376 },
        { name="Anapa-Vityazevo CRP5", seq=5, x=-13023.851006043, y=237929.24073948, radius=1388.6688 },
        { name="Anapa-Vityazevo CRP6", seq=6, x=-10.72, y=250442.21, radius=1388.6688 },
    },
    rwy = {
        { x=-6515.89, y=242189.78 },
        { x=-4342.77, y=244112.95 },
        { x=-4306.46, y=244069.96 },
        { x=-6478.81, y=242148.34 },
    },
}
