-- Tower controller logic for DCS-ATC
local ATC = ATC or {}

-- ...existing code...

function ATC.onTakeoffRequest(arg)
	-- Check for aircraft above the airfield or in the pattern (minimum separation)
	local minVertSep = 500 -- feet
	local minHorizSep = 0.5 -- NM
	local ownUnit = Unit.getByName(unitName)
	local ownPos = ownUnit and ownUnit:getPoint() or nil
	local ownAlt = ownUnit and ownUnit:getPosition().p.y or 0
	local airfieldPatternAlt = fs.patternAlt or 1500
	local conflict = false
	if ownPos then
		for otherName, otherRec in pairs(ATC.state.aircraft) do
			if otherName ~= unitName and otherRec.airbase == airbaseName and otherRec.phase == "pattern" then
				local otherUnit = Unit.getByName(otherName)
				if otherUnit then
					local otherPos = otherUnit:getPoint()
					local otherAlt = otherUnit:getPosition().p.y or 0
					-- Calculate horizontal distance (NM)
					local dx = (ownPos.x - otherPos.x) / 1852
					local dz = (ownPos.z - otherPos.z) / 1852
					local horizDist = math.sqrt(dx*dx + dz*dz)
					local vertDist = math.abs(ownAlt - otherAlt)
					if horizDist < minHorizSep and vertDist < minVertSep then
						conflict = true
						break
					end
				end
			end
		end
	end
	if conflict then
		ATC.msg(rec.groupId, string.format(
			"%s\nHold position.  Aircraft in the pattern or overhead.\nStandby for takeoff clearance.", cs))
		return
	end
	local unitName    = arg.unitName
	local airbaseName = arg.airbaseName
	local rec  = ATC.state.aircraft[unitName]
	if not rec then return end
	local unit = Unit.getByName(unitName)
	if not ATC.isPlayer(unit) then return end
	local cs = unit:getCallsign() or unitName
	local fs = ATC.getFieldState(airbaseName)

	-- Require departure direction selection before clearance
	if not rec.departureDirection then
		ATC.msg(rec.groupId, string.format(
			"%s\nSelect departure direction:", cs))
		-- Present menu options for direction selection (pseudo-code, replace with actual menu logic)
		-- ATC.showMenu(rec.groupId, {
		--     { label = "North", action = function() rec.departureDirection = "north" ATC.onTakeoffRequest(arg) end },
		--     { label = "East",  action = function() rec.departureDirection = "east"  ATC.onTakeoffRequest(arg) end },
		--     { label = "South", action = function() rec.departureDirection = "south" ATC.onTakeoffRequest(arg) end },
		--     { label = "West",  action = function() rec.departureDirection = "west"  ATC.onTakeoffRequest(arg) end },
		-- })
		return
	end

	if not fs.rwyClear then
		ATC.msg(rec.groupId, string.format(
			"%s\nHold position.  Runway not clear.\nStandby for takeoff clearance.",
			cs))
		return
	end

	local already = false
	for _, n in ipairs(fs.departSeq) do
		if n == unitName then already = true break end
	end
	if not already then table.insert(fs.departSeq, unitName) end

	local qpos = #fs.departSeq
	if qpos == 1 then
		-- Get departure frequency from airfield data
		local depFreq = nil
		if fs and fs.frequencies and fs.frequencies.departure then
			depFreq = fs.frequencies.departure.mhz
		end
		-- Get wind data
		local windDir, windSpd = 0, 0
		if ATC.getWind then
			windDir, windSpd = ATC.getWind(airbaseName)
		end
		local windMsg = string.format("Wind %03d at %d knots.", math.floor(windDir + 0.5), math.floor(windSpd + 0.5))
		ATC.msg(rec.groupId, string.format(
			"%s\nRunway clear, cleared for takeoff.\n%s  Cleared for %s departure. After takeoff, contact Departure on %s MHz.",
			cs, windMsg, rec.departureDirection:upper(), depFreq or "[NO FREQ]"))
		fs.rwyClear = false
		ATC.setPhase(unitName, airbaseName, "takeoff")
		ATC.setEngagedField(unitName, airbaseName)
		-- Optionally, trigger handoff logic here or after liftoff event
	else
		ATC.msg(rec.groupId, string.format(
			"%s\nHold short.  Number %s for departure.",
			cs, ATC.sequenceNumber(qpos)))
		ATC.setEngagedField(unitName, airbaseName)
	end
end

function ATC.onReadyDeparture(arg)
	local unitName    = arg.unitName
	local airbaseName = arg.airbaseName
	local rec  = ATC.state.aircraft[unitName]
	if not rec then return end
	local unit = Unit.getByName(unitName)
	if not ATC.isPlayer(unit) then return end
	local cs = unit:getCallsign() or unitName

	ATC.msg(rec.groupId, string.format(
		"%s\nRoger, standby.\nExpect takeoff clearance shortly.", cs))
end

return ATC