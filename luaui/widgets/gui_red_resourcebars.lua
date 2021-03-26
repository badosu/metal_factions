function widget:GetInfo()
	return {
	name      = "Red Resource Bars",
	desc      = "Requires Red UI Framework",
	author    = "Regret, modified by raaar",
	date      = "29 may 2015",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true,
	handler   = true,
	}
end

--  modified by raaar, feb 2016 :
--   . added labels and modified layout and sizes a bit
--   . use red ui framework 8.1

-- local barTexture = LUAUI_DIRNAME.."Images/resbar.dds"

local NeededFrameworkVersion = 8.1
local CanvasX,CanvasY = 1280,734 --resolution in which the widget was made (for 1:1 size)
--1272,734 == 1280,768 windowed

local Config = {
	metal = {
		px = 370,py = 0, --default start position
		sx = 235,sy = 35, --background size
		
		barsy = 6, --width of the actual bar
		fontsize = 12,
		maxFontsize = 24,
		margin = 5, --distance from background border
		
		padding = 4, -- for border effect
		color2 = {1,1,1,0.022}, -- for border effect
		
		expensefadetime = 0.25, --fade effect time, in seconds
		
		cbackground = {0,0,0,0.5}, --color {r,g,b,alpha}
		cborder = {0,0,0,0.88},
		cbarbackground = {0,0,0,1},
		cbar = {1,1,1,1},
		cindicator = {1,0,0,0.8},
		
		cincome = {0,1,0,1},
		cpull = {1,0,0,1},
		cexpense = {1,0,0,1},
		ccurrent = {1,1,1,1},
		cstorage = {1,1,1,1},
		clabel = {0.7,0.7,0.7,1},
		name = "METAL",
		
		dragbutton = {2}, --middle mouse button
		tooltip = {
			background ="\255\255\255\1Leftclick\255\255\255\255 on the bar to set team share.",
			income = "Your metal income per second.",
			pull = "Your metal expense per second.",
			expense = "Your metal expense, same as pull if not shown.",
			storage = "Your maximum metal storage.",
			current = "Your current metal storage.",
		},
	},
	
	energy = {
		px = 636,py = 0,
		sx = 235,sy = 35, --background size
		
		barsy = 6, --width of the actual bar
		fontsize = 12,
		maxFontsize = 24,
		margin = 5,
		
		padding = 4, -- for border effect
		color2 = {1,1,1,0.022}, -- for border effect
		
		expensefadetime = 0.25,
		
		cbackground = {0,0,0,0.5},
		cborder = {0,0,0,0.88},
		cbarbackground = {0,0,0,1},
		cbar = {1,1,0,1},
		cindicator = {1,0,0,0.8},
		
		cincome = {0,1,0,1},
		cpull = {1,0,0,1},
		cexpense = {1,0,0,1},
		ccurrent = {1,1,1,1},
		cstorage = {1,1,1,1},
		clabel = {1,1,0,1},
		name = "ENERGY",
		
		dragbutton = {2}, --middle mouse button
		tooltip = {
			background ="\255\255\255\1Left Click\255\255\255\255 on the bar to set team share.",
			income = "Your energy income per second.",
			pull = "Your energy expense per second.",
			expense = "Your energy expense, same as pull if not shown.",
			storage = "Your maximum energy storage.",
			current = "Your current energy storage.",
		},
	},
}

local sGetMyTeamID = Spring.GetMyTeamID
local sGetTeamResources = Spring.GetTeamResources
local sSetShareLevel = Spring.SetShareLevel
local sformat = string.format

local function IncludeRedUIFrameworkFunctions()
	New = WG.Red.New(widget)
	Copy = WG.Red.Copytable
	SetTooltip = WG.Red.SetTooltip
	GetSetTooltip = WG.Red.GetSetTooltip
	Screen = WG.Red.Screen
	GetWidgetObjects = WG.Red.GetWidgetObjects
end

local function RedUIchecks()
	local color = "\255\255\255\1"
	local passed = true
	if (type(WG.Red)~="table") then
		Spring.Echo(color..widget:GetInfo().name.." requires Red UI Framework.")
		passed = false
	elseif (type(WG.Red.Screen)~="table") then
		Spring.Echo(color..widget:GetInfo().name..">> strange error.")
		passed = false
	elseif (WG.Red.Version < NeededFrameworkVersion) then
		Spring.Echo(color..widget:GetInfo().name..">> update your Red UI Framework.")
		passed = false
	end
	if (not passed) then
		widgetHandler:ToggleWidget(widget:GetInfo().name)
		return false
	end
	IncludeRedUIFrameworkFunctions()
	return true
end

local function AutoResizeObjects() --autoresize v2
	if (LastAutoResizeX==nil) then
		LastAutoResizeX = CanvasX
		LastAutoResizeY = CanvasY
	end
	local lx,ly = LastAutoResizeX,LastAutoResizeY
	local vsx,vsy = Screen.vsx,Screen.vsy
	if ((lx ~= vsx) or (ly ~= vsy)) then
		local objects = GetWidgetObjects(widget)
		local scale = (vsy/ly + vsx/lx) * 0.5 
		local skippedobjects = {}
		for i=1,#objects do
			local o = objects[i]
			local adjust = 0
			if ((o.movableSlaves) and (#o.movableSlaves > 0)) then
				adjust = (o.px*scale+o.sx*scale)-vsx
				if (((o.px+o.sx)-lx) == 0) then
					o._moveduetoresize = true
				end
			end
			if (o.px) then o.px = o.px * scale end
			if (o.py) then o.py = o.py * scale end
			if (o.sx) then o.sx = o.sx * scale end
			if (o.sy) then o.sy = o.sy * scale end
			if (o.fontsize) then o.fontsize = o.fontsize * scale end
			if (adjust > 0) then
				o._moveduetoresize = true
				o.px = o.px - adjust
				for j=1,#o.movableSlaves do
					local s = o.movableSlaves[j]
					s.px = s.px - adjust/scale
				end
			elseif ((adjust < 0) and o._moveduetoresize) then
				o._moveduetoresize = nil
				o.px = o.px - adjust
				for j=1,#o.movableSlaves do
					local s = o.movableSlaves[j]
					s.px = s.px - adjust/scale
				end
			end
		end
		LastAutoResizeX,LastAutoResizeY = vsx,vsy
	end
end

local function short(n,f)
	if (f == nil) then
		f = 0
	end
	if (n > 9999999) then
		return sformat("%."..f.."fm",n/1000000)
	elseif (n > 9999) then
		return sformat("%."..f.."fk",n/1000)
	else
		return sformat("%."..f.."f",n)
	end
end

local function createbar(r)
	local background2 = {"rectangle",
		px=r.px+r.padding,py=r.py+r.padding,
		sx=r.sx-r.padding-r.padding,sy=r.sy-r.padding-r.padding,
		color=r.color2,
	}
	local background = {"rectangle",
		px=r.px,py=r.py,
		sx=r.sx,sy=r.sy,
		color=r.cbackground,
		border=r.cborder,
		movable=r.dragbutton,
		obeyScreenEdge = true,
		
		padding=r.padding,
		
		--overrideCursor = true,
		overrideClick = {1},
		onUpdate=function(self)
			background2.px = self.px + self.padding
			background2.py = self.py + self.padding
			background2.sx = self.sx - self.padding - self.padding
			background2.sy = self.sy - self.padding - self.padding
		end,
	}
	New(background)
	New(background2)
	
	local number = {"text",
		px=0,py=background.py+r.margin,fontsize=r.fontsize,maxFontsize=20,
		caption=r.name.." +99999.9m",
		options="n", --disable colorcodes
	}
	
	local income = New(number)
	income.color = r.cincome
	
	local barbackground = {"rectangle",
		px=background.px+income.getWidth()-r.margin,py=income.py,
		sx=background.sx-income.getWidth(),sy=r.barsy,
		color=r.cbarbackground,
		--texture = barTexture,
		textureColor = {0.15,0.15,0.15,1},
	}

	local barborder = Copy(barbackground)
	barborder.color = nil
	barborder.border = r.cborder
	barborder.texture = nil
	barborder.textureColor = nil
	
	local bar = Copy(barbackground)
	bar.color = r.cbar
	--bar.texture = barTexture
	bar.textureColor = r.cbar
	
	local shareindicator = Copy(barbackground)
	shareindicator.color = r.cindicator
	shareindicator.py = shareindicator.py -2
	shareindicator.sx = barbackground.sy
	shareindicator.sy = shareindicator.sy +4
	shareindicator.border = r.cborder
	--shareindicator.texture = barTexture
	shareindicator.textureColor = r.cindicator

	New(barbackground)
	New(bar)
	New(barborder)
	New(shareindicator)
	
	bar.overrideCursor = true
	
	local pull = New(number)
	pull.color = r.cpull
	--pull.py = pull.py+pull.fontsize
	pull.py = barbackground.py+barbackground.sy+r.margin
	if ((barbackground.sy+r.margin)<r.fontsize) then
		pull.py = barbackground.py+r.fontsize
	end
	
	local expense = New(pull)
	expense.color = r.cexpense
	expense.px = barbackground.px
	
	local current = New(pull)
	current.color = r.ccurrent
	
	local storage = New(pull)
	storage.color = r.cstorage
	
		-- label
	local label = New(number)
	label.color = r.clabel
	label.py = (income.py + pull.py) / 2
	
	expense.effects = {
		fadein_at_activation = r.expensefadetime,
		fadeout_at_deactivation = r.expensefadetime,
	}
	
	background.movableSlaves = {
		barbackground,barborder,bar,shareindicator,
		income,pull,expense,current,storage,label
	}
	
	-- smaller fontsize for fontsize of income and pull
	income.fontsize = r.fontsize*0.93
	pull.fontsize = r.fontsize*0.93
	storage.fontsize = r.fontsize*0.88
	
	--tooltip
	background.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.background) end
	income.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.income) end
	pull.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.pull) end
	expense.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.expense) end
	storage.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.storage) end
	current.mouseOver = function(mx,my,self) SetTooltip(r.tooltip.current) end
	

	return {
		["background"] = background,
		["background2"] = background2,
		["barbackground"] = barbackground,
		["bar"] = bar,
		["barborder"] = barborder,
		["shareindicator"] = shareindicator,
		["income"] = income,
		["pull"] = pull,
		["expense"] = expense,
		["current"] = current,
		["storage"] = storage,
		["label"] = label,
		
		margin = r.margin
	}
end

local function updatebar(b,res)
	local r = {sGetTeamResources(sGetMyTeamID(),res)} -- 1 = cur 2 = cap 3 = pull 4 = income 5 = expense 6 = share
	local barbackpx = b.barbackground.px
	local barbacksx = b.barbackground.sx
	
	b.bar.sx = r[1]/r[2]*barbacksx
	if (b.bar.sx > barbacksx) then --happens on gamestart and storage destruction
		b.bar.sx = barbacksx
	end
	
	b.income.caption = "+ "..short(r[4],(r[4] < 10 and 1 or 0))
	b.pull.caption = "- "..short(r[5],(r[5] < 10 and 1 or 0))  --- was r[3], but it considers weapon E drain twice for some reason
	b.current.caption = short(r[1])
	b.storage.caption = short(r[2])
	b.label.caption = string.upper(res)
	
	--align numbers
	b.income.px = barbackpx - b.income.getWidth() -b.margin*2.2 
	b.pull.px = barbackpx - b.pull.getWidth() -b.margin*2.2
	b.current.px = barbackpx + barbacksx/2 - b.current.getWidth()/2
	b.storage.px = barbackpx + barbacksx - b.storage.getWidth() 
	b.label.px = barbackpx - b.label.getWidth() -b.margin*4.4 - math.max(b.income.getWidth(),b.pull.getWidth())
	
	-- TODO check this
	-- disable expense to make bars less confusing 
	-- it also showed double the amounts it should, which was weird
	if (false and r[3]~=r[5]) then
		b.expense.active = nil --activate
		b.expense.caption = "  - "..short(r[5],(r[5] < 10 and 1 or 0))
	else
		b.expense.active = false
	end
	
	b.shareindicator.px = barbackpx+r[6]*barbacksx-b.shareindicator.sx/2
end

function widget:Initialize()
	PassedStartupCheck = RedUIchecks()
	if (not PassedStartupCheck) then return end
	
	metal = createbar(Config.metal)
	energy = createbar(Config.energy)
	
	metal.barbackground.mouseHeld = {
		{1,function(mx,my,self)
			sSetShareLevel("metal",(mx-self.px)/self.sx)
			updatebar(metal,"metal")
		end},
	}
	energy.barbackground.mouseHeld = {
		{1,function(mx,my,self)
			sSetShareLevel("energy",(mx-self.px)/self.sx)
			updatebar(energy,"energy")
		end},
	}
	
	Spring.SendCommands("resbar 0")
	AutoResizeObjects()
end

function widget:Shutdown()
	Spring.SendCommands("resbar 1")
end

local gameFrame = 0
local lastFrame = -1
function widget:GameFrame(n)
	gameFrame = n
end

function widget:Update()
	AutoResizeObjects()
	if (gameFrame ~= lastFrame) then
		updatebar(energy,"energy")
		updatebar(metal,"metal")
		lastFrame = gameFrame
	end
end

--save/load stuff
--currently only position
--[[
function widget:GetConfigData() --save config
	if (PassedStartupCheck) then
		local vsy = Screen.vsy
		local unscale = CanvasY/vsy --needed due to autoresize, stores unresized variables
		Config.metal.px = metal.background.px * unscale
		Config.metal.py = metal.background.py * unscale
		Config.energy.px = energy.background.px * unscale
		Config.energy.py = energy.background.py * unscale
		return {Config=Config}
	end
	
end
function widget:SetConfigData(data) --load config
	if (data.Config ~= nil) then
		Config.metal.px = data.Config.metal.px
		Config.metal.py = data.Config.metal.py
		Config.energy.px = data.Config.energy.px
		Config.energy.py = data.Config.energy.py
	end
end
--]]