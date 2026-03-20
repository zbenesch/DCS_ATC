ATC = ATC or {}
local _runwaySnapshot = ATC.runways  -- watchdog snapshot for this chunk

-- Constants used by pattern / glideslope logic in this chunk
local ENTRY_BASE_AGL     = 3000   -- altitude AGL for entry / base leg
local FINAL_AGL          = 1500   -- altitude AGL at the final approach point
local PATTERN_CORNER_NM  = 0.5    -- within this NM of a CRP corner: advance to next
local PATTERN_CORNER1_NM = 2.0    -- larger capture only for CRP seq1 to avoid conflicting vectors near entry
local PATTERN_CP5_NM     = 0.5    -- CP5 zone radius (0.5 NM = 1 NM diameter)
local PATTERN_FINAL_ALT  = 1500   -- ft; after full lap at this altitude -> turn final

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
                        ATC.log("INIT  Startup scan: menu built for " .. uName)
                        built = built + 1
                    else
                        ATC.log("INIT  Startup scan: SKIP " .. uName .. " rec=" .. tostring(rec ~= nil) .. " menuRoot=" .. tostring(rec and rec.menuRoot ~= nil))
                    end
                else
                    ATC.log("INIT  Startup scan: no group for " .. uName)
                end
            end
        end
    end
    ATC.log(string.format("INIT  startupScan  found=%d  built=%d", found, built))
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
    timer.scheduleFunction(runVectoring,   nil, t0 + 10)
    timer.scheduleFunction(runGlideslopes, nil, t0 + 10)
end
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
                    local fieldName = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(abName) or abName
                    local distNM = ATC.distUnitToBase(unit, ab)
                    if distNM and distNM <= ATC.config.finalNM then
                        local cs     = unit:getCallsign() or ""
                        local spdKt  = ATC.getSpeedKt(unit)
                        local altFt  = ATC.getAltFt(unit)
                        local spds   = ATC.getApproachSpeeds(unit)
                            local lastT  = rec.lastGuidance[abName] or 0
                            local rwy = ATC.getRunway(abName)
                            local leg = (rwy and ATC.getPatternLeg(unit:getPoint(), abPos, rwy)) or nil
                            local finalLeg = (leg == "final" or leg == "short_final")
                            local patternEntryLeg = (leg == "initial" or leg == "downwind")
                            local onFinal = finalLeg and distNM <= 8
                            local onPatternEntry = patternEntryLeg and distNM <= 10 -- 10 NM default for pattern entry
                            local controller = (onFinal or onPatternEntry) and "Tower" or "Approach"
                            if (onPatternEntry or onFinal) and not rec.handedOffToTower[abName]
                               and not (rec.patternAlt and rec.patternAlt[abName]) then
                                local towerFreq = rwy and rwy.frequencies and rwy.frequencies.tower
                                local freqStr = towerFreq and (towerFreq.mhz .. " MHz") or "Tower frequency"
                                ATC.radioMsg(rec.groupId, abPos, string.format(
                                    "%sContact %s Tower on %s.\n" ..
                                    "%.1f NM from threshold.",
                                    controllerCall(unitName, abName, "Approach"), fieldName, freqStr, distNM),
                                    false, abName, "Approach")
                                rec.handedOffToTower[abName] = true
                            end
                        if spdKt and spdKt < ATC.config.stallWarnKt and unit:inAir() then
                            ATC.radioMsg(rec.groupId, abPos, string.format(
                                "%sgo around, go around!\n"                ..
                                "Airspeed critically low:  %d kt.\n"       ..
                                "Climb immediately, runway heading.",
                                controllerCall(unitName, abName, controller), spdKt), true, abName, controller)
                            ATC.setPhase(unitName, abName, "goaround")
                            rec.lastGuidance[abName] = now
                        elseif (now - lastT) >= ATC.config.guidanceInterval then
                            local cleared = rec.landingCleared and rec.landingCleared[abName]
                            if cleared and onFinal then
                                local gs = ATC.getGlideslope(unit, abPos, rwy)
                                local speedDev = math.abs(gs.speedDev or 0)
                                local aoaDev = math.abs(gs.aoaDev or 0)
                                local altDev = math.abs(gs.altDev or 0)
                                local maxDev = math.max(speedDev, aoaDev, altDev)
                                if maxDev > 0.5 then
                                    ATC.radioMsg(rec.groupId, abPos, "Missed approach, go around!", false, abName, controller)
                                    ATC.setPhase(unitName, abName, "goaround")
                                    rec.lastGuidance[abName] = now
                                elseif maxDev > 0.25 then
                                    ATC.radioMsg(rec.groupId, abPos, "Correct your approach: deviation from glideslope.", false, abName, controller)
                                    rec.lastGuidance[abName] = now
                                end
                            end
                            if cleared and onFinal and distNM <= 2 and not rec.finalCleared[abName] then
                                if ATC.isRunwayClear(abName) then
                                    local windDir, windSpd = ATC.getWind(abPos)
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%s, %s tower, cleared to land, wind %03d at %d, check gear down.",
                                        cs, fieldName, windDir, windSpd),
                                        false, abName, controller)
                                    rec.finalCleared = rec.finalCleared or {}
                                    rec.finalCleared[abName] = true
                                    rec.lastGuidance[abName] = now
                                else
                                    ATC.radioMsg(rec.groupId, abPos, string.format(
                                        "%s, %s tower, runway occupied, return to pattern and await clearance.",
                                        cs, fieldName),
                                        false, abName, controller)
                                    rec.lastGuidance[abName] = now
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
                end -- if ab and rwy
            end -- if not abName / else
        end
    end
end
function ATC.getPatternLegs(rwy)
    if not rwy then return nil end
    local finalHdg  = rwy.hdg
    local downHdg   = rwy.reciprocal or ((rwy.hdg + 180) % 360)
    local dir       = rwy.patternDir or "L"
    local offset    = (dir == "R") and 90 or -90
    local baseHdg   = (downHdg + offset + 360) % 360
    return { finalHdg = finalHdg, baseHdg = baseHdg, downwindHdg = downHdg, dir = dir }
end
function ATC.getPatternCorners(rwy)
    if not rwy or not rwy.crps then return nil end
    local corners = {}
    for _, crp in ipairs(rwy.crps) do
        local p = coord.LLtoLO(crp.lat, crp.lon, 0)
        table.insert(corners, { pos = p, name = crp.name, seq = crp.seq or 99 })
    end
    table.sort(corners, function(a, b) return a.seq < b.seq end)
    if #corners >= 4 then
        local c4 = corners[4]
        local abPos = Airbase.getByName and rwy and nil
        local airbasePos = nil
        do
            if Airbase and Airbase.getByName and ATC.runways then
                for abName, rr in pairs(ATC.runways) do
                    if rr == rwy then
                        local ab = Airbase.getByName(abName)
                        if ab then
                            airbasePos = ATC.getAirbasePos(ab)
                            break
                        end
                    end
                end
            end
        end
        if c4 and c4.pos and airbasePos then
            local finalTrue = ATC.toTrue(rwy.hdg or 0)
            local rad = math.rad(finalTrue)
            local ux, uz = math.cos(rad), math.sin(rad)
            local vx = c4.pos.x - airbasePos.x
            local vz = c4.pos.z - airbasePos.z
            local t = (vx * ux) + (vz * uz)
            local cp5 = {
                pos = {
                    x = airbasePos.x + t * ux,
                    y = airbasePos.y,
                    z = airbasePos.z + t * uz,
                },
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
    local rwy  = ATC.runways and ATC.runways[abName]
    local alts = (rwy and rwy.patternAlts) or { 4500, 3500, 2500, 1500 }
    local floorAlt = alts[#alts] or PATTERN_FINAL_ALT
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
    local slotAlt = highestOccupied and (highestOccupied + 1000) or topAlt
    fs.patternSlots[unitName] = slotAlt
    return slotAlt
end
function ATC.freePatternSlot(unitName, abName)
    local fs = ATC.state.airfields[abName]
    if fs and fs.patternSlots then fs.patternSlots[unitName] = nil end
end
function ATC.freeStackLevel(unitName, abName)
    ATC.freePatternSlot(unitName, abName)
end
local function getPatternFloorAlt(rwy)
    local alts = rwy and rwy.patternAlts
    if alts and #alts > 0 then return alts[#alts] end
    return PATTERN_FINAL_ALT
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
    local floorAlt = getPatternFloorAlt(rwy)
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
    return floorAlt
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
    if hdgDiff <= 10 then
        hdgPart = "fly heading " .. ATC.fmtHdg(magHdg)
    elseif angleDiff(currHdg, targetHdg) > 0 then
        hdgPart = "turn RIGHT heading " .. ATC.fmtHdg(magHdg)
    else
        hdgPart = "turn LEFT heading " .. ATC.fmtHdg(magHdg)
    end
    if distNM then
        hdgPart = hdgPart .. string.format(" for %.1f NM", distNM)
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
    rec.lastVector[abName] = now
end
function ATC.initPatternEntry(unitName, airbaseName)
    local rec  = ATC.state.aircraft[unitName]
    local unit = Unit.getByName(unitName)
    local ab   = Airbase.getByName(airbaseName)
    local rwy  = ATC.getRunway(airbaseName)
    if not rec or not unit or not ab or not rwy then return end
    if rec.patternAlt[airbaseName] then
        ATC.log(string.format("INIT  %-10s @%s  already vectored in reply, skipping", unitName, airbaseName))
        return
    end
    local corners = ATC.getPatternCorners(rwy)
    if not corners then
        ATC.log(string.format("INIT  %-10s @%s  no CRPs -> no vectoring", unitName, airbaseName))
        return
    end
    local uPos   = unit:getPoint()
    local abPos  = ATC.getAirbasePos(ab)
    local distNM = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    local ctrlNm = rwy.ctrlZoneNm or 8
    local slotAlt = ATC.assignPatternSlot(unitName, airbaseName)
    setPatternAltitude(unitName, rec, airbaseName, slotAlt)
    rec.lastVector[airbaseName]      = timer.getTime()
    local gate = { altFt = slotAlt, noSpeed = true }
    if distNM > ctrlNm then
        rec.patternCornerIdx[airbaseName] = 1
        local hdg = hdgTo(uPos, corners[1].pos)
        ATC.log(string.format("INIT  %-10s @%s  OUTSIDE(%.1fNM) -> corner1(%s) hdg=%.0f alt=%d",
            unitName, airbaseName, distNM, corners[1].name, hdg, slotAlt))
        ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, hdg, timer.getTime(), airbaseName, corners[1].pos, corners[1].name)
    else
        rec.patternCornerIdx[airbaseName] = 1
        local hdg = hdgTo(uPos, corners[1].pos)
        ATC.log(string.format("INIT  %-10s @%s  INSIDE(%.1fNM) -> corner1(%s) hdg=%.0f alt=%d",
            unitName, airbaseName, distNM, corners[1].name, hdg, slotAlt))
        ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, hdg, timer.getTime(), airbaseName, corners[1].pos, corners[1].name)
    end
end
local function advancePatternCorner(unitName, rec, unit, abName, now, rwy, corners, abPos)
    local patAlt    = rec.patternAlt[abName]
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    local floorAlt  = getPatternFloorAlt(rwy)
    local nextIdx = (cornerIdx % #corners) + 1
    local protectedAlt = getProtectedPatternAlt(unitName, abName, patAlt, rwy)
    local nextAlt = patAlt
    local gate = { altFt = patAlt, noSpeed = true }
    local isCp5Target = corners[nextIdx] and corners[nextIdx].isCP5
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
    if not isCp5Target and patAlt > protectedAlt then
        nextAlt = math.max(protectedAlt, patAlt - 1000)
    end
    if isCp5Target then
        gate.noAltitude = true
    end
    if corners[cornerIdx] and corners[cornerIdx].isCP5 then
        local inboundHdg = ATC.toTrue(rwy.hdg) % 360
        local finalGate = { altFt = patAlt, noSpeed = true }
        ATC.log(string.format("FINAL %-10s @%s  cp5 reached -> final hdg=%.0f alt=%d",
            unitName, abName, inboundHdg, finalGate.altFt))
        ATC.issueVectorInstruction(unitName, rec, unit, abPos, finalGate, inboundHdg, now, abName, abPos, nil)
        rec.towerHandoffReady = rec.towerHandoffReady or {}
        rec.towerCheckedIn = rec.towerCheckedIn or {}
        rec.towerHandoffReady[abName] = true
        rec.towerCheckedIn[abName] = false
        rec.handedOffToTower = rec.handedOffToTower or {}
        rec.handedOffToTower[abName] = true
        ATC.buildFullMenu(unitName)
        rec.patternAlt[abName] = nil
        rec.patternCornerIdx[abName] = nil
        ATC.setPhase(unitName, abName, "approach")
        if not rec.holdPhase then rec.holdPhase = {} end
        rec.holdPhase[abName] = "pattern"
        return true
    end
    if nextIdx == 1 then
        if patAlt <= floorAlt and protectedAlt <= floorAlt then
            local inboundHdg = ATC.toTrue(rwy.hdg) % 360
            local elev       = rwy.elevation or 0
            local finalGate  = { altFt = elev + 500, noSpeed = true }
            ATC.log(string.format("FINAL %-10s @%s  -> final hdg=%.0f alt=%d",
                unitName, abName, inboundHdg, finalGate.altFt))
            ATC.issueVectorInstruction(unitName, rec, unit, abPos, finalGate, inboundHdg, now, abName, abPos, nil)
            rec.patternAlt[abName] = nil
            rec.patternCornerIdx[abName] = nil
            ATC.setPhase(unitName, abName, "approach")
            if not rec.holdPhase then rec.holdPhase = {} end
            rec.holdPhase[abName] = "pattern"
            return true
        end
        if nextAlt ~= patAlt then
            setPatternAltitude(unitName, rec, abName, nextAlt)
            patAlt = nextAlt
            gate.altFt = patAlt
            ATC.log(string.format("LAP   %-10s @%s  lap complete, descend to %d ft",
                unitName, abName, patAlt))
        end
    elseif nextAlt ~= patAlt then
        setPatternAltitude(unitName, rec, abName, nextAlt)
        patAlt = nextAlt
        gate.altFt = patAlt
        ATC.log(string.format("STEP  %-10s @%s  descend on pattern to %d ft",
            unitName, abName, patAlt))
    end
    rec.patternCornerIdx[abName] = nextIdx
    local uPos      = unit:getPoint()
    local newTarget = corners[nextIdx]
    local newHdg    = hdgTo(uPos, newTarget.pos)
    ATC.log(string.format("TURN  %-10s @%s  -> corner%d(%s) hdg=%.0f alt=%d",
        unitName, abName, nextIdx, newTarget.name, newHdg, patAlt))
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
    local corners = ATC.getPatternCorners(rwy)
    if not corners then return false end
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    local target = corners[cornerIdx]
    if not target then return false end
    local uPos = unit:getPoint()
    local dx = target.pos.x - uPos.x
    local dz = target.pos.z - uPos.z
    local distToCorner = math.sqrt(dx * dx + dz * dz) / 1852
    local baseTolerance = math.max(PATTERN_CORNER_NM, 1.5)
    local reportTolerance = baseTolerance
    if cornerIdx == 1 then
        reportTolerance = math.max(baseTolerance, PATTERN_CORNER1_NM)
    elseif target and target.isCP5 then
        reportTolerance = PATTERN_CP5_NM
    end
    if distToCorner > reportTolerance then return false end
    local abPos = ATC.getAirbasePos(ab)
    ATC.log(string.format("RPTCRP %-10s @%s  corner=%d(%s) dist=%.1fNM -> advance",
        unitName, abName, cornerIdx, target.name, distToCorner))
    return advancePatternCorner(unitName, rec, unit, abName, timer.getTime(), rwy, corners, abPos)
end

local function drivePatternForUnit(unitName, rec, unit, abName, now)
    local ab  = Airbase.getByName(abName)
    local rwy = ATC.getRunway(abName)
    if not ab or not rwy then return end
    local corners = ATC.getPatternCorners(rwy)
    if not corners then return end
    local uPos      = unit:getPoint()
    local abPos     = ATC.getAirbasePos(ab)
    local distNM    = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    local patAlt    = rec.patternAlt[abName]
    local ctrlNm    = rwy.ctrlZoneNm or 8
    local lastT        = rec.lastVector[abName] or 0
    local outerInterval = 30   -- re-announce only every 30 s while outside the control zone
    local cornerIdx = (rec.patternCornerIdx and rec.patternCornerIdx[abName]) or 1
    local floorAlt  = getPatternFloorAlt(rwy)
    ATC.log(string.format("CVEC  %-10s @%s  ph=%s  dist=%.1fNM  alt=%d  corner=%d",
        unitName, abName, ATC.getPhase(unitName, abName), distNM, patAlt, cornerIdx))
    local gate = { altFt = patAlt, noSpeed = true }
    if distNM > ctrlNm then
        if (now - lastT) > outerInterval then
            local hdg = hdgTo(uPos, corners[1].pos)
            ATC.log(string.format("REVEC %-10s @%s  OUTSIDE -> corner1(%s) hdg=%.0f",
                unitName, abName, corners[1].name, hdg))
            ATC.issueVectorInstruction(unitName, rec, unit, abPos, gate, hdg, now, abName, corners[1].pos, corners[1].name)
        end
        return
    end
    -- Inside control zone: only act when the plane reaches the next CRP corner.
    -- No periodic re-vectors between corners.
    local target        = corners[cornerIdx]
    if not target then return end
    local dx            = target.pos.x - uPos.x
    local dz            = target.pos.z - uPos.z
    local distToCorner  = math.sqrt(dx * dx + dz * dz) / 1852
    local baseTolerance = math.max(PATTERN_CORNER_NM, 1.5)
    local reportTolerance = baseTolerance
    if cornerIdx == 1 then
        reportTolerance = math.max(baseTolerance, PATTERN_CORNER1_NM)
    elseif target and target.isCP5 then
        reportTolerance = PATTERN_CP5_NM
    end
    local nearestIdx = ATC.nearestCornerIdx(corners, uPos)
    local nextIdx = (cornerIdx % #corners) + 1
    local allowNearestShortcut = not (target and target.isCP5)
    if distToCorner <= reportTolerance or (allowNearestShortcut and nearestIdx == nextIdx) then
        advancePatternCorner(unitName, rec, unit, abName, now, rwy, corners, abPos)
    end
end
function ATC.checkVectoring()
    local now = timer.getTime()
    for unitName, rec in pairs(ATC.state.aircraft) do
        local unit = Unit.getByName(unitName)
        if unit and ATC.isPlayer(unit) and rec.activeField then
            local abName = rec.activeField
            local ph     = ATC.getPhase(unitName, abName)
            if (ph == "inbound" or ph == "approach")
               and rec.patternAlt and rec.patternAlt[abName] then
                local ab = Airbase.getByName(abName)
                local distNM = ab and ATC.distUnitToBase(unit, ab)
                rec.report15Done = rec.report15Done or {}
                rec.report15ReminderSent = rec.report15ReminderSent or {}
                if distNM and distNM <= 15
                   and not rec.report15Done[abName]
                   and not rec.report15ReminderSent[abName] then
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
