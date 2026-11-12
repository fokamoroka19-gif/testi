-- Finger hint for the guided first shot: a pulsing ring on the goal shows where to press, and a
-- finger demonstrates press → hold (the power bar fills to the green zone) → release.
-- While the player holds, the finger stays pressed and the callout says when to let go.
--
-- Everything sits in a BillboardGui anchored at the target point on the goal, so the ring lines
-- up with the shot on every screen. The ring is sized in studs (it matches the press area); the
-- finger and callout are sized in pixels times the HUD scale (readable on phones).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotPhysics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotPhysics"))
local ImageLoader = require(script.Parent:WaitForChild("ImageLoader"))

local rgb = Color3.fromRGB
local GOLD = rgb(255, 191, 31)
local LIME = rgb(170, 240, 40)
local PINK = rgb(255, 120, 140)
local CREAM = rgb(247, 236, 214)
local INK = rgb(18, 6, 31)
local NAVY = rgb(18, 11, 36)
local VIOLET = rgb(90, 47, 194)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local TEXT = {
	Press = "НАЖМИ И ДЕРЖИ",
	Hold = "ДЕРЖИ…",
	Release = "ОТПУСТИ!",
	Wait = "ДЕРЖИ ДО ЗЕЛЁНОЙ ЗОНЫ",
	Missed = "НАЖМИ НА КРУЖОК",
}

local MARGIN = 360 -- pixels of room around the ring for the finger and the callout
local FINGER_SIZE = 92 -- pixels at HUD scale 1
local FINGER_TIP = Vector2.new(0.235, 0.04) -- fingertip in the finger image (see tools/assets/finger.py)
local FALLBACK_TIP = Vector2.new(0.3, 0.07)

-- Demo timeline (seconds in a loop).
local LOOP = 2.6
local ARRIVE, PRESS, RELEASE, FADE = 0.55, 0.7, 1.35, 1.7
local DEMO_POWER = 0.68 -- where the demo releases (middle of the green zone)

local TutorialHint = {}
TutorialHint.__index = TutorialHint

local function create(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function circle(parent: Instance, name: string, color: Color3, thickness: number): (Frame, UIStroke)
	local f = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	local s = create("UIStroke", { Color = color, Thickness = thickness, Parent = f })
	return f, s
end

local function easeOut(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end

-- Plain finger made of frames, used only if images are unavailable.
local function fallbackFinger(parent: Instance): { GuiObject }
	local parts = {}
	local hand = create("Frame", {
		Name = "Hand",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.95),
		Rotation = -22,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local function piece(name: string, position: UDim2, size: UDim2, color: Color3, radius: number)
		local f = create("Frame", { Name = name, Position = position, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, Parent = hand })
		create("UICorner", { CornerRadius = UDim.new(radius, 0), Parent = f })
		create("UIStroke", { Color = INK, Thickness = 3, Parent = f })
		table.insert(parts, f)
	end
	piece("Index", UDim2.fromScale(0.3, 0), UDim2.fromScale(0.3, 0.6), CREAM, 0.5)
	piece("Palm", UDim2.fromScale(0.05, 0.45), UDim2.fromScale(0.9, 0.4), CREAM, 0.3)
	piece("Cuff", UDim2.fromScale(0.08, 0.82), UDim2.fromScale(0.84, 0.16), VIOLET, 0.2)
	return parts
end

function TutorialHint.new()
	local self = setmetatable({}, TutorialHint)
	self.hint = nil
	self.clock = 0
	self.nudgeUntil = -1
	self.misses = 0

	local anchor = Instance.new("Attachment")
	anchor.Name = "TutorialHintAnchor"
	self.anchor = anchor

	local gui = create("BillboardGui", {
		Name = "TutorialHint",
		Adornee = anchor,
		AlwaysOnTop = true,
		LightInfluence = 0,
		ClipsDescendants = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	-- Ring: the billboard is ring size (studs) plus MARGIN pixels on every side.
	local target = create("Frame", {
		Name = "Target",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -2 * MARGIN, 1, -2 * MARGIN),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	self.target = target
	local fill = create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.82,
		Parent = target,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	self.fill = fill
	circle(target, "Outline", INK, 6)
	local _, ring = circle(target, "Ring", GOLD, 3.5)
	self.ringStroke = ring
	local dot = create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = GOLD,
		Parent = target,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	create("UIStroke", { Color = INK, Thickness = 2, Parent = dot })
	self.dot = dot
	self.ripples = {}
	for i = 1, 2 do
		local ripple, stroke = circle(target, "Ripple" .. i, GOLD, 3)
		self.ripples[i] = { frame = ripple, stroke = stroke }
	end

	-- Callout bubble above the ring.
	local bubble = create("Frame", {
		Name = "Callout",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.05,
		ZIndex = 4,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 9), Parent = bubble })
	self.bubbleStroke = create("UIStroke", { Color = GOLD, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bubble })
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = bubble })
	self.bubbleScale = create("UIScale", { Parent = bubble })
	self.label = create("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextSize = 24,
		TextColor3 = CREAM,
		Text = TEXT.Press,
		ZIndex = 5,
		Parent = bubble,
	})
	create("UIStroke", { Color = INK, Thickness = 2, Parent = self.label })
	self.bubble = bubble
	local tail = create("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 1),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = bubble,
	})
	self.tailStroke = create("UIStroke", { Color = GOLD, Thickness = 2.5, Parent = tail })
	self.popScale = 1

	-- The finger: its anchor point is the fingertip.
	local image = ImageLoader.get("Ui/Finger")
	local finger
	if image then
		finger = create("ImageLabel", {
			Name = "Finger",
			AnchorPoint = FINGER_TIP,
			BackgroundTransparency = 1,
			ImageContent = image,
			ZIndex = 6,
			Parent = gui,
		})
		self.fingerParts = nil
	else
		finger = create("Frame", { Name = "Finger", AnchorPoint = FALLBACK_TIP, BackgroundTransparency = 1, ZIndex = 6, Parent = gui })
		self.fingerParts = fallbackFinger(finger)
	end
	self.finger = finger
	self.fingerScale = create("UIScale", { Parent = finger })
	return self
end

-- hint: { aimX, aimY, ringRadius, tapRadius, powerMin, powerMax } from the server's tutorial episode.
function TutorialHint:show(hint)
	self.hint = hint
	self.point = ShotPhysics.aimToGoalPoint(hint.aimX, hint.aimY)
	self.clock = 0
	self.nudgeUntil = -1
	self.misses = 0
	self.anchor.Parent = workspace.Terrain
	self.anchor.WorldPosition = self.point
	local d = hint.ringRadius * 2
	self.gui.Size = UDim2.new(d, 2 * MARGIN, d, 2 * MARGIN)
	self.gui.Enabled = true
end

function TutorialHint:hide()
	self.hint = nil
	self.gui.Enabled = false
	self.anchor.Parent = nil
end

function TutorialHint:isActive(): boolean
	return self.hint ~= nil
end

-- Whether a press at this aim counts (distance on the goal plane, in studs). A press elsewhere
-- is ignored once with a nudge; after that any press counts, since the guided shot keeps the
-- hinted aim anyway.
function TutorialHint:accepts(aimX: number, aimY: number): boolean
	local hint = self.hint
	if not hint then
		return true
	end
	local p = ShotPhysics.aimToGoalPoint(aimX, aimY)
	if (Vector3.new(p.X, p.Y, 0) - Vector3.new(self.point.X, self.point.Y, 0)).Magnitude <= hint.tapRadius then
		return true
	end
	self.misses += 1
	return self.misses > 1
end

-- Pressed somewhere else: shake the finger and point at the ring again.
function TutorialHint:nudge()
	self.nudgeUntil = self.clock + 1.2
end

function TutorialHint:_setLabel(text: string, color: Color3)
	if self.label.Text ~= text then
		self.label.Text = text
		self.popScale = 1.15
	end
	self.label.TextColor3 = color
	self.bubbleStroke.Color = color
	self.tailStroke.Color = color
end

-- Call every frame with the HUD scale. Returns the demo power to show on the power bar while
-- the player isn't holding.
function TutorialHint:update(dt: number, holding: boolean, power: number, uiScale: number): number?
	local hint = self.hint
	if not hint then
		return nil
	end
	self.clock += dt

	local radius = math.max(12, self.target.AbsoluteSize.X / 2) -- ring radius in pixels at this distance
	local s = uiScale
	self.popScale += (1 - self.popScale) * math.min(1, dt * 10)

	local pulse = 0.5 + 0.5 * math.sin(self.clock * 6)
	local inZone = power >= hint.powerMin and power <= hint.powerMax
	local accent = if holding and inZone then LIME else GOLD
	self.ringStroke.Color = accent
	self.fill.BackgroundColor3 = accent
	self.dot.BackgroundColor3 = accent
	self.fill.BackgroundTransparency = 0.86 - 0.1 * pulse

	local fingerOffset, fingerScale, fingerAlpha, demoPower = Vector2.zero, 1, 0, nil
	local rippleT = (self.clock % 1.1) / 1.1 -- idle ripple
	local pop = self.popScale

	if holding then
		fingerScale, fingerAlpha = 0.86, 0
		if inZone then
			self:_setLabel(TEXT.Release, LIME)
			pop *= 1 + 0.08 * pulse
		else
			self:_setLabel(TEXT.Wait, GOLD)
		end
	elseif self.clock < self.nudgeUntil then
		fingerOffset = Vector2.new(math.sin(self.clock * 40) * 10 * s * (self.nudgeUntil - self.clock), 0)
		self:_setLabel(TEXT.Missed, PINK)
	else
		local t = self.clock % LOOP
		local start = Vector2.new(radius * 1.2 + 60 * s, radius * 1.4 + 90 * s)
		if t < ARRIVE then
			local k = easeOut(t / ARRIVE)
			fingerOffset = start:Lerp(Vector2.zero, k)
			fingerAlpha = 1 - k
			self:_setLabel(TEXT.Press, GOLD)
		elseif t < PRESS then
			fingerScale = 1 - 0.14 * easeOut((t - ARRIVE) / (PRESS - ARRIVE))
			rippleT = (t - ARRIVE) / 1.1
			self:_setLabel(TEXT.Press, GOLD)
		elseif t < RELEASE then
			fingerScale = 0.86
			rippleT = (t - ARRIVE) / 1.1
			demoPower = DEMO_POWER * (t - PRESS) / (RELEASE - PRESS)
			self:_setLabel(TEXT.Hold, GOLD)
		elseif t < FADE then
			local k = easeOut((t - RELEASE) / (FADE - RELEASE))
			fingerScale = 0.86 + 0.14 * k
			fingerOffset = Vector2.new(10 * s * k, -16 * s * k)
			fingerAlpha = k
			demoPower = DEMO_POWER
			self:_setLabel(TEXT.Release, LIME)
		else
			fingerAlpha = 1
			demoPower = 0
			self:_setLabel(TEXT.Press, GOLD)
		end
	end

	-- Positions are pixels from the billboard centre (the target point).
	self.bubble.Position = UDim2.new(0.5, 0, 0.5, -radius - 12 * s)
	self.bubbleScale.Scale = s * pop

	local size = FINGER_SIZE * s
	self.finger.Size = UDim2.fromOffset(size, size)
	self.finger.Position = UDim2.new(0.5, fingerOffset.X, 0.5, fingerOffset.Y)
	self.fingerScale.Scale = fingerScale
	if self.fingerParts then
		for _, part in self.fingerParts do
			part.BackgroundTransparency = fingerAlpha
			local stroke = part:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = fingerAlpha
			end
		end
	else
		self.finger.ImageTransparency = fingerAlpha
	end

	for i, ripple in self.ripples do
		local k = (rippleT + (i - 1) * 0.5) % 1
		ripple.frame.Size = UDim2.fromScale(1 + k * 0.9, 1 + k * 0.9)
		ripple.stroke.Transparency = 0.2 + 0.8 * k
		ripple.stroke.Color = accent
	end
	return demoPower
end

return TutorialHint
