-- Threat.luau
-- BRAINROT NUSANTARA - the tsunami wave event. Every cycle: warn all clients,
-- count down, then sweep a giant translucent wave down the lane. Anyone caught
-- carrying a brainrot outside a base plot loses it to the water.

local function sibling(name)
	local m = script.Parent:FindFirstChild(name)
	if not m then
		m = script:FindFirstChild(name)
	end
	return m
end
local Economy = require(sibling("Economy"))
local BaseManager = require(sibling("BaseManager"))

local Threat = {}

local CYCLE_PAUSE = 75
local WARNING_SECONDS = 10
local SWEEP_SECONDS = 6

local started = false

-- Safe zone = standing on any base plot floor.
function Threat.isInSafeZone(player)
	return BaseManager.isInAnyPlot(player)
end

local function buildWave(world)
	local wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = Vector3.new(70, 14, 5)
	wave.Color = Color3.fromRGB(50, 140, 255)
	wave.Material = Enum.Material.Glass
	wave.Transparency = 0.35
	wave.Anchored = true
	wave.CanCollide = false
	wave.CFrame = CFrame.new(0, 7, -100)
	wave.Parent = world
	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Size = Vector3.new(70, 2.5, 5.6)
	foam.Color = Color3.fromRGB(240, 250, 255)
	foam.Material = Enum.Material.Neon
	foam.Transparency = 0.3
	foam.Anchored = true
	foam.CanCollide = false
	foam.CFrame = CFrame.new(0, 13.5, -100)
	foam.Parent = wave
	return wave
end

function Threat.start(refs)
	if started then
		return
	end
	started = true
	local remotes = Economy.getRemotes()
	local warning = remotes:FindFirstChild("WaveWarning")

	task.spawn(function()
		while true do
			task.wait(CYCLE_PAUSE)
			if warning then
				warning:FireAllClients(WARNING_SECONDS)
			end
			task.wait(WARNING_SECONDS)

			local wave = buildWave(refs.Folder)
			local foam = wave:FindFirstChild("Foam")
			local startZ = -100
			local endZ = 100
			local elapsed = 0
			local checkAcc = 0
			local dt = 0.05
			while elapsed < SWEEP_SECONDS do
				task.wait(dt)
				elapsed += dt
				local alpha = math.clamp(elapsed / SWEEP_SECONDS, 0, 1)
				local z = startZ + (endZ - startZ) * alpha
				wave.CFrame = CFrame.new(0, 7, z)
				if foam then
					foam.CFrame = CFrame.new(0, 13.5, z)
				end
				checkAcc += dt
				if checkAcc >= 0.25 then
					checkAcc = 0
					for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
						local state = Economy.getState(player)
						if state and state.Carried and not Threat.isInSafeZone(player) then
							if BaseManager.destroyCarried(player) then
								Economy.notify(player, "Brainrotmu hanyut terbawa gelombang!")
							end
						end
					end
				end
			end
			wave:Destroy()
		end
	end)
end

return Threat
