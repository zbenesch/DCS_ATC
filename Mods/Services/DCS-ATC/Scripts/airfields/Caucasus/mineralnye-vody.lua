ATC.runways["Mineralnye Vody"] = { hdg=120, reciprocal=300, elevation=1049, ILSfreq=111.10, patternAlt=2549,
    frequencies = {
        ground   = { mhz=122.000, hz=122000000 },
        tower    = { mhz=119.600, hz=119600000 },
        approach = { mhz=123.700, hz=123700000 },
        departure= { mhz=124.100, hz=124100000 }
    },
    controllers = { ground=true, tower=true, approach=true, departure=true },
    
    
    crps = {
        { name="Mineralnye Vody CRP1", seq=1, x=-53523.839630672, y=693052.68375833, radius=3703.9296 },
        { name="Mineralnye Vody CRP2", seq=2, x=-60050.842975842, y=708346.97526997, radius=2777.3376 },
        { name="Mineralnye Vody CRP3", seq=3, x=-48765.037891696, y=714554.37975765, radius=2777.3376 },
        { name="Mineralnye Vody CRP4", seq=4, x=-42513.597471842, y=702882.29952257, radius=2777.3376 },
        { name="Mineralnye Vody CRP5", seq=5, x=-44438.776, y=699132.634, radius=1388.6688 },
        { name="Mineralnye Vody CRP6", seq=6, x=-52969.466, y=714430.612, radius=1388.6688 },
    },
    rwy = {
        { x=-50416.9, y=703880.88 },
        { x=-52120.16, y=707487.59 },
        { x=-52064.89, y=707513.06 },
        { x=-50360.88, y=703907.56 },
    },
}
