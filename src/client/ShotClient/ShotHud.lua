-- Screen UI for the shot drill in the purple "pixel UI kit" style: logo + stage, goals counter,
-- bottom power panel and the result card. Layout is designed at 1280x720 and scaled per panel.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ImageLoader = require(script.Parent:WaitForChild("ImageLoader"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local ShotHud = {}
ShotHud.__index = ShotHud

-- Optional uploaded copy of the logo, e.g. "rbxassetid://1234567890". Empty = the logo PNG
-- embedded in Images/Logo.lua; the text wordmark is only used if images are unavailable.
local LOGO_IMAGE = ""

-- All player-facing text in one place.
local TEXT = {
	LogoTop = "NEW",
	LogoMiddle = "FOOTBALL",
	LogoBottom = "STAR",
	Mode = 'ОБУЧЕНИЕ  •  <font color="#FFBF1F">УДАРЫ</font>',
	ModePass = 'ОБУЧЕНИЕ  •  <font color="#FFBF1F">ПАС</font>',
	Stage = "Этап %d из 3",
	StageFree = "Обучение пройдено",
	Goals = "ГОЛЫ",
	Power = "СИЛА %d%%",
	PowerHint = "55–85% — удобно   ·   100% — мяч летит выше",
	Ready = "Зажми точку у ворот и отпусти для удара",
	Holding = "Отпусти, чтобы ударить",
	Flying = "Удар!",
	AfterShot = "Выбери точку удара и попробуй ещё",
	TutorialReady = "Повтори за пальцем: нажми на кружок и держи",
	TutorialHolding = "Отпусти, когда сила в зелёной зоне",
	PowerZone = "ЗОНА УДАРА",
	PassPowerZone = "ДО ПАРТНЁРА",
	PassPowerHint = "Сила = длина паса   ·   дальше партнёра — не удержит",
	PassReady = "Нажми и веди к партнёру, отпусти — пас",
	PassHolding = "Отпусти, чтобы отдать пас",
	PassFlying = "Пас!",
	PassAfter = "Выбери свободного партнёра",
	PassTutorialReady = "Повтори за пальцем: веди от мяча к партнёру",
	PassTutorialHolding = "Отпусти на партнёре",
	PassReceived = "Принял! Теперь удар",
	FollowUpReady = "Партнёр принял пас — бей по воротам!",
	FollowUpGoal = "Пас и гол! Осталось пасов: %d",
	FollowUpMiss = "Пас засчитан. Осталось пасов: %d",
	CompleteBonus = "Голов после паса: %d",
	NextShot = "ЕЩЁ УДАР  ›",
	Speed = "%d км/ч",
	-- Training
	GoalsTutorial = "ПОДСКАЗКА",
	GoalsTask = "ЗАДАНИЕ: ЗАБЕЙ %d",
	GoalsTaskPass = "ЗАДАНИЕ: %d ТОЧНЫХ ПАСОВ",
	PassTutorialDone = "Отличный пас! Теперь сделай %d точных пасов",
	PassLeft = "Осталось пасов: %d",
	GoalsFree = "ГОЛЫ / УДАРЫ",
	ModeFree = 'СВОБОДНАЯ ИГРА  •  <font color="#FFBF1F">УДАРЫ</font>',
	TutorialDone = "Так и бей! Теперь забей %d голов",
	ToTask = "К ЗАДАНИЮ  ›",
	TutorialRetry = "Попробуй ещё раз по подсказке",
	TaskLeft = "Осталось забить: %d",
	CompleteTitle = "ТРЕНИРОВКА\nПРОЙДЕНА!",
	CompleteSubtitle = "%d голов за %d ударов",
	CompleteSubtitlePass = "%d точных пасов за %d попыток",
	CompleteSpeed = "Лучший удар: %d км/ч",
	CompleteStage = "Этап %d из 3 пройден",
	PlayAgain = "ЕЩЁ РАЗ",
	Next = "ДАЛЕЕ  ›",
	Outcomes = {
		GOAL = { "ГОЛ!", "Отличное попадание в створ" },
		POST_IN = { "ГОЛ!", "От штанги в сетку!" },
		CATCH = { "ПОЙМАЛ!", "Вратарь забрал мяч. Бей ближе к углу" },
		PARRY = { "ОТБИЛ!", "Вратарь дотянулся. Ещё чуть точнее" },
		SAVE = { "СЕЙВ!", "Вратарь успел. Целься ближе к углу" },
		POST = { "ШТАНГА!", "Совсем рядом. Чуть ближе к центру" },
		BAR = { "ПЕРЕКЛАДИНА!", "Совсем рядом. Чуть ниже" },
		WIDE = { "МИМО!", "Мяч прошёл мимо ворот" },
		OVER = { "ВЫШЕ ВОРОТ!", "Слишком сильно. Сбавь силу" },
		PASS_GOOD = { "ТОЧНЫЙ ПАС!", "Партнёр принял мяч" },
		PASS_INTERCEPTED = { "ПЕРЕХВАТ!", "Защитник успел. Пасуй свободному или дождись момента" },
		PASS_TOO_HARD = { "СЛИШКОМ СИЛЬНО!", "Партнёр не удержал. Отпускай ближе к нему" },
		PASS_SHORT = { "НЕ ДОШЁЛ!", "Слабый пас. Веди палец до партнёра" },
		PASS_WIDE = { "МИМО!", "Пас ушёл мимо партнёра" },
	},
}

local C = UiKit.Colors
local rgb = Color3.fromRGB
local NAVY, PANEL_TOP, PANEL_BOTTOM, VIOLET, GLOW, LILAC = C.NAVY, C.PANEL_TOP, C.PANEL_BOTTOM, C.VIOLET, C.GLOW, C.LILAC
local RED, RED_LIGHT, GOLD, GOLD_LIGHT, LIME, ORANGE = C.RED, C.RED_LIGHT, C.GOLD, C.GOLD_LIGHT, C.LIME, C.ORANGE
local CREAM, INK, WHITE = C.CREAM, C.INK, C.WHITE

-- Card look per result kind: title gradient (top -> bottom), glow accent and badge glyph.
local KIND_STYLE = {
	GOAL = { top = CREAM, bottom = GOLD, accent = GOLD, icon = "⚽", sparkle = true },
	POST_IN = { top = CREAM, bottom = GOLD, accent = GOLD, icon = "⚽", sparkle = true },
	CATCH = { top = CREAM, bottom = LILAC, accent = GLOW, icon = "🧤" },
	PARRY = { top = CREAM, bottom = LILAC, accent = GLOW, icon = "🧤" },
	SAVE = { top = CREAM, bottom = LILAC, accent = GLOW, icon = "🧤" },
	POST = { top = GOLD_LIGHT, bottom = ORANGE, accent = ORANGE, icon = "🥅" },
	BAR = { top = GOLD_LIGHT, bottom = ORANGE, accent = ORANGE, icon = "🥅" },
	WIDE = { top = RED_LIGHT, bottom = RED, accent = RED, icon = "❌" },
	OVER = { top = RED_LIGHT, bottom = RED, accent = RED, icon = "❌" },
	PASS_GOOD = { top = CREAM, bottom = GOLD, accent = GOLD, icon = "👟", sparkle = true },
	PASS_INTERCEPTED = { top = CREAM, bottom = LILAC, accent = GLOW, icon = "✋" },
	PASS_TOO_HARD = { top = GOLD_LIGHT, bottom = ORANGE, accent = ORANGE, icon = "💨" },
	PASS_SHORT = { top = RED_LIGHT, bottom = RED, accent = RED, icon = "❌" },
	PASS_WIDE = { top = RED_LIGHT, bottom = RED, accent = RED, icon = "❌" },
}
local PIP_COLORS = { GOAL = GOLD, SAVE = GLOW, POST = CREAM, MISS = RED, GOOD = GOLD, INTERCEPTED = GLOW }

local FONT_HEAVY, FONT_BOLD, FONT_MEDIUM = UiKit.Fonts.HEAVY, UiKit.Fonts.BOLD, UiKit.Fonts.MEDIUM

local DESIGN_SIZE = Vector2.new(1280, 720)
-- Phone layout: screens whose short side is under PHONE_HEIGHT get PHONE_BOOST, limited so the
-- widest row (power panel) and the tallest panel (completion menu) still fit.
local PHONE_HEIGHT = 500
local PHONE_BOOST = 1.7
local PHONE_MIN_WIDTH = 680
local PHONE_MIN_HEIGHT = 400
local PHONE_LOGO = 0.8 -- the logo panel is decoration; on phones it gives its room to the goal
local PHONE_GOALS = 0.68 -- the goals panel sits over the pitch on phones, so it is drawn smaller
local POWER_SEGMENTS = 20
local POWER_WARN = 0.85

local create, frame, text, corner, stroke, outline = UiKit.create, UiKit.frame, UiKit.text, UiKit.corner, UiKit.stroke, UiKit.outline
local sizeLimit, bigText, setBigText, panel = UiKit.sizeLimit, UiKit.bigText, UiKit.setBigText, UiKit.panel
local iconBox, emoji, slashes = UiKit.iconBox, UiKit.emoji, UiKit.slashes

local function crosshairIcon(parent: Instance)
	local ring = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Parent = parent })
	corner(ring)
	stroke(ring, GOLD, 3)
	local dot = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = RED, Parent = ring })
	corner(dot, 1)
	for _, tick in { { 0.5, 0, 3, 10 }, { 0.5, 1, 3, 10 }, { 0, 0.5, 10, 3 }, { 1, 0.5, 10, 3 } } do
		frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(tick[1], tick[2]),
			Size = UDim2.fromOffset(tick[3], tick[4]),
			BackgroundColor3 = GOLD,
			Parent = ring,
		})
	end
end

-- Decorative "////" slashes from the reference panels.


local function logoImageId(): string?
	if LOGO_IMAGE == "" then
		return nil
	end
	return if string.match(LOGO_IMAGE, "^%d+$") then "rbxassetid://" .. LOGO_IMAGE else LOGO_IMAGE
end

-- "NEW / FOOTBALL / STAR ★" stacked and tilted, cream + red with gold swooshes.
local function buildWordmark(parent: Instance): Frame
	local tilt = frame({ Name = "Tilt", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = -8, BackgroundTransparency = 1, Parent = parent })
	swoosh(tilt, UDim2.new(0.5, 10, 0.5, 4), UDim2.fromOffset(296, 116), 5, -28)
	swoosh(tilt, UDim2.new(0.5, 18, 0.5, 8), UDim2.fromOffset(262, 96), 2, -20)

	bigText({ Name = "New", Text = TEXT.LogoTop, TextSize = 34, Position = UDim2.fromOffset(36, 4), Size = UDim2.fromOffset(120, 34), Parent = tilt }, 3, Vector2.new(3, 4))
	bigText({ Name = "Football", Text = TEXT.LogoMiddle, TextSize = 44, Position = UDim2.fromOffset(10, 34), Size = UDim2.fromOffset(276, 44), Parent = tilt }, 3.5, Vector2.new(3, 4))
	bigText({ Name = "Star", Text = TEXT.LogoBottom, TextSize = 50, TextColor3 = RED, Position = UDim2.fromOffset(46, 76), Size = UDim2.fromOffset(148, 48), Parent = tilt }, 4, Vector2.new(3, 4))

	local starHolder = frame({ Name = "StarIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(218, 98), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, Parent = tilt })
	bigText({ Text = "★", TextSize = 48, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = starHolder }, 3, Vector2.new(2, 3))
	return starHolder
end

function ShotHud.new()
	local self = setmetatable({}, ShotHud)
	self.text = TEXT -- shared with the entry script for training messages
	self.scales = {}
	self.onContinue = nil :: (() -> ())?
	self.onRetry = nil :: (() -> ())? -- completion menu buttons
	self.onNext = nil :: (() -> ())?
	self.scale = 1

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
	self:_buildCompleteMenu()

	-- Measured in GUI units (inside the safe area), so it matches what the panels are laid out in.
	local function rescale()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		local scale = math.min(size.X / DESIGN_SIZE.X, size.Y / DESIGN_SIZE.Y)
		local phone = math.min(size.X, size.Y) < PHONE_HEIGHT
		if phone then
			-- Phones: the design-size fit makes text tiny, so go bigger while everything still fits.
			scale = math.min(scale * PHONE_BOOST, (size.X - 40) / PHONE_MIN_WIDTH, (size.Y - 20) / PHONE_MIN_HEIGHT)
		end
		scale = math.clamp(scale, 0.5, 1.3)
		self.scale = scale
		for _, uiScale in self.scales do
			uiScale.Scale = scale
		end
		self.logoScale.Scale = if phone then scale * PHONE_LOGO else scale
		self.goalsScale.Scale = if phone then scale * PHONE_GOALS else scale
	end
	rescale()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	return self
end

-- Viewport scale for a top-level panel. Pop animations use their own nested UIScale.
function ShotHud:_scaled(target: GuiObject): UIScale
	local uiScale = create("UIScale", { Parent = target })
	table.insert(self.scales, uiScale)
	return uiScale
end

function ShotHud:_buildLogo()
	local root = frame({ Name = "Logo", Position = UDim2.fromOffset(14, 4), Size = UDim2.fromOffset(300, 196), BackgroundTransparency = 1, Parent = self.gui })
	self.logoScale = self:_scaled(root)

	local mark = frame({ Name = "Wordmark", Size = UDim2.fromOffset(300, 130), BackgroundTransparency = 1, Parent = root })
	local imageId = logoImageId()
	local embedded = if imageId then nil else ImageLoader.get("Logo/Logo")
	if imageId then
		create("ImageLabel", { Name = "LogoImage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Fit, Parent = mark })
	elseif embedded then
		create("ImageLabel", { Name = "LogoImage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageContent = embedded, ScaleType = Enum.ScaleType.Fit, Parent = mark })
	else
		local star = buildWordmark(mark)
		local starScale = create("UIScale", { Parent = star })
		TweenService:Create(starScale, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 }):Play()
	end

	local mode = frame({ Name = "Mode", Position = UDim2.fromOffset(8, 136), Size = UDim2.fromOffset(250, 30), BackgroundColor3 = NAVY, BackgroundTransparency = 0.1, Parent = root })
	corner(mode, 6)
	stroke(mode, VIOLET, 2)
	local accent = frame({ Name = "Accent", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(6, 14), BackgroundColor3 = RED, Parent = mode })
	corner(accent, 1)
	local modeText = text({ Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -30, 1, 0), Text = TEXT.Mode, TextSize = 16, Parent = mode })
	outline(modeText, 1.5)
	self.modeText = modeText

	local stage = text({ Name = "Stage", Position = UDim2.fromOffset(12, 172), Size = UDim2.fromOffset(112, 20), Text = string.format(TEXT.Stage, 1), TextSize = 15, FontFace = FONT_BOLD, TextTransparency = 0.15, Parent = root })
	sizeLimit(stage, 15)
	outline(stage, 1.5)
	self.stageText = stage
	self.stageDots = {}
	for i = 1, 3 do
		local current = i == 1
		local dot = frame({
			Name = "StageDot" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(134 + (i - 1) * 22, 182),
			Size = if current then UDim2.fromOffset(13, 13) else UDim2.fromOffset(10, 10),
			BackgroundColor3 = if current then GOLD else NAVY,
			Rotation = 45,
			Parent = root,
		})
		corner(dot, 2)
		self.stageDotStrokes = self.stageDotStrokes or {}
		self.stageDotStrokes[i] = stroke(dot, if current then INK else VIOLET, 2)
		self.stageDots[i] = dot
	end
end

function ShotHud:_buildGoals()
	local root = panel({ Name = "Goals", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14), Size = UDim2.fromOffset(292, 104) }, 10)
	root.Parent = self.gui
	self.goalsScale = self:_scaled(root)

	local trophy = iconBox(root, UDim2.fromOffset(14, 12), 50, GOLD)
	self.trophy = trophy
	emoji(trophy, "🏆", 28)

	local label
	label = text({ Name = "GoalsLabel", Position = UDim2.fromOffset(78, 10), Size = UDim2.fromOffset(150, 18), Text = TEXT.Goals, TextSize = 15, TextColor3 = LILAC, Parent = root })
	sizeLimit(label, 15)
	outline(label, 1.5)
	self.goalsLabel = label

	-- Centre-anchored holder so the bump scales around the number, not the panel corner.
	local countHolder = frame({ Name = "Count", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(76, 46), Size = UDim2.fromOffset(150, 36), BackgroundTransparency = 1, Parent = root })
	self.countScale = create("UIScale", { Parent = countHolder })
	self.goalsText = bigText({ Text = "0 / 10", TextSize = 32, Size = UDim2.fromScale(1, 1), Parent = countHolder }, 2.5, Vector2.new(2, 3))

	slashes(root, UDim2.fromOffset(222, 14), 22, GLOW)

	self.pips = frame({ Name = "Pips", Position = UDim2.fromOffset(14, 74), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Parent = root })
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Parent = self.pips,
	})
	self.pipFrames = {}
	self.pipStrokes = {}
end

function ShotHud:_buildPowerPanel()
	local root = panel({ Name = "PowerPanel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(680, 116) }, 12)
	root.Parent = self.gui
	self:_scaled(root)

	local icon = iconBox(root, UDim2.fromOffset(14, 16), 56, GOLD)
	crosshairIcon(icon)

	self.title = text({ Name = "Instruction", Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -100, 0, 28), Text = TEXT.Ready, TextSize = 20, Parent = root })
	sizeLimit(self.title, 20)
	outline(self.title, 2)
	self.titleKind = "Ready"

	local pill = frame({ Name = "PowerPill", Position = UDim2.fromOffset(84, 46), Size = UDim2.fromOffset(118, 28), BackgroundColor3 = NAVY, Parent = root })
	corner(pill, 6)
	self.pillStroke = stroke(pill, GOLD, 2)
	self.powerText = text({ Size = UDim2.fromScale(1, 1), Text = string.format(TEXT.Power, 0), TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Parent = pill })
	outline(self.powerText, 1.5)

	local track = frame({ Name = "PowerBar", Position = UDim2.fromOffset(214, 49), Size = UDim2.new(1, -230, 0, 22), BackgroundColor3 = NAVY, Parent = root })
	corner(track, 5)
	stroke(track, INK, 2)
	local segmentsFrame = frame({ Name = "Segments", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Parent = track })
	self.segments = {}
	self.segmentColors = {}
	self.segmentOff = {}
	for i = 1, POWER_SEGMENTS do
		local warn = (i - 1) / POWER_SEGMENTS >= POWER_WARN - 1e-6
		local seg = frame({
			Name = "Segment" .. i,
			Position = UDim2.new((i - 1) / POWER_SEGMENTS, 1, 0, 0),
			Size = UDim2.new(1 / POWER_SEGMENTS, -2, 1, 0),
			Parent = segmentsFrame,
		})
		corner(seg, 2)
		self.segments[i] = seg
		self.segmentColors[i] = if warn then RED else GOLD:Lerp(ORANGE, (i - 1) / (POWER_SEGMENTS * POWER_WARN))
		self.segmentOff[i] = if warn then rgb(74, 20, 48) else rgb(44, 28, 78)
		seg.BackgroundColor3 = self.segmentOff[i]
	end
	local zone = frame({
		Name = "PowerZone",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = LIME,
		BackgroundTransparency = 0.72,
		Visible = false,
		ZIndex = 2,
		Parent = track,
	})
	corner(zone, 4)
	stroke(zone, LIME, 2.5)
	local zoneLabel
	zoneLabel = text({
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 3),
		Size = UDim2.fromOffset(120, 16),
		Text = TEXT.PowerZone,
		TextSize = 13,
		TextColor3 = LIME,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = zone,
	})
	outline(zoneLabel, 1.5)
	self.powerZoneLabel = zoneLabel
	TweenService:Create(zone, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.45 }):Play()
	self.powerZone = zone

	local marker = frame({ Name = "WarnMarker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(POWER_WARN, 0.5), Size = UDim2.new(0, 4, 1, 12), BackgroundColor3 = CREAM, ZIndex = 2, Parent = track })
	corner(marker, 1)
	stroke(marker, INK, 1.5)

	local hint = text({ Name = "Hint", Position = UDim2.fromOffset(84, 84), Size = UDim2.new(1, -100, 0, 18), Text = TEXT.PowerHint, TextSize = 14, FontFace = FONT_MEDIUM, TextTransparency = 0.25, Parent = root })
	sizeLimit(hint, 14)
	self.powerHint = hint

	slashes(root, UDim2.new(1, -62, 0, 84), 18, GLOW)

	self.lastPercent = -1
	self.litCount = 0
	self.powerWarn = false
end

function ShotHud:_buildCompleteMenu()
	local root = frame({ Name = "TrainingComplete", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = self.gui })
	self.complete = root
	self.completeDim = frame({ Name = "Dim", Position = UDim2.fromOffset(-200, -120), Size = UDim2.new(1, 400, 1, 240), BackgroundColor3 = INK, BackgroundTransparency = 0.45, Parent = root })

	local holder = frame({ Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(500, 380), BackgroundTransparency = 1, Parent = root })
	self:_scaled(holder)
	local body, glows = panel({ Name = "Pop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, 16, GOLD)
	body.Parent = holder
	for _, g in glows do
		g.Color = GOLD
	end
	self.completePop = create("UIScale", { Parent = body })
	slashes(body, UDim2.fromOffset(16, 12), 24, GLOW)
	slashes(body, UDim2.new(1, -66, 0, 12), 24, GLOW)

	local badge = frame({ Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(84, 84), BackgroundTransparency = 1, ZIndex = 3, Parent = body })
	local diamond = frame({ Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), Rotation = 45, BackgroundColor3 = NAVY, Parent = badge })
	corner(diamond, 8)
	stroke(diamond, GOLD, 3.5)
	stroke(frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = diamond }), GOLD, 10, 0.75)
	emoji(badge, "🏆", 36)
	for _, side in { -1, 1 } do
		local sparkle = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * 66, 0.5, 6), Size = UDim2.fromOffset(28, 28), Text = "★", TextSize = 26, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })
		outline(sparkle, 2)
	end
	self.completeBadge = badge

	local title = bigText({ Name = "Title", Text = TEXT.CompleteTitle, TextSize = 46, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 50), Size = UDim2.new(1, -40, 0, 104), Parent = body }, 4, Vector2.new(0, 5), 46)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(CREAM, GOLD), Parent = title })

	self.completeSubtitle = text({ Name = "Subtitle", Position = UDim2.fromOffset(20, 160), Size = UDim2.new(1, -40, 0, 24), Text = "", TextSize = 20, FontFace = FONT_BOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	outline(self.completeSubtitle, 1.5)

	local balls = frame({ Name = "Balls", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 192), Size = UDim2.fromOffset(300, 36), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = balls })
	self.completeBalls = {}
	for i = 1, 8 do
		local ball = text({ Name = "Ball" .. i, LayoutOrder = i, Size = UDim2.fromOffset(34, 34), Text = "⚽", TextSize = 30, FontFace = FONT_MEDIUM, TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = balls })
		create("UIScale", { Parent = ball })
		self.completeBalls[i] = ball
	end

	local chips = frame({ Name = "Chips", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(460, 30), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	local function chip(order: number, icon: string, value: string, color: Color3): (Frame, TextLabel, TextLabel)
		local c = frame({ Name = "Chip", LayoutOrder = order, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = NAVY, Parent = chips })
		corner(c, 8)
		stroke(c, color, 2)
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = c })
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
		local iconLabel = text({ LayoutOrder = 1, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = icon, TextSize = 16, FontFace = FONT_MEDIUM, Parent = c })
		local label = text({ LayoutOrder = 2, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = value, TextSize = 16, Parent = c })
		outline(label, 1.5)
		return c, label, iconLabel
	end
	local _, stageChipText = chip(1, "✅", string.format(TEXT.CompleteStage, 1), LIME)
	self.completeStageText = stageChipText
	self.completeSpeed, self.completeSpeedText, self.completeSpeedIcon = chip(2, "⚡", "", GOLD)

	-- Two buttons: replay the task (secondary) and go on (primary).
	self.retryButton = self:_buildButton(body, TEXT.PlayAgain, function()
		self:_choose(self.onRetry)
	end, true)
	self.retryButton.button.Position = UDim2.new(0.5, -116, 0, 296)
	self.retryButton.button.Size = UDim2.fromOffset(212, 52)
	self.completeButton = self:_buildButton(body, TEXT.Next, function()
		self:_choose(self.onNext)
	end)
	self.completeButton.button.Position = UDim2.new(0.5, 116, 0, 296)
	self.completeButton.button.Size = UDim2.fromOffset(212, 52)
end

-- Gold primary button (or violet secondary). onActivated defaults to the result card's continue.
function ShotHud:_buildButton(parent: Instance, labelText: string, onActivated: (() -> ())?, secondary: boolean?)
	local parts = UiKit.button(parent, labelText, onActivated or function()
		self:_continue()
	end, if secondary then "violet" else "gold")
	parts.button.Name = "Continue"
	parts.button.Position = UDim2.new(0.5, 0, 0, 172)
	return parts
end

local playShine = UiKit.playShine

function ShotHud:_buildCard()
	local card = frame({
		Name = "ResultCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(400, 240),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
		Parent = self.gui,
	})
	self:_scaled(card)
	self.card = card

	local body, glows = panel({ Name = "Pop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, 14)
	body.Parent = card
	self.cardGlows = glows
	self.cardPop = create("UIScale", { Parent = body })

	slashes(body, UDim2.fromOffset(14, 10), 22, GLOW)
	slashes(body, UDim2.new(1, -62, 0, 10), 22, GLOW)

	-- Badge sitting on the top edge.
	local badge = frame({ Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 3, Parent = body })
	local diamond = frame({ Name = "Diamond", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), Rotation = 45, BackgroundColor3 = NAVY, Parent = badge })
	corner(diamond, 6)
	self.badgeStroke = stroke(diamond, GOLD, 3)
	self.badgeGlow = stroke(frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = diamond }), GOLD, 8, 0.8)
	self.badgeIcon = emoji(badge, "⚽", 26)
	self.badge = badge
	self.sparkles = {}
	for _, side in { -1, 1 } do
		local sparkle = text({
			Name = "Sparkle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, side * 52, 0.5, 4),
			Size = UDim2.fromOffset(24, 24),
			Text = "★",
			TextSize = 22,
			TextColor3 = GOLD,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = badge,
		})
		outline(sparkle, 2)
		table.insert(self.sparkles, sparkle)
	end

	local titleHolder = frame({ Name = "Title", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 66), Size = UDim2.new(1, -36, 0, 64), BackgroundTransparency = 1, Parent = body })
	self.titlePop = create("UIScale", { Parent = titleHolder })
	self.cardTitle = bigText({ Text = "", TextSize = 56, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = titleHolder }, 4, Vector2.new(0, 5), 56)
	-- The gradient tints the text white -> kind colour; the dark outline stays dark under any tint.
	self.titleGradient = create("UIGradient", { Rotation = 90, Parent = self.cardTitle })

	self.cardSubtitle = text({ Name = "Subtitle", Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 24), Text = "", TextSize = 18, FontFace = FONT_BOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(self.cardSubtitle, 18)
	outline(self.cardSubtitle, 1.5)

	local chip = frame({
		Name = "SpeedChip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = NAVY,
		Visible = false,
		Parent = body,
	})
	corner(chip, 8)
	stroke(chip, GOLD, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12), Parent = chip })
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = chip,
	})
	text({ Name = "Bolt", LayoutOrder = 1, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = "⚡", TextSize = 16, FontFace = FONT_MEDIUM, Parent = chip })
	self.speedText = text({ Name = "Value", LayoutOrder = 2, Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextSize = 17, Parent = chip })
	outline(self.speedText, 1.5)
	self.speedChip = chip

	local parts = self:_buildButton(body, TEXT.NextShot)
	self.cardButton = parts
	self.button = parts.button
	self.buttonLabel = parts.label
end

function ShotHud:_continue()
	if self.card.Visible and self.onContinue then
		self.onContinue()
	end
end

function ShotHud:_choose(callback: (() -> ())?)
	if self.complete.Visible and callback then
		callback()
	end
end

-- Called by keyboard / gamepad shortcuts: the primary button of whatever is open.
function ShotHud:pressContinue()
	if self.complete.Visible then
		self:_choose(self.onNext)
	else
		self:_continue()
	end
end

function ShotHud:isCardVisible(): boolean
	return self.card.Visible or self.complete.Visible
end

-- kind: Ready | Holding | Flying | AfterShot. Called every frame while aiming, so it skips repeats.
function ShotHud:setTitle(kind: string)
	if self.titleKind == kind then
		return
	end
	self.titleKind = kind
	self.title.Text = TEXT[kind] or kind
end

-- Called every frame while aiming: only touches properties that actually changed.
function ShotHud:setPower(power: number)
	local p = math.clamp(power, 0, 1)
	local percent = math.floor(p * 100 + 0.5)
	if percent == self.lastPercent then
		return
	end
	self.lastPercent = percent
	self.powerText.Text = string.format(TEXT.Power, percent)

	local lit = math.clamp(math.ceil(p * POWER_SEGMENTS - 1e-6), 0, POWER_SEGMENTS)
	if lit ~= self.litCount then
		local from, to = math.min(lit, self.litCount) + 1, math.max(lit, self.litCount)
		for i = from, to do
			self.segments[i].BackgroundColor3 = if i <= lit then self.segmentColors[i] else self.segmentOff[i]
		end
		self.litCount = lit
	end

	local warn = p >= POWER_WARN
	if warn ~= self.powerWarn then
		self.powerWarn = warn
		self.pillStroke.Color = if warn then RED else GOLD
		self.powerText.TextColor3 = if warn then RED_LIGHT else CREAM
	end
end

-- goals: big number; seriesLength: number of result pips; history: outcome per pip.
-- total: number after the slash (defaults to seriesLength).
function ShotHud:setSeries(goals: number, seriesLength: number, history: { string }?, total: number?)
	local shots = history or {}
	setBigText(self.goalsText, string.format('<font color="#FFBF1F">%d</font> / %d', goals, total or seriesLength))

	for i = #self.pipFrames + 1, seriesLength do
		local pip = frame({ Name = "Pip" .. i, LayoutOrder = i, Size = UDim2.fromOffset(18, 18), BackgroundColor3 = NAVY, Parent = self.pips })
		corner(pip, 4)
		self.pipStrokes[i] = stroke(pip, VIOLET, 2)
		self.pipFrames[i] = pip
	end

	local nextIndex = #shots + 1
	for i, pip in self.pipFrames do
		local outcome = shots[i]
		pip.Visible = i <= seriesLength
		pip.BackgroundColor3 = if outcome then PIP_COLORS[outcome] or CREAM else NAVY
		local s = self.pipStrokes[i]
		s.Color = if outcome then INK elseif i == nextIndex then CREAM else VIOLET
		s.Transparency = 0
	end

	-- Gentle pulse on the outline of the shot about to be taken.
	if self.pulseIndex ~= nextIndex then
		if self.pulseTween then
			self.pulseTween:Cancel()
		end
		self.pulseTween = nil
		self.pulseIndex = nextIndex
		local s = self.pipStrokes[nextIndex]
		if s and nextIndex <= seriesLength then
			self.pulseTween = TweenService:Create(s, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 })
			self.pulseTween:Play()
		end
	end
end

function ShotHud:bumpGoals()
	self.countScale.Scale = 1.45
	TweenService:Create(self.countScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	self.trophy.Rotation = -18
	TweenService:Create(self.trophy, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
end

-- kind: GOAL | POST_IN | CATCH | PARRY | POST | BAR | WIDE | OVER
-- options: subtitle (replaces the outcome tip), button (label), speedKmh
function ShotHud:showResult(kind: string, options: { subtitle: string?, button: string?, speedKmh: number? }?)
	local style = KIND_STYLE[kind] or KIND_STYLE.WIDE
	local info = TEXT.Outcomes[kind] or { kind, "" }
	options = options or {}

	setBigText(self.cardTitle, info[1])
	self.titleGradient.Color = ColorSequence.new(style.top, style.bottom)
	self.cardSubtitle.Text = options.subtitle or info[2]
	self.buttonLabel.Text = options.button or TEXT.NextShot

	local speed = options.speedKmh
	local hasChip = type(speed) == "number" and speed > 0
	self.speedChip.Visible = hasChip
	if hasChip then
		self.speedText.Text = string.format(TEXT.Speed, math.floor(speed + 0.5))
	end
	-- Without the chip the card closes up around the button.
	self.card.Size = UDim2.fromOffset(400, if hasChip then 240 else 206)
	self.button.Position = UDim2.new(0.5, 0, 0, if hasChip then 172 else 138)

	for _, s in self.cardGlows do
		s.Color = style.accent
	end
	self.badgeStroke.Color = style.accent
	self.badgeGlow.Color = style.accent
	self.badgeIcon.Text = style.icon
	for _, sparkle in self.sparkles do
		sparkle.Visible = style.sparkle == true
	end

	self.card.Visible = true
	self.cardPop.Scale = 0.55
	TweenService:Create(self.cardPop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	self.titlePop.Scale = 1.5
	TweenService:Create(self.titlePop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.08), { Scale = 1 }):Play()
	self.badge.Rotation = -120
	TweenService:Create(self.badge, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	playShine(self.cardButton)
end

function ShotHud:hideCard()
	self.card.Visible = false
	self.cardButton.shineTween:Cancel()
	self.complete.Visible = false
	self.completeButton.shineTween:Cancel()
	self.retryButton.shineTween:Cancel()
end

-- Stage dots: done = lime, current = gold and larger, still to come = dark. stage 4 = all done.
function ShotHud:_setStage(stage: number)
	for i, dot in self.stageDots do
		local done, current = i < stage, i == stage
		dot.BackgroundColor3 = if done then LIME elseif current then GOLD else NAVY
		dot.Size = if current then UDim2.fromOffset(13, 13) else UDim2.fromOffset(10, 10)
		self.stageDotStrokes[i].Color = if done or current then INK else VIOLET
	end
	self.stageText.Text = if stage > 3 then TEXT.StageFree else string.format(TEXT.Stage, stage)
end

-- Labels for the current part of the training. stage: SHOT | PASS | FREE; mode: TUTORIAL | TASK
-- | FREE (of the stage); kind: what the player is doing now, SHOT or PASS (power bar texts).
function ShotHud:setMode(stage: string, mode: string, taskGoals: number, kind: string)
	local pass = stage == "PASS"
	if stage == "FREE" then
		self.goalsLabel.Text = TEXT.GoalsFree
	elseif mode == "TUTORIAL" then
		self.goalsLabel.Text = TEXT.GoalsTutorial
	else
		self.goalsLabel.Text = string.format(if pass then TEXT.GoalsTaskPass else TEXT.GoalsTask, taskGoals)
	end
	self.modeText.Text = if stage == "FREE" then TEXT.ModeFree elseif pass then TEXT.ModePass else TEXT.Mode
	local passing = kind == "PASS"
	self.powerHint.Text = if passing then TEXT.PassPowerHint else TEXT.PowerHint
	self.powerZoneLabel.Text = if passing then TEXT.PassPowerZone else TEXT.PowerZone
	self:_setStage(if stage == "FREE" then 4 elseif pass then 2 else 1)
end

-- Highlights the power range that the guided shot asks for (nil hides it).
function ShotHud:setPowerZone(min: number?, max: number?)
	local zone = self.powerZone
	-- The zone label sits where the general power tip is, so they take turns.
	self.powerHint.Visible = not (min and max)
	if not (min and max) then
		zone.Visible = false
		return
	end
	zone.Position = UDim2.fromScale(min, 0.5)
	zone.Size = UDim2.new(max - min, 0, 1, 10)
	zone.Visible = true
end

-- Completion menu after a task is done. stats: { kind, goals, shots, bestSpeed, bonusGoals }
function ShotHud:showComplete(stats: { kind: string, goals: number, shots: number, bestSpeed: number?, bonusGoals: number? })
	self.card.Visible = false
	self.cardButton.shineTween:Cancel()
	local stage = if stats.kind == "PASS" then 2 else 1
	self.completeSubtitle.Text = string.format(if stats.kind == "PASS" then TEXT.CompleteSubtitlePass else TEXT.CompleteSubtitle, stats.goals, stats.shots)
	self.completeStageText.Text = string.format(TEXT.CompleteStage, stage)
	-- Second chip: the fastest goal (shot stage) or goals scored after passes (pass stage).
	if stats.kind == "PASS" then
		self.completeSpeed.Visible = true
		self.completeSpeedIcon.Text = "⚽"
		self.completeSpeedText.Text = string.format(TEXT.CompleteBonus, stats.bonusGoals or 0)
	else
		local hasSpeed = type(stats.bestSpeed) == "number" and stats.bestSpeed > 0
		self.completeSpeed.Visible = hasSpeed
		self.completeSpeedIcon.Text = "⚡"
		if hasSpeed then
			self.completeSpeedText.Text = string.format(TEXT.CompleteSpeed, math.floor(stats.bestSpeed + 0.5))
		end
	end
	for i, ball in self.completeBalls do
		ball.Visible = i <= stats.goals
	end
	self:_setStage(stage + 1)

	self.complete.Visible = true
	self.completeDim.BackgroundTransparency = 1
	TweenService:Create(self.completeDim, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()
	self.completePop.Scale = 0.5
	TweenService:Create(self.completePop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for i, ball in self.completeBalls do
		local holderScale = ball:FindFirstChildOfClass("UIScale")
		holderScale.Scale = 0
		TweenService:Create(holderScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.25 + i * 0.09), { Scale = 1 }):Play()
	end
	self.completeBadge.Rotation = -140
	TweenService:Create(self.completeBadge, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	playShine(self.completeButton)
	self.retryButton.body.Position = UDim2.fromOffset(0, 0)
end

return ShotHud
