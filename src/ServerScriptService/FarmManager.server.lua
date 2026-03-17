-- FarmManager Server Script
-- Location: ServerScriptService > FarmManager
-- Manages farm plots: planting, growing, watering, harvesting, wilting

local Players   = game:GetService("Players")
local RS        = game:GetService("ReplicatedStorage")

local GameConfig = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local CropData   = require(RS:WaitForChild("GameModules"):WaitForChild("CropData"))
local Remotes    = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

-- Wait for DataManager to be ready
local DataManager
task.spawn(function()
    repeat task.wait(0.1) until _G.DataManager
    DataManager = _G.DataManager
end)
repeat task.wait(0.1) until DataManager

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getGrowthProgress(plotData)
    if not plotData.CropType or not plotData.PlantedAt then return 0 end
    local crop     = CropData.GetCrop(plotData.CropType)
    if not crop then return 0 end
    local elapsed  = os.time() - plotData.PlantedAt
    local duration = crop.GrowthTime
    if plotData.WateredAt then
        duration = duration * (1 - GameConfig.WaterGrowthBoost)
    end
    return math.min(elapsed / duration, 1)
end

local function isReady(plotData)
    return getGrowthProgress(plotData) >= 1
end

local function isWilted(plotData)
    if not plotData.CropType or not plotData.PlantedAt then return false end
    local crop     = CropData.GetCrop(plotData.CropType)
    if not crop then return false end
    local duration = crop.GrowthTime
    if plotData.WateredAt then
        duration = duration * (1 - GameConfig.WaterGrowthBoost)
    end
    local wiltTime  = duration * (1 + GameConfig.WiltTimeMultiplier)
    local elapsed   = os.time() - plotData.PlantedAt
    return elapsed >= wiltTime
end

-- ── Actions ────────────────────────────────────────────────────────────────

local function plantCrop(player, plotId, cropName)
    local data = DataManager.Get(player)
    if not data then return end

    local plot = data.Plots[tostring(plotId)]
    if not plot then
        Remotes.ShowNotification:FireClient(player, "Invalid plot.", "Error")
        return
    end
    if not plot.Unlocked then
        Remotes.ShowNotification:FireClient(player, "Unlock this plot first!", "Error")
        return
    end
    if plot.CropType then
        Remotes.ShowNotification:FireClient(player, "This plot already has a crop.", "Error")
        return
    end

    local crop = CropData.GetCrop(cropName)
    if not crop then
        Remotes.ShowNotification:FireClient(player, "Unknown crop.", "Error")
        return
    end
    if data.Level < crop.UnlockLevel then
        Remotes.ShowNotification:FireClient(
            player,
            crop.DisplayName .. " requires Level " .. crop.UnlockLevel .. ".",
            "Error"
        )
        return
    end

    -- Check inventory
    local invCount = data.Inventory[cropName] or 0
    if invCount < 1 then
        Remotes.ShowNotification:FireClient(player, "No " .. crop.DisplayName .. " seeds! Buy some first.", "Error")
        return
    end

    -- Deduct seed
    DataManager.RemoveInventory(player, cropName, 1)

    -- Plant
    plot.CropType  = cropName
    plot.PlantedAt = os.time()
    plot.WateredAt = nil
    plot.IsWilted  = false

    Remotes.UpdatePlots:FireClient(player, data.Plots)
    Remotes.PlaySound:FireClient(player, "Plant")
    Remotes.ShowNotification:FireClient(
        player,
        crop.DisplayName .. " planted! Check back in " .. math.ceil(crop.GrowthTime/60) .. " min.",
        "Success"
    )
end

local function harvestCrop(player, plotId)
    local data = DataManager.Get(player)
    if not data then return end

    local plot = data.Plots[tostring(plotId)]
    if not plot or not plot.CropType then
        Remotes.ShowNotification:FireClient(player, "Nothing to harvest here.", "Error")
        return
    end

    if isWilted(plot) then
        -- Wilted – clear the plot, no reward
        plot.CropType  = nil
        plot.PlantedAt = nil
        plot.WateredAt = nil
        plot.IsWilted  = false
        Remotes.UpdatePlots:FireClient(player, data.Plots)
        Remotes.ShowNotification:FireClient(player, "The crop wilted! Plant a new one.", "Error")
        return
    end

    if not isReady(plot) then
        local progress = math.floor(getGrowthProgress(plot) * 100)
        Remotes.ShowNotification:FireClient(
            player,
            "Crop is " .. progress .. "% grown. Come back soon!",
            "Info"
        )
        return
    end

    local crop = CropData.GetCrop(plot.CropType)
    if not crop then return end

    -- Reward
    DataManager.AddCoins(player, crop.HarvestReward)
    DataManager.AddXP(player, crop.XPReward)
    data.TotalHarvests = data.TotalHarvests + 1

    -- Clear plot
    plot.CropType  = nil
    plot.PlantedAt = nil
    plot.WateredAt = nil
    plot.IsWilted  = false

    Remotes.UpdatePlots:FireClient(player, data.Plots)
    Remotes.PlaySound:FireClient(player, "Harvest")
    Remotes.ShowNotification:FireClient(
        player,
        "Harvested " .. crop.DisplayName .. "! +" .. crop.HarvestReward .. " coins, +" .. crop.XPReward .. " XP",
        "Success"
    )
end

local function waterCrop(player, plotId)
    local data = DataManager.Get(player)
    if not data then return end

    local plot = data.Plots[tostring(plotId)]
    if not plot or not plot.CropType then
        Remotes.ShowNotification:FireClient(player, "Nothing to water here.", "Error")
        return
    end
    if plot.WateredAt then
        Remotes.ShowNotification:FireClient(player, "Already watered!", "Info")
        return
    end
    if isReady(plot) then
        Remotes.ShowNotification:FireClient(player, "Crop is ready to harvest!", "Info")
        return
    end

    plot.WateredAt = os.time()
    Remotes.UpdatePlots:FireClient(player, data.Plots)
    Remotes.PlaySound:FireClient(player, "Water")
    Remotes.ShowNotification:FireClient(player, "Crop watered! Grows 50% faster.", "Success")
end

local function unlockPlot(player, plotId)
    local data = DataManager.Get(player)
    if not data then return end

    local id   = tonumber(plotId)
    local plot = data.Plots[tostring(id)]
    if not plot then return end
    if plot.Unlocked then
        Remotes.ShowNotification:FireClient(player, "Plot already unlocked.", "Info")
        return
    end

    local cost = GameConfig.PlotUnlockCosts[id]
    if not cost then
        Remotes.ShowNotification:FireClient(player, "This plot cannot be unlocked.", "Error")
        return
    end
    if data.Coins < cost then
        Remotes.ShowNotification:FireClient(
            player,
            "Need " .. cost .. " coins (you have " .. data.Coins .. ").",
            "Error"
        )
        return
    end

    DataManager.AddCoins(player, -cost)
    plot.Unlocked = true

    Remotes.UpdatePlots:FireClient(player, data.Plots)
    Remotes.PlaySound:FireClient(player, "Coins")
    Remotes.ShowNotification:FireClient(player, "New plot unlocked!", "Success")
end

-- ── Wilt checker loop ──────────────────────────────────────────────────────

task.spawn(function()
    while true do
        task.wait(10)  -- check every 10 seconds
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataManager.Get(player)
            if data then
                local changed = false
                for _, plot in pairs(data.Plots) do
                    if plot.CropType and not plot.IsWilted and isWilted(plot) then
                        plot.IsWilted = true
                        changed = true
                    end
                end
                if changed then
                    Remotes.UpdatePlots:FireClient(player, data.Plots)
                    Remotes.ShowNotification:FireClient(
                        player,
                        "Some crops have wilted! Harvest them to clear the plots.",
                        "Error"
                    )
                end
            end
        end
    end
end)

-- ── Remote connections ─────────────────────────────────────────────────────

Remotes.PlantCrop:Connect(function(player, plotId, cropName)
    plantCrop(player, plotId, cropName)
end)

Remotes.HarvestCrop:Connect(function(player, plotId)
    harvestCrop(player, plotId)
end)

Remotes.WaterCrop:Connect(function(player, plotId)
    waterCrop(player, plotId)
end)

Remotes.UnlockPlot:Connect(function(player, plotId)
    unlockPlot(player, plotId)
end)
