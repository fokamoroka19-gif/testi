-- Shared look of every screen (training HUD and menus): the purple "pixel UI kit" palette,
-- Montserrat fonts, outlined text, glowing panels, the chunky gold/violet buttons and the
-- phone-aware UI scaling.

local TweenService = game:GetService("TweenService")

local UiKit = {}

local rgb = Color3.fromRGB
local NAVY = rgb(18, 11, 36)
local PANEL_TOP = rgb(43, 18, 80)
local PANEL_BOTTOM = rgb(27, 15, 51)
local VIOLET = rgb(90, 47, 194)
local GLOW = rgb(123, 77, 255)
local LILAC = rgb(190, 168, 255)
local RED = rgb(255, 45, 85)
local RED_LIGHT = rgb(255, 150, 170)
local GOLD = rgb(255, 191, 31)
local GOLD_LIGHT = rgb(255, 226, 120)
local LIME = rgb(170, 240, 40)
local ORANGE = rgb(255, 159, 10)
local LIP = rgb(178, 84, 0)
local CREAM = rgb(247, 236, 214)
local INK = rgb(18, 6, 31)
local SHADOW = rgb(46, 16, 92)
local WHITE = Color3.new(1, 1, 1)
local LIP_VIOLET = rgb(40, 16, 96)
local DARK_LIP = rgb(10, 5, 22)

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local FONT_HEAVY = Font.new(MONTSERRAT, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local FONT_BOLD = Font.new(MONTSERRAT, Enum.FontWeight.Bold, Enum.FontStyle.Italic)
local FONT_MEDIUM = Font.new(MONTSERRAT, Enum.FontWeight.Medium)

UiKit.Colors = {
	NAVY = NAVY,
	PANEL_TOP = PANEL_TOP,
	PANEL_BOTTOM = PANEL_BOTTOM,
	VIOLET = VIOLET,
	GLOW = GLOW,
	LILAC = LILAC,
	RED = RED,
	RED_LIGHT = RED_LIGHT,
	GOLD = GOLD,
	GOLD_LIGHT = GOLD_LIGHT,
	LIME = LIME,
	ORANGE = ORANGE,
	LIP = LIP,
	CREAM = CREAM,
	INK = INK,
	SHADOW = SHADOW,
	WHITE = WHITE,
}
UiKit.Fonts = { HEAVY = FONT_HEAVY, BOLD = FONT_BOLD, MEDIUM = FONT_MEDIUM }

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
	props.TextColor3 = props.TextColor3 or CREAM
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return create("TextLabel", props)
end

local function corner(parent: Instance, radius: number?)
	create("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0), Parent = parent })
end

-- Border stroke for frames and buttons.
local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return create("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Text outline; mitred joins keep the chunky pixel-kit corners.
local function outline(label: TextLabel, thickness: number, color: Color3?): UIStroke
	return create("UIStroke", {
		Color = color or INK,
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Miter,
		Parent = label,
	})
end

local function sizeLimit(label: TextLabel, maxSize: number)
	label.TextScaled = true
	create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
end

-- Outlined text with a hard drop shadow (a sibling label, so it cannot be a child of the text).
local shadowOf = setmetatable({}, { __mode = "k" })

local function bigText(props: { [string]: any }, thickness: number, offset: Vector2, maxSize: number?): TextLabel
	local shadowProps = table.clone(props)
	shadowProps.Name = (props.Name or "Text") .. "Shadow"
	shadowProps.TextColor3 = SHADOW
	shadowProps.Position = (props.Position or UDim2.new()) + UDim2.fromOffset(offset.X, offset.Y)
	shadowProps.Text = string.gsub(props.Text or "", "<[^>]+>", "")
	local shadow = text(shadowProps)
	outline(shadow, thickness)
	local main = text(table.clone(props))
	outline(main, thickness)
	if maxSize then
		sizeLimit(shadow, maxSize)
		sizeLimit(main, maxSize)
	end
	shadowOf[main] = shadow
	return main
end

local function setBigText(label: TextLabel, value: string)
	label.Text = value
	local shadow = shadowOf[label]
	if shadow then
		shadow.Text = string.gsub(value, "<[^>]+>", "")
	end
end

-- Dark purple panel: vertical gradient, violet border and a soft glow from stacked strokes.
-- Returns the root and its glow strokes so callers can recolour them.
local function panel(props: { [string]: any }, radius: number, glowColor: Color3?): (Frame, { UIStroke })
	props.BackgroundTransparency = 1
	local root = frame(props)
	local glows = {}
	for _, layer in { { 4, 0.7 }, { 9, 0.84 }, { 16, 0.93 } } do
		local halo = frame({ Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = root })
		corner(halo, radius)
		table.insert(glows, stroke(halo, glowColor or GLOW, layer[1], layer[2]))
	end
	local bg = frame({ Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 0.04, ZIndex = 0, Parent = root })
	corner(bg, radius)
	create("UIGradient", { Color = ColorSequence.new(PANEL_TOP, PANEL_BOTTOM), Rotation = 90, Parent = bg })
	stroke(bg, VIOLET, 2)
	-- Thin top highlight, like the bevel on the reference panels.
	frame({
		Name = "Sheen",
		Position = UDim2.new(0, radius, 0, 3),
		Size = UDim2.new(1, -radius * 2, 0, 2),
		BackgroundColor3 = LILAC,
		BackgroundTransparency = 0.7,
		ZIndex = 0,
		Parent = root,
	})
	return root, glows
end

local function iconBox(parent: Instance, position: UDim2, size: number, accent: Color3): Frame
	local box = frame({ Name = "IconBox", Position = position, Size = UDim2.fromOffset(size, size), BackgroundColor3 = NAVY, Parent = parent })
	corner(box, 8)
	stroke(box, accent, 2)
	frame({ Name = "Bevel", Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 0, 2), BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Parent = box })
	return box
end

local function emoji(parent: Instance, glyph: string, size: number): TextLabel
	return text({
		Name = "Glyph",
		Size = UDim2.fromScale(1, 1),
		Text = glyph,
		TextSize = size,
		FontFace = FONT_MEDIUM,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = parent,
	})
end

-- Decorative "////" slashes from the reference panels.
local function slashes(parent: Instance, position: UDim2, size: number, color: Color3)
	text({
		Name = "Slashes",
		Position = position,
		Size = UDim2.fromOffset(size * 2.2, size),
		TextSize = size,
		Text = "////",
		TextColor3 = color,
		TextTransparency = 0.75,
		Parent = parent,
	})
end

-- Chunky button: dark lip below, gradient face clipped by a CanvasGroup with a moving shine.
-- style: "gold" (primary), "violet" (secondary) or "dark" (quiet). Returns its parts; call
-- UiKit.playShine(parts) when it appears.
local BUTTON_STYLES = {
	gold = { lip = LIP, top = rgb(255, 214, 74), bottom = ORANGE, text = INK },
	violet = { lip = LIP_VIOLET, top = rgb(150, 110, 255), bottom = VIOLET, text = CREAM },
	dark = { lip = DARK_LIP, top = rgb(58, 30, 110), bottom = rgb(32, 16, 64), text = CREAM },
}

local function button(parent: Instance, labelText: string, onActivated: () -> (), style: string?, textSize: number?)
	local look = BUTTON_STYLES[style or "gold"]
	local root = create("TextButton", {
		Name = "Button",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(280, 52),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	})
	local lip = frame({ Name = "Lip", Position = UDim2.new(0, 0, 1, -46), Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = look.lip, Parent = root })
	corner(lip, 9)
	stroke(lip, INK, 2.5)

	local body = frame({ Name = "Body", Size = UDim2.new(1, 0, 1, -6), BackgroundTransparency = 1, Parent = root })
	local face = create("CanvasGroup", { Name = "Face", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = body })
	corner(face, 9)
	local fill = frame({ Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, Parent = face })
	local gradient = create("UIGradient", { Color = ColorSequence.new(look.top, look.bottom), Rotation = 90, Parent = fill })
	frame({ Name = "Sheen", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0.42, 0), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, Parent = face })
	local shine = frame({
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.new(0, 34, 2, 0),
		Rotation = 22,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.45,
		Parent = face,
	})
	local edge = frame({ Name = "Outline", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	corner(edge, 9)
	stroke(edge, INK, 2.5)
	local label = text({ Name = "Label", Size = UDim2.fromScale(1, 1), Text = labelText, TextSize = textSize or 24, TextColor3 = look.text, TextXAlignment = Enum.TextXAlignment.Center, Parent = body })
	if look.text == INK then
		outline(label, 1.5, GOLD_LIGHT).Transparency = 0.4
	else
		outline(label, 2)
	end

	local shineTween = TweenService:Create(
		shine,
		TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.6),
		{ Position = UDim2.fromScale(1.3, 0.5) }
	)
	local parts = { button = root, body = body, shine = shine, label = label, shineTween = shineTween, gradient = gradient, face = face, enabled = true }

	local pressInfo = TweenInfo.new(0.07, Enum.EasingStyle.Quad)
	local function setPressed(pressed: boolean)
		TweenService:Create(body, pressInfo, { Position = UDim2.fromOffset(0, if pressed and parts.enabled then 5 else 0) }):Play()
	end
	root.MouseButton1Down:Connect(function()
		setPressed(true)
	end)
	root.MouseButton1Up:Connect(function()
		setPressed(false)
	end)
	root.MouseLeave:Connect(function()
		setPressed(false)
	end)
	root.Activated:Connect(function()
		if parts.enabled then
			onActivated()
		end
	end)
	return parts
end

local function playShine(parts)
	parts.body.Position = UDim2.fromOffset(0, 0)
	parts.shine.Position = UDim2.fromScale(-0.3, 0.5)
	parts.shineTween:Play()
end

-- Greys a button out (and ignores presses) or brings it back.
local function setEnabled(parts, enabled: boolean)
	parts.enabled = enabled
	parts.face.GroupTransparency = if enabled then 0 else 0.55
	parts.label.TextTransparency = if enabled then 0 else 0.45
	parts.button.AutoButtonColor = false
end

-- Phone-aware scale for panels laid out at DESIGN_SIZE (1280x720 GUI units). Short side under
-- PHONE_HEIGHT: up to PHONE_BOOST larger than the plain fit, as long as a minWidth x minHeight
-- layout still fits. Returns (scale, isPhone).
UiKit.DESIGN_SIZE = Vector2.new(1280, 720)
UiKit.PHONE_HEIGHT = 500
UiKit.PHONE_BOOST = 1.7

local function fitScale(size: Vector2, minWidth: number, minHeight: number): (number, boolean)
	local scale = math.min(size.X / UiKit.DESIGN_SIZE.X, size.Y / UiKit.DESIGN_SIZE.Y)
	local phone = math.min(size.X, size.Y) < UiKit.PHONE_HEIGHT
	if phone then
		scale = math.min(scale * UiKit.PHONE_BOOST, (size.X - 40) / minWidth, (size.Y - 20) / minHeight)
	end
	return math.clamp(scale, 0.5, 1.3), phone
end

UiKit.create = create
UiKit.frame = frame
UiKit.text = text
UiKit.corner = corner
UiKit.stroke = stroke
UiKit.outline = outline
UiKit.sizeLimit = sizeLimit
UiKit.bigText = bigText
UiKit.setBigText = setBigText
UiKit.panel = panel
UiKit.iconBox = iconBox
UiKit.emoji = emoji
UiKit.slashes = slashes
UiKit.button = button
UiKit.playShine = playShine
UiKit.setEnabled = setEnabled
UiKit.fitScale = fitScale

return UiKit
