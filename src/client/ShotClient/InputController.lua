-- Turns mouse or touch into a normalized aim (X -1..1, Y 0..1) and power (0..1).
-- Press on the goal to aim, hold to charge the power meter, release to shoot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local ShotPhysics = require(Shared:WaitForChild("ShotPhysics"))

local InputController = {}
InputController.__index = InputController

function InputController.new()
	local self = setmetatable({
		enabled = false,
		holding = false,
		aimX = 0,
		aimY = 0.5,
		power = 0,
		onShoot = nil :: ((aimX: number, aimY: number, power: number) -> ())?,
		-- Guided shot: presses only count near (aimX, aimY) and the aim stays there.
		guide = nil :: { aimX: number, aimY: number, accepts: (aimX: number, aimY: number) -> boolean, onRejected: (() -> ())? }?,
		_activeInput = nil :: InputObject?,
		_holdStartedAt = 0,
	}, InputController)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		self:_onBegan(input, gameProcessed)
	end)
	UserInputService.InputChanged:Connect(function(input)
		self:_onChanged(input)
	end)
	UserInputService.InputEnded:Connect(function(input)
		self:_onEnded(input)
	end)
	return self
end

function InputController:setEnabled(enabled: boolean)
	self.enabled = enabled
	if not enabled then
		self.holding = false
		self._activeInput = nil
		self.power = 0
	end
end

-- Call every frame: advances the power meter while held.
function InputController:update()
	if not self.holding then
		return
	end
	local phase = ((os.clock() - self._holdStartedAt) / ShotConfig.Input.PowerCycleSeconds) % 1
	self.power = 1 - math.abs(1 - 2 * phase) -- 0 -> 1 -> 0
end

function InputController:setGuide(guide)
	self.guide = guide
	if guide then
		self.aimX, self.aimY = guide.aimX, guide.aimY
	end
end

-- Projects a screen point onto the goal plane (Z = 0).
local function screenToAim(position: Vector3): (number?, number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local ray = camera:ScreenPointToRay(position.X, position.Y)
	if ray.Direction.Z > -1e-4 then
		return nil, nil
	end
	local point = ray.Origin + ray.Direction * (-ray.Origin.Z / ray.Direction.Z)
	return ShotPhysics.goalPointToAim(point)
end

function InputController:_aimAt(position: Vector3)
	if self.guide then
		return
	end
	local aimX, aimY = screenToAim(position)
	if aimX then
		self.aimX, self.aimY = aimX, aimY
	end
end

function InputController:_onBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not self.enabled or self.holding then
		return
	end
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
		local guide = self.guide
		if guide then
			local aimX, aimY = screenToAim(input.Position)
			if not (aimX and guide.accepts(aimX, aimY)) then
				if guide.onRejected then
					guide.onRejected()
				end
				return
			end
		end
		self.holding = true
		self._activeInput = input
		self._holdStartedAt = os.clock()
		self.power = 0
		self:_aimAt(input.Position)
	end
end

function InputController:_onChanged(input: InputObject)
	if not self.enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		self:_aimAt(input.Position) -- PC: the marker follows the mouse even before clicking
	elseif input.UserInputType == Enum.UserInputType.Touch and input == self._activeInput then
		self:_aimAt(input.Position)
	end
end

function InputController:_onEnded(input: InputObject)
	if not self.holding then
		return
	end
	local active = self._activeInput
	local isMouseRelease = input.UserInputType == Enum.UserInputType.MouseButton1
		and active ~= nil
		and active.UserInputType == Enum.UserInputType.MouseButton1
	if not (isMouseRelease or input == active) then
		return
	end

	self.holding = false
	self._activeInput = nil
	if self.enabled and self.onShoot then
		self.onShoot(self.aimX, self.aimY, self.power)
	end
end

return InputController
