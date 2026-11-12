-- Builds the static pitch and goal from ShotConfig so the visuals always match the
-- dimensions the server uses for outcomes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))

local Goal = ShotConfig.Goal
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- cylinder parts are long along X

local SceneBuilder = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function line(name: string, size: Vector3, position: Vector3, parent: Instance)
	makePart({
		Name = name,
		Size = size,
		CFrame = CFrame.new(position),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
end

function SceneBuilder.build(): Folder
	local old = workspace:FindFirstChild("FootballScene")
	if old then
		old:Destroy()
	end

	local scene = Instance.new("Folder")
	scene.Name = "FootballScene"

	makePart({
		Name = "Pitch",
		Size = Vector3.new(160, 1, 160),
		CFrame = CFrame.new(0, -0.5, 50),
		Color = Color3.fromRGB(30, 98, 46),
		Material = Enum.Material.Grass,
		Parent = scene,
	})

	local markings = Instance.new("Folder")
	markings.Name = "Markings"
	markings.Parent = scene
	local boxWidth, boxDepth = Goal.Width + 24, 18
	line("GoalLine", Vector3.new(160, 0.05, 0.4), Vector3.new(0, 0.03, 0), markings)
	line("BoxFront", Vector3.new(boxWidth, 0.05, 0.4), Vector3.new(0, 0.03, boxDepth), markings)
	line("BoxLeft", Vector3.new(0.4, 0.05, boxDepth), Vector3.new(-boxWidth / 2, 0.03, boxDepth / 2), markings)
	line("BoxRight", Vector3.new(0.4, 0.05, boxDepth), Vector3.new(boxWidth / 2, 0.03, boxDepth / 2), markings)
	makePart({
		Name = "BallSpot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 1.2, 1.2),
		CFrame = CFrame.new(0, 0.03, ShotConfig.ShotDistance) * VERTICAL,
		Color = Color3.new(1, 1, 1),
		CanCollide = false,
		CastShadow = false,
		Parent = markings,
	})

	local goal = Instance.new("Model")
	goal.Name = "Goal"
	local postX = Goal.Width / 2 + Goal.PostRadius
	local postLength = Goal.Height + 2 * Goal.PostRadius
	local diameter = 2 * Goal.PostRadius
	for _, side in { -1, 1 } do
		makePart({
			Name = if side < 0 then "LeftPost" else "RightPost",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(postLength, diameter, diameter),
			CFrame = CFrame.new(side * postX, postLength / 2, 0) * VERTICAL,
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Parent = goal,
		})
	end
	makePart({
		Name = "Crossbar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(Goal.Width + 4 * Goal.PostRadius, diameter, diameter),
		CFrame = CFrame.new(0, Goal.Height + Goal.PostRadius, 0),
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		Parent = goal,
	})

	local netProps = {
		Color = Color3.fromRGB(235, 235, 235),
		Material = Enum.Material.SmoothPlastic,
		Transparency = 0.8,
		CanCollide = false,
		CastShadow = false,
	}
	local function net(name: string, size: Vector3, position: Vector3)
		local props = table.clone(netProps)
		props.Name = name
		props.Size = size
		props.CFrame = CFrame.new(position)
		props.Parent = goal
		makePart(props)
	end
	net("NetBack", Vector3.new(Goal.Width, Goal.Height, 0.1), Vector3.new(0, Goal.Height / 2, -Goal.NetDepth))
	net("NetLeft", Vector3.new(0.1, Goal.Height, Goal.NetDepth), Vector3.new(-Goal.Width / 2, Goal.Height / 2, -Goal.NetDepth / 2))
	net("NetRight", Vector3.new(0.1, Goal.Height, Goal.NetDepth), Vector3.new(Goal.Width / 2, Goal.Height / 2, -Goal.NetDepth / 2))
	net("NetTop", Vector3.new(Goal.Width, 0.1, Goal.NetDepth), Vector3.new(0, Goal.Height, -Goal.NetDepth / 2))
	goal.Parent = scene

	scene.Parent = workspace
	return scene
end

return SceneBuilder
