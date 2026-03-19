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

ATC.runways = ATC.runways or {}

return ATC
