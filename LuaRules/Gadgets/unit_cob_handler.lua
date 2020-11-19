
function gadget:GetInfo()
  return {
    name      = "Cob Call Handler",
    desc      = "used to handle calls from cob scripts",
    author    = "raaar",
    date      = "Mar 2015",
    license   = "PD",
    layer     = 2,
    enabled   = true
  }
end

local spEcho = Spring.Echo
local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCommands = Spring.GetUnitCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID 
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamList = Spring.GetTeamList
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitTransporter = Spring.GetUnitTransporter
local floor = math.floor

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
    return
end

-- GLOBAL overkill prevention maps
-- map fire frame by target unit id
GG.unitFireFrameByTargetId = {}
GG.lessThan500HPTargetDefIds = {}
GG.OKP_FRAMES = 90		-- 3 seconds
GG.mobilityModifier = {}
local COMSAT_OKP_FRAMES = 30*30 -- 30s
local comsatFireFrameByAllyIdAndPosition = {}
local comsatAllowIdThisFrameByAllyIdAndPosition = {}

local comsatBeaconDefId = UnitDefNames["cs_beacon"].id
 
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- checks if player has enough energy to enable or disable certain unit abilities
function checkEnergy(unitID, unitDefID, teamID, data)

	-- get team energy
	local currentLevelE,storageE,_,incomeE,expenseE,_,_,_ = Spring.GetTeamResources(teamID,"energy")
	-- if greater than threshold, return 1
	if currentLevelE > data then
		return 1
	end

	-- else return 0
	return 0
end

-- resets the reload status for a unit's weapons
function resetReload(unitID, unitDefID, teamID, data)
	local ud = UnitDefs[unitDefID]
	--Spring.Echo(ud.name.." reset its reload cycle")
	if ud.weapons and ud.weapons[1] and ud.weapons[1].weaponDef then
		for wNum,w in pairs(ud.weapons) do
			local weap=WeaponDefs[w.weaponDef]
		    if weap.isShield == false and weap.description ~= "No Weapon" then
		    	--Spring.Echo(ud.name.." reset reload cycle for weapon "..wNum)
		    	spSetUnitWeaponState(unitID,wNum,"reloadFrame",spGetGameFrame() + spGetUnitWeaponState(unitID,wNum,"reloadTime") * 30)
		    end
		end
    end
	    
	return 0
end

-- delays the reload timer for a unit's weapons
-- if delay <= 10 frames, delay is relative to previous reload frame
-- (so it only affects weapons still reloading)
-- else, delay is relative to current frame
function delayReload(unitID, unitDefID, teamID, delay)
	if delay and delay > 0 then
		local ud = UnitDefs[unitDefID]

		-- skip units being transported as the reloading is frozen		
		local tId = spGetUnitTransporter(unitID)
		if (tId ~= nil) then
			return 0
		end
		
		if ud.weapons and ud.weapons[1] and ud.weapons[1].weaponDef then
			for wNum,w in pairs(ud.weapons) do
				local weap=WeaponDefs[w.weaponDef]
			    if weap.isShield == false and weap.description ~= "No Weapon" then
			    	local reloadFrame = spGetUnitWeaponState(unitID,wNum,"reloadFrame")
					
					if delay > 10 then
						-- force weapon into reload after at least delay frames 
						reloadFrame = math.max(reloadFrame,spGetGameFrame()) + delay
					else
			    	  -- adds delay frames to weapon's reload frame (which may be in the past)
			    		reloadFrame = reloadFrame + delay
			    	end
			    	
			    	--Spring.Echo(ud.name.." reset reload cycle for weapon "..wNum)
			    	spSetUnitWeaponState(unitID,wNum,"reloadFrame",reloadFrame)
			    end
			end
	    end
		    
		return 0
	end
end


-- sets mobility to a percentage of the max value for a unit
function setMobility(unitID, unitDefID, teamID, mobPercent)
	if mobPercent then
		GG.mobilityModifier[unitID] = mobPercent / 100
	end
end

-- returns the next free build point, if any
-- for factories with multiple pads
function getBuildPt(unitID, unitDefID, teamID)
	
	-- if this is called, allowUnitCreation was already called and set a unit rules parameter with the piece number
	local buildPt = spGetUnitRulesParam(unitID,"build_pt")
	
	return buildPt
end

-- sets the current height level (0-10)
-- for units like fortification gates that can be raised or lowered
function setHeightLevel(unitID, unitDefID, teamID, heightLevel)
	
	spSetUnitRulesParam(unitID,"height_level",heightLevel)
	
	return 0
end

-- cancels attack orders
function stopFiring(unitID, unitDefID, teamID, data)
	cmds = spGetUnitCommands(unitID,5)
	-- stop the unit
	if (cmds and (#cmds > 0)) then
		for i,cmd in ipairs(cmds) do
			if cmd["id"] == CMD.ATTACK then
				--Spring.Echo("unit "..unitID.." attack order cancelled")
				spGiveOrderToUnit(unitID, CMD.STOP,{},{})
			end
		end
	end
	return 0
end

function cobDebug(unitID, unitDefID, teamID, data1, data2)
	spEcho("uId="..unitID.." f="..spGetGameFrame().." DEBUG1="..data1.." DEBUG2="..tostring(data2))
end


-- checks if a unit is allowed to fire at a target
-- returns 0 (deny) or 1 (allow) 
function checkAllowFiring(unitID, unitDefID, teamID, wNum, targetID)
	local f = spGetGameFrame()
	local result = 1
	
	if targetID and tonumber(targetID) > 0 then
		local defId = spGetUnitDefID(targetID)
		if (defId and GG.lessThan500HPTargetDefIds[defId]) then
			local lastFireFrame = GG.unitFireFrameByTargetId[targetID]
			if ( lastFireFrame and (f - lastFireFrame < GG.OKP_FRAMES) ) then
				--Spring.Echo("f="..f.."unit "..unitID.." prevented from firing weapon "..wNum.." at target "..tostring(targetID))
				result = 0
			end
		end 
	end

	--Spring.Echo("f="..f.." unit "..unitID.." checking if fire weapon "..wNum.." at target "..tostring(targetID).." : "..(result==1 and "YES" or "NO" ))
	return result
end


-- marks that a unit fired at a target
function checkLockTarget(unitID, unitDefID, teamID, targetID)
	local f = spGetGameFrame()
	local result = 1
	
	if targetID and tonumber(targetID) > 0 then
		local defId = spGetUnitDefID(targetID)
		if (defId and GG.lessThan500HPTargetDefIds[defId]) then
			GG.unitFireFrameByTargetId[targetID] = f
		end 
	end
	
	--Spring.Echo("f="..f.." unit "..unitID.." fired at target "..tostring(targetID))
end

local COMSAT_ZONE_SIZE = 512
--TODO this is probably slow, but should be ok as there are relatively few comsats in play 
function getComsatZoneIndex(px,pz)
	return floor(px/COMSAT_ZONE_SIZE) .."_".. floor(pz/COMSAT_ZONE_SIZE) 
end

-- checks if a unit is allowed to fire at a target
-- specific for comsat stations
-- returns 0 (deny) or 1 (allow) 
function checkComsatAllowFiring(unitID, unitDefID, teamID, wNum, targetID)
	local f = spGetGameFrame()
	local result = 1
	local allyId = spGetUnitAllyTeam(unitID)
	local index = ""
	local px,py,pz
	if targetID and tonumber(targetID) > 0 then
		px,py,pz = spGetUnitPosition(targetID)
	else
		-- check target of attack order
		cmds = spGetUnitCommands(unitID,5)
		if (cmds and (#cmds > 0)) then
			for i,cmd in ipairs(cmds) do
				if cmd["id"] == CMD.ATTACK then
					local pos = cmd["params"]
					if (pos and pos[1]) then
						px=pos[1]
						pz=pos[3]
					end
					--Spring.Echo("unit "..unitID.." target=("..pos[1]..","..pos[2]..","..pos[3]..")")
					break
				end
			end
		end
	end
	
	if (px) then
		
		-- check comsat firing status
		index = getComsatZoneIndex(px,pz)
		-- if another comsat got to aim this frame and is pointed at the target, do not allow it to fire
		if comsatAllowIdThisFrameByAllyIdAndPosition[allyId][index] and comsatAllowIdThisFrameByAllyIdAndPosition[allyId][index] ~= unitID then
			result = 0
		else
			local lastFireFrame = comsatFireFrameByAllyIdAndPosition[allyId][index]
			if ( lastFireFrame and (f - lastFireFrame < COMSAT_OKP_FRAMES) ) then
				--Spring.Echo("f="..f.."unit "..unitID.." prevented from comsatting target "..tostring(targetID))
				result = 0
			end
		end
		if (result == 1) then
			comsatAllowIdThisFrameByAllyIdAndPosition[allyId][index] = unitID
		end
		
		-- if allowed, check for allied comsat beacons at position and mark it if they're still active
		--if (result == 1) then
		--	for _,tId in pairs(spGetTeamList(allyId)) do
		--		for _,uId in pairs(spGetUnitsInRectangle(px-500,pz-500,px+500,pz+500,tId)) do
		--			if (spGetUnitDefID(uId) == comsatBeaconDefId) then
		--				comsatFireFrameByAllyIdAndPosition[allyId][index] = f 
		--				Spring.Echo("f="..f.."unit "..unitID.." prevented from comsatting target (beacon)"..tostring(targetID))
		--				result = 0
		--				break
		--			end
		--		end
		--	end
		--end
	
	end
	

	--Spring.Echo("f="..f.." unit "..unitID.." comsat check for position "..index.." : "..(result==1 and "YES" or "NO" ))
	return result
end


-- marks that a comsat fired at a target position or unit
function checkComsatLockTarget(unitID, unitDefID, teamID, targetID)
	local f = spGetGameFrame()
	local result = 1
	local allyId = spGetUnitAllyTeam(unitID)
	if targetID and tonumber(targetID) > 0 then
		local px,py,pz = spGetUnitPosition(targetID)
		if (px) then 
			local index = getComsatZoneIndex(px,pz)
			comsatFireFrameByAllyIdAndPosition[allyId][index] = f
		end
	else
		-- check target of attack order?
		cmds = spGetUnitCommands(unitID,5)
		if (cmds and (#cmds > 0)) then
			for i,cmd in ipairs(cmds) do
				if cmd["id"] == CMD.ATTACK then
					local pos = cmd["params"]

					if (pos and pos[1]) then
						local index = getComsatZoneIndex(pos[1],pos[3])
						comsatFireFrameByAllyIdAndPosition[allyId][index] = f
					end
					break
				end
			end
		end
	end
	
	--Spring.Echo("f="..f.." unit "..unitID.." fired at target "..tostring(targetID))
end

-- sets the unit neutral to avoid being targetted by enemies automatically
function disableEnemyTargetting(unitID, unitDefID, teamID)
	Spring.SetUnitNeutral(unitID,true)	
	return 0
end



---------------------------------------- CALLINS

-- initialize maps
function gadget:Initialize()
	-- find low hp targets to take into account for OKP
    for _,ud in pairs(UnitDefs) do
    	if ud.health <= 500 then
    		GG.lessThan500HPTargetDefIds[ud.id] = true
    	end
    end
    
    -- init comsat position map
    for _,allyId in pairs(spGetAllyTeamList()) do
    	comsatFireFrameByAllyIdAndPosition[allyId] = {}
    end
end

-- clean up 
function gadget:GameFrame(n)

	-- clean up unit okp map
    for k,v in pairs(GG.unitFireFrameByTargetId) do
   		if (n-v > 2*GG.OKP_FRAMES ) then
   			GG.unitFireFrameByTargetId[k] = nil
   		end
    end

	-- clean up comsat okp map
    for _,allyId in pairs(spGetAllyTeamList()) do
    	for k,v in pairs(comsatFireFrameByAllyIdAndPosition[allyId]) do
    		if (n-v > (COMSAT_OKP_FRAMES + 30) ) then
    			comsatFireFrameByAllyIdAndPosition[allyId][k] = nil
    		end
    	end
    	comsatAllowIdThisFrameByAllyIdAndPosition[allyId] = {}
    end
end


gadgetHandler:RegisterGlobal("cobDebug", cobDebug)
gadgetHandler:RegisterGlobal("checkEnergy", checkEnergy)
gadgetHandler:RegisterGlobal("resetReload", resetReload)
gadgetHandler:RegisterGlobal("delayReload", delayReload)
gadgetHandler:RegisterGlobal("getBuildPt", getBuildPt)
gadgetHandler:RegisterGlobal("setHeightLevel", setHeightLevel)
gadgetHandler:RegisterGlobal("delayReload", delayReload)
gadgetHandler:RegisterGlobal("stopFiring", stopFiring)
gadgetHandler:RegisterGlobal("checkComsatAllowFiring", checkComsatAllowFiring)
gadgetHandler:RegisterGlobal("checkComsatLockTarget", checkComsatLockTarget)
gadgetHandler:RegisterGlobal("checkAllowFiring", checkAllowFiring)
gadgetHandler:RegisterGlobal("checkLockTarget", checkLockTarget)
gadgetHandler:RegisterGlobal("setMobility", setMobility)
gadgetHandler:RegisterGlobal("disableEnemyTargetting", disableEnemyTargetting)