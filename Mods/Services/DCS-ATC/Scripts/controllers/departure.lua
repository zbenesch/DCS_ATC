-- Departure controller logic for DCS-ATC
local ATC = ATC or {}

-- Placeholder for future departure logic
function ATC.onDepartureContact(arg)
	local unitName = arg.unitName
	local airbaseName = arg.airbaseName
	local rec  = ATC.state.aircraft[unitName]
	if not rec then return end
	local unit = Unit.getByName(unitName)
	if not ATC.isPlayer(unit) then return end
	local cs = unit:getCallsign() or unitName
	local fs = ATC.getFieldState(airbaseName)

	-- Determine heading based on selected departure direction
	local dir = rec.departureDirection or "north"
	local heading = 360
	if dir == "north" then heading = 360
	elseif dir == "east" then heading = 90
	elseif dir == "south" then heading = 180
	elseif dir == "west" then heading = 270
	end

	-- Assign outside gate altitude (5000 ft)
	local gateAlt = 5000

	-- Vector message
	local msg = string.format("%s\nDeparture, fly heading %03d, climb to %d ft. Proceed direct to outside gate.", cs, heading, gateAlt)
	ATC.msg(rec.groupId, msg)

	-- Set phase to 'departure'
	ATC.setPhase(unitName, airbaseName, "departure")
	ATC.setEngagedField(unitName, airbaseName)
end

return ATC
-- Periodic check for aircraft crossing the 12nm gate
if not ATC._departureGateTimer then
	ATC._departureGateTimer = timer.scheduleFunction(function()
		for unitName, rec in pairs(ATC.state.aircraft or {}) do
			if rec.phase == "departure" and rec.airbase then
				local unit = Unit.getByName(unitName)
				local ab = Airbase.getByName(rec.airbase)
				if unit and ab then
					local upos = unit:getPoint()
					local apos = ab:getPoint()
					local dx = (upos.x - apos.x) / 1852
					local dz = (upos.z - apos.z) / 1852
					local distNM = math.sqrt(dx*dx + dz*dz)
					if distNM >= 12 then
						-- Time-based greeting
						local hour = os.date("*t").hour
						local greet = "day"
						if hour < 12 then greet = "morning"
						elseif hour < 18 then greet = "afternoon"
						else greet = "evening" end
						local cs = unit:getCallsign() or unitName
						ATC.msg(rec.groupId, string.format("%s\nRadar service terminated. Resume own navigation. Have a good %s!", cs, greet))
						ATC.setPhase(unitName, rec.airbase, "enroute")
					end
				end
			end
		end
		return timer.getTime() + 10
	end, {}, timer.getTime() + 10)
end