-- GameManager Server Script
-- Location: ServerScriptService > GameManager
-- Orchestrates world setup and farm plot part creation

local Players        = game:GetService("Players")
local Workspace      = game:GetService("Workspace")
local RS             = game:GetService("ReplicatedStorage")

local GameConfig     = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local Remotes        = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

-- ── World Setup ────────────────────────────────────────────────────────────

local function buildWorld()
    -- Terrain / Baseplate
    local baseplate      = Workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate.Material = Enum.Material.Grass
        baseplate.BrickColor = BrickColor.new("Bright green")
    end

    -- Sky / Atmosphere
    local lighting = game:GetService("Lighting")
    lighting.Ambient     = Color3.fromRGB(120, 120, 120)
    lighting.Brightness  = 2
    lighting.ClockTime   = 10
    lighting.FogEnd      = 1000

    local sky = Instance.new("Sky")
    sky.Parent = lighting
end

-- ── Farm Plot Parts ────────────────────────────────────────────────────────
-- Creates physical Part objects in the world that players can click.
-- Each Part is named "Plot_<id>" and stored in a Folder per player.

local farmFolders = {}  -- [player] = Folder

local COLS      = GameConfig.FarmGridCols
local ROWS      = GameConfig.FarmGridRows
local PLOT_SIZE = GameConfig.PlotSize
local PLOT_GAP  = GameConfig.PlotGap
local STRIDE    = PLOT_SIZE + PLOT_GAP

local FARM_ORIGIN = Vector3.new(0, 0.6, 0)  -- centre of the farm grid

local function plotIndexToPosition(index)
    local col = ((index - 1) % COLS)
    local row = math.floor((index - 1) / COLS)
    local offsetX = (col - (COLS - 1) / 2) * STRIDE
    local offsetZ = (row - (ROWS - 1) / 2) * STRIDE
    return FARM_ORIGIN + Vector3.new(offsetX, 0, offsetZ)
end

local function createFarmPlots(player)
    local folder = Instance.new("Folder")
    folder.Name  = player.Name .. "_Farm"
    folder.Parent = Workspace

    local total = COLS * ROWS

    for i = 1, total do
        local part = Instance.new("Part")
        part.Name        = "Plot_" .. i
        part.Size        = Vector3.new(PLOT_SIZE, 0.4, PLOT_SIZE)
        part.Position    = plotIndexToPosition(i)
        part.Anchored    = true
        part.Material    = Enum.Material.Ground
        part.BrickColor  = BrickColor.new("Reddish brown")

        -- Locked indicator initially (overridden when data loads)
        if i > GameConfig.StartingUnlockedPlots then
            part.BrickColor = BrickColor.new("Dark grey")
            local billboardGui = Instance.new("BillboardGui")
            billboardGui.Name        = "LockGui"
            billboardGui.Size        = UDim2.new(0, 80, 0, 40)
            billboardGui.StudsOffset = Vector3.new(0, 2, 0)
            billboardGui.Parent      = part

            local label = Instance.new("TextLabel")
            label.Size            = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Text            = "Locked"
            label.TextColor3      = Color3.fromRGB(255,255,255)
            label.Font            = Enum.Font.GothamBold
            label.TextScaled      = true
            label.Parent          = billboardGui
        end

        -- ClickDetector for interaction
        local clickDetector = Instance.new("ClickDetector")
        clickDetector.MaxActivationDistance = 20
        clickDetector.Name   = "ClickDetector"
        clickDetector.Parent = part

        -- Crop indicator (SurfaceGui)
        local surfGui = Instance.new("SurfaceGui")
        surfGui.Name         = "CropGui"
        surfGui.Face         = Enum.NormalId.Top
        surfGui.CanvasSize   = Vector2.new(200, 200)
        surfGui.Parent       = part

        local cropLabel = Instance.new("TextLabel")
        cropLabel.Name               = "CropLabel"
        cropLabel.Size               = UDim2.new(1, 0, 1, 0)
        cropLabel.BackgroundTransparency = 1
        cropLabel.Text               = ""
        cropLabel.TextColor3         = Color3.fromRGB(255,255,255)
        cropLabel.Font               = Enum.Font.GothamBold
        cropLabel.TextScaled         = true
        cropLabel.Parent             = surfGui

        -- Wire up click → fire remote to client (client decides what action to take)
        local plotId = i
        clickDetector.MouseClick:Connect(function(clickingPlayer)
            -- Fire a remote to tell the client which plot was clicked
            Remotes.UpdatePlots:FireClient(clickingPlayer, {ClickedPlot = plotId})
        end)

        part.Parent = folder
    end

    farmFolders[player] = folder
    return folder
end

local function removeFarmPlots(player)
    if farmFolders[player] then
        farmFolders[player]:Destroy()
        farmFolders[player] = nil
    end
end

-- ── Visual Update (driven by data sent from server to client → client handles visuals)
-- The server also updates parts for other players viewing the farm (spectating etc.)
-- For simplicity we keep the visual updates on the client side.

-- ── Players ────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        -- Teleport player to their farm area (offset by UserId for multiple farms)
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        humanoidRootPart.CFrame = CFrame.new(FARM_ORIGIN + Vector3.new(0, 5, -20))
    end)

    -- Create farm plots after a short delay (data loads async)
    task.delay(1, function()
        createFarmPlots(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    removeFarmPlots(player)
end)

-- ── Boot ───────────────────────────────────────────────────────────────────

buildWorld()

-- Ambient background music (plays for all clients via a Sound in Workspace)
local bgMusic = Instance.new("Sound")
bgMusic.Name       = "BackgroundMusic"
bgMusic.SoundId    = GameConfig.Sounds.Background
bgMusic.Volume     = 0.3
bgMusic.Looped     = true
bgMusic.RollOffMaxDistance = 1e6
bgMusic.Parent     = Workspace
bgMusic:Play()

print("[Adam And Eshaals Farm] Server started — v" .. GameConfig.Version)
