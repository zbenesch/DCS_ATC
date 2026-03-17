local ATC = ATC or {}

function ATC.onTaxiRequest(arg)
	local unitName    = arg.unitName
	local unit = Unit.getByName(unitName)
	if not unit or not ATC.isPlayer(unit) then return end
	if not ATC.isGroupLead(unit) then return end
	local rec  = ATC.state.aircraft[unitName]
	local cs = unit:getCallsign() or unitName
	local groupId = rec and rec.groupId or (unit:getGroup() and unit:getGroup():getID())
	if not groupId then return end
	-- Enqueue the request
	-- If controller is free, serve now
	ATC.msg(groupId, string.format("%s\nTaxi clearance granted.", cs))
end
-- ...existing code...

return ATC