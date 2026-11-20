-- Combat.luau
-- Server side of click/tap attacks: the client fires the "Attack" remote,
-- we enforce a per-player cooldown and hit the nearest dino in front.

local Combat = {}
Combat.Remotes = nil -- set by init
Combat.AI = nil -- set by init (DinoAI)
Combat.Stats = nil -- set by init (Survival)

local COOLDOWN = 0.45
local RANGE = 7
local lastAttack = {} -- [player] = os.clock()

function Combat.Start()
	local remotes = Combat.Remotes
	if not remotes then
		warn("[Combat] no remotes wired")
		return
	end
	local attack = remotes:WaitForChild("Attack", 10)
	if not attack then
		warn("[Combat] Attack remote missing")
		return
	end
	attack.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastAttack[player] and now - lastAttack[player] < COOLDOWN then
			return
		end
		lastAttack[player] = now

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local folder = workspace:FindFirstChild("Dinos")
		if not folder then
			return
		end
		local look = hrp.CFrame.LookVector
		local best, bestDist = nil, RANGE
		for _, model in ipairs(folder:GetChildren()) do
			if model:GetAttribute("IsDino") then
				local root = model:FindFirstChild("HumanoidRootPart")
				local hp = model:FindFirstChild("HP")
				if root and hp and hp.Value > 0 then
					local offset = root.Position - hrp.Position
					local dist = Vector3.new(offset.X, 0, offset.Z).Magnitude
					if dist <= bestDist then
						local dir = Vector3.new(offset.X, 0, offset.Z)
						local dot = 0
						if dir.Magnitude > 0.1 then
							dot = Vector3.new(look.X, 0, look.Z).Unit:Dot(dir.Unit)
						end
						if dot > 0.2 or dist < 2.5 then
							best, bestDist = model, dist
						end
					end
				end
			end
		end
		if best then
			local weapon = Combat.Stats.GetWeapon(player)
			Combat.AI.DamageDino(best, weapon.Damage, player, hrp.Position)
		end
	end)
end

return Combat
