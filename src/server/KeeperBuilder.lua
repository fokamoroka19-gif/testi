-- Builds the goalkeeper model on the server. The client animates it locally
-- (KeeperAnimator); the server never moves it, so all players see their own keeper.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))

local Keeper = ShotConfig.Goalkeeper

local SKIN = Color3.fromRGB(234, 192, 160)
local SHIRT = Color3.fromRGB(255, 191, 31) -- gold
local SHORTS = Color3.fromRGB(43, 18, 80) -- dark purple
local GLOVES = Color3.fromRGB(255, 45, 85) -- red
local BOOTS = Color3.fromRGB(20, 14, 30)

local KIT = {
	Head = SKIN,
	UpperTorso = SHIRT,
	LowerTorso = SHORTS,
	LeftUpperArm = SHIRT,
	RightUpperArm = SHIRT,
	LeftLowerArm = SHIRT,
	RightLowerArm = SHIRT,
	LeftHand = GLOVES,
	RightHand = GLOVES,
	LeftUpperLeg = SHORTS,
	RightUpperLeg = SHORTS,
	LeftLowerLeg = SHIRT,
	RightLowerLeg = SHIRT,
	LeftFoot = BOOTS,
	RightFoot = BOOTS,
}

local KeeperBuilder = {}

local function makeRig(): Model
	local description = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Goalkeeper"
	local bodyColors = model:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors:Destroy() -- otherwise it overrides the kit colours below
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local color = KIT[part.Name]
			if color then
				part.Color = color
			end
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		-- Stops the default Animator from fighting the procedural animation.
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy()
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true -- anchors the whole rig; the client moves it with PivotTo
	model.PrimaryPart = root
	model:ScaleTo(Keeper.ModelScale)
	model:SetAttribute("Rig", "R15")
	return model
end

-- Simple block figure, used only if the R15 rig can't be created.
local function makeBlocks(): Model
	local model = Instance.new("Model")
	model.Name = "Goalkeeper"
	local s = Keeper.ModelScale
	local specs = {
		{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.9, 0), SHIRT },
		{ "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.5, 0), SKIN },
		{ "LeftLeg", Vector3.new(0.9, 2.9, 0.9), Vector3.new(-0.5, 1.45, 0), SHORTS },
		{ "RightLeg", Vector3.new(0.9, 2.9, 0.9), Vector3.new(0.5, 1.45, 0), SHORTS },
		{ "LeftArm", Vector3.new(0.7, 2.2, 0.7), Vector3.new(-1.4, 3.8, 0), SHIRT },
		{ "RightArm", Vector3.new(0.7, 2.2, 0.7), Vector3.new(1.4, 3.8, 0), SHIRT },
	}
	for _, spec in specs do
		local part = Instance.new("Part")
		part.Name = spec[1]
		part.Size = spec[2] * s
		part.CFrame = CFrame.new(spec[3] * s)
		part.Color = spec[4]
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Parent = model
		if spec[1] == "Torso" then
			model.PrimaryPart = part
		end
	end
	model:SetAttribute("Rig", "Blocks")
	return model
end

function KeeperBuilder.build(scene: Instance): Model?
	if not Keeper.Enabled then
		return nil
	end
	local ok, model = pcall(makeRig)
	if not ok then
		warn("[KeeperBuilder] Could not create the R15 goalkeeper, using a simple one:", model)
		model = makeBlocks()
	end
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
