-- Approach speed profiles (kt) by DCS unit type name
-- Vref (threshold) speeds sourced from DCS aircraft manuals and NATOPS/POH.
-- clean / gear / maxFinal kept for legacy checks; "final" is the authoritative Vref.

local approachSpeeds = {
    -- ── US fixed-wing ─────────────────────────────────────────────────────
    ["F-16C_50"]            = { clean=250, gear=210, final=160, maxFinal=200 },
    ["FA-18C_hornet"]       = { clean=250, gear=200, final=140, maxFinal=180 },
    ["F-15C"]               = { clean=250, gear=220, final=155, maxFinal=200 },
    ["F-15E"]               = { clean=250, gear=220, final=155, maxFinal=200 },
    ["F-14A-135-GR"]        = { clean=250, gear=210, final=134, maxFinal=180 },
    ["F-14B"]               = { clean=250, gear=210, final=134, maxFinal=180 },
    ["A-10C"]               = { clean=200, gear=160, final=130, maxFinal=160 },
    ["A-10C_2"]             = { clean=200, gear=160, final=130, maxFinal=160 },
    ["AV8BNA"]              = { clean=250, gear=200, final=110, maxFinal=150 },
    -- ── Russian / Soviet fixed-wing ───────────────────────────────────────
    ["Su-27"]               = { clean=250, gear=210, final=145, maxFinal=190 },
    ["Su-33"]               = { clean=250, gear=210, final=145, maxFinal=190 },
    ["Su-25T"]              = { clean=200, gear=160, final=135, maxFinal=170 },
    ["Su-25"]               = { clean=200, gear=160, final=135, maxFinal=170 },
    ["MiG-29A"]             = { clean=250, gear=210, final=145, maxFinal=190 },
    ["MiG-29S"]             = { clean=250, gear=210, final=145, maxFinal=190 },
    ["MiG-21Bis"]           = { clean=250, gear=220, final=170, maxFinal=215 },
    -- ── European fixed-wing ───────────────────────────────────────────────
    ["AJS37"]               = { clean=250, gear=200, final=140, maxFinal=185 },
    ["M-2000C"]             = { clean=250, gear=210, final=155, maxFinal=195 },
    -- ── Multi-national ────────────────────────────────────────────────────
    ["JF-17"]               = { clean=250, gear=210, final=145, maxFinal=185 },
    -- ── Trainers / light jets ─────────────────────────────────────────────
    ["C-101CC"]             = { clean=200, gear=160, final=120, maxFinal=155 },
    ["L-39ZA"]              = { clean=200, gear=160, final=115, maxFinal=150 },
    -- ── WWII / prop aircraft ──────────────────────────────────────────────
    ["Yak-52"]              = { clean=140, gear=110, final= 85, maxFinal=115 },
    ["TF-51D"]              = { clean=140, gear=110, final= 90, maxFinal=120 },
    ["P-51D-30-NA"]         = { clean=140, gear=110, final= 90, maxFinal=120 },
    ["Spitfire LF Mk. IXc"] = { clean=130, gear=100, final= 80, maxFinal=110 },
    ["FW-190D9"]            = { clean=170, gear=130, final=105, maxFinal=140 },
    ["Bf-109K-4"]           = { clean=160, gear=130, final=100, maxFinal=135 },
    -- ── Rotary-wing ───────────────────────────────────────────────────────
    ["Mi-8MT"]              = { clean=120, gear= 80, final= 55, maxFinal= 80 },
    ["Ka-50"]               = { clean=120, gear= 80, final= 50, maxFinal= 70 },
    ["Ka-50_3"]             = { clean=120, gear= 80, final= 50, maxFinal= 70 },
    ["UH-1H"]               = { clean=100, gear= 70, final= 50, maxFinal= 70 },
    ["SA342M"]              = { clean=100, gear= 70, final= 40, maxFinal= 60 },
    ["AH-64D_BLK_II"]       = { clean=120, gear= 80, final= 50, maxFinal= 70 },
    -- ── Fallback ──────────────────────────────────────────────────────────
    ["default"]             = { clean=250, gear=180, final=150, maxFinal=200 },
}

return approachSpeeds
