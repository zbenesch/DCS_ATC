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
_atcHook._lastRadioPollDiag = 0

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

-- Code injected once into the export env at mission start.
-- Wraps LuaExportBeforeNextFrame so it runs in the cockpit frame loop
-- where GetDevice() and LoGetSelfData() are always available.
local _EXPORT_FRAME_INJECT = [[
    local _dcsatc_prevFrame = LuaExportBeforeNextFrame
    local _dcsatc_pollTime  = 0
    LuaExportBeforeNextFrame = function()
        -- Chain to existing export handler (SRS, TacView, etc.)
        if _dcsatc_prevFrame then
            local ok_p, _ = pcall(_dcsatc_prevFrame)
        end
        -- Throttle to 1 Hz
        local now = os.time()
        if now == _dcsatc_pollTime then return end
        _dcsatc_pollTime = now
        -- Read player identity (different DCS APIs/modules may expose
        -- different fields for the same unit: Name vs UnitName).
        local ok_self, sd = pcall(LoGetSelfData)
        if not ok_self or type(sd) ~= "table" then return end
        local unitKeys = {}
        local function addKey(v)
            if type(v) == "string" and v ~= "" then
                for _, e in ipairs(unitKeys) do
                    if e == v then return end
                end
                unitKeys[#unitKeys + 1] = v
            end
        end
        addKey(sd.Name)
        addKey(sd.UnitName)
        -- Also push under the DCS pilot/player name so the server can match via
        -- unit:getPlayerName() regardless of whether UnitName is populated.
        local ok_pid, pid = pcall(function()
            return net and net.get_my_player_id and net.get_my_player_id()
        end)
        if ok_pid and pid and pid ~= 0 then
            local ok_nm, nm = pcall(function() return net.get_name(pid) end)
            if ok_nm and type(nm) == "string" and nm ~= "" then addKey(nm) end
        end
        if #unitKeys == 0 then return end
        -- Scan cockpit devices for radio frequencies
        local seen, list = {}, {}
        for devId = 0, 64 do
            local ok_d, dev = pcall(GetDevice, devId)
            if ok_d and dev and type(dev) ~= "number" then
                local ok_f, raw = pcall(function() return dev:get_frequency() end)
                if ok_f and type(raw) == "number" and raw > 0 then
                    -- Normalise to MHz (handle Hz / kHz / MHz returns)
                    local mhz
                    if     raw >= 1e8 then mhz = raw / 1e6
                    elseif raw >= 1e5 then mhz = raw / 1e3
                    elseif raw >= 100 then mhz = raw
                    end
                    if mhz and mhz >= 100 and mhz <= 500 then
                        local key = math.floor(mhz * 1000 + 0.5)
                        if not seen[key] then
                            seen[key] = true
                            list[#list+1] = string.format("%.3f", mhz)
                        end
                    end
                end
            end
        end
        -- Push frequencies to SSE.
        -- Also store in a global in case net.dostring_in is unavailable here.
        local tbl  = "{" .. table.concat(list, ",") .. "}"
        _dcsatc_radioResult = table.concat(unitKeys, ";") .. "|" .. table.concat(list, ",")
        local cmd = 'if ATC and ATC.setRadioFrequencies then '
        for _, key in ipairs(unitKeys) do
            local safe = key:gsub('["\\]', '\\%0')
            cmd = cmd .. 'ATC.setRadioFrequencies("' .. safe .. '", ' .. tbl .. ') '
        end
        cmd = cmd .. 'end'
        pcall(net.dostring_in, "server", cmd)
    end
    return "ok"
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


    -- Load core ATC scripts in correct order: ATC_Script.lua FIRST
    loadFileIntoSSE(base .. "ATC_Script.lua",  "ATC_Script.lua")
    loadFileIntoSSE(base .. "ATC_Script2.lua", "ATC_Script2.lua")
    loadFileIntoSSE(base .. "ATC_Script3.lua", "ATC_Script3.lua")

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

    local symCheck = net.dostring_in("server", [[
        local function f(n) return type(ATC and ATC[n]) end
        return string.format(
            "P1: textToTokens=%s radioMsg=%s  P2: buildFullMenu=%s onInboundRequest=%s  P3: onSimStart=%s checkGlideslopes=%s",
            f("textToTokens"), f("radioMsg"),
            f("buildFullMenu"), f("onInboundRequest"),
            f("onSimStart"), f("checkGlideslopes"))
    ]])
    log.write("DCS-ATC", log.INFO, "sym-check: " .. tostring(symCheck))

    -- Inject radio poller into the export env's per-frame callback.
    -- LuaExportBeforeNextFrame runs natively in the cockpit frame loop where
    -- GetDevice() and LoGetSelfData() are guaranteed to be available.
    -- Results are pushed directly to SSE via net.dostring_in("server", ...),
    -- and also stored in _dcsatc_radioResult as a fallback for onSimulationFrame.
    local exportInjectOk, exportInjectResult = pcall(net.dostring_in, "export", _EXPORT_FRAME_INJECT)
    log.write("DCS-ATC", log.INFO,
        "Export frame-hook inject: ok=" .. tostring(exportInjectOk)
        .. " result=" .. tostring(exportInjectResult))

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

    -- ── 1 Hz fallback radio poll ─────────────────────────────────────────────
    -- Primary path: the injected LuaExportBeforeNextFrame calls
    --   net.dostring_in("server", ATC.setRadioFrequencies(...)) directly.
    -- Fallback (if net unavailable in export env): the injected hook writes
    --   _dcsatc_radioResult as a global; we read + push it here.
    local now = os.time()
    if now == _atcHook._lastRadioPoll then return end
    _atcHook._lastRadioPoll = now

    local ok_r, rb1, rb2 = pcall(net.dostring_in, "export",
        "return (_dcsatc_radioResult or '')")
    if not ok_r then return end

    local rawResult = nil
    if type(rb1) == "string" then
        rawResult = rb1
    elseif type(rb1) == "boolean" and rb1 and type(rb2) == "string" then
        rawResult = rb2
    end

    if not rawResult or rawResult == "" then return end

    -- rawResult is "UnitKey1;UnitKey2|mhz1,mhz2,..." (normalised in export hook)
    local pipePos = rawResult:find("|", 1, true)
    if not pipePos then return end

    local keyPart = rawResult:sub(1, pipePos - 1)
    local freqsPart = rawResult:sub(pipePos + 1)
    if keyPart == "" then return end

    local mhzParts = {}
    for mhzStr in freqsPart:gmatch("[^,]+") do
        if tonumber(mhzStr) then
            mhzParts[#mhzParts + 1] = mhzStr
        end
    end

    local freqTableStr = "{" .. table.concat(mhzParts, ",") .. "}"

    local cmd = "if ATC and ATC.setRadioFrequencies then "
    local firstKey = nil
    for key in keyPart:gmatch("[^;]+") do
        if key and key ~= "" then
            if not firstKey then firstKey = key end
            local safe = key:gsub('["\\]', '\\%0')
            cmd = cmd .. string.format('ATC.setRadioFrequencies("%s", %s) ', safe, freqTableStr)
        end
    end
    cmd = cmd .. "end"
    net.dostring_in("server", cmd)

    local debugLine = tostring(firstKey or keyPart) .. "=" .. freqTableStr
    if debugLine ~= _atcHook._lastRadioDebug then
        _atcHook._lastRadioDebug = debugLine
        log.write("DCS-ATC", log.INFO, "Live radios (fallback) " .. debugLine)
    end
end

function _atcHook.onSimulationStop()
    _atcHook._startPending = false
    _atcHook._frameCount   = 0
    _atcHook._simRunning   = false
end

DCS.setUserCallbacks(_atcHook)
