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
