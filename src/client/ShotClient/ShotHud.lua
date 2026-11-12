-- Screen UI for the shot drill: logo + stage, goals counter, bottom power panel and the
-- result card. Layout is designed at 1280x720 and scaled per panel to the screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ShotHud = {}
ShotHud.__index = ShotHud

-- All player-facing text in one place.
local TEXT = {
	LogoTop = "NEW",
	LogoBottom = 'FOOTBALL  <font color="#A3E635">STAR</font> <font color="#A3E635" size="22">★</font>',
	Mode = 'ОБУЧЕНИЕ  •  <font color="#A3E635">УДАРЫ</font>',
	Stage = "Этап 1 из 3",
	Goals = "ГОЛЫ",
	Power = 'СИЛА <font color="#A3E635">%d%%</font>',
	PowerHint = "55–85% — удобно   ·   100% — мяч летит выше",
	Ready = "Зажми точку у ворот и отпусти для удара",
	Holding = "Отпусти, чтобы ударить",
	Flying = "Удар!",
	AfterShot = "Выбери точку удара и попробуй ещё",
	NextShot = "ЕЩЁ УДАР  ›",
	NewSeries = "НОВАЯ СЕРИЯ  ›",
	SeriesOver = "Серия окончена: %d из %d голов",
	Outcomes = {
		GOAL = { "ГОЛ!", "Отличное попадание в створ" },
		SAVE = { "СЕЙВ!", "Вратарь успел. Целься ближе к углу" },
		POST = { "ШТАНГА!", "Совсем рядом. Чуть ближе к центру" },
		BAR = { "ПЕРЕКЛАДИНА!", "Совсем рядом. Чуть ниже" },
		WIDE = { "МИМО!", "Мяч прошёл мимо ворот" },
		OVER = { "ВЫШЕ ВОРОТ!", "Слишком сильно. Сбавь силу" },
	},
}

local LIME = Color3.fromRGB(163, 230, 53)
local LIME_DARK = Color3.fromRGB(104, 160, 24)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(184, 198, 192)
local INK = Color3.fromRGB(8, 20, 16)
local PANEL_LEFT = Color3.fromRGB(24, 52, 45)
local PANEL_RIGHT = Color3.fromRGB(7, 18, 15)
local YELLOW = Color3.fromRGB(250, 204, 21)
local RED = Color3.fromRGB(248, 90, 90)

local OUTCOME_COLORS = {
	GOAL = LIME,
	SAVE = WHITE,
	POST = YELLOW,
	BAR = YELLOW,
	WIDE = RED,
	OVER = RED,
}
local PIP_COLORS = { GOAL = LIME, SAVE = WHITE, POST = YELLOW, MISS = RED }

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local FONT_HEAVY = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local FONT_BOLD = Font.new(MONTSERRAT, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local FONT_MEDIUM = Font.new(MONTSERRAT, Enum.FontWeight.Medium)

local DESIGN_SIZE = Vector2.new(1280, 720)

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

local function frame(props: { [string]: any }): Frame
	props.BorderSizePixel = 0
	if props.BackgroundTransparency == nil then
		props.BackgroundTransparency = 0
	end
	return create("Frame", props)
end

local function text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = 1
	props.RichText = true
	props.FontFace = props.FontFace or FONT_HEAVY
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props)
end

local function corner(parent: Instance, radius: number?)
	create("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0), Parent = parent })
end

local function circle(parent: Instance, size: number, props: { [string]: any }?): Frame
	local p = { Size = UDim2.fromOffset(size, size), Parent = parent }
	for key, value in props or {} do
		p[key] = value
	end
	local f = frame(p)
	corner(f)
	return f
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Lime border with a soft outer glow made of stacked, increasingly transparent strokes.
local function glow(target: GuiObject, radius: number, strength: number?)
	local s = strength or 1
	stroke(target, LIME, 2)
	for _, layer in { { 5, 0.72 }, { 10, 0.86 }, { 16, 0.93 } } do
		local halo = frame({ Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = target })
		corner(halo, radius)
		stroke(halo, LIME, layer[1], 1 - (1 - layer[2]) * s)
	end
end

-- Dark panel with a left-to-right gradient, rounded corners and a lime glow.
local function panel(props: { [string]: any }, radius: number): Frame
	props.BackgroundTransparency = 1
	local root = frame(props)
	local bg = frame({ Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 0, Parent = root })
	corner(bg, radius)
	create("UIGradient", { Color = ColorSequence.new(PANEL_LEFT, PANEL_RIGHT), Parent = bg })
	glow(root, radius)
	return root
end

-- Decorative "////" slashes, as in the reference panels.
local function slashes(parent: Instance, position: UDim2, size: number)
	text({
		Name = "Slashes",
		Position = position,
		Size = UDim2.fromOffset(size * 2.2, size),
		TextSize = size,
		Text = "////",
		TextColor3 = LIME,
		TextTransparency = 0.82,
		Parent = parent,
	})
end

local function trophyIcon(parent: Instance, position: UDim2): Frame
	local icon = frame({ Name = "Trophy", Position = position, Size = UDim2.fromOffset(32, 30), BackgroundTransparency = 1, Parent = parent })
	for _, x in { 2, 22 } do
		local handle = circle(icon, 9, { Position = UDim2.fromOffset(x, 4), BackgroundTransparency = 1 })
		stroke(handle, LIME, 2.5)
	end
	local cup = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 1), Size = UDim2.fromOffset(18, 15), BackgroundColor3 = LIME, Parent = icon })
	corner(cup, 6)
	frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 15), Size = UDim2.fromOffset(4, 7), BackgroundColor3 = LIME, Parent = icon })
	local base = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(16, 5), BackgroundColor3 = LIME, Parent = icon })
	corner(base, 2)
	return icon
end

local function crosshairIcon(parent: Instance, center: UDim2)
	local ring = circle(parent, 30, { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, BackgroundTransparency = 1 })
	stroke(ring, LIME, 2.5)
	circle(ring, 6, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = LIME })
	for _, tick in { { 0.5, 0, 2.5, 9 }, { 0.5, 1, 2.5, 9 }, { 0, 0.5, 9, 2.5 }, { 1, 0.5, 9, 2.5 } } do
		frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(tick[1], tick[2]),
			Size = UDim2.fromOffset(tick[3], tick[4]),
			BackgroundColor3 = LIME,
			Parent = ring,
		})
	end
end

-- Football with a small laurel wreath, sitting on the top edge of the result card.
local function ballBadge(parent: Instance)
	local badge = frame({ Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(110, 56), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	for _, side in { -1, 1 } do
		for k, angle in { -25, 10, 45 } do
			local rad = math.rad(angle)
			local leaf = frame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, side * math.cos(rad) * 34, 0.5, -math.sin(rad) * 30 + 2),
				Size = UDim2.fromOffset(7, 15 - k),
				Rotation = side * (angle + 20),
				BackgroundColor3 = LIME,
				ZIndex = 3,
				Parent = badge,
			})
			corner(leaf)
		end
	end
	local ball = circle(badge, 46, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = INK, ZIndex = 4 })
	stroke(ball, LIME, 2)
	text({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Text = "⚽", TextSize = 28, FontFace = FONT_MEDIUM, ZIndex = 5, Parent = ball })
end

function ShotHud.new()
	local self = setmetatable({}, ShotHud)
	self.scales = {}
	self.cardToken = 0

	local gui = create("ScreenGui", {
		Name = "ShotHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	self.gui = gui

	self:_buildLogo()
	self:_buildGoals()
	self:_buildPowerPanel()
	self:_buildCard()

	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / DESIGN_SIZE.X, viewport.Y / DESIGN_SIZE.Y), 0.5, 1.3)
		for _, uiScale in self.scales do
			uiScale.Scale = scale
		end
		self.baseScale = scale
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	return self
end

function ShotHud:_scaled(target: GuiObject): UIScale
	local uiScale = create("UIScale", { Parent = target })
	table.insert(self.scales, uiScale)
	return uiScale
end

function ShotHud:_buildLogo()
	local logo = frame({ Name = "Logo", Position = UDim2.fromOffset(18, 6), Size = UDim2.fromOffset(330, 120), BackgroundTransparency = 1, Parent = self.gui })
	self:_scaled(logo)
	local bar = frame({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(13, 52), Rotation = 12, BackgroundColor3 = LIME, Parent = logo })
	corner(bar, 3)
	text({ Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(300, 30), TextSize = 30, Text = TEXT.LogoTop, Parent = logo })
	text({ Position = UDim2.fromOffset(30, 28), Size = UDim2.fromOffset(300, 32), TextSize = 30, Text = TEXT.LogoBottom, Parent = logo })
	frame({ Position = UDim2.fromOffset(30, 70), Size = UDim2.fromOffset(2, 42), BackgroundColor3 = LIME, Parent = logo })
	text({ Position = UDim2.fromOffset(42, 68), Size = UDim2.fromOffset(280, 20), TextSize = 16, FontFace = FONT_BOLD, Text = TEXT.Mode, Parent = logo })
	text({ Position = UDim2.fromOffset(42, 92), Size = UDim2.fromOffset(120, 18), TextSize = 14, FontFace = FONT_MEDIUM, TextColor3 = MUTED, Text = TEXT.Stage, Parent = logo })
	for i = 1, 3 do
		local dot = circle(logo, 9, { Position = UDim2.fromOffset(150 + (i - 1) * 16, 96), BackgroundColor3 = LIME, BackgroundTransparency = if i == 1 then 0 else 1 })
		if i > 1 then
			stroke(dot, MUTED, 1.5, 0.4)
		end
	end
end

function ShotHud:_buildGoals()
	local holder = frame({
		Name = "GoalsHolder",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 14),
		Size = UDim2.fromOffset(250, 90),
		BackgroundTransparency = 1,
		Parent = self.gui,
	})
	self.goalsScale = self:_scaled(holder)
	local box = panel({ Name = "Goals", Size = UDim2.fromOffset(250, 58), Parent = holder }, 16)
	trophyIcon(box, UDim2.fromOffset(20, 14))
	text({ Position = UDim2.fromOffset(70, 0), Size = UDim2.fromOffset(80, 58), TextSize = 20, FontFace = FONT_BOLD, Text = TEXT.Goals, Parent = box })
	self.goalsText = text({ Position = UDim2.fromOffset(140, 0), Size = UDim2.fromOffset(90, 58), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = box })

	-- One dot per shot of the series.
	local pips = frame({ Name = "Pips", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 70), Size = UDim2.fromOffset(234, 12), BackgroundTransparency = 1, Parent = holder })
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 7),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = pips,
	})
	self.pips = pips
	self.pipFrames = {}
end

function ShotHud:_buildPowerPanel()
	local root = panel({
		Name = "PowerPanel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(760, 140),
		Parent = self.gui,
	}, 20)
	self:_scaled(root)

	local iconBox = frame({ Position = UDim2.fromOffset(28, 38), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = Color3.fromRGB(22, 44, 38), Parent = root })
	corner(iconBox, 12)
	stroke(iconBox, WHITE, 1.5, 0.82)
	crosshairIcon(iconBox, UDim2.fromScale(0.5, 0.5))

	self.title = text({ Position = UDim2.fromOffset(116, 14), Size = UDim2.fromOffset(600, 32), TextSize = 25, Text = TEXT.Ready, Parent = root })

	local pill = frame({ Position = UDim2.fromOffset(116, 56), Size = UDim2.fromOffset(150, 36), BackgroundColor3 = INK, Parent = root })
	corner(pill, 10)
	stroke(pill, LIME, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 14), Parent = pill })
	self.powerText = text({ Size = UDim2.fromScale(1, 1), TextSize = 21, Text = string.format(TEXT.Power, 0), Parent = pill })

	local bar = frame({ Position = UDim2.fromOffset(282, 62), Size = UDim2.fromOffset(450, 24), BackgroundColor3 = Color3.fromRGB(38, 52, 49), Parent = root })
	corner(bar, 12)
	stroke(bar, Color3.fromRGB(200, 212, 206), 1.5, 0.35)
	-- Overpower zone marker (85%+): ball rises and is less accurate.
	frame({ Position = UDim2.new(0.85, 0, 0, 3), Size = UDim2.new(0, 2, 1, -6), BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, Parent = bar })
	-- CanvasGroup clips the stripes to the rounded fill.
	local fill = create("CanvasGroup", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = LIME, BorderSizePixel = 0, Parent = bar })
	corner(fill, 12)
	text({ Position = UDim2.fromOffset(-6, -4), Size = UDim2.fromOffset(470, 32), TextSize = 30, Text = string.rep("/", 48), TextColor3 = LIME_DARK, TextTransparency = 0.35, Parent = fill })
	self.powerFill = fill

	local info = circle(root, 16, { Position = UDim2.fromOffset(116, 105), BackgroundTransparency = 1 })
	stroke(info, MUTED, 1.2, 0.2)
	text({ Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11, FontFace = FONT_BOLD, TextColor3 = MUTED, Text = "i", Parent = info })
	text({ Position = UDim2.fromOffset(142, 102), Size = UDim2.fromOffset(500, 22), TextSize = 15, FontFace = FONT_MEDIUM, TextColor3 = MUTED, Text = TEXT.PowerHint, Parent = root })

	slashes(root, UDim2.fromOffset(640, 4), 30)
	slashes(root, UDim2.fromOffset(640, 104), 30)
end

function ShotHud:_buildCard()
	local card = panel({
		Name = "ResultCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(380, 186),
		Visible = false,
		Parent = self.gui,
	}, 20)
	self.cardScale = self:_scaled(card)
	ballBadge(card)
	slashes(card, UDim2.fromOffset(12, 8), 26)
	slashes(card, UDim2.fromOffset(306, 150), 26)

	self.cardTitle = text({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 60), TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })
	self.cardSubtitle = text({ Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 22), TextSize = 17, FontFace = FONT_MEDIUM, TextXAlignment = Enum.TextXAlignment.Center, Parent = card })

	local button = create("TextButton", {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.fromOffset(272, 50),
		BackgroundColor3 = LIME,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		FontFace = FONT_HEAVY,
		TextSize = 24,
		TextColor3 = INK,
		Text = TEXT.NextShot,
		Parent = card,
	})
	corner(button, 12)
	glow(button, 12, 0.8)
	self.button = button
	self.card = card
	self.onContinue = nil :: (() -> ())?
	button.Activated:Connect(function()
		self:_continue()
	end)
end

function ShotHud:_continue()
	if self.card.Visible and self.onContinue then
		self.onContinue()
	end
end

-- Called by keyboard / gamepad shortcuts.
function ShotHud:pressContinue()
	self:_continue()
end

function ShotHud:isCardVisible(): boolean
	return self.card.Visible
end

function ShotHud:setTitle(kind: string)
	self.title.Text = TEXT[kind] or kind
end

function ShotHud:setPower(power: number)
	local p = math.clamp(power, 0, 1)
	self.powerText.Text = string.format(TEXT.Power, math.floor(p * 100 + 0.5))
	self.powerFill.Size = UDim2.fromScale(p, 1)
	self.powerFill.BackgroundColor3 = if p >= 0.85 then Color3.fromRGB(250, 170, 40) else LIME
end

function ShotHud:setSeries(goals: number, seriesLength: number, history: { string })
	self.goalsText.Text = string.format('<font color="#A3E635">%d</font> / %d', goals, seriesLength)
	for i = #self.pipFrames + 1, seriesLength do
		local pip = circle(self.pips, 13, { LayoutOrder = i, BackgroundTransparency = 1 })
		create("UIStroke", { Color = MUTED, Thickness = 1.5, Transparency = 0.45, Parent = pip })
		self.pipFrames[i] = pip
	end
	for i, pip in self.pipFrames do
		local outcome = history[i]
		pip.Visible = i <= seriesLength
		pip.BackgroundColor3 = if outcome then PIP_COLORS[outcome] or MUTED else MUTED
		pip.BackgroundTransparency = if outcome then 0 else 1
	end
end

function ShotHud:bumpGoals()
	self.goalsScale.Scale = self.baseScale * 1.15
	TweenService:Create(self.goalsScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = self.baseScale }):Play()
end

-- kind: GOAL | SAVE | POST | BAR | WIDE | OVER
function ShotHud:showResult(kind: string, seriesText: string?)
	local info = TEXT.Outcomes[kind] or { kind, "" }
	self.cardTitle.Text = info[1]
	self.cardTitle.TextColor3 = OUTCOME_COLORS[kind] or WHITE
	self.cardSubtitle.Text = seriesText or info[2]
	self.button.Text = if seriesText then TEXT.NewSeries else TEXT.NextShot
	self.card.Visible = true
	self.cardScale.Scale = self.baseScale * 0.6
	TweenService:Create(self.cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = self.baseScale }):Play()
end

function ShotHud:seriesText(goals: number, seriesLength: number): string
	return string.format(TEXT.SeriesOver, goals, seriesLength)
end

function ShotHud:hideCard()
	self.card.Visible = false
end

return ShotHud
