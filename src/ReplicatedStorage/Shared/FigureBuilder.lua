-- Blocky R15-style footballer, in the proportions of the character sheet
-- (tools/assets/source/keeper_sheet.png). Used for the goalkeeper (server) and the pass
-- drill's players (client). The rig faces -Z and uses the R15 Motor6D names, so
-- KeeperAnimator / FigureAnimator can drive it. Decals are filled in by the client's ImageLoader.

local FigureBuilder = {}

local IMAGE_TAG = "NfsImage" -- see ShotClient/ImageLoader

export type Kit = {
	skin: Color3,
	shirt: Color3,
	sleeves: Color3?, -- lower arms (default: skin)
	shorts: Color3,
	socks: Color3,
	boots: Color3,
	hands: Color3?, -- default: skin
	hair: Color3,
}

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

local HEAD_PARTS = { Head = true }

local function makePart(model: Model, name: string, size: Vector3, position: Vector3, color: Color3): Part
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
	part.Parent = model
	return part
end

local function addDecal(part: BasePart, face: string, image: string)
	local decal = Instance.new("Decal")
	decal.Name = "Kit" .. face
	decal.Face = Enum.NormalId[face]
	decal:SetAttribute("Image", "Keeper/" .. image)
	decal:AddTag(IMAGE_TAG)
	decal.Parent = part
end

-- textures: "kit" paints the whole character sheet on (the goalkeeper), "head" only the face
-- and hair (outfield players in plain kit colours). Returns the model, standing on y = 0 and
-- facing -Z, and the height of its root above the ground.
function FigureBuilder.build(name: string, kit: Kit, scale: number, textures: string): (Model, number)
	local model = Instance.new("Model")
	model.Name = name
	local colors = {
		skin = kit.skin,
		shirt = kit.shirt,
		sleeves = kit.sleeves or kit.skin,
		shorts = kit.shorts,
		socks = kit.socks,
		boots = kit.boots,
		hands = kit.hands or kit.skin,
	}

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), kit.shirt)
	root.Transparency = 1
	root.Anchored = true -- anchors the whole rig; animators move it with PivotTo
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, spec in PARTS do
		local part = makePart(model, spec[1], spec[2], spec[3], colors[spec[4]])
		if textures == "kit" or (textures == "head" and HEAD_PARTS[spec[1]]) then
			for face, image in spec[5] do
				addDecal(part, face, image)
			end
		end
		parts[spec[1]] = part
	end

	-- Hair: a cap over the top of the head; the face and back textures already show the fringe.
	local head = parts.Head
	local hair = makePart(model, "Hair", Vector3.new(1.5, 0.34, 1.42), head.Position + Vector3.new(0, 0.74, 0.03), kit.hair)
	if textures ~= "none" then
		for _, face in { "Front", "Back", "Left", "Right" } do
			addDecal(hair, face, "Hair")
		end
	end
	local hairWeld = Instance.new("WeldConstraint")
	hairWeld.Part0 = head
	hairWeld.Part1 = hair
	hairWeld.Parent = hair

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
	local box, size = model:GetBoundingBox()
	local rootHeight = root.Position.Y - (box.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(0, rootHeight, 0))
	return model, rootHeight
end

return FigureBuilder
