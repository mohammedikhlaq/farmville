-- CropData ModuleScript
-- Location: ReplicatedStorage > GameModules > CropData
-- All crop definitions for Adam And Eshaals Farm

--[[
    Each crop entry:
        Name            string   – key used internally
        DisplayName     string   – shown in UI
        GrowthTime      number   – seconds to fully grow
        SeedCost        number   – coins per seed purchase
        HarvestReward   number   – coins earned on harvest
        XPReward        number   – XP earned on harvest
        UnlockLevel     number   – player level required
        BrickColor      string   – fallback colour for plot indicator
        Description     string   – flavour text shown in shop
        Stages          number   – visual growth stages (1–4)
        ImageId         string   – Decal / ImageLabel asset ID
                                   (use free Toolbox images or replace)
]]

local CropData = {}

CropData.Crops = {
    -- ─────────────────── LEVEL 1 ───────────────────
    Strawberry = {
        Name          = "Strawberry",
        DisplayName   = "Strawberry",
        GrowthTime    = 60,
        SeedCost      = 10,
        HarvestReward = 35,
        XPReward      = 1,
        UnlockLevel   = 1,
        BrickColor    = "Bright red",
        Description   = "Fast and tasty! Perfect for beginners.",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",   -- placeholder (red circle)
    },
    Wheat = {
        Name          = "Wheat",
        DisplayName   = "Wheat",
        GrowthTime    = 120,
        SeedCost      = 15,
        HarvestReward = 50,
        XPReward      = 2,
        UnlockLevel   = 1,
        BrickColor    = "Bright yellow",
        Description   = "A classic staple crop.",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 3 ───────────────────
    Carrot = {
        Name          = "Carrot",
        DisplayName   = "Carrot",
        GrowthTime    = 180,
        SeedCost      = 30,
        HarvestReward = 90,
        XPReward      = 3,
        UnlockLevel   = 3,
        BrickColor    = "Bright orange",
        Description   = "Grows underground – great crunch!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 4 ───────────────────
    Tomato = {
        Name          = "Tomato",
        DisplayName   = "Tomato",
        GrowthTime    = 240,
        SeedCost      = 40,
        HarvestReward = 140,
        XPReward      = 4,
        UnlockLevel   = 4,
        BrickColor    = "Crimson",
        Description   = "Red, juicy, and delicious!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 5 ───────────────────
    Corn = {
        Name          = "Corn",
        DisplayName   = "Corn",
        GrowthTime    = 300,
        SeedCost      = 50,
        HarvestReward = 180,
        XPReward      = 5,
        UnlockLevel   = 5,
        BrickColor    = "Bright yellow",
        Description   = "Takes time but the reward is worth it.",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 6 ───────────────────
    Sunflower = {
        Name          = "Sunflower",
        DisplayName   = "Sunflower",
        GrowthTime    = 360,
        SeedCost      = 60,
        HarvestReward = 250,
        XPReward      = 6,
        UnlockLevel   = 6,
        BrickColor    = "Bright yellow",
        Description   = "Brightens up the whole farm!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 8 ───────────────────
    Pumpkin = {
        Name          = "Pumpkin",
        DisplayName   = "Pumpkin",
        GrowthTime    = 480,
        SeedCost      = 75,
        HarvestReward = 320,
        XPReward      = 8,
        UnlockLevel   = 8,
        BrickColor    = "Bright orange",
        Description   = "The pride of the autumn harvest!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 10 ──────────────────
    Blueberry = {
        Name          = "Blueberry",
        DisplayName   = "Blueberry",
        GrowthTime    = 600,
        SeedCost      = 100,
        HarvestReward = 450,
        XPReward      = 10,
        UnlockLevel   = 10,
        BrickColor    = "Bright blue",
        Description   = "Premium berry – top of the range!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 15 ──────────────────
    Watermelon = {
        Name          = "Watermelon",
        DisplayName   = "Watermelon",
        GrowthTime    = 900,
        SeedCost      = 150,
        HarvestReward = 700,
        XPReward      = 15,
        UnlockLevel   = 15,
        BrickColor    = "Bright green",
        Description   = "Huge, refreshing, and very profitable.",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
    -- ─────────────────── LEVEL 20 ──────────────────
    GoldenCrop = {
        Name          = "GoldenCrop",
        DisplayName   = "Golden Crop",
        GrowthTime    = 1800,
        SeedCost      = 500,
        HarvestReward = 2500,
        XPReward      = 50,
        UnlockLevel   = 20,
        BrickColor    = "Bright yellow",
        Description   = "The rarest crop on the farm. Pure gold!",
        Stages        = 4,
        ImageId       = "rbxassetid://1033164",
    },
}

-- ── Helpers ────────────────────────────────────────────────────────────────

-- Return data for a single crop by name
function CropData.GetCrop(cropName)
    return CropData.Crops[cropName]
end

-- Return all crops available at or below `level`, sorted by UnlockLevel
function CropData.GetUnlockedCrops(level)
    local result = {}
    for _, data in pairs(CropData.Crops) do
        if data.UnlockLevel <= level then
            result[#result+1] = data
        end
    end
    table.sort(result, function(a,b) return a.UnlockLevel < b.UnlockLevel end)
    return result
end

return CropData
