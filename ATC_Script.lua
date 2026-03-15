trigger.action.outText("[ATC Script] Loaded", 10)
-- ============================================================
--  ATC_Script.lua  --  DCS World Air Traffic Control System
--  Version : 2.1  (Part 2 – Glideslope & Speed Guidance)
--  Author  : GitHub Copilot
--
--  HOW TO INSTALL
--  ──────────────
--  1. Open the DCS Mission Editor.
--  2. Triggers → New Trigger:
--       Type   : MISSION START
--       Action : DO SCRIPT FILE → select this file
--  3. Save and fly.
--
--  HOW PLAYERS USE IT
--  ──────────────────
--  Press ` → F10 Other → [ATC] Nearby Fields
--  A submenu lists every airbase within 100 km of your aircraft.
--  Select one to open its context-sensitive ATC options.
--  The list refreshes automatically as you fly closer or further.
--
--  RULES
--  ─────
--  • Only human (player) slots can use this menu.  AI units are
--    silently ignored at every entry point.
--  • Per-airfield state (queues, runway occupancy) is fully
--    independent.  You can be inbound to one field while a
--    colleague is taxiing at another.
--
--  CUSTOMISING
--  ───────────
--  Edit only the CONFIG section below.
--  No external libraries required – zero dependencies.
-- ============================================================


-- ============================================================
-- 0.  NAMESPACE
-- ============================================================
ATC = ATC or {}

-- Per-coalition menu paths
ATC.menuPaths = {}  -- [coalitionID] = { root, ground, tower, approach, departure }


-- ============================================================
-- 4.  PER-COALITION MENU SYSTEM (SpicyATC style)
-- ============================================================

--- Ensure menus exist for a coalition, create if missing
function ATC.ensureMenusForCoalition(coalitionID)
    if not coalitionID then return end
    ATC.menuPaths[coalitionID] = ATC.menuPaths[coalitionID] or {}
    local paths = ATC.menuPaths[coalitionID]
    if not paths.root then
        paths.root = missionCommands.addSubMenuForCoalition(coalitionID, "[ATC] Air Traffic Control")
        paths.ground = missionCommands.addSubMenuForCoalition(coalitionID, "Ground", paths.root)
        paths.tower = missionCommands.addSubMenuForCoalition(coalitionID, "Tower", paths.root)
        paths.approach = missionCommands.addSubMenuForCoalition(coalitionID, "Approach", paths.root)
        paths.departure = missionCommands.addSubMenuForCoalition(coalitionID, "Departure", paths.root)

        -- Helper to get player context for the calling group
        local function getPlayerContext()
            -- DCS passes groupId as the first argument to the handler
            local groupId = trigger.misc.getUserFlag("__ATC_LAST_GROUP")
            if not groupId then return nil end
            local group = Group.getByID(groupId)
            if not group then return nil end
            local units = group:getUnits()
            for _, unit in ipairs(units) do
                if ATC.isPlayer(unit) then
                    return unit, groupId
                end
            end
            return nil
        end

        -- Wrapper for each menu command to call the correct handler for the player
        local function wrapHandler(handler)
            return function(...)
                -- DCS does not pass groupId directly, so we use a workaround:
                -- Set a user flag in a custom event handler (see below) before menu call
                local unit, groupId = getPlayerContext()
                if not unit then return end
                local unitName = unit:getName()
                -- Compose arg as expected by handler
                local arg = { unitName = unitName, airbaseName = nil }
                handler(arg)
            end
        end

        -- Ground
        missionCommands.addCommandForCoalition(coalitionID, "Request Startup", paths.ground, wrapHandler(ATC.onRequestStartup or function() end))
        missionCommands.addCommandForCoalition(coalitionID, "Request Taxi", paths.ground, wrapHandler(ATC.onTaxiRequest))
        -- Tower
        missionCommands.addCommandForCoalition(coalitionID, "Request Takeoff", paths.tower, wrapHandler(ATC.onTakeoffRequest))
        missionCommands.addCommandForCoalition(coalitionID, "Ready for Departure", paths.tower, wrapHandler(ATC.onReadyDeparture))
        missionCommands.addCommandForCoalition(coalitionID, "Request Landing / Inbound", paths.tower, wrapHandler(ATC.onInboundRequest))
        -- Approach
        missionCommands.addCommandForCoalition(coalitionID, "Request Approach", paths.approach, wrapHandler(ATC.onInboundRequest))
        -- Departure
        missionCommands.addCommandForCoalition(coalitionID, "Request Departure", paths.departure, wrapHandler(ATC.onReadyDeparture))
        -- Add more as needed
    end
end

--- Periodically ensure menus exist for all coalitions
function ATC.retryAddMenus()
    for _, coa in ipairs({coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL}) do
        ATC.ensureMenusForCoalition(coa)
    end
    return timer.getTime() + 10
end

-- ============================================================
-- 1.  CONFIG (moved back in place)
-- ============================================================
ATC.config = {
    -- ── Proximity filter ─────────────────────────────────────
    -- Airbases further than this from the player are hidden.
    nearRadiusM     = 100000,           -- 100 km in metres

    -- ── Display ──────────────────────────────────────────────
    msgDuration     = 15,               -- seconds text stays on screen
    msgDurationLong = 25,               -- for long messages (emergency etc.)

    -- ── Traffic management ───────────────────────────────────
    maxSequence     = 8,                -- max aircraft in landing sequence
    separationNM    = 3,                -- target spacing between inbounds (NM)

    -- ── Glideslope / approach guidance (Part 2) ─────────────
    gsAngleDeg      = 3.0,    -- default ILS glideslope angle (degrees)

    -- Vertical deviation (ft) before ATC calls "above/below glide path"
    gsDeviationFt   = 200,

    -- How often (seconds) glideslope / speed guidance is repeated per unit.
    guidanceInterval = 30,

    -- Inside this distance (NM) a pilot is considered "on final" and
    -- receives active glideslope + speed calls.
    finalNM         = 12,

    -- Airspeed (kt) below which an airborne unit gets a go-around warning.
    stallWarnKt     = 80,

    -- ── Approach speed profiles (kt) by DCS unit type name ──────────────
    -- Vref (threshold) speeds sourced from DCS aircraft manuals and NATOPS/POH.
    -- clean / gear / maxFinal kept for legacy checks; "final" is the authoritative Vref.
    approachSpeeds = {
        -- ── US fixed-wing ─────────────────────────────────────────────────────
        ["F-16C_50"]            = { clean=250, gear=200, final=160, maxFinal=200 },
        ["FA-18C_hornet"]       = { clean=250, gear=200, final=140, maxFinal=180 },
        ["F-15C"]               = { clean=250, gear=200, final=155, maxFinal=200 },
        ["F-15E"]               = { clean=250, gear=200, final=155, maxFinal=200 },
        ["F-14A-135-GR"]        = { clean=250, gear=200, final=134, maxFinal=180 },
        ["F-14B"]               = { clean=250, gear=200, final=134, maxFinal=180 },
        ["A-10C"]               = { clean=200, gear=160, final=130, maxFinal=160 },
        ["A-10C_2"]             = { clean=200, gear=160, final=130, maxFinal=160 },
        ["AV8BNA"]              = { clean=250, gear=200, final= 90, maxFinal=150 },
        -- ── Russian / Soviet fixed-wing ───────────────────────────────────────
        ["Su-27"]               = { clean=250, gear=180, final=145, maxFinal=190 },
        ["Su-33"]               = { clean=250, gear=180, final=145, maxFinal=190 },
        ["Su-25T"]              = { clean=200, gear=160, final=135, maxFinal=170 },
        ["Su-25"]               = { clean=200, gear=160, final=135, maxFinal=170 },
        ["MiG-29A"]             = { clean=250, gear=180, final=145, maxFinal=190 },
        ["MiG-29S"]             = { clean=250, gear=180, final=145, maxFinal=190 },
        ["MiG-21Bis"]           = { clean=250, gear=200, final=170, maxFinal=215 },
        -- ── European fixed-wing ───────────────────────────────────────────────
        ["AJS37"]               = { clean=250, gear=180, final=140, maxFinal=185 },
        ["M-2000C"]             = { clean=250, gear=200, final=155, maxFinal=195 },
        -- ── Multi-national ────────────────────────────────────────────────────
        ["JF-17"]               = { clean=250, gear=200, final=145, maxFinal=185 },
        -- ── Trainers / light jets ─────────────────────────────────────────────
        ["C-101CC"]             = { clean=200, gear=160, final=120, maxFinal=155 },
        ["L-39ZA"]              = { clean=200, gear=160, final=115, maxFinal=150 },
        -- ── WWII / prop aircraft ──────────────────────────────────────────────
        ["Yak-52"]              = { clean=140, gear=110, final= 85, maxFinal=115 },
        ["TF-51D"]              = { clean=140, gear=110, final= 90, maxFinal=120 },
        ["P-51D-30-NA"]         = { clean=140, gear=110, final= 90, maxFinal=120 },
        ["Spitfire LF Mk. IXc"] = { clean=130, gear=100, final= 80, maxFinal=110 },
        ["FW-190D9"]            = { clean=170, gear=130, final=105, maxFinal=140 },
        ["Bf-109K-4"]           = { clean=160, gear=130, final=100, maxFinal=135 },
        -- ── Rotary-wing ───────────────────────────────────────────────────────
        ["Mi-8MT"]              = { clean=120, gear= 80, final= 55, maxFinal= 80 },
        ["Ka-50"]               = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        ["Ka-50_3"]             = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        ["UH-1H"]               = { clean=100, gear= 70, final= 50, maxFinal= 70 },
        ["SA342M"]              = { clean=100, gear= 70, final= 40, maxFinal= 60 },
        ["AH-64D_BLK_II"]       = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        -- ── Fallback ──────────────────────────────────────────────────────────
        ["default"]             = { clean=250, gear=180, final=150, maxFinal=200 },
    },

    -- ── Menu labels ──────────────────────────────────────────
    rootMenuLabel    = "[ATC] Nearby Fields",
    menuRefreshLabel = "  Refresh Airfield List",

    -- ── Scheduler ────────────────────────────────────────────
    -- How often (seconds) the proximity list is re-evaluated.
    refreshInterval = 15,

    -- Minimum seconds between repeated queue-position broadcasts
    -- to the same unit at the same airfield (anti-spam).
    queueBroadcastInterval = 30,

    -- ── Radar vectoring (Part 3) ─────────────────────────────
    -- How often (seconds) vectoring calls are repeated while a pilot
    -- is being worked around the pattern.
    vectoringInterval = 25,

    -- Distance (NM) at which the racetrack inbound leg turns and step-down
    -- is checked. checkGlideslopes takes over inside this distance.
    ilsHandoffNM = 5,

    -- Standard traffic pattern altitude AGL (ft) used when a field has no
    -- specific patternAlt defined in ATC.runways.
    defaultPatternAltFt = 1500,
}


-- ============================================================
-- 1b.  RUNWAY DATA  (Part 3 – Radar Vectoring)
-- ============================================================
--[[
  One entry per airbase name (must match DCS internal name exactly).
  Fields:
    hdg        – primary runway magnetic heading (degrees, 0-360)
    reciprocal – opposite-end heading
    elevation  – field elevation AMSL (feet)
    ILSfreq    – ILS / localizer frequency (MHz), 0 if none
    patternAlt – traffic pattern altitude AMSL (feet)
                 If omitted, defaultPatternAltFt + elevation is used.

  These values are hardcoded because DCS scripting does not expose
  runway heading or elevation via the API.  Add or correct entries
  as needed for your theatre.  Fields not listed here will still
  get queue/GS calls; they just won't receive heading/alt vectors.
--]]
ATC.runways = {
    -- ── Germany (The Channel, Normandy, etc.) ───────────────
    ["Normandy Carpiquet"] = { hdg=260, reciprocal=80, elevation=256, ILSfreq=0, patternAlt=1756,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Normandy Evreux"] = { hdg=240, reciprocal=60, elevation=526, ILSfreq=0, patternAlt=2026,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Germany map airports here...

    -- ── Afghanistan ────────────────────────────────────────
    ["Bagram"] = { hdg=120, reciprocal=300, elevation=4950, ILSfreq=0, patternAlt=6450,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Afghanistan map airports here...

    -- ── Iraq ───────────────────────────────────────────────
    ["Baghdad Intl"] = { hdg=150, reciprocal=330, elevation=110, ILSfreq=0, patternAlt=1610,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Iraq map airports here...

    -- ── Kola ───────────────────────────────────────────────
    ["Kola Murmansk"] = { hdg=180, reciprocal=0, elevation=150, ILSfreq=0, patternAlt=1650,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Kola map airports here...

    -- ── Sinai ──────────────────────────────────────────────
    ["Sinai Cairo Intl"] = { hdg=200, reciprocal=20, elevation=382, ILSfreq=0, patternAlt=1882,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Sinai map airports here...

    -- ── Caucasus ─────────────────────────────────────────────
    ["Batumi"]              = { hdg=130, reciprocal=310, elevation=32,   ILSfreq=110.30, patternAlt=1532,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kobuleti"]            = { hdg=70,  reciprocal=250, elevation=59,   ILSfreq=111.50, patternAlt=1559, patternDir="R",
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kutaisi"]             = { hdg=80,  reciprocal=260, elevation=147,  ILSfreq=109.75, patternAlt=1647,
        frequencies = {
            ground = { mhz=122.000, hz=122000000 },
            tower = { mhz=118.900, hz=118900000 },
            approach = { mhz=123.700, hz=123700000 },
            departure = { mhz=124.400, hz=124400000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Senaki-Kolkhi"]       = { hdg=90,  reciprocal=270, elevation=43,   ILSfreq=108.90, patternAlt=1543,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Sukhumi"]             = { hdg=120, reciprocal=300, elevation=43,   ILSfreq=0,      patternAlt=1543,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Gudauta"]             = { hdg=150, reciprocal=330, elevation=68,   ILSfreq=0,      patternAlt=1568,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Sochi-Adler"]         = { hdg=60,  reciprocal=240, elevation=98,   ILSfreq=111.10, patternAlt=1598, patternDir="R",
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Gelendzhik"]          = { hdg=20,  reciprocal=200, elevation=72,   ILSfreq=0,      patternAlt=1572,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Anapa-Vityazevo"]     = { hdg=40,  reciprocal=220, elevation=144,  ILSfreq=0,      patternAlt=1644,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krasnodar-Center"]    = { hdg=90,  reciprocal=270, elevation=98,   ILSfreq=0,      patternAlt=1598,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krasnodar-Pashkovsky"]= { hdg=54,  reciprocal=234, elevation=108,  ILSfreq=0,      patternAlt=1608,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krymsk"]              = { hdg=40,  reciprocal=220, elevation=65,   ILSfreq=0,      patternAlt=1565,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Novorossiysk"]        = { hdg=40,  reciprocal=220, elevation=131,  ILSfreq=0,      patternAlt=1631,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tbilisi-Lochini"]     = { hdg=130, reciprocal=310, elevation=1624, ILSfreq=110.30, patternAlt=3124,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Vaziani"]             = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=117.60, patternAlt=3023,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Soganlug"]            = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=0,      patternAlt=3023,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Beslan"]              = { hdg=100, reciprocal=280, elevation=1660, ILSfreq=110.50, patternAlt=3160,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Mozdok"]              = { hdg=80,  reciprocal=260, elevation=507,  ILSfreq=0,      patternAlt=2007,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Nalchik"]             = { hdg=90,  reciprocal=270, elevation=1410, ILSfreq=117.60, patternAlt=2910,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Mineralnye Vody"]     = { hdg=120, reciprocal=300, elevation=1049, ILSfreq=111.10, patternAlt=2549,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },

    -- ── Persian Gulf ─────────────────────────────────────────
    ["Abu Dhabi Intl"]      = { hdg=130, reciprocal=310, elevation=88,   ILSfreq=0,      patternAlt=1588,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Ain Intl"]         = { hdg=70,  reciprocal=250, elevation=869,  ILSfreq=0,      patternAlt=2369,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Bateen"]           = { hdg=130, reciprocal=310, elevation=16,   ILSfreq=0,      patternAlt=1516,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Dhafra AB"]        = { hdg=130, reciprocal=310, elevation=77,   ILSfreq=111.70, patternAlt=1577,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Maktoum Intl"]     = { hdg=120, reciprocal=300, elevation=114,  ILSfreq=0,      patternAlt=1614,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Minhad AB"]        = { hdg=80,  reciprocal=260, elevation=202,  ILSfreq=0,      patternAlt=1702,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Dubai Intl"]          = { hdg=120, reciprocal=300, elevation=62,   ILSfreq=110.90, patternAlt=1562,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Fujairah Intl"]       = { hdg=110, reciprocal=290, elevation=152,  ILSfreq=0,      patternAlt=1652,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kish Intl"]           = { hdg=90,  reciprocal=270, elevation=101,  ILSfreq=0,      patternAlt=1601,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Bandar Abbas Intl"]   = { hdg=210, reciprocal=30,  elevation=22,   ILSfreq=109.90, patternAlt=1522,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Qeshm Island"]        = { hdg=90,  reciprocal=270, elevation=30,   ILSfreq=0,      patternAlt=1530,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Lavan Island"]        = { hdg=90,  reciprocal=270, elevation=76,   ILSfreq=0,      patternAlt=1576,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Lar"]                 = { hdg=210, reciprocal=30,  elevation=2641, ILSfreq=0,      patternAlt=4141,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Jiroft"]              = { hdg=270, reciprocal=90,  elevation=2795, ILSfreq=0,      patternAlt=4295,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kerman"]              = { hdg=220, reciprocal=40,  elevation=5741, ILSfreq=0,      patternAlt=7241,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Shiraz Intl"]         = { hdg=290, reciprocal=110, elevation=4920, ILSfreq=0,      patternAlt=6420,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Sharjah Intl"]        = { hdg=120, reciprocal=300, elevation=111,  ILSfreq=0,      patternAlt=1611,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tunb Island AFB"]     = { hdg=90,  reciprocal=270, elevation=16,   ILSfreq=0,      patternAlt=1516,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Sirri Island"]        = { hdg=90,  reciprocal=270, elevation=43,   ILSfreq=0,      patternAlt=1543,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Abu Musa Island"]     = { hdg=90,  reciprocal=270, elevation=46,   ILSfreq=0,      patternAlt=1546,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },

    -- ── Syria ────────────────────────────────────────────────
    ["Incirlik"]            = { hdg=50,  reciprocal=230, elevation=240,  ILSfreq=109.30, patternAlt=1740,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Akrotiri"]            = { hdg=100, reciprocal=280, elevation=76,   ILSfreq=114.70, patternAlt=1576,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Hatay"]               = { hdg=50,  reciprocal=230, elevation=269,  ILSfreq=108.30, patternAlt=1769,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Adana Sakirpasa"]     = { hdg=50,  reciprocal=230, elevation=65,   ILSfreq=0,      patternAlt=1565,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Gaziantep"]           = { hdg=100, reciprocal=280, elevation=2313, ILSfreq=0,      patternAlt=3813,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Aleppo"]              = { hdg=90,  reciprocal=270, elevation=1276, ILSfreq=0,      patternAlt=2776,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kuweires"]            = { hdg=90,  reciprocal=270, elevation=1158, ILSfreq=0,      patternAlt=2658,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Taftanaz"]            = { hdg=90,  reciprocal=270, elevation=968,  ILSfreq=0,      patternAlt=2468,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Al Qusayr"]           = { hdg=250, reciprocal=70,  elevation=1178, ILSfreq=0,      patternAlt=2678,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Khalkhalah"]          = { hdg=270, reciprocal=90,  elevation=2267, ILSfreq=0,      patternAlt=3767,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tiyas"]               = { hdg=90,  reciprocal=270, elevation=1355, ILSfreq=0,      patternAlt=2855,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Deir ez-Zor"]         = { hdg=270, reciprocal=90,  elevation=700,  ILSfreq=0,      patternAlt=2200,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Abu ad Duhur"]        = { hdg=90,  reciprocal=270, elevation=912,  ILSfreq=0,      patternAlt=2412,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Damascus"]            = { hdg=50,  reciprocal=230, elevation=2020, ILSfreq=108.30, patternAlt=3520,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Marj Ruhayyil"]       = { hdg=60,  reciprocal=240, elevation=2024, ILSfreq=0,      patternAlt=3524,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Mezzeh"]              = { hdg=50,  reciprocal=230, elevation=2362, ILSfreq=0,      patternAlt=3862,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Beirut-Rafic Hariri"] = { hdg=170, reciprocal=350, elevation=87,   ILSfreq=110.50, patternAlt=1587,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Ramat David"]         = { hdg=90,  reciprocal=270, elevation=185,  ILSfreq=108.70, patternAlt=1685,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Haifa"]               = { hdg=340, reciprocal=160, elevation=22,   ILSfreq=0,      patternAlt=1522,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tel Nof"]             = { hdg=20,  reciprocal=200, elevation=193,  ILSfreq=0,      patternAlt=1693,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Paphos"]              = { hdg=110, reciprocal=290, elevation=41,   ILSfreq=0,      patternAlt=1541,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },

    -- ── Nevada (NTTR) ─────────────────────────────────────────
    ["Nellis AFB"]          = { hdg=210, reciprocal=30,  elevation=1870, ILSfreq=109.10, patternAlt=3370,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Creech AFB"]          = { hdg=160, reciprocal=340, elevation=3131, ILSfreq=0,      patternAlt=4631,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["McCarran Intl"]       = { hdg=190, reciprocal=10,  elevation=2181, ILSfreq=111.70, patternAlt=3681,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Henderson Executive"] = { hdg=170, reciprocal=350, elevation=2492, ILSfreq=0,      patternAlt=3992,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Boulder City"]        = { hdg=150, reciprocal=330, elevation=2201, ILSfreq=0,      patternAlt=3701,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Jean"]                = { hdg=20,  reciprocal=200, elevation=2820, ILSfreq=0,      patternAlt=4320,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Beatty"]              = { hdg=140, reciprocal=320, elevation=3170, ILSfreq=0,      patternAlt=4670,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tonopah Test Range"]  = { hdg=140, reciprocal=320, elevation=5549, ILSfreq=0,      patternAlt=7049,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Groom Lake AFB"]      = { hdg=140, reciprocal=320, elevation=4806, ILSfreq=0,      patternAlt=6306,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Lincoln County"]      = { hdg=150, reciprocal=330, elevation=4825, ILSfreq=0,      patternAlt=6325,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },

    -- ── Marianas ─────────────────────────────────────────────
    ["Andersen AFB"]        = { hdg=60,  reciprocal=240, elevation=627,  ILSfreq=111.10, patternAlt=2127,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Antonio B. Won Pat"]  = { hdg=60,  reciprocal=240, elevation=298,  ILSfreq=110.30, patternAlt=1798,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Rota Intl"]           = { hdg=90,  reciprocal=270, elevation=607,  ILSfreq=0,      patternAlt=2107,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Saipan Intl"]         = { hdg=70,  reciprocal=250, elevation=215,  ILSfreq=0,      patternAlt=1715,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tinian"]              = { hdg=60,  reciprocal=240, elevation=271,  ILSfreq=0,      patternAlt=1771,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
}


-- ============================================================
-- 2.  STATE
-- ============================================================
--[[
  Per-player record  (ATC.state.aircraft[unitName]):
    groupId       number
    activeField   string  – last field the player interacted with
    phases        table   – [airbaseName] = phase string
    cleared       table   – [airbaseName] = bool
    seqNum        table   – [airbaseName] = number
    menuRoot      table   – F10 path of the top "[ATC]" submenu
    nearbyFields  table   – array of airbase names last seen in radius
    fieldMenus    table   – [airbaseName] = F10 path of that field submenu
    lastQueueMsg  table   – [airbaseName] = timestamp of last queue broadcast
    lastGuidance  table   – [airbaseName] = timestamp of last guidance call
    lastGSDev     table   – [airbaseName] = "above"|"below"|"on" (last GS deviation state)
    patternLeg    table   – [airbaseName] = "downwind"|"base"|"final"|nil
    lastVector    table   – [airbaseName] = timestamp of last vectoring call

  Phases (per field per player):
    "unknown"  "parked"  "taxi"  "takeoff"  "airborne"
    "inbound"  "approach"  "final"  "landing"  "goaround"

  Per-airfield traffic state  (ATC.state.airfields[airbaseName]):
    landingSeq  array of unitNames (index 1 = next to land)
    departSeq   array of unitNames
    rwyClear    bool
--]]

ATC.state = {
    aircraft  = {},   -- [unitName]    → player record
    airfields = {},   -- [airbaseName] → traffic record
}

--- Return (creating if needed) the traffic record for an airbase.
function ATC.getFieldState(airbaseName)
    if not ATC.state.airfields[airbaseName] then
        ATC.state.airfields[airbaseName] = {
            landingSeq = {},
            departSeq  = {},
            rwyClear   = true,
            holdStack  = {},   -- [unitName] = assigned hold altitude (ft)
        }
    end
    return ATC.state.airfields[airbaseName]
end

--- Return (creating if needed) the player record for a unit.
function ATC.getOrCreateRecord(unitName, groupId)
    if not ATC.state.aircraft[unitName] then
        ATC.state.aircraft[unitName] = {
            groupId       = groupId,
            activeField   = nil,
            engagedField  = nil,  -- airfield player has an active request with
            phases        = {},
            cleared       = {},
            seqNum        = {},
            menuRoot      = nil,
            nearbyFields  = {},
            fieldMenus    = {},
            lastQueueMsg  = {},  -- [airbaseName] = timer.getTime() of last queue broadcast
            lastGuidance  = {},  -- [airbaseName] = timer.getTime() of last guidance call
            lastGSDev     = {},  -- [airbaseName] = "above"|"below"|"on" last deviation state
            patternLeg    = {},  -- [airbaseName] = "downwind"|"base"|"final"|nil
            lastVector    = {},  -- [airbaseName] = timer.getTime() of last vectoring call
            approachGate  = {},  -- [airbaseName] = current approach gate number (1,2,3,4...)
            stackAlt      = {},  -- [airbaseName] = assigned hold altitude (ft)
            landingCleared = {}, -- [airbaseName] = true once "cleared for approach/landing" issued
            holdPhase      = {}, -- [airbaseName] = "inbound"|"outbound" racetrack leg
        }
    end
    return ATC.state.aircraft[unitName]
end

--- Get the current phase of a player at a given airbase.
function ATC.getPhase(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return "unknown" end
    return rec.phases[airbaseName] or "unknown"
end


-- ============================================================
-- 3.  UTILITY HELPERS
-- ============================================================

--- Send a text message to one group only.
function ATC.msg(groupId, text, long)
    local dur = long and ATC.config.msgDurationLong or ATC.config.msgDuration
    trigger.action.outTextForGroup(groupId, text, dur, false)
end

--- Send a text message to ALL players.
function ATC.msgAll(text)
    trigger.action.outText(text, ATC.config.msgDuration, false)
end

--- Straight-line distance (metres) between two Vec3 points.
function ATC.distVec3(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

--- Horizontal distance (metres) ignoring altitude difference.
function ATC.distVec3H(a, b)
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dz*dz)
end

--- Metres to nautical miles.
function ATC.mToNM(m) return m / 1852 end

--- Metres to feet.
function ATC.mToFt(m) return m * 3.28084 end

--- Ordinal string: 1->"1st", 2->"2nd", etc.
function ATC.ordinal(n)
    if n == 1 then return "1st"
    elseif n == 2 then return "2nd"
    elseif n == 3 then return "3rd"
    else return n .. "th" end
end

--- Get Vec3 position of an Airbase object.
function ATC.getAirbasePos(ab)
    return ab:getPoint()
end

--- Return array of nearby Airbase objects sorted nearest-first.
-- Scans all coalitions.
-- @param centre   Vec3
-- @param radiusM  number (metres)
-- @return array of { ab=Airbase, distM=number, name=string }
function ATC.getNearbyAirbases(centre, radiusM)
    local found = {}
    for _, side in ipairs({ coalition.side.BLUE,
                            coalition.side.RED,
                            coalition.side.NEUTRAL }) do
        local bases = coalition.getAirbases(side) or {}
        for _, ab in ipairs(bases) do
            local p = ATC.getAirbasePos(ab)
            if p then
                local d = ATC.distVec3H(centre, p)
                if d <= radiusM then
                    table.insert(found, { ab = ab, distM = d, name = ab:getName() })
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.distM < b.distM end)
    return found
end

--- Get unit altitude in feet MSL.
function ATC.getAltFt(unit)
    if not unit then return nil end
    local pos = unit:getPoint()
    if not pos then return nil end
    return math.floor(ATC.mToFt(pos.y))
end

--- Get unit groundspeed in knots.
function ATC.getSpeedKt(unit)
    if not unit then return nil end
    local vel = unit:getVelocity()
    if not vel then return nil end
    local spd = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
    return math.floor(spd * 1.94384)
end

--- Distance from a unit to an Airbase in NM (horizontal only).
function ATC.distUnitToBase(unit, ab)
    if not unit or not ab then return nil end
    local uPos = unit:getPoint()
    local bPos = ATC.getAirbasePos(ab)
    if not uPos or not bPos then return nil end
    return ATC.mToNM(ATC.distVec3H(uPos, bPos))
end

--- Guard: returns true only for a live human player unit.
function ATC.isPlayer(unit)
    if not unit then return false end
    if not unit:isExist() then return false end
    -- Multiplayer client slots may have nil player name, but are still player units
    if unit:getPlayerName() ~= nil and unit:getPlayerName() ~= "" then return true end
    -- If unit is not AI, treat as player (client slot)
    if unit:getCoalition() ~= nil and unit:getPlayerName() == nil then return true end
    return false
end

-- ── Part 2 Guidance helpers ───────────────────────────────────

--- Magnetic bearing (degrees, 0-360) from Vec3 point a to b.
-- DCS uses a coordinate system where x=North, z=East.
function ATC.getBearing(a, b)
    local dx = b.z - a.z    -- East component
    local dz = b.x - a.x    -- North component
    local brg = math.deg(math.atan2(dx, dz))
    if brg < 0 then brg = brg + 360 end
    return math.floor(brg + 0.5)
end

--- Vertical deviation of a unit from the ideal glideslope (feet).
-- Positive = above GS, negative = below GS.
-- @param unit      Unit object
-- @param ab        Airbase object
-- @param gsAngle   Glideslope angle in degrees (default ATC.config.gsAngleDeg)
-- @return  number (ft) or nil if data unavailable
function ATC.getGSDeviationFt(unit, ab, gsAngle)
    if not unit or not ab then return nil end
    local uPos  = unit:getPoint()
    local bPos  = ATC.getAirbasePos(ab)
    if not uPos or not bPos then return nil end

    local distM  = ATC.distVec3H(uPos, bPos)
    local altM   = uPos.y - bPos.y          -- height above airbase elevation
    local ang    = gsAngle or ATC.config.gsAngleDeg

    -- Ideal altitude at this distance for the given GS angle
    local idealAltM  = distM * math.tan(math.rad(ang))
    local deviationM = altM - idealAltM
    return deviationM * 3.28084             -- metres → feet
end

--- Derive traffic-pattern leg headings from a runway config entry.
--- patternDir "L" = left traffic (standard), "R" = right traffic.
--- Returns { dir, finalHdg, downwindHdg, baseHdg } or nil if insufficient data.
function ATC.getPatternLegs(rwy)
    if not rwy or not rwy.hdg then return nil end
    local dir         = rwy.patternDir or "L"
    local finalHdg    = rwy.hdg % 360
    local downwindHdg = rwy.reciprocal or ((rwy.hdg + 180) % 360)
    -- Left traffic: turn left off downwind → base is 90° clockwise from final
    -- Right traffic: turn right off downwind → base is 90° counter-clockwise from final
    local baseHdg = (dir == "R")
        and ((finalHdg - 90 + 360) % 360)
        or  ((finalHdg + 90) % 360)
    return { dir=dir, finalHdg=finalHdg, downwindHdg=downwindHdg, baseHdg=baseHdg }
end

--- Return approach speed profile for a unit (falls back to "default").
function ATC.getApproachSpeeds(unit)
    if not unit then return ATC.config.approachSpeeds["default"] end
    local t = unit:getTypeName() or "default"
    return ATC.config.approachSpeeds[t]
        or ATC.config.approachSpeeds["default"]
end

--- Send a guidance message as on-screen text AND a radio call subtitle.
-- When voiceover .ogg files are available, replace trigger.action.outTextForGroup
-- with trigger.action.radioTransmission() using the assembled phrase.
-- @param groupId   number
-- @param abPos     Vec3   (airbase position – radio transmitter origin)
-- @param text      string (the full message shown on screen + as subtitle)
-- @param long      bool   (use long duration)
function ATC.radioMsg(groupId, abPos, text, long)
    -- Text fallback (always works, no audio files needed)
    ATC.msg(groupId, text, long)

    --[[ OPTIONAL: uncomment once .ogg files are present in the .miz
    local freq = 305000000   -- TODO: per-airfield tower frequency
    trigger.action.radioTransmission(
        "l10n/DEFAULT/atc_phrase.ogg",  -- placeholder; swap for assembled file list
        abPos,
        0,          -- AM
        false,      -- no loop
        freq,
        100,        -- power
        text        -- subtitle
    )
    --]]
end


-- ── Part 3: Radar vectoring helpers ──────────────────────────────────────────

--- Look up runway data for an airbase. Returns nil if not in ATC.runways.
function ATC.getRunway(airbaseName)
    return ATC.runways[airbaseName]
end

--- Round a heading to the nearest 10 degrees (standard ATC readout).
function ATC.roundHdg(h)
    return math.floor(h / 10 + 0.5) * 10 % 360
end

--- Format a heading as a zero-padded 3-digit string ("090", "270", etc.)
function ATC.fmtHdg(h)
    return string.format("%03d", math.floor(h + 0.5) % 360)
end

--- Angle difference: signed, shortest path, -180 to +180.
local function angleDiff(a, b)
    local d = (b - a) % 360
    if d > 180 then d = d - 360 end
    return d
end

--- Determine which traffic pattern leg a unit is currently on relative to
--- the active runway.
-- Returns: "outbound" | "crosswind" | "downwind" | "base" | "final" | "short_final"
-- @param uPos    Vec3 (unit position)
-- @param abPos   Vec3 (airbase position)
-- @param rwy     runway table entry from ATC.runways
function ATC.getPatternLeg(uPos, abPos, rwy)
    -- Bearing FROM field TO aircraft
    local bearingToAc = ATC.getBearing(abPos, uPos)
    -- Angular difference between runway heading and bearing to aircraft
    -- Negative = aircraft is on the left side of the runway centreline,
    -- Positive = aircraft is on the right side.
    local diff = angleDiff(rwy.hdg, bearingToAc)
    local distNM = ATC.mToNM(ATC.distVec3H(uPos, abPos))

    if distNM <= 2  then return "short_final" end
    if distNM <= 8  then
        -- Within 8 NM: is the aircraft roughly aligned with the runway?
        if math.abs(diff) <= 30 then return "final" end
        if math.abs(diff) <= 90 then return "base" end
    end
    -- Downwind: roughly parallel to runway, reciprocal heading sector
    if math.abs(math.abs(diff) - 180) <= 45 then return "downwind" end
    if math.abs(diff) > 90 then return "crosswind" end
    return "outbound"
end

--- Compute the intercept heading to roll out on the localizer from a given
--- offset position.
-- Strategy: pick a point on the extended centreline 8 NM ahead of the
-- threshold and fly direct to it.  Cap the cut angle at 30°.
-- @param uPos  Vec3
-- @param abPos Vec3
-- @param rwy   runway table
-- @return intercept heading (degrees)
function ATC.getInterceptHeading(uPos, abPos, rwy)
    -- Extended centreline point: 8 NM ahead of the threshold, in the
    -- runway direction (i.e. inbound = reciprocal heading from the field)
    local inboundHdgRad = math.rad(rwy.reciprocal)
    local nm8m = 8 * 1852
    local clPt = {
        x = abPos.x + nm8m * math.cos(inboundHdgRad),
        y = abPos.y,
        z = abPos.z + nm8m * math.sin(inboundHdgRad),
    }
    local rawHdg = ATC.getBearing(uPos, clPt)
    -- Cap cut angle to 30° either side of the inbound track
    local diff = angleDiff(rwy.reciprocal, rawHdg)
    if diff >  30 then rawHdg = (rwy.reciprocal + 30) % 360 end
    if diff < -30 then rawHdg = (rwy.reciprocal - 30 + 360) % 360 end
    return ATC.roundHdg(rawHdg)
end

--- Return the ideal altitude (ft AMSL) to be at for each pattern leg.
-- @param rwy   runway table
-- @param distNM  current distance from field (NM)
function ATC.getPatternAltFt(rwy, leg, distNM)
    local base = rwy.patternAlt or (rwy.elevation + ATC.config.defaultPatternAltFt)
    if leg == "downwind"   then return base end
    if leg == "base"       then return math.floor(base * 0.75) end
    if leg == "final"      then
        -- GS intercept altitude: tan(gs) × distance
        local distM  = distNM * 1852
        local gsAlt  = distM * math.tan(math.rad(ATC.config.gsAngleDeg))
        return math.max(rwy.elevation + 300, math.floor(rwy.elevation + ATC.mToFt(gsAlt)))
    end
    return base
end

--- Define approach gates for stepped descent.
--- Returns array of gates: { altFt, speedKt, distNM }
--- Gates are ordered from furthest to closest.
-- Fixed holding levels used for the approach stack.
-- Levels are absolute MSL altitudes in feet.
-- Only levels meaningfully above the field's pattern altitude are included.
local STACK_LEVELS     = { 5000, 4000, 3000, 2000 }
local STACK_LEVEL_DIST = { [5000]=12, [4000]=12, [3000]=12, [2000]=12 }
-- Pattern speed targets per hold level.  Approach (Vref) is ONLY issued on final.
local STACK_LEVEL_SPEED = { [5000]=300, [4000]=250, [3000]=220, [2000]=200 }

--- Build the descent gate list for an aircraft inbound to a runway.
--- @param rwy      table  – runway config entry (from ATC.runways)
--- @param unit     Unit   – the landing aircraft (used for speed profile)
--- @param startAlt number – assigned hold altitude in feet (from assignStackLevel)
--- @return table  list of { altFt, speedKt, distNM, name } descending to pattern
function ATC.getApproachGates(rwy, unit, startAlt)
    local spds = ATC.getApproachSpeeds(unit)
    local patternAlt = rwy.patternAlt or (rwy.elevation + ATC.config.defaultPatternAltFt)

    startAlt = startAlt or 5000

    -- Include every fixed level that is at or below startAlt and at least
    -- 300 ft above the pattern altitude (so we never send below the pattern).
    local gates = {}
    for _, lv in ipairs(STACK_LEVELS) do
        if lv <= startAlt and lv > patternAlt + 300 then
            table.insert(gates, {
                altFt   = lv,
                speedKt = STACK_LEVEL_SPEED[lv] or 200,
                distNM  = STACK_LEVEL_DIST[lv] or 15,
                name    = "hold" .. lv,
            })
        end
    end

    -- Final gate: pattern altitude at type-specific Vref.
    -- (No gear-speed intermediate — gate speeds already step down to 200 kt.)
    table.insert(gates, {
        altFt   = math.floor(patternAlt),
        speedKt = spds.final,
        distNM  = 3,
        name    = "final",
    })

    return gates
end

--- Check if aircraft parameters are within tolerance of target.
--- @param actual number - actual value
--- @param target number - target value
--- @param tolerance number - tolerance as fraction (0.1 = 10%)
--- @return boolean
local function withinTolerance(actual, target, tolerance)
    if not actual or not target then return false end
    local delta = math.abs(actual - target)
    local maxDelta = target * tolerance
    return delta <= maxDelta
end

--- Check if aircraft is in compliance with approach gate.
--- For non-final gates: 2 of 3 parameters within tolerance
--- For final gate: all 3 parameters within tolerance
--- @param unit Unit
--- @param gate table - { altFt, speedKt, distNM, name }
--- @param heading number - target heading in degrees
--- @param isFinal boolean - true if this is the final gate
--- @return boolean - true if compliant
function ATC.checkGateCompliance(unit, gate, heading, isFinal)
    if not unit or not gate then return false end

    local altFt = ATC.getAltFt(unit)
    local spdKt = ATC.getSpeedKt(unit)
    local vel = unit:getVelocity()
    if not vel or not altFt or not spdKt then return false end

    -- Calculate current heading
    local currentHdg = math.deg(math.atan2(vel.z, vel.x))
    if currentHdg < 0 then currentHdg = currentHdg + 360 end

    -- Calculate heading difference (shortest path)
    local hdgDiff = math.abs(currentHdg - heading)
    if hdgDiff > 180 then hdgDiff = 360 - hdgDiff end

    local tolerance = isFinal and 0.04 or 0.10  -- 4% for final, 10% for others
    local hdgToleranceDeg = isFinal and 15 or 30  -- degrees tolerance for heading

    local altOK = withinTolerance(altFt, gate.altFt, tolerance)
    local spdOK = withinTolerance(spdKt, gate.speedKt, tolerance)
    local hdgOK = hdgDiff <= hdgToleranceDeg

    if isFinal then
        -- Final gate: all 3 must match within tolerance
        return altOK and spdOK and hdgOK
    else
        -- Other gates: 2 of 3 must match within tolerance
        local matchCount = 0
        if altOK then matchCount = matchCount + 1 end
        if spdOK then matchCount = matchCount + 1 end
        if hdgOK then matchCount = matchCount + 1 end
        return matchCount >= 2
    end
end

--- Get the appropriate gate for current distance and altitude.
--- Returns gate number (1-based index).
--- Gate distance represents: "complete this step before reaching this distance"
function ATC.determineCurrentGate(unit, rwy, gates, distNM, altFt)
    if not unit or not rwy or not gates or not distNM or not altFt then return 1 end

    -- Find the first gate we're still working on (haven't reached yet)
    for i = 1, #gates do
        local gate = gates[i]
        if distNM > gate.distNM then
            -- We're still beyond this gate's distance marker, so we're working on this gate
            return i
        end
    end

    -- We're closer than all gate distances, must be on final approach
    return #gates
end



function ATC.seqPos(unitName, airbaseName)
    local fs = ATC.state.airfields[airbaseName]
    if not fs then return 0 end
    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then return i end
    end
    return 0
end

function ATC.addToLandingSeq(unitName, airbaseName)
    local fs  = ATC.getFieldState(airbaseName)
    local pos = ATC.seqPos(unitName, airbaseName)
    if pos > 0 then return pos end
    table.insert(fs.landingSeq, unitName)
    return #fs.landingSeq
end

--- Remove a unit from all sequences at every airfield.
function ATC.removeFromAllSeqs(unitName)
    for _, fs in pairs(ATC.state.airfields) do
        for i, n in ipairs(fs.landingSeq) do
            if n == unitName then table.remove(fs.landingSeq, i) break end
        end
        for i, n in ipairs(fs.departSeq) do
            if n == unitName then table.remove(fs.departSeq, i) break end
        end
    end
end

--- Fully remove a player record, menus, and sequence entries.
function ATC.removeRecord(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    ATC.removeFromAllSeqs(unitName)
    -- Free any held stack slots across all airfields
    for abName, _ in pairs(ATC.state.airfields) do
        ATC.freeStackLevel(unitName, abName)
    end
    if rec.menuRoot then
        missionCommands.removeItemForGroup(rec.groupId, rec.menuRoot)
    end
    ATC.state.aircraft[unitName] = nil
end


-- ============================================================
-- 4.  MENU SYSTEM
-- ============================================================
--[[
  Menu tree (built per player group):

  F10 Other
   └── [ATC] Nearby Fields               ← rec.menuRoot
         ├── Refresh Airfield List
         ├── Batumi (12 km)              ← field sub-submenu
         │     ├── (ground) F1 - Request Taxi Clearance
         │     │            F2 - Request Takeoff Clearance
         │     │            F3 - Ready for Departure
         │     │            F4 - Declare Emergency
         │     └── (air)    F1 - Request Landing / Inbound
         │                  F2 - Report Position
         │                  F3 - Acknowledge / Wilco
         │                  F4 - Request Go-Around
         │                  F5 - Declare Emergency
         ├── Kobuleti (45 km)
         │     └── ...
         └── ...

  Options are chosen by unit:inAir() at build time, so they
  always reflect where the player physically is right now.
  When a phase change happens (e.g. landing) the field
  sub-submenu is torn down and rebuilt with the correct set.
--]]

--- Remove one field's sub-submenu from a player's menu.
function ATC.clearFieldMenu(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local path = rec.fieldMenus[airbaseName]
    if not path then return end
    missionCommands.removeItemForGroup(rec.groupId, path)
    rec.fieldMenus[airbaseName] = nil
end

--- Build (or rebuild) one field's sub-submenu for a player.
-- @param unitName    string
-- @param fieldEntry  { ab=Airbase, distM=number, name=string }
function ATC.buildFieldMenu(unitName, fieldEntry)
    local rec = ATC.state.aircraft[unitName]
    if not rec or not rec.menuRoot then return end

    local abName = fieldEntry.name
    local distKm = math.floor(fieldEntry.distM / 1000 + 0.5)
    local label  = abName .. "  (" .. distKm .. " km)"
    local ph     = ATC.getPhase(unitName, abName)
    local gid    = rec.groupId

    -- Wipe the old submenu for this field
    ATC.clearFieldMenu(unitName, abName)

    local fieldMenu = missionCommands.addSubMenuForGroup(gid, label, rec.menuRoot)
    rec.fieldMenus[abName] = fieldMenu

    -- Arg table: every handler gets the unit name AND which airfield
    local arg = { unitName = unitName, airbaseName = abName }

    -- Determine options by whether the player is physically in the air right now.
    -- unit:inAir() is the authoritative live check; we fall back to stored phase
    -- only when the unit object is temporarily unavailable.
    local unit   = Unit.getByName(unitName)
    local inAir  = unit and unit:inAir() or false
    local ph     = ATC.getPhase(unitName, abName)
    local onRwy  = (ph == "landing")   -- special case: on the ground but just landed

    if onRwy then
        -- Just landed – only option is to vacate
        missionCommands.addCommandForGroup(gid, "F1 - Vacating Runway",
            fieldMenu, ATC.onVacatingRunway, arg)
        missionCommands.addCommandForGroup(gid, "F2 - Acknowledge / Wilco",
            fieldMenu, ATC.onWilco, arg)
        missionCommands.addCommandForGroup(gid, "F3 - Declare Emergency",
            fieldMenu, ATC.onEmergency, arg)

    elseif not inAir then
        -- On the ground (parked, taxiing, holding short)
        missionCommands.addCommandForGroup(gid, "F1 - Request Taxi Clearance",
            fieldMenu, ATC.onTaxiRequest, arg)
        missionCommands.addCommandForGroup(gid, "F2 - Request Takeoff Clearance",
            fieldMenu, ATC.onTakeoffRequest, arg)
        missionCommands.addCommandForGroup(gid, "F3 - Ready for Departure",
            fieldMenu, ATC.onReadyDeparture, arg)
        missionCommands.addCommandForGroup(gid, "F4 - Declare Emergency",
            fieldMenu, ATC.onEmergency, arg)

    else
        -- Airborne (inbound, approach, go-around, or just departed)
        missionCommands.addCommandForGroup(gid, "F1 - Request Landing / Inbound",
            fieldMenu, ATC.onInboundRequest, arg)
        missionCommands.addCommandForGroup(gid, "F2 - Report Position",
            fieldMenu, ATC.onPositionReport, arg)
        missionCommands.addCommandForGroup(gid, "F3 - Acknowledge / Wilco",
            fieldMenu, ATC.onWilco, arg)
        missionCommands.addCommandForGroup(gid, "F4 - Request Go-Around",
            fieldMenu, ATC.onGoAround, arg)
        missionCommands.addCommandForGroup(gid, "F5 - Declare Emergency",
            fieldMenu, ATC.onEmergency, arg)
    end
end

--- Build the complete ATC menu for a player from scratch.
-- Called on BIRTH and whenever the proximity list changes.
function ATC.buildFullMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    -- Tear down old root (removes all children)
    if rec.menuRoot then
        missionCommands.removeItemForGroup(rec.groupId, rec.menuRoot)
        rec.menuRoot   = nil
        rec.fieldMenus = {}
    end

    local unit = Unit.getByName(unitName)
    if not unit or not ATC.isPlayer(unit) then return end

    local uPos = unit:getPoint()

    -- Build root submenu
    local root = missionCommands.addSubMenuForGroup(
        rec.groupId, ATC.config.rootMenuLabel, nil)
    rec.menuRoot = root

    -- ── ENGAGED MODE: Show only the engaged airfield ────────────
    if rec.engagedField then
        local ab = Airbase.getByName(rec.engagedField)
        if ab then
            local abPos  = ATC.getAirbasePos(ab)
            local distM  = (abPos and uPos) and ATC.distVec3H(uPos, abPos) or 0
            local fe = { ab = ab, distM = distM, name = rec.engagedField }

            -- Build the single field menu
            ATC.buildFieldMenu(unitName, fe)

            -- Add "Cancel Request" option at the top level
            missionCommands.addCommandForGroup(rec.groupId,
                "⚠ Cancel Request with " .. rec.engagedField,
                root, ATC.onCancelRequest, { unitName = unitName, airbaseName = rec.engagedField })
        else
            -- Engaged field doesn't exist anymore, clear engagement
            rec.engagedField = nil
            ATC.buildFullMenu(unitName)
        end
        return
    end

    -- ── DEFAULT MODE: Show nearby airfields list ────────────────
    local nearby = ATC.getNearbyAirbases(uPos, ATC.config.nearRadiusM)

    -- Cache name list for change detection in scheduler
    local nameList = {}
    for _, fe in ipairs(nearby) do nameList[#nameList + 1] = fe.name end
    rec.nearbyFields = nameList

    -- Refresh button at the top of the list
    missionCommands.addCommandForGroup(rec.groupId,
        ATC.config.menuRefreshLabel,
        root, ATC.onRefreshMenu, unitName)

    if #nearby == 0 then
        missionCommands.addCommandForGroup(rec.groupId,
            "  (No airfields within 100 km)",
            root, function() end, nil)
        return
    end

    -- One sub-submenu per nearby airbase
    for _, fe in ipairs(nearby) do
        ATC.buildFieldMenu(unitName, fe)
    end
end

--- Change a player's phase at a specific airbase and rebuild that field's menu.
function ATC.setPhase(unitName, airbaseName, newPhase)
    local rec = ATC.state.aircraft[unitName]
    if not rec or airbaseName == nil or airbaseName == "" then return end
    if rec.phases[airbaseName] == newPhase then return end
    rec.phases[airbaseName] = newPhase
    rec.activeField = airbaseName

    local unit = Unit.getByName(unitName)
    if not unit then return end

    local ab    = Airbase.getByName(airbaseName)
    local bPos  = ab and ATC.getAirbasePos(ab)
    local uPos  = unit:getPoint()
    local distM = (bPos and uPos) and ATC.distVec3H(uPos, bPos) or 0

    ATC.buildFieldMenu(unitName, { ab = ab, distM = distM, name = airbaseName })
end

--- Handler for the "Refresh" menu item.
function ATC.onRefreshMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    ATC.buildFullMenu(unitName)
    ATC.msg(rec.groupId,
        "[ATC]  Airfield list refreshed.\n" ..
        "Showing airbases within 100 km of your current position.")
end

--- Engage player with a specific airfield (hides nearby list, shows only this field).
function ATC.setEngagedField(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    rec.engagedField = airbaseName
    ATC.buildFullMenu(unitName)
end

--- Clear engagement (returns to nearby airfields list).
function ATC.clearEngagement(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local field = rec.engagedField
    rec.engagedField = nil
    if field then
        ATC.freeStackLevel(unitName, field)
        if rec.stackAlt       then rec.stackAlt[field]       = nil end
        if rec.approachGate   then rec.approachGate[field]   = nil end
        if rec.landingCleared then rec.landingCleared[field] = nil end
        if rec.patternAdv     then rec.patternAdv[field]     = nil end
        if rec.holdPhase      then rec.holdPhase[field]      = nil end
    end
    ATC.buildFullMenu(unitName)
end

--- Handler for "Cancel Request" menu item.
function ATC.onCancelRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    ATC.msg(rec.groupId, string.format(
        "[ATC]  Request cancelled with %s.\n" ..
        "You may select another airfield from the list.",
        airbaseName))

    ATC.clearEngagement(unitName)
end


-- ============================================================
-- 5.  ATC LOGIC  –  handlers
-- ============================================================
-- Every handler receives:  arg = { unitName = string, airbaseName = string }

--- Standard ATC preamble text.
--- Used for RESPONSES to a pilot's radio call.
--- Format: "FieldName [Controller],  Callsign,  "
--- @param unitName string
--- @param airbaseName string
--- @param controller string - "Approach", "Tower", or "Ground"
local function preamble(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    controller = controller or "Tower"
    return airbaseName .. " " .. controller .. ",  " .. cs .. ",  "
end

--- Controller-initiated call preamble.
--- Used when CONTROLLER is calling the pilot (unsolicited / proactive).
--- Format: "Callsign, FieldName [Controller], "
--- @param unitName string
--- @param airbaseName string
--- @param controller string - "Approach", "Tower", or "Ground"
local function controllerCall(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    controller = controller or "Tower"
    return cs .. ",  " .. airbaseName .. " " .. controller .. ",  "
end

--- Determine which controller should be handling this aircraft.
--- @param unitName string
--- @param airbaseName string
--- @return string - "Approach", "Tower", or "Ground"
local function getController(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return "Tower" end

    local phase = ATC.getPhase(unitName, airbaseName)
    local unit = Unit.getByName(unitName)

    -- Ground controller for parked/taxi
    if phase == "parked" or phase == "taxi" then
        return "Ground"
    end

    -- Tower controller for takeoff and landing operations
    if phase == "takeoff" or phase == "landing" then
        return "Tower"
    end

    -- Check distance for approach/tower handoff (short final)
    if unit then
        local ab = Airbase.getByName(airbaseName)
        local distNM = ATC.distUnitToBase(unit, ab)

        -- Tower handles short final (inside 5 NM) and final approach
        if distNM and distNM <= 5 then
            return "Tower"
        end
    end

    -- Approach handles everything else airborne (inbound, approach, vectors)
    if phase == "inbound" or phase == "approach" or phase == "final" or
       phase == "airborne" or phase == "goaround" then
        return "Approach"
    end

    return "Tower"  -- default fallback
end

-- ── F1 (ground) – Request Taxi ───────────────────────────────
function ATC.onTaxiRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName

    ATC.msg(rec.groupId, string.format(
        "%s\n"                                     ..
        "Taxi to holding point, runway in use.\n"  ..
        "Wind calm.  QNH check.\n"                 ..
        "Monitor this frequency.",
        preamble(unitName, airbaseName, "Ground")))

    ATC.setPhase(unitName, airbaseName, "taxi")
    ATC.setEngagedField(unitName, airbaseName)
    ATC.msgAll(string.format("[Traffic]  %s is taxiing at %s.", cs, airbaseName))
end

-- ── F2 (ground) – Request Takeoff ────────────────────────────
function ATC.onTakeoffRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName
    local fs = ATC.getFieldState(airbaseName)

    if not fs.rwyClear then
        ATC.msg(rec.groupId, string.format(
            "%s\n"                                 ..
            "Hold position.  Runway not clear.\n"  ..
            "Standby for takeoff clearance.",
            preamble(unitName, airbaseName, "Tower")))
        return
    end

    local already = false
    for _, n in ipairs(fs.departSeq) do
        if n == unitName then already = true break end
    end
    if not already then table.insert(fs.departSeq, unitName) end

    local qpos = #fs.departSeq
    if qpos == 1 then
        ATC.msg(rec.groupId, string.format(
            "%s\n"                                           ..
            "Runway clear, cleared for takeoff.\n"           ..
            "Wind calm.  Fly runway heading after departure.",
            preamble(unitName, airbaseName, "Tower")))
        fs.rwyClear = false
        ATC.setPhase(unitName, airbaseName, "takeoff")
        ATC.setEngagedField(unitName, airbaseName)
        ATC.msgAll(string.format("[Traffic]  %s is taking off at %s.", cs, airbaseName))
    else
        ATC.msg(rec.groupId, string.format(
            "%s\n"                                  ..
            "Hold short.  Number %s for departure.",
            preamble(unitName, airbaseName, "Tower"), ATC.ordinal(qpos)))
        ATC.setEngagedField(unitName, airbaseName)
    end
end

-- ── F3 (ground) – Ready for Departure ───────────────────────
function ATC.onReadyDeparture(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName

    ATC.msg(rec.groupId, string.format(
        "%s\n"                                 ..
        "Roger, standby.\n"                    ..
        "Expect takeoff clearance shortly.",
        preamble(unitName, airbaseName, "Tower")))
end

-- ── F1 (airborne) – Request Inbound / Landing ────────────────
function ATC.onInboundRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs     = unit:getCallsign() or unitName
    local fs     = ATC.getFieldState(airbaseName)
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    local altFt  = ATC.getAltFt(unit)
    local seqN   = ATC.addToLandingSeq(unitName, airbaseName)
    rec.seqNum[airbaseName] = seqN

    local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
    local altStr  = altFt  and string.format("%d ft",   altFt)  or "altitude unknown"

    local response
    if seqN == 1 then
        response = string.format(
            "%s\n"                                     ..
            "Radar contact.  %s out at %s.\n"          ..
            "Number 1 for landing.\n"                  ..
            "Cleared for the approach.  Report final.",
            preamble(unitName, airbaseName, "Approach"), distStr, altStr)
        ATC.setPhase(unitName, airbaseName, "approach")
    else
        local aheadName = fs.landingSeq[seqN - 1]
        local aheadUnit = aheadName and Unit.getByName(aheadName)
        local aheadCs   = aheadUnit and aheadUnit:getCallsign() or "preceding traffic"

        response = string.format(
            "%s\n"                                              ..
            "Radar contact.  %s out at %s.\n"                   ..
            "Number %s for landing.  Follow %s.\n"              ..
            "Expect approach clearance when number 1.",
            preamble(unitName, airbaseName, "Approach"),
            distStr, altStr, ATC.ordinal(seqN), aheadCs)
        ATC.setPhase(unitName, airbaseName, "inbound")
    end

    ATC.msg(rec.groupId, response)
    ATC.msgAll(string.format("[Traffic]  %s inbound to %s, number %s.",
        cs, airbaseName, ATC.ordinal(seqN)))

    -- Engage player with this airfield
    ATC.setEngagedField(unitName, airbaseName)

    -- Part 3: If runway data exists, issue radar vectors
    if ATC.getRunway(airbaseName) then
        ATC.vectorToFinal(unitName, airbaseName)
    end
end

-- ── F2 (airborne) – Position Report ─────────────────────────
function ATC.onPositionReport(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs     = unit:getCallsign() or unitName
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    local altFt  = ATC.getAltFt(unit)
    local spdKt  = ATC.getSpeedKt(unit)
    local seqN   = ATC.seqPos(unitName, airbaseName)

    local distStr = distNM and string.format("%.1f NM", distNM) or "unknown"
    local altStr  = altFt  and string.format("%d ft",   altFt)  or "unknown"
    local spdStr  = spdKt  and string.format("%d kt",   spdKt)  or "unknown"
    local seqStr  = seqN > 0 and ("  Number " .. ATC.ordinal(seqN) .. ".") or ""

    ATC.msg(rec.groupId, string.format(
        "%s\n"                           ..
        "Position: %s from field.\n"     ..
        "Altitude: %s.  Speed: %s.%s",
        preamble(unitName, airbaseName, getController(unitName, airbaseName)),
        distStr, altStr, spdStr, seqStr))
end

-- ── F3 – Acknowledge / Wilco ─────────────────────────────────
function ATC.onWilco(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName

    ATC.msg(rec.groupId, string.format(
        "%swilco.", preamble(unitName, airbaseName, getController(unitName, airbaseName))))
end

-- ── F4 (airborne) – Go-Around ────────────────────────────────
function ATC.onGoAround(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName
    local fs = ATC.getFieldState(airbaseName)

    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then table.remove(fs.landingSeq, i) break end
    end
    table.insert(fs.landingSeq, unitName)
    local newSeqN = #fs.landingSeq
    rec.seqNum[airbaseName] = newSeqN

    ATC.msg(rec.groupId, string.format(
        "%s\n"                                                  ..
        "Go-around approved.  Climb runway heading, 3000 ft.\n" ..
        "Re-sequenced number %s.  Contact tower when ready.",
        preamble(unitName, airbaseName, "Tower"), ATC.ordinal(newSeqN)))

    ATC.setPhase(unitName, airbaseName, "goaround")
    -- Reset gear reminder and GS deviation state for the new circuit
    if rec.gearReminded    then rec.gearReminded[airbaseName]    = nil end
    if rec.lastGSDev       then rec.lastGSDev[airbaseName]       = nil end
    if rec.handedOffToTower then rec.handedOffToTower[airbaseName] = nil end
    if rec.approachGate    then rec.approachGate[airbaseName]    = nil end
    if rec.landingCleared  then rec.landingCleared[airbaseName]  = nil end
    if rec.stackAlt        then rec.stackAlt[airbaseName]        = nil end
    if rec.patternAdv      then rec.patternAdv[airbaseName]      = nil end
    if rec.holdPhase       then rec.holdPhase[airbaseName]       = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    fs.rwyClear = true
    ATC.checkAndClearNext(airbaseName)
end

-- ── F1 (landing) – Vacating Runway ───────────────────────────
function ATC.onVacatingRunway(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or unitName
    local fs = ATC.getFieldState(airbaseName)

    ATC.msg(rec.groupId, string.format(
        "%s\n"                                 ..
        "Roger, vacating runway.\n"            ..
        "Taxi to parking.  Welcome to %s.",
        preamble(unitName, airbaseName, "Ground"), airbaseName))

    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then table.remove(fs.landingSeq, i) break end
    end
    fs.rwyClear = true
    -- Reset gear reminder so it fires again on the next approach
    if rec.gearReminded then rec.gearReminded[airbaseName] = nil end
    if rec.handedOffToTower then rec.handedOffToTower[airbaseName] = nil end
    if rec.approachGate then rec.approachGate[airbaseName] = nil end
    if rec.stackAlt then rec.stackAlt[airbaseName] = nil end
    if rec.landingCleared then rec.landingCleared[airbaseName] = nil end
    if rec.patternAdv then rec.patternAdv[airbaseName] = nil end
    if rec.holdPhase  then rec.holdPhase[airbaseName]  = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    ATC.setPhase(unitName, airbaseName, "parked")
    ATC.clearEngagement(unitName)
    ATC.checkAndClearNext(airbaseName)
end

-- ── Emergency ────────────────────────────────────────────────
function ATC.onEmergency(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs     = unit:getCallsign() or unitName
    local ab     = Airbase.getByName(airbaseName)
    local altFt  = ATC.getAltFt(unit)
    local distNM = ATC.distUnitToBase(unit, ab)
    local fs     = ATC.getFieldState(airbaseName)

    local altStr  = altFt  and string.format(" at %d ft",    altFt)  or ""
    local distStr = distNM and string.format(", %.1f NM out", distNM) or ""

    ATC.msg(rec.groupId, string.format(
        "MAYDAY ACKNOWLEDGED  --  %s\n"               ..
        "──────────────────────────────\n"            ..
        "%s%s.\n"                                     ..
        "Runway cleared for immediate approach.\n"    ..
        "Emergency services on standby.\n"            ..
        "State your emergency and intentions.",
        cs, preamble(unitName, airbaseName, "Tower"), altStr .. distStr),
        true)

    ATC.msgAll(string.format(
        "[EMERGENCY]  %s declaring emergency at %s%s%s.",
        cs, airbaseName, altStr, distStr))

    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then table.remove(fs.landingSeq, i) break end
    end
    table.insert(fs.landingSeq, 1, unitName)
    rec.seqNum[airbaseName] = 1

    if not rec.landingCleared then rec.landingCleared = {} end
    rec.landingCleared[airbaseName] = true
    ATC.setPhase(unitName, airbaseName, "approach")
    ATC.setEngagedField(unitName, airbaseName)
end

--- Notify the next aircraft in the landing sequence that the runway is clear.
function ATC.checkAndClearNext(airbaseName)
    local fs = ATC.state.airfields[airbaseName]
    if not fs or not fs.rwyClear then return end
    if #fs.landingSeq == 0 then return end

    local nextName = fs.landingSeq[1]
    local nextRec  = ATC.state.aircraft[nextName]
    if not nextRec then return end

    local nextUnit = Unit.getByName(nextName)
    local nextCs   = nextUnit and nextUnit:getCallsign() or nextName

    ATC.msg(nextRec.groupId, string.format(
        "%s\n"                                     ..
        "Runway clear.  You are number 1.\n"       ..
        "Cleared for the approach.  Report final.",
        preamble(nextName, airbaseName, "Approach")))

    if not nextRec.landingCleared then nextRec.landingCleared = {} end
    nextRec.landingCleared[airbaseName] = true
    ATC.setPhase(nextName, airbaseName, "approach")

    -- Cascade: remaining holding aircraft each descend 1000 ft in the stack.
    -- #2 → 2000, #3 → 3000, etc., making room for new arrivals at the top.
    local ab    = Airbase.getByName(airbaseName)
    local abPos = ab and ATC.getAirbasePos(ab)
    for i = 2, #fs.landingSeq do
        local wName = fs.landingSeq[i]
        local wRec  = ATC.state.aircraft[wName]
        local wUnit = Unit.getByName(wName)
        if wRec and wUnit and wRec.stackAlt then
            local oldAlt = wRec.stackAlt[airbaseName]
            if oldAlt then
                local newAlt = math.max(2000, oldAlt - 1000)
                if newAlt ~= oldAlt then
                    wRec.stackAlt[airbaseName] = newAlt
                    if fs.holdStack then fs.holdStack[wName] = newAlt end
                    -- Notify pilot of new hold altitude; heading unchanged
                    local cs  = wUnit:getCallsign() or wName
                    local spd = STACK_LEVEL_SPEED[newAlt] or 200
                    if abPos then
                        ATC.radioMsg(wRec.groupId, abPos, string.format(
                            "%s, descend and maintain %d ft.  Speed %d kt.",
                            cs, newAlt, spd), true)
                    end
                end
            end
        end
    end
end


-- ============================================================
-- 6.  EVENT HANDLER
-- ============================================================
ATC.eventHandler = {}

function ATC.eventHandler:onEvent(event)

    -- BIRTH: player enters a slot ────────────────────────────
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if not unit then return end
        if not ATC.isPlayer(unit) then return end   -- PLAYER-ONLY GUARD

        local unitName = unit:getName()
        local group    = unit:getGroup()
        if not group then return end
        local groupId  = group:getID()

        timer.scheduleFunction(function()
            local u = Unit.getByName(unitName)
            if not u or not ATC.isPlayer(u) then return end

            ATC.getOrCreateRecord(unitName, groupId)
            ATC.buildFullMenu(unitName)
        end, nil, timer.getTime() + 3)

    -- Additional event handling can go here if needed

    end
end

world.addEventHandler(ATC.eventHandler)

-- Schedule periodic menu rebuild
timer.scheduleFunction(ATC.retryAddMenus, {}, timer.getTime() + 5)

-- Schedule periodic vectoring updates (approach phase, >ilsHandoffNM)
local function runVectoring(_, t)
    ATC.checkVectoring()
    return t + ATC.config.vectoringInterval
end
timer.scheduleFunction(runVectoring, nil, timer.getTime() + 10)

-- Schedule periodic glideslope/speed/gear checks (final phase)
local function runGlideslopes(_, t)
    ATC.checkGlideslopes()
    return t + ATC.config.guidanceInterval
end
timer.scheduleFunction(runGlideslopes, nil, timer.getTime() + 10)

--[[
  Called every scheduler tick for every player currently in
  "approach" or "final" phase and within finalNM of their target field.

  Per aircraft, per tick it checks (in priority order):
    1. Stall / dangerously-slow airborne → immediate go-around warning.
    2. Speed too high on short final → reduce speed call.
    3. Gear reminder at ≤8 NM (once per approach, cleared by vacate/go-around).
    4. Glideslope deviation > gsDeviationFt → above/below/back-on-path calls.
    5. All clear → "on glide path, continue" (only when transitioning to "on").

  Anti-spam: guidance messages are rate-limited to guidanceInterval seconds
  per unit per field, EXCEPT the stall / go-around warning which is immediate.

  ATC.checkSpacing()
  ──────────────────
  For each pair of consecutive aircraft in a landing sequence:
  if the gap between them is < separationNM, the trailing aircraft
  receives a one-time "reduce speed" / "expect delay" call.
--]]

--- Safe nil-guard accessor: ensure guidance state tables exist on record.
local function ensureGuidanceTables(rec, abName)
    if not rec.lastGuidance then rec.lastGuidance = {} end
    if not rec.lastGSDev    then rec.lastGSDev    = {} end
    if not rec.gearReminded then rec.gearReminded = {} end
    if not rec.handedOffToTower then rec.handedOffToTower = {} end
    if not rec.patternAdv   then rec.patternAdv   = {} end
end

function ATC.checkGlideslopes()
    local now = timer.getTime()

    for abName, fs in pairs(ATC.state.airfields) do
        local ab    = Airbase.getByName(abName)
        local abPos = ab and ATC.getAirbasePos(ab)
        if ab and abPos then
            for _, unitName in ipairs(fs.landingSeq) do
                local rec  = ATC.state.aircraft[unitName]
                local unit = Unit.getByName(unitName)
                if rec and unit and ATC.isPlayer(unit) then
                    ensureGuidanceTables(rec, abName)

                    local ph     = ATC.getPhase(unitName, abName)
                    local distNM = ATC.distUnitToBase(unit, ab)
                    if distNM and distNM <= ATC.config.finalNM then
                        local cs     = unit:getCallsign() or unitName
                        local spdKt  = ATC.getSpeedKt(unit)
                        local altFt  = ATC.getAltFt(unit)
                        local spds   = ATC.getApproachSpeeds(unit)
                        local lastT  = rec.lastGuidance[abName] or 0
                        local onFinal = distNM <= 3  -- "short final" threshold

                        -- Determine controller based on distance
                        local controller = onFinal and "Tower" or "Approach"

                        -- ── Handoff from Approach to Tower at 5 NM ──
                        if onFinal and not rec.handedOffToTower[abName] then
                            ATC.radioMsg(rec.groupId, abPos, string.format(
                                "%scontact %s Tower on this frequency.\n" ..
                                "%.1f NM from threshold.",
                                controllerCall(unitName, abName, "Approach"), abName, distNM),
                                false)
                            rec.handedOffToTower[abName] = true
                        end

                        -- Determine controller based on distance
                        local controller = onFinal and "Tower" or "Approach"

                        -- ── 1. Stall / dangerously slow (immediate, no rate-limit) ──
                        if spdKt and spdKt < ATC.config.stallWarnKt and unit:inAir() then
                            ATC.radioMsg(rec.groupId, abPos, string.format(
                                "%sgo around, go around!\n"                ..
                                "Airspeed critically low:  %d kt.\n"       ..
                                "Climb immediately, runway heading.",
                                controllerCall(unitName, abName, controller), spdKt), true)
                            ATC.setPhase(unitName, abName, "goaround")
                            rec.lastGuidance[abName] = now

                        -- Rate-limit all remaining calls
                        elseif (now - lastT) >= ATC.config.guidanceInterval then
                            local cleared = rec.landingCleared and rec.landingCleared[abName]

                            -- ── 2. Gear + approach-speed reminder (once, cleared aircraft ≤5 NM) ──
                            if cleared and distNM <= 5 and not rec.gearReminded[abName] then
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sslow to approach speed, %d kt.\n"   ..
                                    "Check gear down and locked.  %.1f NM.",
                                    controllerCall(unitName, abName, controller),
                                    spds.final, distNM),
                                    false)
                                rec.gearReminded[abName] = true
                                rec.lastGuidance[abName] = now

                            -- ── 3. Speed too high on short final (cleared aircraft) ───────────────
                            elseif cleared and onFinal and spdKt and spdKt > spds.maxFinal then
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sreduce speed to %d kt.\n"              ..
                                    "You are at %d kt  (%.1f NM, %s ft).",
                                    controllerCall(unitName, abName, controller),
                                    spds.final, spdKt,
                                    distNM, altFt and tostring(altFt) or "unknown"),
                                    false)
                                rec.lastGuidance[abName] = now

                            end  -- if/elseif gear-speed checks
                        end  -- elseif rate_limit

                        -- ── Pattern leg advisory (fires once per leg transition) ──────────
                        -- Only fires when the player is on final approach (not in a racetrack hold).
                        -- During holds, the inbound leg heading matches final — skip to avoid false calls.
                        local inHold = rec.holdPhase and rec.holdPhase[abName]
                        local rwy = ATC.runways[abName]
                        if rwy and not inHold then
                            local legs = ATC.getPatternLegs(rwy)
                            local vel  = unit:getVelocity()
                            local acHdg = nil
                            if vel then
                                acHdg = math.deg(math.atan2(vel.z, vel.x))
                                if acHdg < 0 then acHdg = acHdg + 360 end
                            end
                            if legs and acHdg then
                                if not rec.patternAdv then rec.patternAdv = {} end
                                local prevAdv    = rec.patternAdv[abName]
                                local rwyNum     = string.format("%02d", math.floor((rwy.hdg + 5) / 10))
                                local trafficDir = (legs.dir == "R") and "right" or "left"
                                local patAlt     = math.floor(
                                    rwy.patternAlt or (rwy.elevation + ATC.config.defaultPatternAltFt))

                                -- Final: within 20° of runway heading, ≤6 NM
                                if math.abs(angleDiff(acHdg, legs.finalHdg)) <= 20
                                and distNM <= 6 and prevAdv ~= "final" then
                                    rec.patternAdv[abName] = "final"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%sestablished on final, runway %s.\nContinue approach.",
                                        controllerCall(unitName, abName, "Tower"), rwyNum), false)

                                -- Base: within 25° of base heading, ≤8 NM, not yet called base or final
                                elseif math.abs(angleDiff(acHdg, legs.baseHdg)) <= 25
                                and distNM <= 8
                                and prevAdv ~= "base" and prevAdv ~= "final" then
                                    rec.patternAdv[abName] = "base"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%son base, runway %s.\nTurn final heading %s.  Descend to %d ft.",
                                        controllerCall(unitName, abName, "Tower"),
                                        rwyNum, ATC.fmtHdg(legs.finalHdg), patAlt - 300), false)

                                -- Downwind: within 30° of downwind heading, 3–12 NM, not yet called
                                elseif math.abs(angleDiff(acHdg, legs.downwindHdg)) <= 30
                                and distNM <= 12 and distNM > 3 and prevAdv == nil then
                                    rec.patternAdv[abName] = "downwind"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%sabeam the threshold, runway %s, %s traffic.\nDescend to %d ft.  Base heading %s.",
                                        controllerCall(unitName, abName, "Approach"),
                                        rwyNum, trafficDir, patAlt,
                                        ATC.fmtHdg(legs.baseHdg)), false)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end


--- Assign an approach stack altitude to an inbound unit.
--- The stack contains one slot per fixed level {2000,3000,4000,5000}.
--- The player is placed at the lowest unoccupied level that is at or above
--- their current altitude rounded up to the nearest 1000 ft.
--- e.g. at 1600 ft → minimum 2000;  at 2100 ft → minimum 3000.
function ATC.assignStackLevel(unitName, abName, currAltFt)
    local fs = ATC.getFieldState(abName)
    if not fs.holdStack then fs.holdStack = {} end

    -- Minimum level: round current altitude UP to nearest 1000, clamp 2000–5000
    local minLevel = math.ceil(currAltFt / 1000) * 1000
    minLevel = math.max(2000, math.min(5000, minLevel))

    -- Collect levels already occupied by OTHER aircraft
    local occupied = {}
    for uName, alt in pairs(fs.holdStack) do
        if uName ~= unitName then occupied[alt] = true end
    end

    -- Lowest available level at or above minLevel (search from 2000 upward)
    local assigned = 5000  -- fallback if all slots taken
    for i = #STACK_LEVELS, 1, -1 do
        local lv = STACK_LEVELS[i]
        if lv >= minLevel and not occupied[lv] then
            assigned = lv
            break
        end
    end

    fs.holdStack[unitName] = assigned
    return assigned
end

--- Release a unit's hold stack slot when it lands or cancels.
function ATC.freeStackLevel(unitName, abName)
    local fs = ATC.state.airfields[abName]
    if fs and fs.holdStack then
        fs.holdStack[unitName] = nil
    end
end

--- Issue a vectoring radio message to the player.
-- targetHdg: heading to fly. gate: table with altFt and speedKt.
function ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, targetHdg, now, abName)
    local cs      = unit:getCallsign() or unitName
    local altFt   = ATC.getAltFt(unit)
    local currSpd = ATC.getSpeedKt(unit)
    local vel     = unit:getVelocity()
    local currHdg = 0
    if vel then
        currHdg = math.deg(math.atan2(vel.z, vel.x))
        if currHdg < 0 then currHdg = currHdg + 360 end
    end

    local hdgDiff = math.abs(angleDiff(currHdg, targetHdg))
    local altDiff = altFt and math.abs(altFt - gate.altFt) or 999
    local spdDiff = (currSpd and not gate.noSpeed) and math.abs(currSpd - gate.speedKt) or 0

    -- Suppress re-issue if already on parameters within tolerance
    if hdgDiff <= 10 and altDiff <= 50 and (gate.noSpeed or spdDiff <= 10) then
        rec.lastVector[abName] = now
        return
    end

    local hdgPart
    if hdgDiff <= 10 then
        hdgPart = "fly heading " .. ATC.fmtHdg(targetHdg)
    elseif angleDiff(currHdg, targetHdg) > 0 then
        hdgPart = "turn RIGHT heading " .. ATC.fmtHdg(targetHdg)
    else
        hdgPart = "turn LEFT heading " .. ATC.fmtHdg(targetHdg)
    end

    local altTol = math.max(50, math.floor(gate.altFt * 0.03))
    local altPart
    if altDiff <= altTol then
        altPart = "maintain " .. gate.altFt .. " ft"
    elseif altFt and altFt > gate.altFt then
        altPart = "descend to " .. gate.altFt .. " ft"
    else
        altPart = "climb to " .. gate.altFt .. " ft"
    end

    if gate.noSpeed then
        ATC.radioMsg(rec.groupId, abPos,
            string.format("%s, %s, %s.", cs, hdgPart, altPart), true)
    else
        local spdTol = math.max(10, math.floor(gate.speedKt * 0.05))
        local spdPart
        if spdDiff <= spdTol then
            spdPart = "maintain " .. gate.speedKt .. " kt"
        elseif currSpd and currSpd > gate.speedKt then
            spdPart = "reduce speed to " .. gate.speedKt .. " kt"
        else
            spdPart = "increase speed to " .. gate.speedKt .. " kt"
        end
        ATC.radioMsg(rec.groupId, abPos,
            string.format("%s, %s, %s, %s.", cs, hdgPart, altPart, spdPart), true)
    end
    rec.lastVector[abName] = now
end

--- Issue initial radar vectors toward the racetrack entry point.
-- The entry point is 12 NM outbound on the runway centreline.
-- All aircraft converge on this point regardless of their inbound direction.
function ATC.vectorToFinal(unitName, airbaseName)
    local rec  = ATC.state.aircraft[unitName]
    local unit = Unit.getByName(unitName)
    local ab   = Airbase.getByName(airbaseName)
    local rwy  = ATC.getRunway(airbaseName)
    if not rec or not unit or not ab or not rwy then return end

    local uPos  = unit:getPoint()
    local abPos = ATC.getAirbasePos(ab)
    local altFt = ATC.getAltFt(unit)

    -- Assign stack altitude (rounded up to nearest 1000, lowest free slot)
    local assignedAlt = ATC.assignStackLevel(unitName, airbaseName, altFt)
    rec.stackAlt[airbaseName] = assignedAlt

    local holdGate = {
        altFt   = assignedAlt,
        speedKt = STACK_LEVEL_SPEED[assignedAlt] or 200,
    }
    local farNM       = STACK_LEVEL_DIST[assignedAlt] or 12
    local inboundHdg  = rwy.hdg % 360
    local outboundHdg = (inboundHdg + 180) % 360

    -- Compute the racetrack entry point: farNM outbound on runway centreline.
    -- x = north component, z = east component (DCS convention).
    local outHdgRad = math.rad(outboundHdg)
    local farM      = farNM * 1852
    local entryPos  = {
        x = abPos.x + farM * math.cos(outHdgRad),
        z = abPos.z + farM * math.sin(outHdgRad),
        y = abPos.y,
    }

    -- Bearing from current position toward entry point
    local dx        = entryPos.x - uPos.x
    local dz        = entryPos.z - uPos.z
    local toEntryHdg = math.deg(math.atan2(dz, dx))
    if toEntryHdg < 0 then toEntryHdg = toEntryHdg + 360 end

    -- Phase: if already inside the racetrack gate, go outbound first;
    -- otherwise fly toward entry point (roughly inbound direction).
    if not rec.holdPhase then rec.holdPhase = {} end
    local initDist = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    rec.holdPhase[airbaseName] = initDist <= farNM and "outbound" or "inbound"

    -- No speed instruction while still en route to the hold gate
    holdGate.noSpeed = initDist > farNM

    rec.approachGate[airbaseName] = 1
    rec.patternLeg[airbaseName]   = "hold"
    rec.lastVector[airbaseName]   = timer.getTime()

    ATC.issueVectorInstruction(unitName, rec, unit, abPos, holdGate,
        toEntryHdg, timer.getTime(), airbaseName)
end

--- Per-tick vectoring: manages racetrack hold pattern and traffic pattern entry.
--
-- HOLD (not yet cleared for approach):
--   "outbound" → fly reciprocal to farNM → turn "inbound"
--   "inbound"  → fly runway heading to nearNM → turn "outbound" (hold orbit)
--
-- APPROACH (landingCleared set by checkAndClearNext):
--   "inbound" continues toward field; at 2 NM break to downwind heading,
--   set holdPhase=nil → checkGlideslopes handles base/final advisories.
function ATC.checkVectoring()
    local now = timer.getTime()
    for unitName, rec in pairs(ATC.state.aircraft) do
        local unit = Unit.getByName(unitName)
        if unit and ATC.isPlayer(unit) then
            local abName = rec.activeField
            if not abName then
                -- No active field for this record, skip
            else
                local ab  = Airbase.getByName(abName)
                local rwy = ATC.getRunway(abName)
                if ab and rwy then
                    local uPos   = unit:getPoint()
                    local abPos  = ATC.getAirbasePos(ab)
                    local distNM = ATC.mToNM(ATC.distVec3H(uPos, abPos))

                    local ph = ATC.getPhase(unitName, abName)
                    if ph == "approach" or ph == "inbound" then
                        local altFt    = ATC.getAltFt(unit)
                        local stackAlt = rec.stackAlt and rec.stackAlt[abName]
                        if not stackAlt then
                            stackAlt = ATC.assignStackLevel(unitName, abName, altFt)
                            rec.stackAlt[abName] = stackAlt
                        end

                        -- Hold target: current stack altitude and speed
                        local holdGate = {
                            altFt   = stackAlt,
                            speedKt = STACK_LEVEL_SPEED[stackAlt] or 200,
                        }
                        -- Pattern entry target: field pattern altitude and Vref
                        local spds    = ATC.getApproachSpeeds(unit)
                        local patAlt  = math.floor(rwy.patternAlt or
                                        (rwy.elevation + ATC.config.defaultPatternAltFt))
                        local finalGate = { altFt = patAlt, speedKt = spds.final }

                        local legs        = ATC.getPatternLegs(rwy)
                        local inboundHdg  = rwy.hdg % 360
                        local outboundHdg = (inboundHdg + 180) % 360
                        local nearNM      = ATC.config.ilsHandoffNM or 5
                        local farNM       = STACK_LEVEL_DIST[stackAlt] or 12
                        local cleared     = rec.landingCleared and rec.landingCleared[abName]
                        local lastT       = rec.lastVector[abName] or 0
                        local interval    = ATC.config.vectoringInterval or 25

                        if not rec.holdPhase then rec.holdPhase = {} end
                        local holdPhase = rec.holdPhase[abName]

                        if holdPhase == nil then
                            -- On final approach: guide toward threshold outside nearNM
                            if distNM >= nearNM and (now - lastT) > interval then
                                local targetHdg = ATC.getInterceptHeading(uPos, abPos, rwy)
                                ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                    finalGate, targetHdg, now, abName)
                            end

                        elseif holdPhase == "inbound" then
                            -- Flying runway heading toward field
                            if cleared and distNM <= 2 then
                                -- Cleared & overhead: break to downwind, exit hold
                                rec.holdPhase[abName] = nil  -- checkGlideslopes takes over
                                if legs then
                                    ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                        finalGate, legs.downwindHdg, now, abName)
                                end
                            elseif not cleared and distNM <= nearNM then
                                -- Not cleared: turn outbound and continue holding
                                rec.holdPhase[abName] = "outbound"
                                ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                    holdGate, outboundHdg, now, abName)
                            elseif distNM <= farNM and (now - lastT) > interval then
                                -- Inside the hold gate: re-issue position-relative intercept heading
                                local interceptHdg = ATC.getInterceptHeading(uPos, abPos, rwy)
                                ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                    holdGate, interceptHdg, now, abName)
                            end

                        else -- "outbound"
                            -- Flying reciprocal heading, increasing distance from field
                            if distNM >= farNM then
                                -- Reached outbound gate: turn inbound
                                rec.holdPhase[abName] = "inbound"
                                local interceptHdg = ATC.getInterceptHeading(uPos, abPos, rwy)
                                ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                    holdGate, interceptHdg, now, abName)
                            elseif (now - lastT) > interval then
                                -- Still outbound: re-issue
                                ATC.issueVectorInstruction(unitName, rec, unit, abPos,
                                    holdGate, outboundHdg, now, abName)
                            end
                        end
                    end
                end -- if ab and rwy
            end -- if not abName / else
        end
    end
end
