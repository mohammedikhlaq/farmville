-- NPCFarmManager.server.lua
-- Three computer-driven farms that auto-cycle through:
--   Empty → Planted → Growing → Ready → Harvested → Empty → ...
-- Each harvest deposits coins into the city treasury (CityManager).
-- Farms are placed within ~60-80 studs of the player farm so they are clearly visible.

local Workspace  = game:GetService("Workspace")

-- ── NPC Farm definitions ─────────────────────────────────────────────────
--   pos      : centre of the farm pad
--   cols/rows: plot grid size
--   cropName : what they grow (cosmetic name)
--   growTime : seconds per full cycle
--   revenue  : coins deposited per harvest

local NPC_FARMS = {
	{
		name     = "Hartley Farm",
		pos      = Vector3.new(-55, 0, 0),     -- directly west of player farm
		cols     = 4, rows = 4,
		cropName = "Wheat",
		growTime = 90,
		revenue  = 120,
		padColor = "Bright orange",
		cropColor= "Bright yellow",
	},
	{
		name     = "Green Acres",
		pos      = Vector3.new(-60, 0, 55),    -- northwest
		cols     = 5, rows = 3,
		cropName = "Corn",
		growTime = 120,
		revenue  = 180,
		padColor = "Bright green",
		cropColor= "Bright yellow",
	},
	{
		name     = "Sunny Fields",
		pos      = Vector3.new(10, 0, 78),     -- north
		cols     = 4, rows = 5,
		cropName = "Tomatoes",
		growTime = 75,
		revenue  = 100,
		padColor = "Sand red",
		cropColor= "Bright red",
	},
}

local PLOT_SIZE    = 8
local PLOT_SPACING = 1
local STRIDE       = PLOT_SIZE + PLOT_SPACING

-- ── Shared city treasury (set by CityManager once it's ready) ────────────
local CityTreasury = nil

-- ── Build one NPC farm visually ───────────────────────────────────────────
local function buildNPCFarm(def)
	local folder      = Instance.new("Folder")
	folder.Name       = def.name
	folder.Parent     = Workspace

	-- Farm label sign
	local signPost        = Instance.new("Part")
	signPost.Name         = "SignPost"
	signPost.Size         = Vector3.new(0.4, 5, 0.4)
	signPost.CFrame       = CFrame.new(def.pos + Vector3.new(-STRIDE, 2.5, -STRIDE*2))
	signPost.Anchored     = true
	signPost.Material     = Enum.Material.Wood
	signPost.BrickColor   = BrickColor.new("Reddish brown")
	signPost.TopSurface   = Enum.SurfaceType.Smooth
	signPost.BottomSurface = Enum.SurfaceType.Smooth
	signPost.Parent       = folder

	local signBoard       = Instance.new("Part")
	signBoard.Name        = "Sign"
	signBoard.Size        = Vector3.new(8, 2, 0.3)
	signBoard.CFrame      = CFrame.new(def.pos + Vector3.new(-STRIDE+3, 5.5, -STRIDE*2))
	signBoard.Anchored    = true
	signBoard.Material    = Enum.Material.Wood
	signBoard.BrickColor  = BrickColor.new("CGA brown")
	signBoard.TopSurface  = Enum.SurfaceType.Smooth
	signBoard.BottomSurface = Enum.SurfaceType.Smooth
	signBoard.Parent      = folder

	local sg              = Instance.new("SurfaceGui")
	sg.Face               = Enum.NormalId.Front
	sg.Parent             = signBoard
	local lbl             = Instance.new("TextLabel")
	lbl.Size              = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = def.name
	lbl.TextScaled        = true
	lbl.Font              = Enum.Font.GothamBold
	lbl.TextColor3        = Color3.new(1,1,1)
	lbl.Parent            = sg

	-- Fence around the farm
	local halfW = (def.cols * STRIDE) / 2
	local halfH = (def.rows * STRIDE) / 2
	local fenceProps = {
		{Vector3.new(def.cols*STRIDE+2, 1.5, 0.4), def.pos + Vector3.new(0, 0.75, -halfH)},
		{Vector3.new(def.cols*STRIDE+2, 1.5, 0.4), def.pos + Vector3.new(0, 0.75,  halfH)},
		{Vector3.new(0.4, 1.5, def.rows*STRIDE+2), def.pos + Vector3.new(-halfW, 0.75, 0)},
		{Vector3.new(0.4, 1.5, def.rows*STRIDE+2), def.pos + Vector3.new( halfW, 0.75, 0)},
	}
	for _, fp in ipairs(fenceProps) do
		local f           = Instance.new("Part")
		f.Size            = fp[1]
		f.CFrame          = CFrame.new(fp[2])
		f.Anchored        = true
		f.Material        = Enum.Material.Wood
		f.BrickColor      = BrickColor.new("Reddish brown")
		f.TopSurface      = Enum.SurfaceType.Smooth
		f.BottomSurface   = Enum.SurfaceType.Smooth
		f.Parent          = folder
	end

	-- Plots
	local plots = {}
	for row = 0, def.rows - 1 do
		for col = 0, def.cols - 1 do
			local x = def.pos.X + (col - (def.cols-1)/2) * STRIDE
			local z = def.pos.Z + (row - (def.rows-1)/2) * STRIDE

			local pad         = Instance.new("Part")
			pad.Name          = "Plot_"..row.."_"..col
			pad.Size          = Vector3.new(PLOT_SIZE, 0.4, PLOT_SIZE)
			pad.CFrame        = CFrame.new(x, 0.2, z)
			pad.Anchored      = true
			pad.Material      = Enum.Material.Ground
			pad.BrickColor    = BrickColor.new("Reddish brown")
			pad.TopSurface    = Enum.SurfaceType.Smooth
			pad.BottomSurface = Enum.SurfaceType.Smooth
			pad.Parent        = folder

			-- Status label on the plot
			local gui          = Instance.new("SurfaceGui")
			gui.Name           = "StatusGui"
			gui.Face           = Enum.NormalId.Top
			gui.Parent         = pad
			local tl           = Instance.new("TextLabel")
			tl.Name            = "Status"
			tl.Size            = UDim2.new(1,0,1,0)
			tl.BackgroundTransparency = 1
			tl.Text            = "Empty"
			tl.TextScaled      = true
			tl.Font            = Enum.Font.GothamBold
			tl.TextColor3      = Color3.new(1,1,1)
			tl.Parent          = gui

			table.insert(plots, { pad = pad, label = tl })
		end
	end

	return folder, plots
end

-- ── Growth stages ─────────────────────────────────────────────────────────
local STAGES = {
	{ name = "Planted",   color = "Reddish brown",         fraction = 0.00 },
	{ name = "Sprouting", color = "Bright green",           fraction = 0.25 },
	{ name = "Growing",   color = "Bright yellowish-green", fraction = 0.50 },
	{ name = "Ready!",    color = "Bright yellow",          fraction = 0.75 },
}

local function runFarmCycle(def, folder, plots)
	task.spawn(function()
		task.wait(math.random(5, 25))   -- stagger start

		while folder and folder.Parent do
			for _, stage in ipairs(STAGES) do
				for _, p in ipairs(plots) do
					p.pad.BrickColor = BrickColor.new(stage.color)
					p.label.Text     = stage.name
				end
				task.wait(def.growTime * 0.25)
			end

			-- Harvest
			for _, p in ipairs(plots) do
				p.pad.BrickColor = BrickColor.new(def.padColor)
				p.label.Text     = "Harvested!"
			end

			if CityTreasury then
				CityTreasury.deposit(def.revenue)
			end
			print(string.format("[NPC Farm] %s harvested — +%d coins", def.name, def.revenue))

			task.wait(8)   -- brief empty period

			for _, p in ipairs(plots) do
				p.pad.BrickColor = BrickColor.new("Reddish brown")
				p.label.Text     = "Empty"
			end
			task.wait(5)
		end
	end)
end

-- ── Boot ──────────────────────────────────────────────────────────────────
task.wait(2)

-- Bind treasury once CityManager has published the BindableEvent
task.spawn(function()
	local tries = 0
	while not CityTreasury and tries < 60 do
		local bf = Workspace:FindFirstChild("_CityTreasuryAPI")
		if bf and bf:IsA("BindableEvent") then
			CityTreasury = { deposit = function(amount) bf:Fire(amount) end }
		end
		task.wait(1)
		tries = tries + 1
	end
	if CityTreasury then
		print("[NPC Farm] Treasury API bound.")
	else
		warn("[NPC Farm] Treasury API not found after 60s — revenues will be lost.")
	end
end)

for _, def in ipairs(NPC_FARMS) do
	local folder, plots = buildNPCFarm(def)
	runFarmCycle(def, folder, plots)
	print(string.format("[NPC Farm] Built %s (%dx%d) at (%.0f, %.0f)",
		def.name, def.cols, def.rows, def.pos.X, def.pos.Z))
end
