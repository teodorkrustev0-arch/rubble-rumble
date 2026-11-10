--[[
	ConveyorService  (ModuleScript)
	Location: ServerScriptService > Services > ConveyorService

	Spawns random robot parts at the start of the belt, slides them to the
	end, and sells them to players who press E on them (or click them).
]]

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PartCatalog)

local Net = require(script.Parent.Net)
local Util = require(script.Parent.Util)
local PlayerData = require(script.Parent.PlayerData)
local RobotService = require(script.Parent.RobotService)
local ItemVisuals = require(script.Parent.ItemVisuals)

local ConveyorService = {}

local itemFolder
local forSale = {} -- [Part on the belt] = item table

local function buy(player, piece)
	-- Somebody else may have bought it a moment ago.
	local item = forSale[piece]
	if not item then
		return
	end
	if not PlayerData.Get(player) then
		return
	end
	-- Server-side distance check: exploiters can fire prompts from anywhere.
	if not Util.IsNear(player, piece.Position, Config.Conveyor.BuyDistance) then
		return
	end

	local price = Catalog.GetRarity(item).Price
	if not PlayerData.TrySpend(player, price) then
		Net.Notify(player, ("Not enough coins (need %d)."):format(price), "bad")
		return
	end

	-- Nothing above this line waits, so two players can never buy the same
	-- part: the first one to get here removes it from forSale.
	forSale[piece] = nil
	piece:Destroy()

	PlayerData.AddItem(player, item)
	RobotService.PushState(player)
	Net.Notify(player, ("Bought %s (%s)"):format(Catalog.DisplayName(item), item.Rarity), "good")
end

local function spawnItem(startCFrame, endCFrame)
	local item = Catalog.RollItem()
	local rarity = Catalog.GetRarity(item)

	local piece = ItemVisuals.CreatePiece(item)
	piece.CFrame = startCFrame
	ItemVisuals.AddLabel(piece, Catalog.DisplayName(item), rarity.Color, ("%s - %d coins"):format(rarity.Name, rarity.Price))

	-- Press E...
	local prompt = Util.MakePrompt(piece, {
		ActionText = ("Buy (%d)"):format(rarity.Price),
		ObjectText = Catalog.DisplayName(item),
		MaxDistance = 10,
	})
	prompt.Triggered:Connect(function(player)
		buy(player, piece)
	end)

	-- ...or click it.
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.Conveyor.BuyDistance
	click.Parent = piece
	click.MouseClick:Connect(function(player)
		buy(player, piece)
	end)

	forSale[piece] = item
	piece.Destroying:Connect(function()
		forSale[piece] = nil
	end)
	piece.Parent = itemFolder

	-- Slide along the belt, then fall off the end (get destroyed).
	local travelTime = (endCFrame.Position - startCFrame.Position).Magnitude / Config.Conveyor.Speed
	local tween = TweenService:Create(piece, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), { CFrame = endCFrame })
	tween.Completed:Connect(function()
		piece:Destroy()
	end)
	tween:Play()
end

function ConveyorService.Start()
	local conveyor = Workspace:WaitForChild("Map"):WaitForChild("Factory"):WaitForChild("Conveyor")
	local spawnPoint = conveyor:WaitForChild("SpawnPoint")
	local endPoint = conveyor:WaitForChild("EndPoint")

	itemFolder = Instance.new("Folder")
	itemFolder.Name = "ConveyorItems"
	itemFolder.Parent = Workspace

	-- Items keep the SpawnPoint's rotation the whole way along.
	local startCFrame = spawnPoint.CFrame
	local endCFrame = startCFrame.Rotation + endPoint.Position

	task.spawn(function()
		while true do
			if #itemFolder:GetChildren() < Config.Conveyor.MaxItems then
				spawnItem(startCFrame, endCFrame)
			end
			task.wait(Config.Conveyor.SpawnInterval)
		end
	end)
end

return ConveyorService
