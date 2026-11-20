-- DinoAI.luau
-- Spawning and behaviour for wild dinosaurs. Dinos are anchored factory
-- models moved by a server loop that lerps their root CFrame toward a
-- wander point or the nearest player. Combat calls DamageDino; death
-- awards go through the OnKill callback wired by init.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DinoData = require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("DinoData", 10))

local DinoAI = {}
DinoAI.Factory = nil -- set by init
DinoAI.OnKill = nil -- function(player, speciesData) set by init

local MAX_NORMAL = 14
local state = {} -- [model] = { home, wander, pos, lastAttack, flashBusy }
local dinoFolder = nil
local rng = Random.new()

local function flatY(v, y)
	return Vector3.new(v.X, y, v.Z)
end

function DinoAI.GetDinosFolder()
	if not dinoFolder or not dinoFolder.Parent then
		dinoFolder = workspace:FindFirstChild("Dinos")
		if not dinoFolder then
			dinoFolder = Instance.new("Folder")
			dinoFolder.Name = "Dinos"
			dinoFolder.Parent = workspace
		end
	end
	return dinoFolder
end

function DinoAI.CountAlive(bossOnly)
	local count = 0
	for model in pairs(state) do
		if model.Parent then
			local isBoss = model:GetAttribute("Boss") == true
			if bossOnly == nil or isBoss == bossOnly then
				count += 1
			end
		end
	end
	return count
end

function DinoAI.SpawnDino(speciesName, position)
	local data = DinoData.Dinos[speciesName]
	if not data then
		return nil
	end
	local model = DinoAI.Factory.BuildDino(speciesName, position)
	model.Parent = DinoAI.GetDinosFolder()
	state[model] = {
		home = position,
		wander = position,
		pos = position,
		lastAttack = 0,
		flashBusy = false,
		nextWander = 0,
	}
	return model
end

local function randomPointIn(rect, margin)
	return Vector3.new(rng:NextNumber(rect[1] + margin, rect[2] - margin), 0, rng:NextNumber(rect[3] + margin, rect[4] - margin))
end

function DinoAI.SpawnNormal()
	local zones = { "Jungle", "Desert", "Swamp", "Volcano" }
	local zone = zones[rng:NextInteger(1, #zones)]
	local speciesList = DinoData.ZoneSpecies[zone]
	local species = speciesList[rng:NextInteger(1, #speciesList)]
	local rect = DinoData.Zones[zone].Rect
	return DinoAI.SpawnDino(species, randomPointIn(rect, 60))
end

function DinoAI.SpawnBoss()
	local rect = DinoData.Zones.Volcano.Rect
	return DinoAI.SpawnDino("TRex", randomPointIn(rect, 90))
end

-- ===== Damage / death =====

local function flashRed(model, st)
	if st.flashBusy then
		return
	end
	st.flashBusy = true
	local saved = {}
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BasePart") and child.Transparency < 1 then
			saved[child] = child.Color
			child.Color = Color3.fromRGB(255, 60, 50)
		end
	end
	task.delay(0.12, function()
		for partInst, col in pairs(saved) do
			if partInst.Parent then
				partInst.Color = col
			end
		end
		st.flashBusy = false
	end)
end

function DinoAI.DamageDino(model, amount, attacker, fromPosition)
	local st = state[model]
	local hp = model:FindFirstChild("HP")
	if not st or not hp or hp.Value <= 0 then
		return false
	end
	hp.Value -= amount
	DinoAI.Factory.UpdateHPBar(model)
	flashRed(model, st)
	-- Small knockback away from the attacker.
	if fromPosition then
		local away = flatY(st.pos - fromPosition, 0)
		if away.Magnitude > 0.1 then
			st.pos = st.pos + away.Unit * 1.5
			st.pos = Vector3.new(math.clamp(st.pos.X, -495, 495), 0, math.clamp(st.pos.Z, -495, 495))
		end
	end
	if hp.Value <= 0 then
		local speciesName = model:GetAttribute("Species")
		local data = DinoData.Dinos[speciesName]
		state[model] = nil
		model:Destroy()
		if attacker and data and DinoAI.OnKill then
			pcall(DinoAI.OnKill, attacker, data)
		end
		return true
	end
	return false
end

-- ===== Behaviour loop =====

local function nearestPlayer(pos, range)
	local best, bestDist = nil, range
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (flatY(hrp.Position, 0) - pos).Magnitude
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best, bestDist
end

local function aiLoop()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for model, st in pairs(state) do
			if not model.Parent then
				state[model] = nil
			else
				local speciesName = model:GetAttribute("Species")
				local data = DinoData.Dinos[speciesName]
				if data then
					local targetPlayer, dist = nearestPlayer(st.pos, 60)
					local targetPos
					local chasing = false
					if targetPlayer then
						local hrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
						if hrp then
							targetPos = flatY(hrp.Position, 0)
							chasing = true
						end
					end
					if not targetPos then
						if now >= st.nextWander then
							st.nextWander = now + rng:NextNumber(3, 7)
							local dx = rng:NextNumber(-45, 45)
							local dz = rng:NextNumber(-45, 45)
							st.wander = Vector3.new(
								math.clamp(st.home.X + dx, -490, 490),
								0,
								math.clamp(st.home.Z + dz, -490, 490)
							)
						end
						targetPos = st.wander
					end
					local toTarget = targetPos - st.pos
					local flatDist = toTarget.Magnitude
					if chasing and dist and dist <= 5.5 then
						-- Attack on a 1s cooldown.
						if now - st.lastAttack >= 1 then
							st.lastAttack = now
							local hum = targetPlayer.Character and targetPlayer.Character:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then
								hum:TakeDamage(data.Damage)
							end
						end
					elseif flatDist > 0.4 then
						local speed = chasing and data.Speed or data.Speed * 0.4
						local step = math.min(flatDist, speed * 0.1)
						st.pos = st.pos + toTarget.Unit * step
						local face = st.pos + toTarget
						DinoAI.Factory.MoveModel(model, CFrame.lookAt(st.pos, Vector3.new(face.X, 0, face.Z)))
					end
				end
			end
		end
	end
end

local function spawnerLoop()
	-- Boss schedule: check often, respawn ~120s after it dies.
	local lastBossCheck = 0
	while true do
		task.wait(3)
		local ok, err = pcall(function()
			if DinoAI.CountAlive(false) < MAX_NORMAL then
				DinoAI.SpawnNormal()
			end
			if os.clock() - lastBossCheck >= 30 then
				lastBossCheck = os.clock()
				if DinoAI.CountAlive(true) == 0 then
					-- Respawn the boss on the next 120s cadence window.
					task.delay(90, function()
						if DinoAI.CountAlive(true) == 0 then
							DinoAI.SpawnBoss()
						end
					end)
				end
			end
		end)
		if not ok then
			warn("[DinoAI] spawner: " .. tostring(err))
		end
	end
end

function DinoAI.Start()
	DinoAI.GetDinosFolder()
	for _ = 1, 10 do
		DinoAI.SpawnNormal()
	end
	DinoAI.SpawnBoss()
	task.spawn(aiLoop)
	task.spawn(spawnerLoop)
end

return DinoAI
