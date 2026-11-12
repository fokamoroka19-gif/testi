-- Client-only 3D visuals: camera, ball, goalkeeper animation, aim crosshair, trajectory
-- preview and goal effects. Everything here is local to this player and has no effect on the outcome.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local ShotPhysics = require(Shared:WaitForChild("ShotPhysics"))

local Keeper = ShotConfig.Goalkeeper
local BALL_RADIUS = ShotConfig.Ball.Radius
local PREVIEW_DOTS = 14
local FOLLOW_THROUGH_SECONDS = 1.6
local KEEPER_MIN_Y = 1.2
local KEEPER_MAX_TILT = math.rad(95)
local ARMS_READY = math.rad(38)
local ARMS_DIVE = math.rad(165)
local BALL_SPIN_RATE = 14 -- radians per second in flight

local WHITE = Color3.new(1, 1, 1)
local LIME = Color3.fromRGB(163, 230, 53)
local YELLOW = Color3.fromRGB(250, 204, 21)

local ShotVisuals = {}
ShotVisuals.__index = ShotVisuals

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

local function makePart(props: { [string]: any }): Part
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return create("Part", props)
end

local function icosahedronDirections(): { Vector3 }
	local phi = (1 + math.sqrt(5)) / 2
	local dirs = {}
	for _, a in { -1, 1 } do
		for _, b in { -phi, phi } do
			table.insert(dirs, Vector3.new(0, a, b).Unit)
			table.insert(dirs, Vector3.new(a, b, 0).Unit)
			table.insert(dirs, Vector3.new(b, 0, a).Unit)
		end
	end
	return dirs
end

function ShotVisuals.new()
	local self = setmetatable({}, ShotVisuals)
	self.token = 0
	self.clock = 0
	self.shake = 0
	self.fovKick = 0
	self.idle = true

	local folder = create("Folder", { Name = "ShotVisuals", Parent = workspace })

	-- Ball: white sphere with 12 flat dark panels.
	local ballModel = create("Model", { Name = "Ball", Parent = folder })
	self.ballParts = {
		{ makePart({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * BALL_RADIUS * 2, Color = WHITE, Parent = ballModel }), CFrame.identity },
	}
	for _, dir in icosahedronDirections() do
		local reference = if math.abs(dir.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		local up = dir:Cross(reference).Unit
		local patch = makePart({
			Name = "Panel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, BALL_RADIUS * 0.66, BALL_RADIUS * 0.66),
			Color = Color3.fromRGB(22, 22, 26),
			CastShadow = false,
			Parent = ballModel,
		})
		table.insert(self.ballParts, { patch, CFrame.fromMatrix(dir * BALL_RADIUS * 0.985, dir, up) })
	end

	-- Crosshair on the goal plane, the size of the ball, drawn on top of everything.
	local aimPart = makePart({ Name = "Crosshair", Size = Vector3.new(3, 3, 0.05), Transparency = 1, CastShadow = false, Parent = folder })
	local aimGui = create("SurfaceGui", {
		Face = Enum.NormalId.Back,
		AlwaysOnTop = true,
		LightInfluence = 0,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 60,
		Enabled = false,
		Parent = aimPart,
	})
	local ring = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(2 * BALL_RADIUS / 3, 2 * BALL_RADIUS / 3),
		BackgroundColor3 = LIME,
		BackgroundTransparency = 0.82,
		Parent = aimGui,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
	create("UIStroke", { Color = LIME, Thickness = 6, Parent = ring })
	local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, Parent = aimGui })
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	for _, tick in { { 0.5, 0.06, 6, 22 }, { 0.5, 0.94, 6, 22 }, { 0.06, 0.5, 22, 6 }, { 0.94, 0.5, 22, 6 } } do
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(tick[1], tick[2]),
			Size = UDim2.fromOffset(tick[3], tick[4]),
			BackgroundColor3 = LIME,
			BorderSizePixel = 0,
			Parent = aimGui,
		})
	end
	self.aimPart, self.aimGui = aimPart, aimGui

	self.dots = {}
	for i = 1, PREVIEW_DOTS do
		self.dots[i] = makePart({
			Name = "PreviewDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.42 - 0.22 * i / PREVIEW_DOTS),
			Color = LIME,
			Material = Enum.Material.Neon,
			CastShadow = false,
			Transparency = 1,
			Parent = folder,
		})
	end

	local emitterPart = makePart({
		Name = "Confetti",
		Size = Vector3.one,
		Transparency = 1,
		CFrame = CFrame.new(0, ShotConfig.Goal.Height + 1, -ShotConfig.Goal.NetDepth / 2),
		Parent = folder,
	})
	self.confetti = create("ParticleEmitter", {
		Enabled = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, LIME),
			ColorSequenceKeypoint.new(0.5, WHITE),
			ColorSequenceKeypoint.new(1, YELLOW),
		}),
		Size = NumberSequence.new(0.5, 0.15),
		Speed = NumberRange.new(25, 45),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -40, 0),
		Drag = 1.5,
		Lifetime = NumberRange.new(1.5, 2.5),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 0.6,
		Parent = emitterPart,
	})

	self:_findScene()
	self:reset()
	return self
end

function ShotVisuals:_findScene()
	local scene = workspace:WaitForChild("FootballScene", 15)
	if not scene then
		warn("[ShotVisuals] workspace.FootballScene not found; is the server Main script running?")
		return
	end

	local net = scene:FindFirstChild("NetBack", true)
	if net then
		self.netBack, self.netBackHome = net, net.CFrame
	end

	local keeper = Keeper.Enabled and scene:WaitForChild("Goalkeeper", 10)
	if keeper then
		self.keeper = keeper
		self.keeperHome = keeper:GetPivot()
		self.keeperRotation = self.keeperHome.Rotation
		self.shoulders = {}
		for _, info in { { "LeftShoulder", -1 }, { "RightShoulder", 1 } } do
			local motor = keeper:FindFirstChild(info[1], true)
			if motor and motor:IsA("Motor6D") then
				table.insert(self.shoulders, { motor, motor.C0, info[2] })
			end
		end
	end
end

function ShotVisuals:_setBall(position: Vector3, spin: number)
	local base = CFrame.new(position) * CFrame.Angles(-spin, 0, 0)
	for _, entry in self.ballParts do
		entry[1].CFrame = base * entry[2]
	end
end

-- offset: body movement from the home position; tilt: lean around the view axis; arms: shoulder angle.
function ShotVisuals:_poseKeeper(offset: Vector3, tilt: number, arms: number)
	if not self.keeper then
		return
	end
	local position = self.keeperHome.Position + offset
	self.keeper:PivotTo(CFrame.new(position) * CFrame.Angles(0, 0, tilt) * self.keeperRotation)
	for _, shoulder in self.shoulders do
		shoulder[1].C0 = shoulder[2] * CFrame.Angles(0, 0, shoulder[3] * arms)
	end
end

function ShotVisuals:_diveKeeper(target: Vector3, alpha: number)
	local eased = 1 - (1 - alpha) ^ 2
	local offset = Vector3.new(target.X - Keeper.HomeX, math.max(target.Y, KEEPER_MIN_Y) - Keeper.HomeY, 0)
	local tilt = math.clamp(math.atan2(-offset.X, offset.Y + Keeper.HomeY), -KEEPER_MAX_TILT, KEEPER_MAX_TILT)
	local lean = math.clamp(offset.Magnitude / 4, 0, 1)
	self:_poseKeeper(offset * eased, tilt * lean * eased, ARMS_READY + (ARMS_DIVE - ARMS_READY) * math.min(1, alpha * 2))
end

function ShotVisuals:reset()
	self.token += 1
	self.idle = true
	self:_setBall(ShotPhysics.ballSpot(), 0)
	self:_poseKeeper(Vector3.zero, 0, ARMS_READY)
	if self.netBack then
		self.netBack.CFrame = self.netBackHome
	end
	self:updateAiming(false, 0, 0.5, 0, false)
end

-- Per-frame: camera (with shake and kick) and the keeper's ready stance.
function ShotVisuals:update(dt: number)
	self.clock += dt
	self.shake = math.max(0, self.shake - dt * 2.5)
	self.fovKick = math.max(0, self.fovKick - dt * 10)

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = ShotConfig.Camera.FieldOfView - self.fovKick
	local base = CFrame.lookAt(ShotConfig.Camera.Position, ShotConfig.Camera.LookAt)
	if self.shake > 0 then
		local t = self.clock * 25
		local amount = self.shake * 0.3
		base *= CFrame.new(math.noise(t, 1) * amount, math.noise(t, 2) * amount, 0)
	end
	camera.CFrame = base

	if self.idle then
		local t = self.clock
		local sway = Vector3.new(math.sin(t * 2.1) * 0.45, math.abs(math.sin(t * 4.2)) * 0.1, 0)
		self:_poseKeeper(sway, 0, ARMS_READY + math.sin(t * 4.2) * 0.06)
	end
end

-- Shows the crosshair, and while holding, the predicted (no-error) arc.
function ShotVisuals:updateAiming(enabled: boolean, aimX: number, aimY: number, power: number, holding: boolean)
	local point = ShotPhysics.aimToGoalPoint(aimX, aimY)
	self.aimGui.Enabled = enabled
	self.aimPart.CFrame = CFrame.new(point + Vector3.new(0, 0, 0.25))

	local showArc = enabled and holding
	local start = ShotPhysics.ballSpot()
	local flightTime = ShotPhysics.flightTime(start, point, power)
	local velocity = ShotPhysics.launchVelocity(start, point, flightTime)
	for i, dot in self.dots do
		dot.Transparency = if showArc then 0.1 + 0.55 * i / PREVIEW_DOTS else 1
		if showArc then
			dot.CFrame = CFrame.new(ShotPhysics.positionAt(start, velocity, flightTime * i / (PREVIEW_DOTS + 1)))
		end
	end
end

function ShotVisuals:onShotReleased()
	self.fovKick = 1.8
	self:updateAiming(false, 0, 0.5, 0, false)
end

function ShotVisuals:_bulgeNet()
	local net = self.netBack
	if not net then
		return
	end
	net.CFrame = self.netBackHome * CFrame.new(0, 0, -0.9)
	TweenService:Create(net, TweenInfo.new(0.6, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = self.netBackHome }):Play()
end

-- Velocity right after the ball reaches the goal plane / keeper; purely cosmetic.
local function velocityAfterImpact(outcome: string, velocity: Vector3, target: Vector3): Vector3
	if outcome == "GOAL" then
		return velocity * 0.6
	elseif outcome == "SAVE" then
		local side = if target.X >= 0 then 1 else -1
		return Vector3.new(side * 7, 9, -velocity.Z * 0.25)
	elseif outcome == "POST" then
		if target.Y > ShotConfig.Goal.Height - BALL_RADIUS then
			return Vector3.new(velocity.X * 0.5, 10, -velocity.Z * 0.35) -- crossbar
		end
		return Vector3.new(-velocity.X * 0.4, velocity.Y * 0.3 + 3, -velocity.Z * 0.4)
	end
	return velocity
end

-- Plays the server-decided shot. Calls onImpact when the ball reaches the goal or keeper,
-- and yields until the follow-through ends or reset() is called.
function ShotVisuals:playShot(result, onImpact: () -> ())
	self.token += 1
	local token = self.token
	self.idle = false

	local start: Vector3 = result.start
	local target: Vector3 = result.target
	local flightTime: number = result.flightTime
	local velocity = ShotPhysics.launchVelocity(start, target, flightTime)

	-- The keeper stands in front of the line, so a save happens slightly before the goal plane.
	local endTime = flightTime
	if result.outcome == "SAVE" then
		endTime = flightTime * (1 - Keeper.HomeZ / (start.Z - target.Z))
	end
	local reaction: number = result.keeperReaction
	local diveDuration = math.max(endTime - reaction, 0.05)

	local t = 0
	while t < endTime do
		self:_setBall(ShotPhysics.positionAt(start, velocity, t), t * BALL_SPIN_RATE)
		self:_diveKeeper(result.keeperTarget, math.clamp((t - reaction) / diveDuration, 0, 1))
		t += RunService.RenderStepped:Wait()
		if self.token ~= token then
			return
		end
	end

	local position = ShotPhysics.positionAt(start, velocity, endTime)
	local spin = endTime * BALL_SPIN_RATE
	self:_setBall(position, spin)
	self:_diveKeeper(result.keeperTarget, 1)
	if result.outcome == "GOAL" then
		self.shake = 1
		self.confetti:Emit(150)
		self:_bulgeNet()
	else
		self.shake = 0.4
	end
	onImpact()

	-- Follow-through: gravity, ground bounces and the back of the net.
	local vel = velocityAfterImpact(result.outcome, ShotPhysics.velocityAt(velocity, endTime), target)
	local netBack = -ShotConfig.Goal.NetDepth + BALL_RADIUS
	local elapsed = 0
	while elapsed < FOLLOW_THROUGH_SECONDS do
		local dt = math.min(RunService.RenderStepped:Wait(), 1 / 20)
		if self.token ~= token then
			return
		end
		elapsed += dt
		vel += ShotPhysics.gravity() * dt
		position += vel * dt
		if position.Y < BALL_RADIUS then
			position = Vector3.new(position.X, BALL_RADIUS, position.Z)
			vel = Vector3.new(vel.X * 0.8, -vel.Y * 0.5, vel.Z * 0.8)
		end
		if result.outcome == "GOAL" and position.Z < netBack then
			position = Vector3.new(position.X, position.Y, netBack)
			vel = Vector3.new(vel.X * 0.3, vel.Y, 0)
		end
		spin += vel.Magnitude / BALL_RADIUS * dt * 0.5
		self:_setBall(position, spin)
	end
end

return ShotVisuals
