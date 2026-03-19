-- DCS-ATC Hook
-- Automatically loads DCS-ATC into every mission without .miz editing.
--
-- Architecture:
--   net.dostring_in("server", src)  - loads code into the server scripting
--       environment where world, timer, coalition, trigger, missionCommands
--       and all other SSE APIs are available.

local _atcHook = {}

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

function _atcHook.onMissionLoadEnd()
    log.write("DCS-ATC", log.INFO, "onMissionLoadEnd: will load files at sim start")
end

function _atcHook.onSimulationStart()
    local phrasesPath = lfs.writedir() .. "Mods\\Services\\DCS-ATC\\phrases"
    net.dostring_in("server", string.format(
        "if mount_vfs_sound_path then mount_vfs_sound_path([[%s]]) end", phrasesPath))
    log.write("DCS-ATC", log.INFO, "Sound path mount injected: " .. phrasesPath)

    local base = lfs.writedir() .. "Mods\\Services\\DCS-ATC\\Scripts\\"
    log.write("DCS-ATC", log.INFO, "onSimulationStart: loading files. base=" .. base)
    net.dostring_in("server", string.format("_ATC_BASE = [[%s]]", base))

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
    if not _atcHook._startPending then return end
    _atcHook._frameCount = _atcHook._frameCount + 1

    if _atcHook._frameCount == 120 then
        _atcHook._startPending = false

        local bootResult = net.dostring_in("server", [[
            if ATC and ATC.onSimStart then
                local ok, err = pcall(ATC.onSimStart)
                if ok then
                    return "onSimStart OK"
                else
                    return "onSimStart ERROR: " .. tostring(err)
                end
            else
                return "ATC.onSimStart is nil!"
            end
        ]])
        log.write("DCS-ATC", log.INFO, "onSimStart result: " .. tostring(bootResult))
    end
end

function _atcHook.onSimulationStop()
    _atcHook._startPending = false
    _atcHook._frameCount   = 0
end

DCS.setUserCallbacks(_atcHook)