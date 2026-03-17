-- AnimalManager.server.lua
-- 8 farm animal species with detailed sphere/cylinder bodies and
-- 3D spatial sounds. All zones within clear sight of the player farm.
--
-- World reference:  Spawn=(0,3,-28)  Barn=(X30,Z0)  Farm fence=±29 studs
--
-- Zones (all open, obstacle-free):
--   Chicken  : west  (X=-42, Z=-5 ) small coop area
--   Duck     : pond  (X=-25, Z=-18) near well
--   Sheep    : north (X=-10, Z= 42) open pasture
--   Goat     : NW    (X=-38, Z= 25) hillside
--   Pig      : east  (X= 48, Z= 15) pen right of barn
--   Cow      : NE    (X= 48, Z= 45) dairy pasture
--   Bull     : NE    (X= 60, Z= 20) bull paddock
--   Horse    : north (X= 20, Z= 55) paddock

local Workspace = game:GetService("Workspace")
math.randomseed(os.clock() * 1000)

-- ── Species config ────────────────────────────────────────────────────────
local SPECIES = {
	{ kind="chicken", count=7,  cx=-42, cz= -5, radius=11, speed=5.5 },
	{ kind="duck",    count=5,  cx=-25, cz=-18, radius= 8, speed=3.5 },
	{ kind="sheep",   count=5,  cx=-10, cz= 42, radius=14, speed=2.5 },
	{ kind="goat",    count=4,  cx=-38, cz= 25, radius=12, speed=4.0 },
	{ kind="pig",     count=4,  cx= 48, cz= 15, radius=11, speed=3.5 },
	{ kind="cow",     count=4,  cx= 48, cz= 45, radius=15, speed=2.0 },
	{ kind="bull",    count=2,  cx= 60, cz= 20, radius=10, speed=2.5 },
	{ kind="horse",   count=3,  cx= 20, cz= 55, radius=14, speed=6.0 },
}

local IDLE_MIN, IDLE_MAX = 1.5, 5

-- ── Sounds (spatial 3D — parented to animal body) ─────────────────────────
local SOUND_IDS = {
	chicken = "rbxassetid://3546745391",
	duck    = "rbxassetid://3546745391",   -- similar bird sound
	sheep   = "rbxassetid://7112263679",
	goat    = "rbxassetid://7112263679",
	pig     = "rbxassetid://6344318670",
	cow     = "rbxassetid://6344318670",   -- fallback — mooing
	bull    = "rbxassetid://6344318670",
	horse   = "rbxassetid://6344318670",
}

-- ─────────────────────────────────────────────────────────────────────────
--  Low-level part builders
-- ─────────────────────────────────────────────────────────────────────────
local SP, BK = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth

local function mkPart(model, name, color, mat)
	local p           = Instance.new("Part")
	p.Name            = name
	p.Size            = Vector3.new(1,1,1)
	p.BrickColor      = BrickColor.new(color)
	p.Material        = mat or Enum.Material.SmoothPlastic
	p.Anchored        = true
	p.CanCollide      = false
	p.CastShadow      = true
	p.TopSurface      = SP
	p.BottomSurface   = BK
	p.Parent          = model
	return p
end

local function sph(model, name, color, sx,sy,sz, ox,oy,oz, mat)
	local p = mkPart(model, name, color, mat)
	p.CFrame = CFrame.new(ox,oy,oz)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale    = Vector3.new(sx,sy,sz)
	m.Parent   = p
	return p
end

local function cyl(model, name, color, sx,sy,sz, ox,oy,oz, rx,ry,rz)
	local p = mkPart(model, name, color)
	p.CFrame = CFrame.new(ox,oy,oz) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Cylinder
	m.Scale    = Vector3.new(sx,sy,sz)
	m.Parent   = p
	return p
end

local function blk(model, name, color, sx,sy,sz, ox,oy,oz, rx,ry,rz, mat)
	local p = mkPart(model, name, color, mat)
	p.Size   = Vector3.new(sx,sy,sz)
	p.CFrame = CFrame.new(ox,oy,oz) * CFrame.Angles(rx or 0, ry or 0, rz or 0)
	return p
end

-- ─────────────────────────────────────────────────────────────────────────
--  Animal builders — all offsets relative to body centre (0,0,0)
-- ─────────────────────────────────────────────────────────────────────────

local function mkChicken()
	local m = Instance.new("Model"); m.Name = "Chicken"
	local body = sph(m,"Body","Bright yellow",   2.2,1.6,2.8,  0,  0,    0)
	             sph(m,"Head","Bright yellow",   1.3,1.3,1.3,  0,  1.3,  1.1)
	             sph(m,"Comb1","Bright red",     0.45,0.6,0.4,-0.2,2.05,1.1)
	             sph(m,"Comb2","Bright red",     0.55,0.75,0.5, 0, 2.2, 1.1)
	             sph(m,"Comb3","Bright red",     0.45,0.6,0.4,  0.2,2.05,1.1)
	             blk(m,"Beak","Bright orange",  0.35,0.25,0.45, 0, 1.15,1.72)
	             sph(m,"Wattle","Bright red",   0.3,0.4,0.3,   0,  0.8,  1.65)
	             sph(m,"WingL","CGA brown",     0.55,1.2,2.0, -1.2,0,    0)
	             sph(m,"WingR","CGA brown",     0.55,1.2,2.0,  1.2,0,    0)
	             cyl(m,"LegL","Bright orange",  0.3,0.3,1.9, -0.55,-1.3,0.2,0,0,math.rad(90))
	             cyl(m,"LegR","Bright orange",  0.3,0.3,1.9,  0.55,-1.3,0.2,0,0,math.rad(90))
	             sph(m,"TailA","CGA brown",     0.5,0.9,0.5,   0,  0.6, -1.3)
	             sph(m,"TailB","CGA brown",     0.4,0.7,0.4, -0.28,0.4,-1.38)
	             sph(m,"TailC","CGA brown",     0.4,0.7,0.4,  0.28,0.4,-1.38)
	m.PrimaryPart = body; return m
end

local function mkDuck()
	local m = Instance.new("Model"); m.Name = "Duck"
	local body = sph(m,"Body","Bright yellow",  1.8,1.3,2.4,  0,  0,    0)
	             sph(m,"Head","Earth green",    1.0,1.0,1.0,  0,  1.0,  0.95)  -- male mallard green head
	             cyl(m,"Bill","Bright orange",  0.8,0.8,0.6,  0,  0.75, 1.45, 0,0,math.rad(90))
	             sph(m,"Eye1","Black",          0.2,0.2,0.15,-0.38,1.1, 1.2)
	             sph(m,"Eye2","Black",          0.2,0.2,0.15, 0.38,1.1, 1.2)
	             sph(m,"WingL","Bright yellow", 0.4,0.9,1.8, -0.95,0.1,  0)
	             sph(m,"WingR","Bright yellow", 0.4,0.9,1.8,  0.95,0.1,  0)
	             cyl(m,"LegL","Bright orange",  0.25,0.25,1.3,-0.4,-1.0, 0.1, 0,0,math.rad(90))
	             cyl(m,"LegR","Bright orange",  0.25,0.25,1.3, 0.4,-1.0, 0.1, 0,0,math.rad(90))
	             sph(m,"Tail","White",          0.5,0.6,0.5,   0,  0.3, -1.2)
	m.PrimaryPart = body; return m
end

local function mkSheep()
	local m = Instance.new("Model"); m.Name = "Sheep"
	local body = sph(m,"Wool","White",4.2,3.2,5.5, 0,0,0, Enum.Material.Fabric)
	             sph(m,"Head","Medium stone grey",1.8,1.8,1.9, 0,1.8,2.8)
	             sph(m,"Nose","Pastel brown",    0.9,0.7,0.6,   0,  1.45, 3.5)
	             sph(m,"NL","Black",             0.2,0.2,0.2, -0.22,1.38,3.8)
	             sph(m,"NR","Black",             0.2,0.2,0.2,  0.22,1.38,3.8)
	             sph(m,"EyeL","Black",           0.32,0.32,0.2,-0.65,2.05,3.2)
	             sph(m,"EyeR","Black",           0.32,0.32,0.2, 0.65,2.05,3.2)
	             sph(m,"EarL","Medium stone grey",0.55,1.1,0.4,-1.0,2.0,2.6)
	             sph(m,"EarR","Medium stone grey",0.55,1.1,0.4, 1.0,2.0,2.6)
	             cyl(m,"LL1","Dark grey",0.6,0.6,2.8,-1.2,-2.6,-1.2,math.rad(90),0,0)
	             cyl(m,"LL2","Dark grey",0.6,0.6,2.8, 1.2,-2.6,-1.2,math.rad(90),0,0)
	             cyl(m,"LL3","Dark grey",0.6,0.6,2.8,-1.2,-2.6, 1.2,math.rad(90),0,0)
	             cyl(m,"LL4","Dark grey",0.6,0.6,2.8, 1.2,-2.6, 1.2,math.rad(90),0,0)
	             sph(m,"HoofFL","Black",0.65,0.4,0.65,-1.2,-3.55,-1.2)
	             sph(m,"HoofFR","Black",0.65,0.4,0.65, 1.2,-3.55,-1.2)
	             sph(m,"HoofBL","Black",0.65,0.4,0.65,-1.2,-3.55, 1.2)
	             sph(m,"HoofBR","Black",0.65,0.4,0.65, 1.2,-3.55, 1.2)
	             sph(m,"Tail","White",0.8,0.8,0.8, 0,0.5,-2.8, Enum.Material.Fabric)
	m.PrimaryPart = body; return m
end

local function mkGoat()
	local m = Instance.new("Model"); m.Name = "Goat"
	local body = sph(m,"Body","Light grey",      3.0,2.0,4.0,  0,  0,    0)
	             sph(m,"Head","Light grey",      1.5,1.4,1.6,   0,  1.4,  2.1)
	             sph(m,"Muzzle","White",         0.8,0.65,0.6,  0,  1.0,  2.75)
	             sph(m,"NL","Black",             0.18,0.18,0.15,-0.22,0.95,3.05)
	             sph(m,"NR","Black",             0.18,0.18,0.15, 0.22,0.95,3.05)
	             sph(m,"EyeL","Black",           0.28,0.28,0.18,-0.6,1.65,2.5)
	             sph(m,"EyeR","Black",           0.28,0.28,0.18, 0.6,1.65,2.5)
	             -- Curved horns
	             cyl(m,"HornL","Ivory",0.25,0.25,1.2,-0.5,2.4,1.9, math.rad(-30),0,math.rad(-20))
	             cyl(m,"HornR","Ivory",0.25,0.25,1.2, 0.5,2.4,1.9, math.rad(-30),0,math.rad( 20))
	             -- Beard
	             blk(m,"Beard","Light grey",     0.25,0.7,0.25,  0,  0.5,  3.0)
	             -- Ears
	             sph(m,"EarL","Light grey",      0.4,0.85,0.3, -0.9,1.8,2.0)
	             sph(m,"EarR","Light grey",      0.4,0.85,0.3,  0.9,1.8,2.0)
	             -- Legs
	             cyl(m,"LF1","Light grey",0.45,0.45,2.2,-0.85,-1.6,-1.1,math.rad(90),0,0)
	             cyl(m,"LF2","Light grey",0.45,0.45,2.2, 0.85,-1.6,-1.1,math.rad(90),0,0)
	             cyl(m,"LB1","Light grey",0.45,0.45,2.2,-0.85,-1.6, 1.1,math.rad(90),0,0)
	             cyl(m,"LB2","Light grey",0.45,0.45,2.2, 0.85,-1.6, 1.1,math.rad(90),0,0)
	             sph(m,"Tail","White",           0.5,0.5,0.5,   0,  0.4, -2.1)
	m.PrimaryPart = body; return m
end

local function mkPig()
	local m = Instance.new("Model"); m.Name = "Pig"
	local body = sph(m,"Body","Pastel orange",   3.5,2.6,4.8,  0,  0,    0)
	             sph(m,"Head","Pastel orange",   2.4,2.3,2.4,   0,  1.0,  2.4)
	             cyl(m,"Snout","Carnation pink", 1.6,1.6,0.6,   0,  0.7,  3.65, 0,0,math.rad(90))
	             sph(m,"NL","Pastel brown",      0.4,0.4,0.25,-0.38,0.65,3.97)
	             sph(m,"NR","Pastel brown",      0.4,0.4,0.25, 0.38,0.65,3.97)
	             sph(m,"EyeL","Black",           0.45,0.45,0.3,-0.85,1.55,3.25)
	             sph(m,"EyeR","Black",           0.45,0.45,0.3, 0.85,1.55,3.25)
	             sph(m,"EarL","Pastel orange",   0.9,1.4,0.5,  -1.1,2.4,  2.2)
	             sph(m,"EarR","Pastel orange",   0.9,1.4,0.5,   1.1,2.4,  2.2)
	             sph(m,"IEarL","Carnation pink", 0.5,0.9,0.3,  -1.1,2.4,  2.2)
	             sph(m,"IEarR","Carnation pink", 0.5,0.9,0.3,   1.1,2.4,  2.2)
	             cyl(m,"LegFL","Pastel orange",  0.75,0.75,2.5,-1.1,-2.0,-1.3,math.rad(90),0,0)
	             cyl(m,"LegFR","Pastel orange",  0.75,0.75,2.5, 1.1,-2.0,-1.3,math.rad(90),0,0)
	             cyl(m,"LegBL","Pastel orange",  0.75,0.75,2.5,-1.1,-2.0, 1.3,math.rad(90),0,0)
	             cyl(m,"LegBR","Pastel orange",  0.75,0.75,2.5, 1.1,-2.0, 1.3,math.rad(90),0,0)
	             sph(m,"HFL","Black",0.8,0.5,0.8,-1.1,-3.3,-1.3)
	             sph(m,"HFR","Black",0.8,0.5,0.8, 1.1,-3.3,-1.3)
	             sph(m,"HBL","Black",0.8,0.5,0.8,-1.1,-3.3, 1.3)
	             sph(m,"HBR","Black",0.8,0.5,0.8, 1.1,-3.3, 1.3)
	             cyl(m,"Tail1","Pastel orange",  0.35,0.35,1.2, 0,0.6,-2.6, math.rad(-40),0,0)
	             cyl(m,"Tail2","Carnation pink", 0.25,0.25,0.9, 0,1.3,-2.95,math.rad(-60),0,math.rad(30))
	m.PrimaryPart = body; return m
end

local function mkCow()
	local m = Instance.new("Model"); m.Name = "Cow"
	-- Holstein black-and-white patches approximated
	local body = sph(m,"Body","White",           5.5,3.5,7.5,   0,  0,    0)
	             -- Black patches
	             sph(m,"PatchA","Black",          2.5,2.0,2.8,  -1.5,0.8,  1.5)
	             sph(m,"PatchB","Black",          2.0,1.5,2.0,   1.0,-0.5, -1.8)
	             sph(m,"PatchC","Black",          1.5,1.2,1.8,  -0.5,1.2,  -2.0)
	             -- Neck
	             cyl(m,"Neck","White",            1.4,1.4,2.5,   0,  2.0,  3.5, math.rad(-40),0,0)
	             -- Head
	             sph(m,"Head","White",            2.0,1.9,2.2,   0,  3.1,  5.0)
	             -- Muzzle
	             sph(m,"Muzzle","Pastel orange",  1.4,1.0,1.0,   0,  2.65, 6.0)
	             sph(m,"NL","Black",              0.3,0.3,0.22, -0.38,2.55,6.55)
	             sph(m,"NR","Black",              0.3,0.3,0.22,  0.38,2.55,6.55)
	             sph(m,"EyeL","Black",            0.5,0.5,0.3,  -0.9,3.4,  5.5)
	             sph(m,"EyeR","Black",            0.5,0.5,0.3,   0.9,3.4,  5.5)
	             -- Ears
	             sph(m,"EarL","White",            0.7,1.4,0.5,  -1.1,3.7,  4.8)
	             sph(m,"EarR","White",            0.7,1.4,0.5,   1.1,3.7,  4.8)
	             -- Horns (short)
	             cyl(m,"HornL","Ivory",0.3,0.3,1.5,-0.85,4.3,4.75,math.rad(-10),0,math.rad(-35))
	             cyl(m,"HornR","Ivory",0.3,0.3,1.5, 0.85,4.3,4.75,math.rad(-10),0,math.rad( 35))
	             -- Legs
	             cyl(m,"LegFL","White",1.0,1.0,4.2,-1.5,-2.8,-2.2,math.rad(90),0,0)
	             cyl(m,"LegFR","White",1.0,1.0,4.2, 1.5,-2.8,-2.2,math.rad(90),0,0)
	             cyl(m,"LegBL","White",1.0,1.0,4.2,-1.5,-2.8, 2.2,math.rad(90),0,0)
	             cyl(m,"LegBR","White",1.0,1.0,4.2, 1.5,-2.8, 2.2,math.rad(90),0,0)
	             sph(m,"HFL","Black",1.1,0.7,1.1,-1.5,-5.1,-2.2)
	             sph(m,"HFR","Black",1.1,0.7,1.1, 1.5,-5.1,-2.2)
	             sph(m,"HBL","Black",1.1,0.7,1.1,-1.5,-5.1, 2.2)
	             sph(m,"HBR","Black",1.1,0.7,1.1, 1.5,-5.1, 2.2)
	             -- Udder
	             sph(m,"Udder","Carnation pink",  2.0,1.2,1.8,   0, -2.3,  1.5)
	             cyl(m,"TeatFL","Carnation pink", 0.28,0.28,0.7,-0.5,-3.2,1.0,math.rad(90),0,0)
	             cyl(m,"TeatFR","Carnation pink", 0.28,0.28,0.7, 0.5,-3.2,1.0,math.rad(90),0,0)
	             cyl(m,"TeatBL","Carnation pink", 0.28,0.28,0.7,-0.5,-3.2,2.0,math.rad(90),0,0)
	             cyl(m,"TeatBR","Carnation pink", 0.28,0.28,0.7, 0.5,-3.2,2.0,math.rad(90),0,0)
	             -- Tail
	             cyl(m,"Tail","White",0.4,0.4,3.5, 0,1.5,-3.8,math.rad(-60),0,0)
	             sph(m,"TailTip","Black",0.8,1.4,0.8, 0,-0.1,-5.5)
	m.PrimaryPart = body; return m
end

local function mkBull()
	local m = Instance.new("Model"); m.Name = "Bull"
	local body = sph(m,"Body","Reddish brown",   6.5,4.5,9.0,   0,  0,    0)
	             -- Massive muscular hump
	             sph(m,"Hump","Dark orange",      3.5,3.0,3.5,   0,  3.0, -1.5)
	             cyl(m,"Neck","Reddish brown",    2.0,2.0,3.8,   0,  3.5,  4.0, math.rad(-30),0,0)
	             sph(m,"Head","Reddish brown",    2.8,2.5,3.0,   0,  4.5,  6.2)
	             sph(m,"Muzzle","Pastel brown",   1.8,1.3,1.3,   0,  3.9,  7.4)
	             sph(m,"NL","Black",0.38,0.38,0.28,-0.45,3.75,7.95)
	             sph(m,"NR","Black",0.38,0.38,0.28, 0.45,3.75,7.95)
	             sph(m,"EyeL","Black",0.6,0.6,0.38,-1.1,4.85,6.8)
	             sph(m,"EyeR","Black",0.6,0.6,0.38, 1.1,4.85,6.8)
	             sph(m,"EarL","Reddish brown",0.8,1.6,0.6,-1.4,5.5,6.0)
	             sph(m,"EarR","Reddish brown",0.8,1.6,0.6, 1.4,5.5,6.0)
	             -- Long sweeping horns
	             cyl(m,"HornL","Ivory",0.4,0.4,3.0,-1.0,5.9,6.1,math.rad(-5),0,math.rad(-50))
	             cyl(m,"HornTL","Ivory",0.28,0.28,1.5,-2.9,5.5,6.2,math.rad(20),0,math.rad(-70))
	             cyl(m,"HornR","Ivory",0.4,0.4,3.0, 1.0,5.9,6.1,math.rad(-5),0,math.rad( 50))
	             cyl(m,"HornTR","Ivory",0.28,0.28,1.5, 2.9,5.5,6.2,math.rad(20),0,math.rad( 70))
	             cyl(m,"LegFL","Reddish brown",1.4,1.4,5.5,-2.0,-3.5,-2.8,math.rad(90),0,0)
	             cyl(m,"LegFR","Reddish brown",1.4,1.4,5.5, 2.0,-3.5,-2.8,math.rad(90),0,0)
	             cyl(m,"LegBL","Reddish brown",1.4,1.4,5.5,-2.0,-3.5, 2.8,math.rad(90),0,0)
	             cyl(m,"LegBR","Reddish brown",1.4,1.4,5.5, 2.0,-3.5, 2.8,math.rad(90),0,0)
	             sph(m,"HFL","Black",1.5,1.0,1.5,-2.0,-6.5,-2.8)
	             sph(m,"HFR","Black",1.5,1.0,1.5, 2.0,-6.5,-2.8)
	             sph(m,"HBL","Black",1.5,1.0,1.5,-2.0,-6.5, 2.8)
	             sph(m,"HBR","Black",1.5,1.0,1.5, 2.0,-6.5, 2.8)
	             cyl(m,"Tail","Reddish brown",0.5,0.5,4.5, 0,2.0,-4.5,math.rad(-55),0,0)
	             sph(m,"TailTip","Black",1.0,1.8,1.0, 0,-0.5,-6.8)
	m.PrimaryPart = body; return m
end

local function mkHorse()
	local m = Instance.new("Model"); m.Name = "Horse"
	local body = sph(m,"Body","Reddish brown",   4.5,3.8,8.0,   0,  0,    0)
	             -- Long neck
	             cyl(m,"Neck","Reddish brown",   2.0,2.0,5.5,   0,  4.0,  3.8, math.rad(-55),0,0)
	             sph(m,"Head","Reddish brown",   2.2,2.2,3.2,   0,  6.0,  6.0)
	             sph(m,"Muzzle","Pastel brown",  1.5,1.1,1.2,   0,  5.3,  7.5)
	             sph(m,"NL","Black",0.32,0.32,0.24,-0.38,5.12,8.1)
	             sph(m,"NR","Black",0.32,0.32,0.24, 0.38,5.12,8.1)
	             sph(m,"EyeL","Black",0.55,0.55,0.35,-1.0,6.5,6.8)
	             sph(m,"EyeR","Black",0.55,0.55,0.35, 1.0,6.5,6.8)
	             sph(m,"EarL","Reddish brown",0.5,1.2,0.4,-0.8,7.5,5.8)
	             sph(m,"EarR","Reddish brown",0.5,1.2,0.4, 0.8,7.5,5.8)
	             -- Mane (dark strip along neck top)
	             blk(m,"Mane","Black",           0.45,0.6,4.5,  0,  6.2,  4.5, math.rad(-55),0,0, Enum.Material.Fabric)
	             blk(m,"Forelock","Black",       0.45,1.5,0.4,  0,  7.5,  6.0,0,0,0, Enum.Material.Fabric)
	             -- Long legs
	             cyl(m,"LegFL","Reddish brown",0.9,0.9,6.5,-1.5,-4.0,-2.5,math.rad(90),0,0)
	             cyl(m,"LegFR","Reddish brown",0.9,0.9,6.5, 1.5,-4.0,-2.5,math.rad(90),0,0)
	             cyl(m,"LegBL","Reddish brown",0.9,0.9,6.5,-1.5,-4.0, 2.5,math.rad(90),0,0)
	             cyl(m,"LegBR","Reddish brown",0.9,0.9,6.5, 1.5,-4.0, 2.5,math.rad(90),0,0)
	             sph(m,"HFL","Black",1.0,0.7,1.0,-1.5,-7.3,-2.5)
	             sph(m,"HFR","Black",1.0,0.7,1.0, 1.5,-7.3,-2.5)
	             sph(m,"HBL","Black",1.0,0.7,1.0,-1.5,-7.3, 2.5)
	             sph(m,"HBR","Black",1.0,0.7,1.0, 1.5,-7.3, 2.5)
	             -- Flowing tail
	             cyl(m,"Tail1","Black",0.55,0.55,5.0, 0,2.0,-4.1,math.rad(-70),0,0)
	             cyl(m,"Tail2","Black",0.45,0.45,4.0, 0.4,-1.2,-6.5,math.rad(-85),0,math.rad(10))
	             cyl(m,"Tail3","Black",0.35,0.35,4.0,-0.4,-1.2,-6.5,math.rad(-85),0,math.rad(-10))
	m.PrimaryPart = body; return m
end

-- ─────────────────────────────────────────────────────────────────────────
--  Ground offset
-- ─────────────────────────────────────────────────────────────────────────
local function groundOffset(model)
	local pivotY = model.PrimaryPart and model.PrimaryPart.Position.Y or 0
	local minY   = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local mesh  = p:FindFirstChildOfClass("SpecialMesh")
			local halfH = mesh and (p.Size.Y * mesh.Scale.Y * 0.5) or (p.Size.Y * 0.5)
			minY = math.min(minY, p.Position.Y - halfH)
		end
	end
	return (minY == math.huge) and 1 or math.max(0.3, pivotY - minY)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Spatial sound
-- ─────────────────────────────────────────────────────────────────────────
local function attachSound(body, kind)
	local id = SOUND_IDS[kind]; if not id then return end
	local s = Instance.new("Sound")
	s.SoundId             = id
	s.Volume              = 0.6
	s.RollOffMode         = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance  = 10
	s.RollOffMaxDistance  = 70
	s.Parent              = body
	task.spawn(function()
		while body and body.Parent do
			task.wait(6 + math.random() * 12)
			if body and body.Parent then s:Play() end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Wander AI
-- ─────────────────────────────────────────────────────────────────────────
local function randomInZone(cx,cz,r)
	local a = math.random()*math.pi*2
	local d = math.sqrt(math.random())*r
	return cx+math.cos(a)*d, cz+math.sin(a)*d
end

local function wander(model, spec, gy)
	local sx,sz = randomInZone(spec.cx,spec.cz,spec.radius)
	pcall(function() model:PivotTo(CFrame.new(sx,gy,sz)) end)
	task.spawn(function()
		local px,pz = sx,sz
		while model and model.Parent do
			local tx,tz = randomInZone(spec.cx,spec.cz,spec.radius)
			local dx,dz = tx-px, tz-pz
			local dist  = math.sqrt(dx*dx+dz*dz)
			if dist > 0.5 then
				local nx,nz = dx/dist, dz/dist
				local steps = math.max(1,math.ceil(dist/spec.speed*10))
				local step  = dist/steps
				local dt    = (dist/spec.speed)/steps
				for _ = 1,steps do
					if not model or not model.Parent then return end
					px=px+nx*step; pz=pz+nz*step
					pcall(function()
						model:PivotTo(CFrame.lookAt(
							Vector3.new(px,gy,pz),
							Vector3.new(px+nx,gy,pz+nz)))
					end)
					task.wait(dt)
				end
			end
			task.wait(IDLE_MIN+math.random()*(IDLE_MAX-IDLE_MIN))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Builders table
-- ─────────────────────────────────────────────────────────────────────────
local BUILDERS = {
	chicken=mkChicken, duck=mkDuck, sheep=mkSheep, goat=mkGoat,
	pig=mkPig, cow=mkCow, bull=mkBull, horse=mkHorse,
}

-- ─────────────────────────────────────────────────────────────────────────
--  Spawn
-- ─────────────────────────────────────────────────────────────────────────
task.wait(2)

local folder = Instance.new("Folder")
folder.Name  = "Animals"
folder.Parent = Workspace

for _, spec in ipairs(SPECIES) do
	local ok, tmpl = pcall(BUILDERS[spec.kind])
	if not ok then
		warn("[Animals] Build "..spec.kind.." failed: "..tostring(tmpl)); continue
	end
	local gy = groundOffset(tmpl)
	for i = 1, spec.count do
		local ok2,err = pcall(function()
			local clone = tmpl:Clone()
			clone.Name  = spec.kind..i
			clone.Parent = folder
			attachSound(clone.PrimaryPart, spec.kind)
			wander(clone, spec, gy)
		end)
		if not ok2 then warn("[Animals] Spawn "..spec.kind..i..": "..tostring(err)) end
		task.wait(0.04)
	end
	tmpl:Destroy()
	print(string.format("[Animals] %d %ss at (%.0f,%.0f)", spec.count, spec.kind, spec.cx, spec.cz))
end
