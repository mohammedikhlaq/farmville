-- AnimalManager.server.lua
-- Realistic-ish farm animals using SpecialMesh (Sphere + Cylinder) parts.
-- 3D spatial sounds fade with distance — no special Studio settings needed.
--
-- World layout reference (from Main.server.lua):
--   Spawn  : (0, ~3, -28)  Player faces +Z (north)
--   Farm   : X ±29, Z ±29  (fenced grid, centre at origin)
--   Barn   : X 20-40, Z -10 to +10
--   Well   : X -18, Z -8
--
-- Animal zones are placed in OPEN SPACE outside buildings:
--   Chickens : west field  (X=-45, Z=0)   — left of well, fully open
--   Sheep    : north field (X=0,   Z=45)  — north of farm, open pasture
--   Pigs     : east field  (X=55,  Z=10)  — east of barn, open pen

local Workspace = game:GetService("Workspace")
math.randomseed(os.clock() * 1000)

-- ── Zones ────────────────────────────────────────────────────────────────
local ZONES = {
	chicken = { cx = -45, cz =   0, radius = 12 },
	sheep   = { cx =   0, cz =  45, radius = 16 },
	pig     = { cx =  55, cz =  10, radius = 11 },
}

local COUNTS = { chicken = 6, sheep = 4, pig = 3 }
local SPEEDS = { chicken = 5, sheep = 2.5, pig = 3.5 }
local IDLE_MIN, IDLE_MAX = 1.5, 4

-- ── Free Roblox sound IDs ─────────────────────────────────────────────────
local SOUNDS = {
	chicken = { id = "rbxassetid://3546745391", volume = 0.6, pitch = 1.0 },
	sheep   = { id = "rbxassetid://7112263679", volume = 0.5, pitch = 1.2 },  -- goat/sheep bleat
	pig     = { id = "rbxassetid://6344318670", volume = 0.6, pitch = 1.0 },
}

-- ─────────────────────────────────────────────────────────────────────────
--  Part builders
-- ─────────────────────────────────────────────────────────────────────────
local function base(model, name, color, material, ox, oy, oz)
	local p           = Instance.new("Part")
	p.Name            = name
	p.Size            = Vector3.new(1, 1, 1)
	p.CFrame          = CFrame.new(ox, oy, oz)
	p.BrickColor      = BrickColor.new(color)
	p.Material        = material or Enum.Material.SmoothPlastic
	p.Anchored        = true
	p.CanCollide      = false
	p.CastShadow      = true
	p.TopSurface      = Enum.SurfaceType.Smooth
	p.BottomSurface   = Enum.SurfaceType.Smooth
	p.Parent          = model
	return p
end

local function sphere(model, name, color, sx, sy, sz, ox, oy, oz, mat)
	local p  = base(model, name, color, mat, ox, oy, oz)
	local m  = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Scale    = Vector3.new(sx, sy, sz)
	m.Parent   = p
	return p
end

local function cylinder(model, name, color, sx, sy, sz, ox, oy, oz, ax, ay, az)
	local p  = base(model, name, color, nil, ox, oy, oz)
	if ax then p.CFrame = CFrame.new(ox, oy, oz) * CFrame.Angles(ax, ay, az) end
	local m  = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Cylinder
	m.Scale    = Vector3.new(sx, sy, sz)
	m.Parent   = p
	return p
end

local function block(model, name, color, sx, sy, sz, ox, oy, oz, mat)
	local p  = base(model, name, color, mat, ox, oy, oz)
	p.Size   = Vector3.new(sx, sy, sz)
	return p
end

-- ─────────────────────────────────────────────────────────────────────────
--  Animal builders  (all offsets relative to body centre = 0,0,0)
-- ─────────────────────────────────────────────────────────────────────────
local function buildChicken()
	local m = Instance.new("Model"); m.Name = "Chicken"
	-- Body — plump yellow oval
	local body = sphere(m,"Body","Bright yellow", 2.2,1.6,2.8,  0,  0,    0)
	-- Head
	             sphere(m,"Head","Bright yellow", 1.3,1.3,1.3,  0,  1.3,  1.1)
	-- Red comb (3 small spheres)
	             sphere(m,"Comb1","Bright red",   0.4,0.55,0.4, -0.25,2.05,1.1)
	             sphere(m,"Comb2","Bright red",   0.5,0.7, 0.5,  0,   2.15,1.1)
	             sphere(m,"Comb3","Bright red",   0.4,0.55,0.4,  0.25,2.05,1.1)
	-- Beak
	             block (m,"Beak","Bright orange",  0.35,0.25,0.45, 0, 1.15,1.72)
	-- Wattle (red chin blob)
	             sphere(m,"Wattle","Bright red",  0.3,0.4, 0.3,  0,  0.8,  1.65)
	-- Wings
	             sphere(m,"WingL","CGA brown",    0.6,1.2, 2.0, -1.2, 0,   0)
	             sphere(m,"WingR","CGA brown",    0.6,1.2, 2.0,  1.2, 0,   0)
	-- Legs (cylinders rotated vertical)
	             cylinder(m,"LegL","Bright orange",0.3,0.3,1.8, -0.55,-1.25, 0.2,
	                      0,0,math.rad(90))
	             cylinder(m,"LegR","Bright orange",0.3,0.3,1.8,  0.55,-1.25, 0.2,
	                      0,0,math.rad(90))
	-- Tail feathers
	             sphere(m,"Tail1","CGA brown",    0.5,0.9, 0.5,  0,   0.6, -1.3)
	             sphere(m,"Tail2","CGA brown",    0.45,0.7,0.45,-0.3,  0.4, -1.35)
	             sphere(m,"Tail3","CGA brown",    0.45,0.7,0.45, 0.3,  0.4, -1.35)
	m.PrimaryPart = body
	return m
end

local function buildSheep()
	local m = Instance.new("Model"); m.Name = "Sheep"
	-- Woolly body — large white fluffy sphere, Fabric material
	local body = sphere(m,"Wool","White",          4.2,3.2,5.5,  0,  0,    0, Enum.Material.Fabric)
	-- Head — dark grey, outside the wool
	             sphere(m,"Head","Medium stone grey",1.8,1.8,1.9, 0,  1.8,  2.8)
	-- Nose
	             sphere(m,"Nose","Pastel brown",   0.9,0.7, 0.6,  0,  1.45, 3.5)
	-- Nostrils (tiny dark spheres)
	             sphere(m,"NL","Black",            0.2,0.2, 0.2, -0.22,1.38,3.8)
	             sphere(m,"NR","Black",            0.2,0.2, 0.2,  0.22,1.38,3.8)
	-- Eyes
	             sphere(m,"EyeL","Black",          0.3,0.3, 0.2, -0.65,2.05,3.2)
	             sphere(m,"EyeR","Black",          0.3,0.3, 0.2,  0.65,2.05,3.2)
	-- Floppy ears
	             sphere(m,"EarL","Medium stone grey",0.55,1.1,0.4,-1.0, 2.0,  2.6)
	             sphere(m,"EarR","Medium stone grey",0.55,1.1,0.4, 1.0, 2.0,  2.6)
	-- Legs — dark, stick out from under wool
	             cylinder(m,"LL1","Dark grey",     0.6,0.6,2.8, -1.2,-2.6,-1.2, math.rad(90),0,0)
	             cylinder(m,"LL2","Dark grey",     0.6,0.6,2.8,  1.2,-2.6,-1.2, math.rad(90),0,0)
	             cylinder(m,"LL3","Dark grey",     0.6,0.6,2.8, -1.2,-2.6, 1.2, math.rad(90),0,0)
	             cylinder(m,"LL4","Dark grey",     0.6,0.6,2.8,  1.2,-2.6, 1.2, math.rad(90),0,0)
	-- Hooves
	             sphere(m,"HoofLL","Black",        0.65,0.4,0.65,-1.2,-3.55,-1.2)
	             sphere(m,"HoofLR","Black",        0.65,0.4,0.65, 1.2,-3.55,-1.2)
	             sphere(m,"HoofRL","Black",        0.65,0.4,0.65,-1.2,-3.55, 1.2)
	             sphere(m,"HoofRR","Black",        0.65,0.4,0.65, 1.2,-3.55, 1.2)
	-- Tail puff
	             sphere(m,"Tail","White",          0.8,0.8,0.8,  0,  0.5,  -2.8, Enum.Material.Fabric)
	m.PrimaryPart = body
	return m
end

local function buildPig()
	local m = Instance.new("Model"); m.Name = "Pig"
	-- Body — barrel-shaped pink sphere
	local body = sphere(m,"Body","Pastel orange",  3.5,2.6,4.8,  0,  0,    0)
	-- Head — large round
	             sphere(m,"Head","Pastel orange",  2.4,2.3,2.4,  0,  1.0,  2.4)
	-- Snout — flat disc
	             cylinder(m,"Snout","Carnation pink",1.6,1.6,0.6, 0,  0.7,  3.65,0,0,math.rad(90))
	-- Nostrils
	             sphere(m,"NL","Pastel brown",     0.4,0.4,0.25,-0.38,0.65,3.97)
	             sphere(m,"NR","Pastel brown",     0.4,0.4,0.25, 0.38,0.65,3.97)
	-- Eyes
	             sphere(m,"EyeL","Black",          0.45,0.45,0.3,-0.85,1.55,3.25)
	             sphere(m,"EyeR","Black",          0.45,0.45,0.3, 0.85,1.55,3.25)
	-- Ears — large floppy
	             sphere(m,"EarL","Pastel orange",  0.9,1.4, 0.5, -1.1, 2.4,  2.2)
	             sphere(m,"EarR","Pastel orange",  0.9,1.4, 0.5,  1.1, 2.4,  2.2)
	-- Inner ears
	             sphere(m,"IEarL","Carnation pink",0.5,0.9, 0.3,-1.1, 2.4,  2.2)
	             sphere(m,"IEarR","Carnation pink",0.5,0.9, 0.3, 1.1, 2.4,  2.2)
	-- Legs — short and stubby
	             cylinder(m,"LegFL","Pastel orange",0.75,0.75,2.4,-1.1,-2.0,-1.3,math.rad(90),0,0)
	             cylinder(m,"LegFR","Pastel orange",0.75,0.75,2.4, 1.1,-2.0,-1.3,math.rad(90),0,0)
	             cylinder(m,"LegBL","Pastel orange",0.75,0.75,2.4,-1.1,-2.0, 1.3,math.rad(90),0,0)
	             cylinder(m,"LegBR","Pastel orange",0.75,0.75,2.4, 1.1,-2.0, 1.3,math.rad(90),0,0)
	-- Hooves
	             sphere(m,"HFL","Black",           0.8,0.5,0.8, -1.1,-3.25,-1.3)
	             sphere(m,"HFR","Black",           0.8,0.5,0.8,  1.1,-3.25,-1.3)
	             sphere(m,"HBL","Black",           0.8,0.5,0.8, -1.1,-3.25, 1.3)
	             sphere(m,"HBR","Black",           0.8,0.5,0.8,  1.1,-3.25, 1.3)
	-- Curly tail (two angled cylinders)
	             cylinder(m,"Tail1","Pastel orange",0.35,0.35,1.2, 0,0.6,-2.6,
	                      math.rad(-40),0,0)
	             cylinder(m,"Tail2","Carnation pink",0.25,0.25,0.9, 0,1.3,-2.95,
	                      math.rad(-60),0,math.rad(30))
	m.PrimaryPart = body
	return m
end

-- ─────────────────────────────────────────────────────────────────────────
--  Ground offset — pivot height so model's lowest point sits at Y=0
-- ─────────────────────────────────────────────────────────────────────────
local function groundOffset(model)
	local pivotY = model.PrimaryPart and model.PrimaryPart.Position.Y or 0
	local minY   = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local mesh  = p:FindFirstChildOfClass("SpecialMesh")
			local halfH = mesh
				and (p.Size.Y * mesh.Scale.Y * 0.5)
				or  (p.Size.Y * 0.5)
			minY = math.min(minY, p.Position.Y - halfH)
		end
	end
	return (minY == math.huge) and 1 or math.max(0.5, pivotY - minY)
end

-- ─────────────────────────────────────────────────────────────────────────
--  3D spatial sound — attach to animal's body, plays periodically
-- ─────────────────────────────────────────────────────────────────────────
local function attachSound(body, kind)
	local s = SOUNDS[kind]
	if not s then return end

	local sound                 = Instance.new("Sound")
	sound.Name                  = "AnimalSound"
	sound.SoundId               = s.id
	sound.Volume                = s.volume
	sound.PlaybackSpeed         = s.pitch
	sound.RollOffMode           = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance    = 10   -- full volume within 10 studs
	sound.RollOffMaxDistance    = 60   -- silent beyond 60 studs
	sound.Parent                = body -- parented to Part = auto 3D spatial

	-- Play randomly every 5-15 seconds
	task.spawn(function()
		while body and body.Parent do
			task.wait(5 + math.random() * 10)
			if body and body.Parent then
				sound:Play()
			end
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Wander AI
-- ─────────────────────────────────────────────────────────────────────────
local function randomInZone(zone)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * zone.radius
	return zone.cx + math.cos(a) * r,
	       zone.cz + math.sin(a) * r
end

local function startWander(model, kind, zone, gy)
	local speed  = SPEEDS[kind]
	local sx, sz = randomInZone(zone)
	pcall(function() model:PivotTo(CFrame.new(sx, gy, sz)) end)

	task.spawn(function()
		local px, pz = sx, sz
		while model and model.Parent do
			local tx, tz = randomInZone(zone)
			local dx, dz = tx - px, tz - pz
			local dist   = math.sqrt(dx*dx + dz*dz)
			if dist > 0.5 then
				local nx, nz = dx/dist, dz/dist
				local steps  = math.max(1, math.ceil(dist/speed*10))
				local step   = dist/steps
				local dt     = (dist/speed)/steps
				for _ = 1, steps do
					if not model or not model.Parent then return end
					px = px + nx * step
					pz = pz + nz * step
					pcall(function()
						model:PivotTo(CFrame.lookAt(
							Vector3.new(px, gy, pz),
							Vector3.new(px+nx, gy, pz+nz)
						))
					end)
					task.wait(dt)
				end
			end
			task.wait(IDLE_MIN + math.random()*(IDLE_MAX-IDLE_MIN))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Spawn
-- ─────────────────────────────────────────────────────────────────────────
task.wait(2)

local folder        = Instance.new("Folder")
folder.Name         = "Animals"
folder.Parent       = Workspace

local builders = {
	chicken = buildChicken,
	sheep   = buildSheep,
	pig     = buildPig,
}

for _, kind in ipairs({"chicken", "sheep", "pig"}) do
	local ok, tmpl = pcall(builders[kind])
	if not ok then
		warn("[Farm] buildAnimal("..kind..") error: "..tostring(tmpl))
		continue
	end

	local gy   = groundOffset(tmpl)
	local zone = ZONES[kind]

	for i = 1, COUNTS[kind] do
		local ok2, err = pcall(function()
			local clone    = tmpl:Clone()
			clone.Name     = kind..i
			clone.Parent   = folder
			attachSound(clone.PrimaryPart, kind)
			startWander(clone, kind, zone, gy)
		end)
		if not ok2 then
			warn("[Farm] Spawn "..kind..i.." failed: "..tostring(err))
		end
		task.wait(0.05)
	end

	tmpl:Destroy()   -- clean up the template
	print(string.format("[Farm] Spawned %d %ss at (%.0f, %.0f)", COUNTS[kind], kind, zone.cx, zone.cz))
end
