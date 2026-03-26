ATC.runways["Vaziani"] = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=117.60, patternAlt=3023,
    frequencies = {
        ground   = { mhz=121.700, hz=121700000 },
        tower    = { mhz=120.500, hz=120500000 },
        approach = { mhz=123.400, hz=123400000 },
        departure= { mhz=124.000, hz=124000000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Vaziani CRP1", seq=1, x=-306472.66443629, y=905370.59559243, radius=3703.9296 },
        { name="Vaziani CRP2", seq=2, x=-318685.66365478, y=912306.89194268, radius=2777.3376 },
        { name="Vaziani CRP3", seq=3, x=-328229.93032252, y=903562.84981253, radius=2777.3376 },
        { name="Vaziani CRP4", seq=4, x=-320646.93687447, y=894118.83981083, radius=2777.3376 },
        { name="Vaziani CRP5", seq=5, x=-313649.13104622, y=895790.11530536, radius=1388.6688 },
        { name="Vaziani CRP6", seq=6, x=-326508.38, y=908454.21, radius=1388.6688 },
    },
    rwy = {
        { x=-318194.72, y=902258.44 },
        { x=-319953.53, y=903983.72 },
        { x=-319910.34, y=904026.84 },
        { x=-318156.87, y=902296.46 },
    },
}
