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
