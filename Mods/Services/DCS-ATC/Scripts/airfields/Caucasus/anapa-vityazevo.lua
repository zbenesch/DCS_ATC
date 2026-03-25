ATC.runways["Anapa-Vityazevo"] = {
    icao = "URKA",
    iata = "AAQ",
    runways = {
        ["04/22"] = {
            length_m = 2500, width_m = 49, surface = "Hard",
            ends = {
                ["04"] = { hdg = 40, elevation = 49, lat = "N45°00.97'", lon = "E37°20.97'" },
                ["22"] = { hdg = 220, elevation = 144, lat = "N44°59.97'", lon = "E37°23.13'" }
            }
        }
    },
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
        { name="Anapa-Vityazevo CRP5", seq=5, x=-14166.605255138, y=240502.1401143, radius=1388.6688 },
        { name="Anapa-Vityazevo CRP6", seq=6, x=-1833.64406689, y=251447.15294069, radius=1388.6688 },
    }
}