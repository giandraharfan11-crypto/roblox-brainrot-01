-- HUD.client.luau
-- BRAINROT NUSANTARA - client HUD: money, income, rebirth button, sell-carried
-- button, tsunami warning banner and toast notifications.
-- Panel lives in the TOP-RIGHT corner (the top-left is kept clear).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local leaderstats = player:WaitForChild("leaderstats")
local moneyValue = leaderstats:WaitForChild("Money")
local incomeValue = leaderstats:WaitForChild("IncomePerSec")
local rebirthsValue = leaderstats:WaitForChild("Rebirths")

local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local notifyRemote = remotes:WaitForChild("Notify")
local rebirthRemote = remotes:WaitForChild("RequestRebirth")
local sellRemote = remotes:WaitForChild("RequestSellCarried")
local waveRemote = remotes:WaitForChild("WaveWarning")

local REBIRTH_BASE_COST = 10000
local REBIRTH_GROWTH = 5

local function formatMoney(n)
	local s = tostring(math.floor(n))
	local out = ""
	local count = 0
	for i = #s, 1, -1 do
		out = string.sub(s, i, i) .. out
		count += 1
		if count % 3 == 0 and i > 1 then
			out = "," .. out
		end
	end
	return out
end

local function nextRebirthCost()
	return REBIRTH_BASE_COST * (REBIRTH_GROWTH ^ rebirthsValue.Value)
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHUD"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Main panel, top-right.
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, 12)
panel.Size = UDim2.fromOffset(250, 168)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui

local function makeLabel(name, y, text, color, size)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.new(0, 12, 0, y)
	label.Size = UDim2.new(1, -24, 0, size or 26)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = panel
	return label
end

local titleLabel = makeLabel("Title", 6, "BRAINROT NUSANTARA", Color3.fromRGB(255, 220, 90), 22)
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
local moneyLabel = makeLabel("Money", 32, "$0", Color3.fromRGB(140, 255, 150), 28)
local incomeLabel = makeLabel("Income", 62, "$0/detik", Color3.fromRGB(170, 220, 255), 20)
local rebirthLabel = makeLabel("Rebirth", 84, "Rebirth: 0 (x1)", Color3.fromRGB(255, 170, 220), 20)

local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Position = UDim2.new(0, 12, 0, 108)
rebirthButton.Size = UDim2.new(1, -24, 0, 26)
rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 60, 200)
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.TextScaled = true
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.Text = "REBIRTH"
rebirthButton.Parent = panel
rebirthButton.MouseButton1Click:Connect(function()
	rebirthRemote:FireServer()
end)

local sellButton = Instance.new("TextButton")
sellButton.Name = "SellButton"
sellButton.Position = UDim2.new(0, 12, 0, 138)
sellButton.Size = UDim2.new(1, -24, 0, 26)
sellButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
sellButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sellButton.TextScaled = true
sellButton.Font = Enum.Font.GothamBold
sellButton.Text = "Jual yang Dibawa (50%)"
sellButton.Parent = panel
sellButton.MouseButton1Click:Connect(function()
	sellRemote:FireServer()
end)

-- Tsunami warning banner, top-centre, hidden until a wave is announced.
local banner = Instance.new("TextLabel")
banner.Name = "WaveBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 14)
banner.Size = UDim2.fromOffset(560, 52)
banner.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
banner.BackgroundTransparency = 0.1
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextScaled = true
banner.Font = Enum.Font.GothamBlack
banner.Visible = false
banner.Parent = gui

-- Toast notification, bottom-centre.
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -90)
toast.Size = UDim2.fromOffset(520, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
toast.BackgroundTransparency = 0.2
toast.TextColor3 = Color3.fromRGB(255, 240, 180)
toast.TextScaled = true
toast.Font = Enum.Font.GothamBold
toast.Visible = false
toast.Parent = gui

local toastToken = 0
notifyRemote.OnClientEvent:Connect(function(text)
	toastToken += 1
	local myToken = toastToken
	toast.Text = tostring(text)
	toast.Visible = true
	task.delay(3, function()
		if toastToken == myToken then
			toast.Visible = false
		end
	end)
end)

local waveToken = 0
waveRemote.OnClientEvent:Connect(function(seconds)
	seconds = tonumber(seconds) or 10
	waveToken += 1
	local myToken = waveToken
	banner.Visible = true
	task.spawn(function()
		local remaining = seconds
		while remaining > 0 and waveToken == myToken do
			banner.Text = "GELOMBANG TSUNAMI! Lari ke base! (" .. tostring(math.ceil(remaining)) .. "s)"
			task.wait(0.25)
			remaining -= 0.25
		end
		if waveToken == myToken then
			banner.Text = "GELOMBANG DATANG! Bertahan di base!"
			task.wait(6)
			if waveToken == myToken then
				banner.Visible = false
			end
		end
	end)
end)

local function refresh()
	moneyLabel.Text = "$" .. formatMoney(moneyValue.Value)
	incomeLabel.Text = "$" .. formatMoney(incomeValue.Value) .. "/detik"
	local lvl = rebirthsValue.Value
	rebirthLabel.Text = "Rebirth: " .. tostring(lvl) .. " (x" .. tostring(1 + lvl) .. ")"
	local cost = nextRebirthCost()
	rebirthButton.Text = "REBIRTH - $" .. formatMoney(cost)
	if moneyValue.Value >= cost then
		rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 60, 200)
	else
		rebirthButton.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
	end
end

moneyValue:GetPropertyChangedSignal("Value"):Connect(refresh)
incomeValue:GetPropertyChangedSignal("Value"):Connect(refresh)
rebirthsValue:GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()
