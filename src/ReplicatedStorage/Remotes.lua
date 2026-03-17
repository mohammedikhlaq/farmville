-- Remotes ModuleScript
-- Location: ReplicatedStorage > GameModules > Remotes
-- Creates and provides access to all RemoteEvents / RemoteFunctions

local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")

-- Ensure the Remotes folder exists (server creates it, clients wait for it)
local remotesFolder
if RunService:IsServer() then
    remotesFolder = Instance.new("Folder")
    remotesFolder.Name   = "Remotes"
    remotesFolder.Parent = RS
else
    remotesFolder = RS:WaitForChild("Remotes", 15)
end

-- ── Helper ─────────────────────────────────────────────────────────────────

local function getOrCreate(className, name)
    if RunService:IsServer() then
        local obj = Instance.new(className)
        obj.Name   = name
        obj.Parent = remotesFolder
        return obj
    else
        return remotesFolder:WaitForChild(name, 15)
    end
end

-- ── Remote Definitions ─────────────────────────────────────────────────────

local Remotes = {
    -- Client → Server
    PlantCrop      = getOrCreate("RemoteEvent",    "PlantCrop"),       -- (plotId, cropName)
    HarvestCrop    = getOrCreate("RemoteEvent",    "HarvestCrop"),     -- (plotId)
    WaterCrop      = getOrCreate("RemoteEvent",    "WaterCrop"),       -- (plotId)
    BuySeed        = getOrCreate("RemoteEvent",    "BuySeed"),         -- (cropName, amount)
    BuyAnimal      = getOrCreate("RemoteEvent",    "BuyAnimal"),       -- (animalName)
    CollectAnimal  = getOrCreate("RemoteEvent",    "CollectAnimal"),   -- (animalId)
    FeedAnimal     = getOrCreate("RemoteEvent",    "FeedAnimal"),      -- (animalId)
    UnlockPlot     = getOrCreate("RemoteEvent",    "UnlockPlot"),      -- (plotId)
    SellInventory  = getOrCreate("RemoteEvent",    "SellInventory"),   -- (itemName, amount)
    RequestData    = getOrCreate("RemoteFunction", "RequestData"),     -- () → playerData

    -- Server → Client
    UpdatePlots    = getOrCreate("RemoteEvent",    "UpdatePlots"),     -- (plotsTable)
    UpdatePlayerData = getOrCreate("RemoteEvent",  "UpdatePlayerData"),-- (dataTable)
    ShowNotification = getOrCreate("RemoteEvent",  "ShowNotification"),-- (msg, type)
    PlaySound      = getOrCreate("RemoteEvent",    "PlaySound"),       -- (soundKey)
}

return Remotes
