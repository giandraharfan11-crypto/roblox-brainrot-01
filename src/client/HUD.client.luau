-- HUD.client.luau
-- Top-right HUD panel (level, XP, coins, inventory, weapon, companion),
-- an HP bar, toast notifications from the server Notify remote, and the
-- click/tap attack input that fires the Attack remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("DinoRemotes", 15)
if not remotes then
	warn("[HUD] DinoRemotes missing")
	return
end
local attackRemote = remotes:WaitForChild("Attack", 10)
local notifyRemote = remotes:WaitForChild("Notify", 10)

local DinoData = nil
do
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	if shared then
		local dataModule = shared:WaitForChild("DinoData", 10)
		if dataModule then
			DinoData = require(dataModule)
		end
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "DinoHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui", 15)

local function label(parent, name, pos, size, text, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize or 16
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextStrokeTransparency = 0.5
	l.Parent = parent
	return l
end

-- HP bar (top centre-left).
local hpBack = Instance.new("Frame")
hpBack.Name = "HPBack"
hpBack.Position = UDim2.new(0.5, -160, 0, 12)
hpBack.Size = UDim2.fromOffset(320, 24)
hpBack.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
hpBack.BorderSizePixel = 0
hpBack.Parent = gui
local hpFill = Instance.new("Frame")
hpFill.Name = "HPFill"
hpFill.Size = UDim2.new(1, 0, 1, 0)
hpFill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
hpFill.BorderSizePixel = 0
hpFill.Parent = hpBack
local hpText = label(hpBack, "HPText", UDim2.new(0, 8, 0, 0), UDim2.new(1, -16, 1, 0), "HP 100/100", 15)
hpText.TextXAlignment = Enum.TextXAlignment.Center

-- Main panel (top right).
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Position = UDim2.new(1, -252, 0, 12)
panel.Size = UDim2.fromOffset(240, 218)
panel.BackgroundColor3 = Color3.fromRGB(20, 30, 22)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui

local title = label(panel, "Title", UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 24), "🦖 BRAINROT DINO", 18, Color3.fromRGB(255, 220, 120))
title.TextXAlignment = Enum.TextXAlignment.Center
local levelLabel = label(panel, "Level", UDim2.new(0, 10, 0, 32), UDim2.new(1, -20, 0, 20), "Level 1")
local xpLabel = label(panel, "XP", UDim2.new(0, 10, 0, 54), UDim2.new(1, -20, 0, 20), "XP 0/100")
local coinLabel = label(panel, "Koin", UDim2.new(0, 10, 0, 76), UDim2.new(1, -20, 0, 20), "🪙 Koin: 0", 16, Color3.fromRGB(255, 220, 120))
local invLabel = label(panel, "Inventori", UDim2.new(0, 10, 0, 100), UDim2.new(1, -20, 0, 40), "🪵 Kayu: 0   🪨 Batu: 0\n🍖 Daging: 0   🥚 Telur: 0", 15)
local weaponLabel = label(panel, "Weapon", UDim2.new(0, 10, 0, 144), UDim2.new(1, -20, 0, 20), "⚔️ Tongkat Kayu (10)", 15, Color3.fromRGB(180, 230, 255))
local companionLabel = label(panel, "Companion", UDim2.new(0, 10, 0, 166), UDim2.new(1, -20, 0, 40), "🐣 Pendamping: belum ada\nTetaskan telur di Kamp!", 14, Color3.fromRGB(255, 190, 230))

local hint = label(gui, "Hint", UDim2.new(0.5, -260, 1, -30), UDim2.fromOffset(520, 22), "Klik = serang • Dekati pohon/batu/sarang untuk ambil • Api unggun menyembuhkan", 14)
hint.TextXAlignment = Enum.TextXAlignment.Center

-- Toasts.
local toastLabel = label(gui, "Toast", UDim2.new(0.5, -300, 0, 48), UDim2.fromOffset(600, 30), "", 20, Color3.fromRGB(255, 240, 180))
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
local toastToken = 0
local function toast(text)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	task.delay(3.5, function()
		if toastToken == myToken then
			toastLabel.Text = ""
		end
	end)
end
if notifyRemote then
	notifyRemote.OnClientEvent:Connect(toast)
end

-- ===== Live bindings =====

local function bindStats()
	local stats = player:WaitForChild("leaderstats", 15)
	local inv = player:WaitForChild("Inventori", 15)
	if not (stats and inv) then
		return
	end
	local function refresh()
		local level = stats.Level.Value
		local need = 100
		if DinoData then
			need = DinoData.XPForLevel(level)
		end
		levelLabel.Text = "⭐ Level " .. level
		xpLabel.Text = "XP " .. stats.XP.Value .. "/" .. need
		coinLabel.Text = "🪙 Koin: " .. stats.Koin.Value
		invLabel.Text = "🪵 Kayu: " .. inv.Kayu.Value .. "   🪨 Batu: " .. inv.Batu.Value .. "\n🍖 Daging: " .. inv.Daging.Value .. "   🥚 Telur: " .. inv.Telur.Value
		if DinoData then
			local weapon = DinoData.WeaponForLevel(level)
			weaponLabel.Text = "⚔️ " .. weapon.Name .. " (" .. weapon.Damage .. " dmg)"
		end
		local companion = player:GetAttribute("CompanionName")
		if companion and companion ~= "" then
			companionLabel.Text = "🐣 Pendamping: " .. companion .. "\nAura +25% XP aktif!"
		else
			companionLabel.Text = "🐣 Pendamping: belum ada\nTetaskan telur di Kamp!"
		end
	end
	for _, v in ipairs({ stats.Level, stats.XP, stats.Koin, inv.Kayu, inv.Batu, inv.Daging, inv.Telur }) do
		v.Changed:Connect(refresh)
	end
	player:GetAttributeChangedSignal("CompanionName"):Connect(refresh)
	refresh()
end
task.spawn(bindStats)

local function bindCharacter(character)
	local hum = character:WaitForChild("Humanoid", 10)
	if not hum then
		return
	end
	local function refreshHP()
		local frac = 0
		if hum.MaxHealth > 0 then
			frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		end
		hpFill.Size = UDim2.new(frac, 0, 1, 0)
		hpFill.BackgroundColor3 = frac < 0.3 and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(90, 220, 90)
		hpText.Text = "HP " .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
	end
	hum.HealthChanged:Connect(refreshHP)
	refreshHP()
end
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(function(character)
	task.spawn(bindCharacter, character)
end)

-- ===== Attack input =====
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if attackRemote then
			attackRemote:FireServer()
		end
	end
end)

toast("🌴 Selamat datang di Brainrot Dino! Berburu, kumpulkan, tetaskan brainrot!")
