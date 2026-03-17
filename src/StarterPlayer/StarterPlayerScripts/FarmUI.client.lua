-- FarmUI LocalScript
-- Location: StarterPlayer > StarterPlayerScripts > FarmUI
-- Builds and manages all GUI elements for Adam And Eshaals Farm

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer  = Players.LocalPlayer
local playerGui    = localPlayer:WaitForChild("PlayerGui")

local GameConfig   = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local CropData     = require(RS:WaitForChild("GameModules"):WaitForChild("CropData"))
local AnimalData   = require(RS:WaitForChild("GameModules"):WaitForChild("AnimalData"))
local Remotes      = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

-- ══════════════════════════════════════════════════════════════════════════
--  HELPER FUNCTIONS
-- ══════════════════════════════════════════════════════════════════════════

local function makeInstance(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    if parent then obj.Parent = parent end
    return obj
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function addPadding(parent, px)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, px)
    p.PaddingBottom = UDim.new(0, px)
    p.PaddingLeft   = UDim.new(0, px)
    p.PaddingRight  = UDim.new(0, px)
    p.Parent = parent
    return p
end

-- ══════════════════════════════════════════════════════════════════════════
--  ROOT SCREENGUI
-- ══════════════════════════════════════════════════════════════════════════

local screenGui = makeInstance("ScreenGui", {
    Name             = "FarmUI",
    ResetOnSpawn     = false,
    ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
}, playerGui)

-- ══════════════════════════════════════════════════════════════════════════
--  TOP BAR  (Coins | XP | Level)
-- ══════════════════════════════════════════════════════════════════════════

local topBar = makeInstance("Frame", {
    Name             = "TopBar",
    Size             = UDim2.new(1, 0, 0, 52),
    Position         = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(30, 80, 30),
    BackgroundTransparency = 0.1,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(topBar, 0)

-- Title label
makeInstance("TextLabel", {
    Name             = "TitleLabel",
    Size             = UDim2.new(0, 260, 1, 0),
    Position         = UDim2.new(0.5, -130, 0, 0),
    BackgroundTransparency = 1,
    Text             = "Adam And Eshaals Farm",
    TextColor3       = Color3.fromRGB(255, 230, 50),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
}, topBar)

-- Coins label
local coinsLabel = makeInstance("TextLabel", {
    Name             = "CoinsLabel",
    Size             = UDim2.new(0, 160, 1, -8),
    Position         = UDim2.new(0, 10, 0, 4),
    BackgroundColor3 = Color3.fromRGB(50, 40, 0),
    BackgroundTransparency = 0.3,
    Text             = "Coins: 0",
    TextColor3       = Color3.fromRGB(255, 220, 0),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
}, topBar)
addCorner(coinsLabel)

-- XP / Level label
local xpLabel = makeInstance("TextLabel", {
    Name             = "XPLabel",
    Size             = UDim2.new(0, 200, 1, -8),
    Position         = UDim2.new(1, -210, 0, 4),
    BackgroundColor3 = Color3.fromRGB(0, 30, 60),
    BackgroundTransparency = 0.3,
    Text             = "Level 1  |  0 XP",
    TextColor3       = Color3.fromRGB(100, 200, 255),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
}, topBar)
addCorner(xpLabel)

-- ══════════════════════════════════════════════════════════════════════════
--  TOOL BAR  (bottom)
-- ══════════════════════════════════════════════════════════════════════════

local toolBar = makeInstance("Frame", {
    Name             = "ToolBar",
    Size             = UDim2.new(0, 340, 0, 60),
    Position         = UDim2.new(0.5, -170, 1, -72),
    BackgroundColor3 = Color3.fromRGB(30, 60, 30),
    BackgroundTransparency = 0.1,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(toolBar, 12)

local toolLayout = makeInstance("UIListLayout", {
    FillDirection    = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment   = Enum.VerticalAlignment.Center,
    Padding          = UDim.new(0, 8),
}, toolBar)

local function makeToolBtn(label, toolName, color)
    local btn = makeInstance("TextButton", {
        Name             = label,
        Size             = UDim2.new(0, 90, 0, 44),
        BackgroundColor3 = color,
        Text             = label,
        TextColor3       = Color3.fromRGB(255,255,255),
        Font             = Enum.Font.GothamBold,
        TextScaled       = true,
        BorderSizePixel  = 0,
    }, toolBar)
    addCorner(btn, 8)
    btn.MouseButton1Click:Connect(function()
        if _G.SetTool then _G.SetTool(toolName) end
        -- Highlight active
        for _, child in ipairs(toolBar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundTransparency = (child == btn) and 0 or 0.35
            end
        end
    end)
    return btn
end

makeToolBtn("Harvest",   "Harvest", Color3.fromRGB(200,120, 0))
makeToolBtn("Water",     "Water",   Color3.fromRGB( 30,120,200))
makeToolBtn("Shop",      "Shop",    Color3.fromRGB( 80,160, 80))

-- Shop button opens shop
local shopBtn = toolBar:FindFirstChild("Shop")
if shopBtn then
    shopBtn.MouseButton1Click:Connect(function()
        local shopFrame = screenGui:FindFirstChild("ShopFrame")
        if shopFrame then
            shopFrame.Visible = not shopFrame.Visible
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
--  SHOP FRAME
-- ══════════════════════════════════════════════════════════════════════════

local shopFrame = makeInstance("Frame", {
    Name             = "ShopFrame",
    Size             = UDim2.new(0, 480, 0, 520),
    Position         = UDim2.new(0.5, -240, 0.5, -260),
    BackgroundColor3 = Color3.fromRGB(20, 60, 20),
    BackgroundTransparency = 0.05,
    Visible          = false,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(shopFrame, 14)

-- Shop title
makeInstance("TextLabel", {
    Size             = UDim2.new(1, -50, 0, 44),
    Position         = UDim2.new(0, 10, 0, 4),
    BackgroundTransparency = 1,
    Text             = "Seed Shop",
    TextColor3       = Color3.fromRGB(255,230, 50),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
}, shopFrame)

-- Close button
local closeShopBtn = makeInstance("TextButton", {
    Size             = UDim2.new(0, 40, 0, 40),
    Position         = UDim2.new(1, -46, 0, 4),
    BackgroundColor3 = Color3.fromRGB(180, 40, 40),
    Text             = "X",
    TextColor3       = Color3.fromRGB(255,255,255),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
    BorderSizePixel  = 0,
}, shopFrame)
addCorner(closeShopBtn, 8)
closeShopBtn.MouseButton1Click:Connect(function()
    shopFrame.Visible = false
end)

-- Shop scroll frame
local shopScroll = makeInstance("ScrollingFrame", {
    Name             = "ShopScroll",
    Size             = UDim2.new(1, -16, 1, -58),
    Position         = UDim2.new(0, 8, 0, 54),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    CanvasSize       = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, shopFrame)

local shopList = makeInstance("UIListLayout", {
    SortOrder        = Enum.SortOrder.LayoutOrder,
    Padding          = UDim.new(0, 6),
}, shopScroll)
addPadding(shopScroll, 4)

local function buildShopItems(level)
    -- Clear existing items
    for _, child in ipairs(shopScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local crops = CropData.GetUnlockedCrops(level or 1)

    for _, crop in ipairs(crops) do
        local row = makeInstance("Frame", {
            Size             = UDim2.new(1, -8, 0, 68),
            BackgroundColor3 = Color3.fromRGB(30, 80, 30),
            BackgroundTransparency = 0.3,
            BorderSizePixel  = 0,
        }, shopScroll)
        addCorner(row, 8)

        -- Crop name
        makeInstance("TextLabel", {
            Size             = UDim2.new(0, 160, 0.5, 0),
            Position         = UDim2.new(0, 10, 0, 4),
            BackgroundTransparency = 1,
            Text             = crop.DisplayName,
            TextColor3       = Color3.fromRGB(255,255,200),
            Font             = Enum.Font.GothamBold,
            TextScaled       = true,
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, row)

        -- Price info
        makeInstance("TextLabel", {
            Size             = UDim2.new(0, 200, 0.5, 0),
            Position         = UDim2.new(0, 10, 0.5, 0),
            BackgroundTransparency = 1,
            Text             = "Cost: " .. crop.SeedCost .. " | XP: +" .. crop.XPReward .. " | Earn: +" .. crop.HarvestReward,
            TextColor3       = Color3.fromRGB(200,200,200),
            Font             = Enum.Font.Gotham,
            TextScaled       = true,
            TextXAlignment   = Enum.TextXAlignment.Left,
        }, row)

        -- Buy 1 button
        local buyBtn = makeInstance("TextButton", {
            Size             = UDim2.new(0, 80, 0, 36),
            Position         = UDim2.new(1, -180, 0.5, -18),
            BackgroundColor3 = Color3.fromRGB(50,160,50),
            Text             = "Buy x1",
            TextColor3       = Color3.fromRGB(255,255,255),
            Font             = Enum.Font.GothamBold,
            TextScaled       = true,
            BorderSizePixel  = 0,
        }, row)
        addCorner(buyBtn, 6)
        buyBtn.MouseButton1Click:Connect(function()
            Remotes.BuySeed:FireServer(crop.Name, 1)
        end)

        -- Buy 10 button
        local buy10Btn = makeInstance("TextButton", {
            Size             = UDim2.new(0, 80, 0, 36),
            Position         = UDim2.new(1, -90, 0.5, -18),
            BackgroundColor3 = Color3.fromRGB(30,120,180),
            Text             = "Buy x10",
            TextColor3       = Color3.fromRGB(255,255,255),
            Font             = Enum.Font.GothamBold,
            TextScaled       = true,
            BorderSizePixel  = 0,
        }, row)
        addCorner(buy10Btn, 6)
        buy10Btn.MouseButton1Click:Connect(function()
            Remotes.BuySeed:FireServer(crop.Name, 10)
        end)

        -- Select to plant button
        local selectBtn = makeInstance("TextButton", {
            Size             = UDim2.new(0, 70, 0, 36),
            Position         = UDim2.new(1, -260, 0.5, -18),
            BackgroundColor3 = Color3.fromRGB(180,120,0),
            Text             = "Plant",
            TextColor3       = Color3.fromRGB(255,255,255),
            Font             = Enum.Font.GothamBold,
            TextScaled       = true,
            BorderSizePixel  = 0,
        }, row)
        addCorner(selectBtn, 6)
        selectBtn.MouseButton1Click:Connect(function()
            if _G.SetSelectedCrop then _G.SetSelectedCrop(crop.Name) end
            shopFrame.Visible = false
            -- Quick local toast
            local toastLabel = screenGui:FindFirstChild("Toast")
            if toastLabel then
                toastLabel.Text    = "Selected: " .. crop.DisplayName .. " — click an empty plot!"
                toastLabel.Visible = true
                task.delay(3, function() toastLabel.Visible = false end)
            end
        end)
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  INVENTORY PANEL  (right side)
-- ══════════════════════════════════════════════════════════════════════════

local invPanel = makeInstance("Frame", {
    Name             = "InventoryPanel",
    Size             = UDim2.new(0, 180, 0, 300),
    Position         = UDim2.new(1, -190, 0.5, -150),
    BackgroundColor3 = Color3.fromRGB(20, 50, 20),
    BackgroundTransparency = 0.1,
    Visible          = false,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(invPanel, 10)

makeInstance("TextLabel", {
    Size             = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    Text             = "Inventory",
    TextColor3       = Color3.fromRGB(255,230,50),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
}, invPanel)

local invScroll = makeInstance("ScrollingFrame", {
    Size             = UDim2.new(1, -8, 1, -44),
    Position         = UDim2.new(0, 4, 0, 40),
    BackgroundTransparency = 1,
    ScrollBarThickness = 4,
    CanvasSize       = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, invPanel)

makeInstance("UIListLayout", {
    Padding  = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, invScroll)

-- Toggle inventory
local invToggle = makeInstance("TextButton", {
    Size             = UDim2.new(0, 44, 0, 44),
    Position         = UDim2.new(1, -54, 0, 60),
    BackgroundColor3 = Color3.fromRGB(20, 100, 20),
    Text             = "Inv",
    TextScaled       = true,
    Font             = Enum.Font.GothamBold,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(invToggle, 10)
invToggle.MouseButton1Click:Connect(function()
    invPanel.Visible = not invPanel.Visible
end)

local function updateInventoryUI(inventory)
    -- Clear
    for _, child in ipairs(invScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    -- Populate
    for itemName, count in pairs(inventory or {}) do
        if count > 0 then
            local row = makeInstance("Frame", {
                Size             = UDim2.new(1, -4, 0, 32),
                BackgroundTransparency = 0.6,
                BackgroundColor3 = Color3.fromRGB(50,80,50),
            }, invScroll)
            addCorner(row, 4)
            makeInstance("TextLabel", {
                Size             = UDim2.new(1, -4, 1, 0),
                Position         = UDim2.new(0, 4, 0, 0),
                BackgroundTransparency = 1,
                Text             = itemName .. ": x" .. count,
                TextColor3       = Color3.fromRGB(220,220,220),
                Font             = Enum.Font.Gotham,
                TextScaled       = true,
                TextXAlignment   = Enum.TextXAlignment.Left,
            }, row)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
--  TOAST NOTIFICATION
-- ══════════════════════════════════════════════════════════════════════════

local toast = makeInstance("TextLabel", {
    Name             = "Toast",
    Size             = UDim2.new(0, 420, 0, 50),
    Position         = UDim2.new(0.5, -210, 0, 60),
    BackgroundColor3 = Color3.fromRGB(20, 60, 20),
    BackgroundTransparency = 0.1,
    Text             = "",
    TextColor3       = Color3.fromRGB(255,255,255),
    Font             = Enum.Font.GothamBold,
    TextScaled       = true,
    Visible          = false,
    BorderSizePixel  = 0,
}, screenGui)
addCorner(toast, 10)

local function showToast(message, notifType)
    local colors = {
        Success  = Color3.fromRGB(20, 100, 20),
        Error    = Color3.fromRGB(120, 20, 20),
        LevelUp  = Color3.fromRGB(100, 60, 0),
        Info     = Color3.fromRGB(20, 40, 100),
    }
    toast.BackgroundColor3 = colors[notifType] or colors.Info
    toast.Text    = message
    toast.Visible = true

    -- Slide in
    toast.Position = UDim2.new(0.5, -210, 0, 56)
    TweenService:Create(toast, TweenInfo.new(0.25), {
        Position = UDim2.new(0.5, -210, 0, 66)
    }):Play()

    task.delay(GameConfig.NotificationDuration, function()
        TweenService:Create(toast, TweenInfo.new(0.25), {
            Position = UDim2.new(0.5, -210, 0, 56),
        }):Play()
        task.wait(0.3)
        toast.Visible = false
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
--  REMOTE LISTENERS
-- ══════════════════════════════════════════════════════════════════════════

Remotes.ShowNotification.OnClientEvent:Connect(function(message, notifType)
    showToast(message, notifType)
end)

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    -- Update top bar
    coinsLabel.Text = "Coins: " .. data.Coins
    xpLabel.Text    = "Lv " .. data.Level .. "  |  "
                      .. data.XP .. "/" .. GameConfig.XPForLevel(data.Level) .. " XP"
    -- Update shop for level
    buildShopItems(data.Level)
    -- Update inventory
    updateInventoryUI(data.Inventory)
end)

-- ══════════════════════════════════════════════════════════════════════════
--  BOOT
-- ══════════════════════════════════════════════════════════════════════════

buildShopItems(1)  -- initial build with level 1 crops
