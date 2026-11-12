-- Blocky R15-style footballers, in the proportions of the character sheet
-- (tools/assets/source/keeper_sheet.png). The rig faces -Z and uses the R15 Motor6D names, so
-- KeeperAnimator / FigureAnimator can drive it.
--   textures "kit": the goalkeeper, with the sheet's textures painted on (decals are filled in by
--                   the client's ImageLoader).
--   otherwise:      an outfield player in one of the character sheet's looks (LOOKS: MAIN = you,
--                   TEAMMATE, RIVAL): own hair, face and skin, with the kit's colours, sleeve
--                   cuffs, wristbands, banded socks, optional shirt stripes and number.

local FigureBuilder = {}

local IMAGE_TAG = "NfsImage" -- see ShotClient/ImageLoader
local KIT_ATTRIBUTE = "KitColor" -- kit colour key of a part or GUI element (see applyKit)
local LOOK_ATTRIBUTE = "Look"
local PRINT_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)

export type Kit = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3?, -- lower arms (default: skin)
	shorts: Color3,
	socks: Color3,
	boots: Color3,
	hands: Color3?, -- default: skin
	hair: Color3,
	trim: Color3?, -- collar and sleeve cuffs (default: shorts)
	band: Color3?, -- sock stripes (default: shorts)
	stripes: Color3?, -- vertical shirt stripes (none if nil)
	print: Color3?, -- shirt number (default: trim)
	number: number?, -- shirt number (none if nil)
}

local rgb = Color3.fromRGB

-- Character sheet looks. skin / hair override the kit's, so a team can share one kit.
local LOOKS = {
	MAIN = { hair = rgb(58, 32, 24), skin = rgb(214, 132, 82), style = "WAVY", face = "DETERMINED" },
	TEAMMATE = { hair = rgb(214, 160, 88), skin = rgb(222, 140, 88), style = "CURLY", face = "GRIN" },
	RIVAL = { hair = rgb(26, 18, 18), skin = rgb(196, 118, 72), style = "BRAIDS", face = "ANGRY" },
}
FigureBuilder.Looks = LOOKS

-- Texture names per face (Images/Keeper.lua). The rig faces -Z, so Front is the chest.
type Faces = { Front: string?, Back: string?, Left: string?, Right: string? }
local function sides(front: string?, back: string?, side: string): Faces
	return { Front = front, Back = back, Left = side, Right = side .. "R" }
end

-- name, size, centre, kit colour, faces with the full kit textures (all at scale 1, feet on y = 0)
local PARTS: { { any } } = {
	{ "LowerTorso", Vector3.new(2, 0.6, 1), Vector3.new(0, 2.3, 0), "shorts", sides("LowerTorsoFront", "LowerTorsoBack", "LowerTorsoSide") },
	{ "UpperTorso", Vector3.new(2, 1.4, 1), Vector3.new(0, 3.3, 0), "shirt", sides("UpperTorsoFront", "UpperTorsoBack", "UpperTorsoSide") },
	{ "Head", Vector3.new(1.4, 1.25, 1.3), Vector3.new(0, 4.625, 0), "skin", sides("HeadFront", "HeadBack", "HeadSide") },
	{ "LeftUpperArm", Vector3.new(0.9, 1, 0.9), Vector3.new(-1.45, 3.5, 0), "shirt", sides("UpperArmSide", "UpperArmSide", "UpperArmSide") },
	{ "LeftLowerArm", Vector3.new(0.85, 0.75, 0.85), Vector3.new(-1.45, 2.625, 0), "sleeves", sides("LowerArmSide", "LowerArmSide", "LowerArmSide") },
	{ "LeftHand", Vector3.new(0.95, 0.75, 0.95), Vector3.new(-1.45, 1.875, 0), "hands", sides("GloveSide", "GloveSide", "GloveSide") },
	{ "RightUpperArm", Vector3.new(0.9, 1, 0.9), Vector3.new(1.45, 3.5, 0), "shirt", sides("UpperArmSide", "UpperArmSide", "UpperArmSide") },
	{ "RightLowerArm", Vector3.new(0.85, 0.75, 0.85), Vector3.new(1.45, 2.625, 0), "sleeves", sides("LowerArmSide", "LowerArmSide", "LowerArmSide") },
	{ "RightHand", Vector3.new(0.95, 0.75, 0.95), Vector3.new(1.45, 1.875, 0), "hands", sides("GloveSide", "GloveSide", "GloveSide") },
	{ "LeftUpperLeg", Vector3.new(0.98, 1.05, 0.98), Vector3.new(-0.5, 1.475, 0), "shorts", sides("LeftUpperLegFront", "LeftUpperLegBack", "UpperLegSide") },
	{ "LeftLowerLeg", Vector3.new(0.9, 0.6, 0.9), Vector3.new(-0.5, 0.65, 0), "socks", sides("LeftLowerLegFront", "LeftLowerLegBack", "LowerLegSide") },
	{ "LeftFoot", Vector3.new(1, 0.35, 1.2), Vector3.new(-0.5, 0.175, -0.1), "boots", {} },
	{ "RightUpperLeg", Vector3.new(0.98, 1.05, 0.98), Vector3.new(0.5, 1.475, 0), "shorts", sides("RightUpperLegFront", "RightUpperLegBack", "UpperLegSide") },
	{ "RightLowerLeg", Vector3.new(0.9, 0.6, 0.9), Vector3.new(0.5, 0.65, 0), "socks", sides("RightLowerLegFront", "RightLowerLegBack", "LowerLegSide") },
	{ "RightFoot", Vector3.new(1, 0.35, 1.2), Vector3.new(0.5, 0.175, -0.1), "boots", {} },
}

-- joint name, parent part, child part, joint position (scale 1)
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 2.6, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 2.6, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 4, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.45, 3.8, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.45, 3, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.45, 2.25, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.45, 3.8, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.45, 3, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.45, 2.25, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.5, 2, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.5, 0.95, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.5, 0.35, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.5, 2, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.5, 0.95, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.5, 0.35, 0) },
}

-- Outfield kit details welded to a body part: name, part, size, centre, kit colour.
local DETAILS: { { any } } = {}
for _, side in { { "Left", -1 }, { "Right", 1 } } do
	local name, s = side[1], side[2]
	table.insert(DETAILS, { name .. "Cuff", name .. "UpperArm", Vector3.new(0.94, 0.1, 0.94), Vector3.new(1.45 * s, 3.06, 0), "trim" })
	table.insert(DETAILS, { name .. "Wristband", name .. "LowerArm", Vector3.new(0.9, 0.2, 0.9), Vector3.new(1.45 * s, 2.36, 0), "wrist" })
	table.insert(DETAILS, { name .. "SockBand", name .. "LowerLeg", Vector3.new(0.94, 0.08, 0.94), Vector3.new(0.5 * s, 0.86, 0), "band" })
	table.insert(DETAILS, { name .. "SockStripe", name .. "LowerLeg", Vector3.new(0.94, 0.05, 0.94), Vector3.new(0.5 * s, 0.75, 0), "band" })
end

-- Hair per style, built round the head (x +-0.7, y 4.0..5.25, z +-0.65; the face is at -Z):
-- name, size, centre, rotation in degrees (X, Y, Z), colour key, ball?
local HAIR = {
	-- You: dark, thick and wavy, the fringe swept to one side.
	WAVY = {
		{ "Cap", Vector3.new(1.52, 0.34, 1.44), Vector3.new(0, 5.36, 0.03), Vector3.zero, "hair" },
		{ "Back", Vector3.new(1.5, 0.92, 0.26), Vector3.new(0, 4.92, 0.72), Vector3.zero, "hair" },
		{ "SideL", Vector3.new(0.18, 0.5, 1.2), Vector3.new(-0.77, 5.04, 0.1), Vector3.zero, "hair" },
		{ "SideR", Vector3.new(0.18, 0.5, 1.2), Vector3.new(0.77, 5.04, 0.1), Vector3.zero, "hair" },
		{ "Fringe1", Vector3.new(0.46, 0.3, 0.22), Vector3.new(-0.5, 5.15, -0.7), Vector3.new(0, 0, 14), "hair" },
		{ "Fringe2", Vector3.new(0.46, 0.34, 0.22), Vector3.new(-0.1, 5.13, -0.71), Vector3.new(0, 0, 18), "hairShade" },
		{ "Fringe3", Vector3.new(0.44, 0.3, 0.22), Vector3.new(0.3, 5.16, -0.7), Vector3.new(0, 0, 12), "hair" },
		{ "Fringe4", Vector3.new(0.3, 0.26, 0.22), Vector3.new(0.6, 5.2, -0.69), Vector3.new(0, 0, 8), "hairShade" },
		{ "Wave1", Vector3.new(0.6, 0.34, 0.56), Vector3.new(-0.42, 5.56, -0.32), Vector3.new(8, 10, 12), "hair" },
		{ "Wave2", Vector3.new(0.62, 0.36, 0.58), Vector3.new(0.12, 5.6, -0.36), Vector3.new(10, -8, -6), "hairShade" },
		{ "Wave3", Vector3.new(0.56, 0.32, 0.54), Vector3.new(0.5, 5.54, -0.2), Vector3.new(6, 12, -14), "hair" },
		{ "Wave4", Vector3.new(0.6, 0.34, 0.56), Vector3.new(-0.3, 5.56, 0.28), Vector3.new(-8, -10, 10), "hairShade" },
		{ "Wave5", Vector3.new(0.6, 0.34, 0.56), Vector3.new(0.32, 5.55, 0.3), Vector3.new(-6, 14, -10), "hair" },
		{ "Wave6", Vector3.new(0.5, 0.3, 0.4), Vector3.new(0, 5.4, 0.7), Vector3.new(-20, 0, 6), "hairShade" },
		{ "Wave7", Vector3.new(0.34, 0.4, 0.5), Vector3.new(-0.8, 5.3, -0.25), Vector3.new(0, 0, 16), "hairShade" },
		{ "Wave8", Vector3.new(0.34, 0.4, 0.5), Vector3.new(0.8, 5.3, -0.2), Vector3.new(0, 0, -16), "hair" },
	},
	-- Teammate: fair, a big mop of curls.
	CURLY = {
		{ "Cap", Vector3.new(1.5, 0.3, 1.42), Vector3.new(0, 5.33, 0.02), Vector3.zero, "hair" },
		{ "Back", Vector3.new(1.48, 0.8, 0.24), Vector3.new(0, 4.96, 0.72), Vector3.zero, "hair" },
		{ "SideL", Vector3.new(0.18, 0.44, 1.16), Vector3.new(-0.77, 5.06, 0.1), Vector3.zero, "hair" },
		{ "SideR", Vector3.new(0.18, 0.44, 1.16), Vector3.new(0.77, 5.06, 0.1), Vector3.zero, "hair" },
	},
	-- Rival: dark braids running back over the head, short at the sides.
	BRAIDS = {
		{ "Cap", Vector3.new(1.46, 0.2, 1.38), Vector3.new(0, 5.3, 0.03), Vector3.zero, "hair" },
		{ "Back", Vector3.new(1.46, 0.7, 0.2), Vector3.new(0, 5.0, 0.7), Vector3.zero, "hair" },
		{ "FadeL", Vector3.new(0.08, 0.42, 1.08), Vector3.new(-0.72, 5.0, 0.1), Vector3.zero, "hairShade" },
		{ "FadeR", Vector3.new(0.08, 0.42, 1.08), Vector3.new(0.72, 5.0, 0.1), Vector3.zero, "hairShade" },
		{ "Hairline", Vector3.new(1.3, 0.12, 0.08), Vector3.new(0, 5.2, -0.66), Vector3.zero, "hair" },
	},
}

-- Curls: small balls over the top, sides, back and fringe.
do
	local curls = HAIR.CURLY
	local i = 0
	local function curl(position: Vector3, size: number)
		i += 1
		table.insert(curls, { "Curl" .. i, Vector3.one * size, position, Vector3.zero, if i % 3 == 0 then "hairShade" else "hair", true })
	end
	for _, x in { -0.5, -0.17, 0.17, 0.5 } do
		for k, z in { -0.42, -0.08, 0.26, 0.58 } do
			curl(Vector3.new(x + (if k % 2 == 0 then 0.08 else -0.04), 5.52 + (k % 2) * 0.06, z), 0.52)
		end
		curl(Vector3.new(x, 5.16, -0.66), 0.4) -- fringe
	end
	for _, s in { -1, 1 } do
		for _, z in { -0.32, 0.08, 0.46 } do
			curl(Vector3.new(0.76 * s, 5.2, z), 0.44)
		end
	end
	for _, x in { -0.45, 0, 0.45 } do
		curl(Vector3.new(x, 5.2, 0.74), 0.46)
		curl(Vector3.new(x * 0.9, 4.86, 0.76), 0.38)
	end
end

-- Braids: rows front to back over the top, short ends hanging at the back.
do
	local braids = HAIR.BRAIDS
	for i, x in { -0.56, -0.28, 0, 0.28, 0.56 } do
		local key = if i % 2 == 0 then "hairShade" else "hair"
		table.insert(braids, { "Braid" .. i, Vector3.new(0.22, 0.26, 1.38), Vector3.new(x, 5.47 - math.abs(x) * 0.14, 0.04), Vector3.new(0, 0, x * 18), key })
		table.insert(braids, { "BraidEnd" .. i, Vector3.new(0.16, 0.5, 0.16), Vector3.new(x * 0.9, 4.88, 0.82), Vector3.new(-14, 0, 0), key })
	end
end

local function kitColors(kit: Kit, lookName: string?): { [string]: Color3 }
	local look = lookName and LOOKS[lookName]
	local skin = if look then look.skin else kit.skin
	local hair = if look then look.hair else kit.hair
	local trim = kit.trim or kit.shorts
	return {
		skin = skin,
		shirt = kit.shirt,
		sleeves = kit.sleeves or skin,
		shorts = kit.shorts,
		socks = kit.socks,
		boots = kit.boots,
		hands = kit.hands or skin,
		hair = hair,
		hairShade = hair:Lerp(Color3.new(0, 0, 0), 0.28),
		trim = trim,
		band = kit.band or kit.shorts,
		stripes = kit.stripes or kit.shirt,
		print = kit.print or trim,
		wrist = rgb(24, 20, 30),
	}
end

local function makePart(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, kitKey: string?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if kitKey then
		part:SetAttribute(KIT_ATTRIBUTE, kitKey)
	end
	part.Parent = model
	return part
end

local function weld(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function addDecal(part: BasePart, face: string, image: string)
	local decal = Instance.new("Decal")
	decal.Name = "Kit" .. face
	decal.Face = Enum.NormalId[face]
	decal:SetAttribute("Image", "Keeper/" .. image)
	decal:AddTag(IMAGE_TAG)
	decal.Parent = part
end

local function surface(part: BasePart, name: string, face: Enum.NormalId): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.LightInfluence = 1
	gui.Parent = part
	return gui
end

-- Rectangle in scale units; x, y, w, h are fractions of the parent.
local function box(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, kitKey: string?, rotation: number?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	if kitKey then
		f:SetAttribute(KIT_ATTRIBUTE, kitKey)
	end
	f.Parent = parent
	return f
end

local INK = rgb(26, 12, 16)
local WHITE = Color3.new(1, 1, 1)

-- Eye: white with the dark iris towards the nose and a highlight. squint: 0..1 narrower.
local function eye(gui: Instance, x: number, inward: number, squint: number)
	local h = 0.13 * (1 - squint * 0.45)
	local white = box(gui, x, 0.44 + (0.13 - h) / 2, 0.15, h, WHITE)
	local iris = box(white, if inward > 0 then 0.42 else 0, 0, 0.58, 1, INK)
	box(iris, 0.5, 0.12, 0.3, 0.32, WHITE)
end

-- Pixel faces in the character sheet's style (front of the head).
local FACES = {
	DETERMINED = function(gui: Instance, colors)
		box(gui, 0.15, 0.33, 0.27, 0.07, colors.hairShade, "hairShade", 9)
		box(gui, 0.58, 0.33, 0.27, 0.07, colors.hairShade, "hairShade", -9)
		eye(gui, 0.22, 1, 0)
		eye(gui, 0.63, -1, 0)
		box(gui, 0.47, 0.6, 0.06, 0.07, Color3.new(0, 0, 0), nil, 0, 0.82)
		box(gui, 0.43, 0.76, 0.16, 0.035, rgb(96, 42, 30), nil, -4)
		box(gui, 0.2, 0.62, 0.04, 0.09, rgb(160, 84, 54), nil, 25, 0.3) -- small cheek scar
	end,
	GRIN = function(gui: Instance, colors)
		box(gui, 0.17, 0.3, 0.22, 0.06, colors.hairShade, "hairShade", -8)
		box(gui, 0.61, 0.3, 0.22, 0.06, colors.hairShade, "hairShade", 8)
		-- Eyes squeezed shut with laughter: "^ ^"
		for _, x in { 0.21, 0.62 } do
			box(gui, x, 0.47, 0.1, 0.045, INK, nil, -28)
			box(gui, x + 0.07, 0.47, 0.1, 0.045, INK, nil, 28)
		end
		local mouth = box(gui, 0.33, 0.66, 0.34, 0.16, rgb(110, 30, 34))
		Instance.new("UICorner", mouth).CornerRadius = UDim.new(0.35, 0)
		box(mouth, 0.08, 0, 0.84, 0.36, WHITE)
		for _, spot in { { 0.18, 0.6 }, { 0.24, 0.64 }, { 0.15, 0.66 }, { 0.78, 0.6 }, { 0.72, 0.64 }, { 0.81, 0.66 } } do
			box(gui, spot[1], spot[2], 0.025, 0.025, rgb(176, 96, 58)) -- freckles
		end
	end,
	ANGRY = function(gui: Instance, colors)
		box(gui, 0.14, 0.35, 0.29, 0.08, colors.hair, "hair", 18)
		box(gui, 0.57, 0.35, 0.29, 0.08, colors.hair, "hair", -18)
		eye(gui, 0.22, 1, 1)
		eye(gui, 0.63, -1, 1)
		box(gui, 0.47, 0.6, 0.06, 0.07, Color3.new(0, 0, 0), nil, 0, 0.82)
		box(gui, 0.15, 0.62, 0.7, 0.36, Color3.new(0, 0, 0), nil, 0, 0.88) -- stubble
		box(gui, 0.36, 0.69, 0.28, 0.045, colors.hair, "hair") -- moustache
		box(gui, 0.41, 0.77, 0.18, 0.035, rgb(96, 42, 30)) -- frown
		box(gui, 0.38, 0.79, 0.05, 0.035, rgb(96, 42, 30), nil, 30)
		box(gui, 0.57, 0.79, 0.05, 0.035, rgb(96, 42, 30), nil, -30)
		box(gui, 0.43, 0.86, 0.14, 0.12, colors.hair, "hair") -- goatee
	end,
}

local function numberLabel(gui: Instance, name: string, x: number, y: number, w: number, h: number, colors, number: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(w, h)
	label.BackgroundTransparency = 1
	label.FontFace = PRINT_FONT
	label.Text = tostring(number)
	label.TextScaled = true
	label.TextColor3 = colors.print
	label:SetAttribute(KIT_ATTRIBUTE, "print")
	label:SetAttribute("KitNumber", true)
	label.Parent = gui
end

local function dressShirt(parts: { [string]: BasePart }, kit: Kit, colors)
	local torso = parts.UpperTorso
	local front = surface(torso, "ShirtFront", Enum.NormalId.Front)
	local back = surface(torso, "ShirtBack", Enum.NormalId.Back)
	if kit.stripes then
		-- Vertical stripes on the shirt, both sides and the sleeves' outsides.
		for _, gui in { front, back } do
			for i = 0, 3 do
				box(gui, 0.07 + i * 0.25, 0, 0.11, 1, colors.stripes, "stripes")
			end
		end
		for _, name in { "LeftUpperArm", "RightUpperArm" } do
			local sleeve = surface(parts[name], "Stripes", if name == "LeftUpperArm" then Enum.NormalId.Left else Enum.NormalId.Right)
			box(sleeve, 0.38, 0, 0.24, 0.9, colors.stripes, "stripes")
		end
	end
	-- V-neck collar in the trim colour.
	box(front, 0.36, -0.02, 0.17, 0.05, colors.trim, "trim", 38)
	box(front, 0.47, -0.02, 0.17, 0.05, colors.trim, "trim", -38)
	if kit.number then
		numberLabel(front, "ChestNumber", 0.18, 0.2, 0.2, 0.3, colors, kit.number)
		numberLabel(back, "BackNumber", 0.25, 0.14, 0.5, 0.74, colors, kit.number)
		local shorts = surface(parts.RightUpperLeg, "ShortsNumber", Enum.NormalId.Front)
		numberLabel(shorts, "ShortsNumber", 0.2, 0.08, 0.6, 0.3, colors, kit.number)
	end
end

-- Builds a footballer. textures "kit" = the goalkeeper; anything else = an outfield player with
-- `look` (MAIN | TEAMMATE | RIVAL, default MAIN). Returns the model, standing on y = 0 and facing
-- -Z, and the height of its root above the ground.
function FigureBuilder.build(name: string, kit: Kit, scale: number, textures: string, look: string?): (Model, number)
	local model = Instance.new("Model")
	model.Name = name
	local keeper = textures == "kit"
	local lookName = if keeper then nil else (if look and LOOKS[look] then look else "MAIN")
	if lookName then
		model:SetAttribute(LOOK_ATTRIBUTE, lookName)
	end
	local colors = kitColors(kit, lookName)

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), kit.shirt)
	root.Transparency = 1
	root.Anchored = true -- anchors the whole rig; animators move it with PivotTo
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, spec in PARTS do
		local part = makePart(model, spec[1], spec[2], spec[3], colors[spec[4]], spec[4])
		if keeper then
			for face, image in spec[5] do
				addDecal(part, face, image)
			end
		end
		parts[spec[1]] = part
	end
	local head = parts.Head

	if keeper then
		-- Hair: a cap over the top of the head; the face and back textures already show the fringe.
		local hair = makePart(model, "Hair", Vector3.new(1.5, 0.34, 1.42), head.Position + Vector3.new(0, 0.74, 0.03), kit.hair, "hair")
		for _, face in { "Front", "Back", "Left", "Right" } do
			addDecal(hair, face, "Hair")
		end
		weld(hair, head)
	else
		local spec = LOOKS[lookName :: string]
		for _, detail in DETAILS do
			weld(makePart(model, detail[1], detail[3], detail[4], colors[detail[5]], detail[5]), parts[detail[2]])
		end
		for _, piece in HAIR[spec.style] do
			local part = makePart(model, "Hair" .. piece[1], piece[2], piece[3], colors[piece[5]], piece[5])
			if piece[6] then
				part.Shape = Enum.PartType.Ball
			end
			local r = piece[4]
			part.CFrame = CFrame.new(piece[3]) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
			weld(part, head)
		end
		FACES[spec.face](surface(head, "Face", Enum.NormalId.Front), colors)
		dressShirt(parts, kit, colors)
	end

	for _, joint in JOINTS do
		local part0, part1 = parts[joint[2]], parts[joint[3]]
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = CFrame.new(joint[4] - part0.Position)
		motor.C1 = CFrame.new(joint[4] - part1.Position)
		motor.Parent = part1
	end

	model:ScaleTo(scale)
	local bbox, size = model:GetBoundingBox()
	local rootHeight = root.Position.Y - (bbox.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(0, rootHeight, 0))
	return model, rootHeight
end

-- Recolours a model made by build() (e.g. the training team in the player's club kit). The
-- look's own skin and hair stay. Stripes only show if the model was built with them.
function FigureBuilder.applyKit(model: Model, kit: Kit)
	local look = model:GetAttribute(LOOK_ATTRIBUTE)
	local colors = kitColors(kit, if typeof(look) == "string" then look else nil)
	for _, d in model:GetDescendants() do
		local key = d:GetAttribute(KIT_ATTRIBUTE)
		local color = key and colors[key]
		if color then
			if d:IsA("BasePart") then
				d.Color = color
			elseif d:IsA("TextLabel") then
				d.TextColor3 = color
			elseif d:IsA("GuiObject") then
				d.BackgroundColor3 = color
			end
		end
	end
end

-- Changes the shirt number of a model built with kit.number.
function FigureBuilder.setNumber(model: Model, number: number)
	for _, d in model:GetDescendants() do
		if d:IsA("TextLabel") and d:GetAttribute("KitNumber") then
			d.Text = tostring(number)
		end
	end
end

return FigureBuilder
