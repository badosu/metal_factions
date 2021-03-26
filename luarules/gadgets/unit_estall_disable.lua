--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_estall_disable.lua
--  brief:   disables units during energy stall
--  author:  
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "UnitEStallDisable",
    desc      = "Deactivates units during energy stall",
    author    = "Licho",
    date      = "23.7.2007",
    license   = "GNU GPL, v2 or later",
    layer     = 2,
    enabled   = true
  }
end

-- raaar, aug 2015 : modified unit list

--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
--------------------------------------------------------------------------------
--  SYNCED
--------------------------------------------------------------------------------

--Speed-ups

local insert            = table.insert
local GiveOrderToUnit		= Spring.GiveOrderToUnit
local GetUnitStates			= Spring.GetUnitStates
local GetUnitTeam				= Spring.GetUnitTeam
local GetUnitResources	= Spring.GetUnitResources
local GetGameSeconds    = Spring.GetGameSeconds

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local units = {}
local disabledUnits = {}
local changeStateDelay = 3 -- delay in seconds before state of unit can be changed. Do not set it below 2 seconds, because it takes 2 seconds before enabled unit reaches full energy use
local LOW_ENERGY_DISABLE_THRESHOLD = 800
local LOW_ENERGY_ENABLE_THRESHOLD = 1200
local radarDefs = {
  [ UnitDefNames['aven_advanced_radar_tower'].id ] = true,
  [ UnitDefNames['aven_radar_tower'].id ] = true,
  [ UnitDefNames['aven_radar_jamming_tower'].id ] = true,
  [ UnitDefNames['aven_seer'].id ] = true,
  [ UnitDefNames['aven_jammer'].id ] = true,
  [ UnitDefNames['aven_marky'].id ] = true,
  [ UnitDefNames['aven_eraser'].id ] = true,
  [ UnitDefNames['aven_sonar_station'].id ] = true,
  [ UnitDefNames['aven_advanced_sonar_station'].id ] = true,
  [ UnitDefNames['aven_discovery'].id ] = true,
  [ UnitDefNames['aven_escort'].id ] = true,
  [ UnitDefNames['aven_zephyr'].id ] = true,
  [ UnitDefNames['aven_perceptor'].id ] = true,

  [ UnitDefNames['gear_advanced_radar_tower'].id ] = true,
  [ UnitDefNames['gear_radar_tower'].id ] = true,
  [ UnitDefNames['gear_radar_jamming_tower'].id ] = true,
  [ UnitDefNames['gear_informer'].id ] = true,
  [ UnitDefNames['gear_deleter'].id ] = true,
  [ UnitDefNames['gear_voyeur'].id ] = true,
  [ UnitDefNames['gear_spectre'].id ] = true,
  [ UnitDefNames['gear_advanced_sonar_station'].id ] = true,
  [ UnitDefNames['gear_sonar_station'].id ] = true,
    [ UnitDefNames['gear_monitor'].id ] = true,
  [ UnitDefNames['gear_phantom'].id ] = true,

  [ UnitDefNames['claw_advanced_radar_tower'].id ] = true,
  [ UnitDefNames['claw_radar_tower'].id ] = true,
  [ UnitDefNames['claw_radar_jamming_tower'].id ] = true,
  [ UnitDefNames['claw_seer'].id ] = true,
  [ UnitDefNames['claw_jammer'].id ] = true,
  [ UnitDefNames['claw_revealer'].id ] = true,
  [ UnitDefNames['claw_shade'].id ] = true,
  [ UnitDefNames['claw_advanced_sonar_station'].id ] = true,
  [ UnitDefNames['claw_sonar_station'].id ] = true,
  [ UnitDefNames['claw_explorer'].id ] = true,
  [ UnitDefNames['claw_negator'].id ] = true,
  [ UnitDefNames['claw_haze'].id ] = true,

  [ UnitDefNames['sphere_adv_radar_tower'].id ] = true,
  [ UnitDefNames['sphere_radar_tower'].id ] = true,
  [ UnitDefNames['sphere_radar_jamming_tower'].id ] = true,
  [ UnitDefNames['sphere_scanner'].id ] = true,
  [ UnitDefNames['sphere_concealer'].id ] = true,
  [ UnitDefNames['sphere_sensor'].id ] = true,
  [ UnitDefNames['sphere_rain'].id ] = true,
  [ UnitDefNames['sphere_advanced_sonar_station'].id ] = true,
  [ UnitDefNames['sphere_sonar_station'].id ] = true,
  [ UnitDefNames['sphere_echo'].id ] = true,
  [ UnitDefNames['sphere_orb'].id ] = true,
  [ UnitDefNames['sphere_mist'].id ] = true
}

local metalDefs = {
  [ UnitDefNames['aven_exploiter'].id ] = true,
  [ UnitDefNames['gear_exploiter'].id ] = true,
  [ UnitDefNames['claw_exploiter'].id ] = true,
  [ UnitDefNames['sphere_exploiter'].id ] = true,
  [ UnitDefNames['aven_moho_mine'].id ] = true,
  [ UnitDefNames['gear_moho_mine'].id ] = true,
  [ UnitDefNames['claw_moho_mine'].id ] = true,
  [ UnitDefNames['sphere_moho_mine'].id ] = true
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
  for _,unitID in ipairs(Spring.GetAllUnits()) do
    local unitDefID = Spring.GetUnitDefID(unitID)
		AddUnit(unitID, unitDefID)
	end
end


function AddUnit(unitID, unitDefID) 
  if (radarDefs[unitDefID] or metalDefs[unitDefID]) then
		units[unitID] = { defID = unitDefID, changeStateTime = GetGameSeconds() } 
  end
end

function RemoveUnit(unitID) 
  units[unitID] = nil
  disabledUnits[unitID] = nil
end


function gadget:UnitCreated(unitID, unitDefID)
	AddUnit(unitID, unitDefID)
end

function gadget:UnitTaken(unitID, unitDefID)
	AddUnit(unitID, unitDefID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeamID)
  if (newTeamID==nil) then RemoveUnit(unitID) end
end


function gadget:UnitDestroyed(unitID)
  RemoveUnit(unitID)
end



function gadget:GameFrame(n)
	if (((n+8) % 64) < 0.1) then
		local teamEnergy = {}
		local gameSeconds = GetGameSeconds()
		local temp = Spring.GetTeamList() 
		-- update energy available for each team
		for _,teamID in ipairs(temp) do 
			local eCur, eMax, ePull, eInc, _, _, _, eRec = Spring.GetTeamResources(teamID, "energy")
			teamEnergy[teamID] = eCur - ePull + eInc
		end 

		-- check each unit
		for unitID,data in pairs(units) do
			if (gameSeconds - data.changeStateTime > changeStateDelay) then
				local disabledUnitEnergyUse = disabledUnits[unitID] 
				local unitTeamID = GetUnitTeam(unitID)
				
				-- if unit has been disabled, check if it can be activated
				if (disabledUnitEnergyUse~=nil) then -- we have disabled unit
					if (disabledUnitEnergyUse < teamEnergy[unitTeamID] and teamEnergy[unitTeamID] > LOW_ENERGY_ENABLE_THRESHOLD) then  -- we still have enough energy to reenable unit
						disabledUnits[unitID]=nil
						GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, { })
						data.changeStateTime = gameSeconds
						teamEnergy[unitTeamID] = teamEnergy[unitTeamID] - disabledUnitEnergyUse
					end
				else -- we have non-disabled unit
					local _, _, _, energyUse =	GetUnitResources(unitID)
					local energyUpkeep = UnitDefs[data.defID].energyUpkeep
					if (energyUse == nil or energyUpkeep == nil) then -- unit probably doesn't exist, get rid of it
						RemoveUnit(unitID)
					elseif (energyUse > 0 and teamEnergy[unitTeamID] < LOW_ENERGY_DISABLE_THRESHOLD) then -- there is not enough energy to keep unit running (its energy use auto dropped to 0), we will disable it 
						if (GetUnitStates(unitID).active) then  -- only disable "active" unit
							GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, { })
							data.changeStateTime = gameSeconds
							disabledUnits[unitID] = energyUpkeep
						end				
					end
				end
			end
		end
	end
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if (cmdID == CMD.ONOFF and disabledUnits[unitID]~=nil) then
    return false
  else 
		return true
	end
end
 
  
--------------------------------------------------------------------------------
--  END SYNCED
--------------------------------------------------------------------------------
end
