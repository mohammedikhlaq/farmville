-- ShopManager Server Script
-- Location: ServerScriptService > ShopManager
-- Handles purchasing seeds and animals

local RS = game:GetService("ReplicatedStorage")

local GameConfig  = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local CropData    = require(RS:WaitForChild("GameModules"):WaitForChild("CropData"))
local AnimalData  = require(RS:WaitForChild("GameModules"):WaitForChild("AnimalData"))
local Remotes     = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

local DataManager
task.spawn(function()
    repeat task.wait(0.1) until _G.DataManager
    DataManager = _G.DataManager
end)
repeat task.wait(0.1) until DataManager

-- ── Buy Seeds ──────────────────────────────────────────────────────────────

Remotes.BuySeed:Connect(function(player, cropName, amount)
    amount = math.max(1, math.min(amount or 1, 100))  -- clamp 1–100
    local data = DataManager.Get(player)
    if not data then return end

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

    local totalCost = crop.SeedCost * amount
    if data.Coins < totalCost then
        Remotes.ShowNotification:FireClient(
            player,
            "Not enough coins! Need " .. totalCost .. " (you have " .. data.Coins .. ").",
            "Error"
        )
        return
    end

    DataManager.AddCoins(player, -totalCost)
    DataManager.AddInventory(player, cropName, amount)

    Remotes.PlaySound:FireClient(player, "Coins")
    Remotes.ShowNotification:FireClient(
        player,
        "Bought " .. amount .. "x " .. crop.DisplayName .. " seeds for " .. totalCost .. " coins.",
        "Success"
    )
end)

-- ── Buy Animal ─────────────────────────────────────────────────────────────

Remotes.BuyAnimal:Connect(function(player, animalName)
    local data = DataManager.Get(player)
    if not data then return end

    local animal = AnimalData.GetAnimal(animalName)
    if not animal then
        Remotes.ShowNotification:FireClient(player, "Unknown animal.", "Error")
        return
    end
    if data.Level < animal.UnlockLevel then
        Remotes.ShowNotification:FireClient(
            player,
            animal.DisplayName .. " requires Level " .. animal.UnlockLevel .. ".",
            "Error"
        )
        return
    end
    if data.Coins < animal.Cost then
        Remotes.ShowNotification:FireClient(
            player,
            "Not enough coins! Need " .. animal.Cost .. " (you have " .. data.Coins .. ").",
            "Error"
        )
        return
    end

    DataManager.AddCoins(player, -animal.Cost)

    -- Add animal to player data with unique ID
    local uuid = player.UserId .. "_" .. animalName .. "_" .. os.time()
    data.Animals[uuid] = {
        AnimalType  = animalName,
        LastCollect = os.time(),
        LastFed     = nil,
    }

    Remotes.ShowNotification:FireClient(
        player,
        animal.DisplayName .. " added to your farm!",
        "Success"
    )
    Remotes.UpdatePlayerData:FireClient(player, data)
end)

-- ── Collect Animal Product ─────────────────────────────────────────────────

Remotes.CollectAnimal:Connect(function(player, animalId)
    local data = DataManager.Get(player)
    if not data then return end

    local animalState = data.Animals[animalId]
    if not animalState then
        Remotes.ShowNotification:FireClient(player, "Animal not found.", "Error")
        return
    end

    local animal    = AnimalData.GetAnimal(animalState.AnimalType)
    local elapsed   = os.time() - (animalState.LastCollect or 0)
    local prodTime  = animal.ProduceTime
    if animalState.LastFed then
        prodTime = prodTime * 0.75  -- 25% faster when fed
    end

    if elapsed < prodTime then
        local remaining = math.ceil(prodTime - elapsed)
        Remotes.ShowNotification:FireClient(
            player,
            animal.DisplayName .. " not ready yet. " .. remaining .. "s remaining.",
            "Info"
        )
        return
    end

    -- Reward
    DataManager.AddCoins(player, animal.ProductReward)
    DataManager.AddXP(player, animal.XPReward)
    animalState.LastCollect = os.time()
    animalState.LastFed     = nil  -- reset fed bonus

    Remotes.ShowNotification:FireClient(
        player,
        "Collected " .. animal.ProductName .. " from " .. animal.DisplayName
            .. "! +" .. animal.ProductReward .. " coins",
        "Success"
    )
    Remotes.UpdatePlayerData:FireClient(player, data)
end)

-- ── Feed Animal ─────────────────────────────────────────────────────────────

Remotes.FeedAnimal:Connect(function(player, animalId)
    local data = DataManager.Get(player)
    if not data then return end

    local animalState = data.Animals[animalId]
    if not animalState then return end

    local animal = AnimalData.GetAnimal(animalState.AnimalType)
    if data.Coins < animal.FeedCost then
        Remotes.ShowNotification:FireClient(
            player,
            "Need " .. animal.FeedCost .. " coins to feed.",
            "Error"
        )
        return
    end

    DataManager.AddCoins(player, -animal.FeedCost)
    animalState.LastFed = os.time()

    Remotes.ShowNotification:FireClient(
        player,
        animal.DisplayName .. " fed! Produces 25% faster.",
        "Success"
    )
    Remotes.UpdatePlayerData:FireClient(player, data)
end)

-- ── Sell Inventory Items ───────────────────────────────────────────────────

Remotes.SellInventory:Connect(function(player, itemName, amount)
    local data = DataManager.Get(player)
    if not data then return end

    local crop = CropData.GetCrop(itemName)
    if not crop then
        Remotes.ShowNotification:FireClient(player, "Cannot sell that.", "Error")
        return
    end

    local count = math.min(amount or 1, data.Inventory[itemName] or 0)
    if count <= 0 then
        Remotes.ShowNotification:FireClient(player, "None to sell!", "Error")
        return
    end

    local sellPrice = math.floor(crop.SeedCost * 0.5) -- 50% of seed cost
    DataManager.RemoveInventory(player, itemName, count)
    DataManager.AddCoins(player, sellPrice * count)

    Remotes.ShowNotification:FireClient(
        player,
        "Sold " .. count .. "x " .. crop.DisplayName .. " seeds for " .. (sellPrice*count) .. " coins.",
        "Success"
    )
end)
