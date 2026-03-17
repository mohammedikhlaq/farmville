-- AnimalData ModuleScript
-- Location: ReplicatedStorage > GameModules > AnimalData
-- Farm animal definitions for Adam And Eshaals Farm

--[[
    Each animal entry:
        Name            string  – key used internally
        DisplayName     string  – shown in UI
        Cost            number  – coins to purchase
        ProductName     string  – item produced
        ProductReward   number  – coins for each product
        XPReward        number  – XP per product collected
        ProduceTime     number  – seconds between productions
        FeedCost        number  – coins to feed (speeds production)
        UnlockLevel     number  – player level required
        Description     string  – flavour text
        ImageId         string  – asset image ID
]]

local AnimalData = {}

AnimalData.Animals = {
    Chicken = {
        Name          = "Chicken",
        DisplayName   = "Chicken",
        Cost          = 200,
        ProductName   = "Egg",
        ProductReward = 30,
        XPReward      = 2,
        ProduceTime   = 120,   -- 2 minutes
        FeedCost      = 15,
        UnlockLevel   = 2,
        Description   = "Lays eggs regularly. A farm staple!",
        ImageId       = "rbxassetid://1033164",
    },
    Cow = {
        Name          = "Cow",
        DisplayName   = "Cow",
        Cost          = 500,
        ProductName   = "Milk",
        ProductReward = 80,
        XPReward      = 5,
        ProduceTime   = 300,   -- 5 minutes
        FeedCost      = 30,
        UnlockLevel   = 5,
        Description   = "Produces creamy milk twice a day.",
        ImageId       = "rbxassetid://1033164",
    },
    Sheep = {
        Name          = "Sheep",
        DisplayName   = "Sheep",
        Cost          = 450,
        ProductName   = "Wool",
        ProductReward = 70,
        XPReward      = 5,
        ProduceTime   = 240,   -- 4 minutes
        FeedCost      = 25,
        UnlockLevel   = 7,
        Description   = "Fluffy wool brings good prices at market.",
        ImageId       = "rbxassetid://1033164",
    },
    Pig = {
        Name          = "Pig",
        DisplayName   = "Pig",
        Cost          = 600,
        ProductName   = "Truffle",
        ProductReward = 150,
        XPReward      = 10,
        ProduceTime   = 600,   -- 10 minutes
        FeedCost      = 50,
        UnlockLevel   = 10,
        Description   = "Sniffs out truffles – very valuable!",
        ImageId       = "rbxassetid://1033164",
    },
    Duck = {
        Name          = "Duck",
        DisplayName   = "Duck",
        Cost          = 350,
        ProductName   = "FeatherDown",
        ProductReward = 60,
        XPReward      = 4,
        ProduceTime   = 180,
        FeedCost      = 20,
        UnlockLevel   = 4,
        Description   = "Quacks and produces warm feather down.",
        ImageId       = "rbxassetid://1033164",
    },
}

function AnimalData.GetAnimal(animalName)
    return AnimalData.Animals[animalName]
end

function AnimalData.GetUnlockedAnimals(level)
    local result = {}
    for _, data in pairs(AnimalData.Animals) do
        if data.UnlockLevel <= level then
            result[#result+1] = data
        end
    end
    table.sort(result, function(a,b) return a.UnlockLevel < b.UnlockLevel end)
    return result
end

return AnimalData
