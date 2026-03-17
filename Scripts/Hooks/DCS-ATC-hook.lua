-- DCS-ATC hook — auto-loads ATC_Script.lua into each mission's Lua environment.
--
-- Install: copy this file to
--   <Saved Games>\DCS\Scripts\Hooks\DCS-ATC-hook.lua
--
-- How it works:
--   DCS loads all *.lua files in Scripts\Hooks\ into the GUI/Hooks environment.
--   When a mission finishes loading, onMissionLoadEnd() fires.  We use
--   net.dostring_in('mission', ...) to run a dofile() inside the separate
--   mission-scripting Lua environment, where DCS APIs like timer, trigger,
--   Unit, Airbase, etc. are available.
--
-- The script path is resolved from lfs.writedir() so it works for both
-- DCS stable and DCS open beta (each has its own Saved Games folder).

local _ATC_LOG_NAME = "DCS-ATC"

local _atcHook = {}
local _atcSoundMounted = false

local function _mountAtcSoundPath(baseDir)
    if _atcSoundMounted then return true end
    local phrasesPath = baseDir .. "Mods\\Services\\DCS-ATC\\phrases"

    if mount_vfs_sound_path then
        mount_vfs_sound_path(phrasesPath)
        _atcSoundMounted = true
        log.write(_ATC_LOG_NAME, log.INFO,
            "Mounted ATC phrase path via mount_vfs_sound_path: " .. phrasesPath)
        return true
    end

    if VFS and VFS.mount_sound_path then
        VFS.mount_sound_path(phrasesPath)
        _atcSoundMounted = true
        log.write(_ATC_LOG_NAME, log.INFO,
            "Mounted ATC phrase path via VFS.mount_sound_path: " .. phrasesPath)
        return true
    end

    log.write(_ATC_LOG_NAME, log.WARNING,
        "No sound-mount API available in hook environment; ATC voice will be unavailable.")
    return false
end

function _atcHook.onMissionLoadEnd()
    local ok, err = pcall(function()
        local lfs = require('lfs')
        local writeDir = lfs.writedir()
        local scriptPath = lfs.writedir() ..
            "Mods\\Services\\DCS-ATC\\Scripts\\ATC_Script.lua"

        _mountAtcSoundPath(writeDir)

        -- Verify the file exists before injecting
        local probe = io.open(scriptPath, "r")
        if not probe then
            log.write(_ATC_LOG_NAME, log.WARNING,
                "ATC_Script.lua not found — skipping auto-load.\n" ..
                "Expected: " .. scriptPath)
            return
        end
        probe:close()

        -- Inject via a mission-side timer so the script loads after the
        -- simulation is actually running. This matches mission-trigger timing
        -- much more closely than calling dofile() immediately at load end.
        local fwdPath = scriptPath:gsub("\\", "/")
        local missionChunk = string.format([[if not __DCS_ATC_HOOK_SCHEDULED then
    __DCS_ATC_HOOK_SCHEDULED = true
    timer.scheduleFunction(function()
        local okLoad, loadErr = pcall(function()
            if not (_G.ATC and _G.ATC.__hookLoaded) then
                dofile([[%s]])
                if _G.ATC then
                    _G.ATC.__hookLoaded = true
                end
            end
        end)
        if not okLoad and env and env.error then
            env.error("DCS-ATC mission auto-load failed: " .. tostring(loadErr))
        elseif okLoad and env and env.info then
            env.info("DCS-ATC mission auto-load executed.")
        end
        return nil
    end, nil, timer.getTime() + 1)
end]], fwdPath)

        local result, injErr = net.dostring_in('mission', missionChunk)

        if injErr and injErr ~= "" then
            log.write(_ATC_LOG_NAME, log.ERROR,
                "Error scheduling ATC_Script.lua auto-load: " .. tostring(injErr))
        else
            log.write(_ATC_LOG_NAME, log.INFO,
                "ATC_Script.lua auto-load scheduled in mission environment.")
        end
    end)

    if not ok then
        log.write(_ATC_LOG_NAME, log.ERROR,
            "DCS-ATC hook exception: " .. tostring(err))
    end
end

DCS.setUserCallbacks(_atcHook)

log.write(_ATC_LOG_NAME, log.INFO, "DCS-ATC hook registered.")
