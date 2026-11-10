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
