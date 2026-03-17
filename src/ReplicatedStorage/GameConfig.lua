-- GameConfig ModuleScript
-- Location: ReplicatedStorage > GameModules > GameConfig
-- Shared configuration constants for Adam And Eshaals Farm

local GameConfig = {
    -- ══════════════════════════════════════════
    --  GAME IDENTITY
    -- ══════════════════════════════════════════
    GameName    = "Adam And Eshaals Farm",
    Version     = "1.0.0",

    -- ══════════════════════════════════════════
    --  STARTING VALUES
    -- ══════════════════════════════════════════
    StartingCoins         = 500,
    StartingXP            = 0,
    StartingLevel         = 1,
    StartingUnlockedPlots = 9,   -- 3×3 grid to begin with

    -- ══════════════════════════════════════════
    --  FARM GRID
    -- ══════════════════════════════════════════
    FarmGridCols = 6,  -- total columns  (6×6 = 36 plots)
    FarmGridRows = 6,  -- total rows
    PlotSize     = 8,  -- studs per side
    PlotGap      = 1,  -- gap between adjacent plots (studs)

    -- ══════════════════════════════════════════
    --  LEVELLING
    -- ══════════════════════════════════════════
    MaxLevel = 50,
    XPForLevel = function(level)
        return math.floor(100 * (level ^ 1.5))
    end,

    -- ══════════════════════════════════════════
    --  PLOT UNLOCK COSTS  (coins)
    -- Plots 1-9 are free; 10-36 must be purchased
    -- ══════════════════════════════════════════
    PlotUnlockCosts = {
        [10]=200,[11]=200,[12]=200,
        [13]=400,[14]=400,[15]=400,
        [16]=600,[17]=600,[18]=600,
        [19]=800,[20]=800,[21]=800,
        [22]=1000,[23]=1000,[24]=1000,
        [25]=1500,[26]=1500,[27]=1500,
        [28]=2000,[29]=2000,[30]=2000,
        [31]=3000,[32]=3000,[33]=3000,
        [34]=5000,[35]=5000,[36]=5000,
    },

    -- ══════════════════════════════════════════
    --  MECHANICS
    -- ══════════════════════════════════════════
    WaterGrowthBoost    = 0.50,  -- 50 % faster when watered
    WiltTimeMultiplier  = 2.0,   -- wilts after 2× growthTime past ready
    AutoSaveInterval    = 60,    -- seconds between auto-saves
    NotificationDuration = 3,   -- seconds a toast notification stays

    -- ══════════════════════════════════════════
    --  COLOURS
    -- ══════════════════════════════════════════
    Colors = {
        EmptyPlot  = Color3.fromRGB(139,115, 85),
        PlowedPlot = Color3.fromRGB(101, 67, 33),
        WateredPlot= Color3.fromRGB( 71, 47, 23),
        ReadyPlot  = Color3.fromRGB( 50,200, 50),
        WiltedPlot = Color3.fromRGB( 80, 80, 60),
        LockedPlot = Color3.fromRGB( 60, 60, 60),
        Coins      = Color3.fromRGB(255,200,  0),
        XP         = Color3.fromRGB(100,200,255),
        Success    = Color3.fromRGB( 50,200, 50),
        Error      = Color3.fromRGB(200, 50, 50),
        Info       = Color3.fromRGB(100,150,255),
    },

    -- ══════════════════════════════════════════
    --  FREE ROBLOX SOUND IDs
    --  Replace any of these with asset IDs you
    --  find in the free Toolbox audio section.
    -- ══════════════════════════════════════════
    Sounds = {
        Plant      = "rbxassetid://9120386436",  -- shovel / dig
        Harvest    = "rbxassetid://9120386436",  -- pop / collect
        Coins      = "rbxassetid://4612415922",  -- coin clink
        LevelUp    = "rbxassetid://4612415922",  -- fanfare (replace)
        Water      = "rbxassetid://4807472020",  -- water pour
        Error      = "rbxassetid://3510466167",  -- error ding
        Background = "rbxassetid://1843670910",  -- ambient farm music
    },
}

return GameConfig
