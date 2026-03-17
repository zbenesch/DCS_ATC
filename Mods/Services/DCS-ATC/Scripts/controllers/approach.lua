local ATC = ATC or {}

function ATC.onInboundRequest(arg)
	local unitName    = arg.unitName
	local airbaseName = arg.airbaseName
	local rec  = ATC.state.aircraft[unitName]
	if not rec then return end
	local unit = Unit.getByName(unitName)
	if not ATC.isPlayer(unit) then return end
	local cs     = unit:getCallsign() or unitName
	local fs     = ATC.getFieldState(airbaseName)
	local ab     = Airbase.getByName(airbaseName)
	local distNM = ATC.distUnitToBase(unit, ab)
	local altFt  = ATC.getAltFt(unit)
	local seqN   = ATC.addToLandingSeq(unitName, airbaseName)
	rec.seqNum[airbaseName] = seqN

	local distStr = distNM and string.format("%.1f NM", distNM) or "position unknown"
	local altStr  = altFt  and string.format("%d ft",   altFt)  or "altitude unknown"

	rec.greeted[airbaseName] = rec.greeted[airbaseName] or {}
	local greeting = ""
	if not rec.greeted[airbaseName]["Approach"] then
		greeting = "Approach controller, " .. cs .. ". " .. airbaseName .. " Approach.\n"
		rec.greeted[airbaseName]["Approach"] = true
	end

	local response
	if seqN == 1 then
		response = string.format(
			"%s%s\nRadar contact.  %s out at %s.\nNumber 1 for landing.  Hold as assigned.\nExpect approach clearance.",
			greeting, cs, distStr, altStr)
	else
		local aheadName = fs.landingSeq[seqN - 1]
		local aheadUnit = aheadName and Unit.getByName(aheadName)
		local aheadCs   = aheadUnit and aheadUnit:getCallsign() or "preceding traffic"

		response = string.format(
			"%s%s\nRadar contact.  %s out at %s.\nNumber %s for landing.  Follow %s.\nExpect approach clearance when number 1.",
			greeting, cs, distStr, altStr, ATC.sequenceNumber(seqN), aheadCs)
	end

	ATC.setPhase(unitName, airbaseName, "inbound")
	ATC.setEngagedField(unitName, airbaseName)
	ATC.msg(rec.groupId, response)
end


return ATC