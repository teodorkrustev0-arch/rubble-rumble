--[[
	ItemVisuals  (ModuleScript)
	Location: ServerScriptService > Services > ItemVisuals

	Turns an item table into something you can see: a coloured Part with a
	floating name label. The same shapes are used on the conveyor, on build
	pads and for junk-storm drops, so everything looks consistent.

	Want real meshes later? Replace CreatePiece so it clones a model from
	ServerStorage instead of making a plain Part.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.PartCatalog)

local ItemVisuals = {}

-- Size of each slot's piece and where it sits on a robot.
-- Offset is measured from the centre of the TOP of the build pad.
ItemVisuals.Shapes = {
	Legs = { Size = Vector3.new(2.4, 2.5, 1.2), Offset = Vector3.new(0, 1.25, 0) },
	Body = { Size = Vector3.new(3, 3, 1.6), Offset = Vector3.new(0, 4, 0) },
	Arms = { Size = Vector3.new(5.2, 0.9, 0.9), Offset = Vector3.new(0, 4.7, 0) },
	Head = { Size = Vector3.new(1.8, 1.8, 1.8), Offset = Vector3.new(0, 6.4, 0) },
	Core = { Size = Vector3.new(1.1, 1.1, 1.1), Offset = Vector3.new(0, 4, -0.9), Ball = true },
}

-- Makes the Part for one item. It is anchored and has no collisions; the
-- caller positions and parents it.
function ItemVisuals.CreatePiece(item)
	local shape = ItemVisuals.Shapes[item.Slot]
	local rarity = Catalog.GetRarity(item)

	local piece = Instance.new("Part")
	piece.Name = item.Slot
	piece.Size = shape.Size
	piece.Color = rarity.Color
	piece.Anchored = true
	piece.CanCollide = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Material = Enum.Material.SmoothPlastic
	if shape.Ball then
		piece.Shape = Enum.PartType.Ball
		piece.Material = Enum.Material.Neon
	end
	-- Legendary and Mythic parts glow so they stand out on the belt.
	if Catalog.RarityIndex[item.Rarity] >= 4 then
		piece.Material = Enum.Material.Neon
	end
	return piece
end

-- Adds a floating two-line label above a part.
function ItemVisuals.AddLabel(part, title, titleColor, subtitle, height)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, height or 2.2, 0)
	gui.MaxDistance = 70
	gui.AlwaysOnTop = false

	local top = Instance.new("TextLabel")
	top.Name = "Title"
	top.Size = UDim2.fromScale(1, 0.55)
	top.BackgroundTransparency = 1
	top.Font = Enum.Font.GothamBold
	top.TextScaled = true
	top.Text = title
	top.TextColor3 = titleColor or Color3.new(1, 1, 1)
	top.TextStrokeTransparency = 0
	top.Parent = gui

	local bottom = Instance.new("TextLabel")
	bottom.Name = "Subtitle"
	bottom.Size = UDim2.fromScale(1, 0.45)
	bottom.Position = UDim2.fromScale(0, 0.55)
	bottom.BackgroundTransparency = 1
	bottom.Font = Enum.Font.Gotham
	bottom.TextScaled = true
	bottom.Text = subtitle or ""
	bottom.TextColor3 = Color3.new(1, 1, 1)
	bottom.TextStrokeTransparency = 0
	bottom.Parent = gui

	gui.Parent = part
	return gui
end

return ItemVisuals
