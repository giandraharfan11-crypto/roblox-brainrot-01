-- WorldBuilder.luau
-- BRAINROT NUSANTARA - builds the whole map out of Parts: ground, conveyor lane,
-- portal, 8 base plots, decorations and a SpawnLocation.
-- build() returns refs used by every other server module.

local WorldBuilder = {}

local PLOT_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(140, 255, 160),
	Color3.fromRGB(255, 220, 110),
	Color3.fromRGB(210, 140, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(120, 255, 230),
	Color3.fromRGB(255, 140, 200),
}

local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeLabel(parentPart, name, text, size, offset, textColor, bgTransparency)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = size or UDim2.fromOffset(220, 60)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parentPart
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = bgTransparency or 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.Text = text
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

local function buildPlot(world, index, centerX, centerZ)
	local plotFolder = Instance.new("Folder")
	plotFolder.Name = "Plot" .. tostring(index)
	plotFolder.Parent = world

	local floorColor = PLOT_COLORS[((index - 1) % #PLOT_COLORS) + 1]
	local floor = part(plotFolder, "Floor", Vector3.new(26, 0.6, 26),
		CFrame.new(centerX, 0.3, centerZ), floorColor, Enum.Material.SmoothPlastic)

	-- 6 placement pads: two rows of three.
	local pads = {}
	local padOffsets = {
		Vector3.new(-7.5, 0, -5.5), Vector3.new(0, 0, -5.5), Vector3.new(7.5, 0, -5.5),
		Vector3.new(-7.5, 0, 5.5), Vector3.new(0, 0, 5.5), Vector3.new(7.5, 0, 5.5),
	}
	for i, off in ipairs(padOffsets) do
		local pad = part(plotFolder, "Pad" .. tostring(i), Vector3.new(4.4, 0.5, 4.4),
			CFrame.new(centerX + off.X, 0.85, centerZ + off.Z),
			Color3.fromRGB(245, 245, 245), Enum.Material.Neon)
		pad.Transparency = 0.25
		table.insert(pads, pad)
	end

	-- Direction toward the lane (plots on the left face +X, on the right face -X).
	local laneDir = (centerX < 0) and 1 or -1

	-- Sell pad (red) on the lane-side front corner, lock pad (yellow) on the back corner.
	local sellPad = part(plotFolder, "SellPad", Vector3.new(4.5, 0.5, 4.5),
		CFrame.new(centerX + laneDir * 9, 0.85, centerZ - 9.5),
		Color3.fromRGB(230, 50, 50), Enum.Material.Neon)
	makeLabel(sellPad, "SellLabel", "JUAL", UDim2.fromOffset(110, 40), Vector3.new(0, 3, 0))

	local lockPad = part(plotFolder, "LockPad", Vector3.new(4.5, 0.5, 4.5),
		CFrame.new(centerX - laneDir * 9, 0.85, centerZ - 9.5),
		Color3.fromRGB(255, 205, 40), Enum.Material.Neon)
	makeLabel(lockPad, "LockLabelGui", "KUNCI", UDim2.fromOffset(110, 40), Vector3.new(0, 3, 0))
	local lockLabel = makeLabel(lockPad, "LockStateGui", "TERBUKA", UDim2.fromOffset(150, 44),
		Vector3.new(0, 5.5, 0), Color3.fromRGB(120, 255, 140))

	-- Sign board on the lane side with plot number and owner label.
	local signPost = part(plotFolder, "SignPost", Vector3.new(0.6, 5, 0.6),
		CFrame.new(centerX + laneDir * 12.5, 2.5, centerZ + 10), Color3.fromRGB(90, 60, 35))
	local sign = part(plotFolder, "Sign", Vector3.new(0.5, 3.4, 9),
		CFrame.new(centerX + laneDir * 12.5, 6, centerZ + 10), Color3.fromRGB(35, 35, 50))
	local titleLabel = makeLabel(sign, "TitleGui", "BASE " .. tostring(index),
		UDim2.fromOffset(200, 50), Vector3.new(0, 1.6, 0))
	titleLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
	local ownerLabel = makeLabel(sign, "OwnerGui", "KOSONG",
		UDim2.fromOffset(220, 50), Vector3.new(0, -1.4, 0))
	ownerLabel.TextColor3 = Color3.fromRGB(200, 220, 255)

	-- Low border walls around the plot.
	local wallColor = Color3.fromRGB(60, 60, 75)
	part(plotFolder, "WallBack", Vector3.new(26, 1.6, 0.6), CFrame.new(centerX, 1.1, centerZ - 13), wallColor)
	part(plotFolder, "WallFront", Vector3.new(26, 1.6, 0.6), CFrame.new(centerX, 1.1, centerZ + 13), wallColor)
	part(plotFolder, "WallLeft", Vector3.new(0.6, 1.6, 26), CFrame.new(centerX - 13, 1.1, centerZ), wallColor)
	part(plotFolder, "WallRight", Vector3.new(0.6, 1.6, 26), CFrame.new(centerX + 13, 1.1, centerZ), wallColor)

	-- Glass lock walls (hidden until the owner locks the base).
	local glassWalls = {}
	local glassDefs = {
		{ "GlassBack", Vector3.new(26, 7, 0.4), Vector3.new(0, 3.5, -13) },
		{ "GlassFront", Vector3.new(26, 7, 0.4), Vector3.new(0, 3.5, 13) },
		{ "GlassLeft", Vector3.new(0.4, 7, 26), Vector3.new(-13, 3.5, 0) },
		{ "GlassRight", Vector3.new(0.4, 7, 26), Vector3.new(13, 3.5, 0) },
	}
	for _, def in ipairs(glassDefs) do
		local g = part(plotFolder, def[1], def[2],
			CFrame.new(centerX + def[3].X, def[3].Y, centerZ + def[3].Z),
			Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
		g.Transparency = 0.45
		g.CanCollide = false
		g.Visible = false
		table.insert(glassWalls, g)
	end

	return {
		Index = index,
		Floor = floor,
		Pads = pads,
		SellPad = sellPad,
		LockPad = lockPad,
		Center = Vector3.new(centerX, 1, centerZ),
		OwnerLabel = ownerLabel,
		LockLabel = lockLabel,
		GlassWalls = glassWalls,
		Owner = nil,
		LockUntil = 0,
		Occupied = {},
	}
end

function WorldBuilder.build()
	local world = Instance.new("Folder")
	world.Name = "BrainrotWorld"
	world.Parent = workspace

	-- Ground and central road.
	part(world, "Ground", Vector3.new(280, 1, 280), CFrame.new(0, -0.5, 0),
		Color3.fromRGB(95, 190, 85), Enum.Material.Grass)
	part(world, "Road", Vector3.new(20, 0.3, 220), CFrame.new(0, 0.05, 0),
		Color3.fromRGB(90, 90, 100), Enum.Material.Asphalt)

	-- Conveyor lane along Z, from the portal (z=-90) to the far end (z=+90).
	local belt = part(world, "ConveyorBelt", Vector3.new(10, 0.5, 180), CFrame.new(0, 0.45, 0),
		Color3.fromRGB(35, 35, 45), Enum.Material.Metal)
	belt.Name = "ConveyorBelt"
	part(world, "RailLeft", Vector3.new(0.7, 1, 180), CFrame.new(-5.6, 0.9, 0),
		Color3.fromRGB(255, 190, 40), Enum.Material.Metal)
	part(world, "RailRight", Vector3.new(0.7, 1, 180), CFrame.new(5.6, 0.9, 0),
		Color3.fromRGB(255, 190, 40), Enum.Material.Metal)
	for z = -84, 84, 12 do
		local stripe = part(world, "Stripe", Vector3.new(9.4, 0.12, 1.2), CFrame.new(0, 0.76, z),
			Color3.fromRGB(255, 235, 120), Enum.Material.Neon)
		stripe.CanCollide = false
	end

	-- Portal at the start of the lane.
	part(world, "PortalPillarL", Vector3.new(1.6, 11, 1.6), CFrame.new(-6.5, 5.5, -90),
		Color3.fromRGB(120, 60, 220), Enum.Material.Neon)
	part(world, "PortalPillarR", Vector3.new(1.6, 11, 1.6), CFrame.new(6.5, 5.5, -90),
		Color3.fromRGB(120, 60, 220), Enum.Material.Neon)
	part(world, "PortalBeam", Vector3.new(14.6, 1.6, 1.6), CFrame.new(0, 11, -90),
		Color3.fromRGB(120, 60, 220), Enum.Material.Neon)
	local disc = Instance.new("Part")
	disc.Name = "PortalDisc"
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.6, 8.4, 8.4)
	disc.CFrame = CFrame.new(0, 6, -90) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = Color3.fromRGB(170, 90, 255)
	disc.Material = Enum.Material.Neon
	disc.Transparency = 0.25
	disc.Anchored = true
	disc.CanCollide = false
	disc.Parent = world
	makeLabel(disc, "PortalGui", "PORTAL BRAINROT", UDim2.fromOffset(280, 56), Vector3.new(0, 6, 0))

	local spawnPoint = CFrame.new(0, 3.2, -80)
	local laneEnd = Vector3.new(0, 3.2, 88)

	-- 8 base plots: 4 left, 4 right.
	local plots = {}
	local zSlots = { -67.5, -22.5, 22.5, 67.5 }
	local idx = 0
	for side = -1, 1, 2 do
		for i = 1, 4 do
			idx += 1
			local plot = buildPlot(world, idx, side * 34, zSlots[i])
			table.insert(plots, plot)
		end
	end

	-- Decorations: trees, lamps, clouds, edge fence.
	local rng = Random.new(12345)
	for i = 1, 12 do
		local tx = (i % 2 == 0) and -95 or 95
		local tz = -110 + i * 18 + rng:NextNumber(-3, 3)
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk"
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Size = Vector3.new(4.5, 1.1, 1.1)
		trunk.CFrame = CFrame.new(tx, 2.25, tz)
		trunk.Color = Color3.fromRGB(110, 75, 45)
		trunk.Anchored = true
		trunk.Parent = world
		local leaves = Instance.new("Part")
		leaves.Name = "TreeLeaves"
		leaves.Shape = Enum.PartType.Ball
		leaves.Size = Vector3.new(6.5, 6.5, 6.5)
		leaves.CFrame = CFrame.new(tx, 7.5, tz)
		leaves.Color = Color3.fromRGB(60, 170, 70)
		leaves.Anchored = true
		leaves.Parent = world
	end
	for z = -100, 100, 40 do
		for _, lx in ipairs({ -14, 14 }) do
			part(world, "LampPost", Vector3.new(0.5, 7, 0.5), CFrame.new(lx, 3.5, z),
				Color3.fromRGB(50, 50, 60), Enum.Material.Metal)
			local bulb = part(world, "LampBulb", Vector3.new(1.6, 1.6, 1.6), CFrame.new(lx, 7.4, z),
				Color3.fromRGB(255, 240, 170), Enum.Material.Neon)
			bulb.CanCollide = false
		end
	end
	for i = 1, 5 do
		local cloud = part(world, "Cloud", Vector3.new(26 + i * 3, 3, 12),
			CFrame.new(-90 + i * 36, 42 + (i % 3) * 4, -70 + i * 28),
			Color3.fromRGB(250, 250, 255), Enum.Material.SmoothPlastic)
		cloud.CanCollide = false
		cloud.Transparency = 0.15
	end
	part(world, "FenceN", Vector3.new(280, 3, 0.6), CFrame.new(0, 1.5, -140), Color3.fromRGB(130, 90, 55))
	part(world, "FenceS", Vector3.new(280, 3, 0.6), CFrame.new(0, 1.5, 140), Color3.fromRGB(130, 90, 55))
	part(world, "FenceW", Vector3.new(0.6, 3, 280), CFrame.new(-140, 1.5, 0), Color3.fromRGB(130, 90, 55))
	part(world, "FenceE", Vector3.new(0.6, 3, 280), CFrame.new(140, 1.5, 0), Color3.fromRGB(130, 90, 55))

	-- Spawn location near the lane, between the middle plots.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BrainrotSpawn"
	spawn.Size = Vector3.new(9, 1, 9)
	spawn.CFrame = CFrame.new(15, 0.6, 0)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = world

	local brainrotFolder = Instance.new("Folder")
	brainrotFolder.Name = "Brainrots"
	brainrotFolder.Parent = workspace

	return {
		Folder = world,
		Plots = plots,
		SpawnPoint = spawnPoint,
		LaneEnd = laneEnd,
		PortalDisc = disc,
		SpawnLocation = spawn,
		BrainrotFolder = brainrotFolder,
	}
end

return WorldBuilder
