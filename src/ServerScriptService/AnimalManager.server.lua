-- AnimalManager.server.lua
-- 8 interactive farm animal species with:
--   Cows / Goats  : 🥛 Milk   (ProximityPrompt, 5-min cooldown)
--   Sheep         : ✂ Shear  (ProximityPrompt, 5-min cooldown)
--   Chickens/Ducks: 🐾 Pick Up → carry to Slaughterhouse + auto-lay 🥚 eggs
--   Pigs/Goats    : 🐾 Lead   → lead to Slaughterhouse
--   Cows/Bulls/Horses: 🔪 Slaughter directly (too big to carry)
--   🥩 Slaughterhouse building near barn (X=52, Z=-22)

local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

math.randomseed(os.clock() * 1000)

-- ── Coin / Notify helpers ─────────────────────────────────────────────────
local coinAPI, notifyRE

task.spawn(function()
	coinAPI = RS:WaitForChild("_CoinAPI", 30)
end)
task.spawn(function()
	local rf = RS:WaitForChild("Remotes", 30)
	if rf then notifyRE = rf:WaitForChild("Notify", 30) end
end)

local function addCoins(player, amount)
	if coinAPI then pcall(function() coinAPI:Invoke(player.Name, amount) end) end
end
local function notify(player, msg, ntype)
	if notifyRE then notifyRE:FireClient(player, msg, ntype or "Info") end
end

-- ── Rewards & cooldowns ───────────────────────────────────────────────────
local SLAUGHTER_REWARD = {
	chicken=30, duck=35, pig=80, sheep=60,
	goat=50, cow=150, bull=200, horse=100,
}
local MILK_REWARD   = { cow=25, goat=15 }
local SHEAR_REWARD  = { sheep=40 }
local MILK_CD       = 300   -- 5 min
local SHEAR_CD      = 300   -- 5 min
local EGG_INTERVAL  = { chicken=180, duck=240 }
local EGG_REWARD    = { chicken=10,  duck=15  }

-- Carry offsets from player HumanoidRootPart CFrame
-- Negative Z = in front of player, Positive Z = behind
local CARRY_OFFSET = {
	chicken = CFrame.new(0, -0.5, -2.0),   -- held in front
	duck    = CFrame.new(0, -0.5, -2.0),
	pig     = CFrame.new(0, -2.0,  3.5),   -- led behind
	sheep   = CFrame.new(0, -1.5,  3.5),
	goat    = CFrame.new(0, -1.8,  3.5),
}

-- ── Species config ────────────────────────────────────────────────────────
local SPECIES = {
	{ kind="chicken", count=7, cx=-42, cz= -5, radius=11, speed=5.5 },
	{ kind="duck",    count=5, cx=-25, cz=-18, radius= 8, speed=3.5 },
	{ kind="sheep",   count=5, cx=-10, cz= 42, radius=14, speed=2.5 },
	{ kind="goat",    count=4, cx=-38, cz= 25, radius=12, speed=4.0 },
	{ kind="pig",     count=4, cx= 48, cz= 15, radius=11, speed=3.5 },
	{ kind="cow",     count=4, cx= 48, cz= 45, radius=15, speed=2.0 },
	{ kind="bull",    count=2, cx= 60, cz= 20, radius=10, speed=2.5 },
	{ kind="horse",   count=3, cx= 20, cz= 55, radius=14, speed=6.0 },
}

local IDLE_MIN, IDLE_MAX = 1.5, 5

-- ── Sounds ────────────────────────────────────────────────────────────────
local SOUND_IDS = {
	chicken="rbxassetid://3546745391", duck="rbxassetid://3546745391",
	sheep="rbxassetid://7112263679",   goat="rbxassetid://7112263679",
	pig="rbxassetid://6344318670",     cow="rbxassetid://6344318670",
	bull="rbxassetid://6344318670",    horse="rbxassetid://6344318670",
}

-- ── State ─────────────────────────────────────────────────────────────────
local animalRecords = {}
local carriedAnimals = {}   -- [player] = rec

-- ── Part builders ─────────────────────────────────────────────────────────
local SP = Enum.SurfaceType.Smooth

local function mkPart(model, name, color, mat)
	local p = Instance.new("Part")
	p.Name=name; p.Size=Vector3.new(1,1,1)
	p.BrickColor=BrickColor.new(color)
	p.Material=mat or Enum.Material.SmoothPlastic
	p.Anchored=true; p.CanCollide=false
	p.TopSurface=SP; p.BottomSurface=SP
	p.Parent=model; return p
end
local function sph(m,n,c,sx,sy,sz,ox,oy,oz,mat)
	local p=mkPart(m,n,c,mat); p.CFrame=CFrame.new(ox,oy,oz)
	local ms=Instance.new("SpecialMesh"); ms.MeshType=Enum.MeshType.Sphere
	ms.Scale=Vector3.new(sx,sy,sz); ms.Parent=p; return p
end
local function cyl(m,n,c,sx,sy,sz,ox,oy,oz,rx,ry,rz)
	local p=mkPart(m,n,c); p.CFrame=CFrame.new(ox,oy,oz)*CFrame.Angles(rx or 0,ry or 0,rz or 0)
	local ms=Instance.new("SpecialMesh"); ms.MeshType=Enum.MeshType.Cylinder
	ms.Scale=Vector3.new(sx,sy,sz); ms.Parent=p; return p
end
local function blk(m,n,c,sx,sy,sz,ox,oy,oz,rx,ry,rz,mat)
	local p=mkPart(m,n,c,mat); p.Size=Vector3.new(sx,sy,sz)
	p.CFrame=CFrame.new(ox,oy,oz)*CFrame.Angles(rx or 0,ry or 0,rz or 0); return p
end

-- ── Animal builders ───────────────────────────────────────────────────────
local function mkChicken()
	local m=Instance.new("Model"); m.Name="Chicken"
	local body=sph(m,"Body","Bright yellow",2.2,1.6,2.8, 0,0,0)
	sph(m,"Head","Bright yellow",1.3,1.3,1.3, 0,1.3,1.1)
	sph(m,"Comb1","Bright red",0.45,0.6,0.4, -0.2,2.05,1.1)
	sph(m,"Comb2","Bright red",0.55,0.75,0.5,  0,2.2,1.1)
	sph(m,"Comb3","Bright red",0.45,0.6,0.4,  0.2,2.05,1.1)
	blk(m,"Beak","Bright orange",0.35,0.25,0.45, 0,1.15,1.72)
	sph(m,"Wattle","Bright red",0.3,0.4,0.3, 0,0.8,1.65)
	sph(m,"WingL","CGA brown",0.55,1.2,2.0, -1.2,0,0)
	sph(m,"WingR","CGA brown",0.55,1.2,2.0,  1.2,0,0)
	cyl(m,"LegL","Bright orange",0.3,0.3,1.9, -0.55,-1.3,0.2, 0,0,math.rad(90))
	cyl(m,"LegR","Bright orange",0.3,0.3,1.9,  0.55,-1.3,0.2, 0,0,math.rad(90))
	sph(m,"TailA","CGA brown",0.5,0.9,0.5, 0,0.6,-1.3)
	sph(m,"TailB","CGA brown",0.4,0.7,0.4, -0.28,0.4,-1.38)
	sph(m,"TailC","CGA brown",0.4,0.7,0.4,  0.28,0.4,-1.38)
	m.PrimaryPart=body; return m
end
local function mkDuck()
	local m=Instance.new("Model"); m.Name="Duck"
	local body=sph(m,"Body","Bright yellow",1.8,1.3,2.4, 0,0,0)
	sph(m,"Head","Earth green",1.0,1.0,1.0, 0,1.0,0.95)
	cyl(m,"Bill","Bright orange",0.8,0.8,0.6, 0,0.75,1.45, 0,0,math.rad(90))
	sph(m,"EyeL","Black",0.2,0.2,0.15, -0.38,1.1,1.2)
	sph(m,"EyeR","Black",0.2,0.2,0.15,  0.38,1.1,1.2)
	sph(m,"WingL","Bright yellow",0.4,0.9,1.8, -0.95,0.1,0)
	sph(m,"WingR","Bright yellow",0.4,0.9,1.8,  0.95,0.1,0)
	cyl(m,"LegL","Bright orange",0.25,0.25,1.3, -0.4,-1.0,0.1, 0,0,math.rad(90))
	cyl(m,"LegR","Bright orange",0.25,0.25,1.3,  0.4,-1.0,0.1, 0,0,math.rad(90))
	sph(m,"Tail","White",0.5,0.6,0.5, 0,0.3,-1.2)
	m.PrimaryPart=body; return m
end
local function mkSheep()
	local m=Instance.new("Model"); m.Name="Sheep"
	local body=sph(m,"Wool","White",4.2,3.2,5.5, 0,0,0, Enum.Material.Fabric)
	sph(m,"Head","Medium stone grey",1.8,1.8,1.9, 0,1.8,2.8)
	sph(m,"Nose","Pastel brown",0.9,0.7,0.6, 0,1.45,3.5)
	sph(m,"NL","Black",0.2,0.2,0.2, -0.22,1.38,3.8)
	sph(m,"NR","Black",0.2,0.2,0.2,  0.22,1.38,3.8)
	sph(m,"EyeL","Black",0.32,0.32,0.2, -0.65,2.05,3.2)
	sph(m,"EyeR","Black",0.32,0.32,0.2,  0.65,2.05,3.2)
	sph(m,"EarL","Medium stone grey",0.55,1.1,0.4, -1.0,2.0,2.6)
	sph(m,"EarR","Medium stone grey",0.55,1.1,0.4,  1.0,2.0,2.6)
	cyl(m,"LL1","Dark grey",0.6,0.6,2.8,-1.2,-2.6,-1.2, math.rad(90),0,0)
	cyl(m,"LL2","Dark grey",0.6,0.6,2.8, 1.2,-2.6,-1.2, math.rad(90),0,0)
	cyl(m,"LL3","Dark grey",0.6,0.6,2.8,-1.2,-2.6, 1.2, math.rad(90),0,0)
	cyl(m,"LL4","Dark grey",0.6,0.6,2.8, 1.2,-2.6, 1.2, math.rad(90),0,0)
	sph(m,"HFL","Black",0.65,0.4,0.65,-1.2,-3.55,-1.2)
	sph(m,"HFR","Black",0.65,0.4,0.65, 1.2,-3.55,-1.2)
	sph(m,"HBL","Black",0.65,0.4,0.65,-1.2,-3.55, 1.2)
	sph(m,"HBR","Black",0.65,0.4,0.65, 1.2,-3.55, 1.2)
	sph(m,"Tail","White",0.8,0.8,0.8, 0,0.5,-2.8, Enum.Material.Fabric)
	m.PrimaryPart=body; return m
end
local function mkGoat()
	local m=Instance.new("Model"); m.Name="Goat"
	local body=sph(m,"Body","Light grey",3.0,2.0,4.0, 0,0,0)
	sph(m,"Head","Light grey",1.5,1.4,1.6, 0,1.4,2.1)
	sph(m,"Muzzle","White",0.8,0.65,0.6, 0,1.0,2.75)
	sph(m,"NL","Black",0.18,0.18,0.15, -0.22,0.95,3.05)
	sph(m,"NR","Black",0.18,0.18,0.15,  0.22,0.95,3.05)
	sph(m,"EyeL","Black",0.28,0.28,0.18, -0.6,1.65,2.5)
	sph(m,"EyeR","Black",0.28,0.28,0.18,  0.6,1.65,2.5)
	cyl(m,"HornL","Ivory",0.25,0.25,1.2, -0.5,2.4,1.9, math.rad(-30),0,math.rad(-20))
	cyl(m,"HornR","Ivory",0.25,0.25,1.2,  0.5,2.4,1.9, math.rad(-30),0,math.rad( 20))
	blk(m,"Beard","Light grey",0.25,0.7,0.25, 0,0.5,3.0)
	sph(m,"EarL","Light grey",0.4,0.85,0.3, -0.9,1.8,2.0)
	sph(m,"EarR","Light grey",0.4,0.85,0.3,  0.9,1.8,2.0)
	cyl(m,"LF1","Light grey",0.45,0.45,2.2,-0.85,-1.6,-1.1, math.rad(90),0,0)
	cyl(m,"LF2","Light grey",0.45,0.45,2.2, 0.85,-1.6,-1.1, math.rad(90),0,0)
	cyl(m,"LB1","Light grey",0.45,0.45,2.2,-0.85,-1.6, 1.1, math.rad(90),0,0)
	cyl(m,"LB2","Light grey",0.45,0.45,2.2, 0.85,-1.6, 1.1, math.rad(90),0,0)
	sph(m,"Tail","White",0.5,0.5,0.5, 0,0.4,-2.1)
	m.PrimaryPart=body; return m
end
local function mkPig()
	local m=Instance.new("Model"); m.Name="Pig"
	local body=sph(m,"Body","Pastel orange",3.5,2.6,4.8, 0,0,0)
	sph(m,"Head","Pastel orange",2.4,2.3,2.4, 0,1.0,2.4)
	cyl(m,"Snout","Carnation pink",1.6,1.6,0.6, 0,0.7,3.65, 0,0,math.rad(90))
	sph(m,"NL","Pastel brown",0.4,0.4,0.25, -0.38,0.65,3.97)
	sph(m,"NR","Pastel brown",0.4,0.4,0.25,  0.38,0.65,3.97)
	sph(m,"EyeL","Black",0.45,0.45,0.3, -0.85,1.55,3.25)
	sph(m,"EyeR","Black",0.45,0.45,0.3,  0.85,1.55,3.25)
	sph(m,"EarL","Pastel orange",0.9,1.4,0.5, -1.1,2.4,2.2)
	sph(m,"EarR","Pastel orange",0.9,1.4,0.5,  1.1,2.4,2.2)
	sph(m,"IEarL","Carnation pink",0.5,0.9,0.3, -1.1,2.4,2.2)
	sph(m,"IEarR","Carnation pink",0.5,0.9,0.3,  1.1,2.4,2.2)
	cyl(m,"LFL","Pastel orange",0.75,0.75,2.5,-1.1,-2.0,-1.3, math.rad(90),0,0)
	cyl(m,"LFR","Pastel orange",0.75,0.75,2.5, 1.1,-2.0,-1.3, math.rad(90),0,0)
	cyl(m,"LBL","Pastel orange",0.75,0.75,2.5,-1.1,-2.0, 1.3, math.rad(90),0,0)
	cyl(m,"LBR","Pastel orange",0.75,0.75,2.5, 1.1,-2.0, 1.3, math.rad(90),0,0)
	sph(m,"HFL","Black",0.8,0.5,0.8,-1.1,-3.3,-1.3)
	sph(m,"HFR","Black",0.8,0.5,0.8, 1.1,-3.3,-1.3)
	sph(m,"HBL","Black",0.8,0.5,0.8,-1.1,-3.3, 1.3)
	sph(m,"HBR","Black",0.8,0.5,0.8, 1.1,-3.3, 1.3)
	cyl(m,"Tail1","Pastel orange",0.35,0.35,1.2, 0,0.6,-2.6, math.rad(-40),0,0)
	cyl(m,"Tail2","Carnation pink",0.25,0.25,0.9, 0,1.3,-2.95, math.rad(-60),0,math.rad(30))
	m.PrimaryPart=body; return m
end
local function mkCow()
	local m=Instance.new("Model"); m.Name="Cow"
	local body=sph(m,"Body","White",5.5,3.5,7.5, 0,0,0)
	sph(m,"PatchA","Black",2.5,2.0,2.8, -1.5,0.8,1.5)
	sph(m,"PatchB","Black",2.0,1.5,2.0,  1.0,-0.5,-1.8)
	sph(m,"PatchC","Black",1.5,1.2,1.8, -0.5,1.2,-2.0)
	cyl(m,"Neck","White",1.4,1.4,2.5, 0,2.0,3.5, math.rad(-40),0,0)
	sph(m,"Head","White",2.0,1.9,2.2, 0,3.1,5.0)
	sph(m,"Muzzle","Pastel orange",1.4,1.0,1.0, 0,2.65,6.0)
	sph(m,"NL","Black",0.3,0.3,0.22, -0.38,2.55,6.55)
	sph(m,"NR","Black",0.3,0.3,0.22,  0.38,2.55,6.55)
	sph(m,"EyeL","Black",0.5,0.5,0.3, -0.9,3.4,5.5)
	sph(m,"EyeR","Black",0.5,0.5,0.3,  0.9,3.4,5.5)
	sph(m,"EarL","White",0.7,1.4,0.5, -1.1,3.7,4.8)
	sph(m,"EarR","White",0.7,1.4,0.5,  1.1,3.7,4.8)
	cyl(m,"HornL","Ivory",0.3,0.3,1.5,-0.85,4.3,4.75, math.rad(-10),0,math.rad(-35))
	cyl(m,"HornR","Ivory",0.3,0.3,1.5, 0.85,4.3,4.75, math.rad(-10),0,math.rad( 35))
	cyl(m,"LegFL","White",1.0,1.0,4.2,-1.5,-2.8,-2.2, math.rad(90),0,0)
	cyl(m,"LegFR","White",1.0,1.0,4.2, 1.5,-2.8,-2.2, math.rad(90),0,0)
	cyl(m,"LegBL","White",1.0,1.0,4.2,-1.5,-2.8, 2.2, math.rad(90),0,0)
	cyl(m,"LegBR","White",1.0,1.0,4.2, 1.5,-2.8, 2.2, math.rad(90),0,0)
	sph(m,"HFL","Black",1.1,0.7,1.1,-1.5,-5.1,-2.2)
	sph(m,"HFR","Black",1.1,0.7,1.1, 1.5,-5.1,-2.2)
	sph(m,"HBL","Black",1.1,0.7,1.1,-1.5,-5.1, 2.2)
	sph(m,"HBR","Black",1.1,0.7,1.1, 1.5,-5.1, 2.2)
	sph(m,"Udder","Carnation pink",2.0,1.2,1.8, 0,-2.3,1.5)
	cyl(m,"TeatFL","Carnation pink",0.28,0.28,0.7,-0.5,-3.2,1.0, math.rad(90),0,0)
	cyl(m,"TeatFR","Carnation pink",0.28,0.28,0.7, 0.5,-3.2,1.0, math.rad(90),0,0)
	cyl(m,"TeatBL","Carnation pink",0.28,0.28,0.7,-0.5,-3.2,2.0, math.rad(90),0,0)
	cyl(m,"TeatBR","Carnation pink",0.28,0.28,0.7, 0.5,-3.2,2.0, math.rad(90),0,0)
	cyl(m,"Tail","White",0.4,0.4,3.5, 0,1.5,-3.8, math.rad(-60),0,0)
	sph(m,"TailTip","Black",0.8,1.4,0.8, 0,-0.1,-5.5)
	m.PrimaryPart=body; return m
end
local function mkBull()
	local m=Instance.new("Model"); m.Name="Bull"
	local body=sph(m,"Body","Reddish brown",6.5,4.5,9.0, 0,0,0)
	sph(m,"Hump","Dark orange",3.5,3.0,3.5, 0,3.0,-1.5)
	cyl(m,"Neck","Reddish brown",2.0,2.0,3.8, 0,3.5,4.0, math.rad(-30),0,0)
	sph(m,"Head","Reddish brown",2.8,2.5,3.0, 0,4.5,6.2)
	sph(m,"Muzzle","Pastel brown",1.8,1.3,1.3, 0,3.9,7.4)
	sph(m,"NL","Black",0.38,0.38,0.28, -0.45,3.75,7.95)
	sph(m,"NR","Black",0.38,0.38,0.28,  0.45,3.75,7.95)
	sph(m,"EyeL","Black",0.6,0.6,0.38, -1.1,4.85,6.8)
	sph(m,"EyeR","Black",0.6,0.6,0.38,  1.1,4.85,6.8)
	sph(m,"EarL","Reddish brown",0.8,1.6,0.6, -1.4,5.5,6.0)
	sph(m,"EarR","Reddish brown",0.8,1.6,0.6,  1.4,5.5,6.0)
	cyl(m,"HornL","Ivory",0.4,0.4,3.0, -1.0,5.9,6.1, math.rad(-5),0,math.rad(-50))
	cyl(m,"HornTL","Ivory",0.28,0.28,1.5, -2.9,5.5,6.2, math.rad(20),0,math.rad(-70))
	cyl(m,"HornR","Ivory",0.4,0.4,3.0,  1.0,5.9,6.1, math.rad(-5),0,math.rad( 50))
	cyl(m,"HornTR","Ivory",0.28,0.28,1.5,  2.9,5.5,6.2, math.rad(20),0,math.rad( 70))
	cyl(m,"LegFL","Reddish brown",1.4,1.4,5.5,-2.0,-3.5,-2.8, math.rad(90),0,0)
	cyl(m,"LegFR","Reddish brown",1.4,1.4,5.5, 2.0,-3.5,-2.8, math.rad(90),0,0)
	cyl(m,"LegBL","Reddish brown",1.4,1.4,5.5,-2.0,-3.5, 2.8, math.rad(90),0,0)
	cyl(m,"LegBR","Reddish brown",1.4,1.4,5.5, 2.0,-3.5, 2.8, math.rad(90),0,0)
	sph(m,"HFL","Black",1.5,1.0,1.5,-2.0,-6.5,-2.8)
	sph(m,"HFR","Black",1.5,1.0,1.5, 2.0,-6.5,-2.8)
	sph(m,"HBL","Black",1.5,1.0,1.5,-2.0,-6.5, 2.8)
	sph(m,"HBR","Black",1.5,1.0,1.5, 2.0,-6.5, 2.8)
	cyl(m,"Tail","Reddish brown",0.5,0.5,4.5, 0,2.0,-4.5, math.rad(-55),0,0)
	sph(m,"TailTip","Black",1.0,1.8,1.0, 0,-0.5,-6.8)
	m.PrimaryPart=body; return m
end
local function mkHorse()
	local m=Instance.new("Model"); m.Name="Horse"
	local body=sph(m,"Body","Reddish brown",4.5,3.8,8.0, 0,0,0)
	cyl(m,"Neck","Reddish brown",2.0,2.0,5.5, 0,4.0,3.8, math.rad(-55),0,0)
	sph(m,"Head","Reddish brown",2.2,2.2,3.2, 0,6.0,6.0)
	sph(m,"Muzzle","Pastel brown",1.5,1.1,1.2, 0,5.3,7.5)
	sph(m,"NL","Black",0.32,0.32,0.24, -0.38,5.12,8.1)
	sph(m,"NR","Black",0.32,0.32,0.24,  0.38,5.12,8.1)
	sph(m,"EyeL","Black",0.55,0.55,0.35, -1.0,6.5,6.8)
	sph(m,"EyeR","Black",0.55,0.55,0.35,  1.0,6.5,6.8)
	sph(m,"EarL","Reddish brown",0.5,1.2,0.4, -0.8,7.5,5.8)
	sph(m,"EarR","Reddish brown",0.5,1.2,0.4,  0.8,7.5,5.8)
	blk(m,"Mane","Black",0.45,0.6,4.5, 0,6.2,4.5, math.rad(-55),0,0, Enum.Material.Fabric)
	blk(m,"Forelock","Black",0.45,1.5,0.4, 0,7.5,6.0, 0,0,0, Enum.Material.Fabric)
	cyl(m,"LegFL","Reddish brown",0.9,0.9,6.5,-1.5,-4.0,-2.5, math.rad(90),0,0)
	cyl(m,"LegFR","Reddish brown",0.9,0.9,6.5, 1.5,-4.0,-2.5, math.rad(90),0,0)
	cyl(m,"LegBL","Reddish brown",0.9,0.9,6.5,-1.5,-4.0, 2.5, math.rad(90),0,0)
	cyl(m,"LegBR","Reddish brown",0.9,0.9,6.5, 1.5,-4.0, 2.5, math.rad(90),0,0)
	sph(m,"HFL","Black",1.0,0.7,1.0,-1.5,-7.3,-2.5)
	sph(m,"HFR","Black",1.0,0.7,1.0, 1.5,-7.3,-2.5)
	sph(m,"HBL","Black",1.0,0.7,1.0,-1.5,-7.3, 2.5)
	sph(m,"HBR","Black",1.0,0.7,1.0, 1.5,-7.3, 2.5)
	cyl(m,"Tail1","Black",0.55,0.55,5.0,  0, 2.0,-4.1, math.rad(-70),0,0)
	cyl(m,"Tail2","Black",0.45,0.45,4.0,  0.4,-1.2,-6.5, math.rad(-85),0,math.rad(10))
	cyl(m,"Tail3","Black",0.35,0.35,4.0, -0.4,-1.2,-6.5, math.rad(-85),0,math.rad(-10))
	m.PrimaryPart=body; return m
end

local BUILDERS = {
	chicken=mkChicken, duck=mkDuck, sheep=mkSheep, goat=mkGoat,
	pig=mkPig, cow=mkCow, bull=mkBull, horse=mkHorse,
}

-- ── Ground offset ─────────────────────────────────────────────────────────
local function groundOffset(model)
	local pivotY = model.PrimaryPart and model.PrimaryPart.Position.Y or 0
	local minY = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local ms = p:FindFirstChildOfClass("SpecialMesh")
			local hh = ms and (p.Size.Y * ms.Scale.Y * 0.5) or (p.Size.Y * 0.5)
			minY = math.min(minY, p.Position.Y - hh)
		end
	end
	return (minY == math.huge) and 1 or math.max(0.3, pivotY - minY)
end

-- ── Spatial sound ─────────────────────────────────────────────────────────
local function attachSound(body, kind)
	local id = SOUND_IDS[kind]; if not id then return end
	local s = Instance.new("Sound")
	s.SoundId = id; s.Volume = 0.6
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10; s.RollOffMaxDistance = 70
	s.Parent = body
	task.spawn(function()
		while body and body.Parent do
			task.wait(6 + math.random() * 12)
			if body and body.Parent then pcall(function() s:Play() end) end
		end
	end)
end

-- ── Zone helpers ──────────────────────────────────────────────────────────
local function randomInZone(cx, cz, r)
	local a = math.random() * math.pi * 2
	local d = math.sqrt(math.random()) * r
	return cx + math.cos(a)*d, cz + math.sin(a)*d
end

-- ── ProximityPrompt helper ────────────────────────────────────────────────
local function addPrompt(part, action, obj, key, hold, dist)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action; pp.ObjectText = obj or ""
	pp.KeyboardKeyCode = key or Enum.KeyCode.E
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = dist or 8
	pp.RequiresLineOfSight = false
	pp.Parent = part
	return pp
end

-- ── Forward declarations ──────────────────────────────────────────────────
local carryStop, carryStart, processSlaughter, spawnOneAnimal

-- ── Slaughter processing ──────────────────────────────────────────────────
processSlaughter = function(rec)
	rec.slaughtered = true
	for i = #animalRecords, 1, -1 do
		if animalRecords[i] == rec then table.remove(animalRecords, i); break end
	end
	if rec.model and rec.model.Parent then rec.model:Destroy() end
	local spec = rec.spec
	task.delay(60, function()
		if spawnOneAnimal then spawnOneAnimal(spec) end
	end)
end

-- ── Carry system ──────────────────────────────────────────────────────────
carryStop = function(rec)
	rec.carried = false
	if rec.carriedBy then carriedAnimals[rec.carriedBy] = nil end
	rec.carriedBy = nil
	if rec.pickupPrompt then rec.pickupPrompt.Enabled = true end
	if rec.dropPrompt   then rec.dropPrompt.Enabled   = false end
end

carryStart = function(player, rec)
	if carriedAnimals[player] then
		notify(player, "❌ Already carrying an animal! Drop it first.", "Error")
		return
	end
	if rec.carried then return end
	rec.carried   = true
	rec.carriedBy = player
	carriedAnimals[player] = rec
	if rec.pickupPrompt then rec.pickupPrompt.Enabled = false end
	if rec.dropPrompt   then rec.dropPrompt.Enabled   = true end

	local offset = CARRY_OFFSET[rec.kind] or CFrame.new(0, -1, -2)
	task.spawn(function()
		while rec.carried and rec.model and rec.model.Parent do
			local char = player.Character
			local hrp  = char and char:FindFirstChild("HumanoidRootPart")
			if not hrp or not hrp.Parent then carryStop(rec); break end
			pcall(function() rec.model:PivotTo(hrp.CFrame * offset) end)
			task.wait(0.05)
		end
	end)

	local action = (rec.kind == "chicken" or rec.kind == "duck") and "Carrying" or "Leading"
	notify(player, "🐾 "..action.." "..rec.kind.."! Walk to the Slaughterhouse.", "Info")
end

-- ── Egg spawning ──────────────────────────────────────────────────────────
local function startEggLayer(rec)
	task.spawn(function()
		local interval = EGG_INTERVAL[rec.kind] or 180
		while rec.body and rec.body.Parent and not rec.slaughtered do
			task.wait(interval + math.random(-20, 20))
			if rec.slaughtered or not rec.body or not rec.body.Parent then break end

			local pos = rec.body.Position
			local egg = Instance.new("Part")
			egg.Name = "Egg"; egg.Size = Vector3.new(0.45, 0.55, 0.45)
			egg.CFrame = CFrame.new(pos.X + math.random(-2,2), 0.3, pos.Z + math.random(-2,2))
			egg.Anchored = true; egg.CanCollide = false
			egg.Material = Enum.Material.SmoothPlastic
			egg.BrickColor = BrickColor.new("White")
			egg.TopSurface = SP; egg.BottomSurface = SP
			local sm = Instance.new("SpecialMesh")
			sm.MeshType = Enum.MeshType.Sphere
			sm.Scale = Vector3.new(0.9, 1.1, 0.9); sm.Parent = egg
			egg.Parent = Workspace

			local reward = EGG_REWARD[rec.kind] or 10
			local obj    = rec.kind == "duck" and "🦆 Duck Egg" or "🥚 Egg"
			local ep = addPrompt(egg, "Collect", obj, Enum.KeyCode.E, 0, 6)
			ep.Triggered:Connect(function(player)
				addCoins(player, reward)
				notify(player, "🥚 Collected "..rec.kind.." egg! +"..reward.." coins", "Success")
				egg:Destroy()
			end)
			task.delay(300, function() if egg.Parent then egg:Destroy() end end)
		end
	end)
end

-- ── Interaction setup ─────────────────────────────────────────────────────
local function setupInteractions(rec)
	local kind = rec.kind
	local body = rec.body

	-- Milk (cow, goat)
	if MILK_REWARD[kind] then
		local reward = MILK_REWARD[kind]
		local obj    = kind == "cow" and "🐄 Cow" or "🐐 Goat"
		local mp = addPrompt(body, "Milk", obj, Enum.KeyCode.E, 1.5, 8)
		mp.Triggered:Connect(function(player)
			local now = os.clock()
			if now - (rec.milkCooldown or 0) < MILK_CD then
				notify(player, string.format("⏳ %ds until next milk",
					math.ceil(MILK_CD - (now - rec.milkCooldown))), "Info")
				return
			end
			rec.milkCooldown = now
			addCoins(player, reward)
			notify(player, "🥛 Milked the "..kind.."! +"..reward.." coins", "Success")
		end)
	end

	-- Shear (sheep)
	if SHEAR_REWARD[kind] then
		local reward = SHEAR_REWARD[kind]
		local sp = addPrompt(body, "Shear Wool", "🐑 Sheep", Enum.KeyCode.E, 2, 8)
		sp.Triggered:Connect(function(player)
			local now = os.clock()
			if now - (rec.shearCooldown or 0) < SHEAR_CD then
				notify(player, string.format("⏳ %ds until wool grows back",
					math.ceil(SHEAR_CD - (now - rec.shearCooldown))), "Info")
				return
			end
			rec.shearCooldown = now
			addCoins(player, reward)
			notify(player, "✂ Sheared the sheep! +"..reward.." coins of wool", "Success")
		end)
	end

	-- Pick Up / Lead (small + medium: chicken, duck, pig, sheep, goat)
	if CARRY_OFFSET[kind] then
		local action = (kind == "chicken" or kind == "duck") and "Pick Up" or "Lead"
		local cap    = kind:sub(1,1):upper()..kind:sub(2)
		local pp = addPrompt(body, action, "🐾 "..cap, Enum.KeyCode.F, 0.5, 7)
		rec.pickupPrompt = pp
		local dp = addPrompt(body, "Put Down", "🐾 Drop "..cap, Enum.KeyCode.F, 0, 4)
		dp.Enabled = false
		rec.dropPrompt = dp
		pp.Triggered:Connect(function(player) carryStart(player, rec) end)
		dp.Triggered:Connect(function(player)
			if carriedAnimals[player] == rec then
				carryStop(rec)
				notify(player, "🐾 Released the "..kind..".", "Info")
			end
		end)
	end

	-- Direct Slaughter (large: cow, bull, horse — too big to carry)
	if not CARRY_OFFSET[kind] then
		local cap = kind:sub(1,1):upper()..kind:sub(2)
		local reward = SLAUGHTER_REWARD[kind] or 50
		local slp = addPrompt(body, "Slaughter", "🔪 "..cap, Enum.KeyCode.F, 2, 8)
		slp.Triggered:Connect(function(player)
			addCoins(player, reward)
			notify(player, "🥩 "..cap.." slaughtered! +"..reward.." coins", "Success")
			processSlaughter(rec)
		end)
	end
end

-- ── Wander AI ─────────────────────────────────────────────────────────────
local function wander(rec)
	task.spawn(function()
		local spec = rec.spec
		local px, pz = rec.body.Position.X, rec.body.Position.Z
		while rec.model and rec.model.Parent and not rec.slaughtered do
			if rec.carried then
				task.wait(0.1)
			else
				local tx, tz = randomInZone(spec.cx, spec.cz, spec.radius)
				local dx, dz = tx - px, tz - pz
				local dist   = math.sqrt(dx*dx + dz*dz)
				if dist > 0.5 then
					local nx, nz = dx/dist, dz/dist
					local steps  = math.max(1, math.ceil(dist / spec.speed * 10))
					local step   = dist / steps
					local dt     = (dist / spec.speed) / steps
					for _ = 1, steps do
						if rec.carried or rec.slaughtered or
							not rec.model or not rec.model.Parent then break end
						px = px + nx*step; pz = pz + nz*step
						pcall(function()
							rec.model:PivotTo(CFrame.lookAt(
								Vector3.new(px, rec.gy, pz),
								Vector3.new(px+nx, rec.gy, pz+nz)))
						end)
						task.wait(dt)
					end
				end
				task.wait(IDLE_MIN + math.random() * (IDLE_MAX - IDLE_MIN))
			end
		end
	end)
end

-- ── Slaughterhouse building ───────────────────────────────────────────────
local SLAUGHTER_POS = Vector3.new(52, 0, -22)

local function buildSlaughterhouse()
	local folder = Instance.new("Folder")
	folder.Name  = "FarmSlaughterhouse"
	folder.Parent = Workspace

	local cx, cz = SLAUGHTER_POS.X, SLAUGHTER_POS.Z

	local function mp(name, size, x, y, z, color, mat)
		local p = Instance.new("Part"); p.Name = name; p.Size = size
		p.CFrame = CFrame.new(x, y, z); p.Anchored = true
		p.Material = mat or Enum.Material.SmoothPlastic
		p.BrickColor = BrickColor.new(color)
		p.TopSurface = SP; p.BottomSurface = SP; p.Parent = folder; return p
	end

	-- Structure
	mp("WallFront", Vector3.new(12,10,1),   cx,   5,  cz-6,  "Dark red")
	mp("WallBack",  Vector3.new(12,10,1),   cx,   5,  cz+6,  "Dark red")
	mp("WallLeft",  Vector3.new(1, 10,12),  cx-6, 5,  cz,    "Dark red")
	mp("WallRight", Vector3.new(1, 10,12),  cx+6, 5,  cz,    "Dark red")
	mp("Roof",      Vector3.new(13,1,13),   cx,  10.5,cz,    "Dark grey")
	mp("Chimney",   Vector3.new(1.5,5,1.5), cx+3,13,  cz-2,  "Dark grey")
	mp("Floor",     Vector3.new(12,0.3,12), cx,  0.15,cz,    "Brown")
	-- Chimney smoke cap
	mp("ChimneyCap",Vector3.new(2.5,0.4,2.5),cx+3,15.7,cz-2,"Black")
	-- Decorative blood drain
	mp("Drain",     Vector3.new(1,0.2,6),   cx-5,0.2,cz,     "Dark red")

	-- Sign
	local sign = mp("Sign", Vector3.new(10, 2.5, 0.4), cx, 12, cz-6.3, "Dark red")
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.Parent = sign
	local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,0,1,0)
	lbl.BackgroundTransparency = 1; lbl.Text = "🥩 Slaughterhouse"
	lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.new(1,1,1); lbl.Parent = sg

	-- Sub-sign with instructions
	local sub = mp("SubSign", Vector3.new(10,1.5,0.3), cx, 9.2, cz-6.35, "Black")
	local sg2 = Instance.new("SurfaceGui"); sg2.Face = Enum.NormalId.Front; sg2.Parent = sub
	local lbl2 = Instance.new("TextLabel"); lbl2.Size = UDim2.new(1,0,1,0)
	lbl2.BackgroundTransparency = 1; lbl2.Text = "Pick up an animal → walk here → press E"
	lbl2.TextScaled = true; lbl2.Font = Enum.Font.Gotham
	lbl2.TextColor3 = Color3.fromRGB(255,200,100); lbl2.Parent = sg2

	-- Door (interaction part)
	local door = mp("Door", Vector3.new(4,6,0.5), cx, 3, cz-6.3, "Dark grey")
	local doorPrompt = addPrompt(door, "Process Animal", "🔪 Slaughterhouse",
		Enum.KeyCode.E, 1, 10)

	doorPrompt.Triggered:Connect(function(player)
		local rec = carriedAnimals[player]
		if not rec then
			notify(player, "❌ Pick up or lead an animal here first!", "Error")
			return
		end
		local reward = SLAUGHTER_REWARD[rec.kind] or 30
		local cap    = rec.kind:sub(1,1):upper()..rec.kind:sub(2)
		addCoins(player, reward)
		notify(player, "🥩 "..cap.." processed! +"..reward.." coins", "Success")
		carryStop(rec)
		processSlaughter(rec)
	end)

	print("[Animals] Slaughterhouse built at X="..cx..", Z="..cz)
end

-- ── Spawn one animal ──────────────────────────────────────────────────────
local animalFolder

spawnOneAnimal = function(spec)
	local ok, model = pcall(BUILDERS[spec.kind])
	if not ok or not model then
		warn("[Animals] Build "..spec.kind.." failed: "..tostring(model)); return
	end
	local gy = groundOffset(model)
	local sx, sz = randomInZone(spec.cx, spec.cz, spec.radius)
	pcall(function() model:PivotTo(CFrame.new(sx, gy, sz)) end)
	model.Name   = spec.kind.."_"..tostring(math.random(100,999))
	model.Parent = animalFolder or Workspace

	local rec = {
		model        = model,
		body         = model.PrimaryPart,
		kind         = spec.kind,
		spec         = spec,
		gy           = gy,
		carried      = false,
		carriedBy    = nil,
		slaughtered  = false,
		milkCooldown = 0,
		shearCooldown= 0,
	}

	attachSound(rec.body, spec.kind)
	setupInteractions(rec)
	if spec.kind == "chicken" or spec.kind == "duck" then
		startEggLayer(rec)
	end
	wander(rec)
	table.insert(animalRecords, rec)
	return rec
end

-- ── Player cleanup — drop animal on leave / death ────────────────────────
Players.PlayerRemoving:Connect(function(player)
	if carriedAnimals[player] then carryStop(carriedAnimals[player]) end
end)
Players.PlayerAdded:Connect(function(player)
	player.CharacterRemoving:Connect(function()
		if carriedAnimals[player] then carryStop(carriedAnimals[player]) end
	end)
end)

-- ── Boot ──────────────────────────────────────────────────────────────────
task.wait(2)

animalFolder = Instance.new("Folder")
animalFolder.Name   = "Animals"
animalFolder.Parent = Workspace

buildSlaughterhouse()

for _, spec in ipairs(SPECIES) do
	for i = 1, spec.count do
		local ok, err = pcall(spawnOneAnimal, spec)
		if not ok then warn("[Animals] "..spec.kind..i..": "..tostring(err)) end
		task.wait(0.04)
	end
	print(string.format("[Animals] %d %ss spawned at (%.0f,%.0f)",
		spec.count, spec.kind, spec.cx, spec.cz))
end

print("[Animals] All animals ready — Slaughterhouse at X="..SLAUGHTER_POS.X..", Z="..SLAUGHTER_POS.Z)
