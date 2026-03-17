-- AnimalManager.server.lua
-- Loads free Roblox marketplace animal models and gives them
-- zone-restricted wandering AI.
--
-- IMPORTANT — one-time Studio setup required:
--   Game Settings  →  Security  →  Allow Loading Third-Party Assets  ✓
--
-- Free asset IDs used:
--   Chicken : 501817842   (SergeantHippyZombie)
--   Sheep   : 36916758    (Vanake14 — "Baaing sheep")
--   Pig     : 9912720387  (gougeon10)

local Workspace    = game:GetService("Workspace")
local AssetService = game:GetService("AssetService")

math.randomseed(os.clock() * 1000)

-- ── Marketplace asset IDs (all free) ─────────────────────────────────────
local ASSET_IDS = {
	chicken = 501817842,
	sheep   = 36916758,
	pig     = 9912720387,
}

-- ── Zone definitions (circular: centre X/Z + radius in studs) ────────────
local ZONES = {
	chicken = { cx =  30, cz =  30, radius = 12 },
	sheep   = { cx = -55, cz =  15, radius = 20 },
	pig     = { cx =  60, cz =   5, radius = 12 },
}

-- ── Population ────────────────────────────────────────────────────────────
local COUNTS = { chicken = 6, sheep = 4, pig = 3 }

-- ── Walk speed (studs / second) ───────────────────────────────────────────
local SPEEDS = { chicken = 6, sheep = 3, pig = 4 }

-- ── Idle pause range (seconds) ────────────────────────────────────────────
local IDLE_MIN, IDLE_MAX = 1, 4

-- ─────────────────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────────────────

-- Anchor all BaseParts, disable any embedded scripts
local function prepareModel(model)
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.Anchored   = true
			desc.CanCollide = false
		elseif desc:IsA("BaseScript") then
			desc.Disabled   = true
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChildOfClass("BasePart")
	end
end

-- Calculate how many studs above Y=0 the pivot should sit so the
-- model's lowest point rests on the ground.
local function groundOffset(model)
	if not model.PrimaryPart then return 1 end
	local pivotY = model.PrimaryPart.Position.Y
	local minY   = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			minY = math.min(minY, p.Position.Y - p.Size.Y * 0.5)
		end
	end
	if minY == math.huge then return 1 end
	return math.max(0.5, pivotY - minY)   -- pivot height above ground
end

-- Uniform random point inside a circular zone
local function randomInZone(zone)
	local a = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * zone.radius
	return zone.cx + math.cos(a) * r,
	       zone.cz + math.sin(a) * r
end

-- ─────────────────────────────────────────────────────────────────────────
--  Wander AI — one coroutine per animal
-- ─────────────────────────────────────────────────────────────────────────
local function startWander(model, kind, zone, gy)
	local speed  = SPEEDS[kind]
	local sx, sz = randomInZone(zone)
	model:PivotTo(CFrame.new(sx, gy, sz))

	task.spawn(function()
		local px, pz = sx, sz
		while model and model.Parent do
			-- Pick next waypoint inside zone
			local tx, tz = randomInZone(zone)
			local dx, dz = tx - px, tz - pz
			local dist   = math.sqrt(dx * dx + dz * dz)

			if dist > 0.5 then
				local nx, nz = dx / dist, dz / dist
				local steps  = math.max(1, math.ceil(dist / speed * 10))
				local step   = dist / steps
				local dt     = (dist / speed) / steps

				for _ = 1, steps do
					if not model or not model.Parent then return end
					px = px + nx * step
					pz = pz + nz * step
					model:PivotTo(CFrame.lookAt(
						Vector3.new(px, gy, pz),
						Vector3.new(px + nx, gy, pz + nz)
					))
					task.wait(dt)
				end
			end

			-- Idle pause
			task.wait(IDLE_MIN + math.random() * (IDLE_MAX - IDLE_MIN))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Fallback block animal (used only if marketplace load fails)
-- ─────────────────────────────────────────────────────────────────────────
local function buildFallback(kind)
	local m = Instance.new("Model")
	m.Name  = kind

	local function p(name, sz, col, ox, oy, oz)
		local part           = Instance.new("Part")
		part.Name            = name
		part.Size            = sz
		part.CFrame          = CFrame.new(ox, oy, oz)
		part.BrickColor      = BrickColor.new(col)
		part.Material        = Enum.Material.SmoothPlastic
		part.Anchored        = true
		part.CanCollide      = false
		part.TopSurface      = Enum.SurfaceType.Smooth
		part.BottomSurface   = Enum.SurfaceType.Smooth
		part.Parent          = m
		return part
	end

	local body
	if kind == "chicken" then
		body = p("Body", Vector3.new(0.8,0.6,1.2), "Bright yellow",  0,  0,    0)
		       p("Head", Vector3.new(0.5,0.5,0.5), "Bright yellow",  0,  0.55, 0.55)
		       p("Comb", Vector3.new(0.15,0.25,0.15),"Bright red",   0,  0.9,  0.55)
		       p("Beak", Vector3.new(0.2,0.15,0.2), "Bright orange", 0,  0.45, 0.85)
	elseif kind == "sheep" then
		body = p("Body", Vector3.new(1.6,1.3,2.2), "White",          0,  0,    0)
		       p("Head", Vector3.new(0.75,0.75,0.75),"Medium stone grey",0,0.35,1.2)
		       p("Leg1", Vector3.new(0.3,0.9,0.3), "Light grey",    -0.55,-1.1,-0.65)
		       p("Leg2", Vector3.new(0.3,0.9,0.3), "Light grey",     0.55,-1.1,-0.65)
		       p("Leg3", Vector3.new(0.3,0.9,0.3), "Light grey",    -0.55,-1.1, 0.65)
		       p("Leg4", Vector3.new(0.3,0.9,0.3), "Light grey",     0.55,-1.1, 0.65)
	elseif kind == "pig" then
		body = p("Body", Vector3.new(1.3,1.0,1.9), "Light reddish violet", 0, 0, 0)
		       p("Head", Vector3.new(0.85,0.85,0.85),"Light reddish violet",0,0.2,1.1)
		       p("Snout",Vector3.new(0.45,0.35,0.25),"Carnation pink",      0,0.1,1.6)
		       p("Leg1", Vector3.new(0.3,0.7,0.3), "Light reddish violet",-0.5,-0.85,-0.6)
		       p("Leg2", Vector3.new(0.3,0.7,0.3), "Light reddish violet", 0.5,-0.85,-0.6)
		       p("Leg3", Vector3.new(0.3,0.7,0.3), "Light reddish violet",-0.5,-0.85, 0.6)
		       p("Leg4", Vector3.new(0.3,0.7,0.3), "Light reddish violet", 0.5,-0.85, 0.6)
	end

	m.PrimaryPart = body
	return m
end

-- ─────────────────────────────────────────────────────────────────────────
--  Main — load templates then spawn
-- ─────────────────────────────────────────────────────────────────────────

task.wait(2)   -- let Main.server finish building the world first

local animalsFolder      = Instance.new("Folder")
animalsFolder.Name       = "Animals"
animalsFolder.Parent     = Workspace

-- Load one template per species (then clone for each animal)
local templates     = {}
local groundOffsets = {}

for kind, id in pairs(ASSET_IDS) do
	local ok, result = pcall(function()
		return AssetService:LoadAssetAsync(id)
	end)

	if ok and result then
		-- LoadAssetAsync wraps the asset in a container; unwrap it
		local inner = result:FindFirstChildOfClass("Model") or result
		prepareModel(inner)
		groundOffsets[kind] = groundOffset(inner)
		inner.Parent        = nil   -- hold as template only
		templates[kind]     = inner
		print(string.format("[Farm] Loaded %s from marketplace (id %d)", kind, id))
	else
		warn(string.format(
			"[Farm] Could not load %s (id %d) — using fallback blocks.\n" ..
			"       Fix: Game Settings > Security > Allow Loading Third-Party Assets",
			kind, id
		))
		templates[kind]     = buildFallback(kind)
		groundOffsets[kind] = groundOffset(templates[kind])
	end
end

-- Spawn all animals
for kind, count in pairs(COUNTS) do
	local template = templates[kind]
	local zone     = ZONES[kind]
	local gy       = groundOffsets[kind]

	for _ = 1, count do
		local clone    = template:Clone()
		clone.Parent   = animalsFolder
		startWander(clone, kind, zone, gy)
		task.wait(0.05)
	end

	print(string.format("[Farm] Spawned %d %ss", count, kind))
end
