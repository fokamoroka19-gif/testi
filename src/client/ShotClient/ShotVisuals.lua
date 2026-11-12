-- Client-only visuals: camera, ball, goalkeeper, aim marker, trajectory preview, effects and HUD.
-- Everything here is local to this player and has no effect on the outcome.

local Players = game:GetService("Players")
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
local BALL_SPIN_RATE = 14 -- radians per second in flight

local WHITE = Color3.new(1, 1, 1)
local LIME = Color3.fromRGB(163, 230, 53)
local DARK = Color3.fromRGB(14, 20, 16)
local YELLOW = Color3.fromRGB(250, 204, 21)
local RED = Color3.fromRGB(239, 68, 68)

local KIT = Color3.fromRGB(255, 140, 0)
local SKIN = Color3.fromRGB(234, 192, 160)

local OUTCOME_TEXT = {
	GOAL = { "GOAL!", LIME, "What a strike!" },
	SAVE = { "SAVED!", WHITE, "The keeper got there first" },
	POST = { "OFF THE POST!", YELLOW, "So close!" },
	MISS = { "MISSED!", RED, "Keep it on target" },
}

-- Keeper figure relative to his body centre (feet on the ground at HomeY = 3.5), facing +Z.
local KEEPER_PARTS = {
	{ "LeftBoot", Vector3.new(0.9, 0.5, 1.3), CFrame.new(-0.55, -3.25, 0.15), DARK },
	{ "RightBoot", Vector3.new(0.9, 0.5, 1.3), CFrame.new(0.55, -3.25, 0.15), DARK },
	{ "LeftLeg", Vector3.new(0.85, 2.1, 0.85), CFrame.new(-0.55, -2, 0), KIT },
	{ "RightLeg", Vector3.new(0.85, 2.1, 0.85), CFrame.new(0.55, -2, 0), KIT },
	{ "Shorts", Vector3.new(2.1, 0.9, 1.15), CFrame.new(0, -0.6, 0), Color3.fromRGB(25, 25, 28) },
	{ "Torso", Vector3.new(2.2, 2, 1.1), CFrame.new(0, 0.85, 0), KIT },
	{ "LeftArm", Vector3.new(0.7, 2, 0.7), CFrame.new(-1.55, 1.1, 0) * CFrame.Angles(0, 0, math.rad(35)), KIT },
	{ "RightArm", Vector3.new(0.7, 2, 0.7), CFrame.new(1.55, 1.1, 0) * CFrame.Angles(0, 0, -math.rad(35)), KIT },
	{ "LeftGlove", Vector3.one * 0.85, CFrame.new(-2.15, 2.05, 0), LIME },
	{ "RightGlove", Vector3.one * 0.85, CFrame.new(2.15, 2.05, 0), LIME },
	{ "Head", Vector3.one * 1.25, CFrame.new(0, 2.5, 0), SKIN, Enum.PartType.Ball },
	{ "Hair", Vector3.new(1.3, 0.45, 1.3), CFrame.new(0, 3.0, -0.05), Color3.fromRGB(50, 35, 25) },
}

local ShotVisuals = {}
ShotVisuals.__index = ShotVisuals

local function create(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			inst[key] = value
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function makePart(props: { [string]: any }): Part
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return create("Part", props)
end

local function corner(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function label(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBlack
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	return create("TextLabel", props)
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
	self.state = "idle"
	self.clock = 0
	self.shake = 0
	self.fovKick = 0

	local folder = create("Folder", { Name = "ShotVisuals", Parent = workspace })
	self.folder = folder

	-- Ball: white sphere with 12 black patches, moved together.
	local ballModel = create("Model", { Name = "Ball", Parent = folder })
	self.ballParts = {
		{ makePart({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * BALL_RADIUS * 2, Color = WHITE, Parent = ballModel }), CFrame.identity },
	}
	for _, dir in icosahedronDirections() do
		local patch = makePart({
			Name = "Patch",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * BALL_RADIUS * 0.6,
			Color = Color3.fromRGB(20, 20, 22),
			CastShadow = false,
			Parent = ballModel,
		})
		table.insert(self.ballParts, { patch, CFrame.new(dir * BALL_RADIUS * 0.8) })
	end

	local keeperModel = create("Model", { Name = "Goalkeeper" })
	self.keeperParts = {}
	for _, spec in KEEPER_PARTS do
		local part = makePart({ Name = spec[1], Size = spec[2], Color = spec[4], Shape = spec[5] or Enum.PartType.Block, Parent = keeperModel })
		table.insert(self.keeperParts, { part, spec[3] })
		if spec[1] == "Torso" then
			local gui = create("SurfaceGui", { Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 50, Parent = part })
			label({ Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Text = "1", TextColor3 = DARK, Parent = gui })
		end
	end
	keeperModel.Parent = if Keeper.Enabled then folder else nil
	self.keeperHome = Vector3.new(Keeper.HomeX, Keeper.HomeY, Keeper.HomeZ)

	self.aimMarker = makePart({
		Name = "AimMarker",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, BALL_RADIUS * 2, BALL_RADIUS * 2), -- same size as the ball
		Color = LIME,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = folder,
	})
	self.aimDot = makePart({
		Name = "AimDot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 0.45, 0.45),
		Color = WHITE,
		Material = Enum.Material.Neon,
		CastShadow = false,
		Parent = folder,
	})

	self.dots = {}
	for i = 1, PREVIEW_DOTS do
		self.dots[i] = makePart({
			Name = "PreviewDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (0.45 - 0.2 * i / PREVIEW_DOTS),
			Color = LIME,
			Material = Enum.Material.Neon,
			CastShadow = false,
			Parent = folder,
		})
	end

	-- Confetti burst from the top of the net on a goal.
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
		Size = NumberSequence.new(0.6, 0.2),
		Speed = NumberRange.new(25, 45),
		SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -40, 0),
		Drag = 1.5,
		Lifetime = NumberRange.new(1.5, 2.5),
		RotSpeed = NumberRange.new(-200, 200),
		LightEmission = 0.5,
		Parent = emitterPart,
	})

	self:_buildHud()
	self:reset()
	return self
end

function ShotVisuals:_buildHud()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", {
		Name = "ShotHud",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})
	self.hudScale = create("UIScale", { Parent = gui })

	-- Scoreboard (top left)
	local board = create("Frame", {
		Name = "Scoreboard",
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(0, 220, 0, 70),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	corner(board, 12)
	create("UIStroke", { Color = LIME, Thickness = 2, Transparency = 0.2, Parent = board })
	local function stat(caption: string, x: number)
		label({ Position = UDim2.new(x, 0, 0, 8), Size = UDim2.new(0.5, 0, 0, 16), Font = Enum.Font.GothamBold, TextColor3 = LIME, Text = caption, Parent = board })
		return label({ Position = UDim2.new(x, 0, 0, 26), Size = UDim2.new(0.5, 0, 0, 36), Text = "0", Parent = board })
	end
	self.goalsValue = stat("GOALS", 0)
	self.shotsValue = stat("SHOTS", 0.5)
	create("Frame", { Position = UDim2.new(0.5, -1, 0, 12), Size = UDim2.new(0, 2, 1, -24), BackgroundColor3 = LIME, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = board })

	-- Title chip (top centre)
	local chip = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 230, 0, 34),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Parent = gui,
	})
	corner(chip, 17)
	label({ Size = UDim2.new(1, -24, 1, -12), Position = UDim2.new(0, 12, 0, 6), Font = Enum.Font.GothamBold, TextColor3 = LIME, Text = "SHOOTING DRILL", Parent = chip })

	-- Hint (bottom centre)
	local hint = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0, 560, 0, 44),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	})
	corner(hint, 22)
	self.hintText = label({ Size = UDim2.new(1, -32, 1, -16), Position = UDim2.new(0, 16, 0, 8), Font = Enum.Font.GothamBold, Parent = hint })
	self.hintFrame = hint

	-- Result banner (centre)
	local banner = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.3, 0),
		Size = UDim2.new(0, 520, 0, 130),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.2,
		Visible = false,
		Parent = gui,
	})
	corner(banner, 18)
	self.bannerStroke = create("UIStroke", { Thickness = 3, Parent = banner })
	self.bannerTitle = label({ Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -32, 0, 80), Parent = banner })
	create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.3, Parent = self.bannerTitle })
	self.bannerSubtitle = label({ Position = UDim2.new(0, 16, 0, 92), Size = UDim2.new(1, -32, 0, 26), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(210, 220, 210), Parent = banner })
	self.bannerScale = create("UIScale", { Parent = banner })
	self.banner = banner

	-- Power meter (right). The red band marks overpower: harder but less accurate.
	local meter = create("Frame", {
		Name = "PowerMeter",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.55, 0),
		Size = UDim2.new(0, 34, 0, 260),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	})
	corner(meter, 10)
	create("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.6, Parent = meter })
	create("Frame", {
		Size = UDim2.new(1, 0, 1 - ShotConfig.Accuracy.OverpowerFrom, 0),
		BackgroundColor3 = RED,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Parent = meter,
	})
	local fill = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4),
		Size = UDim2.new(1, -8, 0, 0),
		BackgroundColor3 = LIME,
		BorderSizePixel = 0,
		Parent = meter,
	})
	corner(fill, 7)
	label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8), Size = UDim2.new(0, 80, 0, 18), Font = Enum.Font.GothamBold, Text = "POWER", Parent = meter })
	self.powerPercent = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 8), Size = UDim2.new(0, 70, 0, 22), Text = "0%", Parent = meter })
	self.powerMeter = meter
	self.powerFill = fill

	-- Scale the whole HUD with screen height so it fits phones in landscape.
	local function rescale()
		local camera = workspace.CurrentCamera
		if camera then
			self.hudScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.6, 1.3)
		end
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

function ShotVisuals:_setBall(position: Vector3, spin: number)
	local base = CFrame.new(position) * CFrame.Angles(-spin, 0, 0)
	for _, entry in self.ballParts do
		entry[1].CFrame = base * entry[2]
	end
end

function ShotVisuals:_setKeeper(pivot: CFrame)
	for _, entry in self.keeperParts do
		entry[1].CFrame = pivot * entry[2]
	end
end

function ShotVisuals:_poseKeeper(target: Vector3, alpha: number)
	local eased = 1 - (1 - alpha) ^ 2
	local position = self.keeperHome:Lerp(target, eased)
	local direction = target - self.keeperHome
	-- Lean the body towards the dive; bigger dives lean further.
	local tilt = math.clamp(math.atan2(-direction.X, direction.Y), -KEEPER_MAX_TILT, KEEPER_MAX_TILT)
	local lean = math.clamp(direction.Magnitude / 4, 0, 1)
	self:_setKeeper(CFrame.new(position) * CFrame.Angles(0, 0, tilt * lean * eased))
end

function ShotVisuals:setHint(text: string)
	self.hintText.Text = text
	self.hintFrame.Visible = text ~= ""
end

function ShotVisuals:setScore(goals: number, shots: number)
	self.goalsValue.Text = tostring(goals)
	self.shotsValue.Text = tostring(shots)
end

function ShotVisuals:reset()
	self.state = "idle"
	self.ballSpin = 0
	self:_setBall(ShotPhysics.ballSpot(), 0)
	self:_setKeeper(CFrame.new(self.keeperHome))
	self.banner.Visible = false
	self:updateAiming(false, 0, 0.5, 0, false)
end

-- Per-frame: camera (with shake and kick), keeper idle sway.
function ShotVisuals:update(dt: number)
	self.clock += dt
	self.shake = math.max(0, self.shake - dt * 2.5)
	self.fovKick = math.max(0, self.fovKick - dt * 12)

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = ShotConfig.Camera.FieldOfView - self.fovKick
	local base = CFrame.lookAt(ShotConfig.Camera.Position, ShotConfig.Camera.LookAt)
	if self.shake > 0 then
		local t = self.clock * 25
		local amount = self.shake * 0.35
		base *= CFrame.new(math.noise(t, 1) * amount, math.noise(t, 2) * amount, 0)
	end
	camera.CFrame = base

	if self.state == "idle" then
		local t = self.clock
		local sway = Vector3.new(math.sin(t * 2.2) * 0.35, math.abs(math.sin(t * 4.4)) * 0.12, 0)
		self:_setKeeper(CFrame.new(self.keeperHome + sway))
	end
end

-- Shows the aim marker, and while holding, the power meter and the predicted (no-error) arc.
function ShotVisuals:updateAiming(enabled: boolean, aimX: number, aimY: number, power: number, holding: boolean)
	local point = ShotPhysics.aimToGoalPoint(aimX, aimY)
	local facing = CFrame.Angles(0, math.pi / 2, 0)
	local pulse = 0.25 + 0.15 * math.sin(self.clock * 6)
	self.aimMarker.Transparency = if enabled then pulse else 1
	self.aimMarker.CFrame = CFrame.new(point + Vector3.new(0, 0, 0.3)) * facing
	self.aimDot.Transparency = if enabled then 0 else 1
	self.aimDot.CFrame = CFrame.new(point + Vector3.new(0, 0, 0.32)) * facing

	local showPower = enabled and holding
	self.powerMeter.Visible = showPower
	self.powerFill.Size = UDim2.new(1, -8, power, -8 * power)
	self.powerFill.BackgroundColor3 = if power >= ShotConfig.Accuracy.OverpowerFrom
		then RED
		elseif power > 0.6 then LIME:Lerp(YELLOW, (power - 0.6) / 0.25)
		else LIME
	self.powerPercent.Text = string.format("%d%%", math.floor(power * 100 + 0.5))

	local start = ShotPhysics.ballSpot()
	local flightTime = ShotPhysics.flightTime(start, point, power)
	local velocity = ShotPhysics.launchVelocity(start, point, flightTime)
	for i, dot in self.dots do
		dot.Transparency = if showPower then 0.1 + 0.5 * i / PREVIEW_DOTS else 1
		if showPower then
			dot.CFrame = CFrame.new(ShotPhysics.positionAt(start, velocity, flightTime * i / (PREVIEW_DOTS + 1)))
		end
	end
end

-- Called the moment the player releases: small camera kick for impact.
function ShotVisuals:onShotReleased()
	self.fovKick = 2.5
	self:updateAiming(false, 0, 0.5, 0, false)
	self:setHint("")
end

function ShotVisuals:_showBanner(outcome: string)
	local info = OUTCOME_TEXT[outcome] or { outcome, WHITE, "" }
	self.bannerTitle.Text = info[1]
	self.bannerTitle.TextColor3 = info[2]
	self.bannerStroke.Color = info[2]
	self.bannerSubtitle.Text = info[3]
	self.banner.Visible = true
	self.bannerScale.Scale = 0.4
	TweenService:Create(self.bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Makes the server-built crowd jump for a moment (local effect only).
function ShotVisuals:_celebrateCrowd()
	local scene = workspace:FindFirstChild("FootballScene")
	local crowd = scene and scene:FindFirstChild("Crowd")
	if not crowd then
		return
	end
	if not self.crowdParts then
		self.crowdParts, self.crowdBase = {}, {}
		for _, fan in crowd:GetChildren() do
			if fan:IsA("BasePart") then
				table.insert(self.crowdParts, fan)
				table.insert(self.crowdBase, fan.CFrame)
			end
		end
	end
	task.spawn(function()
		local parts, base = self.crowdParts, self.crowdBase
		local frames = table.create(#parts)
		local elapsed = 0
		while elapsed < 2 do
			elapsed += RunService.RenderStepped:Wait()
			local envelope = 1 - elapsed / 2
			for i, cf in base do
				frames[i] = cf + Vector3.new(0, math.abs(math.sin(elapsed * 9 + i * 1.7)) * 0.9 * envelope, 0)
			end
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
		workspace:BulkMoveTo(parts, base, Enum.BulkMoveMode.FireCFrameChanged)
	end)
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

-- Plays the server-decided shot. Yields until the animation is finished.
function ShotVisuals:playShot(result)
	self.state = "shot"

	local start: Vector3 = result.start
	local target: Vector3 = result.target
	local flightTime: number = result.flightTime
	local velocity = ShotPhysics.launchVelocity(start, target, flightTime)

	-- The keeper stands in front of the line, so a save happens slightly before the goal plane.
	local endTime = flightTime
	if result.outcome == "SAVE" then
		endTime = flightTime * (1 - Keeper.HomeZ / (start.Z - target.Z))
	end

	local keeperTarget = Vector3.new(result.keeperTarget.X, math.max(KEEPER_MIN_Y, result.keeperTarget.Y), Keeper.HomeZ)
	local reaction: number = result.keeperReaction
	local diveDuration = math.max(endTime - reaction, 0.05)

	local t = 0
	while t < endTime do
		self:_setBall(ShotPhysics.positionAt(start, velocity, t), t * BALL_SPIN_RATE)
		self:_poseKeeper(keeperTarget, math.clamp((t - reaction) / diveDuration, 0, 1))
		t += RunService.RenderStepped:Wait()
	end

	local position = ShotPhysics.positionAt(start, velocity, endTime)
	local spin = endTime * BALL_SPIN_RATE
	self:_setBall(position, spin)
	self:_poseKeeper(keeperTarget, 1)
	self:_showBanner(result.outcome)
	self:setScore(result.goals, result.shots)
	if result.outcome == "GOAL" then
		self.shake = 1
		self.confetti:Emit(140)
		self:_celebrateCrowd()
	else
		self.shake = 0.4
	end

	-- Follow-through: gravity, ground bounces and the back of the net.
	local vel = velocityAfterImpact(result.outcome, ShotPhysics.velocityAt(velocity, endTime), target)
	local netBack = -ShotConfig.Goal.NetDepth + BALL_RADIUS
	local elapsed = 0
	while elapsed < FOLLOW_THROUGH_SECONDS do
		local dt = math.min(RunService.RenderStepped:Wait(), 1 / 20)
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
	task.wait(0.4)
end

return ShotVisuals
