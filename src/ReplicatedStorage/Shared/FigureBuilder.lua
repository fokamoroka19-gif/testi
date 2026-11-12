-- Blocky R15-style footballers in two builds:
--   "kit"  the goalkeeper, in the proportions of the character sheet
--          (tools/assets/source/keeper_sheet.png) with the sheet's textures painted on.
--   "head" outfield players in the New Football Star mascot style: big square head with spiky
--          hair and a pixel face, short sleeves over bare forearms, shorts to above the knee,
--          long banded socks and boots. All plain parts, so any kit colours work.
-- Both rigs face -Z and use the R15 Motor6D names, so KeeperAnimator / FigureAnimator can drive
-- them. Keeper decals are filled in by the client's ImageLoader.

local FigureBuilder = {}

local IMAGE_TAG = "NfsImage" -- see ShotClient/ImageLoader
local KIT_ATTRIBUTE = "KitColor" -- which kit colour a part (or face/collar frame) takes

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
}

-- Texture names per face (Images/Keeper.lua). The rig faces -Z, so Front is the chest.
type Faces = { Front: string?, Back: string?, Left: string?, Right: string? }
local function sides(front: string?, back: string?, side: string): Faces
	return { Front = front, Back = back, Left = side, Right = side .. "R" }
end

---------------------------------------------------------------- goalkeeper build ("kit")

-- name, size, centre, kit colour, faces with the full kit textures (all at scale 1, feet on y = 0)
local KEEPER_PARTS: { { any } } = {
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
local KEEPER_JOINTS = {
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

---------------------------------------------------------------- outfield build ("head")

-- Chunky mascot proportions (scale 1, feet on y = 0): head 1.56 wide on a 2-wide torso.
local PLAYER_PARTS: { { any } } = {
	{ "LowerTorso", Vector3.new(2, 0.46, 1), Vector3.new(0, 2.37, 0), "shorts" },
	{ "UpperTorso", Vector3.new(2, 1.56, 1), Vector3.new(0, 3.38, 0), "shirt" },
	{ "Head", Vector3.new(1.56, 1.42, 1.46), Vector3.new(0, 4.89, 0), "skin" },
	{ "LeftUpperArm", Vector3.new(0.92, 0.86, 0.92), Vector3.new(-1.46, 3.73, 0), "shirt" },
	{ "LeftLowerArm", Vector3.new(0.84, 0.78, 0.84), Vector3.new(-1.46, 2.91, 0), "sleeves" },
	{ "LeftHand", Vector3.new(0.88, 0.5, 0.88), Vector3.new(-1.46, 2.27, 0), "hands" },
	{ "RightUpperArm", Vector3.new(0.92, 0.86, 0.92), Vector3.new(1.46, 3.73, 0), "shirt" },
	{ "RightLowerArm", Vector3.new(0.84, 0.78, 0.84), Vector3.new(1.46, 2.91, 0), "sleeves" },
	{ "RightHand", Vector3.new(0.88, 0.5, 0.88), Vector3.new(1.46, 2.27, 0), "hands" },
	{ "LeftUpperLeg", Vector3.new(0.92, 0.84, 0.92), Vector3.new(-0.52, 1.72, 0), "skin" }, -- knee shows below the shorts
	{ "LeftLowerLeg", Vector3.new(0.9, 0.96, 0.9), Vector3.new(-0.52, 0.82, 0), "socks" },
	{ "LeftFoot", Vector3.new(0.98, 0.34, 1.25), Vector3.new(-0.52, 0.17, -0.12), "boots" },
	{ "RightUpperLeg", Vector3.new(0.92, 0.84, 0.92), Vector3.new(0.52, 1.72, 0), "skin" },
	{ "RightLowerLeg", Vector3.new(0.9, 0.96, 0.9), Vector3.new(0.52, 0.82, 0), "socks" },
	{ "RightFoot", Vector3.new(0.98, 0.34, 1.25), Vector3.new(0.52, 0.17, -0.12), "boots" },
}

local PLAYER_JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso", Vector3.new(0, 2.6, 0) },
	{ "Waist", "LowerTorso", "UpperTorso", Vector3.new(0, 2.6, 0) },
	{ "Neck", "UpperTorso", "Head", Vector3.new(0, 4.16, 0) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", Vector3.new(-1.46, 3.96, 0) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", Vector3.new(-1.46, 3.3, 0) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", Vector3.new(-1.46, 2.52, 0) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", Vector3.new(1.46, 3.96, 0) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", Vector3.new(1.46, 3.3, 0) },
	{ "RightWrist", "RightLowerArm", "RightHand", Vector3.new(1.46, 2.52, 0) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", Vector3.new(-0.52, 2.14, 0) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", Vector3.new(-0.52, 1.3, 0) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", Vector3.new(-0.52, 0.34, 0) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", Vector3.new(0.52, 2.14, 0) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", Vector3.new(0.52, 1.3, 0) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", Vector3.new(0.52, 0.34, 0) },
}

-- Kit details welded onto a body part: name, part, size, centre, kit colour.
local PLAYER_DETAILS: { { any } } = {}
for _, side in { { "Left", -1 }, { "Right", 1 } } do
	local name, s = side[1], side[2]
	table.insert(PLAYER_DETAILS, { name .. "Shorts", name .. "UpperLeg", Vector3.new(1, 0.6, 1), Vector3.new(0.52 * s, 1.86, 0), "shorts" })
	table.insert(PLAYER_DETAILS, { name .. "SockBand", name .. "LowerLeg", Vector3.new(0.94, 0.13, 0.94), Vector3.new(0.52 * s, 1.13, 0), "band" })
	table.insert(PLAYER_DETAILS, { name .. "SockStripe", name .. "LowerLeg", Vector3.new(0.94, 0.06, 0.94), Vector3.new(0.52 * s, 0.97, 0), "band" })
	table.insert(PLAYER_DETAILS, { name .. "Cuff", name .. "UpperArm", Vector3.new(0.96, 0.1, 0.96), Vector3.new(1.46 * s, 3.35, 0), "trim" })
end

-- Spiky hair over the head (head spans y 4.18..5.6, x +-0.78, z +-0.73; front is -Z):
-- name, size, centre, rotation in degrees (X, Y, Z), colour.
local HAIR: { { any } } = {
	{ "HairTop", Vector3.new(1.68, 0.42, 1.6), Vector3.new(0, 5.72, 0.02), Vector3.zero, "hair" },
	{ "HairBack", Vector3.new(1.66, 1, 0.32), Vector3.new(0, 5.2, 0.78), Vector3.zero, "hair" },
	{ "HairSideL", Vector3.new(0.2, 0.62, 1.3), Vector3.new(-0.86, 5.36, 0.12), Vector3.zero, "hair" },
	{ "HairSideR", Vector3.new(0.2, 0.62, 1.3), Vector3.new(0.86, 5.36, 0.12), Vector3.zero, "hair" },
	-- Fringe falling over the forehead
	{ "Fringe1", Vector3.new(0.42, 0.34, 0.24), Vector3.new(-0.56, 5.42, -0.78), Vector3.new(0, 0, 12), "hair" },
	{ "Fringe2", Vector3.new(0.42, 0.4, 0.24), Vector3.new(-0.18, 5.36, -0.79), Vector3.new(0, 0, -8), "hairDark" },
	{ "Fringe3", Vector3.new(0.42, 0.34, 0.24), Vector3.new(0.2, 5.41, -0.78), Vector3.new(0, 0, 10), "hair" },
	{ "Fringe4", Vector3.new(0.4, 0.3, 0.24), Vector3.new(0.58, 5.46, -0.78), Vector3.new(0, 0, -14), "hairDark" },
	-- Spikes: tilted cubes poking out of the top, sides and back
	{ "Spike1", Vector3.one * 0.5, Vector3.new(-0.55, 6, -0.35), Vector3.new(20, 15, 35), "hair" },
	{ "Spike2", Vector3.one * 0.55, Vector3.new(0, 6.08, -0.4), Vector3.new(25, 40, 10), "hairDark" },
	{ "Spike3", Vector3.one * 0.5, Vector3.new(0.55, 6, -0.3), Vector3.new(15, -20, -35), "hair" },
	{ "Spike4", Vector3.one * 0.5, Vector3.new(-0.35, 6.05, 0.25), Vector3.new(-20, 30, 25), "hairDark" },
	{ "Spike5", Vector3.one * 0.55, Vector3.new(0.35, 6.1, 0.2), Vector3.new(-15, -35, -20), "hair" },
	{ "Spike6", Vector3.one * 0.5, Vector3.new(0, 5.98, 0.65), Vector3.new(-40, 10, 0), "hair" },
	{ "Spike7", Vector3.one * 0.42, Vector3.new(-0.82, 5.85, -0.2), Vector3.new(0, 20, 45), "hairDark" },
	{ "Spike8", Vector3.one * 0.42, Vector3.new(0.82, 5.85, -0.15), Vector3.new(0, -20, -45), "hair" },
	{ "Spike9", Vector3.one * 0.42, Vector3.new(-0.7, 5.5, 0.7), Vector3.new(-30, 0, 40), "hairDark" },
	{ "Spike10", Vector3.one * 0.42, Vector3.new(0.7, 5.55, 0.68), Vector3.new(-30, 0, -40), "hair" },
	{ "Spike11", Vector3.one * 0.45, Vector3.new(0, 5.4, 0.95), Vector3.new(-45, 0, 45), "hairDark" },
	{ "Spike12", Vector3.one * 0.36, Vector3.new(-0.9, 5.25, 0.35), Vector3.new(0, 0, 30), "hair" },
	{ "Spike13", Vector3.one * 0.36, Vector3.new(0.9, 5.25, 0.35), Vector3.new(0, 0, -30), "hairDark" },
}

---------------------------------------------------------------- shared helpers

local function kitColors(kit: Kit): { [string]: Color3 }
	return {
		skin = kit.skin,
		shirt = kit.shirt,
		sleeves = kit.sleeves or kit.skin,
		shorts = kit.shorts,
		socks = kit.socks,
		boots = kit.boots,
		hands = kit.hands or kit.skin,
		hair = kit.hair,
		hairDark = kit.hair:Lerp(Color3.new(0, 0, 0), 0.35),
		trim = kit.trim or kit.shorts,
		band = kit.band or kit.shorts,
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

local function guiFrame(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3, kitKey: string?, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	if kitKey then
		f:SetAttribute(KIT_ATTRIBUTE, kitKey)
	end
	f.Parent = parent
	return f
end

-- Pixel face in the mascot style: angled thick brows, small dark eyes with a highlight.
local function addFace(head: BasePart, colors: { [string]: Color3 })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.Parent = head
	local ink = Color3.fromRGB(26, 12, 16)
	guiFrame(gui, "BrowL", UDim2.fromScale(0.17, 0.37), UDim2.fromScale(0.26, 0.075), colors.hairDark, "hairDark", 11)
	guiFrame(gui, "BrowR", UDim2.fromScale(0.57, 0.37), UDim2.fromScale(0.26, 0.075), colors.hairDark, "hairDark", -11)
	for _, x in { 0.25, 0.65 } do
		local eye = guiFrame(gui, "Eye", UDim2.fromScale(x, 0.465), UDim2.fromScale(0.1, 0.12), ink)
		guiFrame(eye, "Shine", UDim2.fromScale(0.55, 0.12), UDim2.fromScale(0.32, 0.3), Color3.new(1, 1, 1))
	end
	local nose = guiFrame(gui, "Nose", UDim2.fromScale(0.47, 0.6), UDim2.fromScale(0.06, 0.07), Color3.new(0, 0, 0))
	nose.BackgroundTransparency = 0.82
	guiFrame(gui, "Mouth", UDim2.fromScale(0.42, 0.75), UDim2.fromScale(0.16, 0.04), Color3.fromRGB(96, 42, 30))
end

-- Shirt front: V-neck collar in the trim colour. Other scripts may add prints to this gui.
local function addShirtFront(torso: BasePart, colors: { [string]: Color3 })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ShirtFront"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.Parent = torso
	guiFrame(gui, "CollarL", UDim2.fromScale(0.36, -0.02), UDim2.fromScale(0.17, 0.05), colors.trim, "trim", 38)
	guiFrame(gui, "CollarR", UDim2.fromScale(0.47, -0.02), UDim2.fromScale(0.17, 0.05), colors.trim, "trim", -38)
end

local function buildRig(model: Model, kit: Kit, parts: { { any } }, joints: { { any } }, textures: string): { [string]: BasePart }
	local colors = kitColors(kit)
	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), kit.shirt)
	root.Transparency = 1
	root.Anchored = true -- anchors the whole rig; animators move it with PivotTo
	model.PrimaryPart = root

	local byName: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, spec in parts do
		local part = makePart(model, spec[1], spec[2], spec[3], colors[spec[4]], spec[4])
		if textures == "kit" then
			for face, image in spec[5] do
				addDecal(part, face, image)
			end
		end
		byName[spec[1]] = part
	end
	for _, joint in joints do
		local part0, part1 = byName[joint[2]], byName[joint[3]]
		local motor = Instance.new("Motor6D")
		motor.Name = joint[1]
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = CFrame.new(joint[4] - part0.Position)
		motor.C1 = CFrame.new(joint[4] - part1.Position)
		motor.Parent = part1
	end
	return byName
end

-- textures: "kit" builds the goalkeeper with the character sheet painted on; anything else builds
-- an outfield player. Returns the model, standing on y = 0 and facing -Z, and the height of its
-- root above the ground.
function FigureBuilder.build(name: string, kit: Kit, scale: number, textures: string): (Model, number)
	local model = Instance.new("Model")
	model.Name = name
	local colors = kitColors(kit)

	if textures == "kit" then
		local parts = buildRig(model, kit, KEEPER_PARTS, KEEPER_JOINTS, textures)
		-- Hair: a cap over the top of the head; the face and back textures already show the fringe.
		local head = parts.Head
		local hair = makePart(model, "Hair", Vector3.new(1.5, 0.34, 1.42), head.Position + Vector3.new(0, 0.74, 0.03), kit.hair, "hair")
		for _, face in { "Front", "Back", "Left", "Right" } do
			addDecal(hair, face, "Hair")
		end
		weld(hair, head)
	else
		local parts = buildRig(model, kit, PLAYER_PARTS, PLAYER_JOINTS, textures)
		for _, spec in PLAYER_DETAILS do
			weld(makePart(model, spec[1], spec[3], spec[4], colors[spec[5]], spec[5]), parts[spec[2]])
		end
		local head = parts.Head
		for _, spec in HAIR do
			local piece = makePart(model, spec[1], spec[2], spec[3], colors[spec[5]], spec[5])
			local r = spec[4]
			piece.CFrame = CFrame.new(spec[3]) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
			weld(piece, head)
		end
		addFace(head, colors)
		addShirtFront(parts.UpperTorso, colors)
	end

	model:ScaleTo(scale)
	local box, size = model:GetBoundingBox()
	local root = model.PrimaryPart :: BasePart
	local rootHeight = root.Position.Y - (box.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(0, rootHeight, 0))
	return model, rootHeight
end

-- Recolours a model made by build() (e.g. the training team in the player's club kit).
function FigureBuilder.applyKit(model: Model, kit: Kit)
	local colors = kitColors(kit)
	for _, d in model:GetDescendants() do
		local key = d:GetAttribute(KIT_ATTRIBUTE)
		local color = key and colors[key]
		if color then
			if d:IsA("BasePart") then
				d.Color = color
			elseif d:IsA("GuiObject") then
				d.BackgroundColor3 = color
			end
		end
	end
end

return FigureBuilder
