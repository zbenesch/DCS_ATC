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
    info          = _("Procedural ATC for DCS World missions.\n\nSetup: add one Mission Start trigger:\n  DO SCRIPT FILE → Mods\\Services\\DCS-ATC\\Scripts\\ATC_Script.lua"),
})

-- Mount phrase OGG library into DCS sound VFS.
-- Files at phrases\<voice>\<token>.ogg become addressable
-- by trigger.action.radioTransmission as "<voice>/<token>.ogg"
mount_vfs_sound_path(current_mod_path .. "\\phrases")

plugin_done()
