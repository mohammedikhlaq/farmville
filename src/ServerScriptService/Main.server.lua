-- Main.server.lua  (Script in ServerScriptService)
-- Single server script — no _G, no cross-script dependencies

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RS               = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")

-- ══════════════════════════════════════════════════════════════════════════
--  IMMEDIATE GROUND — pure Lua, no XML, runs in milliseconds
--  Character cannot spawn until CharacterAutoLoads = true below, but this
--  ensures solid ground exists even if buildWorld() later has any error.
-- ══════════════════════════════════════════════════════════════════════════

local baseplate            = Instance.new("Part")
baseplate.Name             = "Baseplate"
baseplate.Size             = Vector3.new(2048, 20, 2048)
baseplate.CFrame           = CFrame.new(0, -10, 0)
baseplate.Anchored         = true
baseplate.Material         = Enum.Material.Grass
baseplate.BrickColor       = BrickColor.new("Bright green")
baseplate.TopSurface       = Enum.SurfaceType.Smooth
baseplate.BottomSurface    = Enum.SurfaceType.Smooth
baseplate.Parent           = Workspace

local spawnPad             = Instance.new("SpawnLocation")
spawnPad.Name              = "SpawnLocation"
spawnPad.Size              = Vector3.new(10, 1, 10)
spawnPad.CFrame            = CFrame.new(0, 0.5, 0)
spawnPad.Anchored          = true
spawnPad.Neutral           = true
spawnPad.Material          = Enum.Material.SmoothPlastic
spawnPad.BrickColor        = BrickColor.new("Bright yellow")
spawnPad.TopSurface        = Enum.SurfaceType.Smooth
spawnPad.BottomSurface     = Enum.SurfaceType.Smooth
spawnPad.Parent            = Workspace

-- ══════════════════════════════════════════════════════════════════════════
--  CHARACTER GUARD — fires the instant any character loads, checks if they
--  are floating in the air (Y > 10) and teleports them to the SpawnPad.
--  This is MORE reliable than CharacterAutoLoads = false which has a race
--  condition in Studio Play Solo mode.
-- ══════════════════════════════════════════════════════════════════════════

local function guardSpawn(character)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end
	task.wait()  -- one physics frame so position is settled
	if hrp.Position.Y > 5 then
		hrp.CFrame = CFrame.new(0, 5, 0)  -- land on Baseplate
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(guardSpawn)
	if player.Character then guardSpawn(player.Character) end
end)
-- cover players already in-game (Studio Play Solo has player before script)
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		guardSpawn(p.Character)
	end
end

-- ── Shared data ───────────────────────────────────────────────────────────
local GameData = require(RS:WaitForChild("GameModules"):WaitForChild("GameData"))
local Config   = GameData.Config

-- ══════════════════════════════════════════════════════════════════════════
--  WORLD BUILDER  — runs once at server start, creates ALL terrain & scenery
-- ══════════════════════════════════════════════════════════════════════════

local function buildWorld()
	local terrain = workspace.Terrain

	-- ── Flat grass ground (512×512, surface at Y = 0) ──────────────────────
	terrain:FillBlock(
		CFrame.new(0, -4, 0),
		Vector3.new(512, 8, 512),
		Enum.Material.Grass
	)

	-- ── Dirt path leading to farm ──────────────────────────────────────────
	terrain:FillBlock(
		CFrame.new(0, 0, -14),
		Vector3.new(6, 0.2, 30),
		Enum.Material.Ground
	)

	-- ── SpawnLocation (player lands here on join) ──────────────────────────
	local spawn          = Instance.new("SpawnLocation")
	spawn.Name           = "SpawnLocation"
	spawn.Size           = Vector3.new(8, 1, 8)
	spawn.CFrame         = CFrame.new(0, 0.5, -28)
	spawn.Anchored       = true
	spawn.Material       = Enum.Material.SmoothPlastic
	spawn.BrickColor     = BrickColor.new("Bright green")
	spawn.TopSurface     = Enum.SurfaceType.Smooth
	spawn.BottomSurface  = Enum.SurfaceType.Smooth
	spawn.Neutral        = true
	spawn.Parent         = Workspace

	-- ── Farm sign ──────────────────────────────────────────────────────────
	local signPost        = Instance.new("Part")
	signPost.Name         = "SignPost"
	signPost.Size         = Vector3.new(0.5, 4, 0.5)
	signPost.CFrame       = CFrame.new(-5, 2, -34)
	signPost.Anchored     = true
	signPost.Material     = Enum.Material.Wood
	signPost.BrickColor   = BrickColor.new("Reddish brown")
	signPost.TopSurface   = Enum.SurfaceType.Smooth
	signPost.BottomSurface = Enum.SurfaceType.Smooth
	signPost.Parent       = Workspace

	local signPost2       = signPost:Clone()
	signPost2.CFrame      = CFrame.new(5, 2, -34)
	signPost2.Parent      = Workspace

	local signBoard       = Instance.new("Part")
	signBoard.Name        = "SignBoard"
	signBoard.Size        = Vector3.new(14, 3, 0.4)
	signBoard.CFrame      = CFrame.new(0, 4, -34)
	signBoard.Anchored    = true
	signBoard.Material    = Enum.Material.Wood
	signBoard.BrickColor  = BrickColor.new("CGA brown")
	signBoard.TopSurface  = Enum.SurfaceType.Smooth
	signBoard.BottomSurface = Enum.SurfaceType.Smooth
	signBoard.Parent      = Workspace

	local sg              = Instance.new("SurfaceGui")
	sg.Face               = Enum.NormalId.Front
	sg.CanvasSize         = Vector2.new(700, 150)
	sg.Parent             = signBoard

	local stitle          = Instance.new("TextLabel")
	stitle.Size           = UDim2.new(1, 0, 1, 0)
	stitle.BackgroundTransparency = 1
	stitle.Text           = "🌻  Adam And Eshaals Farm  🌻"
	stitle.TextColor3     = Color3.fromRGB(255, 230, 50)
	stitle.Font           = Enum.Font.GothamBold
	stitle.TextScaled     = true
	stitle.Parent         = sg

	-- ── Barn (red building) ────────────────────────────────────────────────
	local function makePart(name, size, cframe, mat, color)
		local p             = Instance.new("Part")
		p.Name              = name
		p.Size              = size
		p.CFrame            = cframe
		p.Anchored          = true
		p.Material          = mat
		p.BrickColor        = BrickColor.new(color)
		p.TopSurface        = Enum.SurfaceType.Smooth
		p.BottomSurface     = Enum.SurfaceType.Smooth
		p.Parent            = Workspace
		return p
	end

	-- Barn walls
	makePart("BarnFront",  Vector3.new(20, 14, 1),  CFrame.new(30, 7, -10),  Enum.Material.SmoothPlastic, "Bright red")
	makePart("BarnBack",   Vector3.new(20, 14, 1),  CFrame.new(30, 7,  10),  Enum.Material.SmoothPlastic, "Bright red")
	makePart("BarnLeft",   Vector3.new(1,  14, 20), CFrame.new(20, 7,   0),  Enum.Material.SmoothPlastic, "Bright red")
	makePart("BarnRight",  Vector3.new(1,  14, 20), CFrame.new(40, 7,   0),  Enum.Material.SmoothPlastic, "Bright red")
	-- Barn roof (wedges via tilted parts)
	makePart("BarnRoof1",  Vector3.new(22, 1,  12), CFrame.new(30, 14, -5) * CFrame.Angles(math.rad(-28), 0, 0), Enum.Material.SmoothPlastic, "Dark red")
	makePart("BarnRoof2",  Vector3.new(22, 1,  12), CFrame.new(30, 14,  5) * CFrame.Angles(math.rad( 28), 0, 0), Enum.Material.SmoothPlastic, "Dark red")
	-- Barn door
	makePart("BarnDoor",   Vector3.new(6, 8, 0.5),  CFrame.new(30, 4, -10.3), Enum.Material.Wood, "CGA brown")

	-- ── Trees (simple: trunk + sphere leaves) ─────────────────────────────
	local treePositions = {
		Vector3.new(-28, 0, -28), Vector3.new(-32, 0, -10), Vector3.new(-28, 0, 10),
		Vector3.new( 55, 0, -28), Vector3.new( 55, 0,   0), Vector3.new( 55, 0,  20),
		Vector3.new(-28, 0,  28), Vector3.new( 10, 0,  32), Vector3.new( 20, 0,  32),
	}
	for i, pos in ipairs(treePositions) do
		local trunk       = Instance.new("Part")
		trunk.Name        = "TreeTrunk" .. i
		trunk.Size        = Vector3.new(1.2, 8, 1.2)
		trunk.CFrame      = CFrame.new(pos + Vector3.new(0, 4, 0))
		trunk.Anchored    = true
		trunk.Material    = Enum.Material.Wood
		trunk.BrickColor  = BrickColor.new("Reddish brown")
		trunk.Shape       = Enum.PartType.Cylinder
		trunk.TopSurface  = Enum.SurfaceType.Smooth
		trunk.BottomSurface = Enum.SurfaceType.Smooth
		trunk.Parent      = Workspace

		local leaves      = Instance.new("Part")
		leaves.Name       = "TreeLeaves" .. i
		leaves.Size       = Vector3.new(8, 8, 8)
		leaves.CFrame     = CFrame.new(pos + Vector3.new(0, 11, 0))
		leaves.Anchored   = true
		leaves.Material   = Enum.Material.Neon
		leaves.BrickColor = BrickColor.new("Bright green")
		leaves.Shape      = Enum.PartType.Ball
		leaves.TopSurface = Enum.SurfaceType.Smooth
		leaves.BottomSurface = Enum.SurfaceType.Smooth
		leaves.Parent     = Workspace
	end

	-- ── Wooden fence around farm ───────────────────────────────────────────
	local COLS    = Config.GridCols
	local ROWS    = Config.GridRows
	local STRIDE  = Config.PlotSize + Config.PlotSpacing
	local halfW   = (COLS * STRIDE) / 2 + 2
	local halfH   = (ROWS * STRIDE) / 2 + 2
	local fenceY  = 1.5

	local fenceSegments = {
		-- north / south rails
		{Vector3.new(COLS*STRIDE+4, 1, 0.5), CFrame.new( 0, fenceY, -halfH)},
		{Vector3.new(COLS*STRIDE+4, 1, 0.5), CFrame.new( 0, fenceY,  halfH)},
		-- east / west rails
		{Vector3.new(0.5, 1, ROWS*STRIDE+4), CFrame.new(-halfW, fenceY, 0)},
		{Vector3.new(0.5, 1, ROWS*STRIDE+4), CFrame.new( halfW, fenceY, 0)},
		-- lower rails
		{Vector3.new(COLS*STRIDE+4, 1, 0.5), CFrame.new( 0, fenceY-1.5, -halfH)},
		{Vector3.new(COLS*STRIDE+4, 1, 0.5), CFrame.new( 0, fenceY-1.5,  halfH)},
		{Vector3.new(0.5, 1, ROWS*STRIDE+4), CFrame.new(-halfW, fenceY-1.5, 0)},
		{Vector3.new(0.5, 1, ROWS*STRIDE+4), CFrame.new( halfW, fenceY-1.5, 0)},
	}
	for _, seg in ipairs(fenceSegments) do
		makePart("Fence", seg[1], seg[2], Enum.Material.Wood, "Bright orange")
	end

	-- ── Water well (decoration) ────────────────────────────────────────────
	makePart("WellBase",    Vector3.new(4, 1,  4),   CFrame.new(-18, 0.5,  -8), Enum.Material.SmoothPlastic, "Light stone grey")
	makePart("WellWall1",   Vector3.new(4, 2.5, 0.5),CFrame.new(-18, 1.75, -10), Enum.Material.SmoothPlastic, "Light stone grey")
	makePart("WellWall2",   Vector3.new(4, 2.5, 0.5),CFrame.new(-18, 1.75,  -6), Enum.Material.SmoothPlastic, "Light stone grey")
	makePart("WellPost1",   Vector3.new(0.5, 4, 0.5),CFrame.new(-20, 2.5,  -8), Enum.Material.Wood, "Reddish brown")
	makePart("WellPost2",   Vector3.new(0.5, 4, 0.5),CFrame.new(-16, 2.5,  -8), Enum.Material.Wood, "Reddish brown")
	makePart("WellRoof",    Vector3.new(5, 0.5, 2),  CFrame.new(-18, 4.5,  -8), Enum.Material.Wood, "CGA brown")

	print("🌍 World built — terrain, barn, trees, fence, well all ready!")
end

-- Run world builder — pcall so ANY error still lets characters load
local ok, err = pcall(buildWorld)
if not ok then
	warn("[Farm] buildWorld error (game still playable on flat ground): " .. tostring(err))
end

print("[Farm] World ready — all players on solid ground.")

-- ── Create Remotes folder ─────────────────────────────────────────────────
local remotesFolder    = Instance.new("Folder")
remotesFolder.Name     = "Remotes"
remotesFolder.Parent   = RS

local function makeEvent(name)
	local e      = Instance.new("RemoteEvent")
	e.Name       = name
	e.Parent     = remotesFolder
	return e
end

local RE = {
	PlantCrop        = makeEvent("PlantCrop"),
	HarvestCrop      = makeEvent("HarvestCrop"),
	WaterCrop        = makeEvent("WaterCrop"),
	BuySeed          = makeEvent("BuySeed"),
	UnlockPlot       = makeEvent("UnlockPlot"),
	UpdatePlots      = makeEvent("UpdatePlots"),
	UpdatePlayerData = makeEvent("UpdatePlayerData"),
	Notify           = makeEvent("Notify"),
	PlotClicked      = makeEvent("PlotClicked"),
}

-- ── DataStore ─────────────────────────────────────────────────────────────
local FarmStore = DataStoreService:GetDataStore("AaEFarm_v3")

local function defaultPlots()
	local plots = {}
	local total = Config.GridCols * Config.GridRows
	for i = 1, total do
		plots[i] = {
			Unlocked  = (i <= Config.StartingUnlockedPlots),
			CropName  = nil,
			PlantedAt = nil,
			WateredAt = nil,
		}
	end
	return plots
end

local function defaultData()
	return {
		Coins         = Config.StartingCoins,
		XP            = Config.StartingXP,
		Level         = Config.StartingLevel,
		Plots         = defaultPlots(),
		Inventory     = {},
		TotalHarvests = 0,
	}
end

local PlayerData = {}   -- [player] = data table

local function loadData(player)
	local ok, saved = pcall(function()
		return FarmStore:GetAsync("p_" .. player.UserId)
	end)
	local data
	if ok and type(saved) == "table" then
		data = saved
		if not data.Plots    then data.Plots    = defaultPlots() end
		if not data.Inventory then data.Inventory = {} end
		local total = Config.GridCols * Config.GridRows
		for i = 1, total do
			if not data.Plots[i] then
				data.Plots[i] = { Unlocked=(i<=Config.StartingUnlockedPlots), CropName=nil, PlantedAt=nil, WateredAt=nil }
			end
		end
		data.Coins         = data.Coins         or Config.StartingCoins
		data.XP            = data.XP            or 0
		data.Level         = data.Level          or 1
		data.TotalHarvests = data.TotalHarvests  or 0
	else
		data = defaultData()
		if not ok then warn("[Farm] Load failed: " .. tostring(saved)) end
	end
	PlayerData[player] = data
	return data
end

local function saveData(player)
	local data = PlayerData[player]
	if not data then return end
	local ok, err = pcall(function()
		FarmStore:SetAsync("p_" .. player.UserId, data)
	end)
	if not ok then warn("[Farm] Save failed: " .. tostring(err)) end
end

-- ── Sync helpers ──────────────────────────────────────────────────────────

local function notify(player, msg, ntype)
	RE.Notify:FireClient(player, msg, ntype or "Info")
end

local function syncData(player)
	local d = PlayerData[player]
	if not d then return end
	RE.UpdatePlayerData:FireClient(player, {
		Coins         = d.Coins,
		XP            = d.XP,
		Level         = d.Level,
		Inventory     = d.Inventory,
		TotalHarvests = d.TotalHarvests,
	})
end

local function syncPlots(player)
	local d = PlayerData[player]
	if not d then return end
	RE.UpdatePlots:FireClient(player, d.Plots)
end

-- ── XP / Levelling ────────────────────────────────────────────────────────

local function addXP(player, amount)
	local d = PlayerData[player]
	if not d then return end
	d.XP = d.XP + amount
	local levelled = false
	while d.Level < Config.MaxLevel and d.XP >= GameData.XPForLevel(d.Level) do
		d.XP    = d.XP - GameData.XPForLevel(d.Level)
		d.Level = d.Level + 1
		levelled = true
	end
	if levelled then
		notify(player, "⭐ Level Up!  You are now Level " .. d.Level .. "!", "LevelUp")
	end
end

-- ── Growth helpers ────────────────────────────────────────────────────────

local function growthFraction(plot)
	if not plot.CropName or not plot.PlantedAt then return 0 end
	local crop = GameData.GetCrop(plot.CropName)
	if not crop then return 0 end
	local dur = crop.Time
	if plot.WateredAt then dur = dur * (1 - Config.WaterBoost) end
	return math.min((os.time() - plot.PlantedAt) / dur, 1)
end

local function isWilted(plot)
	if not plot.CropName or not plot.PlantedAt then return false end
	local crop = GameData.GetCrop(plot.CropName)
	if not crop then return false end
	local dur = crop.Time
	if plot.WateredAt then dur = dur * (1 - Config.WaterBoost) end
	return (os.time() - plot.PlantedAt) >= dur * (1 + Config.WiltMultiplier)
end

-- ── Farm Part creation ────────────────────────────────────────────────────

local STRIDE = Config.PlotSize + Config.PlotSpacing
local COLS   = Config.GridCols
local ROWS   = Config.GridRows

local function plotPosition(i)
	local col = (i-1) % COLS
	local row = math.floor((i-1) / COLS)
	local x   = (col - (COLS-1)/2) * STRIDE
	local z   = (row - (ROWS-1)/2) * STRIDE
	return Vector3.new(x, 0.75, z)
end

local FarmFolders = {}   -- [player] = Folder

local function createFarmParts(player)
	local folder      = Instance.new("Folder")
	folder.Name       = "Farm_" .. player.Name
	folder.Parent     = Workspace

	local total = COLS * ROWS
	for i = 1, total do
		local part           = Instance.new("Part")
		part.Name            = "Plot" .. i
		part.Size            = Vector3.new(Config.PlotSize, 0.5, Config.PlotSize)
		part.Position        = plotPosition(i)
		part.Anchored        = true
		part.TopSurface      = Enum.SurfaceType.Smooth
		part.BottomSurface   = Enum.SurfaceType.Smooth
		part.Material        = Enum.Material.SmoothPlastic
		part.BrickColor      = BrickColor.new("Reddish brown")

		local cd                     = Instance.new("ClickDetector")
		cd.MaxActivationDistance     = 32
		cd.Parent                    = part

		local bb              = Instance.new("BillboardGui")
		bb.Name               = "Label"
		bb.Size               = UDim2.new(0, 110, 0, 55)
		bb.StudsOffset        = Vector3.new(0, 1.5, 0)
		bb.AlwaysOnTop        = false
		bb.Parent             = part

		local lbl             = Instance.new("TextLabel")
		lbl.Name              = "Text"
		lbl.Size              = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font              = Enum.Font.GothamBold
		lbl.TextScaled        = true
		lbl.TextColor3        = Color3.new(1, 1, 1)
		lbl.Text              = (i <= Config.StartingUnlockedPlots) and "" or "🔒"
		lbl.Parent            = bb

		local plotIndex = i
		cd.MouseClick:Connect(function(clicker)
			if clicker == player then
				RE.PlotClicked:FireClient(player, plotIndex)
			end
		end)

		part.Parent = folder
	end

	FarmFolders[player] = folder
end

local function getPlotPart(player, i)
	local f = FarmFolders[player]
	return f and f:FindFirstChild("Plot" .. i)
end

local function refreshPlotVisual(player, i)
	local d    = PlayerData[player]
	local part = getPlotPart(player, i)
	if not d or not part then return end

	local plot = d.Plots[i]
	local lbl  = part:FindFirstChild("Label") and part.Label:FindFirstChild("Text")

	if not plot.Unlocked then
		part.BrickColor = BrickColor.new("Medium stone grey")
		if lbl then lbl.Text = "🔒" end
		return
	end

	if not plot.CropName then
		part.BrickColor = BrickColor.new("Reddish brown")
		if lbl then lbl.Text = "Empty\nClick Shop!" end
		return
	end

	if isWilted(plot) then
		part.BrickColor = BrickColor.new("Olive")
		if lbl then lbl.Text = "💀\nWilted" end
		return
	end

	local frac = growthFraction(plot)
	if frac >= 1 then
		part.BrickColor = BrickColor.new("Bright green")
		if lbl then lbl.Text = "✅ Ready!\nHarvest!" end
	else
		local pct   = math.floor(frac * 100)
		local stage = frac < 0.33 and "🌱" or frac < 0.66 and "🌿" or "🌾"
		part.BrickColor = BrickColor.new("Brown")
		if lbl then
			local crop = GameData.GetCrop(plot.CropName)
			lbl.Text   = stage .. " " .. (crop and crop.Display:match("^(%S+)") or "Crop") .. "\n" .. pct .. "%"
		end
	end
end

local function refreshAllVisuals(player)
	local d = PlayerData[player]
	if not d then return end
	for i = 1, #d.Plots do refreshPlotVisual(player, i) end
end

-- ── Actions ───────────────────────────────────────────────────────────────

local function plantCrop(player, idx, cropName)
	local d    = PlayerData[player]
	if not d then return end
	local plot = d.Plots[idx]
	if not plot             then notify(player, "Invalid plot", "Error") return end
	if not plot.Unlocked    then notify(player, "Unlock this plot first! Click it.", "Error") return end
	if plot.CropName        then notify(player, "Already planted here!", "Error") return end

	local crop = GameData.GetCrop(cropName)
	if not crop             then notify(player, "Unknown crop", "Error") return end
	if d.Level < crop.Level then notify(player, crop.Display .. " needs Level " .. crop.Level, "Error") return end

	local inv = d.Inventory[cropName] or 0
	if inv < 1 then notify(player, "No " .. crop.Display .. " seeds! Buy from the Shop 🛒", "Error") return end

	d.Inventory[cropName] = inv - 1
	plot.CropName  = cropName
	plot.PlantedAt = os.time()
	plot.WateredAt = nil

	refreshPlotVisual(player, idx)
	syncData(player)
	notify(player, "Planted " .. crop.Display .. "! Ready in " .. crop.Time .. "s", "Success")
end

local function harvestCrop(player, idx)
	local d    = PlayerData[player]
	if not d then return end
	local plot = d.Plots[idx]
	if not plot or not plot.CropName then notify(player, "Nothing to harvest here!", "Error") return end

	if isWilted(plot) then
		plot.CropName  = nil
		plot.PlantedAt = nil
		plot.WateredAt = nil
		refreshPlotVisual(player, idx)
		syncPlots(player)
		notify(player, "Crop wilted and cleared. Plant a new seed!", "Error")
		return
	end

	local frac = growthFraction(plot)
	if frac < 1 then
		notify(player, "Crop is only " .. math.floor(frac*100) .. "% grown — wait a bit!", "Info")
		return
	end

	local crop = GameData.GetCrop(plot.CropName)
	d.Coins        = d.Coins + (crop and crop.Reward or 0)
	addXP(player, crop and crop.XP or 0)
	d.TotalHarvests = d.TotalHarvests + 1
	plot.CropName  = nil
	plot.PlantedAt = nil
	plot.WateredAt = nil

	refreshPlotVisual(player, idx)
	syncData(player)
	notify(player, "Harvested " .. (crop and crop.Display or "crop") .. "! +" .. (crop and crop.Reward or 0) .. " coins 🪙", "Success")
end

local function waterCrop(player, idx)
	local d    = PlayerData[player]
	if not d then return end
	local plot = d.Plots[idx]
	if not plot or not plot.CropName then notify(player, "Nothing to water here!", "Error") return end
	if plot.WateredAt                then notify(player, "Already watered! 💧", "Info") return end
	if growthFraction(plot) >= 1     then notify(player, "Ready to harvest — no need to water!", "Info") return end

	plot.WateredAt = os.time()
	refreshPlotVisual(player, idx)
	notify(player, "Watered! 💧 Grows 50% faster now.", "Success")
end

local function buySeed(player, cropName, amount)
	local d = PlayerData[player]
	if not d then return end
	amount = math.max(1, math.min(tonumber(amount) or 1, 50))
	local crop = GameData.GetCrop(cropName)
	if not crop          then notify(player, "Unknown crop", "Error") return end
	if d.Level < crop.Level then notify(player, "Requires Level " .. crop.Level, "Error") return end
	local cost = crop.Cost * amount
	if d.Coins < cost    then notify(player, "Need " .. cost .. " coins (have " .. d.Coins .. ")", "Error") return end
	d.Coins = d.Coins - cost
	d.Inventory[cropName] = (d.Inventory[cropName] or 0) + amount
	syncData(player)
	notify(player, "Bought " .. amount .. "× " .. crop.Display .. " seeds! 🛒", "Success")
end

local function unlockPlot(player, idx)
	local d    = PlayerData[player]
	if not d then return end
	local plot = d.Plots[idx]
	if not plot             then return end
	if plot.Unlocked        then notify(player, "Already unlocked!", "Info") return end
	local cost = GameData.PlotUnlockCosts[idx]
	if not cost             then notify(player, "Cannot unlock this plot", "Error") return end
	if d.Coins < cost       then notify(player, "Need " .. cost .. " coins to unlock", "Error") return end
	d.Coins    = d.Coins - cost
	plot.Unlocked = true
	refreshPlotVisual(player, idx)
	syncData(player)
	notify(player, "New plot unlocked! 🎉", "Success")
end

-- ── Remote connections ────────────────────────────────────────────────────

RE.PlantCrop.OnServerEvent:Connect(function(p, idx, cropName)
	plantCrop(p, tonumber(idx), cropName)
end)
RE.HarvestCrop.OnServerEvent:Connect(function(p, idx)
	harvestCrop(p, tonumber(idx))
end)
RE.WaterCrop.OnServerEvent:Connect(function(p, idx)
	waterCrop(p, tonumber(idx))
end)
RE.BuySeed.OnServerEvent:Connect(function(p, cropName, amount)
	buySeed(p, cropName, amount)
end)
RE.UnlockPlot.OnServerEvent:Connect(function(p, idx)
	unlockPlot(p, tonumber(idx))
end)

-- ── Player events ─────────────────────────────────────────────────────────

local function onCharacterAdded(player, character)
	task.wait(0.5)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = CFrame.new(0, 4, -28)   -- in front of the farm
	end
	syncData(player)
	syncPlots(player)
	refreshAllVisuals(player)
end

Players.PlayerAdded:Connect(function(player)
	loadData(player)
	task.wait(0.5)
	createFarmParts(player)

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	if FarmFolders[player] then
		FarmFolders[player]:Destroy()
		FarmFolders[player] = nil
	end
	PlayerData[player] = nil
end)

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
	task.wait(2)
end)

-- ── Visual refresh loop ───────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			refreshAllVisuals(p)
		end
	end
end)

-- ── Auto-save loop ────────────────────────────────────────────────────────

task.spawn(function()
	while true do
		task.wait(Config.AutoSaveInterval)
		for _, p in ipairs(Players:GetPlayers()) do
			saveData(p)
		end
	end
end)

print("✅ Adam And Eshaals Farm — server ready!")
