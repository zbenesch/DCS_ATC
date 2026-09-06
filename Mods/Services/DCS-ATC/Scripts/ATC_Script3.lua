
ATC = ATC or {}
ATC.state = ATC.state or { aircraft = {}, airfields = {}, telemetry = {} }
local _runwaySnapshot = ATC.runways  -- watchdog snapshot for this chunk

-- Constants used by pattern / glideslope logic in this chunk
local ENTRY_BASE_AGL     = 4500   -- altitude AGL for entry / base leg
local FINAL_AGL          = 1500   -- altitude AGL at the final approach point
local PATTERN_CORNER_NM  = 2.0    -- within this NM of a CRP corner: advance to next
local PATTERN_CORNER1_NM = 2.5    -- larger capture only for CRP seq1 to avoid conflicting vectors near entry
local PATTERN_CP5_NM     = 0.5    -- CP5 zone radius 
local PATTERN_CP5_MIN_RWY_NM = 1.5 -- minimum CP5 distance from runway/airbase reference
local PATTERN_FINAL_ALT  = 1500   -- ft AGL; -> turn final
local HOLD_MAX_LEVELS_ABOVE = 3   -- extra 1000 ft stack levels allowed above the
                                  -- top of the pattern ladder before it is capped

-- Helper functions shared with ATC_Script2 (duplicated here so this chunk is self-contained)
local function hdgTo(a, b)
    local h = math.deg(math.atan2(b.z - a.z, b.x - a.x))
    return (h < 0) and (h + 360) or h
end

local function angleDiff(a, b)
    return ((b - a + 540) % 360) - 180
end

local function controllerCall(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = (unit and unit:getCallsign()) or unitName or "Unknown"
    local field = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName or "Airfield"
    local ctrl  = controller or "Tower"
    return string.format("%s, %s %s, ", cs, field, ctrl)
end

local function startupScanPlayers()
    local found = 0
    local built = 0
    for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
        for _, u in ipairs(coalition.getPlayers(side) or {}) do
            if u and u:isExist() then
                found = found + 1
                local uName = u:getName()
                local grp   = u:getGroup()
                if grp then
                    local rec = ATC.state.aircraft[uName]
                    if not rec or not rec.menuRoot then
                        ATC.getOrCreateRecord(uName, grp:getID())
                        ATC.buildFullMenu(uName)
                        ATC.log("INIT  menu built for " .. uName)
                        built = built + 1
                    end
                    -- The "already has a menu" case is the steady state and was
                    -- logged every 15 s per player. Silence is the correct
                    -- report for "nothing to do".
                else
                    ATC.logChange("nogroup|" .. uName, "INIT  no group for " .. uName)
                end
            end
        end
    end
    ATC.logChange("scan", string.format("INIT  startupScan  found=%d  built=%d", found, built))
    if found > 0 and not ATC._notificationShown then
        ATC._notificationShown = true
        trigger.action.outText("[DCS-ATC] Ready -> F10 -> Other -> ATC", 20)
    end
end
function ATC.retryAddMenus(_, t)
    startupScanPlayers()
    return t + 15
end
local function updateAircraftTelemetry(unitName, unit, now)
    if not unitName or not unit or not unit:isExist() then return end
    ATC.state.telemetry = ATC.state.telemetry or {}
    local pos = unit:getPoint()
    local headingDeg = nil
    local vel = unit:getVelocity()
    if vel then
        headingDeg = math.deg(math.atan2(vel.z, vel.x))
        if headingDeg < 0 then headingDeg = headingDeg + 360 end
    end
    local aoaDeg = nil
    if unit.getAngleOfAttack then
        local ok, aoa = pcall(function() return unit:getAngleOfAttack() end)
        if ok and type(aoa) == "number" then
            if math.abs(aoa) <= (2 * math.pi + 0.001) then
                aoaDeg = math.deg(aoa)
            else
                aoaDeg = aoa
            end
        end
    end
    local radios = {}
    if ATC.getRadioFrequencies then
        local radioData = ATC.getRadioFrequencies(unitName)
        if radioData then
            for radioIdx, mhz in pairs(radioData) do
                radios[radioIdx] = mhz
            end
        end
    end
    ATC.state.telemetry[unitName] = {
        t = now,
        posX = pos and pos.x or nil,
        posY = pos and pos.y or nil,
        posZ = pos and pos.z or nil,
        headingDeg = headingDeg,
        altAglFt = ATC.getAltAglFt and ATC.getAltAglFt(unit) or nil,
        speedKt = ATC.getSpeedKt and ATC.getSpeedKt(unit) or nil,
        aoaDeg = aoaDeg,
        radios = radios,  -- [radioIndex] = mhz (up to 4 radios)
    }
end

function ATC.updateAllAircraftTelemetry(now)
    local tNow = now or timer.getTime()
    for unitName, _ in pairs(ATC.state.aircraft) do
        local unit = Unit.getByName(unitName)
        if unit and ATC.isPlayer(unit) then
            updateAircraftTelemetry(unitName, unit, tNow)
        elseif ATC.state.telemetry then
            ATC.state.telemetry[unitName] = nil
        end
    end
end
local function runVectoring(_, t)
    if (not ATC.runways or next(ATC.runways) == nil) and _runwaySnapshot then
        ATC.runways = _runwaySnapshot
        ATC.log("WARN  ATC.runways restored in runVectoring at t=" .. tostring(t))
    end
    local okTelem, errTelem = pcall(ATC.updateAllAircraftTelemetry, t)
    if not okTelem then
        trigger.action.outText("[DCS-ATC] telemetry update ERROR: " .. tostring(errTelem), 30)
    end
    local ok, err = pcall(ATC.checkVectoring)
    if not ok then
        trigger.action.outText("[DCS-ATC] checkVectoring ERROR: " .. tostring(err), 30)
    end
    local okMenus, errMenus = pcall(ATC.refreshArrivalMenus)
    if not okMenus then
        trigger.action.outText("[DCS-ATC] refreshArrivalMenus ERROR: " .. tostring(errMenus), 30)
    end
    return t + 1
end
local function runGlideslopes(_, t)
    if (not ATC.runways or next(ATC.runways) == nil) and _runwaySnapshot then
        ATC.runways = _runwaySnapshot
        ATC.log("WARN  ATC.runways was NIL at t=" .. tostring(t) .. " -> restored from snapshot")
    end
    local ok, err = pcall(ATC.checkGlideslopes)
    if not ok then
        trigger.action.outText("[DCS-ATC] checkGlideslopes ERROR: " .. tostring(err), 30)
    end
    return t + ATC.config.guidanceInterval
end
function ATC.onSimStart()
    if ATC._timersStarted then return end
    if ATC.runways and next(ATC.runways) ~= nil then
        _runwaySnapshot = ATC.runways
    end
    ATC._timersStarted = true
    local function clearUnitStateSilent(unitName, why)
        if not unitName or unitName == "" then return end
        local rec = ATC.state.aircraft[unitName]
        if not rec then return end
        ATC.log(string.format("EVNT  %s -> clear ATC state for unit=%s", tostring(why or "unknown"), unitName))
        ATC.removeRecord(unitName)
    end
    world.addEventHandler({
        onEvent = function(self, event)
            if not event then return end
            local ev = world.event or {}
            local id = event.id
            local unit = event.initiator
            local uName = unit and unit:getName() or nil

            if id == ev.S_EVENT_BIRTH then
                if not unit or not unit:isExist() then return end
                local pName = unit:getPlayerName()
                if not pName or pName == "" then return end
                local grp = unit:getGroup()
                if not grp then return end
                ATC.log("EVNT  S_EVENT_BIRTH player=" .. pName .. " unit=" .. uName)
                ATC.getOrCreateRecord(uName, grp:getID())
                ATC.buildFullMenu(uName)
                return
            end

            -- Runway occupancy. Only tracked players matter here; ignoring
            -- everything else keeps AI movements from creating field state.
            if id == ev.S_EVENT_TAKEOFF or id == ev.S_EVENT_LAND then
                if not uName or not ATC.state.aircraft[uName] then return end
                local abName = nil
                if event.place and event.place.getName then
                    local ok, n = pcall(function() return event.place:getName() end)
                    if ok then abName = n end
                end
                -- event.place is absent for some airfield/ship cases; fall back
                -- to whichever field the player is engaged with.
                abName = abName or ATC.state.aircraft[uName].engagedField
                if not abName then return end
                if id == ev.S_EVENT_TAKEOFF then
                    ATC.onDepartedRunway(uName, abName)
                else
                    ATC.onTouchdown(uName, abName)
                end
                return
            end

            if id == ev.S_EVENT_CRASH
               or id == ev.S_EVENT_DEAD
               or id == ev.S_EVENT_PILOT_DEAD
               or id == ev.S_EVENT_EJECTION
               or id == ev.S_EVENT_PLAYER_LEAVE_UNIT then
                clearUnitStateSilent(uName, id)
                return
            end

            if id == ev.S_EVENT_PLAYER_ENTER_UNIT then
                if not unit or not unit:isExist() then return end
                local pName = unit:getPlayerName()
                if not pName or pName == "" then return end
                local grp = unit:getGroup()
                if not grp then return end
                clearUnitStateSilent(uName, "re-enter")
                ATC.log("EVNT  S_EVENT_PLAYER_ENTER_UNIT player=" .. pName .. " unit=" .. uName)
                ATC.getOrCreateRecord(uName, grp:getID())
                ATC.buildFullMenu(uName)
                return
            end
        end
    })
    local t0 = timer.getTime()
    timer.scheduleFunction(function() startupScanPlayers(); return nil end, nil, t0 + 3)
    timer.scheduleFunction(function() startupScanPlayers(); return nil end, nil, t0 + 10)
    timer.scheduleFunction(ATC.retryAddMenus, {}, t0 + 5)
    -- Start the telemetry/vectoring loop promptly. It used to begin at t0+10,
    -- which left ATC.state.telemetry empty for the first ten seconds -- long
    -- enough for a player to call inbound before any radio data existed.
    timer.scheduleFunction(runVectoring,   nil, t0 + 2)
    timer.scheduleFunction(runGlideslopes, nil, t0 + 10)
end
local function ensureGuidanceTables(rec, abName)
    if not rec.lastGuidance then rec.lastGuidance = {} end
    if not rec.lastGSDev    then rec.lastGSDev    = {} end
    if not rec.gearReminded then rec.gearReminded = {} end
    if not rec.handedOffToTower then rec.handedOffToTower = {} end
    if not rec.patternAdv   then rec.patternAdv   = {} end
end

-- Point-in-polygon for the runway rectangle.
-- pos      : Vec3 from unit:getPoint()  (pos.x = northing, pos.z = easting)
-- rwyVerts : {x=northing, y=easting}[] corners from rwy.rwy config
local function pointInRwy(pos, rwyVerts)
    local px, py = pos.x, pos.z
    local n = #rwyVerts
    local inside = false
    local j = n
    for i = 1, n do
        local xi, yi = rwyVerts[i].x, rwyVerts[i].y
        local xj, yj = rwyVerts[j].x, rwyVerts[j].y
        if ((yi > py) ~= (yj > py)) and
           (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- True only when an aircraft is genuinely tracking the runway on the final
-- approach course.
--
-- getPatternLeg's "final" is a +/-30 degree bearing SECTOR, which is +/-3.7 NM
-- wide at 7.4 NM -- wide enough that ordinary circuit legs pass straight
-- through it. That is why traffic was being released and handed to tower while
-- still being vectored to CRP2. This instead tests an absolute corridor around
-- the extended centreline, which does not widen with range, plus the aircraft's
-- actual track and vertical trend. At Batumi the circuit CRPs sit 2.5-5.3 NM
-- off the centreline and are comfortably excluded by a 1.5 NM corridor.
local function isEstablishedOnFinal(unit, abPos, rwy, abName, distNM)
    if not unit or not abPos or not rwy or not distNM then return false end
    if distNM > (ATC.config.finalEstablishNM or 8) then return false end
    local uPos = unit:getPoint()
    local vel  = unit:getVelocity()
    if not uPos or not vel then return false end

    local finalTrue = ATC.toTrue(ATC.getActiveRwyHdg(abName) or rwy.hdg)

    -- Must be on the approach side of the field, inside a fixed-width corridor
    -- around the extended centreline.
    local offAxisDeg = angleDiff((finalTrue + 180) % 360, ATC.getBearing(abPos, uPos))
    if math.abs(offAxisDeg) > 90 then return false end   -- past the departure end
    local lateralNM = math.abs(distNM * math.sin(math.rad(offAxisDeg)))
    if lateralNM > (ATC.config.finalCorridorNM or 1.5) then return false end

    -- Must actually be flying the approach course, not merely crossing it.
    local gsMs = math.sqrt(vel.x * vel.x + vel.z * vel.z)
    if gsMs < 15 then return false end
    local acHdg = math.deg(math.atan2(vel.z, vel.x)) % 360
    if math.abs(angleDiff(finalTrue, acHdg)) > (ATC.config.finalHdgTolDeg or 25) then
        return false
    end

    -- And must not be climbing away: separates an approach from a go-around or
    -- a departure that happens to be lined up with the runway.
    if vel.y and vel.y > (ATC.config.finalMaxClimbMs or 3) then return false end
    return true
end

function ATC.checkGlideslopes()
    local now = timer.getTime()
    local autoVacate = {}   -- collect here; fire after loops to avoid mutating landingSeq mid-iteration
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
                    local fieldName = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(abName) or abName
                    local distNM = ATC.distUnitToBase(unit, ab)
                    if distNM and distNM <= ATC.config.finalNM then
                        local cs     = unit:getCallsign() or ""
                        local spdKt  = ATC.getSpeedKt(unit)
                        local altFt  = ATC.getAltFt(unit)
                        local spds   = ATC.getApproachSpeeds(unit)
                        rec.finalCleared = rec.finalCleared or {}
                        rec.gearReminded = rec.gearReminded or {}
                            local lastT  = rec.lastGuidance[abName] or 0
                            local rwy = ATC.getRunway(abName)
                            local leg = (rwy and ATC.getPatternLeg(unit:getPoint(), abPos, rwy, abName)) or nil
                            local finalLeg = (leg == "final" or leg == "short_final")
                            local patternEntryLeg = (leg == "initial" or leg == "downwind")
                            local onFinal = finalLeg and distNM <= 8
                            local onPatternEntry = patternEntryLeg and distNM <= 10 -- 10 NM default for pattern entry
                            local controller = (onFinal or onPatternEntry) and "Tower" or "Approach"
                            -- An aircraft established on final has left the CRP circuit, whether
                            -- or not it ever captured a corner. patternAlt is otherwise cleared
                            -- only at CP5, and it latches off this handoff, the pattern
                            -- advisories and towerHandoffReady -- so a pilot flying a straight-in
                            -- had no route to a landing clearance at all.
                            --
                            -- The test is isEstablishedOnFinal, NOT onFinal. onFinal is a wide
                            -- bearing sector that circuit legs pass through, which handed traffic
                            -- to tower while it was still being vectored to CRP2.
                            local establishedFinal = (ph ~= "goaround")
                                and isEstablishedOnFinal(unit, abPos, rwy, abName, distNM)
                            -- Captured before the release below, so the downwind branch can still
                            -- tell whether the CRP sequence owns this aircraft.
                            local inCrpPattern = rec.patternAlt and rec.patternAlt[abName]
                            if establishedFinal and inCrpPattern then
                                ATC.releasePatternHold(unitName, rec, abName)
                                inCrpPattern = nil
                                ATC.log(string.format(
                                    "PATREL %-10s @%s  established on final at %.1f NM -> released from CRP circuit",
                                    unitName, abName, distNM))
                            end
                            if (establishedFinal or (onPatternEntry and not inCrpPattern))
                               and not rec.handedOffToTower[abName] then
                                local towerFreq = rwy and rwy.frequencies and rwy.frequencies.tower
                                local freqStr = towerFreq and (towerFreq.mhz .. " MHz") or "Tower frequency"
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sContact %s Tower on %s.\n" ..
                                    "%.1f NM from threshold.",
                                    controllerCall(unitName, abName, "Approach"), fieldName, freqStr, distNM),
                                    false, abName, "Approach")
                                rec.handedOffToTower[abName] = true
                                -- Open the tower dialogue so the pilot can actually request
                                -- landing. Only advancePatternCorner did this before, at CP5.
                                rec.towerHandoffReady = rec.towerHandoffReady or {}
                                rec.towerCheckedIn    = rec.towerCheckedIn    or {}
                                rec.towerHandoffReady[abName] = true
                                if rec.towerCheckedIn[abName] == nil then
                                    rec.towerCheckedIn[abName] = false
                                end
                                ATC.log(string.format("HANDOFF %-10s @%s  tower dialogue open at %.1f NM",
                                    unitName, abName, distNM))
                                ATC.buildFullMenu(unitName)
                            end
                        local cleared = rec.landingCleared and rec.landingCleared[abName]
                        -- Low-speed go-around call.
                        --
                        -- unit:inAir() flickers during rollout and on a bounce, which
                        -- fired "airspeed critically low" at an aircraft that had already
                        -- landed and was simply slowing down. Require real height above
                        -- the ground as well, and never call it once touched down.
                        --
                        -- The threshold is also per-type rather than a flat 80 kt:
                        -- helicopters approach at 50-70, so a global 80 was permanently
                        -- below Vref for them. Only ever lowered, never raised, so fast
                        -- movers keep the existing behaviour.
                        local stallKt = ATC.config.stallWarnKt or 80
                        if spds and spds.final then
                            stallKt = math.min(stallKt, math.floor(spds.final * 0.85))
                        end
                        local aglFt = ATC.getAltAglFt(unit)
                        local airborne = unit:inAir() and aglFt
                            and aglFt > (ATC.config.stallWarnMinAglFt or 100)
                        local slowGa = rec.lastGoAround and rec.lastGoAround[abName] or 0
                        if ph ~= "landing" and ph ~= "goaround" and airborne
                           and spdKt and spdKt < stallKt and (now - slowGa) >= 90 then
                            ATC.radioMsg(rec.groupId, abPos, string.format(
                                "%sgo around, go around!\n"                ..
                                "Airspeed critically low:  %d kt.\n"       ..
                                "Climb immediately, runway heading.",
                                controllerCall(unitName, abName, controller), spdKt), true, abName, controller)
                            ATC.log(string.format(
                                "GOARND %-10s @%s  low speed %d kt (< %d) at %d ft AGL",
                                tostring(unitName), tostring(abName), spdKt, stallKt, aglFt or -1))
                            rec.lastGoAround = rec.lastGoAround or {}
                            rec.lastGoAround[abName] = now
                            ATC.setPhase(unitName, abName, "goaround")
                            rec.lastGuidance[abName] = now
                        elseif ph ~= "goaround" and cleared and finalLeg and distNM <= 2
                               and spdKt and spds and spdKt > spds.maxFinal then
                            rec.lastGoAround = rec.lastGoAround or {}
                            local lastGa = rec.lastGoAround[abName] or 0
                            if (now - lastGa) >= 90 then
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sgo around, go around!\n"          ..
                                    "Excessive speed on final: %d kt.\n" ..
                                    "Climb immediately, runway heading.",
                                    controllerCall(unitName, abName, controller), spdKt),
                                    true, abName, controller)
                                rec.lastGoAround[abName] = now
                                ATC.setPhase(unitName, abName, "goaround")
                                rec.lastGuidance[abName] = now
                            end
                        elseif ph ~= "goaround" and (now - lastT) >= ATC.config.guidanceInterval then
                            if cleared and onFinal and distNM <= (ATC.config.gsMonitorNM or 5) then
                                local gs = ATC.getGlideslope(unit, abPos, rwy)
                                local speedDev = math.abs(gs.speedDev or 0)
                                local aoaDev = math.abs(gs.aoaDev or 0)
                                local altDev = math.abs(gs.altDev or 0)
                                local maxDev = math.max(speedDev, aoaDev, altDev)
                                if maxDev > (ATC.config.gsGoAroundDev or 3.0) then
                                    rec.lastGoAround = rec.lastGoAround or {}
                                    local lastGa = rec.lastGoAround[abName] or 0
                                    if (now - lastGa) >= 90 then
                                        ATC.radioMsg(rec.groupId, abPos, "Missed approach, go around!", false, abName, controller)
                                        rec.lastGoAround[abName] = now
                                        ATC.setPhase(unitName, abName, "goaround")
                                        rec.lastGuidance[abName] = now
                                    end
                                elseif maxDev > (ATC.config.gsAdviseDev or 1.5) then
                                    ATC.radioMsg(rec.groupId, abPos, "Correct your approach: deviation from glideslope.", false, abName, controller)
                                    rec.lastGuidance[abName] = now
                                end
                            end
                            if cleared and onFinal and distNM <= 2 and not rec.finalCleared[abName] then
                                if ATC.isRunwayClear(abName, unitName) then
                                    local windDir, windSpd = ATC.getWind(abPos)
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%s, %s tower, cleared to land, wind %03d at %d, check gear down.",
                                        cs, fieldName, windDir, windSpd),
                                        false, abName, controller)
                                    rec.finalCleared[abName] = true
                                    rec.lastGuidance[abName] = now
                                    ATC.log(string.format(
                                        "CLEAR %-10s @%s  cleared to land on short final (%.1f NM)",
                                        tostring(unitName), tostring(abName), distNM))
                                else
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%s, %s tower, runway occupied, return to pattern and await clearance.",
                                        cs, fieldName),
                                        false, abName, controller)
                                    rec.lastGuidance[abName] = now
                                    ATC.log(string.format(
                                        "HOLD  %-10s @%s  sent around at %.1f NM: runway occupied",
                                        tostring(unitName), tostring(abName), distNM))
                                end
                            elseif cleared and onFinal and distNM <= 5 and not rec.gearReminded[abName] then
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sslow to approach speed, %d kt.\n"   ..
                                    "Check gear down and locked.  %.1f NM.",
                                    controllerCall(unitName, abName, controller),
                                    spds.final, distNM),
                                    false, abName, controller)
                                rec.gearReminded[abName] = true
                                rec.lastGuidance[abName] = now
                                ATC.log(string.format("GEAR  %-10s @%s  gear/speed reminder at %.1f NM (Vref %d kt)",
                                    tostring(unitName), tostring(abName), distNM, spds.final))
                            elseif cleared and finalLeg and distNM <= 4 and spdKt and spdKt > spds.maxFinal then
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sreduce speed to %d kt.\n"              ..
                                    "You are at %d kt  (%.1f NM, %s ft).",
                                    controllerCall(unitName, abName, controller),
                                    spds.final, spdKt,
                                    distNM, altFt and tostring(altFt) or "unknown"),
                                    false, abName, controller)
                                rec.lastGuidance[abName] = now
                            end  -- if/elseif gear-speed checks
                        end  -- elseif rate_limit
                        local inHold = rec.holdPhase and rec.holdPhase[abName]
                        local rwy = ATC.runways and ATC.runways[abName]
                        if rwy and not inHold and not (rec.patternAlt and rec.patternAlt[abName]) then
                            local legs = ATC.getPatternLegs(rwy, abName)
                            local vel  = unit:getVelocity()
                            local acHdg = nil
                            if vel then
                                acHdg = math.deg(math.atan2(vel.z, vel.x))
                                if acHdg < 0 then acHdg = acHdg + 360 end
                            end
                            if legs and acHdg then
                                if not rec.patternAdv then rec.patternAdv = {} end
                                local prevAdv    = rec.patternAdv[abName]
                                local activeHdg  = ATC.getActiveRwyHdg(abName) or rwy.hdg
                                local rwyNum     = ATC.rwyDesignator(activeHdg)
                                local trafficDir = (legs.dir == "R") and "right" or "left"
                                local elev       = rwy.elevation or 0
                                local entryAlt   = elev + ENTRY_BASE_AGL   -- 3000 AGL (downwind/base)
                                local finalApproachAlt = elev + FINAL_AGL  -- 2000 AGL (final approach)
                                if math.abs(angleDiff(acHdg, legs.finalHdg)) <= 20
                                and distNM <= 8 and prevAdv ~= "final" then
                                    rec.patternAdv[abName] = "final"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%sestablished on final, runway %s.\nContinue approach.",
                                        controllerCall(unitName, abName, "Tower"), rwyNum), false, abName, "Tower")
                                elseif math.abs(angleDiff(acHdg, legs.baseHdg)) <= 25
                                and distNM <= 10
                                and prevAdv ~= "base" and prevAdv ~= "final" then
                                    rec.patternAdv[abName] = "base"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%son base, runway %s.\nTurn final heading %s.  Descend to %d ft.",
                                        controllerCall(unitName, abName, "Tower"),
                                        rwyNum, ATC.fmtHdg(ATC.toMag(legs.finalHdg)), finalApproachAlt), false, abName, "Tower")
                                elseif math.abs(angleDiff(acHdg, legs.downwindHdg)) <= 30
                                and distNM <= 15 and distNM > 5 and prevAdv == nil then
                                    rec.patternAdv[abName] = "downwind"
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%sabeam the threshold, runway %s, %s traffic.\nDescend to %d ft.  Base heading %s.",
                                        controllerCall(unitName, abName, "Approach"),
                                        rwyNum, trafficDir, entryAlt,
                                        ATC.fmtHdg(ATC.toMag(legs.baseHdg))), false, abName, "Approach")
                                end
                            end
                        end
                    end
                    -- Auto landing detection: cleared, on ground, < 50 kt, inside runway polygon
                    local rwyDef = ATC.runways and ATC.runways[abName]
                    if rwyDef and rwyDef.rwy
                    and (rec.landingCleared and rec.landingCleared[abName])
                    and not unit:inAir()
                    and (ATC.getSpeedKt(unit) or 999) < 50
                    and pointInRwy(unit:getPoint(), rwyDef.rwy) then
                        table.insert(autoVacate, { unitName = unitName, airbaseName = abName })
                    end
                end -- if ab and rwy
            end -- if not abName / else
        end
    end
    for _, av in ipairs(autoVacate) do
        ATC.log(string.format("AUTO-VACATE %s @%s", av.unitName, av.airbaseName))
        ATC.onVacatingRunway(av)
    end
end
function ATC.getPatternLegs(rwy, abName)
    if not rwy then return nil end
    -- All headings are TRUE north so they can be compared directly with
    -- aircraft velocity headings (which DCS also reports in true north).
    -- Use ATC.toMag() when voicing to the pilot.
    local activeHdg, isRecip = ATC.getActiveRwyHdg(abName)
    local finalMag  = activeHdg or rwy.hdg
    local finalHdg  = ATC.toTrue(finalMag)
    local downHdg   = (finalHdg + 180) % 360
    -- patternDir describes the normal (primary) circuit; flip for reciprocal
    local dir = rwy.patternDir or "L"
    if isRecip then dir = (dir == "R") and "L" or "R" end
    local offset    = (dir == "R") and 90 or -90
    local baseHdg   = (downHdg + offset + 360) % 360
    return { finalHdg = finalHdg, baseHdg = baseHdg, downwindHdg = downHdg, dir = dir }
end

local function enforceCp5MinDistance(cp5Pos, runwayPos, rwy)
    if not cp5Pos or not runwayPos then return cp5Pos end
    local minM = PATTERN_CP5_MIN_RWY_NM * 1852
    local dx = cp5Pos.x - runwayPos.x
    local dz = cp5Pos.z - runwayPos.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist >= minM then return cp5Pos end

    local ux, uz
    if dist > 1 then
        ux = dx / dist
        uz = dz / dist
    else
        local finalTrue = ATC.toTrue((rwy and rwy.hdg) or 0)
        local rad = math.rad(finalTrue)
        ux = -math.cos(rad)
        uz = -math.sin(rad)
    end

    return {
        x = runwayPos.x + ux * minM,
        y = cp5Pos.y,
        z = runwayPos.z + uz * minM,
    }
end

function ATC.getPatternCorners(rwy, abName)
    if not rwy or not rwy.crps then return nil end

    -- Resolve abName if not supplied (legacy callers)
    if not abName and ATC.runways then
        for n, rr in pairs(ATC.runways) do
            if rr == rwy then abName = n; break end
        end
    end

    -- Build a lookup table: seq -> CRP definition
    local bySeq = {}
    for _, crp in ipairs(rwy.crps) do
        local p = nil
        if type(crp.x) == "number" and type(crp.y) == "number" then
            p = { x = crp.x, y = 0, z = crp.y }
        elseif type(crp.lat) == "number" and type(crp.lon) == "number" then
            p = coord.LLtoLO(crp.lat, crp.lon, 0)
        end
        if p then
            bySeq[crp.seq or 99] = { pos = p, name = crp.name, seq = crp.seq or 99, radius = crp.radius }
        end
    end

    local _, isRecip = ATC.getActiveRwyHdg(abName)
    local airbasePos = nil
    if Airbase and Airbase.getByName and abName then
        local ab = Airbase.getByName(abName)
        if ab then airbasePos = ATC.getAirbasePos(ab) end
    end

    -- Reciprocal runway: CRP1 → CRP4 → CRP3 → CRP6 (CRP6 acts as final approach point)
    if isRecip and bySeq[6] then
        local c6 = bySeq[6]
        c6.isCP5 = true
        c6.name  = c6.name or "Final approach point"
        c6.pos   = enforceCp5MinDistance(c6.pos, airbasePos, rwy)
        local corners = {}
        for _, seq in ipairs({ 1, 4, 3, 6 }) do
            if bySeq[seq] then table.insert(corners, bySeq[seq]) end
        end
        -- Altitude must follow position along the route, not the CRP number.
        -- This order visits CRP4 before CRP3, and the seq-keyed profile would
        -- step 4500 -> 2000 -> 2500, i.e. descend and then climb again.
        -- altSeq gives a monotonic 4500 -> 3500 -> 2500 -> 1500 instead.
        for i, c in ipairs(corners) do
            c.altSeq = (i == #corners) and 5 or i
        end
        return corners
    end

    -- Normal runway: sort by seq, use seq 1–5 as before
    local corners = {}
    for _, c in pairs(bySeq) do table.insert(corners, c) end
    table.sort(corners, function(a, b) return a.seq < b.seq end)

    if #corners >= 4 then
        local hasExplicitCP5 = false
        for _, c in ipairs(corners) do
            if c.seq == 5 then
                c.isCP5 = true
                if not c.name or c.name == "" then
                    c.name = "Final approach point"
                end
                c.pos = enforceCp5MinDistance(c.pos, airbasePos, rwy)
                hasExplicitCP5 = true
            end
        end
        if hasExplicitCP5 then
            -- Discard seq > 5 (including CRP6)
            local filtered = {}
            for _, c in ipairs(corners) do
                if (tonumber(c.seq) or 99) <= 5 then table.insert(filtered, c) end
            end
            return filtered
        end

        local c4 = corners[4]

        local centerPos = nil
        do
            local sx, sz, n = 0, 0, 0
            for i = 1, math.min(4, #corners) do
                local cp = corners[i] and corners[i].pos
                if cp then
                    sx = sx + cp.x
                    sz = sz + cp.z
                    n = n + 1
                end
            end
            if n > 0 then
                centerPos = {
                    x = sx / n,
                    y = (airbasePos and airbasePos.y) or 0,
                    z = sz / n,
                }
            end
        end
        local centerAnchor = centerPos or airbasePos
        if type(rwy.cp5CenterLat) == "number" and type(rwy.cp5CenterLon) == "number" then
            local ok, p = pcall(coord.LLtoLO, rwy.cp5CenterLat, rwy.cp5CenterLon, 0)
            if ok and p then
                centerAnchor = {
                    x = p.x,
                    y = (airbasePos and airbasePos.y) or p.y or 0,
                    z = p.z,
                }
            end
        end

        if c4 and c4.pos and centerAnchor then
            local finalTrue = ATC.toTrue(rwy.hdg or 0)
            local rad = math.rad(finalTrue)
            local ux, uz = math.cos(rad), math.sin(rad)
            local vx = c4.pos.x - centerAnchor.x
            local vz = c4.pos.z - centerAnchor.z
            local t = (vx * ux) + (vz * uz)
            local cp5Pos = {
                x = centerAnchor.x + t * ux,
                y = centerAnchor.y,
                z = centerAnchor.z + t * uz,
            }
            cp5Pos = enforceCp5MinDistance(cp5Pos, airbasePos, rwy)
            local cp5 = {
                pos = cp5Pos,
                name = "Final approach point",
                seq = 5,
                isCP5 = true,
            }
            table.insert(corners, cp5)
        end
    end
    return corners
end
function ATC.nearestCornerIdx(corners, uPos)
    local bestIdx, bestD2 = 1, math.huge
    for i, c in ipairs(corners) do
        local dx = c.pos.x - uPos.x
        local dz = c.pos.z - uPos.z
        local d2 = dx * dx + dz * dz
        if d2 < bestD2 then bestIdx, bestD2 = i, d2 end
    end
    return bestIdx
end
function ATC.assignPatternSlot(unitName, abName)
    local fs   = ATC.getFieldState(abName)
    local rwy  = ATC.getRunway(abName)
    local elev = (rwy and rwy.elevation) or 0
    -- Every other altitude in the system is MSL (getPatternFloorAlt returns
    -- elevation + AGL). The built-in ladder mirrors the CRP1..CRP5 AGL profile,
    -- so it needs the field elevation added or a slot at a high-elevation field
    -- lands below the CRP it is supposed to be flying. rwy.patternAlts, when an
    -- airfield supplies one, is taken as already-MSL.
    local alts = rwy and rwy.patternAlts
    if not alts then
        alts = {}
        for i, agl in ipairs({ 4500, 3500, 2500, 1500 }) do
            alts[i] = math.ceil((elev + agl) / 100) * 100
        end
    end
    local floorAlt = alts[#alts] or (elev + PATTERN_FINAL_ALT)
    local topAlt   = alts[1] or (floorAlt + 3000)
    fs.patternSlots = fs.patternSlots or {}
    local highestOccupied = nil
    for otherName, otherRec in pairs(ATC.state.aircraft) do
        if otherName ~= unitName then
            local otherAlt = nil
            if otherRec.patternAlt and otherRec.patternAlt[abName] then
                otherAlt = otherRec.patternAlt[abName]
            else
                local phase = ATC.getPhase(otherName, abName)
                if (otherRec.landingCleared and otherRec.landingCleared[abName])
                   or phase == "approach" or phase == "final" or phase == "landing" then
                    otherAlt = floorAlt
                end
            end
            if otherAlt then
                highestOccupied = highestOccupied and math.max(highestOccupied, otherAlt) or otherAlt
            end
        end
    end
    -- Stack above the highest occupant, but do not climb forever: cap the stack
    -- a few levels above the published top of the ladder.
    local slotAlt = highestOccupied and (highestOccupied + 1000) or topAlt
    local ceilAlt = topAlt + (HOLD_MAX_LEVELS_ABOVE * 1000)
    if slotAlt > ceilAlt then slotAlt = ceilAlt end
    fs.patternSlots[unitName] = slotAlt
    return slotAlt
end
function ATC.freePatternSlot(unitName, abName)
    local fs = ATC.state.airfields[abName]
    if fs and fs.patternSlots then fs.patternSlots[unitName] = nil end
end
-- Releases an aircraft from the CRP circuit: clears the pattern-altitude latch,
-- the corner index and the stack slot.
--
-- rec.patternAlt gates the tower handoff, the pattern advisories and
-- towerHandoffReady, so it must have more than one way out. This is the single
-- exit: used at CP5, and when an aircraft turns up established on final without
-- having flown the circuit at all.
function ATC.releasePatternHold(unitName, rec, abName)
    rec = rec or ATC.state.aircraft[unitName]
    if not rec then return end
    if rec.patternAlt       then rec.patternAlt[abName]       = nil end
    if rec.patternCornerIdx then rec.patternCornerIdx[abName] = nil end
    if rec.lastCornerDist   then rec.lastCornerDist[abName]   = nil end
    ATC.freePatternSlot(unitName, abName)
end
function ATC.freeStackLevel(unitName, abName)
    ATC.freePatternSlot(unitName, abName)
    local fs = ATC.state.airfields[abName]
    if fs and fs.holdStack then fs.holdStack[unitName] = nil end
end
local function getPatternFloorAlt(rwy, crp)
    -- CRP altitude profile (AGL above field elevation, rounded up to nearest 100 ft):
    -- CRP1: field elevation + 4500 ft
    -- CRP2: field elevation + 3500 ft
    -- CRP3: field elevation + 2500 ft
    -- CRP4: field elevation + 2000 ft
    -- CRP5: field elevation + 1500 ft  (final approach point)
    -- Uses rwy.elevation (already in feet) so the profile is a smooth monotonic
    -- descent independent of terrain under each CRP.
    -- altSeq, when present, is the aircraft's position along the route and wins
    -- over the raw CRP number (see the reciprocal ordering in getPatternCorners).
    if crp and (crp.altSeq or crp.seq) then
        local elevFt = (rwy and rwy.elevation) or 0
        local seq = tonumber(crp.altSeq or crp.seq)
        local agl
        if     seq == 1 then agl = 4500
        elseif seq == 2 then agl = 3500
        elseif seq == 3 then agl = 2500
        elseif seq == 4 then agl = 2000
        elseif seq == 5 then agl = 1500
        elseif seq == 6 then agl = 1500  -- CRP6 = final approach gate (same as CRP5)
        else                  agl = 4500
        end
        return math.ceil((elevFt + agl) / 100) * 100
    end
    local alts = rwy and rwy.patternAlts
    if alts and #alts > 0 then return alts[#alts] end
    return ((rwy and rwy.elevation) or 0) + PATTERN_FINAL_ALT
end

local function getOccupiedPatternAlt(otherName, rec, abName, rwy)
    if not rec then return nil end
    if rec.patternAlt and rec.patternAlt[abName] then
        return rec.patternAlt[abName]
    end
    local phase = ATC.getPhase(otherName, abName)
    if (rec.landingCleared and rec.landingCleared[abName])
       or phase == "approach" or phase == "final" or phase == "landing" then
        return getPatternFloorAlt(rwy)
    end
    return nil
end

local function getProtectedPatternAlt(unitName, abName, currentAlt, rwy)
    -- Returns the minimum altitude this unit should be assigned to maintain
    -- 1000 ft vertical separation from the highest aircraft below it.
    -- Returns 0 when no other aircraft are in the pattern below, so the caller
    -- can freely descend to the next CRP target.
    local highestBelow = nil
    for otherName, otherRec in pairs(ATC.state.aircraft) do
        if otherName ~= unitName then
            local otherAlt = getOccupiedPatternAlt(otherName, otherRec, abName, rwy)
            if otherAlt and otherAlt < currentAlt then
                highestBelow = highestBelow and math.max(highestBelow, otherAlt) or otherAlt
            end
        end
    end
    if highestBelow then return highestBelow + 1000 end
    return 0  -- no aircraft below: no altitude protection needed
end

local function setPatternAltitude(unitName, rec, abName, altFt)
    rec.patternAlt[abName] = altFt
    local fs = ATC.getFieldState(abName)
    fs.patternSlots = fs.patternSlots or {}
    fs.patternSlots[unitName] = altFt
end

function ATC.refreshArrivalMenus()
    for unitName, rec in pairs(ATC.state.aircraft) do
        local abName = rec.engagedField
        if abName then
            local unit = Unit.getByName(unitName)
            if unit and ATC.isPlayer(unit) then
                local ph = ATC.getPhase(unitName, abName)
                local arrivalActive = (ph == "inbound" or ph == "approach" or ph == "final"
                    or ph == "goaround" or ph == "landing"
                    or (rec.landingCleared and rec.landingCleared[abName])
                    or (rec.seqNum and rec.seqNum[abName]))
                if arrivalActive then
                    if not rec.postLandingReady then rec.postLandingReady = {} end
                    local landedSlow = (not unit:inAir()) and ((ATC.getSpeedKt(unit) or math.huge) <= 50)
                    if rec.postLandingReady[abName] ~= landedSlow then
                        rec.postLandingReady[abName] = landedSlow
                        ATC.buildFullMenu(unitName)
                    end
                end
            end
        end
    end
end

function ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, targetHdg, now, abName, targetPos, reportPoint)
    local cs      = unit:getCallsign() or ""
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
     local altTol = gate.altFt and math.max(50, gate.altFt * 0.05) or 50
     local altOnTarget = gate.noAltitude or (altFt and gate.altFt and altDiff <= altTol)
    if hdgDiff <= 10
         and altOnTarget
       and (gate.noSpeed or spdDiff <= math.max(10, gate.speedKt * 0.05)) then
        ATC.log(string.format("IVEC  %-10s @%-20s  -> SUPPRESSED (on params)", unitName, abName))
        rec.lastVector[abName] = now
        return
    end
    local uPos   = unit:getPoint()
    local navPos = targetPos or abPos
    local distNM = navPos and ATC.mToNM(ATC.distVec3H(uPos, navPos)) or nil
    local magHdg = ATC.roundHdg(ATC.toMag(targetHdg))
    local hdgPart
    if hdgDiff <= 45 then
        hdgPart = "fly heading " .. ATC.fmtHdg(magHdg)
    elseif angleDiff(currHdg, targetHdg) > 0 then
        hdgPart = "turn RIGHT heading " .. ATC.fmtHdg(magHdg)
    else
        hdgPart = "turn LEFT heading " .. ATC.fmtHdg(magHdg)
    end
    if distNM then
        local distRounded = math.floor(distNM + 0.4)
        if distRounded < 1 then distRounded = 1 end
        hdgPart = hdgPart .. string.format(" for %d miles", distRounded)
    end
    local altPart
    if not gate.noAltitude and gate.altFt then
        local altTolLocal = math.max(50, math.floor(gate.altFt * 0.03))
        if altDiff <= altTolLocal then
            altPart = "maintain " .. gate.altFt .. " ft"
        elseif altFt and altFt > gate.altFt then
            altPart = "descend to " .. gate.altFt .. " ft"
        else
            altPart = "climb to " .. gate.altFt .. " ft"
        end
    else
        altPart = nil
    end
    local ccPrefix = controllerCall(unitName, abName, "Approach")
    local reportPart = ""
    if gate.noSpeed then
        if altPart then
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s, %s.%s", ccPrefix, hdgPart, altPart, reportPart), true, abName, "Approach")
        else
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s.%s", ccPrefix, hdgPart, reportPart), true, abName, "Approach")
        end
    else
        local spdTol = math.max(10, math.floor(gate.speedKt * 0.05))
        local reduceOnly = gate.reduceOnly == true
        local spdPart
        if reduceOnly then
            if currSpd and currSpd > (gate.speedKt + spdTol) then
                spdPart = "reduce speed to " .. gate.speedKt .. " kt"
            elseif currSpd and spdDiff <= spdTol then
                spdPart = "maintain " .. gate.speedKt .. " kt"
            end
        else
            if spdDiff <= spdTol then
                spdPart = "maintain " .. gate.speedKt .. " kt"
            elseif currSpd and currSpd > gate.speedKt then
                spdPart = "reduce speed to " .. gate.speedKt .. " kt"
            else
                spdPart = "increase speed to " .. gate.speedKt .. " kt"
            end
        end
        if spdPart and altPart then
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s, %s, %s.%s", ccPrefix, hdgPart, altPart, spdPart, reportPart), true, abName, "Approach")
        elseif spdPart then
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s, %s.%s", ccPrefix, hdgPart, spdPart, reportPart), true, abName, "Approach")
        elseif altPart then
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s, %s.%s", ccPrefix, hdgPart, altPart, reportPart), true, abName, "Approach")
        else
            ATC.radioMsg(rec.groupId, abPos,
                string.format("%s%s.%s", ccPrefix, hdgPart, reportPart), true, abName, "Approach")
        end
    end
    ATC.log(string.format("VEC   %-10s @%s  hdg %s  %s  %s%s",
        tostring(unitName), tostring(abName), ATC.fmtHdg(magHdg),
        gate.altFt and (tostring(gate.altFt) .. " ft") or "no alt",
        reportPoint and ("-> " .. tostring(reportPoint)) or "-> field",
        distNM and string.format(" (%.1f NM)", distNM) or ""))
    rec.lastVector[abName] = now
end
-- ATC.initPatternEntry was removed. It could never run: onInboundRequest sets
-- rec.patternAlt before scheduling it, and its first guard was an early return
-- on exactly that field. The CRP1 vector it duplicated is built into the
-- inbound reply instead, which is also what keeps it to a single transmission.
local function advancePatternCorner(unitName, rec, unit, abName, now, rwy, corners, abPos)
    local patAlt    = rec.patternAlt[abName]
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    if cornerIdx == 1 then
        rec.report15Done = rec.report15Done or {}
        rec.report15ReminderSent = rec.report15ReminderSent or {}
        rec.report15Done[abName] = true
        rec.report15ReminderSent[abName] = true
    end
    local nextIdx = (cornerIdx % #corners) + 1
    local crp = corners[cornerIdx]
    local nextCrp = corners[nextIdx]
    local floorAlt = getPatternFloorAlt(rwy, crp)
    local protectedAlt = getProtectedPatternAlt(unitName, abName, patAlt, rwy)
    local nextAlt = getPatternFloorAlt(rwy, nextCrp)
    local gate = { altFt = patAlt, noSpeed = true }
    local isCp5Target = nextCrp and nextCrp.isCP5
    local currSpd = ATC.getSpeedKt(unit)
    if (nextIdx == 2 or nextIdx == 3) and currSpd and currSpd > 305 then
        gate.noSpeed = false
        gate.speedKt = 300
        gate.reduceOnly = true
    elseif isCp5Target and currSpd and currSpd > 255 then
        gate.noSpeed = false
        gate.speedKt = 250
        gate.reduceOnly = true
    end
    -- Always descend to the next CRP's computed altitude, but never below protectedAlt
    if nextAlt < patAlt then
        nextAlt = math.max(protectedAlt, nextAlt)
    end
    -- If we are currently at CP5 (we've reached the CP5 report), issue final
    -- and handoff to tower. This ensures FINAL is only issued after arrival at CP5.
    if crp and crp.isCP5 then
        local inboundHdg = ATC.toTrue(ATC.getActiveRwyHdg(abName) or rwy.hdg) % 360
        local cp5Alt = getPatternFloorAlt(rwy, crp)
        local finalGate = { altFt = cp5Alt, noSpeed = true }
        local spokenField = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(abName) or abName
        local cs = unit:getCallsign() or unitName or "Unknown"
        local towerFreq = rwy and rwy.frequencies and rwy.frequencies.tower
        local freqStr = towerFreq and string.format("%.3f MHz", towerFreq.mhz) or "tower frequency"
        local finalMagHdg = ATC.fmtHdg(ATC.toMag(inboundHdg))
        rec.handedOffToTower = rec.handedOffToTower or {}
        if not rec.handedOffToTower[abName] then
            local finalText = string.format(
                "%sTurn final heading %s, maintain %d ft. Contact %s Tower on %s. Report final.",
                controllerCall(unitName, abName, "Approach"), finalMagHdg, finalGate.altFt, spokenField, freqStr)
            ATC.radioMsg(rec.groupId, abPos, finalText, false, abName, "Approach")
            -- Delay the goodbye until the final message has finished playing
            local finalDur = ATC.ttsDuration(finalText)
            local goodbyeText = string.format("%s, switching to %s Tower, have a great day.", cs, spokenField)
            local p = { groupId = rec.groupId, text = goodbyeText, abName = abName }
            timer.scheduleFunction(function(arg)
                ATC.msg(arg.groupId, arg.text, true, arg.abName, "Approach")
                return nil
            end, p, timer.getTime() + finalDur + 0.5)
        end
        rec.lastVector[abName] = now
        rec.towerHandoffReady = rec.towerHandoffReady or {}
        rec.towerCheckedIn = rec.towerCheckedIn or {}
        rec.towerHandoffReady[abName] = true
        rec.towerCheckedIn[abName] = false
        rec.handedOffToTower[abName] = true
        ATC.log(string.format("CRP   %-10s @%s  reached CP5 -> final hdg %s, %d ft, tower dialogue open",
            tostring(unitName), tostring(abName), finalMagHdg, tonumber(finalGate.altFt) or -1))
        ATC.buildFullMenu(unitName)
        ATC.releasePatternHold(unitName, rec, abName)
        ATC.setPhase(unitName, abName, "approach")
        if not rec.holdPhase then rec.holdPhase = {} end
        rec.holdPhase[abName] = "pattern"
        return true
    end

    if nextCrp and nextCrp.isCP5 then
        -- Vector to CP5 instead of immediately switching to final.
        -- Use CP5's computed altitude (field elevation + 1500 ft) for the vector instruction.
        local cp5Alt = getPatternFloorAlt(rwy, nextCrp)
        gate.altFt = cp5Alt
        setPatternAltitude(unitName, rec, abName, cp5Alt)  -- keep patternAlt in sync so re-vectors use the right altitude
        rec.patternCornerIdx[abName] = nextIdx
        local uPos = unit:getPoint()
        local newTarget = nextCrp
        local newHdg = hdgTo(uPos, newTarget.pos)
        ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, newHdg, now, abName, newTarget.pos, newTarget.name)
        return true
    end
    if nextIdx == 1 then
        if patAlt <= floorAlt and protectedAlt <= floorAlt then
            local inboundHdg = ATC.toTrue(ATC.getActiveRwyHdg(abName) or rwy.hdg) % 360
            local elev       = rwy.elevation or 0
            local finalGate  = { altFt = elev + 500, noSpeed = true }
            ATC.issueVectorInstruction(unitName, rec, unit, abPos, finalGate, inboundHdg, now, abName, abPos, nil)
            ATC.releasePatternHold(unitName, rec, abName)
            ATC.setPhase(unitName, abName, "approach")
            if not rec.holdPhase then rec.holdPhase = {} end
            rec.holdPhase[abName] = "pattern"
            return true
        end
        if nextAlt ~= patAlt then
            setPatternAltitude(unitName, rec, abName, nextAlt)
            patAlt = nextAlt
            gate.altFt = patAlt
        end
    elseif nextAlt ~= patAlt then
        setPatternAltitude(unitName, rec, abName, nextAlt)
        patAlt = nextAlt
        gate.altFt = patAlt
    end
    rec.patternCornerIdx[abName] = nextIdx
    local uPos      = unit:getPoint()
    local newTarget = corners[nextIdx]
    local newHdg    = hdgTo(uPos, newTarget.pos)
    ATC.log(string.format("CRP   %-10s @%s  reached corner %d (%s) -> next %d (%s) at %d ft",
        tostring(unitName), tostring(abName), cornerIdx, tostring(crp and crp.name),
        nextIdx, tostring(newTarget.name), tonumber(gate.altFt) or -1))
    ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, newHdg, now, abName, newTarget.pos, newTarget.name)
    return true
end

function ATC.handlePatternReport(unitName, abName)
    local rec  = ATC.state.aircraft[unitName]
    local unit = Unit.getByName(unitName)
    local ab   = Airbase.getByName(abName)
    local rwy  = ATC.getRunway(abName)
    if not rec or not unit or not ab or not rwy then return false end
    if not (rec.patternAlt and rec.patternAlt[abName]) then return false end
    local corners = ATC.getPatternCorners(rwy, abName)
    if not corners then return false end
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    local target = corners[cornerIdx]
    if not target then return false end
    local uPos = unit:getPoint()
    local dx = target.pos.x - uPos.x
    local dz = target.pos.z - uPos.z
    local distToCorner = math.sqrt(dx * dx + dz * dz) / 1852
    -- Use per-CRP radius if available, else fallback to old logic
    local reportTolerance
    if target and target.radius then
        reportTolerance = target.radius / 1852 -- meters to NM
    elseif cornerIdx == 1 then
        reportTolerance = math.max(PATTERN_CORNER_NM, PATTERN_CORNER1_NM)
    elseif target and target.isCP5 then
        reportTolerance = PATTERN_CP5_NM
    else
        reportTolerance = PATTERN_CORNER_NM
    end
    if distToCorner > reportTolerance then return false end
    local abPos = ATC.getAirbasePos(ab)
    return advancePatternCorner(unitName, rec, unit, abName, timer.getTime(), rwy, corners, abPos)
end

local function drivePatternForUnit(unitName, rec, unit, abName, now)
    local ab  = Airbase.getByName(abName)
    local rwy = ATC.getRunway(abName)
    if not ab or not rwy then return end
    local corners = ATC.getPatternCorners(rwy, abName)
    if not corners then return end
    local uPos      = unit:getPoint()
    local abPos     = ATC.getAirbasePos(ab)
    local distNM    = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    local patAlt    = rec.patternAlt[abName]
    local ctrlNm    = rwy.ctrlZoneNm or 8
    local lastT        = rec.lastVector[abName] or 0
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    local gate = { altFt = patAlt, noSpeed = true }

    -- Resolve the current target CRP.
    local target = corners[cornerIdx]
    if not target then return end
    local dx           = target.pos.x - uPos.x
    local dz           = target.pos.z - uPos.z
    local distToCorner = math.sqrt(dx * dx + dz * dz) / 1852

    -- Compute report tolerance for the current target.
    local baseTolerance   = math.max(PATTERN_CORNER_NM, 1.5)
    local reportTolerance = baseTolerance
    if cornerIdx == 1 then
        reportTolerance = math.max(baseTolerance, PATTERN_CORNER1_NM)
    elseif target.isCP5 then
        -- The configured radius is a chart annotation, not a guidance tolerance.
        -- Batumi's CRP5 is 0.75 NM, which no jet is going to hit when the vector
        -- to it is only refreshed every 45 s -- roughly 3 NM of travel at 250 kt.
        -- Floor it to something actually capturable.
        reportTolerance = math.max(
            target.radius and (target.radius / 1852) or PATTERN_CP5_NM,
            ATC.config.cp5MinCaptureNM or 1.5)
    end

    -- Vectors go stale fast close in, which is what produced headings of
    -- 330 -> 030 -> 160 -> 230 while circling a corner that was never captured.
    local outerInterval = (cornerIdx == 1) and 60 or 45
    if distToCorner < 6 then outerInterval = 20 end

    -- Outside the control zone: re-vector toward the CURRENT target (not always CRP1).
    -- When the aircraft is already past CRP1 in the pattern (cornerIdx > 1), sending
    -- it back to CRP1 breaks the sequence. Always continue toward whatever CRP is next.
    if distNM > ctrlNm then
        if (now - lastT) > outerInterval then
            local hdg = hdgTo(uPos, target.pos)
            ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, hdg, now, abName, target.pos, target.name)
        end
        return
    end

    -- Corner captured, or flown past. A radius test alone cannot be relied on:
    -- an aircraft that overshoots is simply vectored back, and circles. Treat the
    -- corner as made once the aircraft is close and the range starts opening
    -- again -- the standard waypoint-passing test.
    rec.lastCornerDist = rec.lastCornerDist or {}
    local prev = rec.lastCornerDist[abName]
    local passedAbeam = prev and prev.idx == cornerIdx
        and distToCorner < reportTolerance * 2.5
        and distToCorner > prev.d + 0.05
    rec.lastCornerDist[abName] = { idx = cornerIdx, d = distToCorner }

    if distToCorner <= reportTolerance or passedAbeam then
        if passedAbeam and distToCorner > reportTolerance then
            ATC.log(string.format("CRP   %-10s @%s  passed abeam corner %d (%s) at %.1f NM",
                tostring(unitName), tostring(abName), cornerIdx,
                tostring(target.name), distToCorner))
        end
        rec.lastCornerDist[abName] = nil
        advancePatternCorner(unitName, rec, unit, abName, now, rwy, corners, abPos)
        return
    end

    -- Inside the zone but moving away from the current target: re-vector every 30 s.
    -- This corrects drift without flooding the pilot with instructions.
    if (now - lastT) > outerInterval then
        local hdg = hdgTo(uPos, target.pos)
        ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, hdg, now, abName, target.pos, target.name)
    end
end
function ATC.checkVectoring()
    local now = timer.getTime()
    for unitName, rec in pairs(ATC.state.aircraft) do
        local unit = Unit.getByName(unitName)
        if unit and ATC.isPlayer(unit) and rec.engagedField then
            local abName = rec.engagedField
            local ph     = ATC.getPhase(unitName, abName)
            if (ph == "inbound" or ph == "approach")
               and rec.patternAlt and rec.patternAlt[abName] then
                local ab = Airbase.getByName(abName)
                local distNM = ab and ATC.distUnitToBase(unit, ab)
                rec.report15Done = rec.report15Done or {}
                rec.report15ReminderSent = rec.report15ReminderSent or {}
                if distNM and distNM <= 15
                   and not rec.report15Done[abName]
                   and not rec.report15ReminderSent[abName]
                   and not (rec.seqNum and rec.seqNum[abName]) then
                    local abPos = ab and ATC.getAirbasePos(ab)
                    local fieldName = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(abName) or abName
                    ATC.radioMsg(rec.groupId, abPos, string.format(
                        "%sreport 15 nautical miles from %s.",
                        controllerCall(unitName, abName, "Approach"), fieldName),
                        false, abName, "Approach")
                    rec.report15ReminderSent[abName] = true
                end
            end
            if (ph == "inbound" or ph == "approach")
               and rec.patternAlt and rec.patternAlt[abName] then
                local ok, err = pcall(drivePatternForUnit, unitName, rec, unit, abName, now)
                if not ok then
                    ATC.log("ERRVEC " .. unitName .. ": " .. tostring(err))
                    trigger.action.outText("[DCS-ATC] vectoring error: " .. tostring(err), 15)
                end
            end
        end
    end
end
