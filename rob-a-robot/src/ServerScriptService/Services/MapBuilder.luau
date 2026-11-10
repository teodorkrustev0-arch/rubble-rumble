--[[
	MapBuilder  (ModuleScript)
	Location: ServerScriptService > Services > MapBuilder

	Builds the whole Rob-a-Robot map out of Parts:
	  * a factory plaza with the conveyor, a part dispenser, a recycler,
	    light arches and a big title sign
	  * 8 walled, colour-coded bases with build pads, a lock button and a sign
	  * paths, trees, crates and an outer wall

	TWO WAYS TO USE IT

	1. Automatic: do nothing. When the game starts and Workspace has no model
	   called "Map", Main calls MapBuilder.Build().

	2. Permanent (recommended once you want to decorate): in Studio, WITHOUT
	   pressing Play, open View > Command Bar and run this one line:

	       require(game.ServerScriptService.Services.MapBuilder).Build()

	   The map is now a normal model in Workspace that you can edit by hand
	   and that gets saved with your place. To throw it away and build a
	   fresh one, run the same line with .Rebuild() instead of .Build().

	The parts the game scripts need (Belt, SpawnPoint, EndPoint, Zone, Door,
	Entrance, Spawn, LockButton, Sign, Pad1-3) keep their exact names.
	Everything inside a folder called "Decor" is decoration only - delete or
	change it freely.
]]

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapBuilder = {}

-- Layout numbers ---------------------------------------------------------------
local GROUND_TOP = 0.1 -- a hair above the default Baseplate so they never flicker
local BASE_SIZE = 40 -- bases are 40 x 40 studs
local WALL_HEIGHT = 14
local DOOR_WIDTH = 10
local BASE_SPACING = 50 -- distance between base centres along the belt
local BASE_DISTANCE = 70 -- distance from the belt to a base centre
local BELT_LENGTH = 180
local BELT_TOP = 3 -- height of the belt surface
local MAP_HALF_X = 136 -- outer wall position
local MAP_HALF_Z = 122

-- Colours ------------------------------------------------------------------------
local CONCRETE = Color3.fromRGB(105, 108, 115)
local DARK_STEEL = Color3.fromRGB(52, 56, 66)
local STEEL = Color3.fromRGB(120, 126, 138)
local BLACK = Color3.fromRGB(20, 20, 24)
local HAZARD = Color3.fromRGB(245, 200, 40)
local WOOD = Color3.fromRGB(150, 105, 60)
local CYAN = Color3.fromRGB(0, 200, 255)
local ORANGE = Color3.fromRGB(255, 130, 30)

local BASE_COLORS = {
	Color3.fromRGB(231, 76, 60),
	Color3.fromRGB(52, 152, 219),
	Color3.fromRGB(46, 204, 113),
	Color3.fromRGB(241, 196, 15),
	Color3.fromRGB(155, 89, 182),
	Color3.fromRGB(230, 126, 34),
	Color3.fromRGB(26, 188, 156),
	Color3.fromRGB(236, 100, 170),
}

-- Part helpers --------------------------------------------------------------------

local function newPart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or CONCRETE
	part.Anchored = true
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A decoration you can walk through (thin stripes, lamps, signs...).
local function newGhost(parent, name, size, cframe, color, material)
	local part = newPart(parent, name, size, cframe, color, material)
	part.CanCollide = false
	return part
end

-- An invisible part that is only used as a position marker / trigger volume.
local function newMarker(parent, name, size, cframe)
	local part = newPart(parent, name, size, cframe)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	return part
end

-- An upright cylinder. cframe is its centre.
local function newCylinder(parent, name, diameter, height, cframe, color, material)
	local part = newPart(parent, name, Vector3.new(height, diameter, diameter), cframe * CFrame.Angles(0, 0, math.pi / 2), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function newFolder(parent, name)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Writes text on one face of a part.
local function addText(part, face, text, color)
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = face
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.PixelsPerStud = 40
	surfaceGui.LightInfluence = 0
	surfaceGui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = surfaceGui
	return label
end

local function addLight(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 24
	light.Brightness = brightness or 1.5
	light.Parent = part
	return light
end

-- Factory ---------------------------------------------------------------------------

local function buildMachine(decor, direction, name, glow)
	-- direction is -1 for the machine at the start of the belt, 1 for the end.
	local x = direction * (BELT_LENGTH / 2 + 8)
	local faceX = direction * (BELT_LENGTH / 2 - 0.1)
	-- The face that looks at the middle of the map.
	local innerFace = direction == -1 and Enum.NormalId.Right or Enum.NormalId.Left

	newPart(decor, name, Vector3.new(16, 16, 16), CFrame.new(x, 8, 0), DARK_STEEL, Enum.Material.Metal)
	newGhost(decor, name .. "Mouth", Vector3.new(0.4, 5.5, 7.4), CFrame.new(faceX, BELT_TOP + 2.75, 0), BLACK)
	newGhost(decor, name .. "Glow", Vector3.new(16.4, 1, 16.4), CFrame.new(x, 10.5, 0), glow, Enum.Material.Neon)

	local plate = newGhost(decor, name .. "Sign", Vector3.new(0.4, 3, 14), CFrame.new(faceX, 13.5, 0), BLACK)
	addText(plate, innerFace, direction == -1 and "PART DISPENSER" or "RECYCLER", glow)

	newCylinder(decor, name .. "Chimney", 4, 10, CFrame.new(x, 21, 0), STEEL, Enum.Material.Metal)
	local ring = newCylinder(decor, name .. "ChimneyGlow", 4.6, 0.8, CFrame.new(x, 25.5, 0), glow, Enum.Material.Neon)
	ring.CanCollide = false
	addLight(ring, glow, 30, 2)

	-- A pile of crates next to each machine.
	for _, side in ipairs({ 1, -1 }) do
		newPart(decor, "Crate", Vector3.new(4, 4, 4), CFrame.new(x, 2, side * 14) * CFrame.Angles(0, 0.3, 0), WOOD, Enum.Material.WoodPlanks)
		newPart(decor, "Crate", Vector3.new(3, 3, 3), CFrame.new(x - direction * 4.5, 1.5, side * 15), WOOD, Enum.Material.WoodPlanks)
		newPart(decor, "Crate", Vector3.new(2.5, 2.5, 2.5), CFrame.new(x, 5.25, side * 14) * CFrame.Angles(0, -0.4, 0), WOOD, Enum.Material.WoodPlanks)
	end
end

local function buildFactory(map)
	local factory = Instance.new("Model")
	factory.Name = "Factory"

	local decor = newFolder(factory, "Decor")

	-- Concrete plaza under the conveyor.
	newPart(decor, "Plaza", Vector3.new(BELT_LENGTH + 56, 0.2, 44), CFrame.new(0, GROUND_TOP + 0.1, 0), CONCRETE, Enum.Material.Concrete)

	-- The conveyor. These three names are what ConveyorService looks for. ------
	local conveyor = Instance.new("Model")
	conveyor.Name = "Conveyor"
	conveyor.Parent = factory

	local belt = newPart(conveyor, "Belt", Vector3.new(BELT_LENGTH, 0.6, 6), CFrame.new(0, BELT_TOP - 0.3, 0), Color3.fromRGB(38, 38, 44), Enum.Material.Rubber)
	conveyor.PrimaryPart = belt
	-- Parts appear at SpawnPoint and slide in a straight line to EndPoint.
	newMarker(conveyor, "SpawnPoint", Vector3.new(1, 1, 1), CFrame.new(-BELT_LENGTH / 2 + 4, BELT_TOP + 1.6, 0))
	newMarker(conveyor, "EndPoint", Vector3.new(1, 1, 1), CFrame.new(BELT_LENGTH / 2 - 4, BELT_TOP + 1.6, 0))

	-- Belt decoration: a body underneath, side rails, slats and warning stripes.
	local beltDecor = newFolder(conveyor, "Decor")
	newPart(beltDecor, "BeltBody", Vector3.new(BELT_LENGTH, BELT_TOP - 0.6, 6.8), CFrame.new(0, (BELT_TOP - 0.6) / 2, 0), DARK_STEEL, Enum.Material.Metal)
	for _, side in ipairs({ 1, -1 }) do
		newPart(beltDecor, "Rail", Vector3.new(BELT_LENGTH, 0.8, 0.4), CFrame.new(0, BELT_TOP - 0.2, side * 3.2), STEEL, Enum.Material.Metal)
		newGhost(beltDecor, "HazardStripe", Vector3.new(BELT_LENGTH, 0.05, 1), CFrame.new(0, GROUND_TOP + 0.23, side * 5.5), HAZARD)
	end
	for x = -BELT_LENGTH / 2 + 3, BELT_LENGTH / 2 - 3, 6 do
		newGhost(beltDecor, "Slat", Vector3.new(0.4, 0.06, 5.8), CFrame.new(x, BELT_TOP + 0.03, 0), Color3.fromRGB(70, 70, 78))
	end

	-- A machine at each end of the belt.
	buildMachine(decor, -1, "Dispenser", CYAN)
	buildMachine(decor, 1, "Recycler", ORANGE)

	-- Four light arches over the belt.
	for _, x in ipairs({ -60, -20, 20, 60 }) do
		for _, side in ipairs({ 1, -1 }) do
			newPart(decor, "ArchPillar", Vector3.new(2, 20, 2), CFrame.new(x, 10, side * 14), DARK_STEEL, Enum.Material.Metal)
		end
		newPart(decor, "ArchBeam", Vector3.new(2, 2, 30), CFrame.new(x, 21, 0), DARK_STEEL, Enum.Material.Metal)
		local lamp = newGhost(decor, "ArchLamp", Vector3.new(3, 0.6, 3), CFrame.new(x, 19.7, 0), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)
		addLight(lamp, Color3.fromRGB(255, 240, 200), 45, 1.5)
	end

	-- Title sign resting on the two middle arches, readable from both sides.
	local title = newPart(decor, "TitleSign", Vector3.new(42, 7, 1), CFrame.new(0, 25.5, 0), BLACK)
	addText(title, Enum.NormalId.Front, "ROB-A-ROBOT", HAZARD)
	addText(title, Enum.NormalId.Back, "ROB-A-ROBOT", HAZARD)
	newGhost(decor, "TitleGlow", Vector3.new(43, 0.5, 1.4), CFrame.new(0, 29.25, 0), CYAN, Enum.Material.Neon)
	newGhost(decor, "TitleGlow", Vector3.new(43, 0.5, 1.4), CFrame.new(0, 21.9, 0), CYAN, Enum.Material.Neon)

	factory.Parent = map
end

-- Bases -------------------------------------------------------------------------------

-- Builds one base. baseCFrame is on the ground at the centre of the base and
-- its front (-Z, the "LookVector") points toward the conveyor.
local function buildBase(folder, index, baseCFrame)
	local color = BASE_COLORS[(index - 1) % #BASE_COLORS + 1]
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local floorColor = color:Lerp(Color3.new(1, 1, 1), 0.6)
	local half = BASE_SIZE / 2
	local floorTop = GROUND_TOP + 0.3

	local base = Instance.new("Model")
	base.Name = "Base" .. index

	local function at(x, y, z)
		return baseCFrame * CFrame.new(x, y, z)
	end

	local floor = newPart(base, "Floor", Vector3.new(BASE_SIZE, 0.3, BASE_SIZE), at(0, floorTop - 0.15, 0), floorColor)
	base.PrimaryPart = floor

	-- Walls: back, left, right, and two front pieces with a door gap between.
	local walls = newFolder(base, "Walls")
	local frontWidth = (BASE_SIZE - DOOR_WIDTH) / 2
	local frontX = DOOR_WIDTH / 2 + frontWidth / 2
	local wallShapes = {
		{ Vector3.new(BASE_SIZE, WALL_HEIGHT, 1), Vector3.new(0, 0, half - 0.5) },
		{ Vector3.new(1, WALL_HEIGHT, BASE_SIZE), Vector3.new(-half + 0.5, 0, 0) },
		{ Vector3.new(1, WALL_HEIGHT, BASE_SIZE), Vector3.new(half - 0.5, 0, 0) },
		{ Vector3.new(frontWidth, WALL_HEIGHT, 1), Vector3.new(-frontX, 0, -half + 0.5) },
		{ Vector3.new(frontWidth, WALL_HEIGHT, 1), Vector3.new(frontX, 0, -half + 0.5) },
	}

	local decor = newFolder(base, "Decor")
	for _, shape in ipairs(wallShapes) do
		local size, offset = shape[1], shape[2]
		newPart(walls, "Wall", size, at(offset.X, WALL_HEIGHT / 2, offset.Z), wallColor, Enum.Material.Concrete)
		-- Glowing strip along the top of every wall in the base's colour.
		newGhost(decor, "WallTrim", Vector3.new(size.X + 0.2, 0.6, size.Z + 0.2), at(offset.X, WALL_HEIGHT + 0.3, offset.Z), color, Enum.Material.Neon)
	end

	-- Corner towers with a lamp on top.
	for _, cornerX in ipairs({ -1, 1 }) do
		for _, cornerZ in ipairs({ -1, 1 }) do
			local x, z = cornerX * (half - 0.5), cornerZ * (half - 0.5)
			newPart(decor, "Tower", Vector3.new(3, WALL_HEIGHT + 3, 3), at(x, (WALL_HEIGHT + 3) / 2, z), DARK_STEEL, Enum.Material.Metal)
			local cap = newGhost(decor, "TowerLamp", Vector3.new(2.2, 1.2, 2.2), at(x, WALL_HEIGHT + 3.6, z), color, Enum.Material.Neon)
			addLight(cap, color, 28, 1.2)
		end
	end

	-- Door posts and a walkway from the door to the spawn pad.
	for _, side in ipairs({ -1, 1 }) do
		newPart(decor, "DoorPost", Vector3.new(1.4, WALL_HEIGHT, 1.6), at(side * (DOOR_WIDTH / 2 + 0.7), WALL_HEIGHT / 2, -half + 0.5), DARK_STEEL, Enum.Material.Metal)
	end
	newGhost(decor, "Walkway", Vector3.new(DOOR_WIDTH - 2, 0.05, half), at(0, floorTop + 0.03, -half / 2), floorColor:Lerp(Color3.new(0, 0, 0), 0.25))

	-- A workbench and some crates in the front-left corner.
	newPart(decor, "Workbench", Vector3.new(7, 2.6, 3), at(-14.5, floorTop + 1.3, -16.5), WOOD, Enum.Material.WoodPlanks)
	newPart(decor, "WorkbenchTop", Vector3.new(7.6, 0.4, 3.6), at(-14.5, floorTop + 2.8, -16.5), STEEL, Enum.Material.Metal)
	newPart(decor, "Crate", Vector3.new(3, 3, 3), at(-16.5, floorTop + 1.5, -11.5) * CFrame.Angles(0, 0.25, 0), WOOD, Enum.Material.WoodPlanks)

	-- Door: a red force field that shows while the base is locked. It never
	-- collides - BaseService throws intruders out instead, so the owner can
	-- always walk through their own door.
	local door = newPart(base, "Door", Vector3.new(DOOR_WIDTH, WALL_HEIGHT, 0.6), at(0, WALL_HEIGHT / 2, -half + 0.5), Color3.fromRGB(255, 40, 40), Enum.Material.ForceField)
	door.Transparency = 1
	door.CanCollide = false

	-- Zone: the invisible box that counts as "inside this base".
	-- Its bottom is at ground level (guards use that as their floor height).
	newMarker(base, "Zone", Vector3.new(BASE_SIZE - 2, 24, BASE_SIZE - 2), at(0, 12, 0))

	-- Entrance: where intruders get dropped when they are thrown out.
	newMarker(base, "Entrance", Vector3.new(2, 2, 2), at(0, 4, -half - 10))

	-- Spawn: where the owner appears. It must be a SpawnLocation.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Size = Vector3.new(6, 0.4, 6)
	spawnPad.CFrame = at(0, floorTop + 0.2, -4)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Color = color
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = base

	-- Build pads along the back wall. Robots face the door.
	local pads = newFolder(base, "Pads")
	for i = 1, 3 do
		local padX = (i - 2) * 11
		newPart(pads, "Pad" .. i, Vector3.new(6, 1, 6), at(padX, floorTop + 0.5, half - 8), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
		newGhost(decor, "PadRing", Vector3.new(7.4, 0.12, 7.4), at(padX, floorTop + 0.06, half - 8), color, Enum.Material.Neon)
	end

	-- Lock button: a glowing red button on a pedestal just inside the door.
	newPart(decor, "LockPedestal", Vector3.new(2, 2.6, 2), at(half - 5, floorTop + 1.3, -half + 5), DARK_STEEL, Enum.Material.Metal)
	newPart(base, "LockButton", Vector3.new(1.6, 0.6, 1.6), at(half - 5, floorTop + 2.9, -half + 5), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)

	-- Sign above the door that shows the owner's name.
	local sign = newPart(base, "Sign", Vector3.new(DOOR_WIDTH + 8, 3.4, 0.8), at(0, WALL_HEIGHT + 2.3, -half + 0.5), BLACK)
	addText(sign, Enum.NormalId.Front, "Empty Base", Color3.new(1, 1, 1))

	base.Parent = folder
end

-- Scenery ---------------------------------------------------------------------------------

local function buildTree(parent, position, scale)
	local trunkHeight = 8 * scale
	newCylinder(parent, "Trunk", 2.4 * scale, trunkHeight, CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)), Color3.fromRGB(105, 75, 50), Enum.Material.Wood)
	local leafColor = Color3.fromRGB(60, 140, 70)
	local big = newPart(parent, "Leaves", Vector3.one * 10 * scale, CFrame.new(position + Vector3.new(0, trunkHeight + 3 * scale, 0)), leafColor, Enum.Material.Grass)
	big.Shape = Enum.PartType.Ball
	local small = newPart(parent, "Leaves", Vector3.one * 7 * scale, CFrame.new(position + Vector3.new(2 * scale, trunkHeight + 7 * scale, 1 * scale)), leafColor:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Grass)
	small.Shape = Enum.PartType.Ball
end

local function buildScenery(map)
	local scenery = newFolder(map, "Decor")

	-- Grass. Its top is just above the default Baseplate, so it does not
	-- matter whether you keep or delete the Baseplate.
	newPart(scenery, "Ground", Vector3.new(MAP_HALF_X * 2 + 10, 1, MAP_HALF_Z * 2 + 10), CFrame.new(0, GROUND_TOP - 0.5, 0), Color3.fromRGB(86, 140, 84), Enum.Material.Grass)

	-- Outer wall so nobody wanders off the map.
	for _, side in ipairs({ 1, -1 }) do
		newPart(scenery, "OuterWall", Vector3.new(MAP_HALF_X * 2 + 2, 10, 2), CFrame.new(0, 5, side * MAP_HALF_Z), DARK_STEEL, Enum.Material.Concrete)
		newPart(scenery, "OuterWall", Vector3.new(2, 10, MAP_HALF_Z * 2 + 2), CFrame.new(side * MAP_HALF_X, 5, 0), DARK_STEEL, Enum.Material.Concrete)
	end

	-- A path from every base door to the plaza.
	for _, side in ipairs({ 1, -1 }) do
		for column = 1, 4 do
			local x = (column - 2.5) * BASE_SPACING
			newPart(scenery, "Path", Vector3.new(12, 0.2, 30), CFrame.new(x, GROUND_TOP + 0.1, side * 36), Color3.fromRGB(190, 180, 160), Enum.Material.Cobblestone)
		end
	end

	-- Trees behind the bases and along the short sides. A fixed seed means
	-- the "random" sizes are the same every time the map is built.
	local random = Random.new(7)
	for _, side in ipairs({ 1, -1 }) do
		for x = -120, 120, 30 do
			buildTree(scenery, Vector3.new(x + random:NextNumber(-4, 4), GROUND_TOP, side * 107), random:NextNumber(0.8, 1.25))
		end
		for _, z in ipairs({ -60, 60 }) do
			buildTree(scenery, Vector3.new(side * 124, GROUND_TOP, z + random:NextNumber(-4, 4)), random:NextNumber(0.8, 1.25))
		end
	end
end

-- A warm early-evening look so the neon and the lamps show up.
local function applyLighting()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2
	Lighting.OutdoorAmbient = Color3.fromRGB(125, 115, 135)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Haze = 1.2
		atmosphere.Color = Color3.fromRGB(255, 214, 170)
		atmosphere.Decay = Color3.fromRGB(120, 90, 130)
		atmosphere.Parent = Lighting
	end
end

-- Public functions --------------------------------------------------------------------------

-- Builds the map, unless Workspace already has a "Map".
function MapBuilder.Build()
	if Workspace:FindFirstChild("Map") then
		return -- there is already a map (yours, or one built earlier)
	end

	local map = Instance.new("Model")
	map.Name = "Map"

	buildScenery(map)
	buildFactory(map)

	-- 4 bases on each side of the belt. Bases on the far side are turned
	-- around so that every door faces the conveyor.
	local bases = newFolder(map, "Bases")
	local index = 0
	for _, side in ipairs({ 1, -1 }) do
		for column = 1, 4 do
			index += 1
			local x = (column - 2.5) * BASE_SPACING
			local cframe = CFrame.new(x, 0, side * BASE_DISTANCE)
			if side == -1 then
				cframe *= CFrame.Angles(0, math.pi, 0)
			end
			buildBase(bases, index, cframe)
		end
	end

	map.Parent = Workspace
	applyLighting()
end

-- Deletes the current map and builds a fresh one. Handy from the Command Bar
-- after you change numbers in this file. Anything you edited by hand in the
-- old map is lost!
function MapBuilder.Rebuild()
	local old = Workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	MapBuilder.Build()
end

return MapBuilder
