function widget:GetInfo()
	return {
		name	= "Settings",
		desc	= "Overrides some Spring settings: grass, camera, maxParticles, clock, fps, speed indicator",
		author	= "raaar",
		date	= "2015-07-20",
		license	= "PD",
		layer	= 5,
		enabled	= true
	}
end

function widget:Initialize()
	-- disable grass
	Spring.SetConfigInt("GrassDetail",0)
	
	-- set camera to "ta" mode
	local camState = Spring.GetCameraState()
	camState.name = 'ta'
	camState.mode = Spring.GetCameraNames()['ta']
	Spring.SetCameraState(camState, 0)
	
	-- set max particles to 20000
	Spring.SetConfigInt("MaxParticles",20000)

	-- set max nano particles to 10000
	Spring.SetConfigInt("MaxNanoParticles",10000)
	
	-- set scrollwheel speed to -25 if >= 0
	local swSpeed = Spring.GetConfigInt("ScrollWheelSpeed")
	if (swSpeed and swSpeed >=0) then
		Spring.SetConfigInt("ScrollWheelSpeed",-25)
	end
	
	-- disable clock and fps (widget is used instead)
	Spring.SendCommands("clock 0")
	Spring.SendCommands("fps 0")
	
	-- disable game speed indicator
	Spring.SendCommands("speed 0")
	
	-- enforce unit icon distance
	Spring.SendCommands("disticon 120")

	-- enforce high terrain detail
	Spring.SendCommands("grounddetail 140")	

	-- enforce hardware cursor	
	Spring.SendCommands("HardwareCursor 1")
	
	-- enforce ground decals
	Spring.SendCommands("grounddecals 1")
end

