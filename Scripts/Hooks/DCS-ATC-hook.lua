-- DCS-ATC hook — auto-loads ATC_Script.lua into each mission's Lua environment.
--
-- Install: copy this file to
--   <Saved Games>\DCS\Scripts\Hooks\DCS-ATC-hook.lua
--
-- How it works:
--   DCS loads all *.lua files in Scripts\Hooks\ into the GUI/Hooks environment.
--   When the simulation starts, onSimulationStart() fires.  We use
--   net.dostring_in('mission', ...) to run a dofile() inside the separate
--   mission-scripting Lua environment, where DCS APIs like timer, trigger,
--   missionCommands, Unit, Airbase, etc. are available.
--
-- NOTE: onSimulationStart is used instead of onMissionLoadEnd because
--   missionCommands (the F10 menu API) and timer are only reliable after the
--   simulation has actually started.  Calls made during onMissionLoadEnd
--   (before the sim starts) are silently discarded by DCS, which is why the
--   F10 menu never appeared.
--
-- The script path is resolved from lfs.writedir() so it works for both
-- DCS stable and DCS open beta (each has its own Saved Games folder).

local _ATC_LOG_NAME = "DCS-ATC"

local _atcHook = {}

function _atcHook.onSimulationStart()
    local ok, err = pcall(function()
        local lfs = require('lfs')
        local scriptPath = lfs.writedir() ..
            "Mods\\Services\\DCS-ATC\\Scripts\\ATC_Script.lua"

        -- Verify the file exists before injecting
        local probe = io.open(scriptPath, "r")
        if not probe then
            log.write(_ATC_LOG_NAME, log.WARNING,
                "ATC_Script.lua not found — skipping auto-load.\n" ..
                "Expected: " .. scriptPath)
            return
        end
        probe:close()

        -- Inject dofile() into the mission Lua sandbox
        -- Use forward slashes to avoid Lua escape issues inside dostring
        local fwdPath = scriptPath:gsub("\\", "/")
        local result, injErr = net.dostring_in('mission',
            string.format('dofile([[%s]])', fwdPath))

        if injErr and injErr ~= "" then
            log.write(_ATC_LOG_NAME, log.ERROR,
                "Error loading ATC_Script.lua: " .. tostring(injErr))
        else
            log.write(_ATC_LOG_NAME, log.INFO,
                "ATC_Script.lua loaded into mission environment.")
        end
    end)

    if not ok then
        log.write(_ATC_LOG_NAME, log.ERROR,
            "DCS-ATC hook exception: " .. tostring(err))
    end
end

DCS.setUserCallbacks(_atcHook)

log.write(_ATC_LOG_NAME, log.INFO, "DCS-ATC hook registered.")
