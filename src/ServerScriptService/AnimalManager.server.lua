-- AnimalManager.server.lua
-- Spawns chickens, sheep and pigs with zone-restricted wandering AI.
-- All animals are built from anchored Parts so there is no physics overhead.
-- Movement is driven by lightweight task.spawn coroutines (~10 updates/sec).

local Workspace = game:GetService("Workspace")

math.randomseed(os.clock() * 1000)

-- ── Zone definitions (circular: center X/Z + radius) ─────────────────────
local ZONES = {
	chicken = { cx =  30, cz =  30, radius = 12 },
	sheep   = { cx = -55, cz =  15, radius = 20 },
	pig     = { cx =  60, cz =   5, radius = 12 },
}

-- ── Population ────────────────────────────────────────────────────────────
local COUNTS = { chicken = 6, sheep = 4, pig = 3 }

-- ── Walk speed (studs / second) ───────────────────────────────────────────
local SPEEDS = { chicken = 6, sheep = 3, pig = 4 }

-- ── Body pivot height above Y=0 ground ───────────────────────────────────
local BODY_Y = { chicken = 0.7, sheep = 1.5, pig = 1.1 }

-- ── Idle pause range (seconds) between walks ──────────────────────────────
local IDLE_MIN, IDLE_MAX = 1, 4

-- ─────────────────────────────────────────────────────────────────────────
--  buildAnimal  — assembles a Model from Parts at local-space offsets
--  (origin = body centre).  All parts anchored, CanCollide false.
-- ─────────────────────────────────────────────────────────────────────────
local function buildAnimal(kind)
	local model = Instance.new("Model")
	model.Name  = kind:sub(1,1):upper() .. kind:sub(2)  -- "Chicken" etc.

	local function p(name, size, color, ox, oy, oz)
		local part              = Instance.new("Part")
		part.Name               = name
		part.Size               = size
		part.CFrame             = CFrame.new(ox, oy, oz)
		part.BrickColor         = BrickColor.new(color)
		part.Material           = Enum.Material.SmoothPlastic
		part.Anchored           = true
		part.CanCollide         = false
		part.CastShadow         = true
		part.TopSurface         = Enum.SurfaceType.Smooth
		part.BottomSurface      = Enum.SurfaceType.Smooth
		part.Parent             = model
		return part
	end

	if kind == "chicken" then
		-- Body — primary part sits at local origin
		local body = p("Body",  Vector3.new(0.8,  0.6,  1.2),  "Bright yellow",      0,     0,     0)
		             p("Head",  Vector3.new(0.5,  0.5,  0.5),  "Bright yellow",      0,     0.55,  0.55)
		             p("Comb",  Vector3.new(0.15, 0.25, 0.15), "Bright red",         0,     0.9,   0.55)
		             p("Beak",  Vector3.new(0.2,  0.15, 0.2),  "Bright orange",      0,     0.45,  0.85)
		             p("Wing1", Vector3.new(0.1,  0.4,  0.9),  "CGA brown",         -0.45,  0.05,  0)
		             p("Wing2", Vector3.new(0.1,  0.4,  0.9),  "CGA brown",          0.45,  0.05,  0)
		             p("Leg1",  Vector3.new(0.1,  0.35, 0.1),  "Bright orange",     -0.2,  -0.45,  0.1)
		             p("Leg2",  Vector3.new(0.1,  0.35, 0.1),  "Bright orange",      0.2,  -0.45,  0.1)
		model.PrimaryPart = body

	elseif kind == "sheep" then
		local body = p("Body",  Vector3.new(1.6,  1.3,  2.2),  "White",              0,     0,     0)
		             p("Head",  Vector3.new(0.75, 0.75, 0.75), "Medium stone grey",  0,     0.35,  1.2)
		             p("Ear1",  Vector3.new(0.1,  0.35, 0.3),  "Medium stone grey", -0.45,  0.7,   1.1)
		             p("Ear2",  Vector3.new(0.1,  0.35, 0.3),  "Medium stone grey",  0.45,  0.7,   1.1)
		             p("Leg1",  Vector3.new(0.3,  0.9,  0.3),  "Light grey",        -0.55, -1.1,  -0.65)
		             p("Leg2",  Vector3.new(0.3,  0.9,  0.3),  "Light grey",         0.55, -1.1,  -0.65)
		             p("Leg3",  Vector3.new(0.3,  0.9,  0.3),  "Light grey",        -0.55, -1.1,   0.65)
		             p("Leg4",  Vector3.new(0.3,  0.9,  0.3),  "Light grey",         0.55, -1.1,   0.65)
		             p("Wool",  Vector3.new(1.8,  1.0,  2.4),  "White",              0,     0.3,   0)
		model.PrimaryPart = body

	elseif kind == "pig" then
		local body = p("Body",  Vector3.new(1.3,  1.0,  1.9),  "Light reddish violet", 0,   0,    0)
		             p("Head",  Vector3.new(0.85, 0.85, 0.85), "Light reddish violet", 0,   0.2,  1.1)
		             p("Snout", Vector3.new(0.45, 0.35, 0.25), "Carnation pink",       0,   0.1,  1.6)
		             p("Ear1",  Vector3.new(0.25, 0.35, 0.15), "Light reddish violet",-0.38, 0.75, 1.05)
		             p("Ear2",  Vector3.new(0.25, 0.35, 0.15), "Light reddish violet", 0.38, 0.75, 1.05)
		             p("Tail",  Vector3.new(0.15, 0.15, 0.4),  "Light reddish violet", 0,   0.3,  -1.1)
		             p("Leg1",  Vector3.new(0.3,  0.7,  0.3),  "Light reddish violet",-0.5, -0.85,-0.6)
		             p("Leg2",  Vector3.new(0.3,  0.7,  0.3),  "Light reddish violet", 0.5, -0.85,-0.6)
		             p("Leg3",  Vector3.new(0.3,  0.7,  0.3),  "Light reddish violet",-0.5, -0.85, 0.6)
		             p("Leg4",  Vector3.new(0.3,  0.7,  0.3),  "Light reddish violet", 0.5, -0.85, 0.6)
		model.PrimaryPart = body
	end

	return model
end

-- ─────────────────────────────────────────────────────────────────────────
--  Helpers
-- ─────────────────────────────────────────────────────────────────────────

-- Uniform random point inside a circle (no clustering at centre)
local function randomInZone(zone)
	local angle = math.random() * math.pi * 2
	local r     = math.sqrt(math.random()) * zone.radius
	return zone.cx + math.cos(angle) * r,
	       zone.cz + math.sin(angle) * r
end

-- ─────────────────────────────────────────────────────────────────────────
--  startWander — each animal gets its own coroutine
-- ─────────────────────────────────────────────────────────────────────────
local function startWander(model, kind, zone)
	local speed  = SPEEDS[kind]
	local groundY = BODY_Y[kind]

	-- Place at a random starting position inside the zone
	local sx, sz = randomInZone(zone)
	model:PivotTo(CFrame.new(sx, groundY, sz))

	task.spawn(function()
		local px, pz = sx, sz   -- current position

		while model and model.Parent do
			-- Pick a new destination inside the zone
			local tx, tz = randomInZone(zone)
			local dx, dz = tx - px, tz - pz
			local dist   = math.sqrt(dx*dx + dz*dz)

			if dist > 0.5 then
				-- Face the target
				local nx, nz = dx / dist, dz / dist
				local facing = CFrame.lookAt(
					Vector3.new(px, groundY, pz),
					Vector3.new(px + nx, groundY, pz + nz)
				)
				model:PivotTo(facing)

				-- Walk in small steps (~10 per second)
				local travelTime = dist / speed
				local steps      = math.max(1, math.ceil(travelTime * 10))
				local stepDist   = dist / steps
				local dt         = travelTime / steps

				for _ = 1, steps do
					if not model or not model.Parent then return end
					px = px + nx * stepDist
					pz = pz + nz * stepDist
					model:PivotTo(CFrame.lookAt(
						Vector3.new(px, groundY, pz),
						Vector3.new(px + nx, groundY, pz + nz)
					))
					task.wait(dt)
				end
			end

			-- Idle pause before next walk
			task.wait(IDLE_MIN + math.random() * (IDLE_MAX - IDLE_MIN))
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  Spawn all animals
-- ─────────────────────────────────────────────────────────────────────────

-- Wait for world to exist before adding animals
task.wait(1)

local animalsFolder      = Instance.new("Folder")
animalsFolder.Name       = "Animals"
animalsFolder.Parent     = Workspace

for kind, count in pairs(COUNTS) do
	local zone = ZONES[kind]
	for _ = 1, count do
		local model  = buildAnimal(kind)
		model.Parent = animalsFolder
		startWander(model, kind, zone)
		task.wait(0.05)   -- tiny stagger so not all coroutines tick together
	end
end

print(string.format("[Farm] Animals spawned: %d chickens, %d sheep, %d pigs",
	COUNTS.chicken, COUNTS.sheep, COUNTS.pig))
