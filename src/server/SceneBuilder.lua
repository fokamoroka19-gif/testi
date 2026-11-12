-- Builds the training ground at runtime: pitch, markings, goal with net, back wall with
-- boards, the goalkeeper and lighting. Goal dimensions come from ShotConfig so the visuals
-- always match the geometry the server uses for outcomes.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))

local Goal = ShotConfig.Goal
local Keeper = ShotConfig.Goalkeeper
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- cylinder parts are long along X

local WHITE = Color3.new(1, 1, 1)
local LIME = Color3.fromRGB(163, 230, 53)
local WALL = Color3.fromRGB(10, 22, 18)
local BOARD = Color3.fromRGB(16, 34, 29)
local GRASS_A = Color3.fromRGB(46, 101, 54)
local GRASS_B = Color3.fromRGB(41, 92, 49)
local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local PITCH_HALF_WIDTH = 120
local PITCH_BACK, PITCH_FRONT = -16, 130
local STRIPE_DEPTH = 9
local WALL_Z, WALL_HEIGHT = -16, 7

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

local function create(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

local function folder(name: string, parent: Instance): Folder
	return create("Folder", { Name = name, Parent = parent })
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
		Size = Vector3.new(600, 1, 600),
		CFrame = CFrame.new(0, -0.6, 60),
		Color = Color3.fromRGB(36, 80, 43),
		Material = Enum.Material.Grass,
		Parent = pitch,
	})
	local stripes = math.ceil((PITCH_FRONT - PITCH_BACK) / STRIPE_DEPTH)
	for i = 0, stripes - 1 do
		makePart({
			Name = "Stripe",
			Size = Vector3.new(PITCH_HALF_WIDTH * 2, 1, STRIPE_DEPTH),
			CFrame = CFrame.new(0, -0.5, PITCH_BACK + STRIPE_DEPTH * (i + 0.5)),
			Color = if i % 2 == 0 then GRASS_A else GRASS_B,
			Material = Enum.Material.Grass,
			Parent = pitch,
		})
	end

	-- Real-world scale (goal width 7.32 m = 24 studs), so the ball sits on the penalty spot.
	local lines = folder("Markings", scene)
	local width = 0.45
	local function line(x1: number, z1: number, x2: number, z2: number)
		makePart({
			Name = "Line",
			Size = Vector3.new(math.abs(x2 - x1) + width, 0.06, math.abs(z2 - z1) + width),
			CFrame = CFrame.new((x1 + x2) / 2, 0, (z1 + z2) / 2),
			Color = WHITE,
			CastShadow = false,
			Parent = lines,
		})
	end
	line(-PITCH_HALF_WIDTH, 0, PITCH_HALF_WIDTH, 0)
	for _, box in { { 30, 18 }, { 66, 54 } } do -- six-yard box, penalty box
		local halfWidth, depth = box[1], box[2]
		line(-halfWidth, 0, -halfWidth, depth)
		line(halfWidth, 0, halfWidth, depth)
		line(-halfWidth, depth, halfWidth, depth)
	end

	-- Lime ring around the ball spot, drawn as a crisp SurfaceGui circle.
	local spot = makePart({
		Name = "BallSpotRing",
		Size = Vector3.new(4, 0.05, 4),
		CFrame = CFrame.new(0, 0.04, ShotConfig.ShotDistance),
		Transparency = 1,
		CastShadow = false,
		Parent = lines,
	})
	local gui = create("SurfaceGui", {
		Face = Enum.NormalId.Top,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
		Brightness = 1.5,
		Parent = spot,
	})
	local ring = create("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundColor3 = LIME,
		BackgroundTransparency = 0.85,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	create("UIStroke", { Color = LIME, Thickness = 6, Parent = ring })
end

-- Transparent panel with a 1-stud grid of lines drawn on one face. SurfaceGui lines are
-- filtered like a texture, so they stay crisp at distance instead of flickering like thin parts.
local function netPanel(parent: Instance, name: string, size: Vector3, cframe: CFrame, face: Enum.NormalId, u: number, v: number)
	local part = makePart({ Name = name, Size = size, CFrame = cframe, Transparency = 1, CastShadow = false, Parent = parent })
	local gui = create("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 32,
		LightInfluence = 0.4,
		Parent = part,
	})
	create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = gui })
	local cellsU, cellsV = math.max(1, math.round(u)), math.max(1, math.round(v))
	for i = 0, cellsU do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(i / cellsU, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	for j = 0, cellsV do
		create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, j / cellsV),
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	return part
end

local function buildGoal(scene: Instance)
	local goal = Instance.new("Model")
	goal.Name = "Goal"

	local W, H, D = Goal.Width, Goal.Height, Goal.NetDepth
	local hw = W / 2
	local postX = hw + Goal.PostRadius
	local postLength = H + 2 * Goal.PostRadius
	local diameter = 2 * Goal.PostRadius
	for _, side in { -1, 1 } do
		makePart({
			Name = if side < 0 then "LeftPost" else "RightPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(postLength, diameter, diameter),
			CFrame = CFrame.new(side * postX, postLength / 2, 0) * VERTICAL,
			Color = WHITE,
			Reflectance = 0.05,
			Parent = goal,
		})
	end
	makePart({
		Name = "Crossbar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(W + 4 * Goal.PostRadius, diameter, diameter),
		CFrame = CFrame.new(0, H + Goal.PostRadius, 0),
		Color = WHITE,
		Reflectance = 0.05,
		Parent = goal,
	})

	-- Thin support frame at the back of the net.
	local support = Color3.fromRGB(215, 220, 218)
	local function rod(from: Vector3, to: Vector3)
		local delta = to - from
		makePart({
			Name = "Support",
			Size = Vector3.new(math.abs(delta.X) + 0.18, math.abs(delta.Y) + 0.18, math.abs(delta.Z) + 0.18),
			CFrame = CFrame.new((from + to) / 2),
			Color = support,
			Parent = goal,
		})
	end
	rod(Vector3.new(-hw, 0, -D), Vector3.new(-hw, H, -D))
	rod(Vector3.new(hw, 0, -D), Vector3.new(hw, H, -D))
	rod(Vector3.new(-hw, H, -D), Vector3.new(hw, H, -D))
	rod(Vector3.new(-hw, H, 0), Vector3.new(-hw, H, -D))
	rod(Vector3.new(hw, H, 0), Vector3.new(hw, H, -D))

	local net = folder("Net", goal)
	-- Faces point into the goal, towards the camera.
	netPanel(net, "NetBack", Vector3.new(W, H, 0.05), CFrame.new(0, H / 2, -D), Enum.NormalId.Back, W, H)
	netPanel(net, "NetLeft", Vector3.new(0.05, H, D), CFrame.new(-hw, H / 2, -D / 2), Enum.NormalId.Right, D, H)
	netPanel(net, "NetRight", Vector3.new(0.05, H, D), CFrame.new(hw, H / 2, -D / 2), Enum.NormalId.Left, D, H)
	netPanel(net, "NetTop", Vector3.new(W, 0.05, D), CFrame.new(0, H, -D / 2), Enum.NormalId.Bottom, W, D)

	goal.Parent = scene
end

local function buildWall(scene: Instance)
	local wall = folder("Wall", scene)
	local length = PITCH_HALF_WIDTH * 2
	makePart({
		Name = "Wall",
		Size = Vector3.new(length, WALL_HEIGHT, 1),
		CFrame = CFrame.new(0, WALL_HEIGHT / 2, WALL_Z - 0.5),
		Color = WALL,
		Parent = wall,
	})
	makePart({
		Name = "TopStrip",
		Size = Vector3.new(length, 0.22, 1.1),
		CFrame = CFrame.new(0, WALL_HEIGHT + 0.11, WALL_Z - 0.5),
		Color = LIME,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = wall,
	})

	for _, x in { -46, -28, 28, 46 } do
		local board = makePart({
			Name = "Board",
			Size = Vector3.new(16, 3.2, 0.3),
			CFrame = CFrame.new(x, 3.2, WALL_Z + 0.2),
			Color = BOARD,
			Parent = wall,
		})
		local gui = create("SurfaceGui", {
			Face = Enum.NormalId.Back, -- faces the pitch (+Z)
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 40,
			LightInfluence = 0.3,
			Parent = board,
		})
		create("UIStroke", { Color = LIME, Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = create("Frame", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Parent = gui,
		}) })
		create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.34),
			BackgroundTransparency = 1,
			RichText = true,
			TextScaled = true,
			FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
			TextColor3 = WHITE,
			Text = '<font color="#A3E635">///  NFS</font> / TRAINING GROUND',
			Parent = gui,
		})
	end
end

local KEEPER_COLORS = {
	Head = Color3.fromRGB(234, 192, 160),
	UpperTorso = Color3.fromRGB(255, 140, 0),
	LowerTorso = Color3.fromRGB(28, 28, 32),
	LeftUpperArm = Color3.fromRGB(255, 140, 0),
	RightUpperArm = Color3.fromRGB(255, 140, 0),
	LeftLowerArm = Color3.fromRGB(255, 140, 0),
	RightLowerArm = Color3.fromRGB(255, 140, 0),
	LeftHand = LIME, -- gloves
	RightHand = LIME,
	LeftUpperLeg = Color3.fromRGB(28, 28, 32),
	RightUpperLeg = Color3.fromRGB(28, 28, 32),
	LeftLowerLeg = Color3.fromRGB(255, 140, 0),
	RightLowerLeg = Color3.fromRGB(255, 140, 0),
	LeftFoot = Color3.fromRGB(20, 20, 22),
	RightFoot = Color3.fromRGB(20, 20, 22),
}

local function makeRigKeeper(): Model
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Goalkeeper"
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy() -- otherwise it overrides the kit colours below
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local color = KEEPER_COLORS[part.Name]
			if color then
				part.Color = color
			end
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true -- anchors the whole rig; the client moves it with PivotTo
	model.PrimaryPart = root
	model:ScaleTo(Keeper.ModelScale)
	return model
end

-- Simple block figure, used only if the R15 rig can't be created.
local function makeBlockKeeper(): Model
	local model = Instance.new("Model")
	model.Name = "Goalkeeper"
	local specs = {
		{ "Torso", Vector3.new(2.2, 2.2, 1.1), Vector3.new(0, 4.2, 0), KEEPER_COLORS.UpperTorso },
		{ "Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 6, 0), KEEPER_COLORS.Head },
		{ "LeftLeg", Vector3.new(0.9, 3, 0.9), Vector3.new(-0.55, 1.5, 0), KEEPER_COLORS.LeftUpperLeg },
		{ "RightLeg", Vector3.new(0.9, 3, 0.9), Vector3.new(0.55, 1.5, 0), KEEPER_COLORS.RightUpperLeg },
		{ "LeftArm", Vector3.new(0.75, 2.4, 0.75), Vector3.new(-1.55, 4.1, 0), KEEPER_COLORS.LeftUpperArm },
		{ "RightArm", Vector3.new(0.75, 2.4, 0.75), Vector3.new(1.55, 4.1, 0), KEEPER_COLORS.RightUpperArm },
	}
	for _, spec in specs do
		local part = makePart({ Name = spec[1], Size = spec[2], CFrame = CFrame.new(spec[3]), Color = spec[4], Parent = model })
		if spec[1] == "Torso" then
			model.PrimaryPart = part
		end
	end
	return model
end

local function buildKeeper(scene: Instance)
	if not Keeper.Enabled then
		return
	end
	local ok, model = pcall(makeRigKeeper)
	if not ok then
		warn("[SceneBuilder] Could not create the R15 goalkeeper, using a simple one:", model)
		model = makeBlockKeeper()
	end
	-- Face the shooter (+Z) and stand with the feet on the ground.
	local facing = CFrame.Angles(0, math.pi, 0)
	model:PivotTo(facing)
	local box, size = model:GetBoundingBox()
	local lift = -(box.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(Keeper.HomeX, lift, Keeper.HomeZ) * facing)
	model.Parent = scene
end

local function ensureChild(parent: Instance, className: string, name: string): any
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	return create(className, { Name = name, Parent = parent })
end

local function setupLighting()
	Lighting.ClockTime = 13.8
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 80, 75)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 160, 155)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25

	local atmosphere = ensureChild(Lighting, "Atmosphere", "Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(198, 222, 236)
	atmosphere.Decay = Color3.fromRGB(120, 140, 155)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.6

	local bloom = ensureChild(Lighting, "BloomEffect", "Bloom")
	bloom.Intensity = 0.6
	bloom.Size = 22
	bloom.Threshold = 1.4

	local grading = ensureChild(Lighting, "ColorCorrectionEffect", "ColorCorrection")
	grading.Saturation = 0.12
	grading.Contrast = 0.1
	grading.Brightness = 0
	grading.TintColor = Color3.fromRGB(255, 252, 245)

	local rays = ensureChild(Lighting, "SunRaysEffect", "SunRays")
	rays.Intensity = 0.02
	rays.Spread = 0.5
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
	buildWall(scene)
	buildKeeper(scene)
	scene.Parent = workspace

	setupLighting()
	print(string.format("[SceneBuilder] Training ground built (%d objects)", #scene:GetDescendants()))
	return scene
end

return SceneBuilder
