-- Steal.luau
-- BRAINROT NUSANTARA - base locking and stealing.
-- The owner locks their base for 60 seconds from the lock pad; glass walls rise
-- and the lock label counts down. Steal prompts (created by BaseManager when a
-- brainrot is placed) route here through BaseManager.StealPromptHandler.

local function sibling(name)
	local m = script.Parent:FindFirstChild(name)
	if not m then
		m = script:FindFirstChild(name)
	end
	return m
end
local Economy = require(sibling("Economy"))
local BaseManager = require(sibling("BaseManager"))

local Steal = {}

local LOCK_DURATION = 60

local started = false

local function setGlass(plot, on)
	for _, wall in ipairs(plot.GlassWalls) do
		wall.Visible = on
		wall.CanCollide = on
	end
end

function Steal.isLocked(plot)
	return plot ~= nil and plot.LockUntil > os.clock()
end

function Steal.lockPlot(player)
	local plot = BaseManager.getPlotOf(player)
	if not plot then
		return false
	end
	if Steal.isLocked(plot) then
		Economy.notify(player, "Basemu sudah terkunci!")
		return false
	end
	plot.LockUntil = os.clock() + LOCK_DURATION
	setGlass(plot, true)
	Economy.notify(player, "Base terkunci selama " .. tostring(LOCK_DURATION) .. " detik!")
	return true
end

-- Called by BaseManager when a non-owner triggers a placed brainrot's steal prompt.
local function onStealPrompt(thief, model, owner)
	local ownerState = Economy.getState(owner)
	if not ownerState then
		return
	end
	local thiefState = Economy.getState(thief)
	if not thiefState then
		return
	end
	if thiefState.Carried then
		Economy.notify(thief, "Tanganmu penuh! Tidak bisa mencuri.")
		return
	end
	local plot = ownerState.Plot
	if Steal.isLocked(plot) then
		Economy.notify(thief, "Base terkunci!")
		return
	end
	if BaseManager.removePlaced(owner, model) then
		BaseManager.carry(thief, model)
		Economy.notify(thief, "Kamu mencuri " .. (model:GetAttribute("BrainrotName") or "Brainrot") .. "!")
		Economy.notify(owner, "Brainrotmu DICURI oleh " .. thief.DisplayName .. "!")
	end
end

function Steal.init(refs)
	if started then
		return
	end
	started = true
	BaseManager.StealPromptHandler = onStealPrompt

	-- One "Kunci" prompt per lock pad, usable only by the plot's owner.
	for _, plot in ipairs(refs.Plots) do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LockPrompt"
		prompt.ActionText = "Kunci Base"
		prompt.ObjectText = "60 detik"
		prompt.MaxActivationDistance = 9
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = plot.LockPad
		prompt.Triggered:Connect(function(player)
			if plot.Owner == player then
				Steal.lockPlot(player)
			else
				Economy.notify(player, "Ini bukan basemu!")
			end
		end)
	end

	-- Countdown / glass upkeep, once per second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, plot in ipairs(refs.Plots) do
				if plot.LockUntil > 0 then
					local remaining = plot.LockUntil - os.clock()
					if remaining <= 0 then
						plot.LockUntil = 0
						setGlass(plot, false)
						plot.LockLabel.Text = "TERBUKA"
						plot.LockLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
						if plot.Owner then
							Economy.notify(plot.Owner, "Kunci basemu sudah terbuka.")
						end
					else
						plot.LockLabel.Text = "TERKUNCI " .. tostring(math.ceil(remaining)) .. "s"
						plot.LockLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
					end
				end
			end
		end
	end)
end

return Steal
