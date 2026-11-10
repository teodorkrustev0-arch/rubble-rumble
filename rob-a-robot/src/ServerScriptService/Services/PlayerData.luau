--[[
	PlayerData  (ModuleScript)
	Location: ServerScriptService > Services > PlayerData

	Holds every player's "profile" in server memory. This is the single source
	of truth for coins, parts and robots - clients never get to change it.

	profile = {
		Coins    = 200,
		Parts    = { item, item, ... },             -- inventory (not placed)
		Robots   = { {Head=item, ...}, {}, {} },    -- one table per build pad
		Upgrades = { Guards=0, Pads=0, CarrySpeed=0, LockTime=0 },
		CanSave  = true,                            -- false if loading failed
	}
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local PlayerData = {}

local profiles = {} -- [Player] = profile
local nextId = 0

-- Every owned item gets an Id that is unique on this server, so the client
-- can say "place item p12" without sending the item itself.
local function newId()
	nextId += 1
	return "p" .. nextId
end

local function defaultProfile()
	local profile = {
		Coins = Config.StartingCoins,
		Parts = {},
		Robots = {},
		Upgrades = {},
		CanSave = true,
	}
	for i = 1, Config.MaxPads do
		profile.Robots[i] = {}
	end
	for _, def in ipairs(Config.Shop) do
		profile.Upgrades[def.Key] = 0
	end
	return profile
end

-- Copies only the fields we trust out of a loaded/saved item.
local function cleanItem(raw)
	if not Catalog.IsValidItem(raw) then
		return nil
	end
	return { Id = newId(), Slot = raw.Slot, Set = raw.Set, Rarity = raw.Rarity }
end

-- Builds a safe profile from whatever came out of the DataStore. Anything
-- missing or broken falls back to the default, so old saves keep working
-- when you add new features.
local function sanitize(raw)
	local profile = defaultProfile()
	if type(raw) ~= "table" then
		return profile
	end

	if type(raw.Coins) == "number" and raw.Coins == raw.Coins and raw.Coins >= 0 then
		profile.Coins = math.floor(raw.Coins)
	end

	if type(raw.Parts) == "table" then
		for _, rawItem in ipairs(raw.Parts) do
			local item = cleanItem(rawItem)
			if item then
				table.insert(profile.Parts, item)
			end
		end
	end

	if type(raw.Robots) == "table" then
		for i = 1, Config.MaxPads do
			local rawRobot = raw.Robots[i]
			if type(rawRobot) == "table" then
				for _, slot in ipairs(Catalog.Slots) do
					local item = cleanItem(rawRobot[slot])
					if item and item.Slot == slot then
						profile.Robots[i][slot] = item
					end
				end
			end
		end
	end

	if type(raw.Upgrades) == "table" then
		for _, def in ipairs(Config.Shop) do
			local level = raw.Upgrades[def.Key]
			if type(level) == "number" and level == level then
				profile.Upgrades[def.Key] = math.clamp(math.floor(level), 0, #def.Prices)
			end
		end
	end

	return profile
end

-- Called once when a player joins. rawData is nil for new players.
function PlayerData.Create(player, rawData)
	local profile = sanitize(rawData)
	profiles[player] = profile

	-- "leaderstats" is the standard Roblox leaderboard. The client also reads
	-- the Coins value from here to show it on screen.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = profile.Coins
	coins.Parent = leaderstats
	leaderstats.Parent = player

	return profile
end

function PlayerData.Get(player)
	return profiles[player]
end

function PlayerData.Remove(player)
	profiles[player] = nil
end

local function syncCoins(player, profile)
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins")
	if coins then
		coins.Value = profile.Coins
	end
end

function PlayerData.AddCoins(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Coins += math.floor(amount)
	syncCoins(player, profile)
end

-- Takes coins only if the player can afford it. Returns true on success.
function PlayerData.TrySpend(player, amount)
	local profile = profiles[player]
	if not profile or profile.Coins < amount then
		return false
	end
	profile.Coins -= amount
	syncCoins(player, profile)
	return true
end

-- Puts an item in the player's inventory (and gives it an Id if needed).
function PlayerData.AddItem(player, item)
	local profile = profiles[player]
	if not profile then
		return
	end
	item.Id = item.Id or newId()
	table.insert(profile.Parts, item)
end

-- Finds an inventory item by Id. Returns the item and its position.
function PlayerData.FindItem(player, itemId)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	for index, item in ipairs(profile.Parts) do
		if item.Id == itemId then
			return item, index
		end
	end
	return nil
end

-- How many build pads this player has unlocked.
function PlayerData.UnlockedPads(profile)
	return math.min(Config.MaxPads, 1 + profile.Upgrades.Pads)
end

-- A plain copy of the profile that is safe to put in a DataStore.
function PlayerData.Serialize(profile)
	local function strip(item)
		return { Slot = item.Slot, Set = item.Set, Rarity = item.Rarity }
	end
	local data = { Coins = profile.Coins, Parts = {}, Robots = {}, Upgrades = {} }
	for _, item in ipairs(profile.Parts) do
		table.insert(data.Parts, strip(item))
	end
	for i = 1, Config.MaxPads do
		data.Robots[i] = {}
		for slot, item in pairs(profile.Robots[i]) do
			data.Robots[i][slot] = strip(item)
		end
	end
	for key, level in pairs(profile.Upgrades) do
		data.Upgrades[key] = level
	end
	return data
end

return PlayerData
