-- AnimalManager.server.lua
-- Spawns chickens, sheep and pigs using SpecialMesh (Sphere) parts so
-- animals look rounded/realistic with no marketplace asset IDs required.
-- Each animal has zone-restricted wandering AI via a task.spawn coroutine.

local Workspace = game:GetService("Workspace")
math.randomseed(os.clock() * 1000)

-- ── Zone definitions — kept close to player spawn (0, ~3, -28) ───────────
--   chicken coop  : right of barn (barn is at X≈30, Z≈0)
--   sheep pasture : left open field
--   pig pen       : behind barn
local ZONES = {
	chicken = { cx =  35, cz =  10, radius = 10 },
	sheep   = { cx = -20, cz =  20, radius = 14 },
	pig     = { cx =  30, cz =  25, radius =  9 },
}

local COUNTS = { chicken = 6, sheep = 4, pig = 3 }
local SPEEDS = { chicken = 5, sheep = 2.5, pig = 3.5 }
local IDLE_MIN, IDLE_MAX = 1.5, 4

-- ─────────────────────────────────────────────────────────────────────────
--  makeSphere — a Part that renders as a sphere via SpecialMesh
-- ─────────────────────────────────────────────────────────────────────────
local function makeSphere(parent, name, rx, ry, rz, color, ox, oy, oz)
	local part              = Instance.new("Part")
	part.Name               = name
	part.Size               = Vector3.new(2, 2, 2)   -- mesh overrides visuals
	part.CFrame             = CFrame.new(ox, oy, oz)
	part.BrickColor         = BrickColor.new(color)
	part.Material           = Enum.Material.SmoothPlastic
	part.Anchored           = true
	part.CanCollide         = false
	part.CastShadow         = true
	part.TopSurface         = Enum.SurfaceType.Smooth
	part.BottomSurface      = Enum.SurfaceType.Smooth

	local mesh              = Instance.new("SpecialMesh")
	mesh.MeshType           = Enum.MeshType.Sphere
	mesh.Scale              = Vector3.new(rx, ry, rz)
	mesh.Parent             = part

	part.Parent             = parent
	return part
end

local function makeBlock(parent, name, sx, sy, sz, color, ox, oy, oz)
	local part              = Instance.new("Part")
	part.Name               = name
	part.Size               = Vector3.new(sx, sy, sz)
	part.CFrame             = CFrame.new(ox, oy, oz)
	part.BrickColor         = BrickColor.new(color)
	part.Material           = Enum.Material.SmoothPlastic
	part.Anchored           = true
	part.CanCollide         = false
	part.CastShadow         = true
	part.TopSurface         = Enum.SurfaceType.Smooth
	part.BottomSurface      = Enum.SurfaceType.Smooth
	part.Parent             = parent
	return part
end

-- ─────────────────────────────────────────────────────────────────────────
--  buildAnimal — all positions are local offsets from body centre (0,0,0)
-- ─────────────────────────────────────────────────────────────────────────
local function buildAnimal(kind)
	local m = Instance.new("Model")
	m.Name  = kind:sub(1,1):upper()..kind:sub(2)

	local body
	if kind == "chicken" then
		-- rounded yellow body, small head, red comb, orange beak, thin legs
		body = makeSphere(m, "Body",  0.9, 0.7, 1.1, "Bright yellow",   0,    0,     0)
		       makeSphere(m, "Head",  0.55,0.55,0.55,"Bright yellow",   0,    0.65,  0.55)
		       makeBlock (m, "Comb",  0.15,0.3, 0.15,"Bright red",      0,    1.05,  0.55)
		       makeBlock (m, "Beak",  0.18,0.13,0.25,"Bright orange",   0,    0.52,  0.88)
		       makeBlock (m, "Leg1",  0.1, 0.55,0.1, "Bright orange",  -0.22,-0.58,  0.1)
		       makeBlock (m, "Leg2",  0.1, 0.55,0.1, "Bright orange",   0.22,-0.58,  0.1)
		       makeBlock (m, "Wing1", 0.12,0.5, 0.9, "CGA brown",      -0.48, 0.05,  0)
		       makeBlock (m, "Wing2", 0.12,0.5, 0.9, "CGA brown",       0.48, 0.05,  0)

	elseif kind == "sheep" then
		-- large fluffy white body, grey rounded head, dark thin legs
		body = makeSphere(m, "Wool",  1.7, 1.35,2.3, "White",           0,    0,     0)
		       makeSphere(m, "Head",  0.75,0.75,0.8, "Medium stone grey",0,   0.5,   1.25)
		       makeBlock (m, "Ear1",  0.12,0.4, 0.3, "Medium stone grey",-0.45,0.9,  1.15)
		       makeBlock (m, "Ear2",  0.12,0.4, 0.3, "Medium stone grey", 0.45,0.9,  1.15)
		       makeBlock (m, "Leg1",  0.28,1.0, 0.28,"Dark grey",       -0.55,-1.15,-0.65)
		       makeBlock (m, "Leg2",  0.28,1.0, 0.28,"Dark grey",        0.55,-1.15,-0.65)
		       makeBlock (m, "Leg3",  0.28,1.0, 0.28,"Dark grey",       -0.55,-1.15, 0.65)
		       makeBlock (m, "Leg4",  0.28,1.0, 0.28,"Dark grey",        0.55,-1.15, 0.65)

	elseif kind == "pig" then
		-- pink rounded body, round head, flat snout, curly tail, short legs
		body = makeSphere(m, "Body",  1.35,1.1, 2.0, "Pastel orange",   0,    0,     0)
		       makeSphere(m, "Head",  0.9, 0.9, 0.95,"Pastel orange",   0,    0.25,  1.1)
		       makeSphere(m, "Snout", 0.55,0.4, 0.35,"Carnation pink",  0,    0.1,   1.6)
		       makeBlock (m, "Ear1",  0.28,0.35,0.12,"Pastel orange",  -0.42, 0.8,   1.05)
		       makeBlock (m, "Ear2",  0.28,0.35,0.12,"Pastel orange",   0.42, 0.8,   1.05)
		       makeBlock (m, "Tail",  0.15,0.15,0.5, "Carnation pink",  0,    0.3,  -1.1)
		       makeBlock (m, "Leg1",  0.3, 0.75,0.3, "Pastel orange",  -0.5, -0.9,  -0.6)
		       makeBlock (m, "Leg2",  0.3, 0.75,0.3, "Pastel orange",   0.5, -0.9,  -0.6)
		       makeBlock (m, "Leg3",  0.3, 0.75,0.3, "Pastel orange",  -0.5, -0.9,   0.6)
		       makeBlock (m, "Leg4",  0.3, 0.75,0.3, "Pastel orange",   0.5, -0.9,   0.6)
	end

	m.PrimaryPart = body
	return m
end

-- ─────────────────────────────────────────────────────────────────────────
--  groundOffset — how high the pivot must sit so the model's lowest
--  point is flush with Y = 0
-- ─────────────────────────────────────────────────────────────────────────
local function groundOffset(model)
	local pivotY = model.PrimaryPart and model.PrimaryPart.Position.Y or 0
	local minY   = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			-- for sphere meshes visual bottom ≈ part.Position.Y - Size.Y/2 * meshScale.Y/2
			local mesh = p:FindFirstChildOfClass("SpecialMesh")
			local halfH = mesh
				and (p.Size.Y * mesh.Scale.Y * 0.5)
				or  (p.Size.Y * 0.5)
			minY = math.min(minY, p.Position.Y - halfH)
		end
	end
	return (minY == math.huge) and 1 or math.max(0.3, pivotY - minY)
end

-- ─────────────────────────────────────────────────────────────────────────
--  randomInZone — uniform distribution inside a circle
-- ─────────────────────────────────────────────────────────────────────────
local function randomInZone(zone)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * zone.radius
	return zone.cx + math.cos(a) * r,
	       zone.cz + math.sin(a) * r
end

-- ─────────────────────────────────────────────────────────────────────────
--  startWander — one coroutine per animal
-- ─────────────────────────────────────────────────────────────────────────
local function startWander(model, kind, zone, gy)
	local speed  = SPEEDS[kind]
	local sx, sz = randomInZone(zone)
	local ok, err = pcall(function() model:PivotTo(CFrame.new(sx, gy, sz)) end)
	if not ok then warn("[Farm] PivotTo failed: "..tostring(err)) return end

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
			task.wait(IDLE_MIN + math.random() * (IDLE_MAX - IDLE_MIN))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Spawn
-- ─────────────────────────────────────────────────────────────────────────
task.wait(2)   -- wait for Main.server to finish building the world

local folder      = Instance.new("Folder")
folder.Name       = "Animals"
folder.Parent     = Workspace

-- Build one template per kind, then clone
local templates = {}
local offsets   = {}
for _, kind in ipairs({"chicken", "sheep", "pig"}) do
	local ok, result = pcall(buildAnimal, kind)
	if ok then
		templates[kind] = result
		offsets[kind]   = groundOffset(result)
		print(string.format("[Farm] Built %s template (groundY=%.2f)", kind, offsets[kind]))
	else
		warn("[Farm] buildAnimal("..kind..") failed: "..tostring(result))
	end
end

for _, kind in ipairs({"chicken", "sheep", "pig"}) do
	local tmpl = templates[kind]
	if not tmpl then
		warn("[Farm] Skipping "..kind.." — no template")
		continue
	end
	local zone = ZONES[kind]
	local gy   = offsets[kind]
	for i = 1, COUNTS[kind] do
		local ok, err = pcall(function()
			local clone    = tmpl:Clone()
			clone.Name     = kind..i
			clone.Parent   = folder
			startWander(clone, kind, zone, gy)
		end)
		if not ok then warn("[Farm] Spawn "..kind..i.." failed: "..tostring(err)) end
		task.wait(0.05)
	end
	print(string.format("[Farm] Spawned %d %ss near (%.0f, %.0f)", COUNTS[kind], kind, zone.cx, zone.cz))
end
