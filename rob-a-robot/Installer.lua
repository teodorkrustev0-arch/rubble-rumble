-- Rob-a-Robot installer. GENERATED FILE - edit the files in src/ instead.
-- Paste this whole file into the Roblox Studio Command Bar and press Enter.
local function container(serviceName, folderName)
	local parent = serviceName == 'StarterPlayerScripts'
		and game:GetService('StarterPlayer'):WaitForChild('StarterPlayerScripts')
		or game:GetService(serviceName)
	if not folderName then return parent end
	local folder = parent:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new('Folder')
		folder.Name = folderName
		folder.Parent = parent
	end
	return folder
end
local function install(className, serviceName, folderName, name, source)
	local parent = container(serviceName, folderName)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local script = Instance.new(className)
	script.Name = name
	script.Source = source
	script.Parent = parent
end
install('ModuleScript', 'ReplicatedStorage', 'Shared', 'Config', [=====[
--[[
	Config  (ModuleScript)
	Location: ReplicatedStorage > Shared > Config

	Every number you might want to tweak lives here, so you can balance the
	game without touching the logic. Both the server and the client read it.
	(The client only uses it to DISPLAY things. The server never asks the
	client what anything costs.)
]]

local Config = {}

-- Economy -------------------------------------------------------------------
Config.StartingCoins = 200 -- coins a brand new player starts with
Config.PassiveIncome = 1 -- coins per second everyone earns (stops soft-locks at 0 coins)
Config.SetBonus = 2 -- earnings multiplier when all 5 parts share one set

-- Players and bases ---------------------------------------------------------
Config.DefaultWalkSpeed = 16
Config.MaxPads = 3 -- build pads that physically exist in every base

-- Conveyor ------------------------------------------------------------------
Config.Conveyor = {
	SpawnInterval = 2, -- seconds between new parts
	Speed = 6, -- studs per second along the belt
	MaxItems = 40, -- safety cap on parts on the belt at once
	BuyDistance = 18, -- how close (studs) you must be to buy
}

-- Building ------------------------------------------------------------------
Config.Build = {
	PlaceDistance = 14, -- how close you must stand to a pad to place a part
}

-- Stealing ------------------------------------------------------------------
Config.Steal = {
	HoldTime = 3, -- seconds to hold the steal prompt
	MaxReach = 16, -- server-side distance check when a steal completes
	CarryWalkSpeed = 9, -- walk speed while carrying loot
	CarrySpeedPerUpgrade = 1.5, -- extra carry speed per "Turbo Boots" level
	TagDistance = 6, -- owner this close to the thief = caught
}

-- Base lock -----------------------------------------------------------------
Config.Lock = {
	Duration = 30, -- seconds the base stays locked
	DurationPerUpgrade = 10, -- extra seconds per "Stronger Lock" level
	Cooldown = 60, -- seconds after the lock ENDS before it can be used again
}

-- Guard bots (step 2) -------------------------------------------------------
Config.Guard = {
	Speed = 7, -- studs per second
	SightRadius = 14, -- guards walk toward intruders closer than this
	PushRadius = 6, -- intruders closer than this get thrown out
	PushCooldown = 5, -- seconds a guard needs to recharge after a push
}

-- Server events (step 3) ----------------------------------------------------
Config.Events = {
	Interval = 600, -- seconds between events (set to 30 while testing!)
	PowerSurge = { Duration = 120, Multiplier = 2 },
	JunkStorm = {
		Count = 12, -- parts that fall from the sky
		Area = 110, -- half-size of the square they land in (studs)
		Lifetime = 90, -- seconds before uncollected junk disappears
		MinRarity = 2, -- 2 = Rare or better (index into PartCatalog.Rarities)
	},
}

-- Saving (step 4) -----------------------------------------------------------
Config.Saving = {
	StoreName = "RobARobot_v1", -- change the name to wipe everyone's data
	AutosaveInterval = 120,
}

-- Shop ----------------------------------------------------------------------
-- Every shop item is an "upgrade level" stored in profile.Upgrades[Key].
-- Prices[1] is the price of level 1, Prices[2] of level 2, and so on.
-- The number of prices is the maximum level.
Config.Shop = {
	{
		Key = "Guards",
		Name = "Guard Bot",
		Desc = "Patrols your base and throws intruders out.",
		Prices = { 500, 2000, 6000 },
	},
	{
		Key = "Pads",
		Name = "Extra Build Pad",
		Desc = "Unlocks another build pad for one more robot.",
		Prices = { 1500, 8000 },
	},
	{
		Key = "CarrySpeed",
		Name = "Turbo Boots",
		Desc = "Walk faster while carrying stolen loot.",
		Prices = { 400, 1200, 3600 },
	},
	{
		Key = "LockTime",
		Name = "Stronger Lock",
		Desc = "Your base lock lasts 10 seconds longer.",
		Prices = { 600, 1800, 5000 },
	},
}

return Config
]=====])
install('ModuleScript', 'ReplicatedStorage', 'Shared', 'PartCatalog', [=====[
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
]=====])
install('Script', 'ServerScriptService', nil, 'Main', [=====[
--[[
	Main  (Script)
	Location: ServerScriptService > Main

	The only server Script in the game. It loads the ModuleScripts in the
	"Services" folder next to it, starts them, and tells them when players
	join and leave.

	GuardService, EventService and DataService are OPTIONAL: if the module is
	not in the Services folder yet, that feature is simply switched off. That
	is how you add them one step at a time.
]]

local Players = game:GetService("Players")

local Services = script.Parent:WaitForChild("Services")

local function load(name)
	return require(Services:WaitForChild(name))
end

local function loadOptional(name)
	local module = Services:FindFirstChild(name)
	if module then
		print("[Main] " .. name .. " is installed.")
		return require(module)
	end
	print("[Main] " .. name .. " not found - feature disabled.")
	return nil
end

-- Step 1: the core game ------------------------------------------------------
load("MapBuilder").Build() -- only builds a map if Workspace.Map is missing
local Net = load("Net")
local PlayerData = load("PlayerData")
local BaseService = load("BaseService")
local RobotService = load("RobotService")
local ConveyorService = load("ConveyorService")
local StealService = load("StealService")
local ShopService = load("ShopService")

-- Steps 2, 3 and 4: extras ----------------------------------------------------
local GuardService = loadOptional("GuardService")
local EventService = loadOptional("EventService")
local DataService = loadOptional("DataService")

BaseService.Start()
RobotService.Start()
ConveyorService.Start()
StealService.Start()
ShopService.Start()
if GuardService then
	ShopService.GuardService = GuardService
	GuardService.Start()
end
if EventService then
	EventService.Start()
end
if DataService then
	DataService.Start()
end

local function onPlayerAdded(player)
	-- Load the save (this can take a moment). Without DataService everyone
	-- simply starts fresh each time.
	local savedData, loadedOk = nil, true
	if DataService then
		savedData, loadedOk = DataService.Load(player)
	end
	if not player.Parent then
		return -- they left while we were loading
	end

	local profile = PlayerData.Create(player, savedData)
	profile.CanSave = loadedOk

	if not BaseService.Assign(player) then
		PlayerData.Remove(player)
		player:Kick("This server is full - please join another one.")
		return
	end

	RobotService.Refresh(player) -- draw saved robots + send the UI its data
	if GuardService then
		GuardService.Refresh(player)
	end

	if not loadedOk then
		Net.Notify(player, "Your data could not be loaded. Progress will NOT be saved this session - please rejoin.", "alarm")
	end
end

local function onPlayerRemoving(player)
	if not PlayerData.Get(player) then
		return
	end
	-- Order matters:
	-- 1. Give back anything they were carrying.
	StealService.PlayerRemoving(player)
	-- 2. Empty their base, so nobody can steal from a player who is gone.
	if GuardService then
		GuardService.Clear(player)
	end
	RobotService.Clear(player)
	BaseService.Release(player)
	-- 3. Save. Save() copies the data immediately and finishes in the
	--    background, so we can delete the profile right away.
	if DataService then
		task.spawn(DataService.Save, player)
	end
	PlayerData.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
-- Catch anyone who joined before this script finished starting.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- When the server shuts down, return all carried loot and save everybody.
if DataService then
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			StealService.PlayerRemoving(player)
		end
		DataService.SaveAll()
	end)
end
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'Net', [=====[
--[[
	Net  (ModuleScript)
	Location: ServerScriptService > Services > Net

	Creates every RemoteEvent the game uses (in ReplicatedStorage > Remotes)
	and gives the other services a simple way to message players.

	Client -> Server (requests; the server checks everything):
		PlacePart(itemId)            put an inventory part on the nearest pad
		RemovePart(padIndex, slot)   take a part off a pad
		ShopBuy(key)                 buy a shop upgrade
	Server -> Client (display only):
		State(snapshot)              the player's inventory / robots / upgrades
		Notify(text, kind)           a pop-up message
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name)
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

Net.PlacePart = remote("PlacePart")
Net.RemovePart = remote("RemovePart")
Net.ShopBuy = remote("ShopBuy")
Net.State = remote("State")
Net.NotifyEvent = remote("Notify")

folder.Parent = ReplicatedStorage

-- kind is "info", "good", "bad" or "alarm" (it only changes the colour).
function Net.Notify(player, text, kind)
	Net.NotifyEvent:FireClient(player, text, kind or "info")
end

function Net.NotifyAll(text, kind)
	Net.NotifyEvent:FireAllClients(text, kind or "info")
end

return Net
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'Util', [=====[
--[[
	Util  (ModuleScript)
	Location: ServerScriptService > Services > Util

	Small helpers shared by the server services.
]]

local CollectionService = game:GetService("CollectionService")

local Util = {}

-- Returns the player's HumanoidRootPart and Humanoid, but only if they are
-- alive. Returns nil otherwise.
function Util.GetRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

-- Server-side distance check. Never assume a player is close just because
-- their client says they pressed a button.
function Util.IsNear(player, position, maxDistance)
	local root = Util.GetRoot(player)
	return root ~= nil and (root.Position - position).Magnitude <= maxDistance
end

-- Creates a ProximityPrompt.
-- props.Tag + props.OwnerUserId let the client hide prompts that are not
-- meant for it ("OwnerOnlyPrompt" / "NotOwnerPrompt"). That is only cosmetic:
-- the server still checks who triggered the prompt.
function Util.MakePrompt(parent, props)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = props.ActionText or "Use"
	prompt.ObjectText = props.ObjectText or ""
	prompt.HoldDuration = props.HoldDuration or 0
	prompt.KeyboardKeyCode = props.Key or Enum.KeyCode.E
	prompt.GamepadKeyCode = props.GamepadKey or Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = props.MaxDistance or 9
	prompt.RequiresLineOfSight = false
	if props.OwnerUserId ~= nil then
		prompt:SetAttribute("OwnerUserId", props.OwnerUserId)
	end
	if props.Tag then
		CollectionService:AddTag(prompt, props.Tag)
	end
	prompt.Parent = parent
	return prompt
end

-- Connects a hold-to-use prompt and ENFORCES the hold time on the server.
-- An exploiter can make their client claim the prompt finished instantly, so
-- we remember when the hold began and ignore triggers that come too early.
function Util.ConnectHold(prompt, onTriggered, onHoldBegan)
	local beganAt = {}
	prompt.PromptButtonHoldBegan:Connect(function(player)
		beganAt[player] = os.clock()
		if onHoldBegan then
			onHoldBegan(player)
		end
	end)
	prompt.Triggered:Connect(function(player)
		local started = beganAt[player]
		beganAt[player] = nil
		if not started or os.clock() - started < prompt.HoldDuration - 0.3 then
			return
		end
		onTriggered(player)
	end)
end

-- Returns a function that answers "is this player allowed to send another
-- request yet?". Used to stop clients from spamming RemoteEvents.
function Util.RateLimiter(seconds)
	local last = {} -- [UserId] = time of the last accepted request
	return function(player)
		local now = os.clock()
		local previous = last[player.UserId]
		if previous and now - previous < seconds then
			return false
		end
		last[player.UserId] = now
		return true
	end
end

return Util
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'ItemVisuals', [=====[
--[[
	ItemVisuals  (ModuleScript)
	Location: ServerScriptService > Services > ItemVisuals

	Turns an item table into something you can see: a coloured Part with a
	floating name label. The same shapes are used on the conveyor, on build
	pads and for junk-storm drops, so everything looks consistent.

	Want real meshes later? Replace CreatePiece so it clones a model from
	ServerStorage instead of making a plain Part.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.PartCatalog)

local ItemVisuals = {}

-- Size of each slot's piece and where it sits on a robot.
-- Offset is measured from the centre of the TOP of the build pad.
ItemVisuals.Shapes = {
	Legs = { Size = Vector3.new(2.4, 2.5, 1.2), Offset = Vector3.new(0, 1.25, 0) },
	Body = { Size = Vector3.new(3, 3, 1.6), Offset = Vector3.new(0, 4, 0) },
	Arms = { Size = Vector3.new(5.2, 0.9, 0.9), Offset = Vector3.new(0, 4.7, 0) },
	Head = { Size = Vector3.new(1.8, 1.8, 1.8), Offset = Vector3.new(0, 6.4, 0) },
	Core = { Size = Vector3.new(1.1, 1.1, 1.1), Offset = Vector3.new(0, 4, -0.9), Ball = true },
}

-- Makes the Part for one item. It is anchored and has no collisions; the
-- caller positions and parents it.
function ItemVisuals.CreatePiece(item)
	local shape = ItemVisuals.Shapes[item.Slot]
	local rarity = Catalog.GetRarity(item)

	local piece = Instance.new("Part")
	piece.Name = item.Slot
	piece.Size = shape.Size
	piece.Color = rarity.Color
	piece.Anchored = true
	piece.CanCollide = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Material = Enum.Material.SmoothPlastic
	if shape.Ball then
		piece.Shape = Enum.PartType.Ball
		piece.Material = Enum.Material.Neon
	end
	-- Legendary and Mythic parts glow so they stand out on the belt.
	if Catalog.RarityIndex[item.Rarity] >= 4 then
		piece.Material = Enum.Material.Neon
	end
	return piece
end

-- Adds a floating two-line label above a part.
function ItemVisuals.AddLabel(part, title, titleColor, subtitle, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, height or 2.2, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false

	local top = Instance.new("TextLabel")
	top.Name = "Title"
	top.Size = UDim2.fromScale(1, 0.55)
	top.BackgroundTransparency = 1
	top.Font = Enum.Font.GothamBold
	top.TextScaled = true
	top.Text = title
	top.TextColor3 = titleColor or Color3.new(1, 1, 1)
	top.TextStrokeTransparency = 0
	top.Parent = gui

	local bottom = Instance.new("TextLabel")
	bottom.Name = "Subtitle"
	bottom.Size = UDim2.fromScale(1, 0.45)
	bottom.Position = UDim2.fromScale(0, 0.55)
	bottom.BackgroundTransparency = 1
	bottom.Font = Enum.Font.Gotham
	bottom.TextScaled = true
	bottom.Text = subtitle or ""
	bottom.TextColor3 = Color3.new(1, 1, 1)
	bottom.TextStrokeTransparency = 0
	bottom.Parent = gui

	gui.Parent = part
	return gui
end

return ItemVisuals
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'PlayerData', [=====[
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
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'MapBuilder', [=====[
--[[
	MapBuilder  (ModuleScript)
	Location: ServerScriptService > Services > MapBuilder

	Builds the whole Rob-a-Robot map out of Parts:
	  * a factory plaza with the conveyor, a part dispenser, a recycler,
	    light arches and a big title sign
	  * 8 walled, colour-coded bases with build pads, a lock button and a sign
	  * paths, trees, crates and an outer wall

	TWO WAYS TO USE IT

	1. Automatic: do nothing. When the game starts and Workspace has no model
	   called "Map", Main calls MapBuilder.Build().

	2. Permanent (recommended once you want to decorate): in Studio, WITHOUT
	   pressing Play, open View > Command Bar and run this one line:

	       require(game.ServerScriptService.Services.MapBuilder).Build()

	   The map is now a normal model in Workspace that you can edit by hand
	   and that gets saved with your place. To throw it away and build a
	   fresh one, run the same line with .Rebuild() instead of .Build().

	The parts the game scripts need (Belt, SpawnPoint, EndPoint, Zone, Door,
	Entrance, Spawn, LockButton, Sign, Pad1-3) keep their exact names.
	Everything inside a folder called "Decor" is decoration only - delete or
	change it freely.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapBuilder = {}

-- Layout numbers ---------------------------------------------------------------
local GROUND_TOP = 0.1 -- a hair above the default Baseplate so they never flicker
local BASE_SIZE = 40 -- bases are 40 x 40 studs
local WALL_HEIGHT = 14
local DOOR_WIDTH = 10
local BASE_SPACING = 50 -- distance between base centres along the belt
local BASE_DISTANCE = 70 -- distance from the belt to a base centre
local BELT_LENGTH = 180
local BELT_TOP = 3 -- height of the belt surface
local MAP_HALF_X = 136 -- outer wall position
local MAP_HALF_Z = 122

-- Colours ------------------------------------------------------------------------
local CONCRETE = Color3.fromRGB(105, 108, 115)
local DARK_STEEL = Color3.fromRGB(52, 56, 66)
local STEEL = Color3.fromRGB(120, 126, 138)
local BLACK = Color3.fromRGB(20, 20, 24)
local HAZARD = Color3.fromRGB(245, 200, 40)
local WOOD = Color3.fromRGB(150, 105, 60)
local CYAN = Color3.fromRGB(0, 200, 255)
local ORANGE = Color3.fromRGB(255, 130, 30)

local BASE_COLORS = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(52, 152, 219),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(241, 196, 15),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(230, 126, 34),
	Color3.fromRGB(26, 188, 156),
	Color3.fromRGB(236, 100, 170),
}

-- Part helpers --------------------------------------------------------------------

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or CONCRETE
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A decoration you can walk through (thin stripes, lamps, signs...).
local function newGhost(parent, name, size, cframe, color, material)
	local part = newPart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- An invisible part that is only used as a position marker / trigger volume.
local function newMarker(parent, name, size, cframe)
	local part = newPart(parent, name, size, cframe)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- An upright cylinder. cframe is its centre.
local function newCylinder(parent, name, diameter, height, cframe, color, material)
	local part = newPart(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.pi / 2), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function newFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Writes text on one face of a part.
local function addText(part, face, text, color)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = face
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 40
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = surfaceGui
	return label
end

local function addLight(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 24
	light.Brightness = brightness or 1.5
	light.Parent = part
	return light
end

-- Factory ---------------------------------------------------------------------------

local function buildMachine(decor, direction, name, glow)
	-- direction is -1 for the machine at the start of the belt, 1 for the end.
	local x = direction * (BELT_LENGTH / 2 + 8)
	local faceX = direction * (BELT_LENGTH / 2 - 0.1)
	-- The face that looks at the middle of the map.
	local innerFace = direction == -1 and Enum.NormalId.Right or Enum.NormalId.Left

	newPart(decor, name, Vector3.new(16, 16, 16), CFrame.new(x, 8, 0), DARK_STEEL, Enum.Material.Metal)
	newGhost(decor, name .. "Mouth", Vector3.new(0.4, 5.5, 7.4), CFrame.new(faceX, BELT_TOP + 2.75, 0), BLACK)
	newGhost(decor, name .. "Glow", Vector3.new(16.4, 1, 16.4), CFrame.new(x, 10.5, 0), glow, Enum.Material.Neon)

	local plate = newGhost(decor, name .. "Sign", Vector3.new(0.4, 3, 14), CFrame.new(faceX, 13.5, 0), BLACK)
	addText(plate, innerFace, direction == -1 and "PART DISPENSER" or "RECYCLER", glow)

	newCylinder(decor, name .. "Chimney", 4, 10, CFrame.new(x, 21, 0), STEEL, Enum.Material.Metal)
	local ring = newCylinder(decor, name .. "ChimneyGlow", 4.6, 0.8, CFrame.new(x, 25.5, 0), glow, Enum.Material.Neon)
	ring.CanCollide = false
	addLight(ring, glow, 30, 2)

	-- A pile of crates next to each machine.
	for _, side in ipairs({ 1, -1 }) do
		newPart(decor, "Crate", Vector3.new(4, 4, 4), CFrame.new(x, 2, side * 14) * CFrame.Angles(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks)
		newPart(decor, "Crate", Vector3.new(3, 3, 3), CFrame.new(x - direction * 4.5, 1.5, side * 15), WOOD, Enum.Material.WoodPlanks)
		newPart(decor, "Crate", Vector3.new(2.5, 2.5, 2.5), CFrame.new(x, 5.25, side * 14) * CFrame.Angles(0, -0.4, 0), WOOD, Enum.Material.WoodPlanks)
	end
end

local function buildFactory(map)
	local factory = Instance.new("Model")
	factory.Name = "Factory"

	local decor = newFolder(factory, "Decor")

	-- Concrete plaza under the conveyor.
	newPart(decor, "Plaza", Vector3.new(BELT_LENGTH + 56, 0.2, 44), CFrame.new(0, GROUND_TOP + 0.1, 0), CONCRETE, Enum.Material.Concrete)

	-- The conveyor. These three names are what ConveyorService looks for. ------
	local conveyor = Instance.new("Model")
	conveyor.Name = "Conveyor"
	conveyor.Parent = factory

	local belt = newPart(conveyor, "Belt", Vector3.new(BELT_LENGTH, 0.6, 6), CFrame.new(0, BELT_TOP - 0.3, 0), Color3.fromRGB(38, 38, 44), Enum.Material.Rubber)
	conveyor.PrimaryPart = belt
	-- Parts appear at SpawnPoint and slide in a straight line to EndPoint.
	newMarker(conveyor, "SpawnPoint", Vector3.new(1, 1, 1), CFrame.new(-BELT_LENGTH / 2 + 4, BELT_TOP + 1.6, 0))
	newMarker(conveyor, "EndPoint", Vector3.new(1, 1, 1), CFrame.new(BELT_LENGTH / 2 - 4, BELT_TOP + 1.6, 0))

	-- Belt decoration: a body underneath, side rails, slats and warning stripes.
	local beltDecor = newFolder(conveyor, "Decor")
	newPart(beltDecor, "BeltBody", Vector3.new(BELT_LENGTH, BELT_TOP - 0.6, 6.8), CFrame.new(0, (BELT_TOP - 0.6) / 2, 0), DARK_STEEL, Enum.Material.Metal)
	for _, side in ipairs({ 1, -1 }) do
		newPart(beltDecor, "Rail", Vector3.new(BELT_LENGTH, 0.8, 0.4), CFrame.new(0, BELT_TOP - 0.2, side * 3.2), STEEL, Enum.Material.Metal)
		newGhost(beltDecor, "HazardStripe", Vector3.new(BELT_LENGTH, 0.05, 1), CFrame.new(0, GROUND_TOP + 0.23, side * 5.5), HAZARD)
	end
	for x = -BELT_LENGTH / 2 + 3, BELT_LENGTH / 2 - 3, 6 do
		newGhost(beltDecor, "Slat", Vector3.new(0.4, 0.06, 5.8), CFrame.new(x, BELT_TOP + 0.03, 0), Color3.fromRGB(70, 70, 78))
	end

	-- A machine at each end of the belt.
	buildMachine(decor, -1, "Dispenser", CYAN)
	buildMachine(decor, 1, "Recycler", ORANGE)

	-- Four light arches over the belt.
	for _, x in ipairs({ -60, -20, 20, 60 }) do
		for _, side in ipairs({ 1, -1 }) do
			newPart(decor, "ArchPillar", Vector3.new(2, 20, 2), CFrame.new(x, 10, side * 14), DARK_STEEL, Enum.Material.Metal)
		end
		newPart(decor, "ArchBeam", Vector3.new(2, 2, 30), CFrame.new(x, 21, 0), DARK_STEEL, Enum.Material.Metal)
		local lamp = newGhost(decor, "ArchLamp", Vector3.new(3, 0.6, 3), CFrame.new(x, 19.7, 0), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)
		addLight(lamp, Color3.fromRGB(255, 240, 200), 45, 1.5)
	end

	-- Title sign resting on the two middle arches, readable from both sides.
	local title = newPart(decor, "TitleSign", Vector3.new(42, 7, 1), CFrame.new(0, 25.5, 0), BLACK)
	addText(title, Enum.NormalId.Front, "ROB-A-ROBOT", HAZARD)
	addText(title, Enum.NormalId.Back, "ROB-A-ROBOT", HAZARD)
	newGhost(decor, "TitleGlow", Vector3.new(43, 0.5, 1.4), CFrame.new(0, 29.25, 0), CYAN, Enum.Material.Neon)
	newGhost(decor, "TitleGlow", Vector3.new(43, 0.5, 1.4), CFrame.new(0, 21.9, 0), CYAN, Enum.Material.Neon)

	factory.Parent = map
end

-- Bases -------------------------------------------------------------------------------

-- Builds one base. baseCFrame is on the ground at the centre of the base and
-- its front (-Z, the "LookVector") points toward the conveyor.
local function buildBase(folder, index, baseCFrame)
	local color = BASE_COLORS[(index - 1) % #BASE_COLORS + 1]
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local floorColor = color:Lerp(Color3.new(1, 1, 1), 0.6)
	local half = BASE_SIZE / 2
	local floorTop = GROUND_TOP + 0.3

	local base = Instance.new("Model")
	base.Name = "Base" .. index

	local function at(x, y, z)
		return baseCFrame * CFrame.new(x, y, z)
	end

	local floor = newPart(base, "Floor", Vector3.new(BASE_SIZE, 0.3, BASE_SIZE), at(0, floorTop - 0.15, 0), floorColor)
	base.PrimaryPart = floor

	-- Walls: back, left, right, and two front pieces with a door gap between.
	local walls = newFolder(base, "Walls")
	local frontWidth = (BASE_SIZE - DOOR_WIDTH) / 2
	local frontX = DOOR_WIDTH / 2 + frontWidth / 2
	local wallShapes = {
		{ Vector3.new(BASE_SIZE, WALL_HEIGHT, 1), Vector3.new(0, 0, half - 0.5) },
		{ Vector3.new(1, WALL_HEIGHT, BASE_SIZE), Vector3.new(-half + 0.5, 0, 0) },
		{ Vector3.new(1, WALL_HEIGHT, BASE_SIZE), Vector3.new(half - 0.5, 0, 0) },
		{ Vector3.new(frontWidth, WALL_HEIGHT, 1), Vector3.new(-frontX, 0, -half + 0.5) },
		{ Vector3.new(frontWidth, WALL_HEIGHT, 1), Vector3.new(frontX, 0, -half + 0.5) },
	}

	local decor = newFolder(base, "Decor")
	for _, shape in ipairs(wallShapes) do
		local size, offset = shape[1], shape[2]
		newPart(walls, "Wall", size, at(offset.X, WALL_HEIGHT / 2, offset.Z), wallColor, Enum.Material.Concrete)
		-- Glowing strip along the top of every wall in the base's colour.
		newGhost(decor, "WallTrim", Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), at(offset.X, WALL_HEIGHT + 0.3, offset.Z), color, Enum.Material.Neon)
	end

	-- Corner towers with a lamp on top.
	for _, cornerX in ipairs({ -1, 1 }) do
		for _, cornerZ in ipairs({ -1, 1 }) do
			local x, z = cornerX * (half - 0.5), cornerZ * (half - 0.5)
			newPart(decor, "Tower", Vector3.new(3, WALL_HEIGHT + 3, 3), at(x, (WALL_HEIGHT + 3) / 2, z), DARK_STEEL, Enum.Material.Metal)
			local cap = newGhost(decor, "TowerLamp", Vector3.new(2.2, 1.2, 2.2), at(x, WALL_HEIGHT + 3.6, z), color, Enum.Material.Neon)
			addLight(cap, color, 28, 1.2)
		end
	end

	-- Door posts and a walkway from the door to the spawn pad.
	for _, side in ipairs({ -1, 1 }) do
		newPart(decor, "DoorPost", Vector3.new(1.4, WALL_HEIGHT, 1.6), at(side * (DOOR_WIDTH / 2 + 0.7), WALL_HEIGHT / 2, -half + 0.5), DARK_STEEL, Enum.Material.Metal)
	end
	newGhost(decor, "Walkway", Vector3.new(DOOR_WIDTH - 2, 0.05, half), at(0, floorTop + 0.03, -half / 2), floorColor:Lerp(Color3.new(0, 0, 0), 0.25))

	-- A workbench and some crates in the front-left corner.
	newPart(decor, "Workbench", Vector3.new(7, 2.6, 3), at(-14.5, floorTop + 1.3, -16.5), WOOD, Enum.Material.WoodPlanks)
	newPart(decor, "WorkbenchTop", Vector3.new(7.6, 0.4, 3.6), at(-14.5, floorTop + 2.8, -16.5), STEEL, Enum.Material.Metal)
	newPart(decor, "Crate", Vector3.new(3, 3, 3), at(-16.5, floorTop + 1.5, -11.5) * CFrame.Angles(0, 0.25, 0), WOOD, Enum.Material.WoodPlanks)

	-- Door: a red force field that shows while the base is locked. It never
	-- collides - BaseService throws intruders out instead, so the owner can
	-- always walk through their own door.
	local door = newPart(base, "Door", Vector3.new(DOOR_WIDTH, WALL_HEIGHT, 0.6), at(0, WALL_HEIGHT / 2, -half + 0.5), Color3.fromRGB(255, 40, 40), Enum.Material.ForceField)
	door.Transparency = 1
	door.CanCollide = false

	-- Zone: the invisible box that counts as "inside this base".
	-- Its bottom is at ground level (guards use that as their floor height).
	newMarker(base, "Zone", Vector3.new(BASE_SIZE - 2, 24, BASE_SIZE - 2), at(0, 12, 0))

	-- Entrance: where intruders get dropped when they are thrown out.
	newMarker(base, "Entrance", Vector3.new(2, 2, 2), at(0, 4, -half - 10))

	-- Spawn: where the owner appears. It must be a SpawnLocation.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Size = Vector3.new(6, 0.4, 6)
	spawnPad.CFrame = at(0, floorTop + 0.2, -4)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Color = color
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = base

	-- Build pads along the back wall. Robots face the door.
	local pads = newFolder(base, "Pads")
	for i = 1, 3 do
		local padX = (i - 2) * 11
		newPart(pads, "Pad" .. i, Vector3.new(6, 1, 6), at(padX, floorTop + 0.5, half - 8), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
		newGhost(decor, "PadRing", Vector3.new(7.4, 0.12, 7.4), at(padX, floorTop + 0.06, half - 8), color, Enum.Material.Neon)
	end

	-- Lock button: a glowing red button on a pedestal just inside the door.
	newPart(decor, "LockPedestal", Vector3.new(2, 2.6, 2), at(half - 5, floorTop + 1.3, -half + 5), DARK_STEEL, Enum.Material.Metal)
	newPart(base, "LockButton", Vector3.new(1.6, 0.6, 1.6), at(half - 5, floorTop + 2.9, -half + 5), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)

	-- Sign above the door that shows the owner's name.
	local sign = newPart(base, "Sign", Vector3.new(DOOR_WIDTH + 8, 3.4, 0.8), at(0, WALL_HEIGHT + 2.3, -half + 0.5), BLACK)
	addText(sign, Enum.NormalId.Front, "Empty Base", Color3.new(1, 1, 1))

	base.Parent = folder
end

-- Scenery ---------------------------------------------------------------------------------

local function buildTree(parent, position, scale)
	local trunkHeight = 8 * scale
	newCylinder(parent, "Trunk", 2.4 * scale, trunkHeight, CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)), Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	local leafColor = Color3.fromRGB(60, 140, 70)
	local big = newPart(parent, "Leaves", Vector3.one * 10 * scale, CFrame.new(position + Vector3.new(0, trunkHeight + 3 * scale, 0)), leafColor, Enum.Material.Grass)
	big.Shape = Enum.PartType.Ball
	local small = newPart(parent, "Leaves", Vector3.one * 7 * scale, CFrame.new(position + Vector3.new(2 * scale, trunkHeight + 7 * scale, 1 * scale)), leafColor:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Grass)
	small.Shape = Enum.PartType.Ball
end

local function buildScenery(map)
	local scenery = newFolder(map, "Decor")

	-- Grass. Its top is just above the default Baseplate, so it does not
	-- matter whether you keep or delete the Baseplate.
	newPart(scenery, "Ground", Vector3.new(MAP_HALF_X * 2 + 10, 1, MAP_HALF_Z * 2 + 10), CFrame.new(0, GROUND_TOP - 0.5, 0), Color3.fromRGB(86, 140, 84), Enum.Material.Grass)

	-- Outer wall so nobody wanders off the map.
	for _, side in ipairs({ 1, -1 }) do
		newPart(scenery, "OuterWall", Vector3.new(MAP_HALF_X * 2 + 2, 10, 2), CFrame.new(0, 5, side * MAP_HALF_Z), DARK_STEEL, Enum.Material.Concrete)
		newPart(scenery, "OuterWall", Vector3.new(2, 10, MAP_HALF_Z * 2 + 2), CFrame.new(side * MAP_HALF_X, 5, 0), DARK_STEEL, Enum.Material.Concrete)
	end

	-- A path from every base door to the plaza.
	for _, side in ipairs({ 1, -1 }) do
		for column = 1, 4 do
			local x = (column - 2.5) * BASE_SPACING
			newPart(scenery, "Path", Vector3.new(12, 0.2, 30), CFrame.new(x, GROUND_TOP + 0.1, side * 36), Color3.fromRGB(190, 180, 160), Enum.Material.Cobblestone)
		end
	end

	-- Trees behind the bases and along the short sides. A fixed seed means
	-- the "random" sizes are the same every time the map is built.
	local random = Random.new(7)
	for _, side in ipairs({ 1, -1 }) do
		for x = -120, 120, 30 do
			buildTree(scenery, Vector3.new(x + random:NextNumber(-4, 4), GROUND_TOP, side * 107), random:NextNumber(0.8, 1.25))
		end
		for _, z in ipairs({ -60, 60 }) do
			buildTree(scenery, Vector3.new(side * 124, GROUND_TOP, z + random:NextNumber(-4, 4)), random:NextNumber(0.8, 1.25))
		end
	end
end

-- A warm early-evening look so the neon and the lamps show up.
local function applyLighting()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 115, 135)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Haze = 1.2
		atmosphere.Color = Color3.fromRGB(255, 214, 170)
		atmosphere.Decay = Color3.fromRGB(120, 90, 130)
		atmosphere.Parent = Lighting
	end
end

-- Public functions --------------------------------------------------------------------------

-- Builds the map, unless Workspace already has a "Map".
function MapBuilder.Build()
	if Workspace:FindFirstChild("Map") then
		return -- there is already a map (yours, or one built earlier)
	end

	local map = Instance.new("Model")
	map.Name = "Map"

	buildScenery(map)
	buildFactory(map)

	-- 4 bases on each side of the belt. Bases on the far side are turned
	-- around so that every door faces the conveyor.
	local bases = newFolder(map, "Bases")
	local index = 0
	for _, side in ipairs({ 1, -1 }) do
		for column = 1, 4 do
			index += 1
			local x = (column - 2.5) * BASE_SPACING
			local cframe = CFrame.new(x, 0, side * BASE_DISTANCE)
			if side == -1 then
				cframe *= CFrame.Angles(0, math.pi, 0)
			end
			buildBase(bases, index, cframe)
		end
	end

	map.Parent = Workspace
	applyLighting()
end

-- Deletes the current map and builds a fresh one. Handy from the Command Bar
-- after you change numbers in this file. Anything you edited by hand in the
-- old map is lost!
function MapBuilder.Rebuild()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	MapBuilder.Build()
end

return MapBuilder
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'BaseService', [=====[
--[[
	BaseService  (ModuleScript)
	Location: ServerScriptService > Services > BaseService

	Gives every player a base, knows who is standing inside which base, and
	runs the lock button.

	A base "record" (one per Base model in Workspace > Map > Bases):
		record.Model, record.Zone, record.Door, record.Entrance, record.Spawn
		record.Pads        = { Pad1, Pad2, Pad3 }
		record.Owner       = Player or nil
		record.LockedUntil = server time when the lock ends
		record.LockReadyAt = server time when the lock can be used again
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)

local BaseService = {}

local records = {} -- array of base records
local byPlayer = {} -- [Player] = record

local function setSign(record, text)
	local sign = record.Model:FindFirstChild("Sign")
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text
	end
end

local function setOwnerAttributes(record, player)
	local userId = player and player.UserId or 0
	record.Model:SetAttribute("OwnerUserId", userId)
	record.Model:SetAttribute("OwnerName", player and player.DisplayName or "")
	record.Model:SetAttribute("LockedUntil", record.LockedUntil)
	record.Model:SetAttribute("LockReadyAt", record.LockReadyAt)
	record.LockPrompt:SetAttribute("OwnerUserId", userId)
end

local function showDoor(record, visible)
	record.DoorShown = visible
	record.Door.Transparency = visible and 0.2 or 1
end

function BaseService.IsLocked(record)
	return Workspace:GetServerTimeNow() < record.LockedUntil
end

-- Is this world position inside the base's Zone box? Works for rotated bases.
function BaseService.IsInside(record, position)
	local point = record.Zone.CFrame:PointToObjectSpace(position)
	local half = record.Zone.Size / 2
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

function BaseService.GetBase(player)
	return byPlayer[player]
end

-- Everyone inside the base who is not the owner: { {Player=, Root=}, ... }
function BaseService.GetIntruders(record)
	local intruders = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= record.Owner then
			local root = Util.GetRoot(player)
			if root and BaseService.IsInside(record, root.Position) then
				table.insert(intruders, { Player = player, Root = root })
			end
		end
	end
	return intruders
end

-- Teleports a player to just outside the base's door.
function BaseService.Eject(record, player)
	local character = player.Character
	if character then
		character:PivotTo(record.Entrance.CFrame)
	end
end

local function tryLock(record, player)
	-- Only the owner can lock, and they must really be next to the button.
	if record.Owner ~= player then
		return
	end
	if not Util.IsNear(player, record.LockButton.Position, 14) then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end

	local now = Workspace:GetServerTimeNow()
	if now < record.LockedUntil then
		Net.Notify(player, "Your base is already locked.", "info")
		return
	end
	if now < record.LockReadyAt then
		Net.Notify(player, ("Lock recharging: %d s"):format(math.ceil(record.LockReadyAt - now)), "bad")
		return
	end

	local duration = Config.Lock.Duration + profile.Upgrades.LockTime * Config.Lock.DurationPerUpgrade
	record.LockedUntil = now + duration
	record.LockReadyAt = record.LockedUntil + Config.Lock.Cooldown
	record.Model:SetAttribute("LockedUntil", record.LockedUntil)
	record.Model:SetAttribute("LockReadyAt", record.LockReadyAt)
	Net.Notify(player, ("Base locked for %d seconds!"):format(duration), "good")
end

-- Gives the player the first free base. Returns nil if all are taken.
function BaseService.Assign(player)
	for _, record in ipairs(records) do
		if not record.Owner then
			record.Owner = player
			byPlayer[player] = record
			setOwnerAttributes(record, player)
			setSign(record, player.DisplayName .. "'s Base")

			-- Respawn in your own base from now on...
			player.RespawnLocation = record.Spawn
			-- ...and if the character already spawned somewhere else, move it.
			if player.Character then
				player.Character:PivotTo(record.Spawn.CFrame + Vector3.new(0, 4, 0))
			end
			return record
		end
	end
	return nil
end

-- Frees the base when its owner leaves.
function BaseService.Release(player)
	local record = byPlayer[player]
	if not record then
		return
	end
	byPlayer[player] = nil
	record.Owner = nil
	record.LockedUntil = 0
	record.LockReadyAt = 0
	setOwnerAttributes(record, nil)
	setSign(record, "Empty Base")
	showDoor(record, false)
end

function BaseService.Start()
	local map = Workspace:WaitForChild("Map")
	local models = map:WaitForChild("Bases"):GetChildren()
	-- Sort by the number in the name so Base2 comes before Base10.
	table.sort(models, function(a, b)
		return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0)
	end)

	for index, model in ipairs(models) do
		local record = {
			Index = index,
			Model = model,
			Zone = model:WaitForChild("Zone"),
			Door = model:WaitForChild("Door"),
			Entrance = model:WaitForChild("Entrance"),
			Spawn = model:WaitForChild("Spawn"),
			LockButton = model:WaitForChild("LockButton"),
			Pads = {},
			Owner = nil,
			LockedUntil = 0,
			LockReadyAt = 0,
			DoorShown = false,
		}
		local pads = model:WaitForChild("Pads")
		for i = 1, Config.MaxPads do
			record.Pads[i] = pads:WaitForChild("Pad" .. i)
		end

		record.LockPrompt = Util.MakePrompt(record.LockButton, {
			ActionText = "Lock Base",
			ObjectText = "Security",
			Tag = "OwnerOnlyPrompt",
			OwnerUserId = 0,
		})
		record.LockPrompt.Triggered:Connect(function(player)
			tryLock(record, player)
		end)

		setOwnerAttributes(record, nil)
		showDoor(record, false)
		records[index] = record
	end

	-- A few times per second: update door visuals and throw intruders out of
	-- locked bases. This is what actually "blocks entry" - it runs on the
	-- server, so a cheater cannot walk through the door.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, record in ipairs(records) do
				local locked = record.Owner ~= nil and BaseService.IsLocked(record)
				if locked ~= record.DoorShown then
					showDoor(record, locked)
				end
				if locked then
					for _, intruder in ipairs(BaseService.GetIntruders(record)) do
						BaseService.Eject(record, intruder.Player)
						Net.Notify(intruder.Player, "That base is locked!", "bad")
					end
				end
			end
		end
	end)
end

return BaseService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'RobotService', [=====[
--[[
	RobotService  (ModuleScript)
	Location: ServerScriptService > Services > RobotService

	Building and earning:
	  * places inventory parts on build pads (and takes them off again)
	  * draws the robots that stand on the pads
	  * pays every player their coins once per second
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local BaseService = require(script.Parent.BaseService)
local ItemVisuals = require(script.Parent.ItemVisuals)

local RobotService = {}

-- StealService fills these in when it starts. (RobotService cannot require
-- StealService directly because StealService already requires RobotService.)
RobotService.OnStealTriggered = nil -- function(thief, owner, padIndex, slotOrNil)
RobotService.OnStealBegan = nil -- function(thief, owner)

-- Global earnings multiplier. EventService sets it to 2 during a Power Surge.
local multiplier = 1

local PAD_ON = Color3.fromRGB(90, 200, 255)
local PAD_OFF = Color3.fromRGB(60, 60, 60)

function RobotService.SetMultiplier(value)
	multiplier = value
end

-- Sends the player a fresh copy of their inventory/robots/upgrades so their
-- UI can redraw. The client can look at this data but changing it does
-- nothing - the real data stays on the server.
function RobotService.PushState(player)
	local profile = PlayerData.Get(player)
	if profile then
		Net.State:FireClient(player, {
			Parts = profile.Parts,
			Robots = profile.Robots,
			Upgrades = profile.Upgrades,
		})
	end
end

-- Rebuilds the robot standing on one pad.
local function drawPad(record, owner, profile, padIndex)
	local pad = record.Pads[padIndex]
	local old = pad:FindFirstChild("Robot")
	if old then
		old:Destroy()
	end

	local unlocked = padIndex <= PlayerData.UnlockedPads(profile)
	pad.Color = unlocked and PAD_ON or PAD_OFF
	if not unlocked then
		return
	end

	local robot = profile.Robots[padIndex]
	local model = Instance.new("Model")
	model.Name = "Robot"
	local padTop = pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0)

	local missing = {}
	for _, slot in ipairs(Catalog.Slots) do
		local item = robot[slot]
		if item then
			local piece = ItemVisuals.CreatePiece(item)
			piece.CFrame = padTop * CFrame.new(ItemVisuals.Shapes[slot].Offset)
			piece.Parent = model

			-- Hold E on a part to steal just that part.
			local prompt = Util.MakePrompt(piece, {
				ActionText = "Steal Part",
				ObjectText = Catalog.DisplayName(item),
				HoldDuration = Config.Steal.HoldTime,
				MaxDistance = 8,
				Tag = "NotOwnerPrompt",
				OwnerUserId = owner.UserId,
			})
			Util.ConnectHold(prompt, function(thief)
				if RobotService.OnStealTriggered then
					RobotService.OnStealTriggered(thief, owner, padIndex, slot)
				end
			end, function(thief)
				if RobotService.OnStealBegan then
					RobotService.OnStealBegan(thief, owner)
				end
			end)
		else
			table.insert(missing, slot)
		end
	end

	-- An invisible part above the robot holds its status label, and the
	-- "steal the whole robot" prompt when the robot is complete.
	local income, complete, setBonus = Catalog.RobotIncome(robot)
	local anchor = Instance.new("Part")
	anchor.Name = "Status"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CFrame = padTop * CFrame.new(0, 8, 0)
	anchor.Parent = model

	if complete then
		local title = ("+%d coins/s"):format(income)
		local subtitle = setBonus and ("FULL SET BONUS x%d!"):format(Config.SetBonus) or "Online"
		ItemVisuals.AddLabel(anchor, title, Color3.fromRGB(120, 255, 120), subtitle, 1)

		-- Hold F to steal the whole robot. It uses a different key from the
		-- part prompts so the two never fight over the E key.
		local prompt = Util.MakePrompt(anchor, {
			ActionText = "Steal Whole Robot",
			ObjectText = owner.DisplayName .. "'s robot",
			HoldDuration = Config.Steal.HoldTime,
			Key = Enum.KeyCode.F,
			GamepadKey = Enum.KeyCode.ButtonY,
			MaxDistance = 12,
			Tag = "NotOwnerPrompt",
			OwnerUserId = owner.UserId,
		})
		Util.ConnectHold(prompt, function(thief)
			if RobotService.OnStealTriggered then
				RobotService.OnStealTriggered(thief, owner, padIndex, nil)
			end
		end, function(thief)
			if RobotService.OnStealBegan then
				RobotService.OnStealBegan(thief, owner)
			end
		end)
	elseif #missing < #Catalog.Slots then
		ItemVisuals.AddLabel(anchor, "OFFLINE", Color3.fromRGB(255, 120, 120), "Missing: " .. table.concat(missing, ", "), 1)
	else
		ItemVisuals.AddLabel(anchor, "Build Pad " .. padIndex, Color3.new(1, 1, 1), "Place 5 parts here", -4)
	end

	model.Parent = pad
end

-- Call this after ANY change to a player's parts, robots or upgrades.
-- It redraws their pads and updates their UI.
function RobotService.Refresh(player)
	local profile = PlayerData.Get(player)
	local record = BaseService.GetBase(player)
	if not profile or not record then
		return
	end
	for padIndex = 1, Config.MaxPads do
		drawPad(record, player, profile, padIndex)
	end
	RobotService.PushState(player)
end

-- Removes the robots from a base when its owner leaves.
function RobotService.Clear(player)
	local record = BaseService.GetBase(player)
	if not record then
		return
	end
	for _, pad in ipairs(record.Pads) do
		local old = pad:FindFirstChild("Robot")
		if old then
			old:Destroy()
		end
		pad.Color = PAD_OFF
	end
end

-- Client request: put inventory item <itemId> on the pad I am standing next to.
local function placePart(player, itemId)
	if type(itemId) ~= "string" then
		return
	end
	local profile = PlayerData.Get(player)
	local record = BaseService.GetBase(player)
	local root = Util.GetRoot(player)
	if not profile or not record or not root then
		return
	end

	-- The server decides which pad: the closest unlocked one in YOUR base.
	local bestPad, bestDistance = nil, Config.Build.PlaceDistance
	for padIndex = 1, PlayerData.UnlockedPads(profile) do
		local distance = (record.Pads[padIndex].Position - root.Position).Magnitude
		if distance <= bestDistance then
			bestPad, bestDistance = padIndex, distance
		end
	end
	if not bestPad then
		Net.Notify(player, "Stand next to one of your build pads first.", "bad")
		return
	end

	-- The item must really be in this player's inventory.
	local item, index = PlayerData.FindItem(player, itemId)
	if not item then
		return
	end

	local robot = profile.Robots[bestPad]
	if robot[item.Slot] then
		Net.Notify(player, ("That robot already has a %s. Remove it first."):format(item.Slot), "bad")
		return
	end

	table.remove(profile.Parts, index)
	robot[item.Slot] = item
	RobotService.Refresh(player)

	local income, complete, setBonus = Catalog.RobotIncome(robot)
	if complete then
		local text = ("Robot online! +%d coins/s"):format(income)
		if setBonus then
			text ..= " (full set bonus!)"
		end
		Net.Notify(player, text, "good")
	end
end

-- Client request: take the part in <slot> off pad <padIndex>.
local function removePart(player, padIndex, slot)
	if type(padIndex) ~= "number" or type(slot) ~= "string" or not Catalog.SlotIsValid[slot] then
		return
	end
	local profile = PlayerData.Get(player)
	local record = BaseService.GetBase(player)
	local root = Util.GetRoot(player)
	if not profile or not record or not root then
		return
	end
	if padIndex % 1 ~= 0 or padIndex < 1 or padIndex > PlayerData.UnlockedPads(profile) then
		return
	end
	-- You must be at home, so you cannot yank parts away from a thief while
	-- you are on the other side of the map.
	if not BaseService.IsInside(record, root.Position) then
		Net.Notify(player, "Go to your base to take robots apart.", "bad")
		return
	end

	local robot = profile.Robots[padIndex]
	local item = robot[slot]
	if not item then
		return
	end
	robot[slot] = nil
	PlayerData.AddItem(player, item)
	RobotService.Refresh(player)
end

function RobotService.Start()
	local canSend = Util.RateLimiter(0.15)

	Net.PlacePart.OnServerEvent:Connect(function(player, itemId)
		if canSend(player) then
			placePart(player, itemId)
		end
	end)
	Net.RemovePart.OnServerEvent:Connect(function(player, padIndex, slot)
		if canSend(player) then
			removePart(player, padIndex, slot)
		end
	end)

	-- Payday, once per second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = PlayerData.Get(player)
				if profile then
					local income = 0
					for padIndex = 1, PlayerData.UnlockedPads(profile) do
						income += Catalog.RobotIncome(profile.Robots[padIndex])
					end
					income = income * multiplier + Config.PassiveIncome
					PlayerData.AddCoins(player, income)
					-- Shown next to the coin counter on the client.
					player:SetAttribute("Income", income)
				end
			end
		end
	end)
end

return RobotService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'ConveyorService', [=====[
--[[
	ConveyorService  (ModuleScript)
	Location: ServerScriptService > Services > ConveyorService

	Spawns random robot parts at the start of the belt, slides them to the
	end, and sells them to players who press E on them (or click them).
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local RobotService = require(script.Parent.RobotService)
local ItemVisuals = require(script.Parent.ItemVisuals)

local ConveyorService = {}

local itemFolder
local forSale = {} -- [Part on the belt] = item table

local function buy(player, piece)
	-- Somebody else may have bought it a moment ago.
	local item = forSale[piece]
	if not item then
		return
	end
	if not PlayerData.Get(player) then
		return
	end
	-- Server-side distance check: exploiters can fire prompts from anywhere.
	if not Util.IsNear(player, piece.Position, Config.Conveyor.BuyDistance) then
		return
	end

	local price = Catalog.GetRarity(item).Price
	if not PlayerData.TrySpend(player, price) then
		Net.Notify(player, ("Not enough coins (need %d)."):format(price), "bad")
		return
	end

	-- Nothing above this line waits, so two players can never buy the same
	-- part: the first one to get here removes it from forSale.
	forSale[piece] = nil
	piece:Destroy()

	PlayerData.AddItem(player, item)
	RobotService.PushState(player)
	Net.Notify(player, ("Bought %s (%s)"):format(Catalog.DisplayName(item), item.Rarity), "good")
end

local function spawnItem(startCFrame, endCFrame)
	local item = Catalog.RollItem()
	local rarity = Catalog.GetRarity(item)

	local piece = ItemVisuals.CreatePiece(item)
	piece.CFrame = startCFrame
	ItemVisuals.AddLabel(piece, Catalog.DisplayName(item), rarity.Color, ("%s - %d coins"):format(rarity.Name, rarity.Price))

	-- Press E...
	local prompt = Util.MakePrompt(piece, {
		ActionText = ("Buy (%d)"):format(rarity.Price),
		ObjectText = Catalog.DisplayName(item),
		MaxDistance = 10,
	})
	prompt.Triggered:Connect(function(player)
		buy(player, piece)
	end)

	-- ...or click it.
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.Conveyor.BuyDistance
	click.Parent = piece
	click.MouseClick:Connect(function(player)
		buy(player, piece)
	end)

	forSale[piece] = item
	piece.Destroying:Connect(function()
		forSale[piece] = nil
	end)
	piece.Parent = itemFolder

	-- Slide along the belt, then fall off the end (get destroyed).
	local travelTime = (endCFrame.Position - startCFrame.Position).Magnitude / Config.Conveyor.Speed
	local tween = TweenService:Create(piece, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), { CFrame = endCFrame })
	tween.Completed:Connect(function()
		piece:Destroy()
	end)
	tween:Play()
end

function ConveyorService.Start()
	local conveyor = Workspace:WaitForChild("Map"):WaitForChild("Factory"):WaitForChild("Conveyor")
	local spawnPoint = conveyor:WaitForChild("SpawnPoint")
	local endPoint = conveyor:WaitForChild("EndPoint")

	itemFolder = Instance.new("Folder")
	itemFolder.Name = "ConveyorItems"
	itemFolder.Parent = Workspace

	-- Items keep the SpawnPoint's rotation the whole way along.
	local startCFrame = spawnPoint.CFrame
	local endCFrame = startCFrame.Rotation + endPoint.Position

	task.spawn(function()
		while true do
			if #itemFolder:GetChildren() < Config.Conveyor.MaxItems then
				spawnItem(startCFrame, endCFrame)
			end
			task.wait(Config.Conveyor.SpawnInterval)
		end
	end)
end

return ConveyorService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'StealService', [=====[
--[[
	StealService  (ModuleScript)
	Location: ServerScriptService > Services > StealService

	Everything about stealing:
	  1. A thief holds the prompt on a robot (RobotService makes the prompts).
	  2. The part(s) leave the owner's robot and the thief "carries" them:
	     a crate appears over their head and they walk slower.
	  3. The steal ends in one of three ways:
	       DELIVERED - the thief reaches their own base -> parts go into
	                   their inventory.
	       CAUGHT    - the owner touches the thief -> parts go back.
	       DROPPED   - the thief dies, leaves or speed-hacks -> parts go back.

	While being carried, the parts are in neither player's profile. They only
	exist in the `carrying` table below, on the server.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local BaseService = require(script.Parent.BaseService)
local RobotService = require(script.Parent.RobotService)

local StealService = {}

local TICK = 0.15

-- [thief Player] = { OwnerId, OwnerName, PadIndex, Items = {item,...}, Crate, LastPosition, Strikes }
local carrying = {}
local lastWarning = {} -- [thief] = os.clock() of the last "someone is stealing" alert

function StealService.IsCarrying(player)
	return carrying[player] ~= nil
end

local function describe(items)
	if #items == 1 then
		return Catalog.DisplayName(items[1])
	end
	return "a whole robot"
end

-- The crate that floats above the thief so everyone can see who has loot.
local function attachCrate(root, items)
	local best = items[1]
	for _, item in ipairs(items) do
		if Catalog.RarityIndex[item.Rarity] > Catalog.RarityIndex[best.Rarity] then
			best = item
		end
	end

	local crate = Instance.new("Part")
	crate.Name = "StolenLoot"
	crate.Size = #items > 1 and Vector3.new(3, 3, 3) or Vector3.new(1.8, 1.8, 1.8)
	crate.Color = Catalog.GetRarity(best).Color
	crate.Material = Enum.Material.Neon
	crate.CanCollide = false
	crate.CanQuery = false
	crate.Massless = true
	crate.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = crate
	weld.Parent = crate

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffset = Vector3.new(0, 2.5, 0)
	gui.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "THIEF!"
	label.TextColor3 = Color3.fromRGB(255, 80, 80)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = crate

	crate.Parent = root.Parent
	return crate
end

-- Ends a steal. outcome is "delivered" or "returned".
local function finish(thief, outcome, thiefMessage, ownerMessage)
	local carry = carrying[thief]
	if not carry then
		return
	end
	carrying[thief] = nil

	if carry.Crate then
		carry.Crate:Destroy()
	end
	local _, humanoid = Util.GetRoot(thief)
	if humanoid then
		humanoid.WalkSpeed = Config.DefaultWalkSpeed
	end

	local owner = Players:GetPlayerByUserId(carry.OwnerId)
	local ownerProfile = owner and PlayerData.Get(owner)

	-- If the owner has left the game there is nobody to give the parts back
	-- to, so the thief keeps them.
	if outcome == "returned" and not ownerProfile then
		outcome = "delivered"
		thiefMessage = "The owner left - the loot is yours."
	end

	if outcome == "delivered" then
		if PlayerData.Get(thief) then
			for _, item in ipairs(carry.Items) do
				PlayerData.AddItem(thief, item)
			end
			RobotService.PushState(thief)
		end
	else
		-- Put each part back where it came from. If the owner already filled
		-- that slot with something else, it goes to their inventory instead.
		local robot = ownerProfile.Robots[carry.PadIndex]
		for _, item in ipairs(carry.Items) do
			if robot[item.Slot] == nil then
				robot[item.Slot] = item
			else
				PlayerData.AddItem(owner, item)
			end
		end
		RobotService.Refresh(owner)
	end

	if thiefMessage and thief.Parent then
		Net.Notify(thief, thiefMessage, outcome == "delivered" and "good" or "bad")
	end
	if ownerMessage and owner then
		Net.Notify(owner, ownerMessage, outcome == "delivered" and "bad" or "good")
	end
end

-- Called when a thief STARTS holding a steal prompt: warn the owner early so
-- they have a chance to react.
local function onStealBegan(thief, owner)
	if thief == owner or not owner.Parent then
		return
	end
	local now = os.clock()
	if lastWarning[thief] and now - lastWarning[thief] < 4 then
		return
	end
	lastWarning[thief] = now
	Net.Notify(owner, ("ALERT! %s is trying to steal from your base!"):format(thief.DisplayName), "alarm")
end

-- Called when a steal prompt finishes. slot = nil means "the whole robot".
-- Every rule is checked here on the server.
local function onStealTriggered(thief, owner, padIndex, slot)
	if thief == owner or carrying[thief] then
		return
	end
	local thiefProfile = PlayerData.Get(thief)
	local ownerProfile = PlayerData.Get(owner)
	local thiefBase = BaseService.GetBase(thief)
	local ownerBase = BaseService.GetBase(owner)
	local root, humanoid = Util.GetRoot(thief)
	if not (thiefProfile and ownerProfile and thiefBase and ownerBase and root) then
		return
	end
	if BaseService.IsLocked(ownerBase) then
		return
	end
	-- The thief must really be standing at the pad, inside the base.
	if (root.Position - ownerBase.Pads[padIndex].Position).Magnitude > Config.Steal.MaxReach then
		return
	end

	local robot = ownerProfile.Robots[padIndex]
	local items = {}
	if slot then
		if not robot[slot] then
			return -- already gone
		end
		table.insert(items, robot[slot])
		robot[slot] = nil
	else
		local _, complete = Catalog.RobotIncome(robot)
		if not complete then
			return
		end
		for _, robotSlot in ipairs(Catalog.Slots) do
			table.insert(items, robot[robotSlot])
			robot[robotSlot] = nil
		end
	end

	local carrySpeed = Config.Steal.CarryWalkSpeed + thiefProfile.Upgrades.CarrySpeed * Config.Steal.CarrySpeedPerUpgrade
	humanoid.WalkSpeed = math.min(carrySpeed, Config.DefaultWalkSpeed)

	carrying[thief] = {
		OwnerId = owner.UserId,
		PadIndex = padIndex,
		Items = items,
		Crate = attachCrate(root, items),
		LastPosition = root.Position,
		Strikes = 0,
	}

	-- The robot on the pad now has a hole in it and stops earning.
	RobotService.Refresh(owner)

	local what = describe(items)
	Net.Notify(thief, ("You grabbed %s! Carry it back to your base."):format(what), "good")
	Net.Notify(owner, ("%s stole %s! Touch them to get it back!"):format(thief.DisplayName, what), "alarm")
end

-- Checks one carrying thief. Runs several times per second.
local function update(thief, carry)
	local root, humanoid = Util.GetRoot(thief)
	if not root then
		finish(thief, "returned", "You dropped the loot!", ("%s dropped your parts - they are back in your base."):format(thief.DisplayName))
		return
	end

	-- Caught by the owner?
	local owner = Players:GetPlayerByUserId(carry.OwnerId)
	local ownerRoot = owner and Util.GetRoot(owner)
	if ownerRoot and (ownerRoot.Position - root.Position).Magnitude <= Config.Steal.TagDistance then
		finish(thief, "returned", ("%s caught you!"):format(owner.DisplayName), ("You caught %s! Your parts are back."):format(thief.DisplayName))
		return
	end

	-- Made it home?
	local home = BaseService.GetBase(thief)
	if home and BaseService.IsInside(home, root.Position) then
		local what = describe(carry.Items)
		finish(thief, "delivered", ("Delivered! %s is in your inventory."):format(what), ("%s got away with %s."):format(thief.DisplayName, what))
		return
	end

	-- Simple anti-cheat. Walk speed is set by the server, but an exploiter can
	-- change it on their own computer. So we measure how fast the thief is
	-- really moving; several far-too-fast checks in a row = loot returned.
	-- (One fast check alone is fine: guards and locks teleport people.)
	local moved = (root.Position - carry.LastPosition) * Vector3.new(1, 0, 1)
	carry.LastPosition = root.Position
	local speed = moved.Magnitude / TICK
	if speed > humanoid.WalkSpeed * 1.6 + 6 then
		carry.Strikes += 1
		if carry.Strikes >= 5 then
			finish(thief, "returned", "You moved too fast and dropped the loot!", "Your parts were returned.")
		end
	else
		carry.Strikes = 0
	end
end

-- Called by Main when a player leaves: whatever they carry goes back.
function StealService.PlayerRemoving(player)
	finish(player, "returned")
	lastWarning[player] = nil
end

function StealService.Start()
	RobotService.OnStealTriggered = onStealTriggered
	RobotService.OnStealBegan = onStealBegan

	task.spawn(function()
		while true do
			task.wait(TICK)
			-- Copy the list first because update() can remove entries.
			local thieves = {}
			for thief in pairs(carrying) do
				table.insert(thieves, thief)
			end
			for _, thief in ipairs(thieves) do
				local carry = carrying[thief]
				if carry then
					update(thief, carry)
				end
			end
		end
	end)
end

return StealService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'ShopService', [=====[
--[[
	ShopService  (ModuleScript)
	Location: ServerScriptService > Services > ShopService

	Sells the upgrades listed in Config.Shop. The client only sends the KEY of
	what it wants ("Guards", "Pads", ...). The price comes from Config on the
	server, so a cheater cannot buy things for 0 coins.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local RobotService = require(script.Parent.RobotService)

local ShopService = {}

-- Main sets this once GuardService exists (step 2). Until then the Guard Bot
-- item politely refuses to be bought.
ShopService.GuardService = nil

local function buy(player, key)
	if type(key) ~= "string" then
		return
	end
	local profile = PlayerData.Get(player)
	if not profile then
		return
	end

	local def
	for _, candidate in ipairs(Config.Shop) do
		if candidate.Key == key then
			def = candidate
			break
		end
	end
	if not def then
		return
	end

	if key == "Guards" and not ShopService.GuardService then
		Net.Notify(player, "Guard bots are not installed yet (step 2 of the guide).", "bad")
		return
	end

	local level = profile.Upgrades[key]
	local price = def.Prices[level + 1]
	if not price then
		Net.Notify(player, def.Name .. " is already at max level.", "info")
		return
	end
	if not PlayerData.TrySpend(player, price) then
		Net.Notify(player, ("Not enough coins (need %d)."):format(price), "bad")
		return
	end

	profile.Upgrades[key] = level + 1
	Net.Notify(player, ("Bought %s (level %d)"):format(def.Name, level + 1), "good")

	-- Redraw pads (a new pad may have unlocked) and update the UI.
	RobotService.Refresh(player)
	if ShopService.GuardService then
		ShopService.GuardService.Refresh(player)
	end
end

function ShopService.Start()
	local canSend = Util.RateLimiter(0.25)
	Net.ShopBuy.OnServerEvent:Connect(function(player, key)
		if canSend(player) then
			buy(player, key)
		end
	end)
end

return ShopService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'GuardService', [=====[
--[[
	GuardService  (ModuleScript)                       *** STEP 2 ***
	Location: ServerScriptService > Services > GuardService

	Guard bots. A player's guard count is profile.Upgrades.Guards (bought in
	the shop). Guards wander around the base; when an intruder comes close
	they walk at them and throw them out of the door, then need a few seconds
	to recharge.

	Guards are simple anchored models moved by the server, so they cannot be
	pushed around or tricked by a client.
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local Net = require(script.Parent.Net)
local PlayerData = require(script.Parent.PlayerData)
local BaseService = require(script.Parent.BaseService)

local GuardService = {}

local STEP = 0.25 -- seconds between guard "thoughts"
local guards = {} -- [owner Player] = { guard, guard, ... }
local random = Random.new()

-- Bottom of the Zone box = floor level of the base.
local function floorY(record)
	return record.Zone.Position.Y - record.Zone.Size.Y / 2
end

-- A random spot inside the base for a guard to walk to.
local function randomPoint(record)
	local half = record.Zone.Size / 2
	local x = random:NextNumber(-half.X + 4, half.X - 4)
	local z = random:NextNumber(-half.Z + 4, half.Z - 4)
	local point = record.Zone.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(point.X, floorY(record) + 2.5, point.Z)
end

local function createGuard(record)
	local model = Instance.new("Model")
	model.Name = "GuardBot"

	local function piece(name, size, offset, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.CanCollide = false
		part.Anchored = false
		part.Massless = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part, offset
	end

	-- The root is the only anchored part; the others are welded to it.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2.6, 3, 1.6)
	root.Color = Color3.fromRGB(40, 45, 60)
	root.Material = Enum.Material.Metal
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = CFrame.new(randomPoint(record))
	root.Parent = model
	model.PrimaryPart = root

	local extras = {
		{ piece("Head", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 2.4, 0), Color3.fromRGB(60, 65, 80)) },
		{ piece("Visor", Vector3.new(1.4, 0.4, 0.2), CFrame.new(0, 2.5, -0.8), Color3.fromRGB(255, 40, 40), Enum.Material.Neon) },
		{ piece("Base", Vector3.new(2.2, 1, 2.2), CFrame.new(0, -2, 0), Color3.fromRGB(25, 25, 30)) },
	}
	for _, entry in ipairs(extras) do
		local part, offset = entry[1], entry[2]
		part.CFrame = root.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
	end

	model.Parent = record.Model
	return { Model = model, Root = root, Waypoint = nil, NextPush = 0 }
end

-- Makes the number of guards in the base match what the player owns.
function GuardService.Refresh(player)
	local profile = PlayerData.Get(player)
	local record = BaseService.GetBase(player)
	if not profile or not record then
		return
	end
	local list = guards[player]
	if not list then
		list = {}
		guards[player] = list
	end
	while #list < profile.Upgrades.Guards do
		table.insert(list, createGuard(record))
	end
end

-- Removes a player's guards when they leave.
function GuardService.Clear(player)
	local list = guards[player]
	if list then
		for _, guard in ipairs(list) do
			guard.Model:Destroy()
		end
	end
	guards[player] = nil
end

local function updateGuard(guard, record, intruders, now)
	local position = guard.Root.Position

	-- Find the closest intruder.
	local target, targetDistance = nil, math.huge
	for _, intruder in ipairs(intruders) do
		local distance = (intruder.Root.Position - position).Magnitude
		if distance < targetDistance then
			target, targetDistance = intruder, distance
		end
	end

	local goal
	if target and targetDistance <= Config.Guard.SightRadius and now >= guard.NextPush then
		if targetDistance <= Config.Guard.PushRadius then
			-- Got them! Throw them out of the door and recharge.
			guard.NextPush = now + Config.Guard.PushCooldown
			BaseService.Eject(record, target.Player)
			Net.Notify(target.Player, "A guard bot threw you out!", "bad")
			return
		end
		goal = target.Root.Position
	else
		-- Nobody to chase: wander between random points.
		if not guard.Waypoint or (guard.Waypoint - position).Magnitude < 1.5 then
			guard.Waypoint = randomPoint(record)
		end
		goal = guard.Waypoint
	end

	-- Take one step toward the goal, staying at floor height.
	goal = Vector3.new(goal.X, position.Y, goal.Z)
	local offset = goal - position
	if offset.Magnitude < 0.1 then
		return
	end
	local stepLength = math.min(offset.Magnitude, Config.Guard.Speed * STEP)
	local newPosition = position + offset.Unit * stepLength
	local newCFrame = CFrame.lookAt(newPosition, newPosition + offset.Unit)
	-- A short tween makes the step look smooth on every client.
	TweenService:Create(guard.Root, TweenInfo.new(STEP, Enum.EasingStyle.Linear), { CFrame = newCFrame }):Play()
end

function GuardService.Start()
	task.spawn(function()
		while true do
			task.wait(STEP)
			local now = Workspace:GetServerTimeNow()
			for player, list in pairs(guards) do
				local record = BaseService.GetBase(player)
				if record and #list > 0 then
					local intruders = BaseService.GetIntruders(record)
					for _, guard in ipairs(list) do
						updateGuard(guard, record, intruders, now)
					end
				end
			end
		end
	end)
end

return GuardService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'EventService', [=====[
--[[
	EventService  (ModuleScript)                       *** STEP 3 ***
	Location: ServerScriptService > Services > EventService

	Every Config.Events.Interval seconds one random server event happens:
	  Power Surge - everyone's robots earn double for a while.
	  Junk Storm  - rare parts fall from the sky; first to grab one keeps it.

	The current event is stored in two Workspace attributes ("EventName" and
	"EventEndsAt") so the client can show a banner with a countdown.
]]

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local RobotService = require(script.Parent.RobotService)
local ItemVisuals = require(script.Parent.ItemVisuals)

local EventService = {}

local random = Random.new()

local function setBanner(name, duration)
	Workspace:SetAttribute("EventName", name)
	Workspace:SetAttribute("EventEndsAt", Workspace:GetServerTimeNow() + duration)
end

local function clearBanner()
	Workspace:SetAttribute("EventName", "")
	Workspace:SetAttribute("EventEndsAt", 0)
end

local function powerSurge()
	local settings = Config.Events.PowerSurge
	Net.NotifyAll(("POWER SURGE! Robots earn x%d for %d seconds!"):format(settings.Multiplier, settings.Duration), "good")
	setBanner("Power Surge", settings.Duration)
	RobotService.SetMultiplier(settings.Multiplier)
	task.wait(settings.Duration)
	RobotService.SetMultiplier(1)
	clearBanner()
	Net.NotifyAll("The power surge is over.", "info")
end

local function dropJunk(center)
	local settings = Config.Events.JunkStorm
	local item = Catalog.RollItem(settings.MinRarity)
	local rarity = Catalog.GetRarity(item)

	local piece = ItemVisuals.CreatePiece(item)
	piece.Anchored = false -- let it fall
	piece.CanCollide = true
	piece.CFrame = CFrame.new(
		center.X + random:NextNumber(-settings.Area, settings.Area),
		center.Y + 80,
		center.Z + random:NextNumber(-settings.Area, settings.Area)
	)
	ItemVisuals.AddLabel(piece, Catalog.DisplayName(item), rarity.Color, rarity.Name .. " - FREE!")

	local taken = false
	local prompt = Util.MakePrompt(piece, { ActionText = "Grab", ObjectText = Catalog.DisplayName(item), MaxDistance = 10 })
	prompt.Triggered:Connect(function(player)
		if taken or not PlayerData.Get(player) then
			return
		end
		if not Util.IsNear(player, piece.Position, 16) then
			return
		end
		taken = true -- first come, first served
		piece:Destroy()
		PlayerData.AddItem(player, item)
		RobotService.PushState(player)
		Net.Notify(player, ("Grabbed %s (%s)!"):format(Catalog.DisplayName(item), item.Rarity), "good")
	end)

	piece.Parent = Workspace
	-- Keep the physics on the server so a cheater's client cannot move it.
	piece:SetNetworkOwner(nil)
	Debris:AddItem(piece, settings.Lifetime)
end

local function junkStorm()
	local settings = Config.Events.JunkStorm
	Net.NotifyAll("JUNK STORM! Rare parts are falling from the sky - grab them!", "good")
	setBanner("Junk Storm", settings.Lifetime)

	local belt = Workspace.Map.Factory.Conveyor:FindFirstChild("Belt")
	local center = belt and belt.Position or Vector3.zero
	for _ = 1, settings.Count do
		dropJunk(center)
		task.wait(0.4)
	end

	task.wait(settings.Lifetime)
	clearBanner()
end

local events = { powerSurge, junkStorm }

function EventService.Start()
	clearBanner()
	task.spawn(function()
		while true do
			task.wait(Config.Events.Interval)
			local event = events[random:NextInteger(1, #events)]
			-- pcall so one broken event can never stop future events.
			local ok, problem = pcall(event)
			if not ok then
				warn("[EventService] event failed:", problem)
				RobotService.SetMultiplier(1)
				clearBanner()
			end
		end
	end)
end

return EventService
]=====])
install('ModuleScript', 'ServerScriptService', 'Services', 'DataService', [=====[
--[[
	DataService  (ModuleScript)                        *** STEP 4 ***
	Location: ServerScriptService > Services > DataService

	Saves each player's coins, inventory parts, robots and upgrades with
	DataStoreService.

	BEFORE THIS WORKS you must:
	  1. Publish the game (File > Publish to Roblox).
	  2. Turn on Game Settings > Security > "Enable Studio Access to API
	     Services" if you want saving to work while testing in Studio.

	Safety rule: if a player's data fails to LOAD, we never SAVE for them in
	that session (profile.CanSave = false). Otherwise a temporary Roblox
	outage would overwrite their real save with a fresh empty one.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local PlayerData = require(script.Parent.PlayerData)

local DataService = {}

local store = nil -- stays nil when DataStores are unavailable (unpublished place)

local function keyFor(player)
	return "player_" .. player.UserId
end

local function disable(reason)
	store = nil
	warn("[DataService] Saving is OFF for this session: " .. tostring(reason))
	warn("[DataService] Publish the game and enable 'Studio Access to API Services' to test saving.")
end

-- Returns: savedData (or nil), loadedOk
function DataService.Load(player)
	if not store then
		return nil, true
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			return result, true
		end
		warn(("[DataService] load failed for %s (try %d): %s"):format(player.Name, attempt, tostring(result)))
		if RunService:IsStudio() then
			-- In Studio this almost always means API access is turned off.
			disable(result)
			return nil, true
		end
		task.wait(2)
	end
	return nil, false
end

-- Number of saves that are still talking to Roblox right now.
local activeSaves = 0

-- Saves one player. The data is copied the moment this is called, so the
-- caller may delete the profile straight afterwards.
function DataService.Save(player)
	local profile = PlayerData.Get(player)
	if not store or not profile or not profile.CanSave then
		return
	end
	local data = PlayerData.Serialize(profile)
	local key = keyFor(player)
	local userId = player.UserId

	activeSaves += 1
	for attempt = 1, 3 do
		local ok, problem = pcall(function()
			store:SetAsync(key, data, { userId })
		end)
		if ok then
			break
		end
		warn(("[DataService] save failed for %s (try %d): %s"):format(player.Name, attempt, tostring(problem)))
		task.wait(2)
	end
	activeSaves -= 1
end

-- Used when the server shuts down: saves everyone who is still here and
-- waits until every save (including ones already running) has finished.
function DataService.SaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.Save, player)
	end
	while activeSaves > 0 do
		task.wait()
	end
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Saving.StoreName)
	end)
	if ok then
		store = result
	else
		disable(result)
	end

	-- Autosave, so a server crash loses a couple of minutes at most.
	task.spawn(function()
		while true do
			task.wait(Config.Saving.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService
]=====])
install('LocalScript', 'StarterPlayerScripts', nil, 'ClientMain', [=====[
--[[
	ClientMain  (LocalScript)
	Location: StarterPlayer > StarterPlayerScripts > ClientMain

	The whole user interface. It builds its own ScreenGui, so you do not have
	to make any UI by hand in Studio:
	  * coin counter (+ coins per second)
	  * "Robots" window: your build pads and your part inventory
	  * "Shop" window: guards and upgrades
	  * pop-up notifications (red alarm when someone steals from you)
	  * event banner and base-lock status

	IMPORTANT: this script only SHOWS things and SENDS REQUESTS. It never
	changes coins or parts itself. A cheater can edit this script as much as
	they like - the server ignores anything that is not allowed.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Catalog = require(Shared:WaitForChild("PartCatalog"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlacePart = Remotes:WaitForChild("PlacePart")
local RemovePart = Remotes:WaitForChild("RemovePart")
local ShopBuy = Remotes:WaitForChild("ShopBuy")
local StateEvent = Remotes:WaitForChild("State")
local NotifyEvent = Remotes:WaitForChild("Notify")

-- The latest copy of our data from the server (display only).
local state = { Parts = {}, Robots = {}, Upgrades = {} }

-- Colours ----------------------------------------------------------------------
local DARK = Color3.fromRGB(28, 30, 38)
local MID = Color3.fromRGB(44, 47, 60)
local LIGHT = Color3.fromRGB(235, 238, 245)
local GREEN = Color3.fromRGB(60, 190, 100)
local RED = Color3.fromRGB(215, 65, 65)
local BLUE = Color3.fromRGB(60, 130, 230)
local GOLD = Color3.fromRGB(255, 205, 60)

-- Small helpers ------------------------------------------------------------------

-- Creates an Instance, sets its properties and adds children in one call.
local function make(className, props, children)
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

-- 1234567 -> "1,234,567"
local function commas(number)
	local text = tostring(math.floor(number))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if result:sub(1, 1) == "," then
		result = result:sub(2)
	end
	return result
end

local function makeText(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = LIGHT,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in pairs(props) do
		defaults[key] = value
	end
	return make("TextLabel", defaults)
end

local function makeButton(text, color, props)
	local defaults = {
		Text = text,
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 15,
		AutoButtonColor = true,
	}
	for key, value in pairs(props or {}) do
		defaults[key] = value
	end
	return make("TextButton", defaults, { corner(6) })
end

-- The ScreenGui ------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "RobARobotUI",
	ResetOnSpawn = false, -- keep the UI when the character respawns
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Coin counter (left side) -----------------------------------------------------------
local coinFrame = make("Frame", {
	Size = UDim2.fromOffset(190, 58),
	Position = UDim2.new(0, 12, 0.5, -130),
	BackgroundColor3 = DARK,
	Parent = gui,
}, { corner(10) })
local coinLabel = makeText({
	Size = UDim2.new(1, -20, 0, 30),
	Position = UDim2.fromOffset(12, 4),
	Font = Enum.Font.GothamBold,
	TextSize = 24,
	TextColor3 = GOLD,
	Text = "0 coins",
	Parent = coinFrame,
})
local incomeLabel = makeText({
	Size = UDim2.new(1, -20, 0, 18),
	Position = UDim2.fromOffset(12, 34),
	TextSize = 14,
	TextColor3 = GREEN,
	Text = "+0 / sec",
	Parent = coinFrame,
})

-- Menu buttons under the coin counter.
local robotsButton = makeButton("Robots", BLUE, {
	Size = UDim2.fromOffset(190, 40),
	Position = UDim2.new(0, 12, 0.5, -64),
	TextSize = 18,
	Parent = gui,
})
local shopButton = makeButton("Shop", GREEN, {
	Size = UDim2.fromOffset(190, 40),
	Position = UDim2.new(0, 12, 0.5, -18),
	TextSize = 18,
	Parent = gui,
})

-- Base lock status + event banner.
local lockLabel = makeText({
	Size = UDim2.fromOffset(190, 22),
	Position = UDim2.new(0, 12, 0.5, 30),
	TextSize = 14,
	Text = "",
	Parent = gui,
})
local eventLabel = makeText({
	Size = UDim2.fromOffset(360, 34),
	Position = UDim2.new(0.5, 0, 1, -90),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(120, 60, 200),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
	Parent = gui,
})
corner(8).Parent = eventLabel

-- Windows --------------------------------------------------------------------------

-- Makes a centred window with a title, a close button and a scrolling list.
local function makeWindow(title)
	local window = make("Frame", {
		Size = UDim2.new(0, 440, 0.8, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = DARK,
		Visible = false,
		Parent = gui,
	}, {
		corner(12),
		make("UISizeConstraint", { MaxSize = Vector2.new(440, 520) }),
	})
	makeText({
		Size = UDim2.new(1, -60, 0, 40),
		Position = UDim2.fromOffset(16, 4),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Text = title,
		Parent = window,
	})
	local close = makeButton("X", RED, {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -40, 0, 8),
		Parent = window,
	})
	close.Activated:Connect(function()
		window.Visible = false
	end)
	local list = make("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -60),
		Position = UDim2.fromOffset(12, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = window,
	}, {
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	return window, list
end

local robotsWindow, robotsList = makeWindow("Robots & Parts")
local shopWindow, shopList = makeWindow("Shop")

robotsButton.Activated:Connect(function()
	shopWindow.Visible = false
	robotsWindow.Visible = not robotsWindow.Visible
end)
shopButton.Activated:Connect(function()
	robotsWindow.Visible = false
	shopWindow.Visible = not shopWindow.Visible
end)

local function clearList(list)
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

-- Each call returns the next LayoutOrder number so rows stay in the order we add them.
local order = 0
local function nextOrder()
	order += 1
	return order
end

local function addHeader(list, text, color)
	makeText({
		Size = UDim2.new(1, -8, 0, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = color or GOLD,
		Text = text,
		LayoutOrder = nextOrder(),
		Parent = list,
	})
end

-- A row with text on the left and (optionally) a button on the right.
local function addRow(list, text, textColor, buttonText, buttonColor, onClick)
	local row = make("Frame", {
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundColor3 = MID,
		LayoutOrder = nextOrder(),
		Parent = list,
	}, { corner(6) })
	makeText({
		Size = UDim2.new(1, buttonText and -110 or -16, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextColor3 = textColor or LIGHT,
		Text = text,
		Parent = row,
	})
	if buttonText then
		local button = makeButton(buttonText, buttonColor, {
			Size = UDim2.fromOffset(88, 26),
			Position = UDim2.new(1, -94, 0.5, -13),
			Parent = row,
		})
		button.Activated:Connect(onClick)
	end
	return row
end

-- Robots window ----------------------------------------------------------------------
local function redrawRobots()
	clearList(robotsList)

	local unlockedPads = math.min(Config.MaxPads, 1 + (state.Upgrades.Pads or 0))
	for padIndex = 1, unlockedPads do
		local robot = state.Robots[padIndex] or {}
		local income, complete, setBonus = Catalog.RobotIncome(robot)
		local status = "offline - needs all 5 parts"
		if complete then
			status = ("+%d coins/s"):format(income) .. (setBonus and "  (FULL SET x" .. Config.SetBonus .. ")" or "")
		end
		addHeader(robotsList, ("Build Pad %d - %s"):format(padIndex, status), complete and GREEN or GOLD)

		for _, slot in ipairs(Catalog.Slots) do
			local item = robot[slot]
			if item then
				local rarity = Catalog.GetRarity(item)
				addRow(robotsList, ("%s  [%s]"):format(Catalog.DisplayName(item), item.Rarity), rarity.Color, "Remove", RED, function()
					RemovePart:FireServer(padIndex, slot)
				end)
			else
				addRow(robotsList, slot .. ": empty", Color3.fromRGB(150, 150, 160))
			end
		end
	end

	addHeader(robotsList, ("Inventory (%d parts)"):format(#state.Parts))
	if #state.Parts == 0 then
		addRow(robotsList, "Buy parts from the conveyor (press E on them).", Color3.fromRGB(150, 150, 160))
	else
		addRow(robotsList, "Stand next to a build pad, then press Place.", Color3.fromRGB(150, 150, 160))
	end

	-- Best parts first.
	local sorted = table.clone(state.Parts)
	table.sort(sorted, function(a, b)
		local rarityA, rarityB = Catalog.RarityIndex[a.Rarity], Catalog.RarityIndex[b.Rarity]
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		return Catalog.DisplayName(a) < Catalog.DisplayName(b)
	end)
	for _, item in ipairs(sorted) do
		local rarity = Catalog.GetRarity(item)
		addRow(robotsList, ("%s  [%s]  +%d/s"):format(Catalog.DisplayName(item), item.Rarity, rarity.Income), rarity.Color, "Place", GREEN, function()
			-- We only send the item's Id. The server works out the rest.
			PlacePart:FireServer(item.Id)
		end)
	end
end

-- Shop window ------------------------------------------------------------------------
local function redrawShop()
	clearList(shopList)
	for _, def in ipairs(Config.Shop) do
		local level = state.Upgrades[def.Key] or 0
		local price = def.Prices[level + 1]
		addHeader(shopList, ("%s  (%d / %d)"):format(def.Name, level, #def.Prices))
		if price then
			addRow(shopList, def.Desc, LIGHT, commas(price), GREEN, function()
				-- We only send WHAT we want. The server decides the price.
				ShopBuy:FireServer(def.Key)
			end)
		else
			addRow(shopList, def.Desc .. "  (MAX)", Color3.fromRGB(150, 150, 160))
		end
	end
end

StateEvent.OnClientEvent:Connect(function(newState)
	state = newState
	state.Parts = state.Parts or {}
	state.Robots = state.Robots or {}
	state.Upgrades = state.Upgrades or {}
	redrawRobots()
	redrawShop()
end)
redrawRobots()
redrawShop()

-- Notifications ------------------------------------------------------------------------
local toastHolder = make("Frame", {
	Size = UDim2.new(0, 440, 0, 300),
	Position = UDim2.new(0.5, 0, 0, 8),
	AnchorPoint = Vector2.new(0.5, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local TOAST_COLORS = {
	info = MID,
	good = Color3.fromRGB(35, 120, 70),
	bad = Color3.fromRGB(140, 60, 50),
	alarm = Color3.fromRGB(220, 30, 30),
}

local function showToast(text, kind)
	local toast = makeText({
		Size = UDim2.new(1, 0, 0, kind == "alarm" and 46 or 36),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = TOAST_COLORS[kind] or MID,
		Font = Enum.Font.GothamBold,
		TextSize = kind == "alarm" and 20 or 16,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
		LayoutOrder = nextOrder(),
		Parent = toastHolder,
	})
	corner(8).Parent = toast
	task.delay(kind == "alarm" and 7 or 4, function()
		toast:Destroy()
	end)
end

NotifyEvent.OnClientEvent:Connect(showToast)

-- Coins ----------------------------------------------------------------------------------
-- The coin number lives in player.leaderstats.Coins, which only the server can change.
task.spawn(function()
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
	local function update()
		coinLabel.Text = commas(coins.Value) .. " coins"
	end
	coins.Changed:Connect(update)
	update()
end)

local function updateIncome()
	incomeLabel.Text = ("+%s / sec"):format(commas(player:GetAttribute("Income") or 0))
end
player:GetAttributeChangedSignal("Income"):Connect(updateIncome)
updateIncome()

-- Lock status + event banner (updated a few times per second) --------------------------------
local function findMyBase()
	local map = Workspace:FindFirstChild("Map")
	local bases = map and map:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			if base:GetAttribute("OwnerUserId") == player.UserId then
				return base
			end
		end
	end
	return nil
end

task.spawn(function()
	while true do
		local now = Workspace:GetServerTimeNow()

		local base = findMyBase()
		if base then
			local lockedUntil = base:GetAttribute("LockedUntil") or 0
			local readyAt = base:GetAttribute("LockReadyAt") or 0
			if now < lockedUntil then
				lockLabel.Text = ("Base LOCKED: %d s"):format(math.ceil(lockedUntil - now))
				lockLabel.TextColor3 = GREEN
			elseif now < readyAt then
				lockLabel.Text = ("Lock recharging: %d s"):format(math.ceil(readyAt - now))
				lockLabel.TextColor3 = RED
			else
				lockLabel.Text = "Lock ready (red button)"
				lockLabel.TextColor3 = LIGHT
			end
		else
			lockLabel.Text = ""
		end

		local eventName = Workspace:GetAttribute("EventName")
		local endsAt = Workspace:GetAttribute("EventEndsAt") or 0
		if eventName and eventName ~= "" and now < endsAt then
			local left = math.ceil(endsAt - now)
			eventLabel.Text = ("%s  %d:%02d"):format(string.upper(eventName), left // 60, left % 60)
			eventLabel.Visible = true
		else
			eventLabel.Visible = false
		end

		task.wait(0.25)
	end
end)

-- Hide prompts that are not meant for us ---------------------------------------------------
-- The server tags prompts and stores the base owner's UserId on them:
--   "OwnerOnlyPrompt" - only the owner should see it (the lock button)
--   "NotOwnerPrompt"  - everyone EXCEPT the owner should see it (steal prompts)
-- Hiding is just for tidiness. The server checks who used a prompt anyway.
local function watchPrompts(tag, ownerShouldSee)
	local function apply(prompt)
		local function update()
			local isMine = prompt:GetAttribute("OwnerUserId") == player.UserId
			prompt.Enabled = (isMine == ownerShouldSee)
		end
		prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
		update()
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(apply)
	for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
		apply(prompt)
	end
end

watchPrompts("OwnerOnlyPrompt", true)
watchPrompts("NotOwnerPrompt", false)
]=====])
print('Rob-a-Robot: installed 17 scripts. Press Play!')
