-- DCS-ATC mod entry point
-- Install: copy Mods\ and Scripts\ folders into Saved Games\DCS\

declare_plugin("DCS-ATC", {
    installed     = true,
    dirName       = current_mod_path,
    developerName = "DCS-ATC",
    developerLink = "https://github.com/",
    displayName   = _("DCS ATC Script"),
    version       = "1.0.0",
    state         = "installed",
    info          = _("Procedural ATC for DCS World missions.\n\nThe script loads automatically on every mission via the DCS-ATC-hook.lua in Scripts\\Hooks\\. No mission trigger required."),
})

-- Mount phrase OGG library into DCS sound VFS when the current mod scope
-- exposes a mount API. Some service-mod environments do not.
local phrasesPath = current_mod_path .. "\\phrases"
if mount_vfs_sound_path then
    mount_vfs_sound_path(phrasesPath)
elseif VFS and VFS.mount_sound_path then
    VFS.mount_sound_path(phrasesPath)
end

plugin_done()
