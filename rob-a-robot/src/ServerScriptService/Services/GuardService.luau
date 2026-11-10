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
