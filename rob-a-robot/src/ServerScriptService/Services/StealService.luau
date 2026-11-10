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
