-- BrainrotFactory.luau
-- BRAINROT NUSANTARA - builds a brainrot Model out of Parts from BrainrotData.
-- create(data, mutation) -> Model, parented to Workspace.Brainrots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local BrainrotFactory = {}

local function makePart(model, name, size, offset, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = CFrame.new(offset)
	p.Parent = model
	return p
end

local function buildHat(model, hatName, headTopY, accentColor)
	if hatName == "Peci" then
		makePart(model, "Hat", Vector3.new(1.7, 0.45, 1.7), Vector3.new(0, headTopY + 0.22, 0),
			Color3.fromRGB(25, 25, 25))
	elseif hatName == "Cone" then
		local cone = Instance.new("WedgePart")
		cone.Name = "Hat"
		cone.Size = Vector3.new(1.6, 1.8, 1.6)
		cone.Color = Color3.fromRGB(255, 120, 30)
		cone.Material = Enum.Material.SmoothPlastic
		cone.Anchored = true
		cone.CanCollide = false
		cone.CFrame = CFrame.new(0, headTopY + 0.9, 0)
		cone.Parent = model
	elseif hatName == "Leaf" then
		makePart(model, "Hat", Vector3.new(1.9, 0.18, 1.1), Vector3.new(0, headTopY + 0.12, 0),
			Color3.fromRGB(70, 200, 80))
	elseif hatName == "Crown" then
		makePart(model, "Hat", Vector3.new(1.8, 0.55, 1.8), Vector3.new(0, headTopY + 0.28, 0),
			Color3.fromRGB(255, 205, 40), Enum.Material.Metal)
		makePart(model, "HatSpikeL", Vector3.new(0.4, 0.6, 0.4), Vector3.new(-0.65, headTopY + 0.8, 0),
			Color3.fromRGB(255, 205, 40), Enum.Material.Metal)
		makePart(model, "HatSpikeR", Vector3.new(0.4, 0.6, 0.4), Vector3.new(0.65, headTopY + 0.8, 0),
			Color3.fromRGB(255, 205, 40), Enum.Material.Metal)
		makePart(model, "HatSpikeM", Vector3.new(0.4, 0.7, 0.4), Vector3.new(0, headTopY + 0.85, 0),
			Color3.fromRGB(255, 205, 40), Enum.Material.Metal)
	elseif hatName == "Antenna" then
		makePart(model, "Hat", Vector3.new(0.18, 1.1, 0.18), Vector3.new(0, headTopY + 0.55, 0),
			Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		local ball = Instance.new("Part")
		ball.Name = "HatBall"
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(0.65, 0.65, 0.65)
		ball.Color = accentColor
		ball.Material = Enum.Material.Neon
		ball.Anchored = true
		ball.CanCollide = false
		ball.CFrame = CFrame.new(0, headTopY + 1.25, 0)
		ball.Parent = model
	end
end

local function applyMutation(model, mutationName)
	if mutationName == "Normal" then
		return
	end
	local parts = {}
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	if mutationName == "Gold" then
		for _, p in ipairs(parts) do
			p.Color = Color3.fromRGB(255, 200, 45)
			p.Material = Enum.Material.Neon
		end
	elseif mutationName == "Diamond" then
		for _, p in ipairs(parts) do
			p.Color = Color3.fromRGB(165, 230, 255)
			p.Material = Enum.Material.Metal
		end
	elseif mutationName == "Rainbow" then
		for i, p in ipairs(parts) do
			p.Color = Color3.fromHSV((i * 0.14) % 1, 0.85, 1)
			p.Material = Enum.Material.Neon
		end
	end
end

function BrainrotFactory.create(data, mutation)
	mutation = mutation or BrainrotData.MUTATIONS[1]
	local effectiveIncome = data.Income * mutation.Mult

	local model = Instance.new("Model")
	model.Name = data.Name

	-- Body is the PrimaryPart: roughly 3 wide, 3 tall, 2 deep, centred at origin.
	local body = makePart(model, "Body", Vector3.new(3, 3, 2), Vector3.new(0, 0, 0), data.Body)
	model.PrimaryPart = body

	-- Head on top of the body, with two black eyes on the front face (-Z front).
	makePart(model, "Head", Vector3.new(2, 1.8, 2), Vector3.new(0, 2.4, 0), data.Accent)
	makePart(model, "EyeL", Vector3.new(0.35, 0.5, 0.12), Vector3.new(-0.5, 2.55, -1.05),
		Color3.fromRGB(15, 15, 15))
	makePart(model, "EyeR", Vector3.new(0.35, 0.5, 0.12), Vector3.new(0.5, 2.55, -1.05),
		Color3.fromRGB(15, 15, 15))
	-- Little feet so it reads as a character, not a box.
	makePart(model, "FootL", Vector3.new(0.9, 0.5, 1.4), Vector3.new(-0.8, -1.7, 0), data.Accent)
	makePart(model, "FootR", Vector3.new(0.9, 0.5, 1.4), Vector3.new(0.8, -1.7, 0), data.Accent)

	buildHat(model, data.Hat, 3.3, data.Accent)
	applyMutation(model, mutation.Name)

	-- Billboard: name / rarity + mutation / income per second.
	local rarityInfo = BrainrotData.rarityInfo(data.Rarity)
	local gui = Instance.new("BillboardGui")
	gui.Name = "InfoGui"
	gui.Size = UDim2.fromOffset(260, 96)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body

	local function line(order, text, color, sizeY)
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. tostring(order)
		label.Size = UDim2.new(1, 0, 0, sizeY)
		label.Position = UDim2.new(0, 0, 0, (order - 1) * 32)
		label.BackgroundTransparency = 0.35
		label.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
		return label
	end
	line(1, data.Name, Color3.fromRGB(255, 255, 255), 32)
	local mutText = ""
	if mutation.Name ~= "Normal" then
		mutText = " " .. mutation.Name
	end
	line(2, data.Rarity .. mutText, rarityInfo.Color, 32)
	line(3, "$" .. tostring(effectiveIncome) .. "/s", Color3.fromRGB(140, 255, 150), 32)

	model:SetAttribute("BrainrotName", data.Name)
	model:SetAttribute("Rarity", data.Rarity)
	model:SetAttribute("Mutation", mutation.Name)
	model:SetAttribute("Income", effectiveIncome)
	model:SetAttribute("Price", data.Price)

	local folder = workspace:FindFirstChild("Brainrots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Brainrots"
		folder.Parent = workspace
	end
	model.Parent = folder
	return model
end

return BrainrotFactory
