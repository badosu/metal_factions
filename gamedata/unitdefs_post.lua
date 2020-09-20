--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local modOptions
if (Spring.GetModOptions) then
  modOptions = Spring.GetModOptions()
end


local function tobool(val)
  local t = type(val)
  if (t == 'nil') then
    return false
  elseif (t == 'boolean') then
    return val
  elseif (t == 'number') then
    return (val ~= 0)
  elseif (t == 'string') then
    return ((val ~= '0') and (val ~= 'false'))
  end
  return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Metal Bonus
--

if (modOptions and modOptions.metalmult and tonumber(modOptions.metalmult) ~= nil) then
  for name in pairs(UnitDefs) do
    local em = UnitDefs[name].extractsmetal
    if (em) then
      UnitDefs[name].extractsmetal = em * modOptions.metalmult
    end
  end
end
--------------------------------------------------------------------------------
-- Hitpoint Bonus
--

if (modOptions and modOptions.hitmult and tonumber(modOptions.hitmult) ~= nil) then
  for name in pairs(UnitDefs) do
    local em = UnitDefs[name].maxdamage
    if (em) then
      UnitDefs[name].maxdamage = em * modOptions.hitmult 
    end
  end
end
--------------------------------------------------------------------------------
-- Velocity Bonus
--

if (modOptions and modOptions.velocitymult and tonumber(modOptions.velocitymult) ~= nil) then
  for name in pairs(UnitDefs) do
    local em = UnitDefs[name].maxvelocity
    if (em) then
      --UnitDefs[name].maxvelocity = em * modOptions.velocitymult
    end
  end
end
--------------------------------------------------------------------------------
-- Build Bonus
--

if (modOptions and modOptions.workermult and tonumber(modOptions.workermult) ~= nil) then
  for name in pairs(UnitDefs) do
    local em = UnitDefs[name].workertime
    if (em) then
      UnitDefs[name].workertime = em * modOptions.workermult 
    end
  end
end
--------------------------------------------------------------------------------
-- Energy Bonus
--

if (modOptions and modOptions.energymult and tonumber(modOptions.energymult) ~= nil) then
  for name in pairs(UnitDefs) do
    local em = UnitDefs[name].energymake
    if (em) then
      UnitDefs[name].energymake = em * modOptions.energymult
    end
  end
end

local function disableunits(unitlist)
  for name, ud in pairs(UnitDefs) do
    if (ud.buildoptions) then
      for _, toremovename in ipairs(unitlist) do
        for index, unitname in pairs(ud.buildoptions) do
          if (unitname == toremovename) then
            table.remove(ud.buildoptions, index)
          end
        end
      end
    end
  end
end

local reducedDecalSizeUnits = {
	aven_wind_generator = true,
	gear_wind_generator = true,
	claw_wind_generator = true
}


local reducedDecalDurationUnits = {
	aven_metal_extractor = true,
	gear_metal_extractor = true,
	claw_metal_extractor = true,
	sphere_metal_extractor = true,
	aven_exploiter = true,
	gear_exploiter = true,
	claw_exploiter = true,
	sphere_exploiter = true,
	aven_moho_mine = true,
	gear_moho_mine = true,
	claw_moho_mine = true,
	sphere_moho_mine = true
}


local noDecalUnits = {
	gear_mine = true,
	gear_incendiary_mine = true,
	aven_premium_nuclear_rocket = true,
	aven_nuclear_rocket = true,
	aven_dc_rocket = true,
	aven_lightning_rocket = true,
	gear_premium_nuclear_rocket = true,
	gear_nuclear_rocket = true,
	gear_dc_rocket = true,
	gear_pyroclasm_rocket = true,
	claw_premium_nuclear_rocket = true,
	claw_nuclear_rocket = true,
	claw_dc_rocket = true,
	claw_impaler_rocket = true,
	sphere_premium_nuclear_rocket = true,
	sphere_nuclear_rocket = true,
	sphere_dc_rocket = true,
	sphere_meteorite_rocket = true
}

-- unitdef tweaking
if (true) then
	for name,unitDef in pairs(UnitDefs) do

		local mv = unitDef.maxvelocity
		local ac = unitDef.acceleration
		local sd = unitDef.sightdistance

		if (sd) then

			-- airlos = los, and increase los 20%
			sd = sd * 1.2
			unitDef.losemitheight = 80
			unitDef.radaremitheight = 120
			unitDef.sightdistance = sd
			unitDef.airsightdistance = sd

			-- level ground beneath structures
			unitDef.levelground = true

			-- disable radar inaccuracy
			unitDef.istargetingupgrade = true
		end

		-- increase slope tolerance for buildings
		if (unitDef.builder and tonumber(unitDef.builder) == 1 and unitDef.footprintx and tonumber(unitDef.footprintx) > 4) then
			-- probably a factory, be more strict about it to avoid some units getting stuck
			unitDef.maxslope = 16
			--Spring.Echo(unitDef.name.." FACTORY")
		else
			unitDef.maxslope = 30
		end
	
		-- standardize idleautoheal and idletime
		-- set to 0, done through gadget now
		unitDef.idletime = 0
		unitDef.idleautoheal = 0
		
		-- if unit generates or drains less than 3E/s, ignore it
		if (unitDef.energymake and math.abs(tonumber(unitDef.energymake)) < 3) then
			unitDef.energymake = 0
		end
		if (unitDef.energymake and math.abs(tonumber(unitDef.energyuse)) < 3) then
			unitDef.energyuse = 0
		end
		
		if (mv and tonumber(mv) > 0) then
			mv = tonumber(mv)
			-- disable transporting enemy units
			unitDef.transportbyenemy = 0
			
			-- disable unit tracks
			unitDef.leavetracks = 0
  
			-- disable speed penalty when turning
			unitDef.turninplaceanglelimit = 90.0
			unitDef.turninplacespeedlimit = mv / 1.5

			-- make sure low acceleration units are able to beat drag
			local minAcceleration = mv / 80
			if ( tonumber(ac) < minAcceleration ) then
				unitDef.acceleration = minAcceleration
			end
			
			-- remove excessive brakerate from aircraft
			local canFly = unitDef.canfly
			local br = tonumber(unitDef.brakerate)
			if (canFly) then
				if (br > 0.5) then
					unitDef.brakerate = br / 5
				end
			end
		
			-- make heavy units push resistant
			-- TODO disabled because units would get stuck in each other
			 --if tonumber(unitDef.buildcostmetal) > 2000 or unitDef.mass > 1500 then
			 	--Spring.Echo(name.." is push resistant")
			 	--unitDef.pushresistant = 1
			 --end
		else
			local factionBuilding = false
			
			if string.sub(name,1,5) == "aven_" then
				unitDef.buildinggrounddecaltype = "building_aven.dds"
				factionBuilding = true
			elseif string.sub(name,1,5) == "gear_" then  
				unitDef.buildinggrounddecaltype = "building_gear.dds"
				factionBuilding = true
			elseif string.sub(name,1,5) == "claw_" then
				unitDef.buildinggrounddecaltype = "building_claw.dds"
				factionBuilding = true
			elseif string.sub(name,1,7) == "sphere_" then
				unitDef.buildinggrounddecaltype = "building_sphere.dds"
				factionBuilding = true
			end
			local fpMod = 1.5
			if (factionBuilding == true and (not noDecalUnits[name]) and (not (unitDef.floater or unitDef.waterline) or (not unitDef.minwaterdepth or tonumber(unitDef.minwaterdepth) < 0) )) then
				unitDef.usebuildinggrounddecal = true
				if (reducedDecalSizeUnits[name] ) then
					fpMod = 0.85
				end
				unitDef.buildinggrounddecalsizex = unitDef.footprintx * fpMod
				unitDef.buildinggrounddecalsizey = unitDef.footprintz * fpMod
				
				if (reducedDecalDurationUnits[name]) then
					unitDef.buildinggrounddecaldecayspeed = 0.5
				else
					unitDef.buildinggrounddecaldecayspeed = 0.01
				end
			end
		end
	end
end
