-- Client-only visuals: camera, ball, goalkeeper, aim marker, trajectory preview and HUD.
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
local PREVIEW_DOTS = 12
local FOLLOW_THROUGH_SECONDS = 1.3
local KEEPER_MIN_Y = 1.2
local KEEPER_MAX_TILT = math.rad(95)

local LIME = Color3.fromRGB(163, 230, 53)
local DARK = Color3.fromRGB(14, 20, 16)

local OUTCOME_TEXT = {
	GOAL = { "GOAL!", LIME },
	SAVE = { "SAVED!", Color3.new(1, 1, 1) },
	POST = { "OFF THE POST!", Color3.fromRGB(250, 204, 21) },
	MISS = { "MISSED!", Color3.fromRGB(248, 113, 113) },
}

local ShotVisuals = {}
ShotVisuals.__index = ShotVisuals

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function makeLabel(props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

function ShotVisuals.new()
	local self = setmetatable({}, ShotVisuals)

	local folder = Instance.new("Folder")
	folder.Name = "ShotVisuals"
	folder.Parent = workspace
	self.folder = folder

	self.ball = makePart({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * BALL_RADIUS * 2,
		Color = Color3.new(1, 1, 1),
		Material = Enum.Material.SmoothPlastic,
		Parent = folder,
	})

	-- Goalkeeper: body + head + gloves, posed as a whole around the body centre.
	local keeperModel = Instance.new("Model")
	keeperModel.Name = "Goalkeeper"
	local body = makePart({
		Name = "Body",
		Size = Vector3.new(2.4, 5.2, 1.2),
		Color = Color3.fromRGB(255, 170, 0),
		Material = Enum.Material.SmoothPlastic,
		Parent = keeperModel,
	})
	local parts = {
		{ body, CFrame.identity },
		{ makePart({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, Color = Color3.fromRGB(234, 192, 160), Parent = keeperModel }), CFrame.new(0, 3.3, 0) },
		{ makePart({ Name = "LeftGlove", Size = Vector3.one * 0.9, Color = LIME, Parent = keeperModel }), CFrame.new(-1.9, 2.4, 0) },
		{ makePart({ Name = "RightGlove", Size = Vector3.one * 0.9, Color = LIME, Parent = keeperModel }), CFrame.new(1.9, 2.4, 0) },
	}
	keeperModel.PrimaryPart = body
	keeperModel.Parent = folder
	self.keeper = keeperModel
	self.keeperParts = parts
	self.keeperHome = Vector3.new(Keeper.HomeX, Keeper.HomeY, Keeper.HomeZ)
	self.keeper.Parent = if Keeper.Enabled then folder else nil

	self.aimMarker = makePart({
		Name = "AimMarker",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, BALL_RADIUS * 2, BALL_RADIUS * 2), -- same size as the ball
		Color = LIME,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CastShadow = false,
		Parent = folder,
	})

	self.dots = {}
	for i = 1, PREVIEW_DOTS do
		self.dots[i] = makePart({
			Name = "PreviewDot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.35,
			Color = LIME,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CastShadow = false,
			Parent = folder,
		})
	end

	self:_buildHud()
	self:reset()
	return self
end

function ShotVisuals:_buildHud()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShotHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	self.scoreLabel = makeLabel({
		Name = "Score",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 20, 0, 16),
		Size = UDim2.new(0.3, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "GOALS 0 / SHOTS 0",
		Parent = gui,
	})

	self.hintLabel = makeLabel({
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(0.8, 0, 0, 30),
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = gui,
	})

	local banner = makeLabel({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.32, 0),
		Size = UDim2.new(0.7, 0, 0.16, 0),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = gui,
	})
	self.bannerScale = Instance.new("UIScale")
	self.bannerScale.Parent = banner
	self.banner = banner

	-- Vertical power meter on the right; the red band marks overpower (less accurate).
	local bar = Instance.new("Frame")
	bar.Name = "PowerBar"
	bar.AnchorPoint = Vector2.new(1, 0.5)
	bar.Position = UDim2.new(1, -24, 0.55, 0)
	bar.Size = UDim2.new(0, 28, 0.5, 0)
	bar.BackgroundColor3 = DARK
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 8)

	local danger = Instance.new("Frame")
	danger.Name = "Overpower"
	danger.Size = UDim2.new(1, 0, 1 - ShotConfig.Accuracy.OverpowerFrom, 0)
	danger.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
	danger.BackgroundTransparency = 0.5
	danger.BorderSizePixel = 0
	danger.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.new(0, 0, 1, 0)
	fill.Size = UDim2.new(1, 0, 0, 0)
	fill.BackgroundColor3 = LIME
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)

	makeLabel({
		Name = "PowerLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.new(0, 70, 0, 20),
		Font = Enum.Font.GothamBold,
		Text = "POWER",
		Parent = bar,
	})

	self.powerBar = bar
	self.powerFill = fill
end

function ShotVisuals:setupCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = ShotConfig.Camera.FieldOfView
	camera.CFrame = CFrame.lookAt(ShotConfig.Camera.Position, ShotConfig.Camera.LookAt)
end

function ShotVisuals:_poseKeeper(target: Vector3, alpha: number)
	local eased = 1 - (1 - alpha) ^ 2
	local position = self.keeperHome:Lerp(target, eased)
	local direction = target - self.keeperHome
	-- Lean the body towards the dive direction; bigger dives lean further.
	local tilt = math.clamp(math.atan2(-direction.X, direction.Y), -KEEPER_MAX_TILT, KEEPER_MAX_TILT)
	local lean = math.clamp(direction.Magnitude / 4, 0, 1)
	local pivot = CFrame.new(position) * CFrame.Angles(0, 0, tilt * lean * eased)
	for _, entry in self.keeperParts do
		entry[1].CFrame = pivot * entry[2]
	end
end

function ShotVisuals:setHint(text: string)
	self.hintLabel.Text = text
end

function ShotVisuals:setScore(goals: number, shots: number)
	self.scoreLabel.Text = string.format("GOALS %d / SHOTS %d", goals, shots)
end

function ShotVisuals:reset()
	self:setupCamera()
	self.ball.CFrame = CFrame.new(ShotPhysics.ballSpot())
	self:_poseKeeper(self.keeperHome, 0)
	self.banner.Visible = false
	self:updateAiming(false, 0, 0.5, 0, false)
end

-- Shows the aim marker, and while holding, the power meter and predicted (no-error) arc.
function ShotVisuals:updateAiming(enabled: boolean, aimX: number, aimY: number, power: number, holding: boolean)
	local point = ShotPhysics.aimToGoalPoint(aimX, aimY)
	self.aimMarker.Transparency = if enabled then 0.3 else 1
	self.aimMarker.CFrame = CFrame.new(point + Vector3.new(0, 0, 0.3)) * CFrame.Angles(0, math.pi / 2, 0)

	local showPower = enabled and holding
	self.powerBar.Visible = showPower
	self.powerFill.Size = UDim2.new(1, 0, power, 0)

	local start = ShotPhysics.ballSpot()
	local flightTime = ShotPhysics.flightTime(start, point, power)
	local velocity = ShotPhysics.launchVelocity(start, point, flightTime)
	for i, dot in self.dots do
		dot.Transparency = if showPower then 0.15 else 1
		if showPower then
			dot.CFrame = CFrame.new(ShotPhysics.positionAt(start, velocity, flightTime * i / (PREVIEW_DOTS + 1)))
		end
	end
end

function ShotVisuals:_showBanner(outcome: string)
	local info = OUTCOME_TEXT[outcome] or { outcome, Color3.new(1, 1, 1) }
	self.banner.Text = info[1]
	self.banner.TextColor3 = info[2]
	self.banner.Visible = true
	self.bannerScale.Scale = 0.5
	TweenService:Create(self.bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Velocity right after the ball reaches the goal plane / keeper; purely cosmetic.
local function velocityAfterImpact(outcome: string, velocity: Vector3, target: Vector3): Vector3
	if outcome == "GOAL" then
		return velocity * 0.6
	elseif outcome == "SAVE" then
		local side = if target.X >= 0 then 1 else -1
		return Vector3.new(side * 6, 8, -velocity.Z * 0.25)
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
	self:updateAiming(false, 0, 0.5, 0, false)

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
	local function keeperAlpha(t: number): number
		return math.clamp((t - reaction) / diveDuration, 0, 1)
	end

	local startedAt = os.clock()
	while true do
		local t = os.clock() - startedAt
		if t >= endTime then
			break
		end
		self.ball.CFrame = CFrame.new(ShotPhysics.positionAt(start, velocity, t))
		self:_poseKeeper(keeperTarget, keeperAlpha(t))
		RunService.RenderStepped:Wait()
	end

	local position = ShotPhysics.positionAt(start, velocity, endTime)
	self.ball.CFrame = CFrame.new(position)
	self:_poseKeeper(keeperTarget, 1)
	self:_showBanner(result.outcome)
	self:setScore(result.goals, result.shots)

	-- Short follow-through: gravity, ground bounces and the back of the net.
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
		self.ball.CFrame = CFrame.new(position)
	end
	task.wait(0.3)
end

return ShotVisuals
