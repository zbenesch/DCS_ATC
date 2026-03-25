local _scriptsBase = _ATC_BASE or ""
ATC = ATC or {}
local _runwaySnapshot = ATC.runways
ATC.runways = ATC.runways or {}
ATC = ATC or {}
ATC._timersStarted = nil
ATC._notificationShown = nil
ATC._phraseDur = ATC._phraseDur or {}
ATC._PSUBS = ATC._PSUBS or {}
ATC._WSET = ATC._WSET or {}
ATC._NATO = ATC._NATO or {}
ATC._DWORDS = ATC._DWORDS or {}
ATC._CALLSIGNS = ATC._CALLSIGNS or {
    enfield=true, springfield=true, uzi=true, colt=true, dodge=true, ford=true, chevy=true, pontiac=true, lobo=true, hawg=true, olds=true, lincoln=true, jedi=true, viper=true, venom=true, witch=true, cobra=true, bone=true, mako=true, dude=true, tiger=true, wolf=true, weasel=true, panther=true, hawk=true, reaper=true, ghost=true, eagle=true, shark=true, sniper=true, lancer=true, devil=true, rebel=true, storm=true, talon=true
}
ATC.menuPaths = {}  -- [coalitionID] = { root, ground, tower, approach, departure }
function ATC.ensureMenusForCoalition(coalitionID)
    if not coalitionID then return end
    ATC.menuPaths[coalitionID] = ATC.menuPaths[coalitionID] or {}
end
ATC.config = {
    msgDuration        = 10,
    msgDurationLong    = 25,
    nearRadiusM        = 185200,
    radioTxPower       = 50000,
    radioModulation    = 0,
    gsAngleDeg         = 3.0,
    magvar             = 6,
    gsDeviationFt   = 200,
    guidanceInterval = 30,
    finalNM         = 20,
    stallWarnKt     = 80,
    approachSpeeds = {
        ["F-16C_50"]            = { clean=250, gear=190, final=160, maxFinal=200 },
        ["FA-18C_hornet"]       = { clean=250, gear=200, final=140, maxFinal=180 },
        ["F-15C"]               = { clean=250, gear=220, final=155, maxFinal=200 },
        ["F-15E"]               = { clean=250, gear=220, final=155, maxFinal=200 },
        ["F-14A-135-GR"]        = { clean=250, gear=210, final=134, maxFinal=180 },
        ["F-14B"]               = { clean=250, gear=210, final=134, maxFinal=180 },
        ["A-10C"]               = { clean=200, gear=160, final=130, maxFinal=160 },
        ["A-10C_2"]             = { clean=200, gear=160, final=130, maxFinal=160 },
        ["AV8BNA"]              = { clean=250, gear=200, final=110, maxFinal=150 },
        ["Su-27"]               = { clean=250, gear=210, final=145, maxFinal=190 },
        ["Su-33"]               = { clean=250, gear=210, final=145, maxFinal=190 },
        ["Su-25T"]              = { clean=200, gear=160, final=135, maxFinal=170 },
        ["Su-25"]               = { clean=200, gear=160, final=135, maxFinal=170 },
        ["MiG-29A"]             = { clean=250, gear=210, final=145, maxFinal=190 },
        ["MiG-29S"]             = { clean=250, gear=210, final=145, maxFinal=190 },
        ["MiG-21Bis"]           = { clean=250, gear=220, final=170, maxFinal=215 },
        ["AJS37"]               = { clean=250, gear=200, final=140, maxFinal=185 },
        ["M-2000C"]             = { clean=250, gear=210, final=155, maxFinal=195 },
        ["JF-17"]               = { clean=250, gear=210, final=145, maxFinal=185 },
        ["C-101CC"]             = { clean=200, gear=160, final=120, maxFinal=155 },
        ["L-39ZA"]              = { clean=200, gear=160, final=115, maxFinal=150 },
        ["Yak-52"]              = { clean=140, gear=110, final= 85, maxFinal=115 },
        ["TF-51D"]              = { clean=140, gear=110, final= 90, maxFinal=120 },
        ["P-51D-30-NA"]         = { clean=140, gear=110, final= 90, maxFinal=120 },
        ["Spitfire LF Mk. IXc"] = { clean=130, gear=100, final= 80, maxFinal=110 },
        ["FW-190D9"]            = { clean=170, gear=130, final=105, maxFinal=140 },
        ["Bf-109K-4"]           = { clean=160, gear=130, final=100, maxFinal=135 },
        ["Mi-8MT"]              = { clean=120, gear= 80, final= 55, maxFinal= 80 },
        ["Ka-50"]               = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        ["Ka-50_3"]             = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        ["UH-1H"]               = { clean=100, gear= 70, final= 50, maxFinal= 70 },
        ["SA342M"]              = { clean=100, gear= 70, final= 40, maxFinal= 60 },
        ["AH-64D_BLK_II"]       = { clean=120, gear= 80, final= 50, maxFinal= 70 },
        ["default"]             = { clean=250, gear=180, final=150, maxFinal=200 },
    },
    rootMenuLabel    = "ATC",
    menuRefreshLabel = "  Refresh Airfield List",
    refreshInterval = 10,
    queueBroadcastInterval = 30,
    vectoringInterval = 25,
    ilsHandoffNM = 8,
    defaultPatternAltFt = 1500,
    voiceDebug = false,
    voiceDebugToGroup = true,
    disableVoice = true,  -- when true, disable tokenization and radioTransmission audio
    magvarCaucasus = 6,   -- Caucasus / Black Sea
    magvarPG = 2,         -- Persian Gulf
    magvarSyria = 4,      -- Syria
    magvarDefault = 0,    -- Default fallback
}

function ATC.voiceDebug(groupId, msg)
    if not (ATC and ATC.config and ATC.config.voiceDebug) then return end
    local line = "VOICE " .. tostring(msg)
    ATC.log(line)
    -- Display is disabled; only log to file
end

local function fmtRadioList(radios)
    local parts = {}
    if not radios then return "none" end
    for idx = 1, 4 do
        local f = radios[idx]
        if f then
            parts[#parts + 1] = string.format("R%d=%.3f", idx, f)
        end
    end
    if #parts == 0 then return "none" end
    return table.concat(parts, ", ")
end
ATC.state = {
    aircraft  = {},   -- [unitName]    -> player record
    airfields = {},   -- [airbaseName] -> traffic record
    telemetry = {},   -- [unitName] -> { t, headingDeg, altAglFt, speedKt, aoaDeg, radios={[1..4]=mhz} }
}
function ATC.getFieldState(airbaseName)
    if not ATC.state.airfields[airbaseName] then
        ATC.state.airfields[airbaseName] = {
            landingSeq = {},
            departSeq  = {},
            rwyClear   = true,
            holdStack  = {},   -- [unitName] = assigned hold altitude (ft)
            patternSlots = {}, -- [unitName] = assigned pattern altitude (ft)
        }
    end
    return ATC.state.airfields[airbaseName]
end
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
            finalCleared       = {}, -- [airbaseName] = true once final landing clearance issued
            gearReminded       = {}, -- [airbaseName] = true once gear/checkspeed reminder sent
            holdPhase          = {}, -- [airbaseName] = "inbound"|"outbound" racetrack leg
            patternCornerIdx   = {}, -- [airbaseName] = 1..#corners, which CRP to fly to next
            patternAlt         = {}, -- [airbaseName] = current stack altitude in ft (MSL)
            report15Done       = {}, -- [airbaseName] = true once pilot reported position at/inside 15 NM
            report15ReminderSent = {}, -- [airbaseName] = true once auto-reminder was sent at/inside 15 NM
            towerHandoffReady  = {}, -- [airbaseName] = true once CP5 crossed and handoff action should appear
            towerCheckedIn     = {}, -- [airbaseName] = true once pilot selected handoff to tower
            postLandingReady   = {}, -- [airbaseName] = true once landed and slowed for tower/ground handoff menu
            greeted            = {}, -- [airbaseName][controller] = true if greeted
            lastFreqRejection  = {}, -- [controllerType] = timer.getTime() of last frequency rejection message (silences duplicates)
        }
    end
    return ATC.state.aircraft[unitName]
end
function ATC.getDaytimeGreeting()
    local hour = 12
    if env and env.mission and env.mission.date and env.mission.start_time then
        local t = env.mission.start_time
        hour = math.floor((t / 3600) % 24)
    elseif timer and timer.getAbsTime then
        hour = math.floor((timer.getAbsTime() / 3600) % 24)
    end
    if hour < 12 then return "Good morning"
    elseif hour < 18 then return "Good afternoon"
    else return "Good evening" end
end
function ATC.getPhase(unitName, airbaseName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return "unknown" end
    return rec.phases[airbaseName] or "unknown"
end
local function getVoiceDuration(text, abName, controller)
    if ATC and ATC.config and ATC.config.disableVoice then
        return 0
    end
    local voice = "adam"
    if abName and controller then
        voice = ATC.getStationVoice(abName, controller)
    end
    local tokens = ATC.textToTokens(text)
    local total = 0
    for _, token in ipairs(tokens) do
        local phraseDur = ATC._phraseDur and ATC._phraseDur[voice .. "/" .. token] or 0.45
        total = total + phraseDur + 0.05 -- 50ms gap
    end
    return math.max(total, 2.0) -- never less than 2s
end
local function sendRadioVoice(groupId, abPos, text, abName, controller, dur)
    if not abPos or not abName or not controller then return end
    local ok, err = pcall(function()
        controller = controller or "Approach"
        local freqHz, modulation, power = ATC.getControllerRadio(abName, controller)
        local voice    = ATC.getStationVoice(abName, controller)
        local tokens   = ATC.textToTokens(text)
        local startT   = ATC.reserveRadioWindow(abName, controller, dur or ATC.ttsDuration(text))
        ATC.voiceDebug(groupId, string.format(
            "radioMsg %s/%s voice=%s freqHz=%s text='%s'",
            tostring(abName), tostring(controller), tostring(voice), tostring(freqHz), tostring(text)))
        ATC.scheduleTokens(groupId, abPos, freqHz, tokens, voice, startT, modulation, power)
    end)
    if not ok then
        ATC.log(string.format("WARN  sendRadioVoice fallback for %s/%s: %s",
            tostring(abName), tostring(controller), tostring(err)))
    end
end

function ATC.msg(groupId, text, long, abName, controller, skipVoice)
    local dur = long and ATC.config.msgDurationLong or ATC.config.msgDuration
    if abName and controller then
        local ok, result = pcall(getVoiceDuration, text, abName, controller)
        if ok and type(result) == "number" and result > 0 then
            dur = result
        else
            -- If voice is disabled or duration couldn't be computed, use long duration
            dur = ATC.config.msgDurationLong
            if not ok then
                ATC.log(string.format("WARN  msg duration fallback for %s/%s: %s",
                    tostring(abName), tostring(controller), tostring(result)))
            end
        end
    end
    trigger.action.outTextForGroup(groupId, text, dur, false)

    if not skipVoice and abName and controller then
        local ab = Airbase.getByName(abName)
        local abPos = ab and ATC.getAirbasePos(ab)
        sendRadioVoice(groupId, abPos, text, abName, controller, dur)
    end
end

function ATC.radioMsg(groupId, abPos, text, long, abName, controller)
    ATC.msg(groupId, text, long, abName, controller, true)
    sendRadioVoice(groupId, abPos, text, abName, controller, nil)
end
local function normalizeAirbaseName(name)
    if not name or name == "" then return nil end
    return string.lower(name):gsub("[^%w]", "")
end

local _AIRBASE_ALIASES = {
    ["sukhumibabushara"] = "Sukhumi",
    ["tbilisisoganlug"]  = "Soganlug",
}

local _SPOKEN_AIRBASE_NAME = {
    ["Anapa-Vityazevo"]      = "Anapa",
    ["Krasnodar-Center"]     = "Krasnodar",
    ["Krasnodar-Pashkovsky"] = "Krasnodar",
    ["Maykop-Khanskaya"]     = "Maykop",
    ["Senaki-Kolkhi"]        = "Senaki",
    ["Sochi-Adler"]          = "Sochi",
    ["Sukhumi-Babushara"]    = "Sukhumi",
    ["Tbilisi-Lochini"]      = "Tbilisi",
    ["Tbilisi-Soganlug"]     = "Tbilisi",
    ["Soganlug"]             = "Tbilisi",
}

function ATC.getSpokenAirbaseName(abName)
    if not abName or abName == "" then return "Airfield" end
    if _SPOKEN_AIRBASE_NAME[abName] then
        return _SPOKEN_AIRBASE_NAME[abName]
    end
    local canonical = _AIRBASE_ALIASES[normalizeAirbaseName(abName)]
    if canonical and _SPOKEN_AIRBASE_NAME[canonical] then
        return _SPOKEN_AIRBASE_NAME[canonical]
    end
    local first = tostring(abName):match("^([^%-]+)")
    return first or abName
end

function ATC.getRunway(abName)
    local rdata = (ATC.runways and next(ATC.runways) ~= nil) and ATC.runways or _runwaySnapshot
    if not rdata or not abName then return nil end
    local exact = rdata[abName]
    if exact then return exact end

    local norm = normalizeAirbaseName(abName)
    if not norm then return nil end

    local aliasKey = _AIRBASE_ALIASES[norm]
    if aliasKey and rdata[aliasKey] then
        return rdata[aliasKey]
    end

    for key, value in pairs(rdata) do
        if normalizeAirbaseName(key) == norm then
            return value
        end
    end

    return nil
end
function ATC.distVec3(a, b)
    if not a or not b or type(a.x) ~= "number" or type(b.x) ~= "number"
       or type(a.y) ~= "number" or type(b.y) ~= "number"
       or type(a.z) ~= "number" or type(b.z) ~= "number" then
        return math.huge
    end
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end
function ATC.distVec3H(a, b)
    if not a or not b or type(a.x) ~= "number" or type(b.x) ~= "number"
       or type(a.z) ~= "number" or type(b.z) ~= "number" then
        return math.huge
    end
    local dx = a.x - b.x
    local dz = a.z - b.z
    return math.sqrt(dx*dx + dz*dz)
end
function ATC.mToNM(m) return m / 1852 end
function ATC.mToFt(m) return m * 3.28084 end
function ATC.ordinal(n)
    if n == 1 then return "1st"
    elseif n == 2 then return "2nd"
    elseif n == 3 then return "3rd"
    else return n .. "th" end
end
function ATC.sequenceNumber(n)
    return tostring(n)
end
function ATC.getAirbasePos(ab)
    return ab:getPoint()
end
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
function ATC.getAltFt(unit)
    if not unit then return nil end
    local pos = unit:getPoint()
    if not pos then return nil end
    return math.floor(ATC.mToFt(pos.y))
end
function ATC.getAltAglFt(unit)
    if not unit then return nil end
    local pos = unit:getPoint()
    if not pos then return nil end
    local groundM = 0
    if land and land.getHeight then
        local ok, h = pcall(land.getHeight, { x = pos.x, y = pos.z })
        if ok and type(h) == "number" then
            groundM = h
        end
    end
    local aglM = pos.y - groundM
    return math.floor(ATC.mToFt(aglM))
end
function ATC.getSpeedKt(unit)
    if not unit then return nil end
    local vel = unit:getVelocity()
    if not vel then return nil end
    local spd = math.sqrt(vel.x*vel.x + vel.y*vel.y + vel.z*vel.z)
    return math.floor(spd * 1.94384)
end
function ATC.distUnitToBase(unit, ab)
    if not unit or not ab then return nil end
    local uPos = unit:getPoint()
    local bPos = ATC.getAirbasePos(ab)
    if not uPos or not bPos then return nil end
    return ATC.mToNM(ATC.distVec3H(uPos, bPos))
end
function ATC.isPlayer(unit)
    if not unit then return false end
    if not unit:isExist() then return false end
    local pName = unit:getPlayerName()
    if pName ~= nil and pName ~= "" then return true end
    for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
        for _, pu in ipairs(coalition.getPlayers(side) or {}) do
            if pu and pu:getName() == unit:getName() then return true end
        end
    end
    return false
end
function ATC.getBearing(a, b)
    local dx = b.z - a.z    -- East component
    local dz = b.x - a.x    -- North component
    local brg = math.deg(math.atan2(dx, dz))
    if brg < 0 then brg = brg + 360 end
    return math.floor(brg + 0.5)
end
function ATC.getBearingText(a, b)
    if not a or not b then return nil end
    local bearing = ATC.getBearing(a, b)
    local sectors = {
        "north", "north-east", "east", "south-east",
        "south", "south-west", "west", "north-west",
    }
    local index = (math.floor(((bearing + 22.5) % 360) / 45) % 8) + 1
    return sectors[index], bearing
end
function ATC.getGSDeviationFt(unit, ab, gsAngle)
    if not unit or not ab then return nil end
    local uPos  = unit:getPoint()
    local bPos  = ATC.getAirbasePos(ab)
    if not uPos or not bPos then return nil end
    local distM  = ATC.distVec3H(uPos, bPos)
    local altM   = uPos.y - bPos.y          -- height above airbase elevation
    local ang    = gsAngle or ATC.config.gsAngleDeg
    local idealAltM  = distM * math.tan(math.rad(ang))
    local deviationM = altM - idealAltM
    return deviationM * 3.28084
end
function ATC.getGlideslope(unit, abPos, rwy)
    local result = { altDev = 0, speedDev = 0, aoaDev = 0 }
    if not unit or not abPos or not rwy then return result end
    local uPos = unit:getPoint()
    if not uPos then return result end
    local distM    = ATC.distVec3H(uPos, abPos)
    local altM     = uPos.y - abPos.y
    local gsAng    = ATC.config.gsAngleDeg or 3.0
    local idealAlt = distM * math.tan(math.rad(gsAng))
    local altErrFt = (altM - idealAlt) * 3.28084
    result.altDev  = altErrFt / (ATC.config.gsDeviationFt or 200)
    local spds = ATC.getApproachSpeeds(unit)
    if spds then
        local spdKt = ATC.getSpeedKt(unit) or 0
        local target = spds.final or 150
        result.speedDev = (spdKt - target) / math.max(target * 0.1, 10)
    end
    return result
end
function ATC.getApproachSpeeds(unit)
    if not unit then return ATC.config.approachSpeeds["default"] end
    local t = unit:getTypeName() or "default"
    return ATC.config.approachSpeeds[t]
        or ATC.config.approachSpeeds["default"]
end

function ATC.isOnFrequency(unitName, airbaseName, controller, opts)
    -- Check if player is tuned to the correct frequency
    -- controller = "approach", "tower", "ground", "departure"
    -- Returns true if on correct freq, false otherwise
    if not unitName or not airbaseName or not controller then return false end
    opts = opts or {}
    local allowNoRadioBypass = (opts.allowNoRadioBypass ~= false)
    
    local rec = ATC.state.aircraft and ATC.state.aircraft[unitName]
    local groupId = rec and rec.groupId or nil
    local rwy = ATC.getRunway(airbaseName)
    if not rwy or not rwy.frequencies or not rwy.frequencies[controller] then
        ATC.voiceDebug(groupId, string.format(
            "%s %s missing runway frequency data",
            tostring(airbaseName), tostring(controller)))
        return false  -- No frequency defined for this controller
    end
    
    local requiredFreqMhz = rwy.frequencies[controller].mhz
    if not requiredFreqMhz then
        ATC.voiceDebug(groupId, string.format(
            "%s %s has nil required mhz",
            tostring(airbaseName), tostring(controller)))
        return false
    end
    
    -- Get current radio frequencies from telemetry
    local telem = ATC.state.telemetry and ATC.state.telemetry[unitName]
    local radios = telem and telem.radios
    -- If no radio data has arrived yet, allow the request through
    -- (export hook may still be initialising).  Log, but don't block.
    local hasRadioData = radios and next(radios) ~= nil
    if not hasRadioData then
        if allowNoRadioBypass then
            ATC.voiceDebug(groupId, string.format(
                "%s freq-check BYPASS (no radio data) controller=%s required=%.3f",
                tostring(unitName), tostring(controller), requiredFreqMhz))
            return true
        end
        ATC.voiceDebug(groupId, string.format(
            "%s freq-check NO RADIO DATA controller=%s required=%.3f",
            tostring(unitName), tostring(controller), requiredFreqMhz))
        return false
    end
    
    -- Check if ANY radio is tuned to the correct frequency (±0.05 MHz tolerance)
    local tolerance = 0.05
    for radioIdx = 1, 4 do
        local currentFreqMhz = radios[radioIdx]
        if currentFreqMhz and math.abs(currentFreqMhz - requiredFreqMhz) < tolerance then
            ATC.voiceDebug(groupId, string.format(
                "%s %s OK required=%.3f tuned=%.3f radios=[%s]",
                tostring(unitName), tostring(controller), requiredFreqMhz, currentFreqMhz, fmtRadioList(radios)))
            return true
        end
    end

    ATC.voiceDebug(groupId, string.format(
        "%s %s FAIL required=%.3f radios=[%s]",
        tostring(unitName), tostring(controller), requiredFreqMhz, fmtRadioList(radios)))
    
    return false
end

function ATC.ttsClean(text)
    return (text:gsub("\n", "  "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end
function ATC.toTrue(magHdg)
    return (magHdg + (ATC.config.magvar or 0)) % 360
end
function ATC.toMag(trueHdg)
    return (trueHdg - (ATC.config.magvar or 0) + 360) % 360
end
function ATC.ttsDuration(text)
    local clean = ATC.ttsClean(text)
    local words = select(2, clean:gsub("%S+", ""))
    return math.max(2, math.ceil(words / 2.5))   -- 2.5 wps
end
local _ATC_LOG_PATH = nil
function ATC.log(msg)
    local line = string.format("[%9.1f] %s", timer.getTime(), msg)
    if io and io.open then
        if not _ATC_LOG_PATH then
            local dir = (lfs and lfs.writedir and lfs.writedir()) or ""
            _ATC_LOG_PATH = dir .. "Logs\\DCS-atc.log"
        end
        local f = io.open(_ATC_LOG_PATH, "a")
        if f then
            f:write(line .. "\n")
            f:close()
            return
        end
    end
    if env and env.info then
        env.info("DCS-ATC " .. line)
    end
end
local _phraseSeqId = 0
local _missingVoiceClipLogged = {}
local function getPhraseAudioPath(voice, token)
    -- Always use .miz internal path for radioTransmission
    return string.format("AUDIO/atc/%s/%s.ogg", voice, token)
end

function ATC.getControllerRadio(abName, controller)
    local rwy     = ATC.runways and ATC.runways[abName]
    local freqs   = rwy and rwy.frequencies
    local ctrlKey = (controller or "Approach"):lower()
    local freqRec = freqs and freqs[ctrlKey]
    local fallback = freqs and freqs.approach
    local radio   = freqRec or fallback or {}
    local freqHz  = radio.hz or 251000000
    local modulation = radio.modulation
    if modulation == nil then
        modulation = ATC.config.radioModulation or 0
    end
    local power = radio.power or ATC.config.radioTxPower or 1000
    return freqHz, modulation, power
end

function ATC.scheduleTokens(groupId, abPos, freqHz, tokens, voice, startT, modulation, power)
    -- Voice playback and scheduling logic removed for reimplementation
    local seqId = _phraseSeqId
    ATC.voiceDebug(groupId, string.format(
        "TX seq=%d voice=%s freqHz=%s modulation=%s power=%s tokens=%d",
        seqId, tostring(voice), tostring(freqHz), tostring(modulation), tostring(power), #tokens))
    -- Debug: Log the contents of ATC._phraseDur at runtime
    if ATC._phraseDur then
        local count = 0
        for k, v in pairs(ATC._phraseDur) do count = count + 1 end
        ATC.log("DEBUG  ATC._phraseDur contains " .. tostring(count) .. " entries.")
        for k, v in pairs(ATC._phraseDur) do
            if count <= 20 then -- only log all if small, else just a sample
                ATC.log("DEBUG  ATC._phraseDur[" .. tostring(k) .. "] = " .. tostring(v))
            end
        end
    else
        ATC.log("DEBUG  ATC._phraseDur is nil!")
    end
    local t = startT
    local phraseDur = ATC._phraseDur or {}
    for i, token in ipairs(tokens) do
        local clipKey = voice .. "/" .. token
        local dur  = phraseDur[clipKey]
        if not dur then
            if not _missingVoiceClipLogged[clipKey] then
                _missingVoiceClipLogged[clipKey] = true
                ATC.log("WARN  VOICE missing clip: " .. tostring(clipKey))
            end
        else
            local name = string.format("ATC_%d_%d", seqId, i)
            local path = getPhraseAudioPath(voice, token)
            ATC.voiceDebug(groupId, string.format(
                "TX seq=%d token=%d/%d %s path=%s start=%.2f dur=%.2f",
                seqId, i, #tokens, tostring(token), tostring(path), t, dur))
            local _pos, _f, _n, _p, _m, _w = abPos, freqHz, name, path, modulation, power
            timer.scheduleFunction(function()
                ATC.log("DEBUG  trigger.action.radioTransmission called: path=" .. tostring(_p) .. ", freqHz=" .. tostring(_f) .. ", name=" .. tostring(_n))
                -- Compute nearest player distance to the transmission point for troubleshooting
                local minDist = nil
                for _, side in ipairs({ coalition.side.BLUE, coalition.side.RED, coalition.side.NEUTRAL }) do
                    for _, pu in ipairs(coalition.getPlayers(side) or {}) do
                        local up = pu and pu:getPoint()
                        if up and _pos then
                            local dx = up.x - (_pos.x or 0)
                            local dz = up.z - (_pos.z or 0)
                            local d = math.sqrt(dx*dx + dz*dz)
                            minDist = minDist and math.min(minDist, d) or d
                        end
                    end
                end
                if minDist then
                    ATC.log(string.format("DEBUG  nearest player dist to tx point = %.1f m (%.2f NM)", minDist, (minDist/1852)))
                else
                    ATC.log("DEBUG  no players found when scheduling radioTransmission")
                end
                trigger.action.radioTransmission(_p, _pos, _m, false, _f, _w, _n)
                return nil
            end, nil, t)
            t = t + dur + 0.05   -- 50 ms gap between clips
        end
    end
end

function ATC.textToTokens(text)
    if ATC and ATC.config and ATC.config.disableVoice then return {} end
    if not text or text == "" then return {} end
    text = text:lower()
    text = text:gsub("[\n\r]", " ")
    text = text:gsub("%-", " ")
    for _, sub in ipairs(ATC._PSUBS or {}) do
        text = text:gsub(sub[1], sub[2])
    end
    text = text:gsub("(%d+)%.%d+ nm", "%1 nm")          -- "3.5 nm" -> "3 nm"
    text = text:gsub(" kt", " knots")
    text = text:gsub(" ft", " feet")
    text = text:gsub(" nm", " nautical-miles")
    text = text:gsub("[%.,!%;:%?%(%)%[%]]", " ")
    text = text:gsub("%s+", " ")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local tokens = {}
    -- Special handling for callsign + number at start
    local callsign, num, rest = text:match("^(%w+)%s+(%d%d)%s*(.*)$")
    if callsign and ATC._CALLSIGNS[callsign] then
        table.insert(tokens, callsign)
        for d in num:gmatch(".") do
            local dw = (ATC._DWORDS or {})[tonumber(d)]
            if dw then table.insert(tokens, dw) end
        end
        text = rest or ""
    end
    -- Only emit tokens for known words, numbers, or callsigns. Unknown words are skipped and will NOT be spelled out letter by letter.
    -- This ensures that if a word does not have an .ogg, it is simply omitted from voice playback.
    for word in text:gmatch("[%w_%-]+") do
        if word:match("^__(.-)__$") then
            local chunk = word:match("^__(.-)__$"):gsub("_", "-")
            chunk = chunk:gsub("[^%w%-]", ""):gsub("%-+", "-"):gsub("^%-+", ""):gsub("%-+$", "")
            if chunk ~= "" then
                table.insert(tokens, chunk)
            end
        elseif word:match("^%d+$") then
            -- Numbers as a single token (not split)
            table.insert(tokens, word)
        elseif (ATC._WSET or {})[word] then
            table.insert(tokens, word)
        elseif (ATC._CALLSIGNS or {})[word] then
            table.insert(tokens, word)
        else
            -- Unknown word: skip (do not split or spell)
            -- This is intentional: if there is no .ogg, the word is omitted from voice output.
        end
    end
    return tokens
end
local _PHRASE_VOICES = { "adam", "alice", "daniel" }
local _ROLE_VOICE = {
    approach  = "adam",
    departure = "adam",
    tower     = "alice",
    ground    = "daniel",
}
function ATC.getStationVoice(abName, role)
    local r = role and role:lower()
    if _ROLE_VOICE[r] then return _ROLE_VOICE[r] end
    local s = (abName or "") .. (role or "")
    local h = 0
    for i = 1, #s do h = h + string.byte(s, i) end
    return _PHRASE_VOICES[(h % #_PHRASE_VOICES) + 1]
end
local _RADIO_GAP_SEC = 0.35
local _radioBusyUntil = {}
function ATC.reserveRadioWindow(abName, controller, duration)
    local now = timer.getTime() + 0.05
    local key = string.format("%s|%s", abName or "ATC", (controller or "Approach"):lower())
    local startT = math.max(now, _radioBusyUntil[key] or 0)
    _radioBusyUntil[key] = startT + (duration or 2) + _RADIO_GAP_SEC
    return startT
end
-- The legacy radioMsg function body has been moved to the earlier definition at the top of this file.
-- Voice playback and scheduling logic removed for reimplementation
function ATC.roundHdg(h)
    local r = math.floor(h / 10 + 0.5) * 10 % 360
    return r == 0 and 360 or r
end
function ATC.fmtHdg(h)
    local r = math.floor(h + 0.5) % 360
    if r == 0 then r = 360 end
    return string.format("%03d", r)
end
local function angleDiff(a, b)
    local d = (b - a) % 360
    if d > 180 then d = d - 360 end
    return d
end
function ATC.getPatternLeg(uPos, abPos, rwy)
    local bearingToAc = ATC.getBearing(abPos, uPos)
    local diff = angleDiff(rwy.hdg, bearingToAc)
    local distNM = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    if distNM <= 2  then return "short_final" end
    if distNM <= 8  then
        if math.abs(diff) <= 30 then return "final" end
        if math.abs(diff) <= 90 then return "base" end
    end
    if distNM > 15 then return "outbound" end
    if math.abs(math.abs(diff) - 180) <= 45 then return "downwind" end
    if math.abs(diff) > 90 then return "crosswind" end
    return "outbound"
end
function ATC.getArrivalReport(unit, airbaseName, ab)
    local report = {
        text = "inbound for landing",
        voice = "inbound for landing",
        traffic = "inbound for landing",
    }
    local rwy = ATC.getRunway(airbaseName)
    if not unit or not ab or not rwy then
        return report
    end
    local uPos = unit:getPoint()
    local abPos = ATC.getAirbasePos(ab)
    if not uPos or not abPos then
        return report
    end
    local distNM = ATC.mToNM(ATC.distVec3H(uPos, abPos))
    local leg = ATC.getPatternLeg(uPos, abPos, rwy)
    if leg == "short_final" or leg == "final" then
        report.text = "established on final"
        report.voice = "established on final"
        report.traffic = "established on final"
    elseif leg == "base" then
        report.text = "on base"
        report.voice = "on base, runway"
        report.traffic = "on base"
    elseif leg == "downwind" then
        report.text = "on downwind"
        report.traffic = "on downwind"
    elseif leg == "crosswind" then
        report.text = "crosswind"
        report.traffic = "crosswind"
    elseif leg == "outbound" then
        report.text = "inbound for landing"
        report.voice = "inbound for landing"
        report.traffic = "inbound for landing"
    end
    return report
end
function ATC.getInterceptHeading(uPos, abPos, rwy)
    local inboundTrueHdg = ATC.toTrue(rwy.hdg)          -- direction to fly to land
    local recipTrueHdg   = ATC.toTrue(rwy.reciprocal)   -- direction from field to FAP
    local inboundHdgRad  = math.rad(recipTrueHdg)
    local nm8m = 8 * 1852
    local entryPos  = {
        x = abPos.x + nm8m * math.cos(inboundHdgRad),
        y = abPos.y,
        z = abPos.z + nm8m * math.sin(inboundHdgRad),
    }
    local rawHdg = ATC.getBearing(uPos, entryPos)
    local diff = angleDiff(inboundTrueHdg, rawHdg)
    if diff >  30 then rawHdg = (inboundTrueHdg + 30) % 360 end
    if diff < -30 then rawHdg = (inboundTrueHdg - 30 + 360) % 360 end
    return ATC.roundHdg(rawHdg)
end
function ATC.getPatternAltFt(rwy, leg, distNM)
    local base = rwy.patternAlt or (rwy.elevation + ATC.config.defaultPatternAltFt)
    if leg == "downwind"   then return base end
    if leg == "base"       then return math.floor(base * 0.75) end
    if leg == "final"      then
        local distM  = distNM * 1852
        local gsAlt  = distM * math.tan(math.rad(ATC.config.gsAngleDeg))
        return math.max(rwy.elevation + 300, math.floor(rwy.elevation + ATC.mToFt(gsAlt)))
    end
    return base
end
ATC.config.holdAglBase   = ATC.config.holdAglBase  or 2500  -- floor of hold stack AGL
ATC.config.holdAglSep    = ATC.config.holdAglSep   or 1000  -- vertical separation between levels
ATC.config.holdMaxLevels = ATC.config.holdMaxLevels or 3    -- max hold levels
local HOLD_AGL_BASE   = ATC.config.holdAglBase
local HOLD_AGL_SEP    = ATC.config.holdAglSep
local HOLD_MAX_LEVELS = ATC.config.holdMaxLevels
local HOLD_SPEED      = 300   -- hold speed kt (uniform for all stack levels)
local HOLD_LEG_NM    = 5      -- outbound leg length NM
local ENTRY_BASE_AGL = 3000   -- altitude AGL for entry / base leg
local FINAL_AGL      = 1500   -- altitude AGL at the final approach point (8 NM)
local PATTERN_CORNER_NM  = 1.5   -- within this NM of a CRP corner: advance to next
local PATTERN_FINAL_ALT  = 1500  -- ft; after full lap at this altitude -> turn final
function ATC.getApproachGates(rwy, unit, startAlt)
    local spds = ATC.getApproachSpeeds(unit)
    local elev = rwy.elevation or 0
    local nearNM = ATC.config.ilsHandoffNM or 8
    startAlt = startAlt or (elev + HOLD_AGL_BASE)
    local gates = {}
    local startAGL  = startAlt - elev
    local maxAGL    = HOLD_AGL_BASE + (HOLD_MAX_LEVELS - 1) * HOLD_AGL_SEP
    local levelAGL  = math.min(math.ceil(startAGL / HOLD_AGL_SEP) * HOLD_AGL_SEP, maxAGL)
    while levelAGL >= HOLD_AGL_BASE do
        table.insert(gates, {
            altFt   = elev + levelAGL,
            speedKt = HOLD_SPEED,
            distNM  = nearNM + HOLD_LEG_NM,
            name    = "hold" .. levelAGL,
        })
        levelAGL = levelAGL - HOLD_AGL_SEP
    end
    table.insert(gates, {
        altFt   = elev + FINAL_AGL,
        speedKt = spds.final,
        distNM  = nearNM,
        name    = "final",
    })
    return gates
end
local function withinTolerance(actual, target, tolerance)
    if not actual or not target then return false end
    local delta = math.abs(actual - target)
    local maxDelta = target * tolerance
    return delta <= maxDelta
end
function ATC.checkGateCompliance(unit, gate, heading, isFinal)
    if not unit or not gate then return false end
    local altFt = ATC.getAltFt(unit)
    local spdKt = ATC.getSpeedKt(unit)
    local vel = unit:getVelocity()
    if not vel or not altFt or not spdKt then return false end
    local currentHdg = math.deg(math.atan2(vel.z, vel.x))
    if currentHdg < 0 then currentHdg = currentHdg + 360 end
    local hdgDiff = math.abs(currentHdg - heading)
    if hdgDiff > 180 then hdgDiff = 360 - hdgDiff end
    local tolerance = isFinal and 0.04 or 0.10  -- 4% for final, 10% for others
    local hdgToleranceDeg = isFinal and 15 or 30  -- degrees tolerance for heading
    local altOK = withinTolerance(altFt, gate.altFt, tolerance)
    local spdOK = withinTolerance(spdKt, gate.speedKt, tolerance)
    local hdgOK = hdgDiff <= hdgToleranceDeg
    if isFinal then
        return altOK and spdOK and hdgOK
    else
        local matchCount = 0
        if altOK then matchCount = matchCount + 1 end
        if spdOK then matchCount = matchCount + 1 end
        if hdgOK then matchCount = matchCount + 1 end
        return matchCount >= 2
    end
end
function ATC.determineCurrentGate(unit, rwy, gates, distNM, altFt)
    if not unit or not rwy or not gates or not distNM or not altFt then return 1 end
    for i = 1, #gates do
        local gate = gates[i]
        if distNM > gate.distNM then
            return i
        end
    end
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
function ATC.removeRecord(unitName)
    local rec = ATC.state.aircraft[unitName]
    if not rec then return end
    ATC.removeFromAllSeqs(unitName)
    for abName, _ in pairs(ATC.state.airfields) do
        ATC.freeStackLevel(unitName, abName)
    end
    if rec.menuRoot then
        missionCommands.removeItemForGroup(rec.groupId, rec.menuRoot)
    end
    ATC.state.aircraft[unitName] = nil
    if ATC.state.telemetry then
        ATC.state.telemetry[unitName] = nil
    end
end
