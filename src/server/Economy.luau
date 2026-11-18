-- Economy.luau
-- BRAINROT NUSANTARA - per-player money state, leaderstats, income tick,
-- buying, selling the carried brainrot and rebirth.
-- BaseManager hooks in through Economy.BuyHandler / Economy.ClearHandler so
-- this module never requires BaseManager (no circular requires).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))

local Economy = {}

Economy.BuyHandler = nil -- function(player, model), set by init
Economy.ClearHandler = nil -- function(player), set by init: destroys placed + carried models

local states = {} -- [player] = { Placed = {model,...}, PlacedPads = {[model]=padIndex}, Carried = model|nil, IncomePerSec = number }
local remotes = nil
local tickStarted = false

local function getRemote(name, className)
	local remote = remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
	return remote
end

function Economy.initRemotes()
	if remotes then
		return remotes
	end
	remotes = ReplicatedStorage:FindFirstChild("BrainrotRemotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "BrainrotRemotes"
		remotes.Parent = ReplicatedStorage
	end
	getRemote("Notify", "RemoteEvent")
	getRemote("RequestRebirth", "RemoteEvent")
	getRemote("RequestSellCarried", "RemoteEvent")
	getRemote("WaveWarning", "RemoteEvent")

	remotes.RequestRebirth.OnServerEvent:Connect(function(player)
		Economy.tryRebirth(player)
	end)
	remotes.RequestSellCarried.OnServerEvent:Connect(function(player)
		Economy.sellCarried(player)
	end)
	return remotes
end

function Economy.getRemotes()
	return Economy.initRemotes()
end

function Economy.notify(player, text)
	local folder = Economy.initRemotes()
	local remote = folder:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, text)
	end
end

function Economy.getState(player)
	return states[player]
end

function Economy.setup(player)
	if states[player] then
		return states[player]
	end
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local money = Instance.new("IntValue")
	money.Name = "Money"
	money.Value = BrainrotData.REBIRTH.StartMoney
	money.Parent = leaderstats

	local income = Instance.new("IntValue")
	income.Name = "IncomePerSec"
	income.Value = 0
	income.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = leaderstats

	leaderstats.Parent = player

	states[player] = {
		Placed = {},
		PlacedPads = {},
		Carried = nil,
		IncomePerSec = 0,
		Plot = nil,
	}
	return states[player]
end

function Economy.recomputeIncome(player)
	local state = states[player]
	if not state then
		return 0
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	local rebirths = 0
	if leaderstats and leaderstats:FindFirstChild("Rebirths") then
		rebirths = leaderstats.Rebirths.Value
	end
	local mult = BrainrotData.rebirthMult(rebirths)
	local total = 0
	for _, model in ipairs(state.Placed) do
		if model and model.Parent then
			total += (model:GetAttribute("Income") or 0)
		end
	end
	state.IncomePerSec = math.floor(total * mult)
	if leaderstats and leaderstats:FindFirstChild("IncomePerSec") then
		leaderstats.IncomePerSec.Value = state.IncomePerSec
	end
	return state.IncomePerSec
end

function Economy.addMoney(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Money") then
		leaderstats.Money.Value += amount
		return leaderstats.Money.Value
	end
	return 0
end

function Economy.getMoney(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Money") then
		return leaderstats.Money.Value
	end
	return 0
end

function Economy.startTick()
	if tickStarted then
		return
	end
	tickStarted = true
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local state = states[player]
				if state and state.IncomePerSec > 0 then
					Economy.addMoney(player, state.IncomePerSec)
				end
			end
		end
	end)
end

-- Buy a brainrot that is walking the lane. Money and hands are checked here;
-- the actual carrying is delegated to BuyHandler (BaseManager.carry).
function Economy.tryBuy(player, model)
	local state = states[player]
	if not state or not model or not model.Parent then
		return false
	end
	if model:GetAttribute("Sold") then
		return false
	end
	if state.Carried then
		Economy.notify(player, "Tanganmu penuh! Bawa dulu ke base.")
		return false
	end
	local price = model:GetAttribute("Price") or 0
	if Economy.getMoney(player) < price then
		Economy.notify(player, "Uang tidak cukup! Butuh $" .. tostring(price))
		return false
	end
	Economy.addMoney(player, -price)
	model:SetAttribute("Sold", true)
	if Economy.BuyHandler then
		Economy.BuyHandler(player, model)
	end
	Economy.notify(player, "Kamu membeli " .. (model:GetAttribute("BrainrotName") or "Brainrot") .. "!")
	return true
end

-- Sell whatever the player is carrying, for 50% of its price.
function Economy.sellCarried(player)
	local state = states[player]
	if not state or not state.Carried then
		Economy.notify(player, "Kamu tidak sedang membawa apa-apa.")
		return false
	end
	local model = state.Carried
	local price = model:GetAttribute("Price") or 0
	local gain = math.floor(price * 0.5)
	state.Carried = nil
	model:Destroy()
	Economy.addMoney(player, gain)
	Economy.notify(player, "Terjual! +$" .. tostring(gain))
	return true
end

function Economy.tryRebirth(player)
	local state = states[player]
	if not state then
		return false
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return false
	end
	local current = leaderstats.Rebirths.Value
	local cost = BrainrotData.rebirthCost(current)
	if Economy.getMoney(player) < cost then
		Economy.notify(player, "Rebirth butuh $" .. tostring(cost) .. "!")
		return false
	end
	if Economy.ClearHandler then
		Economy.ClearHandler(player)
	end
	state.Placed = {}
	state.PlacedPads = {}
	state.Carried = nil
	leaderstats.Rebirths.Value = current + 1
	leaderstats.Money.Value = BrainrotData.REBIRTH.StartMoney
	Economy.recomputeIncome(player)
	Economy.notify(player, "REBIRTH! Income sekarang x" .. tostring(BrainrotData.rebirthMult(current + 1)))
	return true
end

function Economy.cleanup(player)
	states[player] = nil
end

return Economy
