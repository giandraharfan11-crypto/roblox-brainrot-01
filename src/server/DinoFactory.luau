-- DinoFactory.luau
-- Builds blocky dinosaur models and small brainrot companion models.
-- Every part is Anchored and CanCollide=false; models are moved by
-- MoveModel, which reapplies each part's stored local offset to a new
-- root CFrame. No physics, no welds -- the model can never fall apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoData = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("DinoData", 10))

local DinoFactory = {}

local function colorOf(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function addPart(model, name, size, offset, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part:SetAttribute("LocalOffset", offset)
	part.Parent = model
	return part
end

-- Move every part of a factory-built model so the model root sits at cf.
function DinoFactory.MoveModel(model, cf)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("LocalOffset")
			if typeof(offset) == "CFrame" then
				child.CFrame = cf * offset
			end
		end
	end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp then
		model.PrimaryPart = hrp
	end
end

local function rootCFrame(position, facing)
	local flat = Vector3.new(position.X, position.Y, position.Z)
	local look = Vector3.new(facing.X, position.Y, facing.Z)
	if (look - flat).Magnitude < 0.01 then
		look = flat + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(flat, look)
end

local function makeLabel(parentPart, title, subtitle, titleColor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 64)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parentPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = title
	nameLabel.TextColor3 = titleColor or Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Name = "SubLabel"
	sub.Position = UDim2.new(0, 0, 0.55, 0)
	sub.Size = UDim2.new(1, 0, 0.45, 0)
	sub.BackgroundTransparency = 1
	sub.Text = subtitle or ""
	sub.TextColor3 = Color3.fromRGB(255, 240, 200)
	sub.TextStrokeTransparency = 0.4
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.Parent = gui
	return gui
end

local function makeHPBar(parentPart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HPBar"
	gui.Size = UDim2.fromOffset(180, 26)
	gui.StudsOffset = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parentPart

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.new(1, 0, 1, 0)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.BorderSizePixel = 0
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "HPFill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	return gui
end

function DinoFactory.UpdateHPBar(model)
	local hp = model:FindFirstChild("HP")
	local maxHP = model:FindFirstChild("MaxHP")
	local head = model:FindFirstChild("Head")
	if not (hp and maxHP and head) then
		return
	end
	local bar = head:FindFirstChild("HPBar")
	if not bar then
		return
	end
	local fill = bar:FindFirstChild("Back") and bar.Back:FindFirstChild("HPFill")
	if fill then
		local frac = 0
		if maxHP.Value > 0 then
			frac = math.clamp(hp.Value / maxHP.Value, 0, 1)
		end
		fill.Size = UDim2.new(frac, 0, 1, 0)
		if frac < 0.3 then
			fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)
		elseif frac < 0.6 then
			fill.BackgroundColor3 = Color3.fromRGB(240, 180, 60)
		else
			fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
		end
	end
end

-- Build a dinosaur model of the given species with its base at `position`.
function DinoFactory.BuildDino(speciesName, position)
	local data = DinoData.Dinos[speciesName]
	assert(data, "unknown species " .. tostring(speciesName))
	local s = data.Scale
	local bodyColor = colorOf(data.Body)
	local bellyColor = colorOf(data.Belly)

	local model = Instance.new("Model")
	model.Name = "Dino_" .. speciesName
	model:SetAttribute("IsDino", true)
	model:SetAttribute("Species", speciesName)
	model:SetAttribute("Boss", data.Boss)

	local hp = Instance.new("IntValue")
	hp.Name = "HP"
	hp.Value = data.HP
	hp.Parent = model
	local maxHP = Instance.new("IntValue")
	maxHP.Name = "MaxHP"
	maxHP.Value = data.HP
	maxHP.Parent = model

	-- Root sits on the ground; body parts float above it.
	addPart(model, "HumanoidRootPart", Vector3.new(2, 2, 2), CFrame.new(0, 1 * s, 0), bodyColor).Transparency = 1
	addPart(model, "Body", Vector3.new(4.4 * s, 2.8 * s, 6.4 * s), CFrame.new(0, 3.4 * s, 0), bodyColor)
	addPart(model, "Belly", Vector3.new(3.8 * s, 2.2 * s, 5.6 * s), CFrame.new(0, 2.9 * s, 0.2 * s), bellyColor)
	local head = addPart(model, "Head", Vector3.new(2.6 * s, 2.2 * s, 3 * s), CFrame.new(0, 4.6 * s, -4.2 * s), bodyColor)
	addPart(model, "Jaw", Vector3.new(2.2 * s, 0.7 * s, 2.6 * s), CFrame.new(0, 3.6 * s, -4.4 * s), bellyColor)
	addPart(model, "EyeL", Vector3.new(0.4 * s, 0.4 * s, 0.4 * s), CFrame.new(-1.35 * s, 5 * s, -5 * s), Color3.new(0, 0, 0), nil, Enum.PartType.Ball)
	addPart(model, "EyeR", Vector3.new(0.4 * s, 0.4 * s, 0.4 * s), CFrame.new(1.35 * s, 5 * s, -5 * s), Color3.new(0, 0, 0), nil, Enum.PartType.Ball)
	-- Tail tapers backwards (+Z is behind, the model faces -Z).
	addPart(model, "Tail1", Vector3.new(1.8 * s, 1.6 * s, 3 * s), CFrame.new(0, 3.6 * s, 4.4 * s), bodyColor)
	addPart(model, "Tail2", Vector3.new(1 * s, 0.9 * s, 2.6 * s), CFrame.new(0, 4 * s, 6.8 * s), bodyColor)
	-- Legs.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			addPart(model, "Leg", Vector3.new(1.1 * s, 2.4 * s, 1.1 * s), CFrame.new(sx * 1.5 * s, 1.2 * s, sz * 2.2 * s), bodyColor)
		end
	end
	-- Species flavour.
	if speciesName == "Stegosaurus" then
		for i = 0, 3 do
			addPart(model, "Plate", Vector3.new(0.4 * s, 1.8 * s, 1.4 * s), CFrame.new(0, 5.6 * s, (-2 + i * 1.4) * s), colorOf({ 230, 120, 70 }))
		end
	elseif speciesName == "Triceratops" then
		addPart(model, "Frill", Vector3.new(3.6 * s, 3.4 * s, 0.5 * s), CFrame.new(0, 5 * s, -3.2 * s), bellyColor)
		addPart(model, "Horn", Vector3.new(0.5 * s, 0.5 * s, 1.8 * s), CFrame.new(0, 4.9 * s, -6.2 * s), Color3.fromRGB(245, 240, 225))
	elseif speciesName == "Raptor" then
		addPart(model, "Crest", Vector3.new(0.4 * s, 1 * s, 2 * s), CFrame.new(0, 6 * s, -4 * s), colorOf({ 220, 70, 50 }))
	elseif speciesName == "TRex" then
		for i = 0, 4 do
			addPart(model, "Spike", Vector3.new(0.5 * s, 1 * s, 0.5 * s), CFrame.new(0, 5.4 * s, (-2.4 + i * 1.3) * s), Color3.fromRGB(245, 240, 225))
		end
	end

	makeLabel(head, data.Name .. (data.Boss and " 👑" or ""), "HP " .. data.HP, data.Boss and Color3.fromRGB(255, 120, 90) or Color3.new(1, 1, 1))
	makeHPBar(head)

	DinoFactory.MoveModel(model, rootCFrame(position, position + Vector3.new(0, 0, -1)))
	return model
end

-- Build a small brainrot companion model from a roster entry.
function DinoFactory.BuildBrainrot(entry, position)
	local bodyColor = colorOf(entry.Body)
	local accentColor = colorOf(entry.Accent)
	local rarityColor = colorOf(DinoData.RarityColors[entry.Rarity] or { 255, 255, 255 })

	local model = Instance.new("Model")
	model.Name = "Brainrot_" .. entry.Name:gsub("%s+", "")
	model:SetAttribute("IsBrainrot", true)
	model:SetAttribute("BrainrotName", entry.Name)
	model:SetAttribute("Rarity", entry.Rarity)

	addPart(model, "HumanoidRootPart", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 0.8, 0), bodyColor).Transparency = 1
	addPart(model, "Body", Vector3.new(2, 2.4, 1.4), CFrame.new(0, 2, 0), bodyColor)
	local head = addPart(model, "Head", Vector3.new(1.9, 1.7, 1.7), CFrame.new(0, 4, 0), accentColor)
	addPart(model, "Hat", Vector3.new(2.3, 0.5, 2.3), CFrame.new(0, 5, 0), rarityColor, nil, Enum.PartType.Cylinder)
	addPart(model, "EyeL", Vector3.new(0.3, 0.3, 0.3), CFrame.new(-0.5, 4.2, -0.9), Color3.new(0, 0, 0), nil, Enum.PartType.Ball)
	addPart(model, "EyeR", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0.5, 4.2, -0.9), Color3.new(0, 0, 0), nil, Enum.PartType.Ball)
	addPart(model, "FootL", Vector3.new(0.7, 0.5, 1), CFrame.new(-0.6, 0.25, 0), accentColor)
	addPart(model, "FootR", Vector3.new(0.7, 0.5, 1), CFrame.new(0.6, 0.25, 0), accentColor)

	makeLabel(head, entry.Name, entry.Rarity .. " • Power " .. entry.Power, rarityColor)
	DinoFactory.MoveModel(model, rootCFrame(position, position + Vector3.new(0, 0, -1)))
	return model
end

return DinoFactory
