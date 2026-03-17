-- Client.client.lua  (LocalScript in StarterPlayerScripts)
-- Single client script — handles all UI and input

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

local GameData     = require(RS:WaitForChild("GameModules"):WaitForChild("GameData"))

-- Wait for remotes (created by server Main script)
local remotesFolder = RS:WaitForChild("Remotes", 20)
if not remotesFolder then warn("No Remotes folder!") return end

local RE = {
	PlantCrop        = remotesFolder:WaitForChild("PlantCrop"),
	HarvestCrop      = remotesFolder:WaitForChild("HarvestCrop"),
	WaterCrop        = remotesFolder:WaitForChild("WaterCrop"),
	BuySeed          = remotesFolder:WaitForChild("BuySeed"),
	UnlockPlot       = remotesFolder:WaitForChild("UnlockPlot"),
	UpdatePlots      = remotesFolder:WaitForChild("UpdatePlots"),
	UpdatePlayerData = remotesFolder:WaitForChild("UpdatePlayerData"),
	Notify           = remotesFolder:WaitForChild("Notify"),
	PlotClicked      = remotesFolder:WaitForChild("PlotClicked"),
}

-- ── State ─────────────────────────────────────────────────────────────────
local selectedTool = "Harvest"   -- "Harvest" | "Water" | "Plant"
local selectedCrop = nil
local playerData   = { Coins=500, Level=1, XP=0, Inventory={} }
local plotsData    = {}

-- ── UI Helpers ────────────────────────────────────────────────────────────
local function F(props, parent)
	local f = Instance.new("Frame")
	for k,v in pairs(props) do f[k]=v end
	if parent then f.Parent=parent end
	return f
end
local function L(props, parent)
	local l = Instance.new("TextLabel")
	for k,v in pairs(props) do l[k]=v end
	if parent then l.Parent=parent end
	return l
end
local function B(props, parent)
	local b = Instance.new("TextButton")
	for k,v in pairs(props) do b[k]=v end
	if parent then b.Parent=parent end
	return b
end
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 8)
	c.Parent = p
end
local function listLayout(parent, dir, align, padding)
	local l = Instance.new("UIListLayout")
	l.FillDirection        = dir or Enum.FillDirection.Vertical
	l.HorizontalAlignment  = align or Enum.HorizontalAlignment.Center
	l.VerticalAlignment    = Enum.VerticalAlignment.Center
	l.Padding              = UDim.new(0, padding or 6)
	l.Parent               = parent
	return l
end

-- ── Root ScreenGui ────────────────────────────────────────────────────────
local screen = Instance.new("ScreenGui")
screen.Name           = "FarmUI"
screen.ResetOnSpawn   = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent         = playerGui

-- ════════════════════════════════════════════════════════════
--  TOP BAR
-- ════════════════════════════════════════════════════════════
local topBar = F({
	Name="TopBar", Size=UDim2.new(1,0,0,56), Position=UDim2.new(0,0,0,0),
	BackgroundColor3=Color3.fromRGB(20,70,20), BorderSizePixel=0,
}, screen)

L({
	Size=UDim2.new(0,300,1,0), Position=UDim2.new(0.5,-150,0,0),
	BackgroundTransparency=1, Text="🌻 Adam And Eshaals Farm 🌻",
	TextColor3=Color3.fromRGB(255,230,50), Font=Enum.Font.GothamBold, TextScaled=true,
}, topBar)

local coinsLbl = L({
	Name="Coins", Size=UDim2.new(0,180,0,40), Position=UDim2.new(0,8,0,8),
	BackgroundColor3=Color3.fromRGB(40,30,0), BackgroundTransparency=0.2,
	Text="💰 500 coins", TextColor3=Color3.fromRGB(255,215,0),
	Font=Enum.Font.GothamBold, TextScaled=true,
}, topBar)
corner(coinsLbl)

local levelLbl = L({
	Name="Level", Size=UDim2.new(0,210,0,40), Position=UDim2.new(1,-218,0,8),
	BackgroundColor3=Color3.fromRGB(0,25,60), BackgroundTransparency=0.2,
	Text="⭐ Lv 1  |  0 / 100 XP", TextColor3=Color3.fromRGB(100,200,255),
	Font=Enum.Font.GothamBold, TextScaled=true,
}, topBar)
corner(levelLbl)

-- ════════════════════════════════════════════════════════════
--  TOAST
-- ════════════════════════════════════════════════════════════
local toast = L({
	Name="Toast", Size=UDim2.new(0,460,0,54),
	Position=UDim2.new(0.5,-230,0,62),
	BackgroundColor3=Color3.fromRGB(20,80,20), BackgroundTransparency=0.1,
	Text="", TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
	TextScaled=true, Visible=false, BorderSizePixel=0, ZIndex=50,
}, screen)
corner(toast, 10)

local toastThread
local function showToast(msg, ntype)
	local col = {
		Success=Color3.fromRGB(10,110,10), Error=Color3.fromRGB(130,10,10),
		LevelUp=Color3.fromRGB(130,80,0),  Info=Color3.fromRGB(15,50,130),
	}
	toast.BackgroundColor3 = col[ntype] or col.Info
	toast.Text    = msg
	toast.Visible = true
	if toastThread then task.cancel(toastThread) end
	toastThread = task.delay(4, function() toast.Visible = false end)
end

-- ════════════════════════════════════════════════════════════
--  TOOLBAR  (bottom centre)
-- ════════════════════════════════════════════════════════════
local toolbar = F({
	Name="Toolbar", Size=UDim2.new(0,400,0,60),
	Position=UDim2.new(0.5,-200,1,-70),
	BackgroundColor3=Color3.fromRGB(15,55,15), BackgroundTransparency=0.1,
	BorderSizePixel=0,
}, screen)
corner(toolbar, 12)
listLayout(toolbar, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center, 8)
do local p=Instance.new("UIPadding") p.PaddingLeft=UDim.new(0,8) p.PaddingRight=UDim.new(0,8) p.Parent=toolbar end

local toolBtns = {}

local function makeTool(txt, key, color)
	local b = B({
		Size=UDim2.new(0,108,0,46), BackgroundColor3=color,
		Text=txt, TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
		TextScaled=true, BorderSizePixel=0, BackgroundTransparency=0.4,
	}, toolbar)
	corner(b, 8)
	toolBtns[key] = b
	return b
end

local harvestBtn = makeTool("🌾 Harvest",  "Harvest", Color3.fromRGB(180,100,0))
local waterBtn   = makeTool("💧 Water",    "Water",   Color3.fromRGB(30,110,200))
local shopOpenBtn= makeTool("🛒 Shop",     "Shop",    Color3.fromRGB(50,140,50))

local function activateTool(key)
	selectedTool = key
	for k, b in pairs(toolBtns) do
		b.BackgroundTransparency = (k == key) and 0 or 0.4
	end
	if key ~= "Shop" then
		showToast("Tool: " .. key .. " — click a plot", "Info")
	end
end
activateTool("Harvest")

harvestBtn.MouseButton1Click:Connect(function() activateTool("Harvest") end)
waterBtn.MouseButton1Click:Connect(function() activateTool("Water") end)

-- ════════════════════════════════════════════════════════════
--  SHOP FRAME
-- ════════════════════════════════════════════════════════════
local shopFrame = F({
	Name="Shop", Size=UDim2.new(0,520,0,560),
	Position=UDim2.new(0.5,-260,0.5,-280),
	BackgroundColor3=Color3.fromRGB(12,50,12), BackgroundTransparency=0.03,
	Visible=false, BorderSizePixel=0, ZIndex=20,
}, screen)
corner(shopFrame, 14)

L({
	Size=UDim2.new(1,-55,0,50), Position=UDim2.new(0,10,0,4),
	BackgroundTransparency=1, Text="🛒  Seed Shop",
	TextColor3=Color3.fromRGB(255,230,50), Font=Enum.Font.GothamBold,
	TextScaled=true, ZIndex=21,
}, shopFrame)

local closeBtn = B({
	Size=UDim2.new(0,44,0,44), Position=UDim2.new(1,-50,0,4),
	BackgroundColor3=Color3.fromRGB(180,30,30), Text="✕",
	TextColor3=Color3.new(1,1,1), Font=Enum.Font.GothamBold,
	TextScaled=true, BorderSizePixel=0, ZIndex=21,
}, shopFrame)
corner(closeBtn)
closeBtn.MouseButton1Click:Connect(function() shopFrame.Visible=false end)

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Size               = UDim2.new(1,-12,1,-60)
shopScroll.Position           = UDim2.new(0,6,0,56)
shopScroll.BackgroundTransparency = 1
shopScroll.ScrollBarThickness = 5
shopScroll.CanvasSize         = UDim2.new(0,0,0,0)
shopScroll.AutomaticCanvasSize= Enum.AutomaticSize.Y
shopScroll.ZIndex             = 21
shopScroll.Parent             = shopFrame

listLayout(shopScroll, Enum.FillDirection.Vertical, Enum.HorizontalAlignment.Left, 6)
do local p=Instance.new("UIPadding") p.PaddingTop=UDim.new(0,4) p.PaddingLeft=UDim.new(0,4) p.Parent=shopScroll end

local function buildShop(level)
	for _, c in ipairs(shopScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, crop in ipairs(GameData.GetUnlockedCrops(level or 1)) do
		local row = F({
			Size=UDim2.new(1,-8,0,76), BackgroundColor3=Color3.fromRGB(20,70,20),
			BackgroundTransparency=0.25, BorderSizePixel=0, ZIndex=22,
		}, shopScroll)
		corner(row, 8)

		L({
			Size=UDim2.new(0.48,0,0.48,0), Position=UDim2.new(0,10,0.04,0),
			BackgroundTransparency=1, Text=crop.Display,
			TextColor3=Color3.fromRGB(255,255,180), Font=Enum.Font.GothamBold,
			TextScaled=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
		}, row)

		L({
			Size=UDim2.new(0.9,0,0.44,0), Position=UDim2.new(0,10,0.52,0),
			BackgroundTransparency=1,
			Text="💰"..crop.Cost.."  ⏱"..crop.Time.."s  +"..crop.Reward.." coins  +"..crop.XP.." XP",
			TextColor3=Color3.fromRGB(190,190,190), Font=Enum.Font.Gotham,
			TextScaled=true, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=23,
		}, row)

		local function makeShopBtn(txt, xOffset, color, onClick)
			local b = B({
				Size=UDim2.new(0,84,0,36), Position=UDim2.new(1,xOffset,0.5,-18),
				BackgroundColor3=color, Text=txt, TextColor3=Color3.new(1,1,1),
				Font=Enum.Font.GothamBold, TextScaled=true, BorderSizePixel=0, ZIndex=24,
			}, row)
			corner(b, 6)
			b.MouseButton1Click:Connect(onClick)
		end

		makeShopBtn("✏ Plant",  -278, Color3.fromRGB(160,100,0), function()
			selectedCrop  = crop.Name
			selectedTool  = "Plant"
			for k,bb in pairs(toolBtns) do bb.BackgroundTransparency=0.4 end
			shopFrame.Visible = false
			showToast("Selected " .. crop.Display .. " — click an empty plot! 🌱", "Success")
		end)

		makeShopBtn("Buy ×1",  -186, Color3.fromRGB(35,140,35), function()
			RE.BuySeed:FireServer(crop.Name, 1)
		end)

		makeShopBtn("Buy ×10", -94, Color3.fromRGB(25,100,180), function()
			RE.BuySeed:FireServer(crop.Name, 10)
		end)
	end
end

shopOpenBtn.MouseButton1Click:Connect(function()
	shopFrame.Visible = not shopFrame.Visible
	if shopFrame.Visible then
		buildShop(playerData.Level)
	end
end)

-- ════════════════════════════════════════════════════════════
--  INVENTORY STRIP
-- ════════════════════════════════════════════════════════════
local invLbl = L({
	Name="Inv", Size=UDim2.new(0,240,0,38), Position=UDim2.new(0,8,0,64),
	BackgroundColor3=Color3.fromRGB(15,50,15), BackgroundTransparency=0.2,
	Text="🎒 No seeds yet", TextColor3=Color3.new(1,1,1),
	Font=Enum.Font.Gotham, TextScaled=true, BorderSizePixel=0,
}, screen)
corner(invLbl)

local function updateInv(inv)
	local parts = {}
	for name, count in pairs(inv or {}) do
		if count and count > 0 then
			parts[#parts+1] = name:sub(1,5) .. "×" .. count
		end
	end
	invLbl.Text = #parts > 0 and ("🎒 " .. table.concat(parts,"  ")) or "🎒 No seeds"
end

-- ════════════════════════════════════════════════════════════
--  HELP LABEL
-- ════════════════════════════════════════════════════════════
L({
	Size=UDim2.new(0,340,0,36), Position=UDim2.new(0,8,1,-114),
	BackgroundColor3=Color3.fromRGB(10,40,10), BackgroundTransparency=0.2,
	Text="💡 Shop → select seed → click empty plot to plant",
	TextColor3=Color3.fromRGB(200,200,200), Font=Enum.Font.Gotham,
	TextScaled=true, BorderSizePixel=0,
}, screen)

-- ════════════════════════════════════════════════════════════
--  REMOTE LISTENERS
-- ════════════════════════════════════════════════════════════

RE.Notify.OnClientEvent:Connect(function(msg, ntype)
	showToast(msg, ntype)
end)

RE.UpdatePlayerData.OnClientEvent:Connect(function(data)
	playerData = data
	coinsLbl.Text = "💰 " .. data.Coins .. " coins"
	levelLbl.Text = "⭐ Lv " .. data.Level .. "  |  "
		.. data.XP .. " / " .. GameData.XPForLevel(data.Level) .. " XP"
	updateInv(data.Inventory)
	if shopFrame.Visible then buildShop(data.Level) end
end)

RE.UpdatePlots.OnClientEvent:Connect(function(plots)
	plotsData = plots
end)

RE.PlotClicked.OnClientEvent:Connect(function(plotIndex)
	local plot = plotsData[plotIndex]
	if not plot then return end

	if not plot.Unlocked then
		RE.UnlockPlot:FireServer(plotIndex)

	elseif plot.CropName then
		if selectedTool == "Water" then
			RE.WaterCrop:FireServer(plotIndex)
		else
			RE.HarvestCrop:FireServer(plotIndex)
		end

	else
		-- Empty unlocked plot
		if selectedTool == "Plant" and selectedCrop then
			RE.PlantCrop:FireServer(plotIndex, selectedCrop)
		else
			showToast("Open 🛒 Shop, tap ✏ Plant on a seed, then click this plot!", "Info")
		end
	end
end)

print("✅ Farm UI loaded!")
