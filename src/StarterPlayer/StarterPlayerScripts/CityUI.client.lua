-- CityUI.client.lua
-- Client-side UI for the city simulation.
--
-- Elements:
--   • City Dashboard (top-right) — population, happiness, safety, power, water
--   • Mode toggle button — Farm Mode ↔ City Mode
--   • Buy Plot confirmation panel
--   • Build Menu — tabbed by category, shows cost + stats
--   • Notification toasts

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")

local localPlayer   = Players.LocalPlayer
local PlayerGui     = localPlayer:WaitForChild("PlayerGui")

local GameModules   = RS:WaitForChild("GameModules")
local BuildingData  = require(GameModules:WaitForChild("BuildingData"))

-- ── Wait for remotes ──────────────────────────────────────────────────────
-- CityManager creates its own CityRemotes folder (separate from farm Remotes)
local CityRemotes = RS:WaitForChild("CityRemotes", 30)
local function remote(name)
	return CityRemotes and CityRemotes:WaitForChild(name, 30)
end

local RE_BuyPlot        = remote("BuyPlot")
local RE_BuildOnPlot    = remote("BuildOnPlot")
local RE_UpdateStats    = remote("UpdateCityStats")
local RE_UpdateGrid     = remote("UpdateCityGrid")
local RE_Notify         = remote("CityNotify")

-- ── State ─────────────────────────────────────────────────────────────────
local currentStats      = {}
local pendingPlot       = nil   -- {row, col} waiting for confirmation
local buildPlot         = nil   -- {row, col} in build menu
local selectedCategory  = "Residential"

-- ─────────────────────────────────────────────────────────────────────────
--  UI helpers
-- ─────────────────────────────────────────────────────────────────────────
local function frame(parent, name, size, pos, bg, trans)
	local f                     = Instance.new("Frame")
	f.Name                      = name
	f.Size                      = size
	f.Position                  = pos
	f.BackgroundColor3          = bg or Color3.fromRGB(30, 30, 40)
	f.BackgroundTransparency    = trans or 0
	f.BorderSizePixel           = 0
	f.Parent                    = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,8); c.Parent = f
	return f
end

local function label(parent, name, text, size, pos, color, font, align)
	local l             = Instance.new("TextLabel")
	l.Name              = name
	l.Size              = size
	l.Position          = pos
	l.Text              = text
	l.TextColor3        = color or Color3.new(1,1,1)
	l.BackgroundTransparency = 1
	l.Font              = font or Enum.Font.Gotham
	l.TextScaled        = true
	l.TextXAlignment    = align or Enum.TextXAlignment.Left
	l.Parent            = parent
	return l
end

local function button(parent, name, text, size, pos, bg, textColor)
	local b                     = Instance.new("TextButton")
	b.Name                      = name
	b.Size                      = size
	b.Position                  = pos
	b.Text                      = text
	b.BackgroundColor3          = bg or Color3.fromRGB(60, 120, 220)
	b.TextColor3                = textColor or Color3.new(1,1,1)
	b.Font                      = Enum.Font.GothamBold
	b.TextScaled                = true
	b.BorderSizePixel           = 0
	b.Parent                    = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = b
	return b
end

local function scrollFrame(parent, name, size, pos)
	local s                     = Instance.new("ScrollingFrame")
	s.Name                      = name
	s.Size                      = size
	s.Position                  = pos
	s.BackgroundTransparency    = 1
	s.BorderSizePixel           = 0
	s.ScrollBarThickness        = 6
	s.CanvasSize                = UDim2.new(0,0,0,0)
	s.AutomaticCanvasSize       = Enum.AutomaticSize.Y
	s.Parent                    = parent
	local layout                = Instance.new("UIListLayout")
	layout.Padding              = UDim.new(0, 6)
	layout.Parent               = s
	return s
end

-- ─────────────────────────────────────────────────────────────────────────
--  Create ScreenGui
-- ─────────────────────────────────────────────────────────────────────────
local sg            = Instance.new("ScreenGui")
sg.Name             = "CityUI"
sg.ResetOnSpawn     = false
sg.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
sg.Parent           = PlayerGui

-- ─────────────────────────────────────────────────────────────────────────
--  1. CITY DASHBOARD (top-right)
-- ─────────────────────────────────────────────────────────────────────────
local dashboard = frame(sg, "Dashboard",
	UDim2.new(0, 240, 0, 200),
	UDim2.new(1, -250, 0, 10),
	Color3.fromRGB(20, 25, 35), 0.15
)

local dashTitle = label(dashboard, "Title", "🏙 City Stats",
	UDim2.new(1,-10,0,24), UDim2.new(0,5,0,5),
	Color3.fromRGB(255,220,60), Enum.Font.GothamBold, Enum.TextXAlignment.Center
)

local statLines = {
	{ key = "population", icon = "👥", label = "Population" },
	{ key = "happiness",  icon = "😊", label = "Happiness" },
	{ key = "safety",     icon = "🚔", label = "Safety" },
	{ key = "health",     icon = "❤", label = "Health" },
	{ key = "power",      icon = "⚡", label = "Power" },
	{ key = "water",      icon = "💧", label = "Water" },
}
local statLabels = {}
for i, st in ipairs(statLines) do
	local lbl = label(dashboard, st.key,
		st.icon.." "..st.label..": 0",
		UDim2.new(1,-10,0,22),
		UDim2.new(0,8,0, 30 + (i-1)*26),
		Color3.new(1,1,1), Enum.Font.Gotham
	)
	statLabels[st.key] = lbl
end

local incomeLabel = label(dashboard, "Income",
	"💰 Income: $0/min",
	UDim2.new(1,-10,0,22), UDim2.new(0,8,0,192),
	Color3.fromRGB(100,255,100), Enum.Font.GothamBold
)
dashboard.Size = UDim2.new(0,240,0,220)

local function refreshDashboard(stats)
	currentStats = stats
	for _, st in ipairs(statLines) do
		local lbl = statLabels[st.key]
		if lbl then
			local val = stats[st.key] or 0
			local color = Color3.new(1,1,1)
			if st.key == "happiness" then
				color = val >= 70 and Color3.fromRGB(100,255,100)
				     or val >= 40 and Color3.fromRGB(255,220,60)
				     or Color3.fromRGB(255,80,80)
			elseif st.key == "power" or st.key == "water" then
				color = val >= 0 and Color3.fromRGB(100,255,100) or Color3.fromRGB(255,80,80)
			end
			lbl.Text       = st.icon.." "..st.label..": "..tostring(val)
			lbl.TextColor3 = color
		end
	end
	incomeLabel.Text = "💰 Income: $"..(stats.income or 0).."/min"
end

-- ─────────────────────────────────────────────────────────────────────────
--  2. MODE TOGGLE (bottom-centre)
-- ─────────────────────────────────────────────────────────────────────────
local modeBtn = button(sg, "ModeToggle", "🏙 City Mode",
	UDim2.new(0, 160, 0, 40),
	UDim2.new(0.5, -80, 1, -110),
	Color3.fromRGB(40, 100, 200)
)
local cityModeActive = false

modeBtn.MouseButton1Click:Connect(function()
	cityModeActive = not cityModeActive
	if cityModeActive then
		modeBtn.Text                = "🌾 Farm Mode"
		modeBtn.BackgroundColor3    = Color3.fromRGB(60, 160, 60)
	else
		modeBtn.Text                = "🏙 City Mode"
		modeBtn.BackgroundColor3    = Color3.fromRGB(40, 100, 200)
	end
end)

-- ─────────────────────────────────────────────────────────────────────────
--  3. BUY PLOT PANEL
-- ─────────────────────────────────────────────────────────────────────────
local buyPanel = frame(sg, "BuyPanel",
	UDim2.new(0, 320, 0, 160),
	UDim2.new(0.5, -160, 0.5, -80),
	Color3.fromRGB(20, 30, 50)
)
buyPanel.Visible = false

label(buyPanel, "Title", "🏞 Buy City Plot",
	UDim2.new(1,-20,0,30), UDim2.new(0,10,0,10),
	Color3.fromRGB(255,220,60), Enum.Font.GothamBold, Enum.TextXAlignment.Center
)
label(buyPanel, "Desc",
	"Purchase this plot for $"..BuildingData.PlotCost.." coins\nthen build any structure on it.",
	UDim2.new(1,-20,0,50), UDim2.new(0,10,0,48),
	Color3.new(1,1,1), Enum.Font.Gotham, Enum.TextXAlignment.Center
)

local buyConfirm = button(buyPanel, "Confirm", "✅ Buy ($"..BuildingData.PlotCost..")",
	UDim2.new(0,130,0,36), UDim2.new(0,10,1,-46),
	Color3.fromRGB(60,160,60)
)
local buyCancel = button(buyPanel, "Cancel", "✗ Cancel",
	UDim2.new(0,130,0,36), UDim2.new(1,-140,1,-46),
	Color3.fromRGB(180,50,50)
)

buyConfirm.MouseButton1Click:Connect(function()
	if pendingPlot then
		RE_BuyPlot:FireServer(pendingPlot.row, pendingPlot.col, true)
		pendingPlot = nil
	end
	buyPanel.Visible = false
end)
buyCancel.MouseButton1Click:Connect(function()
	pendingPlot  = nil
	buyPanel.Visible = false
end)

-- ─────────────────────────────────────────────────────────────────────────
--  4. BUILD MENU
-- ─────────────────────────────────────────────────────────────────────────
local buildMenu = frame(sg, "BuildMenu",
	UDim2.new(0, 480, 0, 500),
	UDim2.new(0.5, -240, 0.5, -250),
	Color3.fromRGB(15, 20, 35)
)
buildMenu.Visible = false

label(buildMenu, "Title", "🏗 Build on Plot",
	UDim2.new(1,-50,0,32), UDim2.new(0,10,0,8),
	Color3.fromRGB(255,220,60), Enum.Font.GothamBold, Enum.TextXAlignment.Center
)

local closeBtn = button(buildMenu, "Close", "✕",
	UDim2.new(0,32,0,32), UDim2.new(1,-42,0,8),
	Color3.fromRGB(180,50,50)
)
closeBtn.MouseButton1Click:Connect(function()
	buildMenu.Visible = false
	buildPlot = nil
end)

-- Demolish button
local demolishBtn = button(buildMenu, "Demolish", "🗑 Demolish",
	UDim2.new(0,130,0,30), UDim2.new(1,-140,1,-40),
	Color3.fromRGB(150,60,60)
)
demolishBtn.MouseButton1Click:Connect(function()
	if buildPlot then
		RE_BuildOnPlot:FireServer(buildPlot.row, buildPlot.col, nil, true)
		buildMenu.Visible = false
		buildPlot = nil
	end
end)

-- Category tabs
local tabBar = frame(buildMenu, "TabBar",
	UDim2.new(1,-20,0,36), UDim2.new(0,10,0,48),
	Color3.fromRGB(10,15,25)
)
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0,4)
tabLayout.Parent = tabBar

local tabBtns = {}
local function selectCategory(cat)
	selectedCategory = cat
	for c, btn2 in pairs(tabBtns) do
		btn2.BackgroundColor3 = c == cat
			and Color3.fromRGB(60,120,220)
			or  Color3.fromRGB(35,40,55)
	end
	-- Rebuild building list
	local list = buildMenu:FindFirstChild("BuildList")
	if list then
		for _, child in ipairs(list:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
		for key, bd in pairs(BuildingData.Buildings) do
			if bd.category == selectedCategory then
				local row2 = frame(list, key,
					UDim2.new(1,-8,0,70), UDim2.new(0,4,0,0),
					Color3.fromRGB(30,38,55)
				)
				label(row2, "Name", bd.icon.." "..bd.displayName,
					UDim2.new(0.6,0,0,22), UDim2.new(0,8,0,4),
					Color3.fromRGB(255,220,60), Enum.Font.GothamBold
				)
				label(row2, "Cost", "Cost: $"..bd.cost,
					UDim2.new(0.6,0,0,18), UDim2.new(0,8,0,28),
					Color3.fromRGB(100,255,100)
				)
				label(row2, "Stats",
					(bd.income > 0 and "+$"..bd.income.."/m  " or "")..
					(bd.population > 0 and "👥"..bd.population.."  " or "")..
					(bd.happiness ~= 0 and "😊"..(bd.happiness>0 and "+"..bd.happiness or bd.happiness).."  " or "")..
					(bd.safety > 0 and "🚔+"..bd.safety or ""),
					UDim2.new(0.6,0,0,16), UDim2.new(0,8,0,48),
					Color3.fromRGB(180,180,180)
				)
				local buildBtn2 = button(row2, "BuildBtn", "Build",
					UDim2.new(0,80,0,44), UDim2.new(1,-90,0,13),
					Color3.fromRGB(60,160,60)
				)
				local k = key
				buildBtn2.MouseButton1Click:Connect(function()
					if buildPlot then
						RE_BuildOnPlot:FireServer(buildPlot.row, buildPlot.col, k, false)
						buildMenu.Visible = false
						buildPlot = nil
					end
				end)
			end
		end
	end
end

for _, cat in ipairs(BuildingData.Categories) do
	local shortName = cat:sub(1,4)
	local tb = button(tabBar, cat, shortName,
		UDim2.new(0,68,1,-4), UDim2.new(0,0,0,2),
		Color3.fromRGB(35,40,55)
	)
	tabBtns[cat] = tb
	local c = cat
	tb.MouseButton1Click:Connect(function() selectCategory(c) end)
end

-- Building list scroll area
local buildList = scrollFrame(buildMenu, "BuildList",
	UDim2.new(1,-20,1,-140), UDim2.new(0,10,0,92)
)

-- ─────────────────────────────────────────────────────────────────────────
--  5. NOTIFICATION TOASTS (bottom-left)
-- ─────────────────────────────────────────────────────────────────────────
local toastHolder = Instance.new("Frame")
toastHolder.Name  = "Toasts"
toastHolder.Size  = UDim2.new(0, 320, 1, 0)
toastHolder.Position = UDim2.new(0, 10, 0, 0)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = sg

local toastLayout = Instance.new("UIListLayout")
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

local function showToast(msg, color)
	local t = frame(toastHolder, "Toast",
		UDim2.new(1,-10,0,44), UDim2.new(0,0,0,0),
		color or Color3.fromRGB(30,50,80), 0.1
	)
	label(t, "Msg", msg,
		UDim2.new(1,-10,1,0), UDim2.new(0,8,0,0),
		Color3.new(1,1,1), Enum.Font.Gotham, Enum.TextXAlignment.Left
	)
	-- Fade out after 4 seconds
	task.delay(3.5, function()
		TweenService:Create(t, TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
		for _, c in ipairs(t:GetDescendants()) do
			if c:IsA("TextLabel") then
				TweenService:Create(c, TweenInfo.new(0.5), {TextTransparency=1}):Play()
			end
		end
		task.wait(0.6)
		t:Destroy()
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Remote handlers
-- ─────────────────────────────────────────────────────────────────────────
RE_UpdateStats.OnClientEvent:Connect(function(stats)
	refreshDashboard(stats)
end)

RE_BuyPlot.OnClientEvent:Connect(function(row, col)
	if not cityModeActive then return end
	pendingPlot = { row = row, col = col }
	buyPanel.Visible = true
end)

RE_BuildOnPlot.OnClientEvent:Connect(function(row, col, currentBuilding)
	if not cityModeActive then return end
	buildPlot = { row = row, col = col }
	buildMenu.Visible = true
	selectCategory(selectedCategory)
end)

RE_Notify.OnClientEvent:Connect(function(msg)
	local isGood = msg:find("✅") or msg:find("💰") or msg:find("🏗") or msg:find("Built")
	local color  = isGood
		and Color3.fromRGB(20,60,30)
		or  Color3.fromRGB(60,20,20)
	showToast(msg, color)
end)

-- ─────────────────────────────────────────────────────────────────────────
--  Init — select first category
-- ─────────────────────────────────────────────────────────────────────────
task.wait(1)
selectCategory("Residential")
showToast("🏙 City Zone unlocked! Walk east to build your city.", Color3.fromRGB(20,40,80))
