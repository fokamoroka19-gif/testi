-- Builds the stadium at runtime: pitch, markings, goal with net, ad boards, a stand with a
-- crowd, and lighting. Goal dimensions come from ShotConfig so the visuals always match the
-- geometry the server uses for outcomes.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))

local Goal = ShotConfig.Goal
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- cylinder parts are long along X

local WHITE = Color3.new(1, 1, 1)
local LIME = Color3.fromRGB(163, 230, 53)
local DARK = Color3.fromRGB(14, 20, 16)
local GRASS_LIGHT = Color3.fromRGB(64, 138, 56)
local GRASS_DARK = Color3.fromRGB(52, 118, 47)

local PITCH_HALF_WIDTH = 70
local PITCH_BACK, PITCH_FRONT = -14, 114 -- grass behind the goal line / far end
local STRIPE_DEPTH = 8
local BOARD_Z = -17
local STAND_FRONT_Z = -22
local STAND_HALF_WIDTH = 85
local TIERS, TIER_DEPTH, TIER_RISE = 9, 3.2, 1.8

local BOARD_TEXTS = {
	"NEW FOOTBALL STAR", "NEWFORD FC", "EASTBRIDGE UNITED", "REDMONT ATHLETIC",
	"WESTPORT CITY", "NORTHVALE FC", "RIVERSIDE ROVERS", "SOUTHGATE FC",
}

local CROWD_COLORS = {
	LIME, LIME, LIME, WHITE, WHITE, WHITE,
	Color3.fromRGB(30, 90, 50), Color3.fromRGB(30, 90, 50),
	Color3.fromRGB(40, 40, 44), Color3.fromRGB(200, 55, 55),
	Color3.fromRGB(45, 95, 200), Color3.fromRGB(245, 200, 40),
}

local SceneBuilder = {}

-- Decorative, anchored, no collisions: nothing in Stage 1 relies on Roblox physics.
local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Axis-aligned bar between two points (used for pitch lines and net strings).
local function bar(parent: Instance, from: Vector3, to: Vector3, thickness: number, props: { [string]: any }?)
	local delta = to - from
	local size = Vector3.new(
		math.abs(delta.X) + thickness,
		math.abs(delta.Y) + thickness,
		math.abs(delta.Z) + thickness
	)
	local p = { Size = size, CFrame = CFrame.new((from + to) / 2), Color = WHITE, Parent = parent }
	for key, value in props or {} do
		p[key] = value
	end
	return makePart(p)
end

-- The default "Baseplate" template has a baseplate at ground level (flickers through the
-- pitch) and a SpawnLocation in the goal mouth. Removed for this play session only.
local function clearDefaultTemplate()
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") or (child.Name == "Baseplate" and child:IsA("BasePart")) then
			child:Destroy()
		end
	end
end

local function buildPitch(scene: Instance)
	local pitch = folder("Pitch", scene)
	makePart({
		Name = "Surround",
		Size = Vector3.new(420, 1, 420),
		CFrame = CFrame.new(0, -0.55, 40),
		Color = Color3.fromRGB(40, 78, 42),
		Material = Enum.Material.Grass,
		Parent = pitch,
	})
	local stripes = math.ceil((PITCH_FRONT - PITCH_BACK) / STRIPE_DEPTH)
	for i = 0, stripes - 1 do
		makePart({
			Name = "Stripe",
			Size = Vector3.new(PITCH_HALF_WIDTH * 2, 1, STRIPE_DEPTH),
			CFrame = CFrame.new(0, -0.5, PITCH_BACK + STRIPE_DEPTH * (i + 0.5)),
			Color = if i % 2 == 0 then GRASS_LIGHT else GRASS_DARK,
			Material = Enum.Material.Grass,
			Parent = pitch,
		})
	end

	-- Markings at real-world scale (goal width 7.32 m = 24 studs, so the ball sits on the penalty spot).
	local lines = folder("Markings", scene)
	local y, w = 0, 0.4
	local function line(x1: number, z1: number, x2: number, z2: number)
		bar(lines, Vector3.new(x1, y, z1), Vector3.new(x2, y, z2), w, { Size = Vector3.new(math.abs(x2 - x1) + w, 0.06, math.abs(z2 - z1) + w) })
	end
	line(-PITCH_HALF_WIDTH, 0, PITCH_HALF_WIDTH, 0) -- goal line
	line(-PITCH_HALF_WIDTH, 0, -PITCH_HALF_WIDTH, PITCH_FRONT) -- touchlines
	line(PITCH_HALF_WIDTH, 0, PITCH_HALF_WIDTH, PITCH_FRONT)
	for _, box in { { 30, 18 }, { 66, 54 } } do -- six-yard box, penalty box
		local halfWidth, depth = box[1], box[2]
		line(-halfWidth, 0, -halfWidth, depth)
		line(halfWidth, 0, halfWidth, depth)
		line(-halfWidth, depth, halfWidth, depth)
	end
	makePart({
		Name = "PenaltySpot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 1.2, 1.2),
		CFrame = CFrame.new(0, 0, ShotConfig.ShotDistance) * VERTICAL,
		Color = WHITE,
		Parent = lines,
	})
end

local function buildGoal(scene: Instance)
	local goal = Instance.new("Model")
	goal.Name = "Goal"

	local W, H, D = Goal.Width, Goal.Height, Goal.NetDepth
	local postX = W / 2 + Goal.PostRadius
	local postLength = H + 2 * Goal.PostRadius
	local diameter = 2 * Goal.PostRadius
	for _, side in { -1, 1 } do
		makePart({
			Name = if side < 0 then "LeftPost" else "RightPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(postLength, diameter, diameter),
			CFrame = CFrame.new(side * postX, postLength / 2, 0) * VERTICAL,
			Color = WHITE,
			Reflectance = 0.08,
			Parent = goal,
		})
	end
	makePart({
		Name = "Crossbar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(W + 4 * Goal.PostRadius, diameter, diameter),
		CFrame = CFrame.new(0, H + Goal.PostRadius, 0),
		Color = WHITE,
		Reflectance = 0.08,
		Parent = goal,
	})

	-- Back frame of the net box.
	local support = { Color = Color3.fromRGB(205, 205, 210) }
	local hw = W / 2
	bar(goal, Vector3.new(-hw, 0, -D), Vector3.new(-hw, H, -D), 0.25, support)
	bar(goal, Vector3.new(hw, 0, -D), Vector3.new(hw, H, -D), 0.25, support)
	bar(goal, Vector3.new(-hw, H, -D), Vector3.new(hw, H, -D), 0.25, support)
	bar(goal, Vector3.new(-hw, 0.1, -D), Vector3.new(hw, 0.1, -D), 0.25, support)
	for _, x in { -hw, hw } do
		bar(goal, Vector3.new(x, H, 0), Vector3.new(x, H, -D), 0.2, support)
		bar(goal, Vector3.new(x, 0.1, 0), Vector3.new(x, 0.1, -D), 0.2, support)
	end

	-- Net mesh: a 1-stud grid of thin strings on the back, sides and roof.
	local net = folder("Net", goal)
	local netString = { Transparency = 0.25, CastShadow = false, Color = Color3.fromRGB(240, 240, 240) }
	local t = 0.06
	for x = -hw, hw do
		bar(net, Vector3.new(x, 0, -D), Vector3.new(x, H, -D), t, netString)
		bar(net, Vector3.new(x, H, 0), Vector3.new(x, H, -D), t, netString)
	end
	for yy = 0, H do
		bar(net, Vector3.new(-hw, yy, -D), Vector3.new(hw, yy, -D), t, netString)
		bar(net, Vector3.new(-hw, yy, 0), Vector3.new(-hw, yy, -D), t, netString)
		bar(net, Vector3.new(hw, yy, 0), Vector3.new(hw, yy, -D), t, netString)
	end
	for z = 0, D do
		bar(net, Vector3.new(-hw, 0, -z), Vector3.new(-hw, H, -z), t, netString)
		bar(net, Vector3.new(hw, 0, -z), Vector3.new(hw, H, -z), t, netString)
		bar(net, Vector3.new(-hw, H, -z), Vector3.new(hw, H, -z), t, netString)
	end

	goal.Parent = scene
end

local function buildBoards(scene: Instance)
	local boards = folder("AdBoards", scene)
	local count = #BOARD_TEXTS
	local width = STAND_HALF_WIDTH * 2 / count
	for i, text in BOARD_TEXTS do
		local isLime = i % 2 == 0
		local board = makePart({
			Name = "Board",
			Size = Vector3.new(width - 0.3, 3, 0.5),
			CFrame = CFrame.new(-STAND_HALF_WIDTH + width * (i - 0.5), 1.5, BOARD_Z),
			Color = if isLime then LIME else DARK,
			Parent = boards,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- faces the pitch (+Z)
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.2
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = if isLime then DARK else LIME
		label.Parent = gui
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0.18, 0)
		padding.PaddingBottom = UDim.new(0.18, 0)
		padding.PaddingLeft = UDim.new(0.05, 0)
		padding.PaddingRight = UDim.new(0.05, 0)
		padding.Parent = label
	end
end

local function buildStand(scene: Instance)
	local stand = folder("Stand", scene)
	local crowd = folder("Crowd", scene) -- the client makes these jump on a goal
	local rng = Random.new(7) -- fixed seed: same crowd every time
	local width = STAND_HALF_WIDTH * 2

	for tier = 0, TIERS - 1 do
		local front = STAND_FRONT_Z - tier * TIER_DEPTH
		local top = (tier + 1) * TIER_RISE
		makePart({
			Name = "Tier",
			Size = Vector3.new(width, top, TIER_DEPTH),
			CFrame = CFrame.new(0, top / 2, front - TIER_DEPTH / 2),
			Color = if tier % 2 == 0 then Color3.fromRGB(62, 66, 72) else Color3.fromRGB(70, 74, 80),
			Material = Enum.Material.Concrete,
			Parent = stand,
		})
		makePart({
			Name = "Seats",
			Size = Vector3.new(width, 0.7, 1),
			CFrame = CFrame.new(0, top + 0.35, front - TIER_DEPTH + 0.6),
			Color = Color3.fromRGB(24, 74, 40),
			Parent = stand,
		})
		for x = -STAND_HALF_WIDTH + 1.5, STAND_HALF_WIDTH - 1.5, 2.6 do
			if rng:NextNumber() < 0.85 then
				local height = 1.8 + rng:NextNumber() * 0.5
				makePart({
					Name = "Fan",
					Size = Vector3.new(1.3, height, 0.9),
					CFrame = CFrame.new(x + rng:NextNumber(-0.4, 0.4), top + height / 2, front - TIER_DEPTH * 0.5),
					Color = CROWD_COLORS[rng:NextInteger(1, #CROWD_COLORS)],
					Parent = crowd,
				})
			end
		end
	end

	local back = STAND_FRONT_Z - TIERS * TIER_DEPTH
	local roofY = TIERS * TIER_RISE + 8
	makePart({
		Name = "BackWall",
		Size = Vector3.new(width, roofY, 1),
		CFrame = CFrame.new(0, roofY / 2, back - 0.5),
		Color = Color3.fromRGB(34, 38, 44),
		Material = Enum.Material.Concrete,
		Parent = stand,
	})
	local roofDepth = (STAND_FRONT_Z - 4) - back
	makePart({
		Name = "Roof",
		Size = Vector3.new(width + 4, 1, math.abs(roofDepth)),
		CFrame = CFrame.new(0, roofY, (back + STAND_FRONT_Z - 4) / 2),
		Color = Color3.fromRGB(24, 27, 32),
		Material = Enum.Material.Metal,
		Parent = stand,
	})
	makePart({
		Name = "RoofLight",
		Size = Vector3.new(width + 4, 0.5, 0.4),
		CFrame = CFrame.new(0, roofY - 0.5, STAND_FRONT_Z - 4),
		Color = LIME,
		Material = Enum.Material.Neon,
		Parent = stand,
	})
	for _, x in { -STAND_HALF_WIDTH, -STAND_HALF_WIDTH / 3, STAND_HALF_WIDTH / 3, STAND_HALF_WIDTH } do
		makePart({
			Name = "Column",
			Size = Vector3.new(1, roofY, 1),
			CFrame = CFrame.new(x, roofY / 2, STAND_FRONT_Z - 4),
			Color = Color3.fromRGB(34, 38, 44),
			Material = Enum.Material.Metal,
			Parent = stand,
		})
	end
end

local function ensureChild(parent: Instance, className: string, name: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function setupLighting()
	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 145, 140)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = ensureChild(Lighting, "Atmosphere", "Atmosphere")
	atmosphere.Density = 0.25
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(199, 220, 235)
	atmosphere.Decay = Color3.fromRGB(110, 120, 135)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1

	local bloom = ensureChild(Lighting, "BloomEffect", "Bloom")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.5

	local grading = ensureChild(Lighting, "ColorCorrectionEffect", "ColorCorrection")
	grading.Saturation = 0.12
	grading.Contrast = 0.06
	grading.Brightness = 0.02

	local rays = ensureChild(Lighting, "SunRaysEffect", "SunRays")
	rays.Intensity = 0.04
	rays.Spread = 0.6
end

function SceneBuilder.build(): Folder
	local old = workspace:FindFirstChild("FootballScene")
	if old then
		old:Destroy()
	end
	clearDefaultTemplate()

	local scene = Instance.new("Folder")
	scene.Name = "FootballScene"
	buildPitch(scene)
	buildGoal(scene)
	buildBoards(scene)
	buildStand(scene)
	scene.Parent = workspace

	setupLighting()
	print(string.format("[SceneBuilder] Stadium built (%d parts)", #scene:GetDescendants()))
	return scene
end

return SceneBuilder
