-- Survival.luau
-- Player stats & progression (leaderstats + Inventori), gathering nodes,
-- egg hatching, brainrot companions, and the world tick (lava damage,
-- campfire healing, zone-entry toasts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoData = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("DinoData", 10))

local Survival = {}
Survival.Remotes = nil -- set by init before Start
Survival.Factory = nil -- set by init before Start

local companions = {} -- [player] = Model
local companionData = {} -- [player] = roster entry
local lastZone = {} -- [player] = zone name
local nodeBusy = {} -- [Instance] = true while regrowing
local rng = Random.new()

local function notify(player, text)
	if Survival.Remotes then
		local remote = Survival.Remotes:FindFirstChild("Notify")
		if remote then
			remote:FireClient(player, text)
		end
	end
end
Survival.Notify = notify

local function intValue(parent, name, value)
	local v = Instance.new("IntValue")
	v.Name = name
	v.Value = value or 0
	v.Parent = parent
	return v
end

function Survival.SetupPlayer(player)
	if not player:FindFirstChild("leaderstats") then
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		intValue(stats, "Level", 1)
		intValue(stats, "XP", 0)
		intValue(stats, "Koin", 0)
		stats.Parent = player
	end
	if not player:FindFirstChild("Inventori") then
		local inv = Instance.new("Folder")
		inv.Name = "Inventori"
		intValue(inv, "Kayu", 0)
		intValue(inv, "Batu", 0)
		intValue(inv, "Daging", 0)
		intValue(inv, "Telur", 0)
		inv.Parent = player
	end
end

function Survival.GetWeapon(player)
	local stats = player:FindFirstChild("leaderstats")
	local level = stats and stats:FindFirstChild("Level")
	return DinoData.WeaponForLevel(level and level.Value or 1)
end

local function applyMaxHealth(player)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local level = stats.Level.Value
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = 100 + 20 * (level - 1)
	end
end

Survival.ApplyMaxHealth = applyMaxHealth

function Survival.AddXP(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	-- Companion aura: +25% XP while a brainrot follows you.
	if companions[player] then
		amount = math.floor(amount * 1.25 + 0.5)
	end
	local xp = stats.XP
	local level = stats.Level
	local oldWeapon = DinoData.WeaponForLevel(level.Value).Name
	xp.Value += amount
	local leveled = false
	while xp.Value >= DinoData.XPForLevel(level.Value) do
		xp.Value -= DinoData.XPForLevel(level.Value)
		level.Value += 1
		leveled = true
	end
	if leveled then
		applyMaxHealth(player)
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		notify(player, "🎉 NAIK LEVEL! Sekarang Level " .. level.Value .. " — HP pulih penuh!")
		local newWeapon = DinoData.WeaponForLevel(level.Value)
		if newWeapon.Name ~= oldWeapon then
			notify(player, "⚔️ Senjata baru terbuka: " .. newWeapon.Name .. " (damage " .. newWeapon.Damage .. ")!")
		end
	end
end

function Survival.AddCoins(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Koin.Value += amount
	end
end

function Survival.AddItem(player, item, amount)
	local inv = player:FindFirstChild("Inventori")
	if inv and inv:FindFirstChild(item) then
		inv[item].Value += amount
	end
end

-- ===== Companions =====

local function removeCompanion(player)
	local model = companions[player]
	if model then
		model:Destroy()
	end
	companions[player] = nil
	companionData[player] = nil
end
Survival.RemoveCompanion = removeCompanion

function Survival.Hatch(player)
	local inv = player:FindFirstChild("Inventori")
	if not (inv and inv:FindFirstChild("Telur")) then
		return
	end
	if inv.Telur.Value < 1 then
		notify(player, "🥚 Kamu belum punya telur. Cari Sarang Dino di alam liar!")
		return
	end
	inv.Telur.Value -= 1
	local entry = DinoData.RollBrainrot(rng)
	removeCompanion(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local pos = hrp and (hrp.Position + Vector3.new(3, 0, 3)) or Vector3.new(0, 1, 0)
	local model = Survival.Factory.BuildBrainrot(entry, Vector3.new(pos.X, 0, pos.Z))
	model.Parent = workspace
	companions[player] = model
	companionData[player] = entry
	player:SetAttribute("CompanionName", entry.Name .. " (" .. entry.Rarity .. ")")
	notify(player, "🐣 MENETAS! " .. entry.Name .. " [" .. entry.Rarity .. "] mengikutimu! Aura +25% XP aktif.")
end

function Survival.CleanupPlayer(player)
	removeCompanion(player)
	lastZone[player] = nil
end

-- ===== Gather nodes =====

local function setNodeVisible(model, visible)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = visible and 0 or 1
			if child.Name == "Trunk" or child.Name == "Rock" then
				child.CanCollide = visible
			end
		end
	end
end

local function regrow(model, seconds)
	nodeBusy[model] = true
	setNodeVisible(model, false)
	task.delay(seconds, function()
		nodeBusy[model] = nil
		if model.Parent then
			setNodeVisible(model, true)
		end
	end)
end

local function anchorPartOf(model)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function onNodeTriggered(nodeType, model)
	return function(player)
		if nodeBusy[model] then
			return
		end
		if nodeType == "Berry" then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Health = math.min(hum.MaxHealth, hum.Health + 15)
			end
			Survival.AddXP(player, 5)
			notify(player, "🫐 Buah hutan! +15 HP, +5 XP")
			regrow(model, 20)
		elseif nodeType == "Wood" then
			Survival.AddItem(player, "Kayu", 1)
			Survival.AddXP(player, 2)
			notify(player, "🪵 +1 Kayu")
			regrow(model, 25)
		elseif nodeType == "Stone" then
			Survival.AddItem(player, "Batu", 1)
			Survival.AddXP(player, 2)
			notify(player, "🪨 +1 Batu")
			regrow(model, 25)
		elseif nodeType == "Nest" then
			if rng:NextNumber() < 0.7 then
				Survival.AddItem(player, "Telur", 1)
				notify(player, "🥚 Kamu dapat Telur Dino! Tetaskan di alas pink di Kamp.")
			else
				Survival.AddItem(player, "Daging", 1)
				notify(player, "🍖 Sarangnya kosong, tapi ada sisa daging. +1 Daging")
			end
			Survival.AddXP(player, 5)
			regrow(model, 30)
		end
	end
end

local function setupNodes()
	local world = workspace:FindFirstChild("DinoWorld")
	if not world then
		return
	end
	local labels = {
		Berry = { "Ambil Buah", "🫐 Ambil Buah" },
		Wood = { "Tebang Kayu", "🪵 Tebang Kayu" },
		Stone = { "Ambil Batu", "🪨 Ambil Batu" },
		Nest = { "Ambil Telur", "🥚 Periksa Sarang" },
	}
	for _, inst in ipairs(world:GetDescendants()) do
		local nodeType = inst:GetAttribute("NodeType")
		if nodeType and labels[nodeType] and inst:IsA("Model") then
			local anchor = anchorPartOf(inst)
			if anchor then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "GatherPrompt"
				prompt.ActionText = labels[nodeType][1]
				prompt.ObjectText = labels[nodeType][2]
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 10
				prompt.Parent = anchor
				prompt.Triggered:Connect(onNodeTriggered(nodeType, inst))
			end
		elseif nodeType == "Hatch" and inst:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HatchPrompt"
			prompt.ActionText = "Tetaskan Telur"
			prompt.ObjectText = "🐣 Penetasan Brainrot"
			prompt.HoldDuration = 0.6
			prompt.MaxActivationDistance = 10
			prompt.Parent = inst
			prompt.Triggered:Connect(function(player)
				Survival.Hatch(player)
			end)
		end
	end
end

-- ===== World tick: lava, campfire, zones, companions =====

local function playerRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function worldTick()
	local world = workspace:FindFirstChild("DinoWorld")
	local lavaParts, firePos = {}, nil
	if world then
		for _, inst in ipairs(world:GetDescendants()) do
			if inst:IsA("BasePart") and inst:GetAttribute("IsLava") then
				table.insert(lavaParts, inst)
			elseif inst:IsA("BasePart") and inst:GetAttribute("IsCampfire") then
				firePos = inst.Position
			end
		end
	end
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local hrp, hum = playerRoot(player)
			if hrp and hum and hum.Health > 0 then
				-- Lava damage.
				for _, lava in ipairs(lavaParts) do
					local dx = math.abs(hrp.Position.X - lava.Position.X)
					local dz = math.abs(hrp.Position.Z - lava.Position.Z)
					if dx <= lava.Size.X / 2 and dz <= lava.Size.Z / 2 and hrp.Position.Y < lava.Position.Y + 6 then
						hum:TakeDamage(12)
						notify(player, "🔥 AWAS LAVA! Cepat menjauh!")
						break
					end
				end
				-- Campfire heal: ~5 HP per second nearby.
				if firePos and (hrp.Position - firePos).Magnitude <= 16 and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + 5)
				end
				-- Zone-entry toast (once per zone change).
				local zone = DinoData.ZoneAt(hrp.Position)
				if zone and lastZone[player] ~= zone then
					local first = lastZone[player] == nil
					lastZone[player] = zone
					if not first then
						notify(player, "📍 Memasuki: " .. DinoData.Zones[zone].Label)
					end
				end
			end
		end
	end
end

local function companionLoop()
	while true do
		task.wait(0.2)
		for player, model in pairs(companions) do
			local hrp = playerRoot(player)
			if not model.Parent then
				companions[player] = nil
				companionData[player] = nil
			elseif hrp then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root then
					local behind = hrp.Position - hrp.CFrame.LookVector * 4 + Vector3.new(2.5, 0, 0)
					local target = Vector3.new(behind.X, 0, behind.Z)
					local current = root.Position
					local flat = Vector3.new(current.X, 0, current.Z)
					local dist = (target - flat).Magnitude
					if dist > 40 then
						Survival.Factory.MoveModel(model, CFrame.lookAt(target, target + hrp.CFrame.LookVector))
					elseif dist > 1.2 then
						local step = target - flat
						local newPos = flat + step.Unit * math.min(dist, 3.2)
						Survival.Factory.MoveModel(model, CFrame.lookAt(newPos, newPos + step))
					end
				end
			end
		end
	end
end

function Survival.Start()
	setupNodes()
	task.spawn(worldTick)
	task.spawn(companionLoop)
	for _, player in ipairs(Players:GetPlayers()) do
		Survival.SetupPlayer(player)
	end
end

return Survival
