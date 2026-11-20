-- WorldBuilder.luau
-- Procedurally builds the ~1000x1000 stud DinoWorld: four wild zones, a
-- river, a central camp with spawn + campfire + hatch pad, edge cliffs,
-- and scattered gather nodes (BerryBush / WoodTree / StoneRock / DinoNest).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoData = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("DinoData", 10))

local WorldBuilder = {}

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(parent, name, size, position, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.Parent = parent
	return p
end

local function sign(parent, position, text, color)
	local post = part(parent, "SignPost", Vector3.new(1, 7, 1), position + Vector3.new(0, 3.5, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood, false)
	local board = part(parent, "SignBoard", Vector3.new(14, 4, 0.6), position + Vector3.new(0, 8, 0), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, false)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(20, 0, 5, 0)
	gui.MaxDistance = 170
	gui.AlwaysOnTop = false
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = gui
	return post
end

local function tree(parent, position, rng, leafColor)
	local height = rng:NextNumber(9, 14)
	part(parent, "Trunk", Vector3.new(2, height, 2), position + Vector3.new(0, height / 2, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood, true)
	part(parent, "Leaves", Vector3.new(9, 7, 9), position + Vector3.new(0, height + 3, 0), leafColor, Enum.Material.SmoothPlastic, false)
	part(parent, "LeavesTop", Vector3.new(6, 4, 6), position + Vector3.new(0, height + 7, 0), leafColor, Enum.Material.SmoothPlastic, false)
end

local function nodeModel(parent, nodeType, name)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("NodeType", nodeType)
	model.Parent = parent
	return model
end

function WorldBuilder.Build()
	local old = workspace:FindFirstChild("DinoWorld")
	if old then
		old:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "DinoWorld"
	world.Parent = workspace

	part(world, "GroundBase", Vector3.new(1012, 2, 1012), Vector3.new(0, -1.1, 0), Color3.fromRGB(86, 148, 70), Enum.Material.Grass, true)

	local rng = Random.new(20261120)

	-- Zone grounds (top surface at Y=0).
	for zoneName, zone in pairs(DinoData.Zones) do
		if zoneName ~= "Camp" then
			local r = zone.Rect
			local cx, cz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
			part(world, "Ground_" .. zoneName, Vector3.new(r[2] - r[1], 2, r[4] - r[3]), Vector3.new(cx, -1, cz), rgb(zone.Ground), Enum.Material.Grass, true)
		end
	end
	-- Camp clearing on top of the middle.
	part(world, "Ground_Camp", Vector3.new(130, 2.4, 130), Vector3.new(0, -1, 0), rgb(DinoData.Zones.Camp.Ground), Enum.Material.Grass, true)

	-- River strip running north-south between the west and east zones.
	part(world, "River", Vector3.new(46, 1, 1000), Vector3.new(0, 0.15, 0), Color3.fromRGB(60, 140, 220), Enum.Material.SmoothPlastic, false).Transparency = 0.25
	-- Wooden bridges over the river at camp height.
	part(world, "BridgeW", Vector3.new(60, 1, 14), Vector3.new(0, 0.6, -120), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, true)
	part(world, "BridgeE", Vector3.new(60, 1, 14), Vector3.new(0, 0.6, 120), Color3.fromRGB(140, 100, 60), Enum.Material.Wood, true)

	-- Ponds in the swamp.
	for _ = 1, 4 do
		local x, z = rng:NextNumber(-460, -120), rng:NextNumber(120, 460)
		part(world, "Pond", Vector3.new(rng:NextNumber(30, 55), 1, rng:NextNumber(30, 55)), Vector3.new(x, 0.2, z), Color3.fromRGB(50, 90, 70), Enum.Material.SmoothPlastic, false).Transparency = 0.2
	end

	-- Volcano cone + lava pools (lava parts are found by name for damage).
	local volcano = part(world, "VolcanoCone", Vector3.new(120, 55, 120), Vector3.new(330, 24, 330), Color3.fromRGB(70, 60, 65), Enum.Material.Rock, true)
	volcano.Shape = Enum.PartType.Cylinder
	volcano.Orientation = Vector3.new(0, 0, 90)
	for i = 1, 3 do
		local x, z = 240 + i * 55, 150 + (i % 2) * 90
		local lava = part(world, "LavaPool", Vector3.new(34, 1.2, 34), Vector3.new(x, 0.4, z), Color3.fromRGB(255, 110, 20), Enum.Material.Neon, false)
		lava:SetAttribute("IsLava", true)
	end
	local crater = part(world, "LavaPool", Vector3.new(44, 2, 44), Vector3.new(330, 52, 330), Color3.fromRGB(255, 130, 25), Enum.Material.Neon, false)
	crater:SetAttribute("IsLava", true)

	-- Edge cliffs so players stay inside the world.
	local cliffColor = Color3.fromRGB(95, 85, 80)
	part(world, "CliffN", Vector3.new(1040, 26, 12), Vector3.new(0, 11, -506), cliffColor, Enum.Material.Rock, true)
	part(world, "CliffS", Vector3.new(1040, 26, 12), Vector3.new(0, 11, 506), cliffColor, Enum.Material.Rock, true)
	part(world, "CliffW", Vector3.new(12, 26, 1040), Vector3.new(-506, 11, 0), cliffColor, Enum.Material.Rock, true)
	part(world, "CliffE", Vector3.new(12, 26, 1040), Vector3.new(506, 11, 0), cliffColor, Enum.Material.Rock, true)

	-- Scatter decorative trees per zone.
	local jungleLeaf = Color3.fromRGB(45, 130, 50)
	for _ = 1, 42 do
		tree(world, Vector3.new(rng:NextNumber(-480, -90), 0, rng:NextNumber(-480, -90)), rng, jungleLeaf)
	end
	for _ = 1, 20 do
		tree(world, Vector3.new(rng:NextNumber(-480, -90), 0, rng:NextNumber(90, 480)), rng, Color3.fromRGB(40, 90, 45))
	end
	for _ = 1, 8 do -- desert cacti
		local pos = Vector3.new(rng:NextNumber(90, 480), 0, rng:NextNumber(-480, -90))
		part(world, "Cactus", Vector3.new(2.5, 11, 2.5), pos + Vector3.new(0, 5.5, 0), Color3.fromRGB(60, 150, 70), Enum.Material.SmoothPlastic, true)
	end
	for _ = 1, 10 do -- desert bones
		local pos = Vector3.new(rng:NextNumber(90, 480), 0, rng:NextNumber(-480, -90))
		part(world, "Bone", Vector3.new(10, 1.2, 1.2), pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(240, 235, 215), Enum.Material.SmoothPlastic, false)
		part(world, "Bone", Vector3.new(1.2, 1.2, 6), pos + Vector3.new(3, 0.8, 2), Color3.fromRGB(240, 235, 215), Enum.Material.SmoothPlastic, false)
	end
	for _ = 1, 12 do -- volcanic rocks
		local pos = Vector3.new(rng:NextNumber(90, 480), 0, rng:NextNumber(90, 480))
		if (pos - Vector3.new(330, 0, 330)).Magnitude > 90 then
			part(world, "Rock", Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(3, 7), rng:NextNumber(4, 9)), pos + Vector3.new(0, 2, 0), Color3.fromRGB(85, 75, 80), Enum.Material.Rock, true)
		end
	end

	-- ===== CAMP =====
	local camp = Instance.new("Folder")
	camp.Name = "Camp"
	camp.Parent = world

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DinoSpawn"
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = Vector3.new(0, 1.2, 0)
	spawn.Color = Color3.fromRGB(255, 200, 80)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Neutral = true
	spawn.Parent = camp
	part(camp, "CampPad", Vector3.new(50, 0.6, 50), Vector3.new(0, 0.4, 0), Color3.fromRGB(190, 160, 110), Enum.Material.Wood, true)

	-- Campfire: heals nearby players (handled by the world tick).
	local fireBase = part(camp, "Campfire", Vector3.new(6, 1.5, 6), Vector3.new(12, 1, 10), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, false)
	fireBase:SetAttribute("IsCampfire", true)
	fireBase.Shape = Enum.PartType.Cylinder
	local flame = part(camp, "Flame", Vector3.new(3.4, 4.5, 3.4), Vector3.new(12, 3.5, 10), Color3.fromRGB(255, 140, 30), Enum.Material.Neon, false)
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 12
	fire.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 80)
	light.Range = 34
	light.Brightness = 2
	light.Parent = flame

	-- Hatch pad at camp.
	local hatch = part(camp, "HatchPad", Vector3.new(10, 1, 10), Vector3.new(-14, 0.8, 12), Color3.fromRGB(255, 170, 220), Enum.Material.SmoothPlastic, true)
	hatch:SetAttribute("NodeType", "Hatch")
	hatch.Shape = Enum.PartType.Cylinder

	-- Camp fences.
	for _, spec in ipairs({
		{ Vector3.new(56, 3, 2), Vector3.new(0, 1.8, -28) },
		{ Vector3.new(56, 3, 2), Vector3.new(0, 1.8, 28) },
		{ Vector3.new(2, 3, 56), Vector3.new(-28, 1.8, 0) },
		{ Vector3.new(2, 3, 56), Vector3.new(28, 1.8, 0) },
	}) do
		part(camp, "Fence", spec[1], spec[2], Color3.fromRGB(130, 90, 55), Enum.Material.Wood, true)
	end

	sign(camp, Vector3.new(0, 0, -34), "🏕️ KAMP DINO", Color3.fromRGB(255, 230, 150))
	sign(world, Vector3.new(-90, 0, -90), "🌴 HUTAN RIMBA", Color3.fromRGB(170, 255, 170))
	sign(world, Vector3.new(90, 0, -90), "🦴 GURUN TULANG", Color3.fromRGB(255, 235, 180))
	sign(world, Vector3.new(-90, 0, 90), "🐸 RAWA GELAP", Color3.fromRGB(170, 255, 210))
	sign(world, Vector3.new(90, 0, 90), "🌋 GUNUNG BERAPI — AWAS T-REX!", Color3.fromRGB(255, 160, 120))

	-- ===== GATHER NODES =====
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = world

	local function scatterPos(zoneName)
		local r = DinoData.Zones[zoneName].Rect
		return Vector3.new(rng:NextNumber(r[1] + 25, r[2] - 25), 0, rng:NextNumber(r[3] + 25, r[4] - 25))
	end
	local wildZones = { "Jungle", "Desert", "Swamp", "Volcano" }

	for i = 1, 14 do
		local pos = scatterPos(wildZones[(i % 4) + 1])
		local m = nodeModel(nodes, "Berry", "BerryBush" .. i)
		part(m, "Bush", Vector3.new(5, 3.5, 5), pos + Vector3.new(0, 1.7, 0), Color3.fromRGB(50, 140, 60), Enum.Material.SmoothPlastic, false)
		for b = 1, 4 do
			part(m, "Berry", Vector3.new(0.9, 0.9, 0.9), pos + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1.5, 3.4), rng:NextNumber(-2, 2)), Color3.fromRGB(230, 60, 90), Enum.Material.SmoothPlastic, false).Shape = Enum.PartType.Ball
		end
	end
	for i = 1, 14 do
		local pos = scatterPos(wildZones[((i + 1) % 4) + 1])
		local m = nodeModel(nodes, "Wood", "WoodTree" .. i)
		part(m, "Trunk", Vector3.new(2.6, 12, 2.6), pos + Vector3.new(0, 6, 0), Color3.fromRGB(120, 80, 45), Enum.Material.Wood, true)
		part(m, "Leaves", Vector3.new(10, 8, 10), pos + Vector3.new(0, 15, 0), Color3.fromRGB(60, 150, 65), Enum.Material.SmoothPlastic, false)
	end
	for i = 1, 12 do
		local pos = scatterPos(wildZones[((i + 2) % 4) + 1])
		local m = nodeModel(nodes, "Stone", "StoneRock" .. i)
		part(m, "Rock", Vector3.new(5, 3.5, 4.5), pos + Vector3.new(0, 1.6, 0), Color3.fromRGB(140, 140, 145), Enum.Material.Rock, true)
		part(m, "RockTop", Vector3.new(3, 2, 3), pos + Vector3.new(0.5, 4, 0), Color3.fromRGB(160, 160, 165), Enum.Material.Rock, false)
	end
	for i = 1, 8 do
		local pos = scatterPos(wildZones[((i + 3) % 4) + 1])
		local m = nodeModel(nodes, "Nest", "DinoNest" .. i)
		part(m, "Nest", Vector3.new(7, 1.6, 7), pos + Vector3.new(0, 0.8, 0), Color3.fromRGB(150, 110, 60), Enum.Material.Wood, false).Shape = Enum.PartType.Cylinder
		for e = 1, 3 do
			local egg = part(m, "Egg", Vector3.new(1.6, 2, 1.6), pos + Vector3.new((e - 2) * 1.8, 2.2, rng:NextNumber(-1, 1)), Color3.fromRGB(245, 240, 220), Enum.Material.SmoothPlastic, false)
			egg.Shape = Enum.PartType.Ball
		end
	end

	return world
end

return WorldBuilder
