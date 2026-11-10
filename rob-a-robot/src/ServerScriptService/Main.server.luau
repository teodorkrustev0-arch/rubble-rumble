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
