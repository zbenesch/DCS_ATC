-- Taxiway graph definitions for DCS-ATC
local ATC = ATC or {}

ATC.taxiwayGraphs = ATC.taxiwayGraphs or {}
ATC.taxiwayGraphs["Kobuleti"] = {
  nodes = {
    -- Aprons and parking
    Apron_N = { name = "Apron North", lat = 41.930800, lon = 41.858500, edges = {"N1"} },
    Apron_C = { name = "Apron Center", lat = 41.928400, lon = 41.855500, edges = {"C1"} },
    Apron_B = { name = "Apron Bravo", lat = 41.931700, lon = 41.873900, edges = {"B1"} },
    Apron_S = { name = "Apron South", lat = 41.926000, lon = 41.860000, edges = {"S1"} },
    Papa = { name = "Papa (Maintenance)", lat = 41.929000, lon = 41.852000, edges = {"N1"} },

    -- Taxiways (Alpha, Bravo, Charlie, November, Sierra)
    N1 = { name = "Taxiway November 1", lat = 41.930600, lon = 41.858000, edges = {"Apron_N", "N2", "Papa"} },
    N2 = { name = "Taxiway November 2", lat = 41.930400, lon = 41.857500, edges = {"N1", "N3"} },
    N3 = { name = "Taxiway November 3", lat = 41.930200, lon = 41.857000, edges = {"N2", "N4"} },
    N4 = { name = "Taxiway November 4", lat = 41.930000, lon = 41.856500, edges = {"N3", "N5"} },
    N5 = { name = "Taxiway November 5", lat = 41.929800, lon = 41.856000, edges = {"N4", "N6"} },
    N6 = { name = "Taxiway November 6", lat = 41.929600, lon = 41.855500, edges = {"N5", "N7"} },
    N7 = { name = "Taxiway November 7", lat = 41.929400, lon = 41.855000, edges = {"N6", "N8"} },
    N8 = { name = "Taxiway November 8", lat = 41.929200, lon = 41.854500, edges = {"N7", "N9"} },
    N9 = { name = "Taxiway November 9", lat = 41.929000, lon = 41.854000, edges = {"N8"} },

    C1 = { name = "Taxiway Charlie 1", lat = 41.928200, lon = 41.855000, edges = {"Apron_C", "C2"} },
    C2 = { name = "Taxiway Charlie 2", lat = 41.928000, lon = 41.854500, edges = {"C1", "C3"} },
    C3 = { name = "Taxiway Charlie 3", lat = 41.927800, lon = 41.854000, edges = {"C2"} },

    B1 = { name = "Taxiway Bravo 1", lat = 41.931500, lon = 41.873400, edges = {"Apron_B", "B2"} },
    B2 = { name = "Taxiway Bravo 2", lat = 41.931300, lon = 41.872900, edges = {"B1", "A1"} },

    A1 = { name = "Taxiway Alpha 1", lat = 41.931000, lon = 41.872000, edges = {"B2", "A2"} },
    A2 = { name = "Taxiway Alpha 2", lat = 41.930500, lon = 41.871000, edges = {"A1", "RWY25_Alpha"} },

    S1 = { name = "Taxiway Sierra 1", lat = 41.926500, lon = 41.860500, edges = {"Apron_S", "S2"} },
    S2 = { name = "Taxiway Sierra 2", lat = 41.927000, lon = 41.861000, edges = {"S1", "RWY07_Sierra"} },

    -- Echo intersection (for RWY25/Echo)
    E1 = { name = "Taxiway Echo 1", lat = 41.934000, lon = 41.881000, edges = {"RWY25_Echo"} },

    -- Holding Positions
    P1 = { name = "Holding Position P1", lat = 41.930900, lon = 41.858200, edges = {"N1"} },
    P2 = { name = "Holding Position P2", lat = 41.928500, lon = 41.855700, edges = {"C1"} },
    P3 = { name = "Holding Position P3", lat = 41.931600, lon = 41.873600, edges = {"B1"} },
    RWY25_Echo = { name = "RWY25/Echo Intersection", lat = 41.934100, lon = 41.881100, edges = {"E1"} },
    RWY25_Alpha = { name = "RWY25/Alpha Intersection", lat = 41.930600, lon = 41.871100, edges = {"A2"} },
    RWY07_Sierra = { name = "RWY07/Sierra Intersection", lat = 41.927100, lon = 41.861100, edges = {"S2"} },

    -- Runway thresholds
    RWY25 = { name = "Runway 25 Threshold", lat = 41.934200, lon = 41.880783, edges = {"RWY25_Echo"} },
    RWY07 = { name = "Runway 07 Threshold", lat = 41.927200, lon = 41.860900, edges = {"RWY07_Sierra"} }
  }
}

return ATC
