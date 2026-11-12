-- The player's footballer on the pitch during career creation: built in the chosen club's kit,
-- he appears facing the camera (gold flash, sparkles), then turns round to show the surname and
-- number on his back. Name or number changes turn him to the back again and pop the print.
-- Everything here is local to this client; CareerMenu drives it and owns the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local CareerConfig = require(Shared:WaitForChild("CareerConfig"))
local FigureBuilder = require(Shared:WaitForChild("FigureBuilder"))
local FigureAnimator = require(script.Parent:WaitForChild("FigureAnimator"))
local UiKit = require(script.Parent:WaitForChild("UiKit"))

local SCALE = ShotConfig.Goalkeeper.ModelScale -- same size as the training players
-- He stands between the shot spot and the camera, the goal and the stand behind him. The camera
-- is shifted left so he sits in the right half of the screen, next to the creation panel.
local STAGE = Vector3.new(0, 0, 56)
local CAMERA_OFFSET = Vector3.new(-4.6, 4.4, 17)
local LOOK_OFFSET = Vector3.new(-4.6, 3.7, 0)
local FOV = 40
local FADE_IN = 0.55
local FRONT_HOLD = 1.5 -- seconds facing the camera before the first turn
local TURN_TIME = 0.9
local PRINT_PIXELS = 60 -- SurfaceGui pixels per stud on the shirt

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- cylinder parts are long along X

local PlayerPreview = {}
PlayerPreview.__index = PlayerPreview

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function facingFor(angle: number): Vector3
	return Vector3.new(math.sin(angle), 0, math.cos(angle))
end

local FRONT_ANGLE = math.atan2(CAMERA_OFFSET.X, CAMERA_OFFSET.Z) -- facing the camera

local function makePart(props: { [string]: any }): Part
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = props.CastShadow or false
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	return UiKit.create("Part", props)
end

function PlayerPreview.new()
	local self = setmetatable({}, PlayerPreview)
	self.folder = UiKit.create("Folder", { Name = "CareerPreview" })
	self.visible = false
	self.clock = 0
	self.club = nil
	self.animator = nil
	self.angle = FRONT_ANGLE
	self.turnFrom, self.turnTo, self.turnStart = FRONT_ANGLE, FRONT_ANGLE, -math.huge
	self.facingBack = false
	self.introAt = nil :: number?

	-- Showcase lighting: warm key light from the camera side, violet rim from behind.
	local key = makePart({ Name = "KeyLight", Size = Vector3.one * 0.2, Transparency = 1, Position = STAGE + Vector3.new(-3, 7, 8), Parent = self.folder })
	UiKit.create("PointLight", { Color = UiKit.rgb(255, 232, 200), Brightness = 1.6, Range = 16, Shadows = false, Parent = key })
	local rim = makePart({ Name = "RimLight", Size = Vector3.one * 0.2, Transparency = 1, Position = STAGE + Vector3.new(2.5, 7, -4), Parent = self.folder })
	UiKit.create("PointLight", { Color = UiKit.GLOW, Brightness = 3, Range = 12, Shadows = false, Parent = rim })

	-- Podium ring under his feet and the flash ring that bursts out when he appears.
	self.podium = makePart({
		Name = "Podium",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, 6.4, 6.4),
		CFrame = CFrame.new(STAGE + Vector3.new(0, 0.04, 0)) * VERTICAL,
		Color = UiKit.GLOW,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		Parent = self.folder,
	})
	self.flash = makePart({
		Name = "Flash",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.05, 2, 2),
		CFrame = CFrame.new(STAGE + Vector3.new(0, 0.07, 0)) * VERTICAL,
		Color = UiKit.GOLD,
		Material = Enum.Material.Neon,
		Transparency = 1,
		Parent = self.folder,
	})
	local sparkleCarrier = makePart({ Name = "Sparkles", Size = Vector3.one * 0.2, Transparency = 1, Position = STAGE + Vector3.new(0, 3.6, 0), Parent = self.folder })
	self.sparkles = UiKit.create("ParticleEmitter", {
		Enabled = false,
		Color = ColorSequence.new(UiKit.GOLD_LIGHT, UiKit.GOLD),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(7, 14),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -10, 0),
		Drag = 2,
		Parent = sparkleCarrier,
	})
	return self
end

-- Where the camera looks at him from.
function PlayerPreview.cameraTarget(): (CFrame, number)
	return CFrame.lookAt(STAGE + CAMERA_OFFSET, STAGE + LOOK_OFFSET), FOV
end

-- Shirt print: surname and big number on the back, the club badge on the chest.
function PlayerPreview:_dressShirt(model: Model, club)
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	local back = UiKit.create("SurfaceGui", {
		Name = "BackPrint",
		Face = Enum.NormalId.Back,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PRINT_PIXELS,
		LightInfluence = 1,
		Parent = torso,
	})
	self.backName = UiKit.text({
		Name = "Surname",
		Position = UDim2.fromScale(0.06, 0.07),
		Size = UDim2.fromScale(0.88, 0.22),
		Text = "",
		FontFace = UiKit.FONT_PRINT,
		TextColor3 = club.print,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = back,
	})
	UiKit.sizeLimit(self.backName, 40)
	local numberHolder = UiKit.frame({ Name = "NumberHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.8, 0.64), BackgroundTransparency = 1, Parent = back })
	self.numberPop = UiKit.create("UIScale", { Parent = numberHolder })
	self.backNumber = UiKit.text({
		Name = "Number",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		FontFace = UiKit.FONT_PRINT,
		TextColor3 = club.print,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Parent = numberHolder,
	})

	local front = UiKit.create("SurfaceGui", {
		Name = "FrontPrint",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PRINT_PIXELS,
		LightInfluence = 1,
		Parent = torso,
	})
	UiKit.crest(front, { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.72, 0.3), Size = UDim2.fromOffset(34, 34) }, club)
	self.prints = { back, front }
end

function PlayerPreview:_build(club)
	if self.animator then
		self.animator.model:Destroy()
	end
	local model, rootHeight = FigureBuilder.build("CareerPlayer", CareerConfig.kit(club), SCALE, "head")
	self.fadeParts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = true
			table.insert(self.fadeParts, d)
		elseif d:IsA("Decal") then
			table.insert(self.fadeParts, d)
		end
	end
	self:_dressShirt(model, club)
	model.Parent = self.folder
	self.animator = FigureAnimator.new(model, rootHeight, SCALE)
	self.club = club
end

function PlayerPreview:_setFade(amount: number)
	for _, part in self.fadeParts do
		part.LocalTransparencyModifier = amount
	end
	for _, gui in self.prints do
		gui.Enabled = amount < 0.5
	end
end

function PlayerPreview:_turn(delta: number)
	self.turnFrom = self.angle
	self.turnTo += delta
	self.turnStart = self.clock
end

function PlayerPreview:showBack()
	if not self.facingBack then
		self.facingBack = true
		self:_turn(math.pi)
	end
end

function PlayerPreview:showFront()
	if self.facingBack then
		self.facingBack = false
		self:_turn(math.pi)
	end
end

-- Appears in the club's kit facing the camera, then turns to show the back.
function PlayerPreview:show(club, lastName: string, number: number?)
	if club ~= self.club then
		self:_build(club)
	end
	self.folder.Parent = workspace
	self.visible = true
	self.angle, self.turnFrom, self.turnTo, self.turnStart = FRONT_ANGLE, FRONT_ANGLE, FRONT_ANGLE, -math.huge
	self.facingBack = false
	self.animator:place(STAGE, facingFor(FRONT_ANGLE))
	self.animator:play(nil)
	self.appearStart = self.clock
	self.introAt = self.clock + FRONT_HOLD
	self:_setFade(1)
	self:setIdentity(lastName, number, true)

	self.flash.Size = Vector3.new(0.05, 2, 2)
	self.flash.Transparency = 0.1
	TweenService:Create(self.flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, 15, 15), Transparency = 1 }):Play()
	task.delay(0.12, function()
		if self.visible then
			self.sparkles:Emit(36)
		end
	end)
end

-- Updates the shirt print. Unless `quiet`, he turns to show the back and the number pops.
function PlayerPreview:setIdentity(lastName: string, number: number?, quiet: boolean?)
	if not self.animator then
		return
	end
	local surname = CareerConfig.upper(lastName)
	local digits = if number then tostring(number) else ""
	local changed = self.backName.Text ~= surname or self.backNumber.Text ~= digits
	self.backName.Text = surname
	self.backNumber.Text = digits
	if quiet or not changed or self.introAt then
		return
	end
	self:showBack()
	self.numberPop.Scale = 1.3
	TweenService:Create(self.numberPop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Contract signed: turns to the camera and celebrates.
function PlayerPreview:celebrate()
	self.introAt = nil
	self:showFront()
	if self.animator then
		self.animator:play("CHEER")
	end
	self.sparkles:Emit(24)
end

function PlayerPreview:hide()
	self.visible = false
	self.folder.Parent = nil
	if self.animator then
		self.animator:play(nil)
	end
end

function PlayerPreview:update(dt: number)
	if not (self.visible and self.animator) then
		return
	end
	self.clock += dt
	self:_setFade(1 - smooth((self.clock - self.appearStart) / FADE_IN))
	if self.introAt and self.clock >= self.introAt then
		self.introAt = nil
		self:showBack()
	end
	self.angle = self.turnFrom + (self.turnTo - self.turnFrom) * smooth((self.clock - self.turnStart) / TURN_TIME)
	self.animator:place(STAGE, facingFor(self.angle))
	self.animator:update(dt)
	local pulse = 0.5 + 0.5 * math.sin(self.clock * 2.4)
	self.podium.Transparency = 0.5 + 0.2 * pulse
end

return PlayerPreview
