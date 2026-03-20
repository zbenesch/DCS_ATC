-- DCS-ATC Hook
-- Automatically loads DCS-ATC into every mission without .miz editing.
--
-- Architecture:
--   net.dostring_in("server", src)  - loads code into the server scripting
--       environment where world, timer, coalition, trigger, missionCommands
--       and all other SSE APIs are available.
--   net.dostring_in("export", src)  - executes code in the export environment
--       where GetDevice(n):get_frequency() reads live cockpit radio values.
--
-- Radio frequency flow:
--   onSimulationFrame (1 Hz) -> export env (GetDevice scan) -> SSE (ATC.setRadioFrequencies)
--   Each player's DCS client pushes their own live radio data to the server.

local _atcHook = {}
_atcHook._lastRadioPoll  = 0     -- os.time() of last radio poll
_atcHook._startPending   = false
_atcHook._frameCount     = 0
_atcHook._simRunning     = false
_atcHook._lastRadioDebug  = nil

local function loadFileIntoSSE(path, label)
    local f = io.open(path, "r")
    if not f then
        log.write("DCS-ATC", log.ERROR, "Cannot open: " .. path)
        return false
    end
    local src = f:read("*a")
    f:close()
    local ok, result = net.dostring_in("server", src)
    log.write("DCS-ATC", ok and log.INFO or log.ERROR,
        label .. " ok=" .. tostring(ok) ..
        " bytes=" .. #src ..
        " result=" .. tostring(result))
    return ok
end

-- Lua string used in export env to scan all device IDs and collect aviation-band frequencies.
-- Returns "UnitName|Hz1,Hz2,..." or "" if no player.
-- Device IDs 0-60 cover all known aircraft radio devices. Frequencies filtered to 100-400 MHz.
local _EXPORT_RADIO_SCAN = [[
    local ok_self, selfData = pcall(LoGetSelfData)
    if not ok_self or not selfData or not selfData.UnitName then return "" end
    local unitName = selfData.UnitName
    local seen = {}
    local freqs = {}
    for devId = 0, 60 do
        local ok, dev = pcall(GetDevice, devId)
        if ok and dev and type(dev) ~= "number" then
            local on_ok, isOn = pcall(function() return dev:is_on() end)
            if on_ok and isOn then
                local f_ok, freq = pcall(function() return dev:get_frequency() end)
                if f_ok and type(freq) == "number"
                   and freq >= 100000000 and freq <= 400000000
                   and not seen[freq] then
                    seen[freq] = true
                    freqs[#freqs + 1] = tostring(math.floor(freq))
                end
            end
        end
    end
    return unitName .. "|" .. table.concat(freqs, ",")
]]

function _atcHook.onMissionLoadEnd()
    log.write("DCS-ATC", log.INFO, "onMissionLoadEnd: will load files at sim start")
end

function _atcHook.onSimulationStart()
    _atcHook._simRunning  = true
    _atcHook._lastRadioPoll = 0

    local phrasesPath = lfs.writedir() .. "Mods\\Services\\DCS-ATC\\phrases"
    net.dostring_in("server", string.format(
        "if mount_vfs_sound_path then mount_vfs_sound_path([[%s]]) end", phrasesPath))
    log.write("DCS-ATC", log.INFO, "Sound path mount injected: " .. phrasesPath)

    local base = lfs.writedir() .. "Mods\\Services\\DCS-ATC\\Scripts\\"
    log.write("DCS-ATC", log.INFO, "onSimulationStart: loading files. base=" .. base)
    net.dostring_in("server", string.format("_ATC_BASE = [[%s]]", base))

    -- Inject radio frequency store into SSE.
    -- ATC._radioFreqs[unitName] = { [1..4] = mhz }  (live values pushed from each client's hook)
    net.dostring_in("server", [[
        ATC = ATC or {}
        ATC._radioFreqs = {}
        function ATC.getRadioFrequencies(unitName)
            return ATC._radioFreqs[unitName] or {}
        end
        function ATC.setRadioFrequencies(unitName, freqs)
            if unitName and unitName ~= "" then
                ATC._radioFreqs[unitName] = freqs or {}
            end
        end
    ]])
    log.write("DCS-ATC", log.INFO, "Radio frequency store injected into SSE")

    loadFileIntoSSE(base .. "airfields.lua", "airfields.lua")

    local airfieldsDir = base .. "airfields\\"
    local theaters = { "Caucasus", "PersianGulf", "Syria", "Nevada", "Normandy" }
    for _, theater in ipairs(theaters) do
        local dir = airfieldsDir .. theater
        for fName in lfs.dir(dir) do
            if fName:match("%.lua$") then
                loadFileIntoSSE(dir .. "\\" .. fName, theater .. "/" .. fName)
            end
        end
    end

    local rwyCount = net.dostring_in("server", [[
        local n = 0; for _ in pairs(ATC.runways or {}) do n = n + 1 end
        return tostring(n)
    ]])
    log.write("DCS-ATC", log.INFO, "Loaded " .. tostring(rwyCount) .. " airfield entries")

    loadFileIntoSSE(base .. "controllers/phrasedur.lua",  "controllers/phrasedur.lua")
    loadFileIntoSSE(base .. "ATC_Script.lua",  "ATC_Script.lua")
    loadFileIntoSSE(base .. "ATC_Script2.lua", "ATC_Script2.lua")
    loadFileIntoSSE(base .. "ATC_Script3.lua", "ATC_Script3.lua")

    local symCheck = net.dostring_in("server", [[
        local function f(n) return type(ATC and ATC[n]) end
        return string.format(
            "P1: textToTokens=%s radioMsg=%s  P2: buildFullMenu=%s onInboundRequest=%s  P3: onSimStart=%s checkGlideslopes=%s",
            f("textToTokens"), f("radioMsg"),
            f("buildFullMenu"), f("onInboundRequest"),
            f("onSimStart"), f("checkGlideslopes"))
    ]])
    log.write("DCS-ATC", log.INFO, "sym-check: " .. tostring(symCheck))

    _atcHook._startPending = true
    _atcHook._frameCount   = 0
end

function _atcHook.onSimulationFrame()
    -- ── Boot sequence (first 120 frames after sim start) ─────────────────────
    if _atcHook._startPending then
        _atcHook._frameCount = _atcHook._frameCount + 1
        if _atcHook._frameCount == 120 then
            _atcHook._startPending = false
            local bootResult = net.dostring_in("server", [[
                if ATC and ATC.onSimStart then
                    local ok, err = pcall(ATC.onSimStart)
                    return ok and "onSimStart OK" or ("onSimStart ERROR: " .. tostring(err))
                end
                return "ATC.onSimStart is nil!"
            ]])
            log.write("DCS-ATC", log.INFO, "onSimStart result: " .. tostring(bootResult))
        end
        return
    end

    if not _atcHook._simRunning then return end

    -- ── 1 Hz real-time radio frequency polling ────────────────────────────────
    -- Uses the export environment (where GetDevice is available) to read live
    -- cockpit radio frequencies, then pushes them into the SSE.
    local now = os.time()
    if now == _atcHook._lastRadioPoll then return end
    _atcHook._lastRadioPoll = now

    local ok, exportOk, exportResult = pcall(net.dostring_in, "export", _EXPORT_RADIO_SCAN)
    if not ok or not exportOk or not exportResult or exportResult == "" then return end

    -- exportResult is "UnitName|Hz1,Hz2,..."
    local pipePos = exportResult:find("|", 1, true)
    if not pipePos then return end

    local unitName = exportResult:sub(1, pipePos - 1)
    local freqsPart = exportResult:sub(pipePos + 1)
    if unitName == "" then return end

    -- Build a Lua table constructor string: {mhz1, mhz2, ...}
    local mhzParts = {}
    for hzStr in freqsPart:gmatch("[^,]+") do
        local hz = tonumber(hzStr)
        if hz then
            -- Round to 3 decimal MHz (5 kHz precision, same as SRS)
            mhzParts[#mhzParts + 1] = string.format("%.3f", hz / 1000000)
        end
    end

    -- Escape the unit name for safe embedding in Lua (replace special chars)
    local safeUnit = unitName:gsub('[\\"]', '\\%0')  -- escape backslash and quote
    local freqTableStr = "{" .. table.concat(mhzParts, ",") .. "}"

    net.dostring_in("server", string.format(
        'if ATC and ATC.setRadioFrequencies then ATC.setRadioFrequencies("%s", %s) end',
        safeUnit, freqTableStr))

    local debugLine = unitName .. "=" .. freqTableStr
    if debugLine ~= _atcHook._lastRadioDebug then
        _atcHook._lastRadioDebug = debugLine
        log.write("DCS-ATC", log.INFO, "Live radios " .. debugLine)
    end
end

function _atcHook.onSimulationStop()
    _atcHook._startPending = false
    _atcHook._frameCount   = 0
    _atcHook._simRunning   = false
end

DCS.setUserCallbacks(_atcHook)
