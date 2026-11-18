-- Spawner.luau
-- BRAINROT NUSANTARA - spawns brainrots at the portal and walks them down the
-- conveyor lane. Each carries a "Beli" ProximityPrompt wired to Economy.tryBuy.

local RunService = game:GetService("RunService")

local function sibling(name)
	local m = script.Parent:FindFirstChild(name)
	if not m then
		m = script:FindFirstChild(name)
	end
	return m
end
local Economy = require(sibling("Economy"))
local BrainrotFactory = require(sibling("BrainrotFactory"))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local Spawner = {}

local MAX_ON_LANE = 6
local WALK_SPEED = 6
local SPAWN_INTERVAL = 3.5

local active = {} -- { {Model=model, X=number, Angle=number}, ... }
local started = false

function Spawner.untrack(model)
	for i = #active, 1, -1 do
		if active[i].Model == model then
			table.remove(active, i)
		end
	end
end

function Spawner.activeCount()
	local n = 0
	for _, entry in ipairs(active) do
		if entry.Model and entry.Model.Parent and not entry.Model:GetAttribute("Sold") then
			n += 1
		end
	end
	return n
end

local function spawnOne(refs, rng)
	local rarityName = BrainrotData.rollRarity(rng)
	local mutation = BrainrotData.rollMutation(rng)
	local pool = BrainrotData.charactersOfRarity(rarityName)
	if #pool == 0 then
		pool = BrainrotData.charactersOfRarity("Common")
	end
	local data = pool[rng:NextInteger(1, #pool)]
	local model = BrainrotFactory.create(data, mutation)
	local x = rng:NextNumber(-2.2, 2.2)
	local startPos = refs.SpawnPoint.Position
	model:SetPrimaryPartCFrame(CFrame.new(x, startPos.Y, startPos.Z))
	local entry = { Model = model, X = x, Angle = rng:NextNumber(0, 6.28) }
	table.insert(active, entry)

	local body = model.PrimaryPart
	if body then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuyPrompt"
		prompt.ActionText = "Beli"
		prompt.ObjectText = "$" .. tostring(data.Price) .. " - " .. data.Name
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0.25
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		prompt.Triggered:Connect(function(player)
			if Economy.tryBuy(player, model) then
				Spawner.untrack(model)
			end
		end)
	end
	return model
end

function Spawner.start(refs)
	if started then
		return
	end
	started = true
	local rng = Random.new()

	-- Walk every live lane brainrot toward the lane end; destroy at the end.
	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for i = #active, 1, -1 do
			local entry = active[i]
			local model = entry.Model
			if not model or not model.Parent or model:GetAttribute("Sold") then
				table.remove(active, i)
			else
				local body = model.PrimaryPart
				if body then
					local pos = body.Position
					local newZ = pos.Z + WALK_SPEED * dt
					if newZ >= refs.LaneEnd.Z then
						model:Destroy()
						table.remove(active, i)
					else
						entry.Angle += dt * 0.6
						local bob = math.sin(t * 4 + entry.Angle * 3) * 0.18
						model:SetPrimaryPartCFrame(
							CFrame.new(entry.X, refs.SpawnPoint.Position.Y + bob, newZ)
								* CFrame.Angles(0, entry.Angle, 0)
						)
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			if Spawner.activeCount() < MAX_ON_LANE then
				spawnOne(refs, rng)
			end
		end
	end)
end

return Spawner
