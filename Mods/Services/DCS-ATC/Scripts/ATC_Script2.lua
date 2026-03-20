ATC = ATC or {}
local function formatControllerFreq(rwy, controllerName)
    local key = controllerName and string.lower(controllerName) or nil
    local freq = key and rwy and rwy.frequencies and rwy.frequencies[key]
    if freq and freq.mhz then
        return string.format("%s %.3f MHz", controllerName, freq.mhz)
    end
    return controllerName
end

local function isRussianAircraft(unitName)
    local unit = Unit.getByName(unitName)
    if not unit then return false end
    local typeName = unit:getTypeName() or ""
    return (typeName:match("^Su%-") or typeName:match("^MiG%-") or 
            typeName:match("^Mi%-") or typeName:match("^Ka%-") or typeName:match("^Yak%-"))
end

local function formatRangeText(unitName, radiusM)
    local nearKm = math.floor(((radiusM or 0) / 1000) + 0.5)
    local nearNM = math.floor(((radiusM or 0) / 1852) + 0.5)
    if isRussianAircraft(unitName) then
        return string.format("%d km", nearKm)
    else
        return string.format("%d nm", nearNM)
    end
end

local function isArrivalEngaged(rec, airbaseName, phase)
    if not rec or rec.engagedField ~= airbaseName then return false end
    if phase == "inbound" or phase == "approach" or phase == "final"
       or phase == "goaround" or phase == "landing" then
        return true
    end
    if rec.seqNum and rec.seqNum[airbaseName] then return true end
    if rec.landingCleared and rec.landingCleared[airbaseName] then return true end
    return false
end

function ATC.clearFieldMenu(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local path = rec.fieldMenus[airbaseName]
    if not path then return end
    missionCommands.removeItemForGroup(rec.groupId, path)
    rec.fieldMenus[airbaseName] = nil
end
function ATC.buildFieldMenu(unitName, fieldEntry)
    local rec = ATC.state.aircraft[unitName]
    if not rec or not rec.menuRoot then return end
    local abName = fieldEntry.name
    local distKm = math.floor(fieldEntry.distM / 1000 + 0.5)
    local rwy    = ATC.runways and ATC.runways[abName]
    local freqStr = (rwy and rwy.frequencies and rwy.frequencies.approach)
                    and ("  APP " .. rwy.frequencies.approach.mhz) or ""
    local label  = abName .. "  (" .. distKm .. " km)" .. freqStr
    local gid    = rec.groupId
    ATC.clearFieldMenu(unitName, abName)
    local fieldMenu = missionCommands.addSubMenuForGroup(gid, label, rec.menuRoot)
    rec.fieldMenus[abName] = fieldMenu
    local arg = { unitName = unitName, airbaseName = abName }
    local unit   = Unit.getByName(unitName)
    local inAir  = unit and unit:inAir() or false
    local spdKt  = unit and ATC.getSpeedKt(unit) or nil
    local ph     = ATC.getPhase(unitName, abName)
    local onRwy  = (ph == "landing")
    local arrivalEngaged = isArrivalEngaged(rec, abName, ph)
    local postLandingReady = rec.postLandingReady and rec.postLandingReady[abName]
    if postLandingReady and not inAir and spdKt and spdKt <= 50 then
        missionCommands.addCommandForGroup(gid, formatControllerFreq(rwy, "Tower"),
            fieldMenu, function(a) ATC.onTowerContact(a) end, arg)
        missionCommands.addCommandForGroup(gid, formatControllerFreq(rwy, "Ground"),
            fieldMenu, function(a) ATC.onVacatingRunway(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Declare Emergency",
            fieldMenu, function(a) ATC.onEmergency(a) end, arg)
    elseif onRwy then
        missionCommands.addCommandForGroup(gid, "Vacating Runway",
            fieldMenu, function(a) ATC.onVacatingRunway(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Acknowledge / Wilco",
            fieldMenu, function(a) ATC.onWilco(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Declare Emergency",
            fieldMenu, function(a) ATC.onEmergency(a) end, arg)
    elseif arrivalEngaged then
        missionCommands.addCommandForGroup(gid, "Report Position",
            fieldMenu, function(a) ATC.onPositionReport(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Acknowledge / Wilco",
            fieldMenu, function(a) ATC.onWilco(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Request Go-Around",
            fieldMenu, function(a) ATC.onGoAround(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Declare Emergency",
            fieldMenu, function(a) ATC.onEmergency(a) end, arg)
    elseif not inAir then
        missionCommands.addCommandForGroup(gid, "Request Taxi Clearance",
            fieldMenu, function(a) ATC.onTaxiRequest(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Request Takeoff Clearance",
            fieldMenu, function(a) ATC.onTakeoffRequest(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Ready for Departure",
            fieldMenu, function(a) ATC.onReadyDeparture(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Declare Emergency",
            fieldMenu, function(a) ATC.onEmergency(a) end, arg)
    else
        missionCommands.addCommandForGroup(gid, "Request Landing / Inbound",
            fieldMenu, function(a) ATC.onInboundRequest(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Report Position",
            fieldMenu, function(a) ATC.onPositionReport(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Acknowledge / Wilco",
            fieldMenu, function(a) ATC.onWilco(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Request Go-Around",
            fieldMenu, function(a) ATC.onGoAround(a) end, arg)
        missionCommands.addCommandForGroup(gid, "Declare Emergency",
            fieldMenu, function(a) ATC.onEmergency(a) end, arg)
    end
end
function ATC.buildFullMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then
        ATC.log("MENU  buildFullMenu: no rec for " .. tostring(unitName))
        return
    end
    if rec.menuRoot then
        missionCommands.removeItemForGroup(rec.groupId, rec.menuRoot)
        rec.menuRoot   = nil
        rec.fieldMenus = {}
    end
    local unit = Unit.getByName(unitName)
    if not unit or not unit:isExist() then
        ATC.log("MENU  buildFullMenu: unit not found: " .. tostring(unitName))
        return
    end
    local uPos = unit:getPoint()
    local root = missionCommands.addSubMenuForGroup(
        rec.groupId, ATC.config.rootMenuLabel, nil)
    rec.menuRoot = root
    if rec.engagedField then
        local ab = Airbase.getByName(rec.engagedField)
        if ab then
            local abPos  = ATC.getAirbasePos(ab)
            local distM  = (abPos and uPos) and ATC.distVec3H(uPos, abPos) or 0
            local fe = { ab = ab, distM = distM, name = rec.engagedField }
            ATC.buildFieldMenu(unitName, fe)
            local ph = ATC.getPhase(unitName, rec.engagedField)
            local arrivalEngaged = isArrivalEngaged(rec, rec.engagedField, ph)
            local postLandingReady = rec.postLandingReady and rec.postLandingReady[rec.engagedField]
            if not postLandingReady or not arrivalEngaged then
                missionCommands.addCommandForGroup(rec.groupId,
                    "Cancel Request with " .. rec.engagedField,
                    root, ATC.onCancelRequest, { unitName = unitName, airbaseName = rec.engagedField })
            end
        else
            rec.engagedField = nil
            ATC.buildFullMenu(unitName)
        end
        return
    end
    local nearby = ATC.getNearbyAirbases(uPos, ATC.config.nearRadiusM)
    local rangeText = formatRangeText(unitName, ATC.config.nearRadiusM)
    local nameList = {}
    for _, fe in ipairs(nearby) do nameList[#nameList + 1] = fe.name end
    rec.nearbyFields = nameList
    missionCommands.addCommandForGroup(rec.groupId,
        ATC.config.menuRefreshLabel,
        root, ATC.onRefreshMenu, unitName)
    if #nearby == 0 then
        missionCommands.addCommandForGroup(rec.groupId,
            string.format("  (No airfields within %s)", rangeText),
            root, function() end, nil)
        return
    end
    for _, fe in ipairs(nearby) do
        ATC.buildFieldMenu(unitName, fe)
    end
end
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
function ATC.onRefreshMenu(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local rangeText = formatRangeText(unitName, ATC.config.nearRadiusM)
    ATC.buildFullMenu(unitName)
    ATC.msg(rec.groupId,
        "[ATC]  Airfield list refreshed.\n" ..
        string.format("Showing airbases within %s of your current position.", rangeText))
end
function ATC.setEngagedField(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    rec.engagedField = airbaseName
    ATC.buildFullMenu(unitName)
end
function ATC.clearEngagement(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local field = rec.engagedField
    rec.engagedField = nil
    if field then
        ATC.freeStackLevel(unitName, field)
        if rec.stackAlt       then rec.stackAlt[field]       = nil end
        if rec.approachGate   then rec.approachGate[field]   = nil end
        if rec.landingCleared then rec.landingCleared[field]  = nil end
        if rec.patternAdv     then rec.patternAdv[field]     = nil end
        if rec.holdPhase      then rec.holdPhase[field]      = nil end
        if rec.postLandingReady then rec.postLandingReady[field] = nil end
    end
    ATC.buildFullMenu(unitName)
end
local function preamble(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = (unit and unit:getCallsign()) or unitName or "Unknown"
    local field = airbaseName or "Airfield"
    local ctrl  = controller or "Tower"
    return string.format("%s, %s %s.", cs, field, ctrl)
end
local function controllerCall(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = (unit and unit:getCallsign()) or unitName or "Unknown"
    local field = airbaseName or "Airfield"
    local ctrl  = controller or "Tower"
    return string.format("%s, %s %s, ", cs, field, ctrl)
end
local function getController(unitName, airbaseName)
    local phase = ATC.getPhase(unitName, airbaseName)
    local unit = Unit.getByName(unitName)
    if phase == "inbound" or phase == "approach" or phase == "final" or
       phase == "airborne" or phase == "goaround" then
        return "Approach"
    end
    if unit then
        local ab = Airbase.getByName(airbaseName)
        local distNM = ATC.distUnitToBase(unit, ab)
        if distNM and distNM <= 5 then
            return "Tower"
        end
    end
    return "Tower"
end
function ATC.onCancelRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local fs     = ATC.getFieldState(airbaseName)
    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then table.remove(fs.landingSeq, i) break end
    end
    for i, n in ipairs(fs.departSeq) do
        if n == unitName then table.remove(fs.departSeq, i) break end
    end
    if rec.seqNum then rec.seqNum[airbaseName] = nil end
    if rec.stackAlt then rec.stackAlt[airbaseName] = nil end
    if rec.approachGate then rec.approachGate[airbaseName] = nil end
    if rec.landingCleared then rec.landingCleared[airbaseName] = nil end
    if rec.patternAdv then rec.patternAdv[airbaseName] = nil end
    if rec.holdPhase then rec.holdPhase[airbaseName] = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    ATC.msg(rec.groupId, string.format(
        "%s\nRequest cancelled. Contact ATC again when ready.",
        preamble(unitName, airbaseName, getController(unitName, airbaseName))))
    ATC.clearEngagement(unitName)
end
local function hdgTo(a, b)
    local h = math.deg(math.atan2(b.z - a.z, b.x - a.x))
    return (h < 0) and (h + 360) or h
end
local function angleDiff(a, b)
    return ((b - a + 540) % 360) - 180
end
function ATC.onInboundRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    if not ATC._timersStarted then ATC.onSimStart() end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs     = unit:getCallsign() or ""
    local fs     = ATC.getFieldState(airbaseName)
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    local altFt  = ATC.getAltFt(unit)
    local seqN   = ATC.addToLandingSeq(unitName, airbaseName)
    rec.seqNum[airbaseName] = seqN
    if rec.postLandingReady then rec.postLandingReady[airbaseName] = nil end
    ATC.setEngagedField(unitName, airbaseName)
    local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
    local altStr  = altFt  and string.format("%d ft",   altFt)  or "altitude unknown"
    rec.greeted[airbaseName] = rec.greeted[airbaseName] or {}
    local greeting = ""
    if not rec.greeted[airbaseName]["Approach"] then
        greeting = ATC.getDaytimeGreeting() .. ", " .. cs .. ", " .. airbaseName .. " Approach.\n"
        rec.greeted[airbaseName]["Approach"] = true
    else
        greeting = cs .. ", " .. airbaseName .. " Approach.\n"
    end
    local firstVectorLine = ""
    local firstVectorVoice = ""
    local rwy     = ATC.getRunway(airbaseName)
    local corners = rwy and ATC.getPatternCorners(rwy)
    local abPos = ATC.getAirbasePos(ab)
    local uPos = unit:getPoint()
    local bearingText = (abPos and uPos and ATC.getBearingText(abPos, uPos)) or nil
    do
        local rwType = type(ATC.runways)
        local rwCount = (rwType == "table") and (function() local n=0; for _ in pairs(ATC.runways) do n=n+1 end; return n end)() or 0
        local rwHit   = (rwType == "table") and tostring(ATC.runways[airbaseName] ~= nil) or "N/A"
        ATC.log(string.format("INBD  %-10s @%s  runways=%s(keys=%d) hit=%s  rwy=%s  corners=%s  dist=%s",
            unitName, airbaseName,
            rwType, rwCount, rwHit,
            rwy and "ok" or "NIL",
            corners and tostring(#corners) or "NIL",
            distStr))
    end
    if corners then
        local ctrlNm  = rwy.ctrlZoneNm or 8
        local slotAlt = ATC.assignPatternSlot(unitName, airbaseName)
        rec.patternAlt[airbaseName]       = slotAlt
        rec.lastVector[airbaseName]       = timer.getTime()
        local targetCorner, targetIdx
        if not distNM or distNM > ctrlNm then
            targetIdx    = 1
            targetCorner = corners[1]
        else
            targetIdx     = 1
            targetCorner  = corners[1]
        end
        rec.patternCornerIdx[airbaseName] = targetIdx
        local trueHdg = hdgTo(uPos, targetCorner.pos)
        local magHdg  = ATC.roundHdg(ATC.toMag(trueHdg))
        local legDistNm = ATC.mToNM(ATC.distVec3H(uPos, targetCorner.pos))
        local turnDir
        local vel = unit:getVelocity()
        if vel then
            local currHdg = math.deg(math.atan2(vel.z, vel.x))
            if currHdg < 0 then currHdg = currHdg + 360 end
            turnDir = angleDiff(currHdg, trueHdg) > 0 and "Turn RIGHT" or "Turn LEFT"
        else
            turnDir = "Fly"
        end
        firstVectorLine = string.format(
            "\n%s heading %s for %.1f NM, %s %d ft. Report at %s.",
            turnDir, ATC.fmtHdg(magHdg),
            legDistNm,
            (slotAlt > (ATC.getAltFt(unit) or 0)) and "climb to" or "descend to",
            slotAlt, targetCorner.name)
        firstVectorVoice = string.format(
            "\n%s heading %s for %.1f NM, %s %d ft. Report at %s.",
            turnDir, ATC.fmtHdg(magHdg),
            legDistNm,
            (slotAlt > (ATC.getAltFt(unit) or 0)) and "climb to" or "descend to",
            slotAlt, targetCorner.name)
        ATC.log(string.format("INBD  %-10s @%s  corner=%d(%s) trueHdg=%.0f magHdg=%d alt=%d  vector:[%s]",
            unitName, airbaseName, targetIdx, targetCorner.name, trueHdg, magHdg, slotAlt, firstVectorLine))
    end
    local response = string.format(
        "%s"
        .. "Radar contact. You are %s %s of %s.\n"
        .. "You are number %s for landing.%s",
        greeting,
        distStr,
        bearingText or "out",
        airbaseName,
        ATC.sequenceNumber(seqN),
        firstVectorLine)
    local responseVoice = string.format(
        "%s"
        .. "Radar contact. %s out at %s.\n"
        .. "You are number %s for landing.%s",
        greeting,
        distStr,
        altStr,
        ATC.sequenceNumber(seqN),
        firstVectorVoice)
    ATC.setPhase(unitName, airbaseName, "inbound")
    local initialCallText = string.format(
        "%s approach, %s inbound for landing.\n%s at %s.",
        airbaseName, cs, distStr, altStr)
    local initialCallVoice = string.format(
        "%s approach, %s inbound for landing.\n%s at %s.",
        airbaseName, cs, distStr, altStr)
    ATC.radioMsgCustom(rec.groupId, abPos, initialCallText, initialCallVoice, false, airbaseName, "Approach")
    local introDur = math.max(ATC.ttsDuration(initialCallVoice), 3)
    local t1       = timer.getTime() + introDur + 1.5
    local respDur  = ATC.ttsDuration(responseVoice)
    timer.scheduleFunction(function(p)
        local r  = ATC.state.aircraft[p.unitName]
        local u2 = Unit.getByName(p.unitName)
        if not r or not u2 then return nil end
        local ab2  = Airbase.getByName(p.airbaseName)
        local pos2 = ab2 and ATC.getAirbasePos(ab2) or p.abPos
        ATC.radioMsgCustom(r.groupId, pos2, p.responseText, p.responseVoice, false, p.airbaseName, "Approach")
        return nil
    end, {
        unitName=unitName,
        airbaseName=airbaseName,
        responseText=response,
        responseVoice=responseVoice,
        abPos=abPos,
    }, t1)
    timer.scheduleFunction(function(p)
        local ok, err = pcall(function()
            local r = ATC.state.aircraft[p.unitName]
            if not r or not Unit.getByName(p.unitName) then return end
            if ATC.getRunway(p.airbaseName) then
                ATC.initPatternEntry(p.unitName, p.airbaseName)
            end
        end)
        if not ok then trigger.action.outText("[DCS-ATC] initPatternEntry ERROR: " .. tostring(err), 30) end
        return nil
    end, { unitName=unitName, airbaseName=airbaseName }, t1 + respDur + 0.5)
    timer.scheduleFunction(function(p)
        local ok, err = pcall(function()
            local fs2  = ATC.state.airfields[p.airbaseName]
            if not fs2 or not fs2.rwyClear then return end
            local top  = fs2.landingSeq and fs2.landingSeq[1]
            local topR = top and ATC.state.aircraft[top]
            if topR and not (topR.landingCleared and topR.landingCleared[p.airbaseName]) then
                ATC.checkAndClearNext(p.airbaseName)
            end
        end)
        if not ok then trigger.action.outText("[DCS-ATC] clearNext ERROR: " .. tostring(err), 30) end
        return nil
    end, { airbaseName=airbaseName }, t1 + respDur + 6)
end
function ATC.onTowerContact(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local rwy = ATC.getRunway(airbaseName)
    local freqLabel = formatControllerFreq(rwy, "Tower")
    ATC.msg(rec.groupId, string.format(
        "%s\nMonitor %s.",
        preamble(unitName, airbaseName, "Tower"), freqLabel))
end

function ATC.onTaxiRequest(arg)
    local unitName    = arg.unitName
    local unit = Unit.getByName(unitName)
    if not unit or not ATC.isPlayer(unit) then return end
    local rec     = ATC.state.aircraft[unitName]
    local cs      = unit:getCallsign() or ""
    local groupId = rec and rec.groupId or (unit:getGroup() and unit:getGroup():getID())
    if not groupId then return end
    local airfield  = (rec and rec.engagedField) or arg.airbaseName or "Kobuleti"
    local rwy       = ATC.runways and ATC.runways[airfield]
    local rwyHdg    = rwy and rwy.hdg        or 70
    local rwyRec    = rwy and rwy.reciprocal or 250
    local ab       = Airbase.getByName(airfield)
    local abPos    = ab and ATC.getAirbasePos(ab)
    local windDir, windSpd = ATC.getWind(abPos)
    local heavy = arg.heavy or (rec and rec.heavy)
    local bestRwy
    if heavy then
        bestRwy = string.format("%02d", math.floor((rwyRec + 5) / 10))
    else
        local function headwind(hdg)
            local diff = math.abs(hdg - windDir)
            if diff > 180 then diff = 360 - diff end
            return windSpd * math.cos(math.rad(diff))
        end
        if headwind(rwyHdg) >= headwind(rwyRec) then
            bestRwy = string.format("%02d", math.floor((rwyHdg + 5) / 10))
        else
            bestRwy = string.format("%02d", math.floor((rwyRec + 5) / 10))
        end
    end
    ATC.msg(groupId, string.format(
        "%s\nCleared to taxi, runway %s in use.\nHold short of runway %s.",
        preamble(unitName, airfield, "Ground"), bestRwy, bestRwy))
end
function ATC.onTakeoffRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
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
    else
        ATC.msg(rec.groupId, string.format(
            "%s\n"                                  ..
            "Hold short.  Number %s for departure.",
            preamble(unitName, airbaseName, "Tower"), ATC.sequenceNumber(qpos)))
        ATC.setEngagedField(unitName, airbaseName)
    end
end
function ATC.onReadyDeparture(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or ""
    ATC.msg(rec.groupId, string.format(
        "%s\n"                                 ..
        "Roger, standby.\n"                    ..
        "Expect takeoff clearance shortly.",
        preamble(unitName, airbaseName, "Tower")))
end
function ATC.onPositionReport(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    if ATC.handlePatternReport and ATC.handlePatternReport(unitName, airbaseName) then
        return
    end
    local cs     = unit:getCallsign() or ""
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    local altFt  = ATC.getAltFt(unit)
    local spdKt  = ATC.getSpeedKt(unit)
    local seqN   = ATC.seqPos(unitName, airbaseName)
    local distStr = distNM and string.format("%.1f NM", distNM) or "unknown"
    local altStr  = altFt  and string.format("%d ft",   altFt)  or "unknown"
    local spdStr  = spdKt  and string.format("%d kt",   spdKt)  or "unknown"
    local seqStr  = seqN > 0 and ("  Number " .. ATC.sequenceNumber(seqN) .. ".") or ""
    ATC.msg(rec.groupId, string.format(
        "%s\n"                           ..
        "Position: %s from field.\n"     ..
        "Altitude: %s.  Speed: %s.%s",
        preamble(unitName, airbaseName, getController(unitName, airbaseName)),
        distStr, altStr, spdStr, seqStr))
end
function ATC.onWilco(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or ""
    ATC.msg(rec.groupId, string.format(
        "%swilco.", preamble(unitName, airbaseName, getController(unitName, airbaseName))))
end
function ATC.onGoAround(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
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
        preamble(unitName, airbaseName, "Tower"), ATC.sequenceNumber(newSeqN)))
    ATC.setPhase(unitName, airbaseName, "goaround")
    if rec.gearReminded    then rec.gearReminded[airbaseName]    = nil end
    if rec.lastGSDev       then rec.lastGSDev[airbaseName]       = nil end
    if rec.handedOffToTower then rec.handedOffToTower[airbaseName] = nil end
    if rec.approachGate    then rec.approachGate[airbaseName]    = nil end
    if rec.landingCleared  then rec.landingCleared[airbaseName]  = nil end
    if rec.stackAlt        then rec.stackAlt[airbaseName]        = nil end
    if rec.patternAdv      then rec.patternAdv[airbaseName]      = nil end
    if rec.holdPhase       then rec.holdPhase[airbaseName]       = nil end
    if rec.postLandingReady then rec.postLandingReady[airbaseName] = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    fs.rwyClear = true
    ATC.checkAndClearNext(airbaseName)
end
function ATC.onVacatingRunway(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or ""
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
    if rec.gearReminded then rec.gearReminded[airbaseName] = nil end
    if rec.handedOffToTower then rec.handedOffToTower[airbaseName] = nil end
    if rec.approachGate then rec.approachGate[airbaseName] = nil end
    if rec.stackAlt then rec.stackAlt[airbaseName] = nil end
    if rec.landingCleared then rec.landingCleared[airbaseName] = nil end
    if rec.patternAdv then rec.patternAdv[airbaseName] = nil end
    if rec.holdPhase  then rec.holdPhase[airbaseName]  = nil end
    if rec.postLandingReady then rec.postLandingReady[airbaseName] = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    ATC.setPhase(unitName, airbaseName, "parked")
    ATC.clearEngagement(unitName)
    ATC.checkAndClearNext(airbaseName)
end
function ATC.onEmergency(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs     = unit:getCallsign() or ""
    local ab     = Airbase.getByName(airbaseName)
    local altFt  = ATC.getAltFt(unit)
    local distNM = ATC.distUnitToBase(unit, ab)
    local fs     = ATC.getFieldState(airbaseName)
    local altStr  = altFt  and string.format(" at %d ft",    altFt)  or ""
    local distStr = distNM and string.format(", %.1f NM out", distNM) or ""
    ATC.msg(rec.groupId, string.format(
        "MAYDAY ACKNOWLEDGED  --  %s\n"               ..
        "----------------------------------------\n"  ..
        "%s%s.\n"                                     ..
        "Runway cleared for immediate approach.\n"    ..
        "Emergency services on standby.\n"            ..
        "State your emergency and intentions.",
        cs, preamble(unitName, airbaseName, "Tower"), altStr .. distStr),
        true)
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
function ATC.checkAndClearNext(airbaseName)
    local fs = ATC.state.airfields[airbaseName]
    if not fs or not fs.rwyClear then return end
    if #fs.landingSeq == 0 then return end
    local nextName = fs.landingSeq[1]
    local nextUnit = Unit.getByName(nextName)
    local ab       = Airbase.getByName(airbaseName)
    if nextUnit and ab then
        local distNM = ATC.distUnitToBase(nextUnit, ab)
        local handoffNM = ATC.config.ilsHandoffNM or 8
        if distNM and distNM > handoffNM then return end
    end
    local nextRec  = ATC.state.aircraft[nextName]
    if not nextRec then return end
    local nextCs = (nextUnit and nextUnit:getCallsign()) or ""
    local abPos  = ab and ATC.getAirbasePos(ab)
    local rwyC      = ATC.runways and ATC.runways[airbaseName]
    local towerFreq  = rwyC and rwyC.frequencies and rwyC.frequencies.tower
    local freqStr    = towerFreq and (towerFreq.mhz .. " MHz") or "Tower frequency"
    local holdSpeedKt = (ATC.config and ATC.config.holdSpeedKt) or 300
    ATC.radioMsg(nextRec.groupId, abPos, string.format(
        "%s"                                                       ..
        "Cleared for the approach.  "                             ..
        "Contact %s Tower on %s, report final.",
        preamble(nextName, airbaseName, "Approach"), airbaseName, freqStr), false, airbaseName, "Approach")
    if not nextRec.landingCleared then nextRec.landingCleared = {} end
    nextRec.landingCleared[airbaseName] = true
    ATC.setPhase(nextName, airbaseName, "approach")
    local rwyC  = ATC.runways and ATC.runways[airbaseName]
    local elev  = (rwyC and rwyC.elevation) or 0
    for i = 2, #fs.landingSeq do
        local wName = fs.landingSeq[i]
        local wRec  = ATC.state.aircraft[wName]
        local wUnit = Unit.getByName(wName)
        if wRec and wUnit and wRec.stackAlt then
            local oldAlt = wRec.stackAlt[airbaseName]
            if oldAlt then
                local newAlt = math.max(elev + ATC.config.holdAglBase, oldAlt - ATC.config.holdAglSep)
                if newAlt ~= oldAlt then
                    wRec.stackAlt[airbaseName] = newAlt
                    if fs.holdStack then fs.holdStack[wName] = newAlt end
                    if abPos then
                        ATC.radioMsg(wRec.groupId, abPos, string.format(
                            "%sDescend to %d ft.  Maintain %d kt.",
                            controllerCall(wName, airbaseName, "Approach"),
                            newAlt, holdSpeedKt), true, airbaseName, "Approach")
                    end
                end
            end
        end
    end
end
function ATC.onStartupRequest(arg)
    local unitName = arg.unitName
    local unit = Unit.getByName(unitName)
    if not unit or not ATC.isPlayer(unit) then return end
    local rec = ATC.state.aircraft[unitName]
    local cs  = unit:getCallsign() or ""
    ATC.msg(rec and rec.groupId or (unit:getGroup() and unit:getGroup():getID()),
        string.format("%s\nStartup clearance granted. Contact ground when ready to taxi.", cs))
end
function ATC.onDepartureContact(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local cs = unit:getCallsign() or ""
    local dir     = rec.departureDirection or "north"
    local heading = ({ north=360, east=90, south=180, west=270 })[dir] or 360
    ATC.msg(rec.groupId, string.format(
        "%s\nDeparture, fly heading %03d, climb to 5000 ft.", cs, heading))
    ATC.setPhase(unitName, airbaseName, "departure")
    ATC.setEngagedField(unitName, airbaseName)
end
