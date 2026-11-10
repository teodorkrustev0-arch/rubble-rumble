--[[
	PartCatalog  (ModuleScript)
	Location: ReplicatedStorage > Shared > PartCatalog

	Defines what robot parts exist: the 5 slots, the rarities and the sets.
	A robot part ("item") is just a small table:
		{ Id = "p12", Slot = "Head", Set = "Pizza", Rarity = "Rare" }
]]

local Config = require(script.Parent.Config)

local Catalog = {}

-- A robot needs one part in each of these slots.
Catalog.Slots = { "Head", "Body", "Arms", "Legs", "Core" }

-- Chance = spawn weight (they add up to 100, so they read as percentages).
-- Price  = cost on the conveyor.   Income = coins per second for that part.
Catalog.Rarities = {
	{ Name = "Common", Chance = 60, Price = 25, Income = 1, Color = Color3.fromRGB(190, 190, 190) },
	{ Name = "Rare", Chance = 25, Price = 100, Income = 4, Color = Color3.fromRGB(60, 140, 255) },
	{ Name = "Epic", Chance = 10, Price = 400, Income = 12, Color = Color3.fromRGB(170, 70, 255) },
	{ Name = "Legendary", Chance = 4, Price = 1500, Income = 40, Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Chance = 1, Price = 6000, Income = 150, Color = Color3.fromRGB(255, 60, 90) },
}

-- Add your own sets here. Key is what gets saved, Name is what players see.
Catalog.Sets = {
	{ Key = "Pizza", Name = "Pizza Bot" },
	{ Key = "Ninja", Name = "Ninja Bot" },
	{ Key = "Space", Name = "Space Bot" },
	{ Key = "Pirate", Name = "Pirate Bot" },
}

-- Lookup tables so we can go from a name to its definition quickly.
Catalog.RarityByName = {}
Catalog.RarityIndex = {}
for index, rarity in ipairs(Catalog.Rarities) do
	Catalog.RarityByName[rarity.Name] = rarity
	Catalog.RarityIndex[rarity.Name] = index
end

Catalog.SetByKey = {}
for _, set in ipairs(Catalog.Sets) do
	Catalog.SetByKey[set.Key] = set
end

Catalog.SlotIsValid = {}
for _, slot in ipairs(Catalog.Slots) do
	Catalog.SlotIsValid[slot] = true
end

local random = Random.new()

-- Picks a rarity using the Chance weights.
-- minIndex (optional) skips the cheaper rarities: 2 = Rare or better.
function Catalog.RollRarity(minIndex)
	minIndex = minIndex or 1
	local total = 0
	for i = minIndex, #Catalog.Rarities do
		total += Catalog.Rarities[i].Chance
	end
	local roll = random:NextNumber() * total
	for i = minIndex, #Catalog.Rarities do
		roll -= Catalog.Rarities[i].Chance
		if roll <= 0 then
			return Catalog.Rarities[i]
		end
	end
	return Catalog.Rarities[#Catalog.Rarities]
end

-- Makes a random item (without an Id - PlayerData gives it one when owned).
function Catalog.RollItem(minRarityIndex)
	return {
		Slot = Catalog.Slots[random:NextInteger(1, #Catalog.Slots)],
		Set = Catalog.Sets[random:NextInteger(1, #Catalog.Sets)].Key,
		Rarity = Catalog.RollRarity(minRarityIndex).Name,
	}
end

-- True if the table looks like a real item. Used to clean loaded save data.
function Catalog.IsValidItem(item)
	return type(item) == "table"
		and Catalog.SlotIsValid[item.Slot] == true
		and Catalog.SetByKey[item.Set] ~= nil
		and Catalog.RarityByName[item.Rarity] ~= nil
end

-- "Pizza Bot Head"
function Catalog.DisplayName(item)
	return Catalog.SetByKey[item.Set].Name .. " " .. item.Slot
end

function Catalog.GetRarity(item)
	return Catalog.RarityByName[item.Rarity]
end

-- robot = { Head = item, Body = item, ... } (some slots may be missing)
-- Returns: coinsPerSecond, isComplete, hasSetBonus
-- An incomplete robot earns nothing.
function Catalog.RobotIncome(robot)
	local income = 0
	local firstSet = nil
	local sameSet = true
	for _, slot in ipairs(Catalog.Slots) do
		local item = robot[slot]
		if not item then
			return 0, false, false
		end
		income += Catalog.RarityByName[item.Rarity].Income
		if firstSet == nil then
			firstSet = item.Set
		elseif item.Set ~= firstSet then
			sameSet = false
		end
	end
	if sameSet then
		income *= Config.SetBonus
	end
	return income, true, sameSet
end

return Catalog
