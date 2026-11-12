-- 3D side of the menus: the camera over the evening stadium and the "showroom" player on the
-- pitch (club kit, name and number on the back) with his entrance, turn and celebration.
-- Client-only; everything lives in workspace.MenuScene while a menu is open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local FigureBuilder = require(Shared:WaitForChild("FigureBuilder"))
local FigureAnimator = require(script.Parent:WaitForChild("FigureAnimator"))

local SCALE = ShotConfig.Goalkeeper.ModelScale
local SPOT = Vector3.new(0, 0, 60) -- where the showroom player stands (on the pitch, facing the camera)
local BLEND = 0.9 -- seconds for camera moves between menu views
local RISE = 0.85 -- entrance: rising out of the beam
local HOLD_FRONT = 0.9 -- then shows his front this long before turning
local TURN = 0.75
local TEXT_FADE = 0.35

local rgb = Color3.fromRGB
local GOLD = rgb(255, 191, 31)
local VIOLET = rgb(123, 77, 255)
local WARM = rgb(255, 236, 214)

local MenuScene = {}
MenuScene.__index = MenuScene

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOutBack(t: number): number
	t = math.clamp(t, 0, 1)
	local c = 1.4
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

-- Camera views. stadium: slow drift over the pitch towards the goal and the stand.
-- showroom: the player on the right third of the screen, room for a panel on the left.
local function stadiumView(t: number): (CFrame, number)
	local x = -4 + math.sin(t * 0.08) * 9
	local position = Vector3.new(x, 11 + math.sin(t * 0.05) * 1.5, 98)
	return CFrame.lookAt(position, Vector3.new(x * 0.3, 5, 14)), 50
end

local function showroomView(t: number): (CFrame, number)
	local look = SPOT + Vector3.new(-5.2, 3.6, 0)
	local sway = math.sin(t * 0.3) * 0.6
	local position = look + Vector3.new(sway, 0.9, 16.5)
	return CFrame.lookAt(position, look), 40
end

local VIEWS = { stadium = stadiumView, showroom = showroomView }

function MenuScene.new()
	local self = setmetatable({}, MenuScene)
	self.clock = 0
	self.view = "stadium"
	self.active = false
	self.blendT = 1

	local folder = Instance.new("Folder")
	folder.Name = "MenuScene"
	self.folder = folder

	-- Stage under the player: glowing violet disc with a gold rim.
	local disc = part({ Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 7, 7), Color = VIOLET, Material = Enum.Material.Neon, Transparency = 0.55 })
	disc.CFrame = CFrame.new(SPOT + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Parent = folder
	local rim = part({ Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.06, 7.8, 7.8), Color = GOLD, Material = Enum.Material.Neon, Transparency = 0.25 })
	rim.CFrame = CFrame.new(SPOT + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	rim.Parent = folder

	-- Key light from the front, violet rim light from behind.
	local key = part({ Name = "KeyLight", Size = Vector3.one * 0.2, Transparency = 1 })
	key.CFrame = CFrame.lookAt(SPOT + Vector3.new(-3, 14, 12), SPOT + Vector3.new(0, 3, 0))
	key.Parent = folder
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Brightness = 3.2
	spot.Range = 34
	spot.Angle = 45
	spot.Color = WARM
	spot.Shadows = false
	spot.Parent = key
	local back = part({ Name = "RimLight", Size = Vector3.one * 0.2, Transparency = 1 })
	back.CFrame = CFrame.new(SPOT + Vector3.new(2, 7, -5))
	back.Parent = folder
	local glow = Instance.new("PointLight")
	glow.Color = VIOLET
	glow.Brightness = 3
	glow.Range = 14
	glow.Shadows = false
	glow.Parent = back

	-- Entrance: a light column and sparkles.
	local beam = part({ Name = "Beam", Shape = Enum.PartType.Cylinder, Size = Vector3.new(16, 4.2, 4.2), Color = GOLD, Material = Enum.Material.Neon, Transparency = 1 })
	beam.CFrame = CFrame.new(SPOT + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = folder
	self.beam = beam
	local sparkHolder = part({ Name = "Sparks", Size = Vector3.new(4, 0.2, 4), Transparency = 1 })
	sparkHolder.CFrame = CFrame.new(SPOT + Vector3.new(0, 0.3, 0))
	sparkHolder.Parent = folder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(GOLD, VIOLET)
	sparks.LightEmission = 0.9
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(6, 14)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -12, 0)
	sparks.Rate = 0
	sparks.Parent = sparkHolder
	self.sparks = sparks
	return self
end

function MenuScene:setActive(active: boolean)
	if self.active == active then
		return
	end
	self.active = active
	self.folder.Parent = if active then workspace else nil
	if active then
		local camera = workspace.CurrentCamera
		self.blendFrom, self.blendFov, self.blendT = camera.CFrame, camera.FieldOfView, 0
	end
end

-- stadium | showroom
function MenuScene:setView(view: string)
	if self.view == view then
		return
	end
	self.view = view
	local camera = workspace.CurrentCamera
	self.blendFrom, self.blendFov, self.blendT = camera.CFrame, camera.FieldOfView, 0
end

-- Direction from the player to the showroom camera (on the ground).
local function toCamera(): Vector3
	local look = SPOT + Vector3.new(-5.2, 3.6, 0)
	local cam = look + Vector3.new(0, 0.9, 16.5)
	return Vector3.new(cam.X - SPOT.X, 0, cam.Z - SPOT.Z).Unit
end

-- Shows the player in a kit. entrance: rise out of the beam facing the camera, then turn to show
-- the back. Calling it again with the same kit only updates the shirt.
function MenuScene:showPlayer(kitKey: string, kit, shirtName: string, number: number, trim: Color3, entrance: boolean)
	if self.kitKey ~= kitKey or not self.figure then
		if self.figure then
			self.figure.model:Destroy()
		end
		local model, rootHeight = FigureBuilder.build("ShowroomPlayer", kit, SCALE, "head")
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = true
			end
		end
		model.Parent = self.folder
		self.figure = FigureAnimator.new(model, rootHeight, SCALE)
		self.figure:place(SPOT, toCamera())
		self.kitKey = kitKey
		self.angle = 0
		self.turnFrom, self.turnTo, self.turnT = 0, 0, 1
		entrance = true
	end
	self.trim = trim
	self:setShirt(shirtName, number, false)
	if entrance then
		self.entranceT = 0
		self.figure.lift = -9
		self.revealPending = true
		self.textAlpha = 1
		self.turnFrom, self.turnTo, self.turnT = 0, 0, 1
		self.angle = 0
		self.sparks:Emit(40)
	end
end

function MenuScene:hidePlayer()
	if self.figure then
		self.figure.model:Destroy()
		self.figure = nil
		self.kitKey = nil
	end
end

-- Updates the shirt; pop = fade the text in again (it changed) and turn round to show it.
function MenuScene:setShirt(shirtName: string, number: number, pop: boolean)
	if not self.figure then
		return
	end
	self.shirtBack, self.shirtFront = FigureBuilder.setShirt(self.figure.model, shirtName, number, self.trim or GOLD)
	if pop then
		self.textAlpha = 1
		self.textT = 0
		if not self.revealPending and self.turnTo < math.pi / 2 then
			self:turn()
		end
	end
end

-- Front <-> back.
function MenuScene:turn()
	if not self.figure then
		return
	end
	self.turnFrom = self.angle
	self.turnTo = if self.turnTo > math.pi / 2 then 0 else math.pi
	self.turnT = 0
end

function MenuScene:cheer(on: boolean)
	if self.figure then
		self.figure:play(if on then "CHEER" else nil)
	end
end

function MenuScene:_setTextAlpha(alpha: number)
	for _, g in { self.shirtBack, self.shirtFront } do
		if g then
			for _, l in g:GetChildren() do
				if l:IsA("TextLabel") then
					l.TextTransparency = alpha
					local s = l:FindFirstChildOfClass("UIStroke")
					if s then
						s.Transparency = alpha
					end
				end
			end
		end
	end
end

function MenuScene:update(dt: number)
	if not self.active then
		return
	end
	self.clock += dt

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	local target, fov = VIEWS[self.view](self.clock)
	if self.blendT < 1 then
		self.blendT = math.min(1, self.blendT + dt / BLEND)
		local k = smooth(self.blendT)
		camera.CFrame = self.blendFrom:Lerp(target, k)
		camera.FieldOfView = self.blendFov + (fov - self.blendFov) * k
	else
		camera.CFrame = target
		camera.FieldOfView = fov
	end

	local figure = self.figure
	self.beam.Transparency = 1
	if not figure then
		return
	end
	-- Entrance: rise, hold the front, then turn and let the name and number appear.
	if self.entranceT then
		self.entranceT += dt
		local t = self.entranceT
		figure.lift = -9 * (1 - easeOutBack(t / RISE))
		self.beam.Transparency = 0.35 + 0.65 * smooth((t - RISE * 0.6) / 0.8)
		if t >= RISE and not self.landed then
			self.landed = true
			self.sparks:Emit(30)
		end
		if t >= RISE + HOLD_FRONT and self.revealPending then
			self.revealPending = false
			self.entranceT = nil
			self.landed = false
			figure.lift = 0
			self.turnFrom, self.turnTo, self.turnT = self.angle, math.pi, 0
			self.textT = 0
		end
		self:_setTextAlpha(1)
	elseif self.textT then
		self.textT += dt
		local alpha = 1 - smooth((self.textT - TURN * 0.5) / TEXT_FADE)
		self:_setTextAlpha(alpha)
		if alpha <= 0 then
			self.textT = nil
		end
	end
	if self.turnT < 1 then
		self.turnT = math.min(1, self.turnT + dt / TURN)
		self.angle = self.turnFrom + (self.turnTo - self.turnFrom) * smooth(self.turnT)
	end
	local base = toCamera()
	local c, s = math.cos(self.angle), math.sin(self.angle)
	local facing = Vector3.new(base.X * c - base.Z * s, 0, base.X * s + base.Z * c)
	figure:moveTo(SPOT, facing, 1) -- exact facing every frame (the turn is eased above)
	figure.speed = 0
	figure:update(dt)
end

return MenuScene
