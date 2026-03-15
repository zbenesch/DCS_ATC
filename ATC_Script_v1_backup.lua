-- ============================================================
--  ATC_Script.lua  --  DCS World Air Traffic Control System
--  Version : 1.0  (Part 1 – Radio Menu & State Foundation)
--  Author  : GitHub Copilot
--
--  HOW TO INSTALL
--  ──────────────
--  1. Open the DCS Mission Editor.
--  2. Go to Triggers → New Trigger:
--       Type : MISSION START
--       Action : DO SCRIPT FILE → select this file
--  3. Save and fly the mission.
--
--  HOW PLAYERS USE IT
--  ──────────────────
--  Press ` (backtick / comms key) → F10 Other → [ATC] <airfield>
--  A context-sensitive submenu appears.  Options change depending
--  on whether the player is parked, taxiing, airborne, inbound etc.
--
--  CUSTOMISING
--  ───────────
--  Edit only the CONFIG section below.  Everything else is
--  driven by those values.  No external libraries required.
-- ============================================================


-- ============================================================
-- 0.  NAMESPACE  –  all ATC data lives inside this table
-- ============================================================
ATC = ATC or {}


-- ============================================================
-- 1.  CONFIG  –  edit this block for each mission / airfield
-- ============================================================
ATC.config = {

    -- ── Airfield ────────────────────────────────────────────
    airfieldName    = "Batumi",          -- exact DCS Airbase name
    atcCallsign     = "Batumi Tower",    -- shown in every ATC message
    menuTitle       = "[ATC] Batumi",    -- F10 submenu root label

    -- ── Active runway ────────────────────────────────────────
    -- Magnetic heading of the landing runway (degrees).
    -- Used in Part 2 for glideslope math.
    activeRunway    = "13",              -- runway designator string
    rwyHeadingDeg   = 130,              -- magnetic heading for landing

    -- ── Glideslope ───────────────────────────────────────────
    gsAngleDeg      = 3.0,              -- standard ILS glideslope (deg)

    -- ── Airfield position ────────────────────────────────────
    -- Used for distance / bearing calculations.
    -- Grab from F10 map in DCS (right-click → coordinates).
    -- Default values are Batumi, Georgia.
    airfieldLat     = 41.5998,
    airfieldLon     = 41.5998,          -- placeholder – replace with real lon
    airfieldElev    = 32,               -- elevation in metres above MSL

    -- ── Display ──────────────────────────────────────────────
    msgDuration     = 15,               -- seconds text stays on screen
    msgDurationLong = 25,               -- for ATIS / longer messages

    -- ── Traffic management ───────────────────────────────────
    maxSequence     = 8,                -- max aircraft in landing sequence
    separationNM    = 3,                -- target spacing between inbounds (NM)

    -- ── Frequencies (informational – shown in ATIS) ──────────
    freqTower       = "131.000",        -- MHz
    freqGround      = "131.000",
    freqATIS        = "123.050",
    elevation       = "32 ft",          -- shown in ATIS
    ils             = "108.90",         -- ILS frequency if applicable
}


-- ============================================================
-- 2.  STATE  –  runtime data, reset on each mission start
-- ============================================================
ATC.state = {
    -- aircraft[unitName] = {
    --   groupId   : number
    --   phase     : "unknown"|"parked"|"taxi"|"takeoff"|"airborne"
    --               |"inbound"|"approach"|"final"|"landing"|"goaround"
    --   cleared   : bool   – holds a clearance
    --   seqNum    : number – landing sequence slot (0 = not sequenced)
    --   menuRoot  : table  – path table returned by addSubMenuForGroup
    --   lastMsg   : string – last ATC text sent to this unit
    -- }
    aircraft    = {},

    -- ordered list of unitNames waiting to land (index 1 = next to land)
    landingSeq  = {},

    -- ordered list of unitNames waiting for takeoff clearance
    departSeq   = {},

    -- runway occupied flag
    rwyClear    = true,
}


-- ============================================================
-- 3.  UTILITY HELPERS
-- ============================================================

--- Send a text message to a specific group only.
-- @param groupId  number
-- @param text     string
-- @param long     bool (optional) use longer display time
function ATC.msg(groupId, text, long)
    local dur = long and ATC.config.msgDurationLong or ATC.config.msgDuration
    trigger.action.outTextForGroup(groupId, text, dur, false)
end

--- Send a text message to ALL players (e.g. traffic info).
function ATC.msgAll(text)
    trigger.action.outText(text, ATC.config.msgDuration, false)
end

--- Degrees → radians.
function ATC.rad(deg) return deg * math.pi / 180 end

--- Compute straight-line distance in metres between two DCS Vec3 points.
function ATC.distVec3(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

--- Convert metres to nautical miles.
function ATC.mToNM(m) return m / 1852 end

--- Convert metres to feet.
function ATC.mToFt(m) return m * 3.28084 end

--- Get the DCS Vec3 position of the airfield.
-- Cached after first call.
function ATC.getAirfieldPos()
    if ATC.state._airfieldPos then return ATC.state._airfieldPos end
    local ab = Airbase.getByName(ATC.config.airfieldName)
    if ab then
        ATC.state._airfieldPos = ab:getPoint()
    end
    return ATC.state._airfieldPos
end

--- Return the state record for a unit, creating it if missing.
function ATC.getOrCreateRecord(unitName, groupId)
    if not ATC.state.aircraft[unitName] then
        ATC.state.aircraft[unitName] = {
            groupId  = groupId,
            phase    = "unknown",
            cleared  = false,
            seqNum   = 0,
            menuRoot = nil,
            lastMsg  = "",
        }
    end
    return ATC.state.aircraft[unitName]
end

--- Safely remove a unit record and clean up sequences.
function ATC.removeRecord(unitName)
    -- remove from landing sequence
    for i, n in ipairs(ATC.state.landingSeq) do
        if n == unitName then table.remove(ATC.state.landingSeq, i) break end
    end
    -- remove from departure sequence
    for i, n in ipairs(ATC.state.departSeq) do
        if n == unitName then table.remove(ATC.state.departSeq, i) break end
    end
    ATC.state.aircraft[unitName] = nil
end

--- Look up landing sequence position for a unit (1-based, 0 = not in seq).
function ATC.seqPos(unitName)
    for i, n in ipairs(ATC.state.landingSeq) do
        if n == unitName then return i end
    end
    return 0
end

--- Add a unit to the landing sequence if not already present.
-- Returns the assigned sequence number.
function ATC.addToLandingSeq(unitName)
    local pos = ATC.seqPos(unitName)
    if pos > 0 then return pos end
    table.insert(ATC.state.landingSeq, unitName)
    return #ATC.state.landingSeq
end

--- Build a nice ordinal string: 1→"1st", 2→"2nd", etc.
function ATC.ordinal(n)
    if n == 1 then return "1st"
    elseif n == 2 then return "2nd"
    elseif n == 3 then return "3rd"
    else return n.."th" end
end

--- Get unit altitude in feet MSL (returns nil if unit not found/not airborne).
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
    return math.floor(spd * 1.94384) -- m/s → knots
end

--- Get distance from unit to airfield in NM.
function ATC.distToFieldNM(unit)
    local afPos = ATC.getAirfieldPos()
    if not afPos or not unit then return nil end
    local uPos = unit:getPoint()
    if not uPos then return nil end
    return ATC.mToNM(ATC.distVec3(uPos, afPos))
end


-- ============================================================
-- 4.  MENU SYSTEM
-- ============================================================

--[[
  Menu layout (context-sensitive):

  Always visible:
    F1  ATIS / Field Info
    F7  Declare Emergency

  On ground (parked / taxi):
    F2  Request Taxi Clearance
    F3  Request Takeoff Clearance
    F4  Report Ready for Departure

  Airborne / inbound:
    F2  Request Inbound / Landing
    F3  Report Position
    F4  Acknowledge / Wilco
    F5  Request Go-Around

  The menu is fully rebuilt (remove all → re-add) each time the
  player's phase changes, so stale options never appear.
--]]

--- Remove all menu items under a group's ATC root and the root itself.
function ATC.clearMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec or not rec.menuRoot then return end
    missionCommands.removeItemForGroup(rec.groupId, rec.menuRoot)
    rec.menuRoot = nil
end

--- Rebuild the F10 ATC submenu for one player group.
-- Must be called after any phase change.
function ATC.buildMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    -- Remove old menu first
    ATC.clearMenu(unitName)

    local gid  = rec.groupId
    local cfg  = ATC.config
    local ph   = rec.phase

    -- Create root submenu under F10 Other
    local root = missionCommands.addSubMenuForGroup(gid, cfg.menuTitle, nil)
    rec.menuRoot = root

    -- ── Always available ──────────────────────────────────────
    missionCommands.addCommandForGroup(gid, "F1 - ATIS / Field Information",
        root, ATC.onATIS, unitName)

    -- ── Ground options ────────────────────────────────────────
    if ph == "unknown" or ph == "parked" or ph == "taxi" then
        missionCommands.addCommandForGroup(gid, "F2 - Request Taxi Clearance",
            root, ATC.onTaxiRequest, unitName)
        missionCommands.addCommandForGroup(gid, "F3 - Request Takeoff Clearance",
            root, ATC.onTakeoffRequest, unitName)
        missionCommands.addCommandForGroup(gid, "F4 - Ready for Departure",
            root, ATC.onReadyDeparture, unitName)

    -- ── Airborne / inbound options ────────────────────────────
    elseif ph == "airborne" or ph == "inbound" or
           ph == "approach" or ph == "final"   or ph == "goaround" then
        missionCommands.addCommandForGroup(gid, "F2 - Request Landing / Inbound",
            root, ATC.onInboundRequest, unitName)
        missionCommands.addCommandForGroup(gid, "F3 - Report Position",
            root, ATC.onPositionReport, unitName)
        missionCommands.addCommandForGroup(gid, "F4 - Acknowledge / Wilco",
            root, ATC.onWilco, unitName)
        missionCommands.addCommandForGroup(gid, "F5 - Request Go-Around",
            root, ATC.onGoAround, unitName)

    -- ── Landing / rollout ─────────────────────────────────────
    elseif ph == "landing" then
        missionCommands.addCommandForGroup(gid, "F2 - Vacating Runway",
            root, ATC.onVacatingRunway, unitName)
        missionCommands.addCommandForGroup(gid, "F4 - Acknowledge / Wilco",
            root, ATC.onWilco, unitName)
    end

    -- ── Always available ──────────────────────────────────────
    missionCommands.addCommandForGroup(gid, "F7 - Declare Emergency",
        root, ATC.onEmergency, unitName)
end

--- Change a unit's phase and immediately rebuild its menu.
function ATC.setPhase(unitName, newPhase)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    if rec.phase == newPhase then return end  -- no-op if same
    rec.phase = newPhase
    ATC.buildMenu(unitName)
end


-- ============================================================
-- 5.  ATC LOGIC  –  handler functions (one per menu item)
-- ============================================================

--- Format the standard ATC preamble: "Batumi Tower, <callsign>, ..."
local function preamble(unitName)
    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    return ATC.config.atcCallsign .. ",  " .. cs .. ",  "
end

-- ── F1 ATIS / Field Information ───────────────────────────────
function ATC.onATIS(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local cfg = ATC.config

    local windDir, windSpd = "calm", ""
    -- In Part 2 we'll pull live atmosphere data via atmosphere.getWindAtPoint()
    -- For now we report calm winds as a placeholder.

    local text = string.format(
        "ATIS  %s\n" ..
        "──────────────────────────────\n" ..
        "Active runway : %s  (HDG %03d°)\n" ..
        "Tower freq    : %s MHz\n" ..
        "ILS           : %s MHz\n" ..
        "Elevation     : %s\n" ..
        "Glideslope    : %.1f°\n" ..
        "Wind          : %s%s\n" ..
        "Traffic       : %d aircraft in sequence\n" ..
        "──────────────────────────────\n" ..
        "Advise on initial contact.",
        cfg.airfieldName,
        cfg.activeRunway, cfg.rwyHeadingDeg,
        cfg.freqTower,
        cfg.ils,
        cfg.elevation,
        cfg.gsAngleDeg,
        windDir, windSpd,
        #ATC.state.landingSeq
    )
    ATC.msg(rec.groupId, text, true)
end

-- ── F2 (ground) – Request Taxi ────────────────────────────────
function ATC.onTaxiRequest(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    local cfg  = ATC.config

    local response = string.format(
        "%s%s,\n" ..
        "Taxi to holding point runway %s.\n" ..
        "Wind calm.  QNH reported.\n" ..
        "Monitor this frequency.",
        preamble(unitName), cs,
        cfg.activeRunway
    )
    ATC.msg(rec.groupId, response)
    ATC.setPhase(unitName, "taxi")

    -- announce to all traffic
    ATC.msgAll(string.format("[Traffic]  %s is taxiing at %s.", cs, cfg.airfieldName))
end

-- ── F3 (ground) – Request Takeoff ────────────────────────────
function ATC.onTakeoffRequest(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    local cfg  = ATC.config

    if not ATC.state.rwyClear then
        ATC.msg(rec.groupId, string.format(
            "%s%s,\n" ..
            "Hold position.  Runway %s not clear.\n" ..
            "Standby for takeoff clearance.",
            preamble(unitName), cs, cfg.activeRunway))
        return
    end

    -- add to departure queue
    local alreadyQueued = false
    for _, n in ipairs(ATC.state.departSeq) do
        if n == unitName then alreadyQueued = true break end
    end
    if not alreadyQueued then
        table.insert(ATC.state.departSeq, unitName)
    end

    local pos = #ATC.state.departSeq
    if pos == 1 then
        ATC.msg(rec.groupId, string.format(
            "%s%s,\n" ..
            "Runway %s, cleared for takeoff.\n" ..
            "Wind calm.  Fly runway heading after departure.",
            preamble(unitName), cs, cfg.activeRunway))
        ATC.state.rwyClear = false
        ATC.setPhase(unitName, "takeoff")
        ATC.msgAll(string.format("[Traffic]  %s is taking off from runway %s at %s.",
            cs, cfg.activeRunway, cfg.airfieldName))
    else
        ATC.msg(rec.groupId, string.format(
            "%s%s,\n" ..
            "Hold short runway %s.  Number %s for departure.",
            preamble(unitName), cs, cfg.activeRunway, ATC.ordinal(pos)))
    end
end

-- ── F4 (ground) – Ready for Departure ───────────────────────
function ATC.onReadyDeparture(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName

    ATC.msg(rec.groupId, string.format(
        "%s%s,\n" ..
        "Roger, standby.\n" ..
        "Expect takeoff clearance shortly.",
        preamble(unitName), cs))
end

-- ── F2 (airborne) – Request Inbound / Landing ────────────────
function ATC.onInboundRequest(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    local cfg  = ATC.config

    -- Gather position data
    local distNM = unit and ATC.distToFieldNM(unit) or nil
    local altFt  = unit and ATC.getAltFt(unit)      or nil
    local spdKt  = unit and ATC.getSpeedKt(unit)    or nil

    -- Add to landing sequence
    local seqN = ATC.addToLandingSeq(unitName)
    rec.seqNum = seqN

    local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
    local altStr  = altFt  and string.format("%d ft", altFt)    or "altitude unknown"

    local response
    if seqN == 1 then
        response = string.format(
            "%s%s,\n" ..
            "Radar contact.  %s from %s at %s.\n" ..
            "You are number 1 for landing.\n" ..
            "Runway %s in use.  ILS %s MHz.\n" ..
            "Cleared for the approach.  Report final.",
            preamble(unitName), cs,
            distStr, cfg.airfieldName, altStr,
            cfg.activeRunway, cfg.ils)
        ATC.setPhase(unitName, "approach")
    else
        -- Find the aircraft ahead in the sequence
        local aheadName = ATC.state.landingSeq[seqN - 1]
        local aheadUnit = aheadName and Unit.getByName(aheadName)
        local aheadCs   = aheadUnit and aheadUnit:getCallsign() or "preceding traffic"

        response = string.format(
            "%s%s,\n" ..
            "Radar contact.  %s from %s at %s.\n" ..
            "You are number %s for landing.\n" ..
            "Follow %s on the approach.\n" ..
            "Runway %s in use.  ILS %s MHz.\n" ..
            "Expect approach clearance when number 1.  Report field in sight.",
            preamble(unitName), cs,
            distStr, cfg.airfieldName, altStr,
            ATC.ordinal(seqN), aheadCs,
            cfg.activeRunway, cfg.ils)
        ATC.setPhase(unitName, "inbound")
    end

    ATC.msg(rec.groupId, response)
    ATC.msgAll(string.format("[Traffic]  %s is inbound to %s, number %s.",
        cs, cfg.airfieldName, ATC.ordinal(seqN)))
end

-- ── F3 (airborne) – Position Report ─────────────────────────
function ATC.onPositionReport(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit   = Unit.getByName(unitName)
    local cs     = unit and unit:getCallsign() or unitName
    local distNM = unit and ATC.distToFieldNM(unit) or nil
    local altFt  = unit and ATC.getAltFt(unit)      or nil
    local spdKt  = unit and ATC.getSpeedKt(unit)    or nil
    local cfg    = ATC.config
    local seqN   = ATC.seqPos(unitName)

    local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
    local altStr  = altFt  and string.format("%d ft", altFt)    or "altitude unknown"
    local spdStr  = spdKt  and string.format("%d kt", spdKt)    or ""

    local seqStr  = seqN > 0
        and string.format("  You are number %s.", ATC.ordinal(seqN))
        or ""

    local response = string.format(
        "%s%s,\n" ..
        "Position: %s from %s.\n" ..
        "Altitude: %s.  Speed: %s.\n" ..
        "Runway %s in use.%s",
        preamble(unitName), cs,
        distStr, cfg.airfieldName,
        altStr, spdStr,
        cfg.activeRunway, seqStr)

    ATC.msg(rec.groupId, response)
end

-- ── F4 – Acknowledge / Wilco ─────────────────────────────────
function ATC.onWilco(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName

    ATC.msg(rec.groupId, string.format(
        "%s%s, wilco.", preamble(unitName), cs))
end

-- ── F5 (airborne) – Go-Around ────────────────────────────────
function ATC.onGoAround(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    local cfg  = ATC.config

    -- Remove from front of landing sequence, re-insert at back
    for i, n in ipairs(ATC.state.landingSeq) do
        if n == unitName then table.remove(ATC.state.landingSeq, i) break end
    end
    table.insert(ATC.state.landingSeq, unitName)
    local newSeqN = #ATC.state.landingSeq
    rec.seqNum = newSeqN

    ATC.msg(rec.groupId, string.format(
        "%s%s,\n" ..
        "Go-around approved.  Fly runway heading, climb to 3000 ft.\n" ..
        "You are re-sequenced number %s.\n" ..
        "Contact tower when ready for another approach.",
        preamble(unitName), cs,
        ATC.ordinal(newSeqN)))

    ATC.setPhase(unitName, "goaround")
    ATC.state.rwyClear = true   -- runway is now clear

    -- Notify the next aircraft in sequence
    ATC.checkAndClearNext()
end

-- ── F2 (landing) – Vacating Runway ───────────────────────────
function ATC.onVacatingRunway(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit = Unit.getByName(unitName)
    local cs   = unit and unit:getCallsign() or unitName
    local cfg  = ATC.config

    ATC.msg(rec.groupId, string.format(
        "%s%s,\n" ..
        "Roger, vacating runway %s.\n" ..
        "Taxi to parking, monitor ground %s MHz.\n" ..
        "Welcome to %s.",
        preamble(unitName), cs,
        cfg.activeRunway, cfg.freqGround,
        cfg.airfieldName))

    -- Remove from landing sequence, clear runway
    for i, n in ipairs(ATC.state.landingSeq) do
        if n == unitName then table.remove(ATC.state.landingSeq, i) break end
    end
    ATC.state.rwyClear = true
    ATC.setPhase(unitName, "parked")

    -- Notify the next inbound that runway is clear
    ATC.checkAndClearNext()
end

-- ── F7 – Emergency ───────────────────────────────────────────
function ATC.onEmergency(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end

    local unit   = Unit.getByName(unitName)
    local cs     = unit and unit:getCallsign() or unitName
    local cfg    = ATC.config
    local altFt  = unit and ATC.getAltFt(unit) or nil
    local distNM = unit and ATC.distToFieldNM(unit) or nil

    local altStr  = altFt  and string.format(" at %d ft", altFt)   or ""
    local distStr = distNM and string.format(", %.1f NM out", distNM) or ""

    ATC.msg(rec.groupId, string.format(
        "MAYDAY ACKNOWLEDGED  –  %s\n" ..
        "──────────────────────────────\n" ..
        "%s%s%s.\n" ..
        "Runway %s cleared for immediate approach.\n" ..
        "Emergency services are on standby.\n" ..
        "State your emergency and intentions.",
        cs,
        preamble(unitName), cs, altStr .. distStr,
        cfg.activeRunway), true)

    -- Broadcast to all
    ATC.msgAll(string.format(
        "[EMERGENCY]  %s is declaring an emergency at %s%s%s.",
        cs, cfg.airfieldName, altStr, distStr))

    -- Move emergency aircraft to the front of the queue
    for i, n in ipairs(ATC.state.landingSeq) do
        if n == unitName then table.remove(ATC.state.landingSeq, i) break end
    end
    table.insert(ATC.state.landingSeq, 1, unitName)
    rec.seqNum = 1

    ATC.setPhase(unitName, "approach")
end

-- ── Internal: notify #1 in sequence when runway is free ──────
function ATC.checkAndClearNext()
    if not ATC.state.rwyClear then return end
    if #ATC.state.landingSeq == 0 then return end

    local nextName = ATC.state.landingSeq[1]
    local nextRec  = ATC.state.aircraft[nextName]
    if not nextRec then return end

    local nextUnit = Unit.getByName(nextName)
    local nextCs   = nextUnit and nextUnit:getCallsign() or nextName

    ATC.msg(nextRec.groupId, string.format(
        "%s%s,\n" ..
        "Runway %s clear.  You are number 1.\n" ..
        "Cleared for the approach.  Report final.",
        preamble(nextName), nextCs,
        ATC.config.activeRunway))

    ATC.setPhase(nextName, "approach")
end


-- ============================================================
-- 6.  EVENT HANDLER  –  auto-register / deregister players
-- ============================================================
ATC.eventHandler = {}

function ATC.eventHandler:onEvent(event)
    -- S_EVENT_BIRTH : a unit spawned (player entered a slot)
    if event.id == world.event.S_EVENT_BIRTH then
        local unit = event.initiator
        if not unit then return end
        if not unit:getPlayerName() then return end  -- skip AI

        local unitName = unit:getName()
        local group    = unit:getGroup()
        if not group then return end
        local groupId  = group:getID()

        -- Small delay so DCS fully initialises the unit before we query it
        timer.scheduleFunction(function()
            local rec = ATC.getOrCreateRecord(unitName, groupId)
            -- Determine initial phase: if unit is in air → airborne, else parked
            if unit:inAir() then
                rec.phase = "airborne"
            else
                rec.phase = "parked"
            end
            ATC.buildMenu(unitName)

            -- Welcome message
            ATC.msg(groupId, string.format(
                "%s  –  Welcome.\n" ..
                "Select '[ATC] %s' in F10 Other for ATC services.\n" ..
                "Tower: %s MHz",
                ATC.config.atcCallsign,
                ATC.config.airfieldName,
                ATC.config.freqTower), true)
        end, nil, timer.getTime() + 3)

    -- S_EVENT_PILOT_DEAD or S_EVENT_EJECTION : clean up
    elseif event.id == world.event.S_EVENT_PILOT_DEAD or
           event.id == world.event.S_EVENT_EJECTION then
        local unit = event.initiator
        if not unit then return end
        if not unit:getPlayerName() then return end

        local unitName = unit:getName()
        ATC.clearMenu(unitName)
        ATC.removeRecord(unitName)

    -- S_EVENT_LAND : unit touched down
    elseif event.id == world.event.S_EVENT_LAND then
        local unit = event.initiator
        if not unit then return end
        if not unit:getPlayerName() then return end

        local unitName = unit:getName()
        local rec = ATC.state.aircraft[unitName]
        if not rec then return end

        ATC.state.rwyClear = false          -- runway occupied
        ATC.setPhase(unitName, "landing")

        ATC.msg(rec.groupId, string.format(
            "%s%s,\n" ..
            "Landed.  Vacate runway %s when able.\n" ..
            "Select 'Vacating Runway' when clear.",
            preamble(unitName),
            unit:getCallsign() or unitName,
            ATC.config.activeRunway))

    -- S_EVENT_TAKEOFF : unit lifted off
    elseif event.id == world.event.S_EVENT_TAKEOFF then
        local unit = event.initiator
        if not unit then return end
        if not unit:getPlayerName() then return end

        local unitName = unit:getName()
        local rec = ATC.state.aircraft[unitName]
        if not rec then return end

        -- Remove from departure queue
        for i, n in ipairs(ATC.state.departSeq) do
            if n == unitName then table.remove(ATC.state.departSeq, i) break end
        end

        ATC.state.rwyClear = true
        ATC.setPhase(unitName, "airborne")

        -- If there's another aircraft queued for departure, clear them
        if #ATC.state.departSeq > 0 then
            local nextDep  = ATC.state.departSeq[1]
            local nextRec  = ATC.state.aircraft[nextDep]
            if nextRec then
                local nextUnit = Unit.getByName(nextDep)
                local nextCs   = nextUnit and nextUnit:getCallsign() or nextDep
                ATC.msg(nextRec.groupId, string.format(
                    "%s%s,\n" ..
                    "Runway %s, cleared for takeoff.\n" ..
                    "Wind calm.",
                    preamble(nextDep), nextCs,
                    ATC.config.activeRunway))
                ATC.state.rwyClear = false
                ATC.setPhase(nextDep, "takeoff")
                table.remove(ATC.state.departSeq, 1)
            end
        end
    end
end

world.addEventHandler(ATC.eventHandler)


-- ============================================================
-- 7.  SCHEDULER  –  passive monitoring loop (Part 2 hook)
-- ============================================================
--[[
  This loop runs every 10 seconds and is the foundation for Part 2:
    - Glideslope deviation alerts
    - Spacing warnings between sequenced aircraft
    - Automated "check gear" / speed callouts
    - Runway occupancy timeouts

  For Part 1 it only performs lightweight sanity checks:
    - Auto-detects if an unregistered player unit appears
    - Cleans up records for units that no longer exist
--]]
ATC.schedulerInterval = 10  -- seconds

function ATC.schedulerTick(arg, time)
    -- ── Clean up dead units ──────────────────────────────────
    for unitName, rec in pairs(ATC.state.aircraft) do
        local unit = Unit.getByName(unitName)
        if not unit or not unit:isExist() then
            ATC.clearMenu(unitName)
            ATC.removeRecord(unitName)
        end
    end

    -- ── Auto-detect unregistered player units ─────────────────
    -- Iterate all player units on the map and register any that
    -- slipped through (e.g. fast-mission start before BIRTH fired).
    local playerUnits = {}
    for _, co in ipairs({coalition.side.RED, coalition.side.BLUE, coalition.side.NEUTRAL}) do
        local groups = coalition.getGroups(co, Group.Category.AIRPLANE)
        for _, grp in ipairs(groups or {}) do
            for _, unit in ipairs(grp:getUnits() or {}) do
                if unit:getPlayerName() and not ATC.state.aircraft[unit:getName()] then
                    local gid = grp:getID()
                    ATC.getOrCreateRecord(unit:getName(), gid)
                    ATC.state.aircraft[unit:getName()].phase =
                        unit:inAir() and "airborne" or "parked"
                    ATC.buildMenu(unit:getName())
                end
            end
        end
    end

    -- ── Part 2 hook: glideslope / spacing checks ─────────────
    -- ATC.checkGlideslopes()   ← will be implemented in Part 2
    -- ATC.checkSpacing()       ← will be implemented in Part 2

    return time + ATC.schedulerInterval  -- reschedule
end

-- Start the scheduler 5 seconds after mission begins
timer.scheduleFunction(ATC.schedulerTick, nil, timer.getTime() + 5)


-- ============================================================
-- 8.  INIT  –  startup message (visible in DCS scripting log)
-- ============================================================
env.info("===========================================")
env.info(" ATC_Script.lua  loaded successfully.")
env.info(" Airfield  : " .. ATC.config.airfieldName)
env.info(" Runway    : " .. ATC.config.activeRunway ..
         "  HDG " .. ATC.config.rwyHeadingDeg)
env.info(" ATC call  : " .. ATC.config.atcCallsign)
env.info("===========================================")
