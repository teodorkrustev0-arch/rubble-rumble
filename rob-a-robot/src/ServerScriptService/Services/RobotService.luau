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
