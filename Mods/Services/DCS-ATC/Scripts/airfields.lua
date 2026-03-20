-- Airfields utility functions for DCS-ATC
-- Individual airport data is loaded from airfields/<theater>/*.lua by the hook.
ATC = ATC or {}

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
