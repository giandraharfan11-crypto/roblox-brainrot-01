-- init.server.luau
-- BRAINROT NUSANTARA - server entry point. Wires every module together:
-- world, economy, bases, spawner, tsunami threat and stealing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local function req(name)
	local m = script:FindFirstChild(name)
	if not m then
		m = script.Parent:FindFirstChild(name)
	end
	assert(m, "BrainrotNusantara: missing server module " .. name)
	return require(m)
end

local WorldBuilder = req("WorldBuilder")
local Economy = req("Economy")
local BaseManager = req("BaseManager")
local Spawner = req("Spawner")
local Threat = req("Threat")
local Steal = req("Steal")

local refs = WorldBuilder.build()

Economy.initRemotes()
Economy.startTick()

BaseManager.init(refs)
BaseManager.start()

-- Cross-module wiring (keeps the require graph acyclic).
Economy.BuyHandler = function(player, model)
	Spawner.untrack(model)
	BaseManager.carry(player, model)
end
Economy.ClearHandler = function(player)
	BaseManager.clearAll(player)
end

Spawner.start(refs)
Threat.start(refs)
Steal.init(refs)

local function onPlayerAdded(player)
	Economy.setup(player)
	BaseManager.assignPlot(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid.WalkSpeed = 20
		end
	end)
end

local function onPlayerRemoving(player)
	BaseManager.clearAll(player)
	BaseManager.releasePlot(player)
	Economy.cleanup(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

-- Slowly spin the portal disc.
local angle = 0
RunService.Heartbeat:Connect(function(dt)
	angle += dt * 0.8
	refs.PortalDisc.CFrame = CFrame.new(0, 6, -90)
		* CFrame.Angles(0, 0, math.rad(90))
		* CFrame.Angles(angle, 0, 0)
end)

print("[BrainrotNusantara] server siap")
