--[[
	MapBuilder  (ModuleScript)
	Location: ServerScriptService > Services > MapBuilder

	Builds a simple grey-box map when the game starts, so the game is playable
	before you have modelled anything: a conveyor in the middle and 8 walled
	bases around it.

	IT ONLY RUNS IF Workspace HAS NO "Map" MODEL. Once you build your own map
	(see the naming table in the README) this module does nothing.

	Tip: press Play, then in the Explorer copy Workspace > Map, press Stop and
	paste it into Workspace. Now the generated map is a normal model you can
	edit and decorate by hand.
]]

local Workspace = game:GetService("Workspace")

local MapBuilder = {}

local BASE_SIZE = 40 -- bases are 40 x 40 studs
local WALL_HEIGHT = 14
local DOOR_WIDTH = 10
local BASE_SPACING = 50 -- distance between base centres along the belt
local BASE_DISTANCE = 70 -- distance from the belt to a base centre
local BELT_LENGTH = 180

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

local function newPart(parent, name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(120, 120, 120)
	part.Anchored = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
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

local function buildFactory(map)
	local factory = Instance.new("Model")
	factory.Name = "Factory"

	local conveyor = Instance.new("Model")
	conveyor.Name = "Conveyor"
	conveyor.Parent = factory

	-- The belt runs along the X axis. Its top surface is at Y = 3.
	local belt = newPart(conveyor, "Belt", Vector3.new(BELT_LENGTH, 3, 6), CFrame.new(0, 1.5, 0), Color3.fromRGB(45, 45, 50))
	belt.Material = Enum.Material.DiamondPlate

	-- Parts appear at SpawnPoint and slide to EndPoint.
	newMarker(conveyor, "SpawnPoint", Vector3.new(1, 1, 1), CFrame.new(-BELT_LENGTH / 2 + 4, 4.6, 0))
	newMarker(conveyor, "EndPoint", Vector3.new(1, 1, 1), CFrame.new(BELT_LENGTH / 2 - 4, 4.6, 0))

	-- Decoration: a machine at each end of the belt.
	for _, x in ipairs({ -BELT_LENGTH / 2 - 5, BELT_LENGTH / 2 + 5 }) do
		newPart(factory, "Machine", Vector3.new(12, 14, 12), CFrame.new(x, 7, 0), Color3.fromRGB(70, 75, 85))
		local light = newPart(factory, "MachineLight", Vector3.new(12.2, 1, 12.2), CFrame.new(x, 11, 0), Color3.fromRGB(0, 200, 255))
		light.Material = Enum.Material.Neon
		light.CanCollide = false
	end

	factory.Parent = map
end

-- Builds one base. baseCFrame sits on the ground at the centre of the base
-- and its front (-Z, the "LookVector") points toward the conveyor.
local function buildBase(folder, index, baseCFrame)
	local color = BASE_COLORS[index]
	local half = BASE_SIZE / 2

	local base = Instance.new("Model")
	base.Name = "Base" .. index

	local function at(x, y, z)
		return baseCFrame * CFrame.new(x, y, z)
	end

	local floor = newPart(base, "Floor", Vector3.new(BASE_SIZE, 0.2, BASE_SIZE), at(0, 0.1, 0), color:Lerp(Color3.new(1, 1, 1), 0.55))
	base.PrimaryPart = floor

	-- Walls: back, left, right, and two front pieces with a door gap between.
	local wallColor = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = base
	newPart(walls, "Wall", Vector3.new(BASE_SIZE, WALL_HEIGHT, 1), at(0, WALL_HEIGHT / 2, half - 0.5), wallColor)
	newPart(walls, "Wall", Vector3.new(1, WALL_HEIGHT, BASE_SIZE), at(-half + 0.5, WALL_HEIGHT / 2, 0), wallColor)
	newPart(walls, "Wall", Vector3.new(1, WALL_HEIGHT, BASE_SIZE), at(half - 0.5, WALL_HEIGHT / 2, 0), wallColor)
	local frontWidth = (BASE_SIZE - DOOR_WIDTH) / 2
	local frontX = DOOR_WIDTH / 2 + frontWidth / 2
	newPart(walls, "Wall", Vector3.new(frontWidth, WALL_HEIGHT, 1), at(-frontX, WALL_HEIGHT / 2, -half + 0.5), wallColor)
	newPart(walls, "Wall", Vector3.new(frontWidth, WALL_HEIGHT, 1), at(frontX, WALL_HEIGHT / 2, -half + 0.5), wallColor)

	-- Door: a red force field that shows while the base is locked. It never
	-- collides - BaseService throws intruders out instead, so the owner can
	-- always walk through their own door.
	local door = newPart(base, "Door", Vector3.new(DOOR_WIDTH, WALL_HEIGHT, 0.6), at(0, WALL_HEIGHT / 2, -half + 0.5), Color3.fromRGB(255, 40, 40))
	door.Material = Enum.Material.ForceField
	door.Transparency = 1
	door.CanCollide = false

	-- Zone: the invisible box that counts as "inside this base".
	newMarker(base, "Zone", Vector3.new(BASE_SIZE - 2, 24, BASE_SIZE - 2), at(0, 12, 0))

	-- Entrance: where intruders get dropped when they are thrown out.
	newMarker(base, "Entrance", Vector3.new(2, 2, 2), at(0, 4, -half - 10))

	-- Spawn: where the owner appears. It must be a SpawnLocation.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "Spawn"
	spawnPad.Size = Vector3.new(6, 0.4, 6)
	spawnPad.CFrame = at(0, 0.4, -4)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Color = color
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = base

	-- Build pads along the back wall. Robots face the door.
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = base
	for i = 1, 3 do
		local pad = newPart(pads, "Pad" .. i, Vector3.new(6, 1, 6), at((i - 2) * 11, 0.5, half - 8), Color3.fromRGB(60, 60, 60))
		pad.Material = Enum.Material.Metal
	end

	-- Lock button: a red block just inside the door.
	local lockButton = newPart(base, "LockButton", Vector3.new(2, 3, 2), at(half - 5, 1.5, -half + 5), Color3.fromRGB(255, 60, 60))
	lockButton.Material = Enum.Material.Neon

	-- Sign above the door that shows the owner's name.
	local sign = newPart(base, "Sign", Vector3.new(DOOR_WIDTH + 6, 3, 0.6), at(0, WALL_HEIGHT + 1.5, -half + 0.5), Color3.fromRGB(25, 25, 30))
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Face = Enum.NormalId.Front
	surfaceGui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "Empty Base"
	label.Parent = surfaceGui

	base.Parent = folder
end

function MapBuilder.Build()
	if Workspace:FindFirstChild("Map") then
		return -- you built your own map, leave it alone
	end

	local map = Instance.new("Model")
	map.Name = "Map"

	-- Only make a ground if the default Baseplate has been deleted.
	if not Workspace:FindFirstChild("Baseplate") then
		local ground = newPart(map, "Ground", Vector3.new(500, 4, 400), CFrame.new(0, -2, 0), Color3.fromRGB(90, 130, 90))
		ground.Material = Enum.Material.Grass
	end

	buildFactory(map)

	local bases = Instance.new("Folder")
	bases.Name = "Bases"
	bases.Parent = map

	-- 4 bases on each side of the belt. Bases on the far side are turned
	-- around so that every door faces the conveyor.
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
end

return MapBuilder
