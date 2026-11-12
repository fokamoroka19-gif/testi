-- Builds the goalkeeper on the server: a blocky R15-style rig in the proportions of the
-- character sheet (tools/assets/source/keeper_sheet.png), with the sheet's kit painted on as
-- decals. The client fills the decals in (ImageLoader) and animates the rig locally
-- (KeeperAnimator, which drives the R15 Motor6D names below); the server never moves it.
-- Part colours match the kit, so the keeper still looks right if images are unavailable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))

local Keeper = ShotConfig.Goalkeeper
local IMAGE_TAG = "NfsImage" -- see ImageLoader

local SKIN = Color3.fromRGB(214, 132, 82)
local KIT = Color3.fromRGB(30, 22, 40) -- black/purple camo shirt and shorts
local SOCKS = Color3.fromRGB(22, 18, 28)
local GLOVES = Color3.fromRGB(236, 232, 244)
local BOOTS = Color3.fromRGB(232, 228, 242)
local HAIR = Color3.fromRGB(52, 32, 26)

-- Texture names per face (Images/Keeper.lua). The rig faces -Z, so Front is the chest.
type Faces = { Front: string?, Back: string?, Left: string?, Right: string? }
local function sides(front: string?, back: string?, side: string): Faces
	return { Front = front, Back = back, Left = side, Right = side .. "R" }
end

-- name, size, centre, colour, faces (all at scale 1, feet on y = 0)
local PARTS: { { any } } = {
	{ "LowerTorso", Vector3.new(2, 0.6, 1), Vector3.new(0, 2.3, 0), KIT, sides("LowerTorsoFront", "LowerTorsoBack", "LowerTorsoSide") },
	{ "UpperTorso", Vector3.new(2, 1.4, 1), Vector3.new(0, 3.3, 0), KIT, sides("UpperTorsoFront", "UpperTorsoBack", "UpperTorsoSide") },
	{ "Head", Vector3.new(1.4, 1.25, 1.3), Vector3.new(0, 4.625, 0), SKIN, sides("HeadFront", "HeadBack", "HeadSide") },
	{ "LeftUpperArm", Vector3.new(0.9, 1, 0.9), Vector3.new(-1.45, 3.5, 0), KIT, sides("UpperArmSide", "UpperArmSide", "UpperArmSide") },
	{ "LeftLowerArm", Vector3.new(0.85, 0.75, 0.85), Vector3.new(-1.45, 2.625, 0), KIT, sides("LowerArmSide", "LowerArmSide", "LowerArmSide") },
	{ "LeftHand", Vector3.new(0.95, 0.75, 0.95), Vector3.new(-1.45, 1.875, 0), GLOVES, sides("GloveSide", "GloveSide", "GloveSide") },
	{ "RightUpperArm", Vector3.new(0.9, 1, 0.9), Vector3.new(1.45, 3.5, 0), KIT, sides("UpperArmSide", "UpperArmSide", "UpperArmSide") },
	{ "RightLowerArm", Vector3.new(0.85, 0.75, 0.85), Vector3.new(1.45, 2.625, 0), KIT, sides("LowerArmSide", "LowerArmSide", "LowerArmSide") },
	{ "RightHand", Vector3.new(0.95, 0.75, 0.95), Vector3.new(1.45, 1.875, 0), GLOVES, sides("GloveSide", "GloveSide", "GloveSide") },
	{ "LeftUpperLeg", Vector3.new(0.98, 1.05, 0.98), Vector3.new(-0.5, 1.475, 0), KIT, sides("LeftUpperLegFront", "LeftUpperLegBack", "UpperLegSide") },
	{ "LeftLowerLeg", Vector3.new(0.9, 0.6, 0.9), Vector3.new(-0.5, 0.65, 0), SOCKS, sides("LeftLowerLegFront", "LeftLowerLegBack", "LowerLegSide") },
	{ "LeftFoot", Vector3.new(1, 0.35, 1.2), Vector3.new(-0.5, 0.175, -0.1), BOOTS, {} },
	{ "RightUpperLeg", Vector3.new(0.98, 1.05, 0.98), Vector3.new(0.5, 1.475, 0), KIT, sides("RightUpperLegFront", "RightUpperLegBack", "UpperLegSide") },
	{ "RightLowerLeg", Vector3.new(0.9, 0.6, 0.9), Vector3.new(0.5, 0.65, 0), SOCKS, sides("RightLowerLegFront", "RightLowerLegBack", "LowerLegSide") },
	{ "RightFoot", Vector3.new(1, 0.35, 1.2), Vector3.new(0.5, 0.175, -0.1), BOOTS, {} },
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

local KeeperBuilder = {}

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

local function makeRig(): Model
	local model = Instance.new("Model")
	model.Name = "Goalkeeper"

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), KIT)
	root.Transparency = 1
	root.Anchored = true -- anchors the whole rig; the client moves it with PivotTo
	model.PrimaryPart = root

	local parts: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, spec in PARTS do
		local part = makePart(model, spec[1], spec[2], spec[3], spec[4])
		for face, image in spec[5] do
			addDecal(part, face, image)
		end
		parts[spec[1]] = part
	end

	-- Hair: a cap over the top of the head; the face and back textures already show the fringe.
	local head = parts.Head
	local hair = makePart(model, "Hair", Vector3.new(1.5, 0.34, 1.42), head.Position + Vector3.new(0, 0.74, 0.03), HAIR)
	for _, face in { "Front", "Back", "Left", "Right" } do
		addDecal(hair, face, "Hair")
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

	model:ScaleTo(Keeper.ModelScale)
	model:SetAttribute("Rig", "R15 blocks")
	return model
end

function KeeperBuilder.build(scene: Instance): Model?
	if not Keeper.Enabled then
		return nil
	end
	local model = makeRig()
	-- Face the shooter (+Z) and stand with the feet on the ground.
	local facing = CFrame.Angles(0, math.pi, 0)
	model:PivotTo(facing)
	local box, size = model:GetBoundingBox()
	local lift = -(box.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(Keeper.HomeX, lift, Keeper.HomeZ) * facing)
	model.Parent = scene
	print(string.format("[KeeperBuilder] Goalkeeper ready (%s, %.1f studs tall)", model:GetAttribute("Rig"), size.Y))
	return model
end

return KeeperBuilder
