-- Menus the player sees before and after the training: main menu (new career / continue /
-- settings), club choice, player creation with the 3D preview, the contract, settings, dialogs and
-- the "training complete" screen. Built with UiKit so it matches the training HUD; the 3D side
-- (camera, showroom player) is MenuScene. All career changes go through the server
-- (Remotes.CareerRequest); this only shows and asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CareerConfig = require(Shared:WaitForChild("CareerConfig"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local ImageLoader = require(script.Parent:WaitForChild("ImageLoader"))
local MenuScene = require(script.Parent:WaitForChild("MenuScene"))

local C = UiKit.Colors
local F = UiKit.Fonts
local create, frame, text, corner, stroke, outline = UiKit.create, UiKit.frame, UiKit.text, UiKit.corner, UiKit.stroke, UiKit.outline
local sizeLimit, bigText, panel = UiKit.sizeLimit, UiKit.bigText, UiKit.panel

local TEXT = {
	Tagline = "КАРЬЕРА ФУТБОЛИСТА",
	NewCareer = "НОВАЯ КАРЬЕРА",
	Continue = "ПРОДОЛЖИТЬ",
	Settings = "НАСТРОЙКИ",
	NoCareer = "Сохранённой карьеры пока нет",
	CareerLine = "%s %s  ·  #%d  ·  %s  ·  %s",
	Stages = { SHOT = "обучение: удар", PASS = "обучение: пас", DONE = "ждёт первый матч" },
	SaveOn = "☁  Прогресс сохраняется",
	SaveOff = "⚠  Сохранение недоступно: прогресс только до выхода из игры",
	Back = "‹  НАЗАД",
	ChooseClub = "ВЫБЕРИ КЛУБ",
	LeagueLine = "%s  ·  %s  ·  8 клубов",
	YourRating = "ТВОЙ РЕЙТИНГ  <font color=\"#FFBF1F\">%d</font>",
	ClubsHint = "Тебе предлагают контракт <font color=\"#AAF028\">3 клуба</font>. Расти в рейтинге — и топ-клубы позовут тебя.",
	Choose = "ВЫБРАТЬ  ›",
	Offer = "ПРЕДЛАГАЕТ КОНТРАКТ",
	Locked = "🔒  РЕЙТИНГ %d+",
	Ovr = "СИЛА %d",
	CreateTitle = "СОЗДАЙ ИГРОКА",
	FirstName = "ИМЯ",
	LastName = "ФАМИЛИЯ",
	FirstPlaceholder = "Например, Иван",
	LastPlaceholder = "Например, Петров",
	Number = "НОМЕР НА ФУТБОЛКЕ",
	Turn = "↻",
	Confirm = "ПОДТВЕРДИТЬ  ›",
	ShirtPlaceholder = "ИГРОК",
	ContractTitle = "КОНТРАКТ",
	ContractLine = "#%d  ·  Нападающий  ·  Рейтинг %d",
	ContractNote = "Сначала короткое обучение: удар и пас.\nПотом первый матч за клуб.",
	Edit = "ИЗМЕНИТЬ",
	Sign = "ПОДПИСАТЬ  ✍",
	SettingsTitle = "НАСТРОЙКИ",
	SettingNames = { shake = "Тряска камеры", effects = "Эффекты и конфетти", aimLine = "Линия полёта мяча" },
	SettingOrder = { "shake", "effects", "aimLine" },
	DeleteCareer = "УДАЛИТЬ КАРЬЕРУ",
	Done = "ГОТОВО",
	NewCareerTitle = "НОВАЯ КАРЬЕРА?",
	NewCareerText = "Текущая карьера (%s, %s) будет заменена новой.",
	DeleteTitle = "УДАЛИТЬ КАРЬЕРУ?",
	DeleteText = "%s, %s: весь прогресс будет удалён.",
	Yes = "ДА",
	Cancel = "ОТМЕНА",
	DoneTitle = "ОБУЧЕНИЕ\nПРОЙДЕНО!",
	DoneSubtitle = "Ты готов к первому матчу за %s",
	Soon = "СКОРО",
	MatchNote = "Первый матч появится в следующем обновлении",
	ToMenu = "В ГЛАВНОЕ МЕНЮ",
	Retrain = "ПРОЙТИ ОБУЧЕНИЕ ЕЩЁ РАЗ",
	Failed = "Не получилось: %s",
	NoConnection = "Сервер не ответил, попробуй ещё раз",
}

local MenuFlow = {}
MenuFlow.__index = MenuFlow

-- ---------------------------------------------------------------- small widgets

-- Club badge: rounded shield in the club's colours with a diagonal stripe and the short name.
local function crest(parent: Instance, club, size: number, position: UDim2?, anchor: Vector2?): Frame
	local holder = frame({ Name = "Crest", AnchorPoint = anchor or Vector2.new(0.5, 0), Position = position or UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(size, size * 1.1), BackgroundTransparency = 1, Parent = parent })
	local group = create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = club.shirt, BorderSizePixel = 0, Parent = holder })
	create("UICorner", { CornerRadius = UDim.new(0.22, 0), Parent = group })
	frame({ Name = "Stripe", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.28, 0, 2, 0), Rotation = 32, BackgroundColor3 = club.trim, BackgroundTransparency = 0.15, Parent = group })
	frame({ Name = "Shade", Position = UDim2.fromScale(0, 0.62), Size = UDim2.fromScale(1, 0.38), BackgroundColor3 = C.INK, BackgroundTransparency = 0.75, Parent = group })
	local edge = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder })
	create("UICorner", { CornerRadius = UDim.new(0.22, 0), Parent = edge })
	stroke(edge, C.INK, math.max(2, size / 28))
	local label = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.9, 0.36), Text = club.short, TextScaled = true, TextColor3 = C.WHITE, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder })
	outline(label, math.max(1.5, size / 30))
	local star = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromScale(0.3, 0.26), Text = "★", TextScaled = true, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = holder })
	outline(star, math.max(1, size / 40))
	return holder
end

-- Row of five stars, value in 0.5 steps; the half star is split with a hard gradient.
local function starRow(parent: Instance, value: number, height: number, position: UDim2, anchor: Vector2?): Frame
	local row = frame({ Name = "Stars", AnchorPoint = anchor or Vector2.new(0.5, 0), Position = position, Size = UDim2.fromOffset(height * 5.4, height), BackgroundTransparency = 1, Parent = parent })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, height * 0.08), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	for i = 1, 5 do
		local star = text({ LayoutOrder = i, Size = UDim2.fromOffset(height, height), Text = "★", TextScaled = true, TextColor3 = C.WHITE, TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		outline(star, 1.5)
		local fill = math.clamp(value - (i - 1), 0, 1)
		local dim = Color3.fromRGB(64, 44, 110)
		if fill >= 1 then
			star.TextColor3 = C.GOLD
		elseif fill <= 0 then
			star.TextColor3 = dim
		else
			create("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, C.GOLD),
					ColorSequenceKeypoint.new(0.5, C.GOLD),
					ColorSequenceKeypoint.new(0.501, dim),
					ColorSequenceKeypoint.new(1, dim),
				}),
				Parent = star,
			})
		end
	end
	return row
end

-- Small pill with text.
local function chip(parent: Instance, value: string, color: Color3, position: UDim2, height: number, anchor: Vector2?): (Frame, TextLabel)
	local c = frame({ Name = "Chip", AnchorPoint = anchor or Vector2.new(0.5, 0), Position = position, Size = UDim2.fromOffset(0, height), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.NAVY, BackgroundTransparency = 0.05, Parent = parent })
	corner(c, 7)
	stroke(c, color, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = c })
	local label = text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = value, TextSize = math.floor(height * 0.56), TextColor3 = color, FontFace = F.BOLD, Parent = c })
	outline(label, 1.2)
	return c, label
end

-- Text field in the kit's style.
local function field(parent: Instance, title: string, placeholder: string, y: number): (TextBox, UIStroke)
	local label = text({ Position = UDim2.fromOffset(24, y), Size = UDim2.fromOffset(300, 20), Text = title, TextSize = 15, TextColor3 = C.LILAC, FontFace = F.BOLD, Parent = parent })
	outline(label, 1.2)
	local box = frame({ Position = UDim2.fromOffset(24, y + 24), Size = UDim2.new(1, -48, 0, 50), BackgroundColor3 = C.NAVY, Parent = parent })
	corner(box, 9)
	local s = stroke(box, C.VIOLET, 2.5)
	local input = create("TextBox", {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Text = "",
		PlaceholderText = placeholder,
		PlaceholderColor3 = Color3.fromRGB(120, 100, 170),
		FontFace = F.HEAVY,
		TextSize = 24,
		TextColor3 = C.CREAM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	input.Focused:Connect(function()
		s.Color = C.GOLD
	end)
	input.FocusLost:Connect(function()
		s.Color = C.VIOLET
	end)
	return input, s
end

-- Small square button (−, +, quick numbers, dice, turn).
local function smallButton(parent: Instance, label: string, position: UDim2, size: Vector2, onClick: () -> (), color: Color3?): TextButton
	local b = create("TextButton", {
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color or Color3.fromRGB(43, 18, 80),
		AutoButtonColor = true,
		FontFace = F.HEAVY,
		Text = label,
		TextSize = math.floor(size.Y * 0.5),
		TextColor3 = C.CREAM,
		Parent = parent,
	})
	corner(b, 8)
	stroke(b, C.INK, 2.5)
	local inner = create("UIStroke", { Color = C.VIOLET, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b })
	inner.Transparency = 1
	b.Activated:Connect(onClick)
	return b
end

-- On / off switch.
local function toggle(parent: Instance, y: number, title: string, on: boolean, onChange: (boolean) -> ())
	local row = frame({ Position = UDim2.fromOffset(24, y), Size = UDim2.new(1, -48, 0, 46), BackgroundColor3 = C.NAVY, BackgroundTransparency = 0.2, Parent = parent })
	corner(row, 9)
	local label = text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -110, 1, 0), Text = title, TextSize = 19, FontFace = F.BOLD, Parent = row })
	outline(label, 1.2)
	local track = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(64, 30), Text = "", AutoButtonColor = false, BackgroundColor3 = C.LIME, Parent = row })
	corner(track)
	stroke(track, C.INK, 2)
	local knob = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.WHITE, Parent = track })
	corner(knob)
	stroke(knob, C.INK, 2)
	local state = on
	local function render(animated: boolean)
		local info = TweenInfo.new(if animated then 0.15 else 0, Enum.EasingStyle.Quad)
		TweenService:Create(knob, info, { Position = UDim2.fromScale(if state then 0.72 else 0.28, 0.5) }):Play()
		TweenService:Create(track, info, { BackgroundColor3 = if state then C.LIME else Color3.fromRGB(64, 44, 110) }):Play()
	end
	render(false)
	track.Activated:Connect(function()
		state = not state
		render(true)
		onChange(state)
	end)
	return function(value: boolean)
		state = value
		render(false)
	end
end

local function pop(target: Instance, from: number?)
	local s = target:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = target })
	s.Scale = from or 0.7
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- ---------------------------------------------------------------- construction

function MenuFlow.new(remote: RemoteFunction, callbacks: { onTraining: (any) -> (), onSettings: (any) -> () })
	local self = setmetatable({}, MenuFlow)
	self.remote = remote
	self.callbacks = callbacks
	self.state = nil -- last answer from the server: { career, settings, saveAvailable }
	self.busy = false
	self.scene = MenuScene.new()
	self.holders = {} -- { frame, minWidth, minHeight, uiScale } for the phone-aware scale
	self.draft = { clubId = nil, firstName = "", lastName = "", number = 10 }

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Backdrop: full-bleed darkening behind the panels (the 3D scene shows through).
	self.backdrop = create("ScreenGui", { Name = "MenuBackdrop", ResetOnSpawn = false, IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, DisplayOrder = 8, Enabled = false, Parent = playerGui })
	local shade = frame({ Name = "LeftShade", Size = UDim2.fromScale(0.62, 1), BackgroundColor3 = C.INK, Parent = self.backdrop })
	create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = shade })
	self.leftShade = shade
	local fullShade = frame({ Name = "FullShade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.INK, BackgroundTransparency = 0.45, Visible = false, Parent = self.backdrop })
	self.fullShade = fullShade
	local bottom = frame({ Name = "BottomShade", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = C.INK, Parent = self.backdrop })
	create("UIGradient", { Rotation = -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }), Parent = bottom })

	self.gui = create("ScreenGui", { Name = "Menus", ResetOnSpawn = false, IgnoreGuiInset = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9, Enabled = false, Parent = playerGui })

	self.screens = {}
	self:_buildMain()
	self:_buildClubs()
	self:_buildCreator()
	self:_buildDone()
	self:_buildContract()
	self:_buildSettings()
	self:_buildConfirm()
	self:_buildToast()

	local function rescale()
		local size = self.gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			return
		end
		for _, h in self.holders do
			local scale = UiKit.fitScale(size, h.minWidth, h.minHeight)
			h.uiScale.Scale = scale
		end
		self:_layoutRail(size)
	end
	self.rescale = rescale
	self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	task.defer(rescale)

	RunService.RenderStepped:Connect(function(dt)
		self.scene:update(dt)
	end)
	return self
end

-- A frame laid out at design size that scales with the screen (see UiKit.fitScale).
function MenuFlow:_holder(parent: Instance, name: string, props: { [string]: any }, minWidth: number, minHeight: number): Frame
	props.Name = name
	props.BackgroundTransparency = 1
	props.Parent = parent
	local h = frame(props)
	local s = create("UIScale", { Parent = h })
	table.insert(self.holders, { frame = h, minWidth = minWidth, minHeight = minHeight, uiScale = s })
	return h
end

function MenuFlow:_screen(name: string): Frame
	local s = frame({ Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = self.gui })
	self.screens[name] = s
	return s
end

-- Back button + title, top left.
function MenuFlow:_topBar(screen: Frame, title: string, onBack: () -> ()): (Frame, TextLabel)
	local bar = self:_holder(screen, "TopBar", { Position = UDim2.fromOffset(24, 16), Size = UDim2.fromOffset(900, 90) }, 760, 560)
	local back = UiKit.button(bar, TEXT.Back, onBack, "dark", 20)
	back.button.AnchorPoint = Vector2.new(0, 0)
	back.button.Position = UDim2.fromOffset(0, 8)
	back.button.Size = UDim2.fromOffset(150, 50)
	local heading = bigText({ Name = "Title", Position = UDim2.fromOffset(176, 0), Size = UDim2.fromOffset(700, 52), Text = title, TextSize = 46, Parent = bar }, 3.5, Vector2.new(3, 4), 46)
	return bar, heading
end

function MenuFlow:_buildMain()
	local screen = self:_screen("Main")
	local column = self:_holder(screen, "Column", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(460, 600) }, 520, 620)

	local logoHolder = frame({ Name = "Logo", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(440, 220), BackgroundTransparency = 1, Parent = column })
	local logo = ImageLoader.get("Logo/Logo")
	if logo then
		create("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ImageContent = logo, ScaleType = Enum.ScaleType.Fit, Parent = logoHolder })
	else
		local mark = bigText({ Size = UDim2.fromScale(1, 0.7), Text = 'NEW FOOTBALL <font color="#FF2D55">STAR</font>', TextSize = 54, TextXAlignment = Enum.TextXAlignment.Center, Parent = logoHolder }, 4, Vector2.new(3, 5), 54)
		mark.TextWrapped = true
	end
	self.mainLogo = logoHolder
	local tagline = text({ Position = UDim2.fromOffset(0, 222), Size = UDim2.fromOffset(440, 26), Text = TEXT.Tagline, TextSize = 20, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = column })
	outline(tagline, 2)

	local function place(parts, y: number)
		parts.button.AnchorPoint = Vector2.new(0.5, 0)
		parts.button.Position = UDim2.new(0, 220, 0, y)
		parts.button.Size = UDim2.fromOffset(400, 66)
	end
	self.newButton = UiKit.button(column, TEXT.NewCareer, function()
		self:_onNewCareer()
	end, "gold", 28)
	place(self.newButton, 270)
	self.continueButton = UiKit.button(column, TEXT.Continue, function()
		self:_onContinue()
	end, "violet", 28)
	place(self.continueButton, 352)
	self.careerLine = text({ Position = UDim2.fromOffset(10, 422), Size = UDim2.fromOffset(420, 22), Text = "", TextSize = 16, FontFace = F.BOLD, TextColor3 = C.LILAC, TextXAlignment = Enum.TextXAlignment.Center, Parent = column })
	sizeLimit(self.careerLine, 16)
	outline(self.careerLine, 1.5)
	self.settingsButton = UiKit.button(column, TEXT.Settings, function()
		self:_openSettings()
	end, "dark", 26)
	place(self.settingsButton, 458)
	self.saveLine = text({ Position = UDim2.fromOffset(0, 548), Size = UDim2.fromOffset(440, 20), Text = "", TextSize = 14, FontFace = F.MEDIUM, TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center, Parent = column })
	sizeLimit(self.saveLine, 14)
	self.mainColumn = column
end

function MenuFlow:_buildClubs()
	local screen = self:_screen("Clubs")
	local bar = self:_topBar(screen, TEXT.ChooseClub, function()
		self:showMain()
	end)
	local league = text({ Position = UDim2.fromOffset(178, 54), Size = UDim2.fromOffset(500, 22), Text = string.format(TEXT.LeagueLine, CareerConfig.League, CareerConfig.Season), TextSize = 17, FontFace = F.BOLD, TextColor3 = C.LILAC, Parent = bar })
	outline(league, 1.5)

	local rating = self:_holder(screen, "Rating", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 24), Size = UDim2.fromOffset(240, 44) }, 760, 560)
	local _, ratingLabel = chip(rating, string.format(TEXT.YourRating, CareerConfig.PlayerStartOvr), C.GOLD, UDim2.new(1, 0, 0, 0), 40, Vector2.new(1, 0))
	ratingLabel.TextColor3 = C.CREAM

	-- Horizontal rail of club cards (swipe / scroll); cards are resized with the screen.
	local rail = create("ScrollingFrame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.GLOW,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Parent = screen,
	})
	self.railLayout = create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = rail })
	self.railPadding = create("UIPadding", { Parent = rail })
	self.rail = rail
	self.cards = {}
	for i, club in CareerConfig.Clubs do
		self.cards[club.id] = self:_buildCard(rail, club, i)
	end

	local footer = self:_holder(screen, "Footer", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(1100, 70) }, 760, 560)
	local hint = text({ Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -340, 1, 0), Text = TEXT.ClubsHint, TextSize = 18, FontFace = F.BOLD, TextWrapped = true, Parent = footer })
	sizeLimit(hint, 18)
	outline(hint, 1.5)
	self.chooseButton = UiKit.button(footer, TEXT.Choose, function()
		if self.draft.clubId then
			self:showCreator()
		end
	end, "gold", 26)
	self.chooseButton.button.AnchorPoint = Vector2.new(1, 0.5)
	self.chooseButton.button.Position = UDim2.new(1, 0, 0.5, 0)
	self.chooseButton.button.Size = UDim2.fromOffset(300, 64)
end

local CARD = Vector2.new(232, 330)
local CARD_GAP = 18

function MenuFlow:_buildCard(rail: Instance, club, order: number)
	local slot = frame({ Name = "Card" .. club.id, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.fromOffset(CARD.X, CARD.Y), Parent = rail })
	local content = frame({ Name = "Content", Size = UDim2.fromOffset(CARD.X, CARD.Y), BackgroundTransparency = 1, Parent = slot })
	local scale = create("UIScale", { Parent = content })
	local body, glows = panel({ Name = "Body", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -8, 1, -8) }, 14, if club.open then C.GLOW else Color3.fromRGB(70, 50, 110))
	body.Parent = content
	local pick = create("UIScale", { Parent = body })

	crest(body, club, 92, UDim2.new(0.5, 0, 0, 30))
	local name = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.new(1, -24, 0, 54), Text = string.upper(club.name), TextSize = 22, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(name, 22)
	outline(name, 2)
	starRow(body, club.stars, 26, UDim2.new(0.5, 0, 0, 200))
	chip(body, string.format(TEXT.Ovr, club.ovr), C.LILAC, UDim2.new(0.5, 0, 0, 236), 26)
	local status
	if club.open then
		status = chip(body, TEXT.Offer, C.LIME, UDim2.new(0.5, 0, 0, 276), 28)
	else
		status = chip(body, string.format(TEXT.Locked, club.unlockOvr or 99), Color3.fromRGB(150, 135, 190), UDim2.new(0.5, 0, 0, 276), 28)
		-- Dimmed: visible goal, not a choice yet.
		local veil = frame({ Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.INK, BackgroundTransparency = 0.42, ZIndex = 5, Parent = body })
		corner(veil, 14)
		status.ZIndex = 6
		for _, d in status:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 6
			end
		end
	end

	local hit = create("TextButton", { Name = "Hit", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 10, Parent = body })
	hit.Activated:Connect(function()
		if club.open then
			self:_selectClub(club.id)
		else
			pop(body, 0.94)
			self:toast(string.format("%s: нужен рейтинг %d. У тебя пока %d.", club.name, club.unlockOvr or 99, CareerConfig.PlayerStartOvr))
		end
	end)
	return { slot = slot, content = content, scale = scale, body = body, glows = glows, pick = pick, club = club }
end

function MenuFlow:_layoutRail(size: Vector2)
	local scale = UiKit.fitScale(size, 760, 560)
	local top = 110 * scale + 16
	local bottom = 100 * scale
	local height = math.max(120, size.Y - top - bottom)
	local cardScale = math.min(scale, height / (CARD.Y + 10))
	self.rail.Position = UDim2.fromOffset(0, top)
	self.rail.Size = UDim2.new(1, 0, 0, height)
	self.railLayout.Padding = UDim.new(0, CARD_GAP * cardScale)
	self.railPadding.PaddingLeft = UDim.new(0, 24)
	self.railPadding.PaddingRight = UDim.new(0, 24)
	for _, card in self.cards do
		card.slot.Size = UDim2.fromOffset(CARD.X * cardScale, CARD.Y * cardScale)
		card.scale.Scale = cardScale
	end
end

function MenuFlow:_selectClub(id: string)
	self.draft.clubId = id
	for cardId, card in self.cards do
		local selected = cardId == id
		for _, g in card.glows do
			g.Color = if selected then C.GOLD elseif card.club.open then C.GLOW else Color3.fromRGB(70, 50, 110)
		end
		card.pick.Scale = if selected then 1.04 else 1
	end
	pop(self.cards[id].body, 0.92)
	self.cards[id].pick.Scale = 1.04
	UiKit.setEnabled(self.chooseButton, true)
	self.chooseButton.label.Text = TEXT.Choose
	UiKit.playShine(self.chooseButton)
	local club = CareerConfig.club(id)
	if club then
		self.scene:showPlayer(club.id, CareerConfig.kit(club), self:_shirtName(), self.draft.number, club.trim, false)
	end
end

function MenuFlow:_buildCreator()
	local screen = self:_screen("Creator")
	self:_topBar(screen, TEXT.CreateTitle, function()
		self:showClubs()
	end)
	local holder = self:_holder(screen, "Form", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -16), Size = UDim2.fromOffset(500, 540) }, 560, 660)
	local body = panel({ Name = "Body", Size = UDim2.fromScale(1, 1) }, 16)
	body.Parent = holder
	self.creatorBody = body

	-- Club line.
	self.creatorCrestHolder = frame({ Position = UDim2.fromOffset(24, 18), Size = UDim2.fromOffset(46, 50), BackgroundTransparency = 1, Parent = body })
	self.creatorClub = text({ Position = UDim2.fromOffset(82, 16), Size = UDim2.new(1, -100, 0, 28), Text = "", TextSize = 24, Parent = body })
	sizeLimit(self.creatorClub, 24)
	outline(self.creatorClub, 2)
	self.creatorStarsHolder = frame({ Position = UDim2.fromOffset(82, 46), Size = UDim2.fromOffset(120, 22), BackgroundTransparency = 1, Parent = body })

	self.firstBox, self.firstStroke = field(body, TEXT.FirstName, TEXT.FirstPlaceholder, 84)
	self.lastBox, self.lastStroke = field(body, TEXT.LastName, TEXT.LastPlaceholder, 168)
	self.nameError = text({ Position = UDim2.fromOffset(24, 248), Size = UDim2.new(1, -48, 0, 20), Text = "", TextSize = 15, FontFace = F.BOLD, TextColor3 = C.RED_LIGHT, Parent = body })
	outline(self.nameError, 1.2)

	local numberTitle = text({ Position = UDim2.fromOffset(24, 272), Size = UDim2.fromOffset(300, 20), Text = TEXT.Number, TextSize = 15, TextColor3 = C.LILAC, FontFace = F.BOLD, Parent = body })
	outline(numberTitle, 1.2)
	smallButton(body, "−", UDim2.fromOffset(24, 298), Vector2.new(58, 58), function()
		self:_setNumber(if self.draft.number <= CareerConfig.NumberMin then CareerConfig.NumberMax else self.draft.number - 1)
	end)
	local numberBox = frame({ Position = UDim2.fromOffset(92, 298), Size = UDim2.fromOffset(120, 58), BackgroundColor3 = C.NAVY, Parent = body })
	corner(numberBox, 9)
	stroke(numberBox, C.GOLD, 2.5)
	self.numberLabel = bigText({ Size = UDim2.fromScale(1, 1), Text = "10", TextSize = 40, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = numberBox }, 3, Vector2.new(2, 3))
	self.numberBox = numberBox
	smallButton(body, "+", UDim2.fromOffset(222, 298), Vector2.new(58, 58), function()
		self:_setNumber(if self.draft.number >= CareerConfig.NumberMax then CareerConfig.NumberMin else self.draft.number + 1)
	end)
	smallButton(body, "🎲", UDim2.fromOffset(290, 298), Vector2.new(58, 58), function()
		self:_setNumber(math.random(CareerConfig.NumberMin, CareerConfig.NumberMax))
	end)
	smallButton(body, TEXT.Turn, UDim2.new(1, -82, 0, 298), Vector2.new(58, 58), function()
		self.scene:turn()
	end, Color3.fromRGB(58, 30, 110))
	for i, n in CareerConfig.QuickNumbers do
		smallButton(body, tostring(n), UDim2.fromOffset(24 + (i - 1) * 74, 368), Vector2.new(64, 42), function()
			self:_setNumber(n)
		end)
	end

	self.confirmButton = UiKit.button(body, TEXT.Confirm, function()
		self:_openContract()
	end, "gold", 26)
	self.confirmButton.button.Position = UDim2.new(0.5, 0, 0, 446)
	self.confirmButton.button.Size = UDim2.fromOffset(440, 66)

	local function onText()
		self.draft.firstName = self.firstBox.Text
		self.draft.lastName = self.lastBox.Text
		self:_validateDraft(false)
		self.scene:setShirt(self:_shirtName(), self.draft.number, false)
		self.scene:faceBack()
	end
	self.firstBox:GetPropertyChangedSignal("Text"):Connect(onText)
	self.lastBox:GetPropertyChangedSignal("Text"):Connect(onText)
	for _, box in { self.firstBox, self.lastBox } do
		box.FocusLost:Connect(function()
			self:_validateDraft(true)
			self.scene:setShirt(self:_shirtName(), self.draft.number, true)
		end)
	end
end

function MenuFlow:_shirtName(): string
	local name = CareerConfig.shirtName(self.draft.firstName, self.draft.lastName)
	return if name == "" then TEXT.ShirtPlaceholder else name
end

function MenuFlow:_setNumber(n: number)
	self.draft.number = n
	UiKit.setBigText(self.numberLabel, tostring(n))
	pop(self.numberBox, 0.8)
	self.scene:setShirt(self:_shirtName(), n, true)
end

-- showErrors: also flag empty fields (after leaving a field / pressing confirm).
function MenuFlow:_validateDraft(showErrors: boolean): boolean
	local first, firstError = CareerConfig.validateName(self.draft.firstName)
	local last, lastError = CareerConfig.validateName(self.draft.lastName)
	local message = ""
	local firstBad = not first and (showErrors or self.draft.firstName ~= "")
	local lastBad = not last and (showErrors or self.draft.lastName ~= "")
	if firstBad then
		message = TEXT.FirstName .. ": " .. (firstError or "")
	elseif lastBad then
		message = TEXT.LastName .. ": " .. (lastError or "")
	end
	self.nameError.Text = message
	self.firstStroke.Color = if firstBad then C.RED else C.VIOLET
	self.lastStroke.Color = if lastBad then C.RED else C.VIOLET
	local ok = first ~= nil and last ~= nil
	UiKit.setEnabled(self.confirmButton, ok)
	return ok
end

function MenuFlow:_buildContract()
	local screen = self:_screen("Contract")
	local holder = self:_holder(screen, "Card", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0), Size = UDim2.fromOffset(500, 470) }, 560, 520)
	local body = panel({ Name = "Body", Size = UDim2.fromScale(1, 1) }, 16, C.GOLD)
	body.Parent = holder
	self.contractBody = body
	local title = bigText({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 48), Text = TEXT.ContractTitle, TextSize = 42, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, 3.5, Vector2.new(0, 4), 42)
	title.Name = "Title"
	self.contractCrest = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 78), Size = UDim2.fromOffset(84, 92), BackgroundTransparency = 1, Parent = body })
	self.contractClub = text({ Position = UDim2.fromOffset(20, 176), Size = UDim2.new(1, -40, 0, 26), Text = "", TextSize = 22, TextColor3 = C.LILAC, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	outline(self.contractClub, 1.5)
	self.contractName = bigText({ Position = UDim2.fromOffset(20, 208), Size = UDim2.new(1, -40, 0, 46), Text = "", TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, 3, Vector2.new(0, 4), 38)
	self.contractLine = text({ Position = UDim2.fromOffset(20, 260), Size = UDim2.new(1, -40, 0, 24), Text = "", TextSize = 19, FontFace = F.BOLD, TextColor3 = C.GOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	outline(self.contractLine, 1.5)
	local note = text({ Position = UDim2.fromOffset(30, 294), Size = UDim2.new(1, -60, 0, 50), Text = TEXT.ContractNote, TextSize = 16, FontFace = F.MEDIUM, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(note, 16)
	local edit = UiKit.button(body, TEXT.Edit, function()
		self:showCreator(true)
	end, "dark", 22)
	edit.button.AnchorPoint = Vector2.new(0, 0)
	edit.button.Position = UDim2.fromOffset(24, 372)
	edit.button.Size = UDim2.fromOffset(170, 64)
	self.signButton = UiKit.button(body, TEXT.Sign, function()
		self:_sign()
	end, "gold", 26)
	self.signButton.button.AnchorPoint = Vector2.new(1, 0)
	self.signButton.button.Position = UDim2.new(1, -24, 0, 372)
	self.signButton.button.Size = UDim2.fromOffset(270, 64)
end

function MenuFlow:_buildDone()
	local screen = self:_screen("Done")
	local holder = self:_holder(screen, "Card", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 0), Size = UDim2.fromOffset(520, 560) }, 580, 600)
	local body = panel({ Name = "Body", Size = UDim2.fromScale(1, 1) }, 16, C.GOLD)
	body.Parent = holder
	self.doneBody = body
	local title = bigText({ Position = UDim2.fromOffset(20, 24), Size = UDim2.new(1, -40, 0, 112), Text = TEXT.DoneTitle, TextSize = 50, TextColor3 = C.WHITE, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, 4, Vector2.new(0, 5), 50)
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.CREAM, C.GOLD), Parent = title })
	self.doneSubtitle = text({ Position = UDim2.fromOffset(20, 146), Size = UDim2.new(1, -40, 0, 26), Text = "", TextSize = 20, FontFace = F.BOLD, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(self.doneSubtitle, 20)
	outline(self.doneSubtitle, 1.5)

	-- Next match card.
	local match = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 188), Size = UDim2.fromOffset(440, 150), BackgroundColor3 = C.NAVY, Parent = body })
	corner(match, 12)
	stroke(match, C.VIOLET, 2)
	self.doneHome = frame({ Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(80, 88), BackgroundTransparency = 1, Parent = match })
	self.doneAway = frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -40, 0, 20), Size = UDim2.fromOffset(80, 88), BackgroundTransparency = 1, Parent = match })
	bigText({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(120, 50), Text = "VS", TextSize = 44, TextColor3 = C.CREAM, TextXAlignment = Enum.TextXAlignment.Center, Parent = match }, 3, Vector2.new(2, 3))
	chip(match, TEXT.Soon, C.GOLD, UDim2.new(0.5, 0, 0, 96), 28)
	self.doneMatchNames = text({ Position = UDim2.fromOffset(10, 120), Size = UDim2.new(1, -20, 0, 22), Text = "", TextSize = 15, FontFace = F.BOLD, TextColor3 = C.LILAC, TextXAlignment = Enum.TextXAlignment.Center, Parent = match })
	sizeLimit(self.doneMatchNames, 15)
	local note = text({ Position = UDim2.fromOffset(20, 348), Size = UDim2.new(1, -40, 0, 22), Text = TEXT.MatchNote, TextSize = 15, FontFace = F.MEDIUM, TextTransparency = 0.15, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(note, 15)

	self.toMenuButton = UiKit.button(body, TEXT.ToMenu, function()
		self:showMain()
	end, "gold", 26)
	self.toMenuButton.button.Position = UDim2.new(0.5, 0, 0, 386)
	self.toMenuButton.button.Size = UDim2.fromOffset(440, 66)
	local retrain = UiKit.button(body, TEXT.Retrain, function()
		self:_run("retrain")
	end, "dark", 20)
	retrain.button.Position = UDim2.new(0.5, 0, 0, 466)
	retrain.button.Size = UDim2.fromOffset(440, 58)
end

-- Modal panel in the middle of the screen with a dimmed background.
function MenuFlow:_modal(name: string, size: Vector2, glow: Color3?): (Frame, Frame)
	local layer = frame({ Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 50, Parent = self.gui })
	local blocker = create("TextButton", { Name = "Blocker", Position = UDim2.fromOffset(-400, -200), Size = UDim2.new(1, 800, 1, 400), BackgroundColor3 = C.INK, BackgroundTransparency = 0.4, AutoButtonColor = false, Text = "", Parent = layer })
	blocker.ZIndex = 50
	local holder = self:_holder(layer, "Holder", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), ZIndex = 51 }, size.X + 40, size.Y + 40)
	local body = panel({ Name = "Body", Size = UDim2.fromScale(1, 1) }, 16, glow)
	body.Parent = holder
	return layer, body
end

function MenuFlow:_buildSettings()
	local layer, body = self:_modal("Settings", Vector2.new(520, 470))
	self.settingsLayer = layer
	self.settingsBody = body
	bigText({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 46), Text = TEXT.SettingsTitle, TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, 3.5, Vector2.new(0, 4), 40)
	self.toggles = {}
	for i, key in TEXT.SettingOrder do
		self.toggles[key] = toggle(body, 84 + (i - 1) * 58, TEXT.SettingNames[key], CareerConfig.DefaultSettings[key], function(value)
			self:_setSetting(key, value)
		end)
	end
	self.settingsSave = text({ Position = UDim2.fromOffset(24, 264), Size = UDim2.new(1, -48, 0, 22), Text = "", TextSize = 14, FontFace = F.MEDIUM, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	sizeLimit(self.settingsSave, 14)
	self.deleteButton = UiKit.button(body, TEXT.DeleteCareer, function()
		self:_onDelete()
	end, "dark", 20)
	self.deleteButton.button.Position = UDim2.new(0.5, 0, 0, 300)
	self.deleteButton.button.Size = UDim2.fromOffset(440, 56)
	self.deleteButton.label.TextColor3 = C.RED_LIGHT
	local done = UiKit.button(body, TEXT.Done, function()
		self.settingsLayer.Visible = false
	end, "gold", 26)
	done.button.Position = UDim2.new(0.5, 0, 0, 376)
	done.button.Size = UDim2.fromOffset(440, 64)
	self.settingsDone = done
end

function MenuFlow:_buildConfirm()
	local layer, body = self:_modal("Confirm", Vector2.new(500, 290), C.RED)
	self.confirmLayer = layer
	self.confirmTitle = bigText({ Position = UDim2.fromOffset(20, 22), Size = UDim2.new(1, -40, 0, 44), Text = "", TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, Parent = body }, 3, Vector2.new(0, 4), 36)
	self.confirmText = text({ Position = UDim2.fromOffset(30, 80), Size = UDim2.new(1, -60, 0, 84), Text = "", TextSize = 19, FontFace = F.BOLD, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = body })
	sizeLimit(self.confirmText, 19)
	outline(self.confirmText, 1.2)
	local cancel = UiKit.button(body, TEXT.Cancel, function()
		self.confirmLayer.Visible = false
	end, "dark", 22)
	cancel.button.AnchorPoint = Vector2.new(0, 0)
	cancel.button.Position = UDim2.fromOffset(24, 196)
	cancel.button.Size = UDim2.fromOffset(212, 64)
	self.confirmYes = UiKit.button(body, TEXT.Yes, function()
		self.confirmLayer.Visible = false
		local action = self.confirmAction
		self.confirmAction = nil
		if action then
			action()
		end
	end, "gold", 24)
	self.confirmYes.button.AnchorPoint = Vector2.new(1, 0)
	self.confirmYes.button.Position = UDim2.new(1, -24, 0, 196)
	self.confirmYes.button.Size = UDim2.fromOffset(212, 64)
end

function MenuFlow:_buildToast()
	local holder = self:_holder(self.gui, "Toast", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(640, 56), Visible = false, ZIndex = 80 }, 680, 400)
	local body = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.NAVY, BackgroundTransparency = 0.05, ZIndex = 80, Parent = holder })
	corner(body, 12)
	stroke(body, C.GOLD, 2.5)
	self.toastLabel = text({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 1, 0), Text = "", TextSize = 18, FontFace = F.BOLD, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 81, Parent = body })
	sizeLimit(self.toastLabel, 18)
	outline(self.toastLabel, 1.2)
	self.toastHolder = holder
end

-- ---------------------------------------------------------------- behaviour

function MenuFlow:toast(message: string)
	self.toastLabel.Text = message
	self.toastHolder.Visible = true
	pop(self.toastHolder, 0.85)
	local token = {}
	self.toastToken = token
	task.delay(3, function()
		if self.toastToken == token then
			self.toastHolder.Visible = false
		end
	end)
end

-- Asks first; onYes runs when the player agrees.
function MenuFlow:confirm(title: string, message: string, yes: string?, onYes: () -> ())
	UiKit.setBigText(self.confirmTitle, title)
	self.confirmText.Text = message
	self.confirmYes.label.Text = yes or TEXT.Yes
	self.confirmAction = onYes
	self.confirmLayer.Visible = true
	pop(self.confirmLayer:FindFirstChild("Holder") :: Frame, 0.8)
	UiKit.playShine(self.confirmYes)
end

-- Calls the server; returns its answer or nil (and shows why) on failure.
function MenuFlow:_request(action: string, payload: any?): any?
	local ok, result = pcall(function()
		return self.remote:InvokeServer(action, payload)
	end)
	if not ok or type(result) ~= "table" then
		self:toast(TEXT.NoConnection)
		return nil
	end
	if not result.ok then
		self:toast(string.format(TEXT.Failed, tostring(result.error)))
		return nil
	end
	self.state = result
	if result.settings then
		self.callbacks.onSettings(result.settings)
	end
	return result
end

-- Runs a request that may start the training (continue / create / retrain).
function MenuFlow:_run(action: string, payload: any?)
	if self.busy then
		return
	end
	self.busy = true
	local result = self:_request(action, payload)
	self.busy = false
	if not result then
		return
	end
	if result.mode == "TRAINING" then
		self:close()
		self.callbacks.onTraining(result)
	elseif result.mode == "DONE" then
		self:showDone()
	end
end

function MenuFlow:_show(name: string)
	for screenName, screen in self.screens do
		screen.Visible = screenName == name
	end
	self.settingsLayer.Visible = false
	self.confirmLayer.Visible = false
	self.leftShade.Visible = name ~= "Clubs"
	self.fullShade.Visible = name == "Clubs"
end

-- Opens the menus (first start, or back from the training) on the main menu.
function MenuFlow:open()
	self.backdrop.Enabled = true
	self.gui.Enabled = true
	self.scene:setActive(true)
	self:showMain()
end

function MenuFlow:close()
	self.backdrop.Enabled = false
	self.gui.Enabled = false
	self.scene:setActive(false)
end

function MenuFlow:isOpen(): boolean
	return self.gui.Enabled
end

function MenuFlow:_careerClub()
	local career = self.state and self.state.career
	return career, career and CareerConfig.club(career.clubId)
end

function MenuFlow:showMain()
	self:_show("Main")
	self.scene:cheer(false)
	if not self.state then
		self:_request("get")
	end
	local career, club = self:_careerClub()
	UiKit.setEnabled(self.continueButton, career ~= nil)
	if career and club then
		self.careerLine.Text = string.format(TEXT.CareerLine, career.firstName, career.lastName, career.number, club.name, TEXT.Stages[career.tutorialStage] or "")
		self.scene:setView("showroom")
		self.scene:showPlayer(club.id, CareerConfig.kit(club), CareerConfig.shirtName(career.firstName, career.lastName), career.number, club.trim, false)
	else
		self.careerLine.Text = TEXT.NoCareer
		self.scene:hidePlayer()
		self.scene:setView("stadium")
	end
	local saving = self.state == nil or self.state.saveAvailable
	self.saveLine.Text = if saving then TEXT.SaveOn else TEXT.SaveOff
	self.saveLine.TextColor3 = if saving then C.LILAC else C.GOLD_LIGHT
	pop(self.mainColumn, 0.92)
	UiKit.playShine(self.newButton)
	if career then
		UiKit.playShine(self.continueButton)
	end
end

function MenuFlow:_onNewCareer()
	local career, club = self:_careerClub()
	if career and club then
		self:confirm(TEXT.NewCareerTitle, string.format(TEXT.NewCareerText, career.firstName .. " " .. career.lastName, club.name), TEXT.Yes, function()
			self:showClubs()
		end)
	else
		self:showClubs()
	end
end

function MenuFlow:_onContinue()
	if self.state and self.state.career then
		self:_run("continue")
	end
end

function MenuFlow:showClubs()
	self:_show("Clubs")
	self.scene:setView("stadium")
	self.scene:hidePlayer()
	if not self.draft.clubId then
		UiKit.setEnabled(self.chooseButton, false)
	end
	if self.draft.clubId then
		self:_selectClub(self.draft.clubId)
	end
	self.rescale()
end

-- keepDraft: back from the contract (names stay as typed).
function MenuFlow:showCreator(keepDraft: boolean?)
	local club = CareerConfig.club(self.draft.clubId)
	if not club then
		self:showClubs()
		return
	end
	self:_show("Creator")
	self.scene:setView("showroom")
	for _, child in self.creatorCrestHolder:GetChildren() do
		child:Destroy()
	end
	for _, child in self.creatorStarsHolder:GetChildren() do
		child:Destroy()
	end
	crest(self.creatorCrestHolder, club, 46, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
	starRow(self.creatorStarsHolder, club.stars, 20, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
	self.creatorClub.Text = string.upper(club.name)
	if not keepDraft then
		self.firstBox.Text = self.draft.firstName
		self.lastBox.Text = self.draft.lastName
	end
	UiKit.setBigText(self.numberLabel, tostring(self.draft.number))
	self:_validateDraft(false)
	-- New entrance when coming from the club list; just the shirt when coming back from the contract.
	self.scene:showPlayer(club.id, CareerConfig.kit(club), self:_shirtName(), self.draft.number, club.trim, not keepDraft)
	pop(self.creatorBody, 0.92)
end

function MenuFlow:_openContract()
	if not self:_validateDraft(true) then
		return
	end
	local club = CareerConfig.club(self.draft.clubId)
	if not club then
		return
	end
	self:_show("Contract")
	for _, child in self.contractCrest:GetChildren() do
		child:Destroy()
	end
	crest(self.contractCrest, club, 84, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
	self.contractClub.Text = string.upper(club.name)
	local first = CareerConfig.validateName(self.draft.firstName) or ""
	local last = CareerConfig.validateName(self.draft.lastName) or ""
	UiKit.setBigText(self.contractName, first .. " " .. last)
	self.contractLine.Text = string.format(TEXT.ContractLine, self.draft.number, CareerConfig.PlayerStartOvr)
	pop(self.contractBody, 0.85)
	UiKit.playShine(self.signButton)
	self.scene:faceBack()
end

function MenuFlow:_sign()
	if self.busy then
		return
	end
	self.scene:cheer(true)
	self:_run("create", {
		clubId = self.draft.clubId,
		firstName = self.draft.firstName,
		lastName = self.draft.lastName,
		number = self.draft.number,
	})
	self.scene:cheer(false)
end

function MenuFlow:showDone()
	local career, club = self:_careerClub()
	if not (career and club) then
		self:showMain()
		return
	end
	self:_show("Done")
	self.scene:setView("showroom")
	self.scene:showPlayer(club.id, CareerConfig.kit(club), CareerConfig.shirtName(career.firstName, career.lastName), career.number, club.trim, false)
	self.scene:cheer(true)
	self.doneSubtitle.Text = string.format(TEXT.DoneSubtitle, club.name)
	-- First opponent: the next club in the league list.
	local opponent = CareerConfig.Clubs[1]
	for i, c in CareerConfig.Clubs do
		if c.id == club.id then
			opponent = CareerConfig.Clubs[i % #CareerConfig.Clubs + 1]
		end
	end
	for _, holder in { self.doneHome, self.doneAway } do
		for _, child in holder:GetChildren() do
			child:Destroy()
		end
	end
	crest(self.doneHome, club, 80, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
	crest(self.doneAway, opponent, 80, UDim2.fromOffset(0, 0), Vector2.new(0, 0))
	self.doneMatchNames.Text = club.name .. "  —  " .. opponent.name
	pop(self.doneBody, 0.8)
	UiKit.playShine(self.toMenuButton)
end

-- After the training: refresh the career (stage saved by the server) and show the result.
function MenuFlow:openDone()
	self.backdrop.Enabled = true
	self.gui.Enabled = true
	self.scene:setActive(true)
	self:_request("get")
	self:showDone()
end

function MenuFlow:_openSettings()
	local settings = (self.state and self.state.settings) or CareerConfig.DefaultSettings
	for key, set in self.toggles do
		set(settings[key] ~= false)
	end
	local career = self.state and self.state.career
	self.deleteButton.button.Visible = career ~= nil
	local saving = self.state == nil or self.state.saveAvailable
	self.settingsSave.Text = if saving then TEXT.SaveOn else TEXT.SaveOff
	self.settingsLayer.Visible = true
	pop(self.settingsLayer:FindFirstChild("Holder") :: Frame, 0.85)
	UiKit.playShine(self.settingsDone)
end

function MenuFlow:_setSetting(key: string, value: boolean)
	if self.state and self.state.settings then
		self.state.settings[key] = value
		self.callbacks.onSettings(self.state.settings)
	end
	task.spawn(function()
		self:_request("settings", { key = key, value = value })
	end)
end

function MenuFlow:_onDelete()
	local career, club = self:_careerClub()
	if not (career and club) then
		return
	end
	self:confirm(TEXT.DeleteTitle, string.format(TEXT.DeleteText, career.firstName .. " " .. career.lastName, club.name), TEXT.DeleteCareer, function()
		if self:_request("reset") then
			self:showMain()
		end
	end)
end

return MenuFlow
