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
