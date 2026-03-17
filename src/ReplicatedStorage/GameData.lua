-- GameData ModuleScript
-- Location: ReplicatedStorage > GameModules > GameData

local GameData = {}

GameData.Config = {
	GameName              = "Adam And Eshaals Farm",
	StartingCoins         = 500,
	StartingLevel         = 1,
	StartingXP            = 0,
	GridCols              = 6,
	GridRows              = 6,
	PlotSize              = 8,
	PlotSpacing           = 1,
	StartingUnlockedPlots = 9,
	AutoSaveInterval      = 60,
	WiltMultiplier        = 2.0,
	WaterBoost            = 0.50,
	MaxLevel              = 50,
}

GameData.Crops = {
	{ Name="Strawberry", Display="Strawberry 🍓", Cost=10,  Reward=35,   XP=1,  Time=60,   Level=1  },
	{ Name="Wheat",      Display="Wheat 🌾",      Cost=15,  Reward=50,   XP=2,  Time=120,  Level=1  },
	{ Name="Carrot",     Display="Carrot 🥕",     Cost=30,  Reward=90,   XP=3,  Time=180,  Level=3  },
	{ Name="Tomato",     Display="Tomato 🍅",     Cost=40,  Reward=140,  XP=4,  Time=240,  Level=4  },
	{ Name="Corn",       Display="Corn 🌽",       Cost=50,  Reward=180,  XP=5,  Time=300,  Level=5  },
	{ Name="Sunflower",  Display="Sunflower 🌻",  Cost=60,  Reward=250,  XP=6,  Time=360,  Level=6  },
	{ Name="Pumpkin",    Display="Pumpkin 🎃",    Cost=75,  Reward=320,  XP=8,  Time=480,  Level=8  },
	{ Name="Blueberry",  Display="Blueberry 🫐",  Cost=100, Reward=450,  XP=10, Time=600,  Level=10 },
	{ Name="Watermelon", Display="Watermelon 🍉", Cost=150, Reward=700,  XP=15, Time=900,  Level=15 },
	{ Name="GoldenCrop", Display="Golden Crop ✨", Cost=500, Reward=2500, XP=50, Time=1800, Level=20 },
}

GameData.PlotUnlockCosts = {
	[10]=200,[11]=200,[12]=200,
	[13]=400,[14]=400,[15]=400,
	[16]=600,[17]=600,[18]=600,
	[19]=800,[20]=800,[21]=800,
	[22]=1000,[23]=1000,[24]=1000,
	[25]=1500,[26]=1500,[27]=1500,
	[28]=2000,[29]=2000,[30]=2000,
	[31]=3000,[32]=3000,[33]=3000,
	[34]=5000,[35]=5000,[36]=5000,
}

function GameData.GetCrop(name)
	for _, crop in ipairs(GameData.Crops) do
		if crop.Name == name then return crop end
	end
end

function GameData.GetUnlockedCrops(level)
	local result = {}
	for _, crop in ipairs(GameData.Crops) do
		if crop.Level <= level then result[#result+1] = crop end
	end
	return result
end

function GameData.XPForLevel(level)
	return math.floor(100 * (level ^ 1.5))
end

return GameData
