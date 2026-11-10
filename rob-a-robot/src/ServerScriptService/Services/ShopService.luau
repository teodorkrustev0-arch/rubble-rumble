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
