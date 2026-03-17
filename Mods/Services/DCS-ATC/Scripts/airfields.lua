-- Airfields utility functions and runways table for DCS-ATC
local ATC = ATC or {}

function ATC.getWind(abPos)
	if env and env.mission and env.mission.weather and env.mission.weather.wind then
		local wind = env.mission.weather.wind.atGround or { speed = 0, dir = 0 }
		local speed = wind.speed or 0
		local dir = wind.dir or 0
		return dir, speed
	end
	return 0, 0
end

function ATC.isRunwayClear(abName)
	local fs = ATC.state and ATC.state.airfields and ATC.state.airfields[abName]
	if not fs or not fs.rwyClear then return false end
	return fs.rwyClear
end

ATC.runways = {
    -- ── Germany (The Channel, Normandy, etc.) ───────────────
    ["Normandy Carpiquet"] = { hdg=260, reciprocal=80, elevation=256, ILSfreq=0, patternAlt=1756,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Normandy Evreux"] = { hdg=240, reciprocal=60, elevation=526, ILSfreq=0, patternAlt=2026,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Germany map airports here...
    -- ── Afghanistan ────────────────────────────────────────
    ["Bagram"] = { hdg=120, reciprocal=300, elevation=4950, ILSfreq=0, patternAlt=6450,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Afghanistan map airports here...
    -- ── Iraq ───────────────────────────────────────────────
    ["Baghdad Intl"] = { hdg=150, reciprocal=330, elevation=110, ILSfreq=0, patternAlt=1610,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Iraq map airports here...
    -- ── Kola ───────────────────────────────────────────────
    ["Kola Murmansk"] = { hdg=180, reciprocal=0, elevation=150, ILSfreq=0, patternAlt=1650,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Kola map airports here...
    -- ── Sinai ──────────────────────────────────────────────
    ["Sinai Cairo Intl"] = { hdg=200, reciprocal=20, elevation=382, ILSfreq=0, patternAlt=1882,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- Add all other Sinai map airports here...
    -- ── Caucasus ─────────────────────────────────────────────
    ["Batumi"]              = { hdg=130, reciprocal=310, elevation=32,   ILSfreq=110.30, patternAlt=1532,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Kobuleti"]            = { hdg=70,  reciprocal=250, elevation=59,   ILSfreq=111.50, patternAlt=1559, patternDir="R",
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true },
        crps = {
            { name="Black Sea", lat=42.018767, lon=41.752067, rwyHdg=70  },
            { name="South",     lat=41.823583, lon=41.772667, rwyHdg=70  },
            { name="NE",        lat=42.000733, lon=42.001550, rwyHdg=250 },
            { name="East",      lat=41.909883, lon=42.007750, rwyHdg=250 },
        },
    chart = "charts/Caucasus - Aerodrome Charts.pdf"
    },
    ["Kutaisi"]             = { hdg=80,  reciprocal=260, elevation=147,  ILSfreq=109.75, patternAlt=1647,
        frequencies = {
            ground = { mhz=122.000, hz=122000000 },
            tower = { mhz=118.900, hz=118900000 },
            approach = { mhz=123.700, hz=123700000 },
            departure = { mhz=124.400, hz=124400000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Senaki-Kolkhi"]       = { hdg=90,  reciprocal=270, elevation=43,   ILSfreq=108.90, patternAlt=1543,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Sukhumi"]             = { hdg=120, reciprocal=300, elevation=43,   ILSfreq=0,      patternAlt=1543,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Gudauta"]             = { hdg=150, reciprocal=330, elevation=68,   ILSfreq=0,      patternAlt=1568,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true },
    chart = "charts/Caucasus - Aerodrome Charts.pdf"
    },
    ["Sochi-Adler"]         = { hdg=60,  reciprocal=240, elevation=98,   ILSfreq=111.10, patternAlt=1598, patternDir="R",
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Gelendzhik"]          = { hdg=20,  reciprocal=200, elevation=72,   ILSfreq=0,      patternAlt=1572,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true },
    chart = "charts/Caucasus - Aerodrome Charts.pdf"
    },
    ["Anapa-Vityazevo"]     = { hdg=40,  reciprocal=220, elevation=144,  ILSfreq=0,      patternAlt=1644,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krasnodar-Center"]    = { hdg=90,  reciprocal=270, elevation=98,   ILSfreq=0,      patternAlt=1598,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krasnodar-Pashkovsky"] = { hdg=54,  reciprocal=234, elevation=108,  ILSfreq=0,      patternAlt=1608,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Krymsk"]              = { hdg=40,  reciprocal=220, elevation=65,   ILSfreq=0,      patternAlt=1565,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Novorossiysk"]        = { hdg=40,  reciprocal=220, elevation=131,  ILSfreq=0,      patternAlt=1631,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Tbilisi-Lochini"]     = { hdg=130, reciprocal=310, elevation=1624, ILSfreq=110.30, patternAlt=3124,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Vaziani"]             = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=117.60, patternAlt=3023,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Soganlug"]            = { hdg=130, reciprocal=310, elevation=1523, ILSfreq=0,      patternAlt=3023,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Beslan"]              = { hdg=100, reciprocal=280, elevation=1660, ILSfreq=110.50, patternAlt=3160,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118800000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Mozdok"]              = { hdg=80,  reciprocal=260, elevation=507,  ILSfreq=0,      patternAlt=2007,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Nalchik"]             = { hdg=90,  reciprocal=270, elevation=1410, ILSfreq=117.60, patternAlt=2910,
        frequencies = {
            ground = { mhz=121.900, hz=121900000 },
            tower = { mhz=118.800, hz=118700000 },
            approach = { mhz=123.600, hz=123600000 },
            departure = { mhz=124.300, hz=124300000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    ["Mineralnye Vody"]     = { hdg=120, reciprocal=300, elevation=1049, ILSfreq=111.10, patternAlt=2549,
        frequencies = {
            ground = { mhz=121.800, hz=121800000 },
            tower = { mhz=118.700, hz=118700000 },
            approach = { mhz=123.500, hz=123500000 },
            departure = { mhz=124.200, hz=124200000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true }
    },
    -- ── Persian Gulf ─────────────────────────────────────────
    ...existing code...
    -- ── NTTR (Nevada, Real World) ──
    ["North Las Vegas"] = {
        hdg=74, reciprocal=254, elevation=2205, ILSfreq=0, patternAlt=3005,
        frequencies = {
            tower = { mhz=125.7, hz=125700000 },
            tower2 = { mhz=119.15, hz=119150000 },
            ground = { mhz=121.7, hz=121700000 },
            atis = { mhz=118.05, hz=118050000 },
            approach = { mhz=119.4, hz=119400000 },
            approach2 = { mhz=118.125, hz=118125000 },
            clearance = { mhz=124.0, hz=124000000 },
            unicom = { mhz=122.95, hz=122950000 }
        },
        controllers = { ground=true, tower=true, approach=true, departure=true },
        chart = "charts/North Las Vegas.pdf"
    },
    -- ── Persian Gulf (Missing/Extra) ──
    ["Ras Al Khaimah"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Liwa"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Bandar Lengeh"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Havadarya"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── NTTR (Nevada, Missing/Extra) ──
    ["North Las Vegas"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Syria (Missing/Extra) ──
    ["Bassel Al-Assad (Latakia)"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Hama"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Palmyra"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Tabqa"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Ben Gurion"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Hatzor"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Palmachim"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── South Atlantic (Missing/Extra) ──
    ["Mount Pleasant"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Port Stanley"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Rio Gallegos"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Rio Grande"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Ushuaia"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Marianas (Missing/Extra) ──
    ["Tinian Intl"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Sinai (Missing/Extra) ──
    ["Hurghada"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Sharm El Sheikh"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Beni Suef"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Borg El Arab"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Ramon"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Ovda"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Hatzerim"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Tabuk"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Kola Peninsula (Missing/Extra) ──
    ["Severomorsk-1"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Severomorsk-3"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Olenegorsk"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Monchegorsk"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Murmansk"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Rovaniemi"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Kemi-Tornio"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Bodø"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Andøya"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Lakselv (Banak)"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Kiruna"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Afghanistan (Missing/Extra) ──
    ["Kabul"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Kandahar"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Herat"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },

    -- ── Cold War Germany (Missing/Extra) ──
    ["Ramstein"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Spangdahlem"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Bitburg"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Wiesbaden"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Frankfurt Rhein-Main"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Hahn"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Fassberg"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Celle"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Hamburg"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    ["Gatow"] = { hdg=0, reciprocal=0, elevation=0, ILSfreq=0, patternAlt=0,
        frequencies = {}, controllers = {}, chart = "" },
    -- ── Syria ────────────────────────────────────────────────
    ...existing code...
    -- ── Nevada (NTTR) ─────────────────────────────────────────
    ...existing code...
    -- ── Marianas ─────────────────────────────────────────────
    ...existing code...
}

return ATC
