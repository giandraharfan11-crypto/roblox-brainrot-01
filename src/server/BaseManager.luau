-- BaseManager.luau
-- BRAINROT NUSANTARA - plot assignment, carrying brainrots on the head,
-- auto-placing on pads, and selling placed brainrots.
-- Steal hooks in through BaseManager.StealPromptHandler (set by Steal.init).

local RunService = game:GetService("RunService")

local function sibling(name)
	local m = script.Parent:FindFirstChild(name)
	if not m then
		m = script:FindFirstChild(name)
	end
	return m
end
local Economy = require(sibling("Economy"))

local BaseManager = {}

BaseManager.StealPromptHandler = nil -- function(thief, model, owner), set by Steal

local refs = nil
local started = false

function BaseManager.init(worldRefs)
	refs = worldRefs
end

local function characterRoot(player)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local head = character:FindFirstChild("Head")
	local root = character:FindFirstChild("HumanoidRootPart")
	return root, head
end

function BaseManager.getPlotOf(player)
	local state = Economy.getState(player)
	if state then
		return state.Plot
	end
	return nil
end

function BaseManager.assignPlot(player)
	if not refs then
		return nil
	end
	local state = Economy.getState(player)
	if state and state.Plot then
		return state.Plot
	end
	for _, plot in ipairs(refs.Plots) do
		if plot.Owner == nil then
			plot.Owner = player
			plot.OwnerLabel.Text = player.DisplayName
			if state then
				state.Plot = plot
			end
			Economy.notify(player, "Base " .. tostring(plot.Index) .. " jadi milikmu!")
			return plot
		end
	end
	Economy.notify(player, "Semua base penuh!")
	return nil
end

function BaseManager.releasePlot(player)
	local state = Economy.getState(player)
	local plot = state and state.Plot
	if plot then
		plot.Owner = nil
		plot.OwnerLabel.Text = "KOSONG"
		plot.LockUntil = 0
		for k in pairs(plot.Occupied) do
			plot.Occupied[k] = nil
		end
		if state then
			state.Plot = nil
		end
	end
end

-- Is the player's root inside the floor bounds of this plot (any height near ground)?
function BaseManager.isOnPlot(player, plot)
	local root = characterRoot(player)
	if not root or not plot then
		return false
	end
	local pos = root.Position
	local center = plot.Floor.Position
	local half = plot.Floor.Size.X / 2
	return math.abs(pos.X - center.X) <= half and math.abs(pos.Z - center.Z) <= half and pos.Y < 12
end

function BaseManager.isInAnyPlot(player)
	if not refs then
		return false
	end
	for _, plot in ipairs(refs.Plots) do
		if BaseManager.isOnPlot(player, plot) then
			return true
		end
	end
	return false
end

local function isOnPart(player, part)
	local root = characterRoot(player)
	if not root or not part then
		return false
	end
	local pos = root.Position
	local center = part.Position
	return math.abs(pos.X - center.X) <= part.Size.X / 2 + 0.6
		and math.abs(pos.Z - center.Z) <= part.Size.Z / 2 + 0.6
		and pos.Y < 12
end

local function removePrompt(model, promptName)
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("ProximityPrompt") and child.Name == promptName then
			child:Destroy()
		end
	end
end

local function addPrompt(parentPart, name, actionText, objectText)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 9
	prompt.HoldDuration = 0.35
	prompt.RequiresLineOfSight = false
	prompt.Parent = parentPart
	return prompt
end

-- Carry a model above the player's head. The Heartbeat loop in start() moves it.
function BaseManager.carry(player, model)
	local state = Economy.getState(player)
	if not state or not model then
		return false
	end
	removePrompt(model, "BuyPrompt")
	removePrompt(model, "StealPrompt")
	removePrompt(model, "SellPrompt")
	state.Carried = model
	model:SetAttribute("CarriedBy", player.UserId)
	return true
end

function BaseManager.destroyCarried(player)
	local state = Economy.getState(player)
	if state and state.Carried then
		local model = state.Carried
		state.Carried = nil
		if model and model.Parent then
			model:Destroy()
		end
		return true
	end
	return false
end

-- Remove a placed model from its owner's records and free its pad (no destroy).
function BaseManager.removePlaced(owner, model)
	local state = Economy.getState(owner)
	if not state then
		return false
	end
	local plot = state.Plot
	local padIndex = state.PlacedPads[model]
	for i, m in ipairs(state.Placed) do
		if m == model then
			table.remove(state.Placed, i)
			break
		end
	end
	state.PlacedPads[model] = nil
	if plot and padIndex then
		plot.Occupied[padIndex] = nil
	end
	removePrompt(model, "StealPrompt")
	removePrompt(model, "SellPrompt")
	Economy.recomputeIncome(owner)
	return true
end

function BaseManager.sellPlaced(player, model)
	local state = Economy.getState(player)
	if not state then
		return false
	end
	local price = model:GetAttribute("Price") or 0
	local gain = math.floor(price * 0.5)
	if BaseManager.removePlaced(player, model) then
		model:Destroy()
		Economy.addMoney(player, gain)
		Economy.notify(player, "Brainrot terjual! +$" .. tostring(gain))
		return true
	end
	return false
end

function BaseManager.placeOnPad(player)
	local state = Economy.getState(player)
	if not state or not state.Carried or not state.Plot then
		return false
	end
	local plot = state.Plot
	local model = state.Carried
	for i, pad in ipairs(plot.Pads) do
		if not plot.Occupied[i] then
			plot.Occupied[i] = model
			state.PlacedPads[model] = i
			table.insert(state.Placed, model)
			state.Carried = nil
			model:SetAttribute("CarriedBy", nil)
			model:SetAttribute("PlacedBy", player.UserId)
			local body = model.PrimaryPart
			if body then
				model:SetPrimaryPartCFrame(CFrame.new(pad.Position + Vector3.new(0, 2.3, 0)))
			end
			-- Sell prompt: only the owner may use it (checked on trigger).
			local sellPrompt = addPrompt(body, "SellPrompt", "Jual 50%",
				model:GetAttribute("BrainrotName") or "Brainrot")
			sellPrompt.Triggered:Connect(function(triggerPlayer)
				if triggerPlayer == player then
					BaseManager.sellPlaced(player, model)
				else
					Economy.notify(triggerPlayer, "Ini bukan brainrotmu!")
				end
			end)
			-- Steal prompt: handled by the Steal module.
			local stealPrompt = addPrompt(body, "StealPrompt", "Curi",
				model:GetAttribute("BrainrotName") or "Brainrot")
			stealPrompt.Triggered:Connect(function(triggerPlayer)
				if triggerPlayer ~= player and BaseManager.StealPromptHandler then
					BaseManager.StealPromptHandler(triggerPlayer, model, player)
				end
			end)
			Economy.recomputeIncome(player)
			Economy.notify(player, "Brainrot terpasang! +$" .. tostring(model:GetAttribute("Income") or 0) .. "/s")
			return true
		end
	end
	Economy.notify(player, "Semua pad penuh!")
	return false
end

-- Destroy every brainrot the player owns (used by rebirth and cleanup).
function BaseManager.clearAll(player)
	local state = Economy.getState(player)
	if not state then
		return
	end
	for _, model in ipairs(state.Placed) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	if state.Plot then
		for k in pairs(state.Plot.Occupied) do
			state.Plot.Occupied[k] = nil
		end
	end
	state.Placed = {}
	state.PlacedPads = {}
	if state.Carried and state.Carried.Parent then
		state.Carried:Destroy()
	end
	state.Carried = nil
end

function BaseManager.start()
	if started then
		return
	end
	started = true

	-- Carried models ride above the head with a gentle bob.
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			local state = Economy.getState(player)
			if state and state.Carried and state.Carried.Parent then
				local _, head = characterRoot(player)
				local model = state.Carried
				if head and model.PrimaryPart then
					local bob = math.sin(t * 3 + player.UserId) * 0.25
					local target = head.CFrame * CFrame.new(0, 3.4 + bob, 0)
					model:SetPrimaryPartCFrame(target)
				end
			end
		end
	end)

	-- Periodic check: standing on your own sell pad sells the carried brainrot;
	-- standing anywhere else on your own floor places it on the first free pad.
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local state = Economy.getState(player)
				if state and state.Carried and state.Plot then
					if isOnPart(player, state.Plot.SellPad) then
						Economy.sellCarried(player)
					elseif BaseManager.isOnPlot(player, state.Plot) then
						BaseManager.placeOnPad(player)
					end
				end
			end
		end
	end)
end

return BaseManager
