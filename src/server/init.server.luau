-- init.server.luau -- BRAINROT DINO server entry point.
-- Spawn safety comes FIRST: characters must always load, unanchored and
-- able to move, even if every game module below fails.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = true

-- ===== Remotes (created before any module or client can wait on them) =====
local remotes = Instance.new("Folder")
remotes.Name = "DinoRemotes"
remotes.Parent = ReplicatedStorage
for _, remoteName in ipairs({ "Attack", "Notify" }) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = remotes
end

-- ===== Module loading (pcall so a broken module never kills wiring) =====
local function loadModule(name)
	local inst = script:FindFirstChild(name) or script.Parent:FindFirstChild(name)
	if not inst then
		warn("[Dino] module not found: " .. name)
		return nil
	end
	local ok, result = pcall(require, inst)
	if not ok then
		warn("[Dino] module failed to load: " .. name .. " -- " .. tostring(result))
		return nil
	end
	return result
end

local DinoFactory = loadModule("DinoFactory")
local Survival = loadModule("Survival")
local DinoAI = loadModule("DinoAI")
local Combat = loadModule("Combat")

-- ===== World is baked into the place file (Workspace.DinoWorld) =====
-- The static world pre-exists in Workspace (world.rbxmx via Rojo), so
-- DinoSpawn is already present before any player wiring below.

-- ===== Player wiring (connected BEFORE any module starts) =====

local function onCharacterAdded(character)
	for _, partInst in ipairs(character:GetDescendants()) do
		if partInst:IsA("BasePart") then
			partInst.Anchored = false
		end
	end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 20
		hum.PlatformStand = false
		hum.Sit = false
	end
	-- Keep MaxHealth in sync with Level once stats exist.
	if Survival then
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			pcall(Survival.ApplyMaxHealth, player)
		end
	end
	task.spawn(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		local spawnPad = workspace:FindFirstChild("DinoSpawn", true)
		if hrp and spawnPad then
			character:PivotTo(CFrame.new(spawnPad.Position + Vector3.new(0, 4, 0)))
		end
	end)
end

local function onPlayerAdded(player)
	if Survival then
		local ok, err = pcall(Survival.SetupPlayer, player)
		if not ok then
			warn("[Dino] SetupPlayer failed: " .. tostring(err))
		end
	end
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
	task.delay(2, function()
		if player.Parent and not player.Character then
			pcall(function()
				player:LoadCharacter()
			end)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	if Survival then
		pcall(Survival.CleanupPlayer, player)
	end
end)

-- ===== Start the game world and modules (each isolated in pcall) =====

if Survival and DinoFactory then
	Survival.Remotes = remotes
	Survival.Factory = DinoFactory
	local ok, err = pcall(Survival.Start)
	if not ok then
		warn("[Dino] Survival failed: " .. tostring(err))
	end
end

if DinoAI and DinoFactory then
	DinoAI.Factory = DinoFactory
	DinoAI.OnKill = function(player, speciesData)
		if Survival then
			Survival.AddXP(player, speciesData.XP)
			Survival.AddCoins(player, speciesData.Coins)
			Survival.AddItem(player, "Daging", speciesData.Meat)
			Survival.Notify(player, "🦖 " .. speciesData.Name .. " tumbang! +" .. speciesData.XP .. " XP, +" .. speciesData.Coins .. " Koin, +" .. speciesData.Meat .. " Daging")
		end
	end
	local ok, err = pcall(DinoAI.Start)
	if not ok then
		warn("[Dino] DinoAI failed: " .. tostring(err))
	end
end

if Combat then
	Combat.Remotes = remotes
	Combat.AI = DinoAI
	Combat.Stats = Survival
	local ok, err = pcall(Combat.Start)
	if not ok then
		warn("[Dino] Combat failed: " .. tostring(err))
	end
end

print("[Dino] BRAINROT DINO server started")
