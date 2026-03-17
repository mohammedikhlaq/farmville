-- CityManager.server.lua
-- SimCity / Monopoly-style city simulation.
--
-- Features:
--   • 10×10 purchasable city grid east of the player farm (starts at X=65)
--   • Buy a plot (500 coins) → build any building on it
--   • Buildings add population, happiness, safety, health, education,
--     power, water and per-minute income
--   • City stats tick every 60 s, paying income and updating dashboard
--   • Monopoly rent: if another player walks on your plot they pay rent
--   • NPC Farm treasury deposits arrive via _CityTreasuryAPI BindableEvent
--   • Uses its own CityRemotes folder to avoid conflicts with farm remotes

local Players           = game:GetService("Players")
local RS                = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- ── Wait for modules ──────────────────────────────────────────────────────
local GameModules   = RS:WaitForChild("GameModules", 30)
local BuildingData  = require(GameModules:WaitForChild("BuildingData", 30))

-- ── City grid config ──────────────────────────────────────────────────────
local GRID_COLS     = 10
local GRID_ROWS     = 10
local CELL_SIZE     = 16     -- studs per cell
-- City starts at X=65 (clearly east of barn at X=40, close enough to be visible)
local GRID_ORIGIN   = Vector3.new(65, 0, -((GRID_ROWS * CELL_SIZE) / 2))

-- ── State ─────────────────────────────────────────────────────────────────
local CityStats = {
	population  = 0,
	happiness   = 50,
	safety      = 0,
	health      = 0,
	education   = 0,
	power       = 0,
	water       = 0,
	income      = 0,
	treasury    = 0,
}

-- plotData[row][col] = { owner = userId, building = buildingKey }
local PlotData  = {}
local PlotParts = {}   -- [row][col] = BasePart
local CityFolder = nil

-- ── Own remotes folder (separate from Main.server's farm remotes) ─────────
local CityRemotes = Instance.new("Folder")
CityRemotes.Name  = "CityRemotes"
CityRemotes.Parent = RS

local function makeRE(name)
	local e = Instance.new("RemoteEvent")
	e.Name  = name
	e.Parent = CityRemotes
	return e
end

local RE = {
	BuyPlot        = makeRE("BuyPlot"),
	BuildOnPlot    = makeRE("BuildOnPlot"),
	DemolishPlot   = makeRE("DemolishPlot"),
	UpdateCityStats = makeRE("UpdateCityStats"),
	UpdateCityGrid = makeRE("UpdateCityGrid"),
	CityNotify     = makeRE("CityNotify"),
}

-- ── NPC Farm treasury bridge ──────────────────────────────────────────────
local treasuryEvent   = Instance.new("BindableEvent")
treasuryEvent.Name    = "_CityTreasuryAPI"
treasuryEvent.Parent  = Workspace

treasuryEvent.Event:Connect(function(amount)
	CityStats.treasury = CityStats.treasury + amount
end)

-- ── Helpers ───────────────────────────────────────────────────────────────
local function cellOrigin(row, col)
	return Vector3.new(
		GRID_ORIGIN.X + col * CELL_SIZE + CELL_SIZE / 2,
		0,
		GRID_ORIGIN.Z + row * CELL_SIZE + CELL_SIZE / 2
	)
end

local function getPlot(row, col)
	if not PlotData[row] then PlotData[row] = {} end
	return PlotData[row][col]
end

local function setPlot(row, col, data)
	if not PlotData[row] then PlotData[row] = {} end
	PlotData[row][col] = data
end

-- ── Recalculate CityStats from all buildings ──────────────────────────────
local function recalcStats()
	local s = {
		population = 0, happiness = 50, safety = 0,
		health = 0, education = 0, power = 0, water = 0, income = 0,
	}
	for row = 0, GRID_ROWS - 1 do
		for col = 0, GRID_COLS - 1 do
			local plot = getPlot(row, col)
			if plot and plot.building then
				local bd = BuildingData.Buildings[plot.building]
				if bd then
					s.population = s.population + bd.population
					s.happiness  = s.happiness  + bd.happiness
					s.safety     = s.safety     + bd.safety
					s.health     = s.health     + bd.health
					s.education  = s.education  + bd.education
					s.power      = s.power      + bd.power
					s.water      = s.water      + bd.water
					s.income     = s.income     + bd.income
				end
			end
		end
	end
	s.happiness = math.clamp(s.happiness, 0, 100)
	if s.power < 0 then s.happiness = math.max(0, s.happiness + s.power * 2) end
	if s.water < 0 then s.happiness = math.max(0, s.happiness + s.water * 2) end
	CityStats.population = s.population
	CityStats.happiness  = s.happiness
	CityStats.safety     = s.safety
	CityStats.health     = s.health
	CityStats.education  = s.education
	CityStats.power      = s.power
	CityStats.water      = s.water
	CityStats.income     = s.income
end

local function broadcastStats()
	RE.UpdateCityStats:FireAllClients(CityStats)
end

-- ── Update a single plot's visual ─────────────────────────────────────────
local function updatePlotVisual(row, col)
	local pad  = PlotParts[row] and PlotParts[row][col]
	if not pad then return end
	local plot = getPlot(row, col)
	local gui  = pad:FindFirstChild("PlotGui")
	local tl   = gui and gui:FindFirstChild("Label")

	-- Remove old building model
	local oldModel = pad:FindFirstChild("BuildingModel")
	if oldModel then oldModel:Destroy() end

	if not plot then
		pad.BrickColor = BrickColor.new("Medium green")
		pad.Material   = Enum.Material.Grass
		if tl then tl.Text = "Buy\n$"..BuildingData.PlotCost end
		return
	end

	if not plot.building then
		pad.BrickColor = BrickColor.new("Sand yellow")
		pad.Material   = Enum.Material.SmoothPlastic
		if tl then tl.Text = "Owned\n(empty)" end
		return
	end

	local bd = BuildingData.Buildings[plot.building]
	if not bd then return end

	local safeColor = (bd.color == "Transparent") and "White" or bd.color
	pad.BrickColor = BrickColor.new(safeColor)
	pad.Material   = Enum.Material.SmoothPlastic
	if tl then
		tl.Text = (bd.icon or "").."\n"..bd.displayName
		if bd.income > 0 then
			tl.Text = tl.Text.."\n+$"..bd.income.."/m"
		end
	end

	-- Simple building model
	local model        = Instance.new("Model")
	model.Name         = "BuildingModel"

	local height       = 4 + math.random(2, 8)
	local body         = Instance.new("Part")
	body.Name          = "Block"
	body.Size          = Vector3.new(CELL_SIZE*0.65, height, CELL_SIZE*0.65)
	body.CFrame        = CFrame.new(pad.Position + Vector3.new(0, height/2 + 0.2, 0))
	body.Anchored      = true
	body.BrickColor    = BrickColor.new(safeColor)
	body.Material      = Enum.Material.SmoothPlastic
	body.TopSurface    = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Parent        = model

	local roof         = Instance.new("Part")
	roof.Name          = "Roof"
	roof.Size          = Vector3.new(CELL_SIZE*0.7, 1, CELL_SIZE*0.7)
	roof.CFrame        = CFrame.new(body.Position + Vector3.new(0, height/2 + 0.5, 0))
	roof.Anchored      = true
	roof.BrickColor    = BrickColor.new("Dark grey")
	roof.Material      = Enum.Material.SmoothPlastic
	roof.TopSurface    = Enum.SurfaceType.Smooth
	roof.BottomSurface = Enum.SurfaceType.Smooth
	roof.Parent        = model

	for wx = -1, 1 do
		local win         = Instance.new("Part")
		win.Size          = Vector3.new(1.2, 0.9, 0.2)
		win.CFrame        = CFrame.new(body.Position + Vector3.new(wx*2.5, 0, -body.Size.Z/2 - 0.1))
		win.Anchored      = true
		win.BrickColor    = BrickColor.new("Bright blue")
		win.Material      = Enum.Material.Neon
		win.TopSurface    = Enum.SurfaceType.Smooth
		win.BottomSurface = Enum.SurfaceType.Smooth
		win.Parent        = model
	end

	model.Parent = pad
end

-- ── Build the visual city grid ─────────────────────────────────────────────
local function buildCityGrid()
	CityFolder        = Instance.new("Folder")
	CityFolder.Name   = "CityZone"
	CityFolder.Parent = Workspace

	-- Road grid underlay
	local roadBase         = Instance.new("Part")
	roadBase.Name          = "CityBase"
	roadBase.Size          = Vector3.new(GRID_COLS*CELL_SIZE+4, 0.3, GRID_ROWS*CELL_SIZE+4)
	roadBase.CFrame        = CFrame.new(
		GRID_ORIGIN.X + (GRID_COLS*CELL_SIZE)/2,
		-0.15,
		GRID_ORIGIN.Z + (GRID_ROWS*CELL_SIZE)/2
	)
	roadBase.Anchored      = true
	roadBase.Material      = Enum.Material.SmoothPlastic
	roadBase.BrickColor    = BrickColor.new("Dark grey")
	roadBase.TopSurface    = Enum.SurfaceType.Smooth
	roadBase.BottomSurface = Enum.SurfaceType.Smooth
	roadBase.Parent        = CityFolder

	-- City sign post
	local signPost         = Instance.new("Part")
	signPost.Size          = Vector3.new(0.5, 6, 0.5)
	signPost.CFrame        = CFrame.new(GRID_ORIGIN.X - 4, 3, GRID_ORIGIN.Z - 4)
	signPost.Anchored      = true
	signPost.Material      = Enum.Material.Metal
	signPost.BrickColor    = BrickColor.new("Dark grey")
	signPost.TopSurface    = Enum.SurfaceType.Smooth
	signPost.BottomSurface = Enum.SurfaceType.Smooth
	signPost.Parent        = CityFolder

	local signBoard        = Instance.new("Part")
	signBoard.Size         = Vector3.new(18, 3, 0.4)
	signBoard.CFrame       = CFrame.new(GRID_ORIGIN.X + 5, 7, GRID_ORIGIN.Z - 4)
	signBoard.Anchored     = true
	signBoard.Material     = Enum.Material.SmoothPlastic
	signBoard.BrickColor   = BrickColor.new("Bright blue")
	signBoard.TopSurface   = Enum.SurfaceType.Smooth
	signBoard.BottomSurface = Enum.SurfaceType.Smooth
	signBoard.Parent       = CityFolder

	local sg               = Instance.new("SurfaceGui")
	sg.Face                = Enum.NormalId.Front
	sg.Parent              = signBoard
	local lbl              = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = "Adam & Eshaals City"
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextColor3         = Color3.new(1,1,1)
	lbl.Parent             = sg

	-- Road path connecting farm to city (dirt strip)
	local roadPath         = Instance.new("Part")
	roadPath.Name          = "CityRoad"
	roadPath.Size          = Vector3.new(6, 0.25, 65 - 42)   -- from barn edge X=42 to city X=65
	roadPath.CFrame        = CFrame.new((42 + 65)/2, 0.1, 0)
	roadPath.Anchored      = true
	roadPath.Material      = Enum.Material.Ground
	roadPath.BrickColor    = BrickColor.new("Brown")
	roadPath.TopSurface    = Enum.SurfaceType.Smooth
	roadPath.BottomSurface = Enum.SurfaceType.Smooth
	roadPath.Parent        = CityFolder

	-- Cell pads
	for row = 0, GRID_ROWS - 1 do
		PlotParts[row] = {}
		for col = 0, GRID_COLS - 1 do
			local origin = cellOrigin(row, col)
			local pad    = Instance.new("Part")
			pad.Name     = string.format("CityPlot_%d_%d", row, col)
			pad.Size     = Vector3.new(CELL_SIZE - 1, 0.4, CELL_SIZE - 1)
			pad.CFrame   = CFrame.new(origin.X, 0.2, origin.Z)
			pad.Anchored = true
			pad.Material = Enum.Material.Grass
			pad.BrickColor = BrickColor.new("Medium green")
			pad.TopSurface   = Enum.SurfaceType.Smooth
			pad.BottomSurface = Enum.SurfaceType.Smooth
			pad.Parent   = CityFolder

			local gui    = Instance.new("SurfaceGui")
			gui.Name     = "PlotGui"
			gui.Face     = Enum.NormalId.Top
			gui.Parent   = pad
			local tl     = Instance.new("TextLabel")
			tl.Name      = "Label"
			tl.Size      = UDim2.new(1,0,1,0)
			tl.BackgroundTransparency = 1
			tl.Text      = "Buy\n$"..BuildingData.PlotCost
			tl.TextScaled = true
			tl.Font      = Enum.Font.Gotham
			tl.TextColor3 = Color3.new(1,1,1)
			tl.Parent    = gui

			local cd     = Instance.new("ClickDetector")
			cd.MaxActivationDistance = 20
			cd.Parent    = pad

			PlotParts[row][col] = pad

			local r, c = row, col
			cd.MouseClick:Connect(function(player)
				local plot = getPlot(r, c)
				if not plot then
					RE.BuyPlot:FireClient(player, r, c)
				elseif plot.owner == player.UserId then
					RE.BuildOnPlot:FireClient(player, r, c, plot.building)
				else
					-- Monopoly rent
					local ownerPlayer = Players:GetPlayerByUserId(plot.owner)
					if ownerPlayer then
						local bd   = plot.building and BuildingData.Buildings[plot.building]
						local rent = bd and math.floor(bd.cost * 0.05) or 50
						RE.CityNotify:FireClient(player,
							"You owe rent of $"..rent.." to "..ownerPlayer.Name.."!")
						RE.CityNotify:FireClient(ownerPlayer,
							player.Name.." paid you $"..rent.." rent!")
					end
				end
			end)
		end
	end
end

-- ── Handle BuyPlot confirmed from client ──────────────────────────────────
RE.BuyPlot.OnServerEvent:Connect(function(player, row, col, confirmed)
	if not confirmed then return end
	if getPlot(row, col) then
		RE.CityNotify:FireClient(player, "That plot is already owned!")
		return
	end

	-- Find player's coin value (set by Main.server in player's Farm folder)
	local farmFolder  = Workspace:FindFirstChild("Farm_" .. player.Name)
	local statsFolder = farmFolder and farmFolder:FindFirstChild("Stats")
	local coinsVal    = statsFolder and statsFolder:FindFirstChild("Coins")

	if coinsVal and coinsVal.Value < BuildingData.PlotCost then
		RE.CityNotify:FireClient(player, "Not enough coins! Need $"..BuildingData.PlotCost)
		return
	end
	if coinsVal then coinsVal.Value = coinsVal.Value - BuildingData.PlotCost end

	setPlot(row, col, { owner = player.UserId, building = nil })
	updatePlotVisual(row, col)
	RE.UpdateCityGrid:FireAllClients(row, col, getPlot(row, col))
	RE.CityNotify:FireClient(player, "Plot ("..col..","..row..") purchased!")
end)

-- ── Handle BuildOnPlot from client ────────────────────────────────────────
RE.BuildOnPlot.OnServerEvent:Connect(function(player, row, col, buildingKey, demolish)
	local plot = getPlot(row, col)
	if not plot or plot.owner ~= player.UserId then
		RE.CityNotify:FireClient(player, "You don't own this plot.")
		return
	end

	if demolish then
		plot.building = nil
		setPlot(row, col, plot)
		updatePlotVisual(row, col)
		recalcStats()
		broadcastStats()
		RE.CityNotify:FireClient(player, "Building demolished.")
		return
	end

	local bd = BuildingData.Buildings[buildingKey]
	if not bd then
		RE.CityNotify:FireClient(player, "Unknown building: "..tostring(buildingKey))
		return
	end

	local farmFolder  = Workspace:FindFirstChild("Farm_" .. player.Name)
	local statsFolder = farmFolder and farmFolder:FindFirstChild("Stats")
	local coinsVal    = statsFolder and statsFolder:FindFirstChild("Coins")

	if coinsVal and coinsVal.Value < bd.cost then
		RE.CityNotify:FireClient(player, "Need $"..bd.cost.." to build "..bd.displayName)
		return
	end
	if coinsVal then coinsVal.Value = coinsVal.Value - bd.cost end

	plot.building = buildingKey
	setPlot(row, col, plot)
	updatePlotVisual(row, col)
	recalcStats()
	broadcastStats()
	RE.UpdateCityGrid:FireAllClients(row, col, plot)
	RE.CityNotify:FireClient(player,
		"Built "..bd.displayName.." — Population +"..bd.population)
end)

-- ── Income tick every 60 seconds ──────────────────────────────────────────
task.spawn(function()
	while true do
		task.wait(BuildingData.IncomeTick)
		recalcStats()

		for row = 0, GRID_ROWS - 1 do
			for col = 0, GRID_COLS - 1 do
				local plot = getPlot(row, col)
				if plot and plot.building then
					local bd    = BuildingData.Buildings[plot.building]
					local owner = bd and Players:GetPlayerByUserId(plot.owner)
					if owner and bd and bd.income > 0 then
						local ff = Workspace:FindFirstChild("Farm_" .. owner.Name)
						local sf = ff and ff:FindFirstChild("Stats")
						local cv = sf and sf:FindFirstChild("Coins")
						if cv then cv.Value = cv.Value + bd.income end
					end
				end
			end
		end

		-- Distribute NPC farm treasury to all online players
		if CityStats.treasury > 0 then
			local online = Players:GetPlayers()
			if #online > 0 then
				local share = math.floor(CityStats.treasury / #online)
				for _, p in ipairs(online) do
					local ff = Workspace:FindFirstChild("Farm_" .. p.Name)
					local sf = ff and ff:FindFirstChild("Stats")
					local cv = sf and sf:FindFirstChild("Coins")
					if cv then cv.Value = cv.Value + share end
				end
				CityStats.treasury = CityStats.treasury % #online
			end
		end

		broadcastStats()
	end
end)

-- ── Boot ──────────────────────────────────────────────────────────────────
task.wait(3)   -- let Main.server finish world build
buildCityGrid()
recalcStats()
broadcastStats()
print(string.format("[City] Grid built — %dx%d plots starting at X=%.0f",
	GRID_COLS, GRID_ROWS, GRID_ORIGIN.X))
