local ATC = ATC or {}

function ATC.onStartupRequest(arg)
	local unitName = arg.unitName
	local unit = Unit.getByName(unitName)
	if not unit or not ATC.isPlayer(unit) then return end
	-- Handle startup individually, not by group
	local rec = ATC.state.aircraft[unitName]
	local cs = unit:getCallsign() or unitName
	-- Enqueue the request
	local startupAb = rec and rec.engagedField or "Kobuleti"
	ATC.msg(unitName, string.format("%s\nStartup clearance granted. Contact ground when ready to taxi.", cs), false, startupAb, "Ground")
end

function ATC.onTaxiRequest(arg)
	local unitName = arg.unitName
	local unit = Unit.getByName(unitName)
	if not unit or not ATC.isPlayer(unit) then return end
	-- Handle taxi request individually, not by group
	local rec = ATC.state.aircraft[unitName]
	local cs = unit:getCallsign() or unitName
	local groupId = rec and rec.groupId or (unit:getGroup() and unit:getGroup():getID())

	-- Determine airfield
	local airfield = rec and rec.engagedField or "Kobuleti"
	local taxiGraph = ATC.taxiwayGraphs and ATC.taxiwayGraphs[airfield]

	-- Get wind and select best runway, override for heavy loadout
	local rwy07 = ATC.runways and ATC.runways[airfield] and ATC.runways[airfield].hdg or 64
	local rwy25 = ATC.runways and ATC.runways[airfield] and ATC.runways[airfield].reciprocal or 244
	local windDir, windSpd = ATC.getWind and ATC.getWind(ATC.getAirbasePos and ATC.getAirbasePos(Airbase.getByName(airfield))) or 130, 8

	local heavy = arg.heavy or (rec and rec.heavy)

	local bestRwy, bestNode
	if heavy then
		bestRwy = "25"
		bestNode = "RWY25"
	else
		-- Calculate headwind component for each runway
		local function headwind(runwayHdg, windHdg, windSpd)
			local diff = math.abs(runwayHdg - windHdg)
			if diff > 180 then diff = 360 - diff end
			return windSpd * math.cos(math.rad(diff))
		end
		local hw07 = headwind(rwy07, windDir, windSpd)
		local hw25 = headwind(rwy25, windDir, windSpd)
		if hw07 >= hw25 then
			bestRwy = "07"
			bestNode = "RWY07"
		else
			bestRwy = "25"
			bestNode = "RWY25"
		end
	end

	-- Find the nearest taxiway node to the aircraft's current position
	local startNode = nil
	if taxiGraph and taxiGraph.nodes and unit then
		local uPos = unit:getPoint()
		local minDist = math.huge
		for node, data in pairs(taxiGraph.nodes) do
			local dLat = data.lat or 0
			local dLon = data.lon or 0
			local dist = math.sqrt((uPos.z - dLat)^2 + (uPos.x - dLon)^2)
			if data.lat and data.lon then
				dist = ATC.findTaxiRoute and ATC.findTaxiRoute.__haversine and ATC.findTaxiRoute.__haversine(uPos.z, uPos.x, dLat, dLon) or dist
			end
			if dist < minDist then
				minDist = dist
				startNode = node
			end
		end
	end

	-- Find the route
	local route = nil
	if startNode and bestNode and ATC.findTaxiRoute then
		route = ATC.findTaxiRoute(airfield, startNode, bestNode)
	end

	-- Format the route for the pilot
	local routeStr = ""
	if route and #route > 1 then
		local names = {}
		for i, n in ipairs(route) do
			local node = taxiGraph.nodes[n]
			if node then table.insert(names, node.name or n) end
		end
		routeStr = "\nTaxi route: " .. table.concat(names, " → ")
	end

	ATC.msg(groupId, string.format("%s, cleared taxi, hold short runway %s.%s", cs, bestRwy, routeStr), false, airfield, "Ground")
end
-- ...existing code...

return ATC