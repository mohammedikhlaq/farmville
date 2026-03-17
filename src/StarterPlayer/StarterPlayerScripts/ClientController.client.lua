-- ClientController LocalScript
-- Location: StarterPlayer > StarterPlayerScripts > ClientController
-- Handles client-side farm interaction, sound playback, and plot visuals

local Players       = game:GetService("Players")
local RS            = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")
local SoundService  = game:GetService("SoundService")
local UserInput     = game:GetService("UserInputService")

local localPlayer   = Players.LocalPlayer
local GameConfig    = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local CropData      = require(RS:WaitForChild("GameModules"):WaitForChild("CropData"))
local Remotes       = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

-- ── State ──────────────────────────────────────────────────────────────────

local playerData  = nil   -- cached copy of server data
local plotsData   = nil   -- cached copy of plots
local selectedTool = "Harvest"  -- "Harvest" | "Water" | "Plant" | "Unlock"
local selectedCrop = nil  -- crop name for planting

-- ── Farm folder reference ──────────────────────────────────────────────────

local farmFolder
local function getFarmFolder()
    if farmFolder and farmFolder.Parent then return farmFolder end
    farmFolder = workspace:FindFirstChild(localPlayer.Name .. "_Farm")
    return farmFolder
end

-- ── Plot Visual Update ─────────────────────────────────────────────────────

local STAGE_EMOJIS = { "Seedling", "Growing", "Almost", "Ready!" }

local function getProgressStage(progress)
    if progress < 0.25 then return 1
    elseif progress < 0.5 then return 2
    elseif progress < 1   then return 3
    else return 4 end
end

local function updatePlotVisual(plotPart, plotState)
    if not plotPart then return end

    local cropLabel = plotPart:FindFirstChild("CropGui")
                      and plotPart.CropGui:FindFirstChild("CropLabel")
    local lockGui   = plotPart:FindFirstChild("LockGui")

    if not plotState.Unlocked then
        plotPart.BrickColor = BrickColor.new("Dark grey")
        if lockGui then lockGui.Enabled = true end
        if cropLabel then cropLabel.Text = "" end
        return
    end

    if lockGui then lockGui.Enabled = false end

    if plotState.IsWilted then
        plotPart.BrickColor = BrickColor.new("Olive")
        if cropLabel then cropLabel.Text = "Wilted" end
        return
    end

    if not plotState.CropType then
        plotPart.BrickColor = BrickColor.new("Reddish brown")
        if cropLabel then cropLabel.Text = "" end
        return
    end

    -- Growing / ready
    local crop     = CropData.GetCrop(plotState.CropType)
    local elapsed  = os.time() - (plotState.PlantedAt or os.time())
    local duration = crop and crop.GrowthTime or 60
    if plotState.WateredAt then
        duration = duration * (1 - GameConfig.WaterGrowthBoost)
    end
    local progress = math.min(elapsed / duration, 1)

    if progress >= 1 then
        plotPart.BrickColor = BrickColor.new("Bright green")
        if cropLabel then
            cropLabel.Text = (crop and crop.DisplayName or plotState.CropType) .. "\nReady!"
        end
    else
        local stage = getProgressStage(progress)
        local stageText = STAGE_EMOJIS[stage]
        plotPart.BrickColor = BrickColor.new("Reddish brown")
        if cropLabel then
            cropLabel.Text = stageText .. " " .. (crop and crop.DisplayName or plotState.CropType)
                             .. "\n" .. math.floor(progress * 100) .. "%"
        end
    end

    if plotState.WateredAt then
        plotPart.Material = Enum.Material.SmoothPlastic
    else
        plotPart.Material = Enum.Material.Ground
    end
end

local function refreshAllPlotVisuals()
    if not plotsData then return end
    local folder = getFarmFolder()
    if not folder then return end

    for plotId, state in pairs(plotsData) do
        local part = folder:FindFirstChild("Plot_" .. plotId)
        if part then
            updatePlotVisual(part, state)
        end
    end
end

-- ── Continuous Growth Animation ────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(5)
        refreshAllPlotVisuals()
    end
end)

-- ── Sound Playback ─────────────────────────────────────────────────────────

local soundCache = {}
local function playSound(key)
    local id = GameConfig.Sounds[key]
    if not id then return end
    local sound = soundCache[key]
    if not sound then
        sound = Instance.new("Sound")
        sound.SoundId = id
        sound.Parent  = SoundService
        soundCache[key] = sound
    end
    sound:Play()
end

-- ── Plot Click Handling ────────────────────────────────────────────────────

local function onPlotClicked(plotId)
    if not plotsData then return end
    local state = plotsData[tostring(plotId)]
    if not state then return end

    if not state.Unlocked then
        -- Try to unlock
        Remotes.UnlockPlot:FireServer(plotId)
        return
    end

    if state.IsWilted then
        -- Harvest to clear
        Remotes.HarvestCrop:FireServer(plotId)
        return
    end

    if state.CropType then
        -- Crop on plot: water or harvest
        if selectedTool == "Water" then
            Remotes.WaterCrop:FireServer(plotId)
        else
            Remotes.HarvestCrop:FireServer(plotId)
        end
    else
        -- Empty plot: plant
        if selectedCrop then
            Remotes.PlantCrop:FireServer(plotId, selectedCrop)
        else
            -- Open the seed shop (signal to UI)
            local FarmUI = localPlayer.PlayerGui:FindFirstChild("FarmUI")
            if FarmUI then
                local shopFrame = FarmUI:FindFirstChild("ShopFrame", true)
                if shopFrame then shopFrame.Visible = true end
            end
        end
    end
end

-- ── Remote Listeners ──────────────────────────────────────────────────────

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    playerData = data
    -- Propagate to UI script via BindableEvent-like approach using shared table
    _G.PlayerData = data
end)

Remotes.UpdatePlots.OnClientEvent:Connect(function(data)
    -- Check for plot-click signal
    if data.ClickedPlot then
        onPlotClicked(data.ClickedPlot)
        return
    end
    plotsData = data
    _G.PlotsData = data
    refreshAllPlotVisuals()
end)

Remotes.PlaySound.OnClientEvent:Connect(function(soundKey)
    playSound(soundKey)
end)

-- ── Expose tool selection to FarmUI ───────────────────────────────────────

_G.SetTool = function(tool)
    selectedTool = tool
end

_G.SetSelectedCrop = function(cropName)
    selectedCrop  = cropName
    selectedTool  = "Plant"
end

-- ── Request initial data ───────────────────────────────────────────────────

task.delay(2, function()
    local data = Remotes.RequestData:InvokeServer()
    if data then
        playerData = data
        _G.PlayerData = data
        plotsData  = data.Plots
        _G.PlotsData = data.Plots
        refreshAllPlotVisuals()
    end
end)
