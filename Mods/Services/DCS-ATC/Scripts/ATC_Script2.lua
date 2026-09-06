-- Telemetry logging utility
local function logAircraftTelemetry(unitName, airbaseName)
    local unit = Unit.getByName(unitName)
    if not unit then return end
    local pos = unit:getPoint()
    local alt = ATC.getAltAglFt(unit)
    local spd = ATC.getSpeedKt(unit)
    local hdg = (unit.getHeading and unit:getHeading()) or 0
    local aoa = (unit.getAngleOfAttack and unit:getAngleOfAttack()) or 0
    local t = timer.getTime()
    local logDir = lfs.writedir() .. "/DCS-ATC-Telemetry/"
    local logFile = logDir .. string.format("%s_%s.log", unitName, airbaseName)
    -- Ensure directory exists
    lfs.mkdir(logDir)
    local f = io.open(logFile, "a")
    if f then
        f:write(string.format("%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n", t, alt or 0, spd or 0, hdg or 0, aoa or 0, pos and pos.y or 0))
        f:close()
    end
end

-- Periodic telemetry logger for all aircraft in inbound/landing
local function scheduleTelemetryLogging()
    for unitName, rec in pairs(ATC.state.aircraft) do
        if rec and rec.phases then
            for abName, phase in pairs(rec.phases) do
                if phase == "inbound" or phase == "landing" or phase == "approach" then
                    logAircraftTelemetry(unitName, abName)
                end
            end
        end
    end
    -- Schedule next log in 5 seconds
    timer.scheduleFunction(function() scheduleTelemetryLogging() return nil end, nil, timer.getTime() + 5)
end

-- Start telemetry logging on sim start
if not ATC._telemetryLoggingStarted then
    ATC._telemetryLoggingStarted = true
    scheduleTelemetryLogging()
end
ATC = ATC or {}
local function formatControllerFreq(rwy, controllerName)
    local key = controllerName and string.lower(controllerName) or nil
    local freq = key and rwy and rwy.frequencies and rwy.frequencies[key]
    if freq and freq.mhz then
        return string.format("%s %.3f MHz", controllerName, freq.mhz)
    end
    return controllerName
end

local function addFrequencyInfoCommands(gid, menuPath, rwy)
    if not gid or not menuPath or not rwy then return end
    local order = { "Tower", "Approach", "Ground", "Departure" }
    for _, controllerName in ipairs(order) do
        local key = string.lower(controllerName)
        local enabled = rwy.controllers and rwy.controllers[key]
        local freq = rwy.frequencies and rwy.frequencies[key]
        if enabled and freq and freq.mhz then
            missionCommands.addCommandForGroup(
                gid,
                string.format("[Freq] %s %.3f MHz", controllerName, freq.mhz),
                menuPath,
                function() end,
                nil
            )
        end
    end
end

function ATC.onToggleVoiceDebug(arg)
    local unitName = arg and arg.unitName
    local rec = unitName and ATC.state.aircraft[unitName]
    if not rec then return end
    ATC.config.voiceDebug = not ATC.config.voiceDebug
    local state = ATC.config.voiceDebug and "ON" or "OFF"
    ATC.msg(rec.groupId, "[ATC] Voice debug " .. state .. ".")
    ATC.buildFullMenu(unitName)
end

function ATC.onVoiceDebugCheck(arg)
    local unitName = arg and arg.unitName
    local airbaseName = arg and arg.airbaseName
    local rec = unitName and ATC.state.aircraft[unitName]
    if not rec or not airbaseName then return end

    local rwy = ATC.getRunway(airbaseName)
    local telem = ATC.state.telemetry and ATC.state.telemetry[unitName]
    local radios = telem and telem.radios or {}
    local radioParts = {}
    for idx = 1, 4 do
        local f = radios[idx]
        if f then
            radioParts[#radioParts + 1] = string.format("R%d=%.3f", idx, f)
        end
    end
    local hasRadioData = (#radioParts > 0)
    local radioText = (#radioParts > 0) and table.concat(radioParts, ", ") or "none"

    local lines = { "[ATC DEBUG] Voice check for " .. airbaseName, "Radios: " .. radioText }
    local roles = { "ground", "tower", "approach", "departure" }
    for _, role in ipairs(roles) do
        local freq = rwy and rwy.frequencies and rwy.frequencies[role]
        if freq and freq.mhz then
            if not hasRadioData then
                lines[#lines + 1] = string.format("%s %.3f MHz -> NO RADIO DATA", role:upper(), freq.mhz)
            else
                local ok = ATC.isOnFrequency(unitName, airbaseName, role, { allowNoRadioBypass = false })
                lines[#lines + 1] = string.format("%s %.3f MHz -> %s", role:upper(), freq.mhz, ok and "TUNED" or "NOT TUNED")
            end
        else
            lines[#lines + 1] = string.format("%s (missing)", role:upper())
        end
    end

    ATC.msg(rec.groupId, table.concat(lines, "\n"), true)
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

local function getMissionQnhHpa()
    local weather = env and env.mission and env.mission.weather
    local qnh = weather and weather.qnh
    if type(qnh) ~= "number" then
        return 1013.25
    end
    if qnh > 2000 then
        return qnh / 100.0   -- raw Pa → hPa
    end
    if qnh > 800 then
        return qnh            -- already hPa
    end
    if qnh > 200 then
        return qnh * 1.33322  -- mmHg → hPa
    end
    return 1013.25
end

local function getQfeHpa(rwy)
    local qnhHpa = getMissionQnhHpa()
    local elevFt = (rwy and rwy.elevation) or 0
    local elevM = elevFt * 0.3048
    local ratio = 1.0 - (elevM / 44330.0)
    if ratio < 0.01 then ratio = 0.01 end
    local qfe = qnhHpa * (ratio ^ 5.255)
    return math.floor(qfe + 0.5)
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
    -- Normalize all airfield names for robust lookup
    if abName then
        local norm = abName:lower():gsub("[^%w]", "")
        -- Find the canonical key in ATC.runways
        for key, _ in pairs(ATC.runways or {}) do
            if key:lower():gsub("[^%w]", "") == norm then
                abName = key
                break
            end
        end
    end
    local distKm = math.floor(fieldEntry.distM / 1000 + 0.5)
    local rwy    = ATC.getRunway(abName)
    local freqStr = (rwy and rwy.frequencies and rwy.frequencies.approach)
                    and ("  APP " .. rwy.frequencies.approach.mhz) or ""
    local label  = abName .. "  (" .. distKm .. " km)" .. freqStr
    local gid    = rec.groupId
    ATC.clearFieldMenu(unitName, abName)
    local fieldMenu = missionCommands.addSubMenuForGroup(gid, label, rec.menuRoot)
    rec.fieldMenus[abName] = fieldMenu
    addFrequencyInfoCommands(gid, fieldMenu, rwy)
    missionCommands.addCommandForGroup(gid, "Debug Voice Check",
        fieldMenu, function(a) ATC.onVoiceDebugCheck(a) end, { unitName = unitName, airbaseName = abName })
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
        -- Offered on engagement, not gated on towerHandoffReady. Gating on it
        -- meant an arrival that never captured a CRP saw neither item and had
        -- no way to request landing. Matches buildFullMenu.
        local towerCheckedIn = rec.towerCheckedIn and rec.towerCheckedIn[abName]
        if not towerCheckedIn then
            missionCommands.addCommandForGroup(gid, "Contact Tower",
                fieldMenu, function(a) ATC.onHandoffToTower(a) end, arg)
        else
            missionCommands.addCommandForGroup(gid, "Request Landing",
                fieldMenu, function(a) ATC.onRequestLanding(a) end, arg)
        end
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
        local safeUnitName = tostring(unitName or 'nil')
        local safeAirbaseName = tostring((arg and arg.airbaseName) or 'nil')
        ATC.log(string.format("MENU: Adding 'Request Landing / Inbound' for unit=%s airbase=%s", safeUnitName, safeAirbaseName))
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
        local safeUnitName2 = tostring(unitName or 'nil')
        local safeAbName = tostring(abName or 'nil')
        local safeInAir = tostring(inAir or 'nil')
        local safeDistM = tonumber(fieldEntry.distM) or -1
        ATC.log(string.format("BUILD_FIELD_MENU: unit=%s ab=%s inAir=%s distM=%.1f", safeUnitName2, safeAbName, safeInAir, safeDistM))
end
function ATC.buildFullMenu(unitName)
    ATC.log("BUILD_FULL_MENU: called for unit=" .. tostring(unitName))
    if ATC and ATC.state and ATC.state.aircraft and ATC.state.aircraft[unitName] then
        local rec = ATC.state.aircraft[unitName]
        ATC.log("BUILD_FULL_MENU: engagedField=" .. tostring(rec.engagedField))
    end
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
    missionCommands.addCommandForGroup(rec.groupId,
        "Voice Debug: " .. (ATC.config.voiceDebug and "ON" or "OFF"),
        root, ATC.onToggleVoiceDebug, { unitName = unitName })
    if rec.engagedField then
        local ab = Airbase.getByName(rec.engagedField)
        if ab then
            local abName = rec.engagedField
            local abPos  = ATC.getAirbasePos(ab)
            local distM  = (abPos and uPos) and ATC.distVec3H(uPos, abPos) or 0
            local ph     = ATC.getPhase(unitName, abName)
            local arrivalEngaged  = isArrivalEngaged(rec, abName, ph)
            local postLandingReady = rec.postLandingReady and rec.postLandingReady[abName]
            local inAir  = unit:inAir()
            local spdKt  = ATC.getSpeedKt(unit)
            local arg    = { unitName = unitName, airbaseName = abName }

            if postLandingReady and not inAir and spdKt and spdKt <= 50 then
                -- Landed and slowed: single action to vacate
                missionCommands.addCommandForGroup(rec.groupId,
                    "Vacate Runway and Contact Ground",
                    root, function(a) ATC.onVacatingRunway(a) end, arg)

            elseif arrivalEngaged then
                -- In-flight arrival: flat items directly at ATC root
                local towerCheckedIn = rec.towerCheckedIn and rec.towerCheckedIn[abName]
                if not towerCheckedIn then
                    missionCommands.addCommandForGroup(rec.groupId,
                        "Handoff to Tower",
                        root, function(a) ATC.onHandoffToTower(a) end, arg)
                else
                    missionCommands.addCommandForGroup(rec.groupId,
                        "Request Landing",
                        root, function(a) ATC.onRequestLanding(a) end, arg)
                end
                missionCommands.addCommandForGroup(rec.groupId,
                    "Cancel Request",
                    root, ATC.onCancelRequest, arg)

            else
                -- Ground / departure: keep the per-field sub-menu
                local fe = { ab = ab, distM = distM, name = abName }
                ATC.log("BUILD_FULL_MENU: building menu for engagedField=" .. tostring(abName))
                ATC.buildFieldMenu(unitName, fe)
                missionCommands.addCommandForGroup(rec.groupId,
                    "Cancel Request with " .. abName,
                    root, ATC.onCancelRequest, arg)
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
    ATC.log("BUILD_FULL_MENU: nearby airfields count=" .. tostring(#nearby))
    for i, fe in ipairs(nearby) do
        ATC.log(string.format("BUILD_FULL_MENU: nearby[%d]=%s distM=%.1f", i, tostring(fe.name), tonumber(fe.distM or -1)))
    end
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
        ATC.log("BUILD_FULL_MENU: building field menu for " .. tostring(fe.name))
        ATC.buildFieldMenu(unitName, fe)
    end
end
function ATC.setPhase(unitName, airbaseName, newPhase)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    if not rec.phases then rec.phases = {} end
    rec.phases[airbaseName] = newPhase
    ATC.buildFullMenu(unitName)
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
        ATC.releaseRunway(field, unitName)
        if rec.stackAlt       then rec.stackAlt[field]       = nil end
        if rec.approachGate   then rec.approachGate[field]   = nil end
        if rec.landingCleared then rec.landingCleared[field]  = nil end
        if rec.patternAdv     then rec.patternAdv[field]     = nil end
        if rec.holdPhase      then rec.holdPhase[field]      = nil end
        if rec.report15Done   then rec.report15Done[field]   = nil end
        if rec.report15ReminderSent then rec.report15ReminderSent[field] = nil end
        if rec.towerHandoffReady then rec.towerHandoffReady[field] = nil end
        if rec.towerCheckedIn then rec.towerCheckedIn[field] = nil end
        if rec.postLandingReady then rec.postLandingReady[field] = nil end
    end
    ATC.buildFullMenu(unitName)
end
local function preamble(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = (unit and unit:getCallsign()) or unitName or "Unknown"
    local field = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName or "Airfield"
    local ctrl  = controller or "Tower"
    return string.format("%s, %s %s.", cs, field, ctrl)
end
local function controllerCall(unitName, airbaseName, controller)
    local unit = Unit.getByName(unitName)
    local cs   = (unit and unit:getCallsign()) or unitName or "Unknown"
    local field = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName or "Airfield"
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

local function checkFrequencyAndRespond(unitName, airbaseName, controller, rec)
    -- Validate that player is on the correct frequency
    -- If not, send tuning instruction and return true (to skip further processing)
    -- Uses cooldown to silence duplicate rejections (same controller type within 10 sec)
    if not unitName or not airbaseName or not controller or not rec then return false end
    
    if not ATC.isOnFrequency(unitName, airbaseName, string.lower(controller)) then
        local ctrlLower = string.lower(controller)
        local now = timer.getTime()
        
        -- Cooldown: only send rejection message once per controller type per 10 seconds
        rec.lastFreqRejection = rec.lastFreqRejection or {}
        local lastRejAt = rec.lastFreqRejection[ctrlLower] or 0
        
        if (now - lastRejAt) > 10.0 then
            local rwy = ATC.getRunway(airbaseName)
            local freq = rwy and rwy.frequencies and rwy.frequencies[ctrlLower]
            local unit = Unit.getByName(unitName)
            local cs = unit and unit:getCallsign() or ""
            local spokenField = ATC.getSpokenAirbaseName(airbaseName) or airbaseName
            
            if freq and freq.mhz then
                ATC.msg(rec.groupId, 
                    cs .. ", we read you but you are not on " .. spokenField .. " " .. controller .. 
                    " frequency. Tune " .. string.format("%.1f", freq.mhz) .. " MHz.",
                    true, airbaseName, controller)
            else
                ATC.msg(rec.groupId, cs .. ", check your frequency.", true, airbaseName, controller)
            end
            rec.lastFreqRejection[ctrlLower] = now
        end
        return true  -- Skip further processing
    end
    return false  -- Frequency is OK, continue
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
    local safeUnitName3 = tostring(unitName or 'nil')
    local safeAirbaseName2 = tostring(airbaseName or 'nil')
    ATC.log(string.format("INBD_HANDLER: called for unit=%s airbase=%s", safeUnitName3, safeAirbaseName2))
    local rec  = ATC.state.aircraft[unitName]
    if not rec then ATC.log("INBD_HANDLER: no rec for unit " .. tostring(unitName)); return end
    if not ATC._timersStarted then ATC.onSimStart() end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then ATC.log("INBD_HANDLER: not a player unit"); return end
    
    -- Frequency check: Player must be on Approach frequency (with cooldown to silence duplicates)
    if not ATC.isOnFrequency(unitName, airbaseName, "approach") then
        ATC.log("INBD_HANDLER: not on approach frequency")
        local now = timer.getTime()
        rec.lastFreqRejection = rec.lastFreqRejection or {}
        local lastRejAt = rec.lastFreqRejection["approach"] or 0
        if (now - lastRejAt) > 10.0 then
            local rwy = ATC.getRunway(airbaseName)
            local approachFreq = rwy and rwy.frequencies and rwy.frequencies["approach"] and rwy.frequencies["approach"].mhz
            local spokenField = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName
            local cs = unit:getCallsign() or ""
            if approachFreq then
                ATC.msg(rec.groupId, 
                    cs .. ", we read you but you are not on " .. spokenField .. " Approach frequency. Tune " .. 
                    string.format("%.1f", approachFreq) .. " MHz and call back.", 
                    true, airbaseName, "Approach")
            else
                ATC.msg(rec.groupId, cs .. ", try again on proper frequency.", true, airbaseName, "Approach")
            end
            rec.lastFreqRejection["approach"] = now
        end
        return
    end
    
    local cs     = unit:getCallsign() or ""
    local fs     = ATC.getFieldState(airbaseName)
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    local altFt  = ATC.getAltAglFt(unit)
    local spokenField = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName
    -- Outside-airspace check: >50 NM → play single OGG and disengage
    if distNM and distNM > 50 then
        local abPos2 = ab and ATC.getAirbasePos and ATC.getAirbasePos(ab)
        -- Voice text = only the compound token so the single OGG plays once cleanly.
        -- The full sentence is shown on screen; the OGG already contains the full phrase.
        ATC.radioMsgCustom(rec.groupId, abPos2,
            "You are outside my airspace. Contact me again within 50 miles.",
            "outside my airspace",
            false, airbaseName, "Approach")
        return
    end
    local safePatternCornerIdx = tostring((rec.patternCornerIdx and rec.patternCornerIdx[airbaseName]) or 'nil')
    local safePhases = tostring((rec.phases and rec.phases[airbaseName]) or 'nil')
    ATC.log(string.format("INBD_HANDLER: state: patternCornerIdx=%s, phases=%s", safePatternCornerIdx, safePhases))
    rec.report15Done = rec.report15Done or {}
    rec.report15ReminderSent = rec.report15ReminderSent or {}
    rec.towerHandoffReady = rec.towerHandoffReady or {}
    rec.towerCheckedIn = rec.towerCheckedIn or {}
    rec.report15Done[airbaseName] = nil
    rec.report15ReminderSent[airbaseName] = nil
    rec.towerHandoffReady[airbaseName] = nil
    rec.towerCheckedIn[airbaseName] = nil
    local seqN   = ATC.addToLandingSeq(unitName, airbaseName)
    rec.seqNum[airbaseName] = seqN
    if rec.postLandingReady then rec.postLandingReady[airbaseName] = nil end
    ATC.setEngagedField(unitName, airbaseName)
    local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
    local altStr  = altFt  and string.format("%d ft",   altFt)  or "altitude unknown"
    rec.greeted[airbaseName] = rec.greeted[airbaseName] or {}
    local greeting = ""
    if not rec.greeted[airbaseName]["Approach"] then
        greeting = ATC.getDaytimeGreeting() .. ", " .. cs .. ", " .. spokenField .. " Approach.\n"
        rec.greeted[airbaseName]["Approach"] = true
    else
        greeting = cs .. ", " .. spokenField .. " Approach.\n"
    end
    local firstVectorLine = ""
    local firstVectorVoice = ""
    local rwy     = ATC.getRunway(airbaseName)
    local corners = rwy and ATC.getPatternCorners(rwy, airbaseName)
    local abPos = ATC.getAirbasePos(ab)
    local uPos = unit:getPoint()
    local bearingText = (abPos and uPos and ATC.getBearingText(abPos, uPos)) or nil
    local safeCorners = corners and #corners or 0
    ATC.log(string.format("INBD_HANDLER: corners=%d", safeCorners))
    do
        local rwType = type(ATC.runways)
        local rwCount = (rwType == "table") and (function() local n=0; for _ in pairs(ATC.runways) do n=n+1 end; return n end)() or 0
        local rwHit   = (rwType == "table") and tostring(ATC.runways[airbaseName] ~= nil) or "N/A"
        local safeUnitName4 = tostring(unitName or 'nil')
        local safeAirbaseName3 = tostring(airbaseName or 'nil')
        local safeRwType = tostring(rwType or 'nil')
        local safeRwCount = tonumber(rwCount) or 0
        local safeRwHit = tostring(rwHit or 'nil')
        local safeRwy = rwy and "ok" or "NIL"
        local safeCorners2 = corners and tostring(#corners) or "NIL"
        local safeDistStr = tostring(distStr or 'nil')
        ATC.log(string.format("INBD  %-10s @%s  runways=%s(keys=%d) hit=%s  rwy=%s  corners=%s  dist=%s",
            safeUnitName4, safeAirbaseName3,
            safeRwType, safeRwCount, safeRwHit,
            safeRwy,
            safeCorners2,
            safeDistStr))
    end
    if corners and #corners > 0 then
        local ctrlNm  = (rwy and rwy.ctrlZoneNm) or 8
        local slotAlt = ATC.assignPatternSlot(unitName, airbaseName)
        rec.patternAlt[airbaseName]       = slotAlt
        rec.lastVector[airbaseName]       = timer.getTime()
        -- Always start at CRP1 on inbound if not set or out of bounds
        local idx = rec.patternCornerIdx[airbaseName]
        if not idx or idx < 1 or idx > #corners then
            idx = 1
            rec.patternCornerIdx[airbaseName] = 1
        end
        local currCRP = corners[idx]
        -- If close to current CRP, increment to next (but never skip CRP5)
        if currCRP and currCRP.pos and uPos and ATC.mToNM(ATC.distVec3H(uPos, currCRP.pos)) < 1.0 and idx < #corners then
            idx = idx + 1
            rec.patternCornerIdx[airbaseName] = idx
            currCRP = corners[idx]
        end
        -- If at CRP5 (seq==5 or marked isCP5), next vector is to final
        local currSeq = currCRP and currCRP.seq
        ATC.log(string.format("INBD_DEBUG: idx=%d currSeq=%s currName=%s", idx, tostring(currSeq or 'nil'), tostring(currCRP and currCRP.name or 'nil')))
        if currCRP and (currCRP.isCP5 or currCRP.seq == 5) then
            local rwyPos = abPos
            local trueHdg = hdgTo(uPos, rwyPos)
            local magHdg  = ATC.roundHdg(ATC.toMag(trueHdg))
            local legDistNm = ATC.mToNM(ATC.distVec3H(uPos, rwyPos))
            local turnDir
            local vel = unit:getVelocity()
            if vel then
                local currHdg = math.deg(math.atan2(vel.z, vel.x))
                if currHdg < 0 then currHdg = currHdg + 360 end
                local diff = angleDiff(currHdg, trueHdg)
                if math.abs(diff) > 45 then
                    turnDir = diff > 0 and "Turn RIGHT" or "Turn LEFT"
                else
                    turnDir = "Fly"
                end
            else
                turnDir = "Fly"
            end
            firstVectorLine = string.format(
                "\n%s final heading %s for %d miles, %s %d ft. Contact tower.",
                turnDir, ATC.fmtHdg(magHdg),
                math.max(1, math.floor(legDistNm + 0.4)),
                (slotAlt > (ATC.getAltFt(unit) or 0)) and "climb to" or "descend to",
                slotAlt)
            firstVectorVoice = firstVectorLine
            ATC.log(string.format("INBD  %-10s @%s  FINAL vector: trueHdg=%.0f magHdg=%d alt=%d  vector:[%s]",
                unitName, airbaseName, trueHdg, magHdg, slotAlt, firstVectorLine))
        else
            -- Vector to current CRP
            local trueHdg = hdgTo(uPos, currCRP.pos)
            local magHdg  = ATC.roundHdg(ATC.toMag(trueHdg))
            local legDistNm = ATC.mToNM(ATC.distVec3H(uPos, currCRP.pos))
            local turnDir
            local vel = unit:getVelocity()
            if vel then
                local currHdg = math.deg(math.atan2(vel.z, vel.x))
                if currHdg < 0 then currHdg = currHdg + 360 end
                local diff = angleDiff(currHdg, trueHdg)
                if math.abs(diff) > 45 then
                    turnDir = diff > 0 and "Turn RIGHT" or "Turn LEFT"
                else
                    turnDir = "Fly"
                end
            else
                turnDir = "Fly"
            end
            firstVectorLine = string.format(
                "\n%s heading %s for %d miles, %s %d ft.",
                turnDir, ATC.fmtHdg(magHdg),
                math.max(1, math.floor(legDistNm + 0.4)),
                (slotAlt > (ATC.getAltFt(unit) or 0)) and "climb to" or "descend to",
                slotAlt)
            firstVectorVoice = firstVectorLine
            ATC.log(string.format("INBD  %-10s @%s  CRP=%d(%s) trueHdg=%.0f magHdg=%d alt=%d  vector:[%s]",
                unitName, airbaseName, idx, currCRP.name, trueHdg, magHdg, slotAlt, firstVectorLine))
        end
    else
        firstVectorLine = "\nUnable to provide pattern vector: no pattern corners defined."
        firstVectorVoice = firstVectorLine
        ATC.log(string.format("INBD  %-10s @%s  ERROR: No pattern corners for runway.", unitName, airbaseName))
    end
    local qfeHpa = getQfeHpa(rwy)
    local qfeInHg = qfeHpa * 0.02953
    local isRussian = isRussianAircraft(unitName)
    local qfeText
    if isRussian then
        qfeText = string.format("QFE %d.", qfeHpa)
    else
        qfeText = string.format("QFE %.2f.", qfeInHg)
    end
    local response = string.format(
        "%s"
        .. "Radar contact. You are %s %s of %s.\n"
        .. "%s\n"
        .. "You are number %s for landing.%s",
        greeting,
        distStr,
        bearingText or "out",
        spokenField,
        qfeText,
        ATC.sequenceNumber(seqN),
        firstVectorLine)
    local responseVoice = string.format(
        "%s"
        .. "Radar contact. "
        .. "You are %s %s of %s. "
        .. "%s "
        .. "You are number %s for landing.%s",
        greeting,
        distStr,
        bearingText or "",
        spokenField,
        qfeText,
        ATC.sequenceNumber(seqN),
        firstVectorVoice)
    ATC.setPhase(unitName, airbaseName, "inbound")
    local initialCallText = string.format(
        "%s approach, %s inbound for landing.\n%s at %s.",
        spokenField, cs, distStr, altStr)
    -- Show pilot's call as text only — no voice, fixed 3 s display
    trigger.action.outTextForGroup(rec.groupId, initialCallText, 3, false)
    local t1 = timer.getTime() + 4.5
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
    -- Nothing else is scheduled here. The CRP1 vector is built into the reply
    -- above so it arrives as one transmission, and the sequence number was
    -- already assigned by addToLandingSeq -- there is nothing for
    -- checkAndClearNext to renumber at this point.
end

function ATC.onHandoffToTower(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    
    -- Frequency check: Player must be on Tower frequency to contact tower
    if not ATC.isOnFrequency(unitName, airbaseName, "tower") then
        local rwy = ATC.getRunway(airbaseName)
        local freq = rwy and rwy.frequencies and rwy.frequencies.tower
        local cs = unit:getCallsign() or ""
        local fieldName = ATC.getSpokenAirbaseName(airbaseName) or airbaseName
        
        if freq and freq.mhz then
            ATC.msg(rec.groupId, 
                cs .. ", Tower frequency is " .. string.format("%.1f", freq.mhz) .. " MHz. Standby.",
                true, airbaseName, "Tower")
        else
            ATC.msg(rec.groupId, cs .. ", check your frequency.", true, airbaseName, "Tower")
        end
        return
    end
    
    local rwy = ATC.getRunway(airbaseName)
    local towerFreq = rwy and rwy.frequencies and rwy.frequencies.tower
    local freqStr = towerFreq and string.format("%.3f MHz", towerFreq.mhz) or "tower frequency"
    local cs = unit:getCallsign() or unitName or "Unknown"
    local fieldName = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName
    rec.towerCheckedIn = rec.towerCheckedIn or {}
    rec.towerCheckedIn[airbaseName] = true
    rec.handedOffToTower = rec.handedOffToTower or {}
    rec.handedOffToTower[airbaseName] = true
    local ab = Airbase.getByName(airbaseName)
    local abPos = ab and ATC.getAirbasePos(ab)
    ATC.radioMsg(rec.groupId, abPos, string.format(
        "%s, %s Tower, radar contact on %s. Report final.",
        cs, fieldName, freqStr), false, airbaseName, "Tower")
    ATC.buildFullMenu(unitName)
end

function ATC.onRequestLanding(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end

    -- If tower handoff is pending, perform tower contact first.
    local towerReady = rec.towerHandoffReady and rec.towerHandoffReady[airbaseName]
    local towerCheckedIn = rec.towerCheckedIn and rec.towerCheckedIn[airbaseName]
    if towerReady and not towerCheckedIn then
        ATC.onHandoffToTower(arg)
        towerCheckedIn = rec.towerCheckedIn and rec.towerCheckedIn[airbaseName]
        if not towerCheckedIn then return end
    end
    
    -- Frequency check: Player must be on Tower frequency
    if not ATC.isOnFrequency(unitName, airbaseName, "tower") then
        local rwy = ATC.getRunway(airbaseName)
        local freq = rwy and rwy.frequencies and rwy.frequencies.tower
        local cs = unit:getCallsign() or ""
        local fieldName = ATC.getSpokenAirbaseName(airbaseName) or airbaseName
        
        if freq and freq.mhz then
            ATC.msg(rec.groupId, 
                cs .. ", you are not on Tower frequency. Tune " .. string.format("%.1f", freq.mhz) .. " MHz.",
                true, airbaseName, "Tower")
        else
            ATC.msg(rec.groupId, cs .. ", check your frequency.", true, airbaseName, "Tower")
        end
        return
    end
    
    local cs = unit:getCallsign() or unitName or "Unknown"
    local fieldName = ATC.getSpokenAirbaseName and ATC.getSpokenAirbaseName(airbaseName) or airbaseName
    local ab = Airbase.getByName(airbaseName)
    local abPos = ab and ATC.getAirbasePos(ab)
    local rwy = ATC.getRunway(airbaseName)
    local rwyHdg = ATC.getActiveRwyHdg(airbaseName) or (rwy and rwy.hdg) or 0
    local rwyNum = ATC.rwyDesignator(rwyHdg)
    local windDir, windSpd = ATC.getWind(abPos)
    if not ATC.isRunwayClear(airbaseName, unitName) then
        ATC.radioMsg(rec.groupId, abPos, string.format(
            "%s, %s Tower, runway occupied. Hold present position, standby for landing clearance.",
            cs, fieldName), false, airbaseName, "Tower")
        return
    end
    rec.landingCleared = rec.landingCleared or {}
    rec.landingCleared[airbaseName] = true
    ATC.reserveRunway(airbaseName, unitName)
    ATC.radioMsg(rec.groupId, abPos, string.format(
        "%s, %s Tower, cleared to land runway %s, wind %03d at %d, slow to approach speed, check gear down.",
        cs, fieldName, rwyNum, windDir, windSpd), false, airbaseName, "Tower")
    ATC.buildFullMenu(unitName)
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
    local unitName = arg.unitName
    local unit = Unit.getByName(unitName)
    if not unit or not ATC.isPlayer(unit) then return end
    local rec     = ATC.state.aircraft[unitName]
    local groupId = rec and rec.groupId or (unit:getGroup() and unit:getGroup():getID())
    if not groupId then return end
    local airfield = (rec and rec.engagedField) or arg.airbaseName or "Kobuleti"
    local rwy      = ATC.runways and ATC.runways[airfield]
    local ab       = Airbase.getByName(airfield)
    local abPos    = ab and ATC.getAirbasePos(ab)

    -- Determine active runway
    local activeHdg = ATC.getActiveRwyHdg(airfield)
    activeHdg = activeHdg or (rwy and rwy.hdg) or 0
    local rwyNum = ATC.rwyDesignator(activeHdg)

    -- Taxi routing (only for airfields that have zone data)
    local routeStr = ""
    if rwy and rwy.taxiGraph and rwy.zoneLabel and rwy.holdshortZone then
        local targetZone = rwy.holdshortZone[activeHdg]
        if targetZone then
            local unitPos  = unit:getPoint()
            local fromZone = ATC.findGroundZone(unitPos, rwy)
            ATC.debugLog(string.format("TAXI  unit=%s fromZone=%s targetZone=%s", unitName, tostring(fromZone), targetZone))
            if fromZone and fromZone ~= targetZone then
                local path = ATC.planTaxiRoute(fromZone, targetZone, rwy.taxiGraph)
                if path then
                    local labels = ATC.taxiRouteLabels(path, rwy.zoneLabel)
                    if #labels > 0 then
                        -- Capitalise first letter for display; lowercase for voice tokenisation
                        local parts = {}
                        for i, lbl in ipairs(labels) do
                            parts[i] = lbl:sub(1,1):upper() .. lbl:sub(2)
                        end
                        routeStr = " via " .. table.concat(parts, ", ") .. ","
                    end
                end
            end
        end
    end

    local windDir, windSpd = ATC.getWind(abPos)
    local windStr = (windSpd > 2)
        and string.format("wind %03d at %d.", windDir, windSpd)
        or  "wind calm."
    local text = string.format(
        "%s cleared to taxi runway %s,%s hold short runway %s, %s",
        controllerCall(unitName, airfield, "Ground"),
        rwyNum, routeStr, rwyNum, windStr)
    ATC.radioMsg(groupId, abPos, text, false, airfield, "Ground")
end
function ATC.onTakeoffRequest(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local fs = ATC.getFieldState(airbaseName)
    if not ATC.isRunwayClear(airbaseName, unitName) then
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
        ATC.reserveRunway(airbaseName, unitName)
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
    
    local controller = getController(unitName, airbaseName)
    if checkFrequencyAndRespond(unitName, airbaseName, controller, rec) then return end
    
    local ab     = Airbase.getByName(airbaseName)
    local distNM = ATC.distUnitToBase(unit, ab)
    if distNM and distNM <= 15 then
        rec.report15Done = rec.report15Done or {}
        rec.report15ReminderSent = rec.report15ReminderSent or {}
        rec.report15Done[airbaseName] = true
        rec.report15ReminderSent[airbaseName] = true
    end
    if ATC.handlePatternReport and ATC.handlePatternReport(unitName, airbaseName) then
        return
    end
    local cs     = unit:getCallsign() or ""
    local altFt  = ATC.getAltAglFt(unit)
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
    if rec.towerHandoffReady then rec.towerHandoffReady[airbaseName] = nil end
    if rec.towerCheckedIn then rec.towerCheckedIn[airbaseName] = nil end
    if rec.approachGate    then rec.approachGate[airbaseName]    = nil end
    if rec.landingCleared  then rec.landingCleared[airbaseName]  = nil end
    if rec.stackAlt        then rec.stackAlt[airbaseName]        = nil end
    if rec.patternAdv      then rec.patternAdv[airbaseName]      = nil end
    if rec.holdPhase       then rec.holdPhase[airbaseName]       = nil end
    if rec.postLandingReady then rec.postLandingReady[airbaseName] = nil end
    ATC.freeStackLevel(unitName, airbaseName)
    ATC.releaseRunway(airbaseName, unitName)
    ATC.checkAndClearNext(airbaseName)
end
function ATC.onVacatingRunway(arg)
    local unitName    = arg.unitName
    local airbaseName = arg.airbaseName
    local rec  = ATC.state.aircraft[unitName]
    if not rec then return end
    local unit = Unit.getByName(unitName)
    if not ATC.isPlayer(unit) then return end
    local fs  = ATC.getFieldState(airbaseName)
    local rwy = ATC.runways and ATC.runways[airbaseName]
    local ab  = Airbase.getByName(airbaseName)
    local abPos = ab and ATC.getAirbasePos(ab)

    -- Find closest free parking spot
    local spot = ATC.getClosestParking(unit, ab)
    local spotNum = spot and spot.Term_Index

    -- Build taxi-back route if zone data available
    local routeStr = ""
    if rwy and rwy.taxiGraph and rwy.zoneLabel and rwy.parkingZone then
        local unitPos  = unit:getPoint()
        local fromZone = ATC.findGroundZone(unitPos, rwy)
        if fromZone and fromZone ~= rwy.parkingZone then
            local path = ATC.planTaxiRoute(fromZone, rwy.parkingZone, rwy.taxiGraph)
            if path then
                local labels = ATC.taxiRouteLabels(path, rwy.zoneLabel)
                if #labels > 0 then
                    local parts = {}
                    for i, lbl in ipairs(labels) do
                        parts[i] = lbl:sub(1,1):upper() .. lbl:sub(2)
                    end
                    routeStr = " via " .. table.concat(parts, ", ") .. ","
                end
            end
        end
    end

    -- Build spot text
    local spotStr = spotNum and string.format(" spot %d,", spotNum) or ""

    local text = string.format(
        "%s taxi to parking%s%s welcome to %s.",
        controllerCall(unitName, airbaseName, "Ground"),
        spotStr, routeStr, airbaseName)
    ATC.radioMsg(rec.groupId, abPos, text, false, airbaseName, "Ground")

    for i, n in ipairs(fs.landingSeq) do
        if n == unitName then table.remove(fs.landingSeq, i) break end
    end
    ATC.releaseRunway(airbaseName, unitName)
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

-- Airborne off the departure runway (S_EVENT_TAKEOFF).
-- Without this the field stays flagged occupied for the rest of the mission:
-- onTakeoffRequest reserves the runway and only the arrival paths ever released
-- it, so a single departure blocked every subsequent landing clearance.
function ATC.onDepartedRunway(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    local fs = ATC.getFieldState(airbaseName)
    for i, n in ipairs(fs.departSeq) do
        if n == unitName then table.remove(fs.departSeq, i) break end
    end
    ATC.releaseRunway(airbaseName, unitName)
    if ATC.getPhase(unitName, airbaseName) == "takeoff" then
        ATC.setPhase(unitName, airbaseName, "airborne")
    end
    ATC.log(string.format("EVNT  TAKEOFF %s @%s -> runway released", unitName, airbaseName))
    ATC.checkAndClearNext(airbaseName)
end

-- Touchdown (S_EVENT_LAND). The aircraft physically holds the runway from here
-- until it vacates, so take the reservation in its name even if the clearance
-- came from a path that did not reserve one.
function ATC.onTouchdown(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    -- Only take the runway for an aircraft actually working this field. A pilot
    -- who lands without ever calling ATC must not leave behind a reservation
    -- that no later path will release.
    if rec.engagedField ~= airbaseName then return end
    ATC.reserveRunway(airbaseName, unitName)
    ATC.setPhase(unitName, airbaseName, "landing")
    ATC.log(string.format("EVNT  LAND %s @%s -> runway held", unitName, airbaseName))
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
    local altFt  = ATC.getAltAglFt(unit)
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
-- Re-sequences the arrival queue after an aircraft leaves it (landed, vacated,
-- went around, departed) and tells anyone whose number changed.
--
-- This function does NOT issue landing clearance. In the CRP pattern that is
-- advancePatternCorner's job at CP5 (approach -> tower handoff) and
-- onRequestLanding / checkGlideslopes' job on final. It used to try to do both
-- and was unreachable as a result: it returned early whenever patternAlt was
-- set, and required patternCornerIdx to still point at CP5 -- but the CP5
-- handler clears both fields at the same moment, so neither branch could pass.
--
-- Stack separation is likewise not adjusted here. getProtectedPatternAlt already
-- keeps 1000 ft between aircraft and relaxes on its own as slots below free up;
-- issuing a descent here would be overwritten by the next CRP advance.
function ATC.checkAndClearNext(airbaseName)
    local fs = ATC.state.airfields[airbaseName]
    if not fs or #fs.landingSeq == 0 then return end
    local ab    = Airbase.getByName(airbaseName)
    local abPos = ab and ATC.getAirbasePos(ab)

    for i, wName in ipairs(fs.landingSeq) do
        local wRec  = ATC.state.aircraft[wName]
        local wUnit = Unit.getByName(wName)
        if wRec and wUnit then
            wRec.seqNum = wRec.seqNum or {}
            local prevSeq = wRec.seqNum[airbaseName]
            wRec.seqNum[airbaseName] = i
            -- Only speak up when the number actually moved, and only to traffic
            -- still being worked -- no point renumbering someone on rollout.
            if abPos and prevSeq and prevSeq ~= i and wUnit:inAir()
               and ATC.isOnFrequency(wName, airbaseName, "approach") then
                ATC.radioMsg(wRec.groupId, abPos, string.format(
                    "%syou are number %s for landing.",
                    controllerCall(wName, airbaseName, "Approach"),
                    ATC.sequenceNumber(i)), false, airbaseName, "Approach")
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

-- ─── Overlay menu JSON API ─────────────────────────────────────────────────────
-- Called by DCS-ATC-OverlayGameGUI.lua via net.dostring_in("server", ...).
-- Returns a JSON string so the overlay can render a numbered menu without F10.

local function _jStr(s)
    return '"' .. tostring(s or ""):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '') .. '"'
end

local function _jItem(item)
    local parts = {}
    for k, v in pairs(item) do
        local enc
        if     type(v) == "string"  then enc = _jStr(v)
        elseif type(v) == "boolean" then enc = v and "true" or "false"
        elseif type(v) == "number"  then enc = tostring(v)
        else                             enc = "null"
        end
        parts[#parts + 1] = _jStr(k) .. ":" .. enc
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- Build item list for a player currently engaged with an airfield.
local function _overlayEngagedItems(rec, playerName, abName)
    local items = {}
    local unit   = Unit.getByName(playerName)
    local inAir  = unit and unit:inAir() or false
    local spdKt  = unit and ATC.getSpeedKt(unit) or nil
    local ph     = ATC.getPhase(playerName, abName)
    local postLanding = rec.postLandingReady and rec.postLandingReady[abName]
    local arrived     = isArrivalEngaged(rec, abName, ph)

    local function addCmd(label, fn)
        items[#items + 1] = {
            kind  = "cmd",
            label = label,
            cmd   = string.format("ATC.%s({unitName=%s,airbaseName=%s})",
                        fn, _jStr(playerName), _jStr(abName)),
        }
    end

    if postLanding and not inAir and spdKt and spdKt <= 50 then
        addCmd("Vacate Runway and Contact Ground", "onVacatingRunway")
        addCmd("Declare Emergency",                "onEmergency")
    elseif ph == "landing" then
        addCmd("Vacating Runway",        "onVacatingRunway")
        addCmd("Acknowledge / Wilco",    "onWilco")
        addCmd("Declare Emergency",      "onEmergency")
    elseif arrived then
        local towerCheckedIn = rec.towerCheckedIn and rec.towerCheckedIn[abName]
        local landingCleared = rec.landingCleared and rec.landingCleared[abName]
        -- Same as buildFieldMenu / buildFullMenu: not gated on towerHandoffReady.
        -- The overlay was the strictest of the three, so a straight-in arrival
        -- saw no tower item here at all.
        if not towerCheckedIn then
            addCmd("Contact Tower", "onHandoffToTower")
        elseif not landingCleared then
            addCmd("Request Landing", "onRequestLanding")
        end
        addCmd("Report Position",    "onPositionReport")
        addCmd("Acknowledge / Wilco","onWilco")
        if landingCleared then
            addCmd("Missed Approach",    "onGoAround")
        else
            addCmd("Request Go-Around",  "onGoAround")
        end
        addCmd("Declare Emergency",  "onEmergency")
        addCmd("Cancel Request",     "onCancelRequest")
    elseif not inAir then
        addCmd("Request Taxi Clearance",    "onTaxiRequest")
        addCmd("Request Takeoff Clearance", "onTakeoffRequest")
        addCmd("Ready for Departure",       "onReadyDeparture")
        addCmd("Declare Emergency",         "onEmergency")
    else
        addCmd("Request Landing / Inbound", "onInboundRequest")
        addCmd("Report Position",    "onPositionReport")
        addCmd("Acknowledge / Wilco","onWilco")
        addCmd("Request Go-Around",  "onGoAround")
        addCmd("Declare Emergency",  "onEmergency")
        addCmd("Cancel Request",     "onCancelRequest")
    end
    return items
end

local function _encodeMenu(title, items)
    local parts = {}
    for _, item in ipairs(items) do parts[#parts + 1] = _jItem(item) end
    return string.format('{"title":%s,"items":[%s]}', _jStr(title), table.concat(parts, ","))
end

-- Top-level menu (nearby airfields or engaged-field actions).
function ATC.getOverlayMenuJson(playerName)
    local rec = ATC.state.aircraft[playerName]
    if not rec then return '{"title":"DCS ATC","items":[]}' end

    if rec.engagedField then
        local ab = Airbase.getByName(rec.engagedField)
        if ab then
            local items = _overlayEngagedItems(rec, playerName, rec.engagedField)
            return _encodeMenu("ATC -- " .. rec.engagedField, items)
        else
            rec.engagedField = nil
        end
    end

    -- Not engaged: show nearby airfields
    local unit  = Unit.getByName(playerName)
    local uPos  = unit and unit:getPoint()
    local items = {}
    if uPos then
        items[#items + 1] = {
            kind  = "cmd",
            label = "Refresh",
            cmd   = string.format("ATC.onRefreshMenu(%s)", _jStr(playerName)),
        }
        local nearby = ATC.getNearbyAirbases(uPos, ATC.config.nearRadiusM)
        for _, fe in ipairs(nearby) do
            local distKm  = math.floor(fe.distM / 1000 + 0.5)
            local rwy     = ATC.getRunway(fe.name)
            local freqStr = (rwy and rwy.frequencies and rwy.frequencies.approach)
                            and ("  APP " .. rwy.frequencies.approach.mhz) or ""
            items[#items + 1] = {
                kind  = "sub",
                label = fe.name .. "  (" .. distKm .. " km)" .. freqStr,
                key   = fe.name,
            }
        end
    end
    return _encodeMenu("DCS ATC", items)
end

-- Sub-menu for a specific airfield (called when user drills into a field).
function ATC.getFieldOverlayMenuJson(playerName, fieldName)
    local rec = ATC.state.aircraft[playerName]
    if not rec then return '{"title":"DCS ATC","items":[]}' end

    local rwy     = ATC.getRunway(fieldName)
    local freqStr = (rwy and rwy.frequencies and rwy.frequencies.approach)
                    and ("  APP " .. rwy.frequencies.approach.mhz) or ""
    local items   = _overlayEngagedItems(rec, playerName, fieldName)

    if #items == 0 then
        items[#items + 1] = {
            kind  = "cmd",
            label = "Request Landing / Inbound",
            cmd   = string.format("ATC.onInboundRequest({unitName=%s,airbaseName=%s})",
                        _jStr(playerName), _jStr(fieldName)),
        }
    end
    return _encodeMenu(fieldName .. freqStr, items)
end
