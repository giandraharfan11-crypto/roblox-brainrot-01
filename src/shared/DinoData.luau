-- DinoData.luau
-- Shared data for BRAINROT DINO -- Petualangan Zaman Dinosaurus.
-- Brainrot roster, dinosaur species, weapons, level curve and map zones.

local DinoData = {}

-- XP needed to go from `level` to `level + 1`.
function DinoData.XPForLevel(level: number): number
	return math.floor(100 * (level ^ 1.5) + 0.5)
end

-- Weapon tiers. The equipped weapon is derived from the player's Level.
DinoData.Weapons = {
	{ Name = "Tongkat Kayu", Damage = 10, UnlockLevel = 1 },
	{ Name = "Kapak Batu", Damage = 22, UnlockLevel = 3 },
	{ Name = "Pedang Tulang", Damage = 40, UnlockLevel = 6 },
}

function DinoData.WeaponForLevel(level: number)
	local best = DinoData.Weapons[1]
	for _, weapon in ipairs(DinoData.Weapons) do
		if level >= weapon.UnlockLevel then
			best = weapon
		end
	end
	return best
end

-- Brainrot companions. Power is flavour/score; rarity drives hatch weights.
-- Colors are {r, g, b} 0-255 so this module stays pure data.
DinoData.Brainrots = {
	{ Name = "Tung Tung Sahur", Rarity = "Common", Power = 5, Weight = 50, Body = { 150, 100, 55 }, Accent = { 90, 60, 30 } },
	{ Name = "Kuda Nil Kepo", Rarity = "Common", Power = 6, Weight = 50, Body = { 150, 150, 160 }, Accent = { 255, 150, 200 } },
	{ Name = "Ayam Geprek Turbo", Rarity = "Common", Power = 7, Weight = 50, Body = { 255, 220, 90 }, Accent = { 220, 60, 40 } },
	{ Name = "Lirili Larila", Rarity = "Rare", Power = 12, Weight = 25, Body = { 120, 200, 120 }, Accent = { 240, 240, 220 } },
	{ Name = "Ballerina Cappuccina", Rarity = "Rare", Power = 14, Weight = 25, Body = { 255, 190, 220 }, Accent = { 150, 95, 55 } },
	{ Name = "Cengcorang Santuy", Rarity = "Rare", Power = 13, Weight = 25, Body = { 110, 180, 200 }, Accent = { 255, 255, 255 } },
	{ Name = "Cappuccino Assassino", Rarity = "Epic", Power = 24, Weight = 15, Body = { 235, 220, 200 }, Accent = { 60, 60, 70 } },
	{ Name = "Tralalero Tralala", Rarity = "Epic", Power = 26, Weight = 15, Body = { 90, 160, 255 }, Accent = { 255, 255, 255 } },
	{ Name = "Sate Padang Sakti", Rarity = "Epic", Power = 25, Weight = 15, Body = { 200, 90, 40 }, Accent = { 255, 200, 60 } },
	{ Name = "Bombardiro Crocodilo", Rarity = "Legendary", Power = 45, Weight = 7, Body = { 90, 170, 80 }, Accent = { 80, 90, 80 } },
	{ Name = "Garuda Wifi Kencang", Rarity = "Legendary", Power = 48, Weight = 7, Body = { 220, 170, 60 }, Accent = { 180, 40, 40 } },
	{ Name = "Raja Seblak Emas", Rarity = "Secret", Power = 90, Weight = 3, Body = { 255, 190, 40 }, Accent = { 255, 90, 30 } },
}

DinoData.RarityColors = {
	Common = { 200, 200, 200 },
	Rare = { 80, 170, 255 },
	Epic = { 180, 90, 255 },
	Legendary = { 255, 190, 40 },
	Secret = { 255, 80, 160 },
}

-- Roll a random brainrot using the rarity weights.
function DinoData.RollBrainrot(rng: Random)
	local total = 0
	for _, entry in ipairs(DinoData.Brainrots) do
		total += entry.Weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, entry in ipairs(DinoData.Brainrots) do
		acc += entry.Weight
		if roll <= acc then
			return entry
		end
	end
	return DinoData.Brainrots[1]
end

-- Dinosaur species. Tuned so Tongkat Kayu (10 dmg) kills a Raptor (45 HP)
-- in 5 hits, Kapak Batu (22 dmg) feels strong vs mid tiers, and a Level 6+
-- player with Pedang Tulang (40 dmg) can beat the T-Rex (340 HP, 20 dmg)
-- in a sustained fight with heals between hits.
DinoData.Dinos = {
	Raptor = {
		Name = "Raptor", HP = 45, Damage = 8, Speed = 17, XP = 30, Coins = 10, Meat = 1,
		Scale = 0.8, Body = { 200, 140, 60 }, Belly = { 240, 210, 150 }, Boss = false,
	},
	Stegosaurus = {
		Name = "Stegosaurus", HP = 95, Damage = 12, Speed = 12, XP = 50, Coins = 16, Meat = 2,
		Scale = 1.15, Body = { 110, 170, 90 }, Belly = { 200, 230, 180 }, Boss = false,
	},
	Triceratops = {
		Name = "Triceratops", HP = 130, Damage = 14, Speed = 11, XP = 65, Coins = 22, Meat = 2,
		Scale = 1.25, Body = { 150, 130, 110 }, Belly = { 225, 205, 180 }, Boss = false,
	},
	TRex = {
		Name = "T-REX", HP = 340, Damage = 20, Speed = 14, XP = 220, Coins = 120, Meat = 5,
		Scale = 1.9, Body = { 170, 60, 50 }, Belly = { 235, 200, 170 }, Boss = true,
	},
}

-- Map zones on a ~1000x1000 stud world. Rects are {minX, maxX, minZ, maxZ}.
DinoData.Zones = {
	Jungle = { Rect = { -500, -60, -500, -60 }, Label = "Hutan Rimba", Ground = { 70, 140, 60 } },
	Desert = { Rect = { 60, 500, -500, -60 }, Label = "Gurun Tulang", Ground = { 215, 190, 130 } },
	Swamp = { Rect = { -500, -60, 60, 500 }, Label = "Rawa Gelap", Ground = { 55, 95, 55 } },
	Volcano = { Rect = { 60, 500, 60, 500 }, Label = "Gunung Berapi", Ground = { 80, 70, 75 } },
	Camp = { Rect = { -60, 60, -60, 60 }, Label = "Kamp Dino", Ground = { 120, 170, 90 } },
}

function DinoData.ZoneAt(position: Vector3): string?
	for name, zone in pairs(DinoData.Zones) do
		local r = zone.Rect
		if position.X >= r[1] and position.X <= r[2] and position.Z >= r[3] and position.Z <= r[4] then
			return name
		end
	end
	return nil
end

-- Which normal species wander each wild zone.
DinoData.ZoneSpecies = {
	Jungle = { "Raptor", "Stegosaurus" },
	Desert = { "Raptor", "Triceratops" },
	Swamp = { "Stegosaurus", "Triceratops" },
	Volcano = { "Raptor", "Triceratops" },
}

return DinoData
