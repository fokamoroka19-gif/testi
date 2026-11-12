-- Finger hint for the guided first shot: a pulsing ring on the goal shows where to press, and a
-- finger demonstrates press → hold (the power bar fills to the green zone) → release.
-- While the player holds, the finger stays pressed and the callout says when to let go.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ShotPhysics = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotPhysics"))

local rgb = Color3.fromRGB
local GOLD = rgb(255, 191, 31)
local LIME = rgb(170, 240, 40)
local CREAM = rgb(247, 236, 214)
local INK = rgb(18, 6, 31)
local NAVY = rgb(18, 11, 36)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

local TEXT = {
	Press = "НАЖМИ И ДЕРЖИ ЗДЕСЬ",
	Hold = "ДЕРЖИ…",
	Release = "ОТПУСТИ!",
	Wait = "ДЕРЖИ… ЖДИ ЗЕЛЁНУЮ ЗОНУ",
	Missed = "НАЖМИ НА КРУЖОК",
}

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

function TutorialHint.new()
	local self = setmetatable({}, TutorialHint)
	self.hint = nil
	self.clock = 0
	self.nudgeUntil = -1

	-- Viewport coordinates, so WorldToViewportPoint positions map 1:1.
	local gui = create("ScreenGui", {
		Name = "TutorialHint",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 5,
		Enabled = false,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	local target = create("Frame", { Name = "Target", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	self.target = target
	local glow = create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.82,
		Parent = target,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
	self.fill = glow
	local _, outer = circle(target, "Outline", INK, 7)
	self.outerStroke = outer
	local _, ring = circle(target, "Ring", GOLD, 4)
	self.ringStroke = ring
	local dot = create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = GOLD,
		Parent = target,
	})
	create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
	create("UIStroke", { Color = INK, Thickness = 2, Parent = dot })
	self.ripples = {}
	for i = 1, 2 do
		local ripple, stroke = circle(target, "Ripple" .. i, GOLD, 3)
		self.ripples[i] = { frame = ripple, stroke = stroke }
	end

	-- Callout bubble above the ring.
	local bubble = create("Frame", {
		Name = "Callout",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 8), Parent = bubble })
	self.bubbleStroke = create("UIStroke", { Color = GOLD, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = bubble })
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = bubble })
	self.bubbleScale = create("UIScale", { Parent = bubble })
	self.label = create("TextLabel", {
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextSize = 20,
		TextColor3 = CREAM,
		Text = TEXT.Press,
		Parent = bubble,
	})
	create("UIStroke", { Color = INK, Thickness = 2, Parent = self.label })
	self.bubble = bubble
	-- Little tail pointing at the ring.
	local tail = create("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, 1),
		Size = UDim2.fromOffset(12, 12),
		Rotation = 45,
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = bubble,
	})
	self.tailStroke = create("UIStroke", { Color = GOLD, Thickness = 2.5, Parent = tail })

	-- The finger: fingertip of the emoji sits on the anchor point.
	local finger = create("TextLabel", {
		Name = "Finger",
		AnchorPoint = Vector2.new(0.4, 0.06),
		Size = UDim2.fromOffset(84, 84),
		BackgroundTransparency = 1,
		Text = "👆",
		TextSize = 76,
		ZIndex = 3,
		Parent = gui,
	})
	self.finger = finger
	self.fingerScale = create("UIScale", { Parent = finger })
	return self
end

-- hint: { aimX, aimY, tapRadius, powerMin, powerMax } from the server's tutorial episode.
function TutorialHint:show(hint)
	self.hint = hint
	self.point = ShotPhysics.aimToGoalPoint(hint.aimX, hint.aimY)
	self.clock = 0
	self.nudgeUntil = -1
	self.gui.Enabled = true
end

function TutorialHint:hide()
	self.hint = nil
	self.gui.Enabled = false
end

function TutorialHint:isActive(): boolean
	return self.hint ~= nil
end

-- Whether a press at this aim is close enough to the ring (measured on the goal plane, in studs).
function TutorialHint:accepts(aimX: number, aimY: number): boolean
	local hint = self.hint
	if not hint then
		return true
	end
	local p = ShotPhysics.aimToGoalPoint(aimX, aimY)
	return (Vector3.new(p.X, p.Y, 0) - Vector3.new(self.point.X, self.point.Y, 0)).Magnitude <= hint.tapRadius
end

-- Pressed somewhere else: shake the finger and point at the ring again.
function TutorialHint:nudge()
	self.nudgeUntil = self.clock + 1.2
end

function TutorialHint:_setLabel(text: string, color: Color3)
	if self.label.Text ~= text then
		self.label.Text = text
		self.bubbleScale.Scale = 1.15
	end
	self.label.TextColor3 = color
	self.bubbleStroke.Color = color
	self.tailStroke.Color = color
end

-- Call every frame. Returns the demo power to show on the power bar while the player isn't holding.
function TutorialHint:update(dt: number, holding: boolean, power: number): number?
	local hint = self.hint
	local camera = workspace.CurrentCamera
	if not hint or not camera then
		return nil
	end
	self.clock += dt

	local center = camera:WorldToViewportPoint(self.point)
	local edge = camera:WorldToViewportPoint(self.point + Vector3.new(hint.tapRadius, 0, 0))
	local radius = math.max(24, math.abs(edge.X - center.X))
	local at = Vector2.new(center.X, center.Y)

	self.target.Position = UDim2.fromOffset(at.X, at.Y)
	self.target.Size = UDim2.fromOffset(radius * 2, radius * 2)
	self.bubble.Position = UDim2.fromOffset(at.X, at.Y - radius - 14)
	self.bubbleScale.Scale += (1 - self.bubbleScale.Scale) * math.min(1, dt * 10)

	local pulse = 0.5 + 0.5 * math.sin(self.clock * 6)
	local inZone = power >= hint.powerMin and power <= hint.powerMax
	local accent = if holding and inZone then LIME else GOLD
	self.ringStroke.Color = accent
	self.fill.BackgroundColor3 = accent
	self.fill.BackgroundTransparency = 0.88 - 0.1 * pulse

	local fingerOffset, fingerScale, fingerAlpha, demoPower = Vector2.zero, 1, 0, nil
	local rippleT = (self.clock % 1.1) / 1.1 -- idle ripple

	if holding then
		fingerScale, fingerAlpha = 0.84, 0
		if inZone then
			self:_setLabel(TEXT.Release, LIME)
			self.bubbleScale.Scale = 1 + 0.08 * pulse
		else
			self:_setLabel(TEXT.Wait, GOLD)
		end
	elseif self.clock < self.nudgeUntil then
		local shake = math.sin(self.clock * 40) * 10 * (self.nudgeUntil - self.clock)
		fingerOffset = Vector2.new(shake, 0)
		self:_setLabel(TEXT.Missed, rgb(255, 120, 140))
	else
		local t = self.clock % LOOP
		local start = Vector2.new(radius * 1.3 + 40, radius * 1.6 + 90)
		if t < ARRIVE then
			local k = easeOut(t / ARRIVE)
			fingerOffset = start:Lerp(Vector2.zero, k)
			fingerAlpha = 1 - k
			self:_setLabel(TEXT.Press, GOLD)
		elseif t < PRESS then
			fingerScale = 1 - 0.16 * easeOut((t - ARRIVE) / (PRESS - ARRIVE))
			rippleT = (t - ARRIVE) / 1.1
			self:_setLabel(TEXT.Press, GOLD)
		elseif t < RELEASE then
			fingerScale = 0.84
			rippleT = (t - ARRIVE) / 1.1
			demoPower = DEMO_POWER * (t - PRESS) / (RELEASE - PRESS)
			self:_setLabel(TEXT.Hold, GOLD)
		elseif t < FADE then
			local k = easeOut((t - RELEASE) / (FADE - RELEASE))
			fingerScale = 0.84 + 0.16 * k
			fingerOffset = Vector2.new(0, -18 * k)
			fingerAlpha = k
			demoPower = DEMO_POWER
			self:_setLabel(TEXT.Release, LIME)
		else
			fingerAlpha = 1
			demoPower = 0
			self:_setLabel(TEXT.Press, GOLD)
		end
	end

	self.finger.Position = UDim2.fromOffset(at.X + fingerOffset.X, at.Y + fingerOffset.Y)
	self.fingerScale.Scale = fingerScale
	self.finger.TextTransparency = fingerAlpha

	for i, ripple in self.ripples do
		local k = (rippleT + (i - 1) * 0.5) % 1
		ripple.frame.Size = UDim2.fromScale(1 + k * 0.9, 1 + k * 0.9)
		ripple.stroke.Transparency = 0.2 + 0.8 * k
		ripple.stroke.Color = accent
	end
	return demoPower
end

return TutorialHint
