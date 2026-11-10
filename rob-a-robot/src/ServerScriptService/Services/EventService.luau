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
