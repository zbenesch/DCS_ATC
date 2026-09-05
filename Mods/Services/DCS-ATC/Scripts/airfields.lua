-- Airfields utility functions for DCS-ATC
-- Individual airport data is loaded from airfields/<theater>/*.lua by the hook.
ATC = ATC or {}

-- Wind at a field, in the form ATC actually reports it.
-- Returns (directionWindComesFrom_magnetic, speedKt) -- both already rounded, so
-- callers can drop them straight into "wind %03d at %d".
--
-- Three conversions happen here, all of which used to be missing:
--   * atmosphere.getWind returns a velocity vector, i.e. the direction the air
--     is travelling TOWARD. ATC reports where it comes FROM, so +180.
--   * DCS wind is m/s; ATC reports knots.
--   * DCS is true north; runway headings in ATC.runways are magnetic, and
--     getActiveRwyHdg compares the two directly.
-- Sampled 10 m above the field, the standard anemometer height, rather than
-- exactly at ground level.
function ATC.getWind(abPos)
	local windToTrue, speedMs = nil, nil

	if abPos and atmosphere and atmosphere.getWind then
		local ok, v = pcall(atmosphere.getWind,
			{ x = abPos.x, y = (abPos.y or 0) + 10, z = abPos.z })
		if ok and v and type(v.x) == "number" and type(v.z) == "number" then
			speedMs = math.sqrt(v.x * v.x + v.z * v.z)
			if speedMs > 0.01 then
				windToTrue = math.deg(math.atan2(v.z, v.x)) % 360
			else
				windToTrue = 0
			end
		end
	end

	-- Fallback: static mission weather. The mission file stores the direction
	-- the wind blows toward, same convention as the velocity vector above.
	if not windToTrue then
		local wind = env and env.mission and env.mission.weather
		             and env.mission.weather.wind and env.mission.weather.wind.atGround
		if not wind then return 0, 0 end
		speedMs    = wind.speed or 0
		windToTrue = (wind.dir or 0) % 360
	end

	local fromTrue = (windToTrue + 180) % 360
	local fromMag  = ATC.toMag and ATC.toMag(fromTrue) or fromTrue
	local dir      = math.floor(fromMag + 0.5) % 360
	if dir == 0 then dir = 360 end
	return dir, math.floor(speedMs * 1.94384 + 0.5)
end

-- Returns the active runway magnetic heading and whether it is the reciprocal.
-- Uses the headwind component: the runway end with more headwind is preferred.
function ATC.getActiveRwyHdg(abName)
	local rwy = ATC.runways and ATC.runways[abName]
	if not rwy then return nil, false end
	local ab    = Airbase and Airbase.getByName and Airbase.getByName(abName)
	local abPos = ab and ATC.getAirbasePos and ATC.getAirbasePos(ab)
	local windDir, windSpd = ATC.getWind(abPos)
	local function headwind(hdg)
		local diff = math.abs(hdg - windDir)
		if diff > 180 then diff = 360 - diff end
		return windSpd * math.cos(math.rad(diff))
	end
	local recipHdg = rwy.reciprocal or ((rwy.hdg + 180) % 360)
	if headwind(rwy.hdg) >= headwind(recipHdg) then
		return rwy.hdg, false
	else
		return recipHdg, true
	end
end

-- True when the runway is free for `forUnitName`.
-- `forUnitName` is optional. The aircraft currently holding the runway
-- reservation gets `true` for itself, so an aircraft that has just been cleared
-- to land is not subsequently told its own runway is occupied.
function ATC.isRunwayClear(abName, forUnitName)
	local fs = ATC.state and ATC.state.airfields and ATC.state.airfields[abName]
	if not fs then return false end
	if fs.rwyClear then return true end
	return forUnitName ~= nil and fs.rwyOccupiedBy == forUnitName
end

-- Reserves the runway for a single aircraft. Recorded by name so the holder can
-- be told the runway is clear for itself and so only the holder can release it.
function ATC.reserveRunway(abName, unitName)
	local fs = ATC.getFieldState(abName)
	fs.rwyClear      = false
	fs.rwyOccupiedBy = unitName
end

-- Releases the runway, but only if `unitName` holds it -- one aircraft's
-- go-around or rollout must not clear another aircraft's reservation.
-- Pass unitName = nil to force a release (mission-level cleanup).
function ATC.releaseRunway(abName, unitName)
	local fs = ATC.getFieldState(abName)
	if unitName and fs.rwyOccupiedBy and fs.rwyOccupiedBy ~= unitName then
		return false
	end
	fs.rwyClear      = true
	fs.rwyOccupiedBy = nil
	return true
end

function ATC.generateStandardCRPs(arpLat, arpLon, runwayHeading, distanceNM)
	-- Generate 4 standard CRP corners at compass points around ARP
	-- distanceNM: distance from ARP (default 8 NM)
	distanceNM = distanceNM or 8.0
	local R = 6371.0  -- Earth radius in km
	local NMtoKm = 1.852
	local distKm = distanceNM * NMtoKm
	local distRad = distKm / R
	
	local lat1 = math.rad(arpLat)
	local lon1 = math.rad(arpLon)
	local crps = {}
	
	-- Four compass bearings: 0°=N, 90°=E, 180°=S, 270°=W
	local bearings = {
		{ name="North", bearing=0, namePrefix="" },
		{ name="East", bearing=90, namePrefix="" },
		{ name="South", bearing=180, namePrefix="" },
		{ name="West", bearing=270, namePrefix="" },
	}
	
	for i, bearing_info in ipairs(bearings) do
		local theta = math.rad(bearing_info.bearing)
		
		-- Haversine-based calculation for lat/lon at bearing and distance
		local lat2 = math.asin(math.sin(lat1) * math.cos(distRad) +
		                        math.cos(lat1) * math.sin(distRad) * math.cos(theta))
		local lon2 = lon1 + math.atan2(math.sin(theta) * math.sin(distRad) * math.cos(lat1),
		                                math.cos(distRad) - math.sin(lat1) * math.sin(lat2))
		
		table.insert(crps, {
			name = bearing_info.namePrefix .. bearing_info.name,
			seq = i,
			lat = math.deg(lat2),
			lon = math.deg(lon2),
		})
	end
	
	return crps
end

ATC.runways = ATC.runways or {}

return ATC
