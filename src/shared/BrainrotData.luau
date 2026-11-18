-- BrainrotData.luau
-- BRAINROT NUSANTARA - pure data module: rarities, mutations, characters, rebirth.
-- No side effects, no game services beyond Random passed in by callers.

local BrainrotData = {}

-- Ordered rarities: index 1 is the most common, last is the rarest.
BrainrotData.RARITIES = {
	{ Name = "Common", Weight = 100, Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Rare", Weight = 45, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Weight = 18, Color = Color3.fromRGB(170, 85, 255) },
	{ Name = "Legendary", Weight = 6, Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Weight = 2, Color = Color3.fromRGB(255, 70, 120) },
	{ Name = "Secret", Weight = 1, Color = Color3.fromRGB(40, 255, 200) },
}

-- Mutations multiply income. Rainbow is the rarest by far.
BrainrotData.MUTATIONS = {
	{ Name = "Normal", Mult = 1, Weight = 100 },
	{ Name = "Gold", Mult = 2, Weight = 22 },
	{ Name = "Diamond", Mult = 3, Weight = 8 },
	{ Name = "Rainbow", Mult = 10, Weight = 2 },
}

-- Original absurd Indonesian characters. Price and Income climb steeply per rarity.
-- Hat is one of: "Peci" | "Cone" | "Leaf" | "Crown" | "Antenna" | "None"
BrainrotData.CHARACTERS = {
	-- Common
	{ Name = "Tahu Bulat Dadakan", Rarity = "Common", Price = 50, Income = 1,
		Body = Color3.fromRGB(245, 220, 160), Accent = Color3.fromRGB(180, 130, 60), Hat = "None" },
	{ Name = "Onde-Onde Berotot", Rarity = "Common", Price = 90, Income = 2,
		Body = Color3.fromRGB(250, 240, 210), Accent = Color3.fromRGB(120, 200, 90), Hat = "Leaf" },
	{ Name = "Lele Peci Joget", Rarity = "Common", Price = 140, Income = 3,
		Body = Color3.fromRGB(110, 140, 160), Accent = Color3.fromRGB(30, 30, 30), Hat = "Peci" },
	-- Rare
	{ Name = "Siput Turbo Skateboard", Rarity = "Rare", Price = 450, Income = 9,
		Body = Color3.fromRGB(255, 170, 90), Accent = Color3.fromRGB(80, 180, 255), Hat = "Antenna" },
	{ Name = "Ayam Geprek Terbang", Rarity = "Rare", Price = 700, Income = 14,
		Body = Color3.fromRGB(255, 240, 230), Accent = Color3.fromRGB(230, 60, 40), Hat = "Leaf" },
	{ Name = "Bakso Beranak", Rarity = "Rare", Price = 1000, Income = 20,
		Body = Color3.fromRGB(190, 130, 90), Accent = Color3.fromRGB(240, 230, 200), Hat = "None" },
	-- Epic
	{ Name = "Kucing Oren Barista", Rarity = "Epic", Price = 3500, Income = 70,
		Body = Color3.fromRGB(255, 150, 50), Accent = Color3.fromRGB(90, 60, 40), Hat = "Peci" },
	{ Name = "Durian Bluetooth", Rarity = "Epic", Price = 5200, Income = 105,
		Body = Color3.fromRGB(140, 190, 70), Accent = Color3.fromRGB(70, 140, 255), Hat = "Antenna" },
	{ Name = "Sate Taichan Ninja", Rarity = "Epic", Price = 7500, Income = 150,
		Body = Color3.fromRGB(240, 220, 190), Accent = Color3.fromRGB(40, 40, 50), Hat = "Cone" },
	-- Legendary
	{ Name = "Bajaj Berhantu", Rarity = "Legendary", Price = 28000, Income = 560,
		Body = Color3.fromRGB(255, 130, 40), Accent = Color3.fromRGB(160, 220, 255), Hat = "Antenna" },
	{ Name = "Kopi Tubruk Mecha", Rarity = "Legendary", Price = 42000, Income = 840,
		Body = Color3.fromRGB(90, 60, 45), Accent = Color3.fromRGB(200, 200, 210), Hat = "Crown" },
	{ Name = "Jamu Jetpack", Rarity = "Legendary", Price = 60000, Income = 1200,
		Body = Color3.fromRGB(90, 200, 120), Accent = Color3.fromRGB(255, 120, 60), Hat = "Antenna" },
	-- Mythic
	{ Name = "Pisang Goreng Kripto", Rarity = "Mythic", Price = 220000, Income = 4600,
		Body = Color3.fromRGB(255, 215, 60), Accent = Color3.fromRGB(60, 220, 160), Hat = "Crown" },
	{ Name = "Kerucut Hantu Tol", Rarity = "Mythic", Price = 350000, Income = 7200,
		Body = Color3.fromRGB(255, 110, 40), Accent = Color3.fromRGB(240, 240, 255), Hat = "Cone" },
	-- Secret
	{ Name = "Raksasa Es Teh", Rarity = "Secret", Price = 2500000, Income = 55000,
		Body = Color3.fromRGB(200, 120, 50), Accent = Color3.fromRGB(120, 230, 255), Hat = "Crown" },
}

-- Lookup by character name.
BrainrotData.ByName = {}
for _, ch in ipairs(BrainrotData.CHARACTERS) do
	BrainrotData.ByName[ch.Name] = ch
end

function BrainrotData.characterFor(name)
	return BrainrotData.ByName[name]
end

-- All characters of one rarity name (array, may be empty).
function BrainrotData.charactersOfRarity(rarityName)
	local out = {}
	for _, ch in ipairs(BrainrotData.CHARACTERS) do
		if ch.Rarity == rarityName then
			table.insert(out, ch)
		end
	end
	return out
end

local function totalWeight(list)
	local total = 0
	for _, item in ipairs(list) do
		total += item.Weight
	end
	return total
end

local function weightedPick(list, rng)
	local total = totalWeight(list)
	if total <= 0 then
		return list[1]
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, item in ipairs(list) do
		acc += item.Weight
		if roll <= acc then
			return item
		end
	end
	return list[#list]
end

-- rng is a Random instance; a fresh one is made when omitted.
function BrainrotData.rollRarity(rng)
	rng = rng or Random.new()
	local entry = weightedPick(BrainrotData.RARITIES, rng)
	return entry.Name
end

function BrainrotData.rollMutation(rng)
	rng = rng or Random.new()
	return weightedPick(BrainrotData.MUTATIONS, rng)
end

function BrainrotData.rarityInfo(rarityName)
	for _, r in ipairs(BrainrotData.RARITIES) do
		if r.Name == rarityName then
			return r
		end
	end
	return BrainrotData.RARITIES[1]
end

-- Rebirth: going from level L to L+1 costs 10000 * 5^L Money.
-- Income multiplier at level L is 1 + L.
BrainrotData.REBIRTH = {
	BaseCost = 10000,
	CostGrowth = 5,
	StartMoney = 250,
}

function BrainrotData.rebirthCost(currentLevel)
	return BrainrotData.REBIRTH.BaseCost * (BrainrotData.REBIRTH.CostGrowth ^ currentLevel)
end

function BrainrotData.rebirthMult(level)
	return 1 + level
end

return BrainrotData
