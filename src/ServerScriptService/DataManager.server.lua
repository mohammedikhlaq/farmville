-- DataManager Server Script
-- Location: ServerScriptService > DataManager
-- Handles saving and loading player data via DataStoreService

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local RS               = game:GetService("ReplicatedStorage")

local GameConfig = require(RS:WaitForChild("GameModules"):WaitForChild("GameConfig"))
local Remotes    = require(RS:WaitForChild("GameModules"):WaitForChild("Remotes"))

local FarmStore  = DataStoreService:GetDataStore("AdamAndEshaalsFarm_v1")

-- ── Defaults ───────────────────────────────────────────────────────────────

local function defaultPlots()
    local plots = {}
    local total = GameConfig.FarmGridCols * GameConfig.FarmGridRows
    for i = 1, total do
        plots[tostring(i)] = {
            Unlocked   = (i <= GameConfig.StartingUnlockedPlots),
            CropType   = nil,
            PlantedAt  = nil,
            WateredAt  = nil,
            IsWilted   = false,
        }
    end
    return plots
end

local function defaultData()
    return {
        Coins          = GameConfig.StartingCoins,
        XP             = GameConfig.StartingXP,
        Level          = GameConfig.StartingLevel,
        Plots          = defaultPlots(),
        Inventory      = {},   -- { [cropName] = count }
        Animals        = {},   -- { [uuid] = animalState }
        TotalHarvests  = 0,
        TotalCoinsEarned = 0,
        JoinDate       = os.time(),
        LastSaved      = os.time(),
    }
end

-- ── In-memory cache ────────────────────────────────────────────────────────

local PlayerData = {}   -- [player] = data table

-- ── Load / Save ────────────────────────────────────────────────────────────

local function loadData(player)
    local success, data = pcall(function()
        return FarmStore:GetAsync("player_" .. player.UserId)
    end)

    if success and data then
        -- Merge any missing default keys (handles version upgrades)
        local defaults = defaultData()
        for k, v in pairs(defaults) do
            if data[k] == nil then data[k] = v end
        end
        -- Ensure all plots exist
        local totalPlots = GameConfig.FarmGridCols * GameConfig.FarmGridRows
        for i = 1, totalPlots do
            local key = tostring(i)
            if not data.Plots[key] then
                data.Plots[key] = {
                    Unlocked  = (i <= GameConfig.StartingUnlockedPlots),
                    CropType  = nil,
                    PlantedAt = nil,
                    WateredAt = nil,
                    IsWilted  = false,
                }
            end
        end
        PlayerData[player] = data
    else
        PlayerData[player] = defaultData()
        if not success then
            warn("[DataManager] Failed to load data for " .. player.Name .. ": " .. tostring(data))
        end
    end

    -- Inform client
    Remotes.UpdatePlayerData:FireClient(player, PlayerData[player])
    Remotes.UpdatePlots:FireClient(player, PlayerData[player].Plots)

    return PlayerData[player]
end

local function saveData(player)
    local data = PlayerData[player]
    if not data then return end
    data.LastSaved = os.time()

    local success, err = pcall(function()
        FarmStore:SetAsync("player_" .. player.UserId, data)
    end)

    if not success then
        warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
    end
end

-- ── Public API (used by other server scripts) ──────────────────────────────

local DataManager = {}

function DataManager.Get(player)
    return PlayerData[player]
end

function DataManager.Set(player, key, value)
    if PlayerData[player] then
        PlayerData[player][key] = value
    end
end

function DataManager.AddCoins(player, amount)
    local data = PlayerData[player]
    if not data then return end
    data.Coins = math.max(0, data.Coins + amount)
    if amount > 0 then data.TotalCoinsEarned = data.TotalCoinsEarned + amount end
    Remotes.UpdatePlayerData:FireClient(player, data)
end

function DataManager.AddXP(player, amount)
    local data = PlayerData[player]
    if not data then return end
    data.XP = data.XP + amount

    -- Level-up loop
    local levelled = false
    while data.Level < GameConfig.MaxLevel
        and data.XP >= GameConfig.XPForLevel(data.Level) do
        data.XP    = data.XP - GameConfig.XPForLevel(data.Level)
        data.Level = data.Level + 1
        levelled   = true
    end

    if levelled then
        Remotes.ShowNotification:FireClient(
            player,
            "Level Up! You are now Level " .. data.Level .. "!",
            "LevelUp"
        )
        Remotes.PlaySound:FireClient(player, "LevelUp")
    end

    Remotes.UpdatePlayerData:FireClient(player, data)
end

function DataManager.AddInventory(player, itemName, count)
    local data = PlayerData[player]
    if not data then return end
    data.Inventory[itemName] = (data.Inventory[itemName] or 0) + count
    Remotes.UpdatePlayerData:FireClient(player, data)
end

function DataManager.RemoveInventory(player, itemName, count)
    local data = PlayerData[player]
    if not data then return false end
    local current = data.Inventory[itemName] or 0
    if current < count then return false end
    data.Inventory[itemName] = current - count
    Remotes.UpdatePlayerData:FireClient(player, data)
    return true
end

function DataManager.SaveAll()
    for player, _ in pairs(PlayerData) do
        saveData(player)
    end
end

-- ── Events ─────────────────────────────────────────────────────────────────

Players.PlayerAdded:Connect(function(player)
    loadData(player)
end)

Players.PlayerRemoving:Connect(function(player)
    saveData(player)
    PlayerData[player] = nil
end)

-- Handle server shutdown
game:BindToClose(function()
    if RunService:IsStudio() then
        task.wait(2)
    else
        for player, _ in pairs(PlayerData) do
            saveData(player)
        end
        task.wait(3)
    end
end)

-- Handle RequestData RemoteFunction
Remotes.RequestData.OnServerInvoke = function(player)
    return PlayerData[player] or defaultData()
end

-- Auto-save loop
task.spawn(function()
    while true do
        task.wait(GameConfig.AutoSaveInterval)
        DataManager.SaveAll()
    end
end)

-- Make DataManager accessible to other server scripts via _G (simple approach)
_G.DataManager = DataManager

return DataManager
