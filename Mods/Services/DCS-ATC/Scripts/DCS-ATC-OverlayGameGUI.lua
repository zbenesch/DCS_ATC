-- DCS-ATC Overlay — GameGUI script
-- Loaded from DCS-ATC-hook.lua via pcall(dofile, ...).
-- Runs in the same Lua state as the hook.
--
-- Shows a numbered ATC menu overlay that mirrors the F10 radio menu,
-- driven entirely by hotkeys (no F10 required).
--
-- All hotkeys are configurable in:
--   Saved Games\DCS\Config\DCS-ATC-Overlay.lua
-- (auto-created with defaults and key-name reference on first run)

log.write("DCS-ATC-Overlay", log.INFO, "Loading DCS-ATC-OverlayGameGUI")

local lfs          = require('lfs')
local net          = require('net')
local DialogLoader = require('DialogLoader')
local Static       = require('Static')

-- ── atcOverlay is a global so the hook can call atcOverlay.onFrame() etc. ────
atcOverlay = {}

-- ── Layout constants ──────────────────────────────────────────────────────────
local WIDTH    = 420
local CONT_W   = WIDTH - 16
local TITLE_H  = 26
local ITEM_H   = 22
local HINT_H   = 18
local PAD      = 6

-- ── Default config ────────────────────────────────────────────────────────────
-- Every key is overridable in Config/DCS-ATC-Overlay.lua.
-- Key name format: see the auto-generated config file for full reference.
atcOverlay.config = {
    key_toggle = "Ctrl+Shift+a",  -- toggle overlay open / close
    key_1      = "[1]",           -- Numpad 1  →  select item 1
    key_2      = "[2]",
    key_3      = "[3]",
    key_4      = "[4]",
    key_5      = "[5]",
    key_6      = "[6]",
    key_7      = "[7]",
    key_8      = "[8]",
    key_9      = "[9]",           -- Numpad 9  →  select item 9
    key_back   = "[0]",           -- Numpad 0  →  back / close
    position   = { x = 10, y = 200 },
}

-- Template written to disk on first run so users have a reference.
local _CONFIG_TEMPLATE = [[
-- DCS-ATC Overlay — key bindings
-- Edit this file to remap any key.  DCS must be restarted to pick up changes.
--
-- ── Key name format ───────────────────────────────────────────────────────────
--   Letters / numbers : "a"  "b"  "1"  "2"  ...   (lower-case for letters)
--   Numpad            : "[0]" "[1]" "[2]" ... "[9]"
--                       "[.]"  "[/]"  "[*]"  "[-]"  "[+]"  (numpad operators)
--   Special keys      : "space"  "return"  "escape"  "backspace"  "tab"
--                       "up"  "down"  "left"  "right"
--                       "f1" .. "f15"
--                       "home"  "end"  "insert"  "delete"
--                       "page up"  "page down"
--   Modifier prefixes : "Ctrl+"  "Alt+"  "Shift+"  (combinable, any order)
--   Examples          : "Ctrl+Shift+a"   "Alt+f5"   "Ctrl+[5]"   "home"
--
-- Note: DCS dxgui only accepts  Ctrl / Alt / Shift  as modifiers.
--       L/R variants (LCtrl, RAlt …) are NOT valid here.
-- ─────────────────────────────────────────────────────────────────────────────

return {
    -- Toggle overlay open / close
    key_toggle = "Ctrl+Shift+a",

    -- Select menu item 1–9  (defaults: Numpad 1–9)
    key_1    = "[1]",
    key_2    = "[2]",
    key_3    = "[3]",
    key_4    = "[4]",
    key_5    = "[5]",
    key_6    = "[6]",
    key_7    = "[7]",
    key_8    = "[8]",
    key_9    = "[9]",

    -- Go back one level, or close if already at the top menu
    key_back = "[0]",

    -- Window position — updated automatically whenever you drag the overlay
    position = { x = 10, y = 200 },
}
]]

-- ── Internal state ─────────────────────────────────────────────────────────────
local _configPath = lfs.writedir() .. "Config\\DCS-ATC-Overlay.lua"
local _dlgPath    = lfs.writedir() .. "Mods\\Services\\DCS-ATC\\UI\\DCS-ATC-Overlay.dlg"

local _window     = nil
local _box        = nil
local _statics    = {}
local _skinTitle  = nil
local _skinItem   = nil
local _skinSub    = nil
local _skinHint   = nil

local _isCreated  = false
local _isOpen     = false   -- visible (floating or pinned)
local _isPinned   = false   -- pinned = visible but click-through (no cursor)
local _curMenu    = nil
local _prevMenu   = nil
local _playerName = nil

local _pendingToggle = 0     -- counter: incremented by hotkey, drained in onFrame
local _pendingSelect = nil
local _pendingBack   = false
local _clickZones    = {}    -- [{n, y1, y2}] — populated by _renderMenu for mouse clicks

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function _log(msg)
    log.write("DCS-ATC-Overlay", log.INFO, tostring(msg))
end

local function _err(msg)
    log.write("DCS-ATC-Overlay", log.ERROR, tostring(msg))
end

local function _doSSE(code)
    local ok, r1, r2 = pcall(net.dostring_in, "server", code)
    if not ok then return nil end
    if type(r1) == "string"                       then return r1 end
    if type(r1) == "boolean" and r1 and
       type(r2) == "string"                       then return r2 end
    return nil
end

local _JSON = nil
local function _decodeJson(str)
    if not str or str == "" then return nil end
    if not _JSON then
        local loader = loadfile("Scripts\\JSON.lua")
        if loader then
            local ok, j = pcall(loader)
            if ok then _JSON = j end
        end
    end
    if _JSON then
        local ok, t = pcall(function() return _JSON:decode(str) end)
        if ok and type(t) == "table" then return t end
    end
    local ok2, t2 = pcall(function() return net.json2lua(str) end)
    if ok2 and type(t2) == "table" then return t2 end
    _err("JSON decode failed: " .. str:sub(1, 120))
    return nil
end

local function _getPlayerName()
    -- Step 1: net.get_player_info "unit_name"
    local ok_pid, pid = pcall(function() return net.get_my_player_id() end)
    _log(string.format("gpn step1: ok=%s pid=%s", tostring(ok_pid), tostring(pid)))
    if ok_pid and pid and pid ~= 0 then
        local ok_un, uname = pcall(function() return net.get_player_info(pid, "unit_name") end)
        _log(string.format("gpn step1b: ok=%s uname=%s", tostring(ok_un), tostring(uname)))
        if ok_un and type(uname) == "string" and uname ~= "" then
            return uname
        end
    end

    -- Step 2: scan all keys from export radio result via SSE
    local ok_r, rb1, rb2 = pcall(net.dostring_in, "export",
        "return (_dcsatc_radioResult or '')")
    local raw = nil
    if ok_r then
        if     type(rb1) == "string"                        then raw = rb1
        elseif type(rb1) == "boolean" and rb1 and
               type(rb2) == "string"                        then raw = rb2
        end
    end
    _log("gpn step2: raw=" .. tostring(raw))
    if raw and raw ~= "" then
        local pipePos = raw:find("|", 1, true)
        if pipePos then
            local keyPart = raw:sub(1, pipePos - 1)
            local keys = {}
            for k in keyPart:gmatch("[^;]+") do keys[#keys + 1] = k end
            if #keys > 0 then
                local jkeys = {}
                for _, k in ipairs(keys) do jkeys[#jkeys+1] = string.format("%q", k) end
                local code = string.format([[
                    local keys = {%s}
                    -- Direct ATC record lookup
                    for _, k in ipairs(keys) do
                        if ATC and ATC.state and ATC.state.aircraft and ATC.state.aircraft[k] then
                            return "atc:" .. k
                        end
                    end
                    -- Direct unit name lookup
                    for _, k in ipairs(keys) do
                        if Unit.getByName(k) then return "unit:" .. k end
                    end
                    -- Match player display name → resolve actual unit name
                    for _, side in ipairs({coalition.side.BLUE, coalition.side.RED}) do
                        for _, grp in ipairs(coalition.getGroups(side) or {}) do
                            for _, u in ipairs(grp:getUnits() or {}) do
                                local pname = u:getPlayerName()
                                if pname then
                                    for _, k in ipairs(keys) do
                                        if k == pname then return "pname:" .. u:getName() end
                                    end
                                end
                            end
                        end
                    end
                    return "none:" .. (keys[1] or "")
                ]], table.concat(jkeys, ","))
                local result = _doSSE(code)
                _log("gpn step2b SSE result=" .. tostring(result))
                if result then
                    local val = result:match("^%w+:(.+)$")
                    if val and val ~= "" then return val end
                end
            end
        end
    end

    -- Step 3: last resort pilot display name
    local ok2, pid2 = pcall(function() return net.get_my_player_id() end)
    if not ok2 or not pid2 or pid2 == 0 then pid2 = 1 end
    local ok3, nm = pcall(function() return net.get_player_info(pid2, "name") end)
    _log("gpn step3: nm=" .. tostring(nm))
    if ok3 and type(nm) == "string" and nm ~= "" then return nm end
    return nil
end

local function _esc(s) return (tostring(s or "")):gsub("'", "\\'") end

-- Human-readable label for a DCS key string used in the hint footer.
-- "[1]" → "Num1",  "Ctrl+Shift+a" → "Ctrl+Shift+A"
local function _keyLabel(k)
    if not k or k == "" then return "?" end
    -- Numpad bracket notation → "Num<x>"
    local inner = k:match("^%[(.+)%]$")
    if inner then return "Num" .. inner end
    -- Capitalise the last component (the key itself, not the modifiers)
    return k:gsub("(%+?)(%a)$", function(sep, ch) return sep .. ch:upper() end)
end

-- ── Config persistence ────────────────────────────────────────────────────────
local function _writeDefaultConfig()
    local f = io.open(_configPath, "w")
    if f then
        f:write(_CONFIG_TEMPLATE)
        f:close()
        _log("Created default config: " .. _configPath)
    end
end

local function _loadConfig()
    -- Write the template on first run so users have a reference.
    local probe = io.open(_configPath, "r")
    if probe then
        probe:close()
    else
        _writeDefaultConfig()
    end

    local ok, cfg = pcall(dofile, _configPath)
    if not ok or type(cfg) ~= "table" then return end

    -- Migrate old single-key format: "hotkey" → "key_toggle"
    if cfg.hotkey and not cfg.key_toggle then
        cfg.key_toggle = cfg.hotkey
    end

    -- Merge every recognised field into the live config.
    local keys = { "key_toggle",
                   "key_1","key_2","key_3","key_4","key_5",
                   "key_6","key_7","key_8","key_9","key_back" }
    for _, k in ipairs(keys) do
        if type(cfg[k]) == "string" and cfg[k] ~= "" then
            atcOverlay.config[k] = cfg[k]
        end
    end
    if type(cfg.position) == "table" then
        atcOverlay.config.position = cfg.position
    end
end

local function _saveConfig()
    local f = io.open(_configPath, "w")
    if not f then return end
    local c   = atcOverlay.config
    local pos = c.position or {}
    f:write("-- DCS-ATC Overlay config  (auto-saved on drag; edit keys manually)\n")
    f:write("return {\n")
    f:write(string.format("    key_toggle = %q,\n",    c.key_toggle or "Ctrl+Shift+a"))
    for i = 1, 9 do
        f:write(string.format("    key_%-6s = %q,\n", i, c["key_"..i] or ("["..i.."]")))
    end
    f:write(string.format("    key_back   = %q,\n",   c.key_back   or "[0]"))
    f:write(string.format("    position   = { x = %d, y = %d },\n",
        math.floor(pos.x or 10), math.floor(pos.y or 200)))
    f:write("}\n")
    f:close()
end

-- ── Menu rendering ────────────────────────────────────────────────────────────
local function _renderMenu()
    if not _isCreated or not _curMenu then return end

    local items = _curMenu.items or {}
    local yOff  = PAD

    _statics.title:setSkin(_skinTitle)
    _statics.title:setBounds(8, yOff, CONT_W, TITLE_H)
    _statics.title:setText(_curMenu.title or "DCS ATC")
    yOff = yOff + TITLE_H

    _clickZones = {}
    for i = 1, 9 do
        local s    = _statics["item" .. i]
        local item = items[i]
        if item then
            local label = "[" .. i .. "]  " .. (item.label or "")
            if item.kind == "sub" then
                s:setSkin(_skinSub)
                label = label .. "  >>"
            else
                s:setSkin(_skinItem)
            end
            s:setBounds(8, yOff, CONT_W, ITEM_H)
            s:setText(label)
            _clickZones[#_clickZones + 1] = { n = i, y1 = yOff, y2 = yOff + ITEM_H }
            yOff = yOff + ITEM_H
        else
            s:setBounds(0, -200, 0, 0)
            s:setText("")
        end
    end

    local c    = atcOverlay.config
    local back = _keyLabel(c.key_back)
    local tog  = _keyLabel(c.key_toggle)
    local togAction = _isPinned and "Close" or "Pin"
    local selHint = (c.topRowSelect ~= false) and "1-9 or Num1-9=Select" or "Num1-9=Select"
    local hint = _prevMenu
        and (back .. "/0=Back    " .. tog .. "=" .. togAction)
        or  (selHint .. "    " .. tog .. "=" .. togAction)
    _statics.hint:setSkin(_skinHint)
    _statics.hint:setBounds(8, yOff + 2, CONT_W, HINT_H)
    _statics.hint:setText(hint)

    local boxH = yOff + HINT_H + PAD
    _box:setBounds(0, 0, WIDTH, boxH)
    _window:setSize(WIDTH, boxH)
    _window:setHasCursor(true)
end

-- ── Open / close ──────────────────────────────────────────────────────────────
local function _openNow()
    _playerName = _getPlayerName()
    if not _playerName then
        _log("open: player name unavailable (spectator/lobby)")
        return
    end

    local jsonStr = _doSSE(string.format(
        "return type(ATC)=='table' and type(ATC.getOverlayMenuJson)=='function' and ATC.getOverlayMenuJson('%s') or ''",
        _esc(_playerName)))

    _curMenu  = _decodeJson(jsonStr)
    _prevMenu = nil

    if not _curMenu or not _curMenu.items or #_curMenu.items == 0 then
        _log("open: no menu data returned for '" .. tostring(_playerName) .. "'")
        return
    end

    _isOpen   = true
    _isPinned = false
    _log("opened ok, player=" .. tostring(_playerName) .. " items=" .. #_curMenu.items)
    _window:setVisible(true)   -- re-show if X button hid it
    _box:setVisible(true)
    _window:setHasCursor(true)
    _renderMenu()
end

local function _pinNow()
    _isPinned = true
    _window:setHasCursor(false)   -- click-through; position locked from floating state
    _renderMenu()                 -- refresh hint: "Close" instead of "Pin"
    _log("pinned")
end

local function _closeNow()
    _isOpen   = false
    _isPinned = false
    _curMenu  = nil
    _prevMenu = nil
    _box:setVisible(false)
    _window:setSize(0, 0)
    _window:setHasCursor(false)
end

local function _selectNow(n)
    if not _isOpen or not _curMenu then return end
    local item = (_curMenu.items or {})[n]
    if not item then return end

    if item.kind == "sub" then
        local jsonStr = _doSSE(string.format(
            "return type(ATC)=='table' and type(ATC.getFieldOverlayMenuJson)=='function' and ATC.getFieldOverlayMenuJson('%s','%s') or ''",
            _esc(_playerName), _esc(item.key)))
        local sub = _decodeJson(jsonStr)
        if sub and sub.items and #sub.items > 0 then
            _prevMenu = _curMenu
            _curMenu  = sub
            _renderMenu()
        end
    elseif item.kind == "cmd" then
        if item.cmd and item.cmd ~= "" then _doSSE(item.cmd) end
        -- Refresh to top-level menu so user can see updated state; stay open.
        _prevMenu = nil
        _openNow()
    end
end

local function _backNow()
    if not _isOpen then return end
    if _prevMenu then
        _curMenu  = _prevMenu
        _prevMenu = nil
        _renderMenu()
    else
        _closeNow()
    end
end

-- ── Hotkey registration helper ────────────────────────────────────────────────
-- Registers a single hotkey; logs a warning on failure but never throws.
local function _addHK(keyStr, callback, label)
    if not keyStr or keyStr == "" then return end
    local ok, err = pcall(_window.addHotKeyCallback, _window, keyStr, callback)
    if not ok then
        _err(string.format("Hotkey '%s' (%s) rejected: %s", keyStr, label, tostring(err)))
    end
end

-- ── Window creation ────────────────────────────────────────────────────────────
local function _createWindow()
    _window = DialogLoader.spawnDialogFromFile(_dlgPath, cdata)
    if not _window then
        _err("Failed to spawn dialog from " .. _dlgPath)
        return
    end

    _box     = _window.Box
    local pSkins = _window.pSkins
    _skinTitle = pSkins.sTitle:getSkin()
    _skinItem  = pSkins.sItem:getSkin()
    _skinSub   = pSkins.sSub:getSkin()
    _skinHint  = pSkins.sHint:getSkin()

    local st = Static.new(); _box:insertWidget(st); _statics.title = st
    local _rowClickOk = true
    for i = 1, 9 do
        local s = Static.new(); _box:insertWidget(s); _statics["item"..i] = s
        -- Click handler goes on the row itself, not the parent Panel. Static
        -- inherits Widget and so is mouse-capable: it sits on top of the Panel
        -- and consumes the 'down' event, which is why the Panel-level handler
        -- never fired. Binding per row also means no hit-testing -- the widget
        -- already knows which item it is.
        local n = i
        local ok = pcall(s.addMouseDownCallback, s, function()
            if _isOpen then _pendingSelect = n end
        end)
        if not ok then _rowClickOk = false end
    end
    if not _rowClickOk then
        _err("row click handlers failed to attach; use the number keys")
    end
    local sh = Static.new(); _box:insertWidget(sh); _statics.hint = sh

    -- ── Register all hotkeys from config ──────────────────────────────────────
    local c = atcOverlay.config

    _addHK(c.key_toggle, function() _pendingToggle = _pendingToggle + 1 end, "toggle")

    -- The configured select keys default to NUMPAD ("[1]".."[9]"), but the menu
    -- renders items as "[1] Contact Tower", so pressing the number row is the
    -- natural thing to do and nothing happened. Bind the top row as well.
    --
    -- Set topRowSelect = false in the config if this steals number-row keys from
    -- the cockpit (ICP, countermeasure programs): DCS GameGUI hotkeys can consume
    -- a keypress before the sim sees it, even while the overlay is closed.
    local topRow = (c.topRowSelect ~= false)
    for i = 1, 9 do
        local n = i
        local sel = function() if _isOpen then _pendingSelect = n end end
        _addHK(c["key_"..i], sel, "select "..i)
        if topRow then _addHK(tostring(n), sel, "select "..n.." (top row)") end
    end

    local back = function() if _isOpen then _pendingBack = true end end
    _addHK(c.key_back, back, "back")
    if topRow then _addHK("0", back, "back (top row)") end

    -- ── Mouse click → select item ─────────────────────────────────────────────
    -- Logged, because a pcall that silently swallows a missing API is
    -- indistinguishable from "clicking does not work" at runtime.
    local _mouseOk, _mouseErr = pcall(_box.addMouseDownCallback, _box, function(_, _, y, _)
        if not _isOpen then return end
        for _, zone in ipairs(_clickZones) do
            if y >= zone.y1 and y < zone.y2 then
                _pendingSelect = zone.n
                break
            end
        end
    end)
    if not _mouseOk then
        _err("mouse click callback NOT attached (clicking will not select): "
             .. tostring(_mouseErr))
    else
        _log("mouse click callback attached")
    end

    -- ── Position tracking ─────────────────────────────────────────────────────
    _window:addPositionCallback(function()
        local x, y = _window:getPosition()
        atcOverlay.config.position = { x = x, y = y }
        _saveConfig()
    end)

    local pos = c.position
    _window:setPosition(pos.x, pos.y)

    _window:setVisible(true)
    _box:setVisible(false)
    _window:setSize(0, 0)
    _window:setHasCursor(false)

    _isCreated = true
    _log(string.format(
        "Window created  toggle=%s  select=[%s..%s]  back=%s",
        c.key_toggle,
        c.key_1 or "[1]", c.key_9 or "[9]",
        c.key_back))
end

-- ── Public interface ──────────────────────────────────────────────────────────
function atcOverlay.onFrame()
    -- (Re)create window if it was never made, or if DCS destroyed it (e.g. X button).
    if not _isCreated then
        local ok, err = pcall(_createWindow)
        if not ok then _err("_createWindow failed: " .. tostring(err)) end
        if not _isCreated then return end
    else
        -- Health check: if DCS silently destroyed the window object, reset and recreate.
        local alive = _window ~= nil and pcall(function() _window:getPosition() end)
        if not alive then
            _isCreated = false; _window = nil; _box = nil; _statics = {}
            _skinTitle = nil; _skinItem = nil; _skinSub = nil; _skinHint = nil
            _isOpen = false; _isPinned = false; _clickZones = {}
            return  -- will recreate on next frame
        end
    end

    local toggleCount = _pendingToggle
    _pendingToggle = 0
    for _ = 1, toggleCount do
        _log("toggle: _isOpen=" .. tostring(_isOpen) .. " _isPinned=" .. tostring(_isPinned))
        if not _isOpen then
            _openNow()          -- hidden  → floating
        elseif not _isPinned then
            _pinNow()           -- floating → pinned
        else
            _closeNow()         -- pinned  → hidden
        end
    end

    if _pendingSelect then
        local n = _pendingSelect; _pendingSelect = nil
        _selectNow(n)

    elseif _pendingBack then
        _pendingBack = false
        _backNow()
    end
end

function atcOverlay.onSimStop()
    _isCreated = false; _window = nil; _box = nil; _statics = {}
    _skinTitle = nil; _skinItem = nil; _skinSub = nil; _skinHint = nil
    _isOpen = false; _isPinned = false; _curMenu = nil; _prevMenu = nil
    _pendingToggle = 0; _pendingSelect = nil; _pendingBack = false
end

-- ── Bootstrap ─────────────────────────────────────────────────────────────────
_loadConfig()

log.write("DCS-ATC-Overlay", log.INFO,
    "DCS-ATC-OverlayGameGUI loaded  toggle=" .. atcOverlay.config.key_toggle)

-- Create the window immediately (like SRS does) so hotkeys work from the main menu.
local _bootOk, _bootErr = pcall(_createWindow)
if not _bootOk then
    log.write("DCS-ATC-Overlay", log.WARNING,
        "Boot _createWindow failed: " .. tostring(_bootErr))
end
