function gadget:GetInfo()
  return {
    name      = "Unit engagement range setter",
    desc      = "Sets engagement distance for units with multiple weapons",
    author    = "raaar",
    date      = "2017",
    license   = "PD",
    layer     = 5,
    enabled   = false  
  }
end

--TODO : enable when this works properly, spSetUnitMaxRange does nothing apparently

local spSetUnitMaxRange = Spring.SetUnitMaxRange
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetAllUnits = Spring.GetAllUnits

local RANGE_MARGIN = 50

-- ignore cases : main weapon has the most range and is by far the most relevant
local ignoreCases = {
	[UnitDefNames["gear_might"].id] = true,
	[UnitDefNames["aven_turbulence"].id] = true
	
}

-- special cases : more than two weapons, the middle range weapon is relevant, but the short range ones aren't
local specialCases = {
	[UnitDefNames["gear_edge"].id] = 1100
}

local function updateEngagementRange(unitID, unitDefID)
	-- handle exceptions
	if ignoreCases[unitDefID] then
		return
	elseif specialCases[unitDefID] then
		spSetUnitMaxRange(unitID, specialCases[unitDefID])
		return
	end 

	-- set engagementRange to the shortest range found
	local ud = UnitDefs[unitDefID]
	local engagementRange = 99999999
	if ud.weapons and ud.weapons[1] and ud.weapons[1].weaponDef then
		for wNum,w in pairs(ud.weapons) do
			local weap=WeaponDefs[w.weaponDef]
		    if weap.isShield == false and weap.description ~= "No Weapon" then
		    	local range = spGetUnitWeaponState(unitID,wNum,"range")
		    
				if range < engagementRange then
					engagementRange = range - RANGE_MARGIN
				end
		    end
		end
    end
    
	spSetUnitMaxRange(unitID, engagementRange)
	Spring.Echo("f="..Spring.GetGameFrame().." unit "..ud.name.." engagementRange = "..engagementRange)
end


if (gadgetHandler:IsSyncedCode()) then
	-- update when the unit is created
	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		updateEngagementRange(unitID, unitDefID)
	end
	
	--- update every 5 seconds
	function gadget:GameFrame(n)
		if (n % 150 == 0) then
			for _,unitID in pairs(spGetAllUnits()) do
				unitDefID = spGetUnitDefID(unitID)
				updateEngagementRange(unitID, unitDefID)
			end
		end
	end
end