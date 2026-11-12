-- Pure shot geometry and ball flight. Used by the server to decide outcomes and by the
-- client to draw the exact same arc, so what the player sees matches what was decided.

local ShotConfig = require(script.Parent.ShotConfig)

local Goal = ShotConfig.Goal
local BALL_RADIUS = ShotConfig.Ball.Radius
local GRAVITY = Vector3.new(0, -ShotConfig.Gravity, 0)

local ShotPhysics = {}

-- Where the ball crosses the goal plane relative to the frame.
ShotPhysics.Zone = {
	OnTarget = "ON_TARGET", -- fully inside the goal mouth
	Frame = "FRAME", -- solid contact with a post or the crossbar
	Wide = "WIDE", -- wide or over
}

function ShotPhysics.ballSpot(): Vector3
	return Vector3.new(0, BALL_RADIUS, ShotConfig.ShotDistance)
end

-- Aim X in -1..1 and Y in 0..1 cover exactly the area where the whole ball fits inside the
-- goal mouth, so aiming at the edge means grazing the frame.
function ShotPhysics.aimToGoalPoint(aimX: number, aimY: number): Vector3
	local halfWidth = Goal.Width / 2 - BALL_RADIUS
	local x = math.clamp(aimX, -1, 1) * halfWidth
	local y = BALL_RADIUS + math.clamp(aimY, 0, 1) * (Goal.Height - 2 * BALL_RADIUS)
	return Vector3.new(x, y, 0)
end

function ShotPhysics.goalPointToAim(point: Vector3): (number, number)
	local halfWidth = Goal.Width / 2 - BALL_RADIUS
	local aimX = math.clamp(point.X / halfWidth, -1, 1)
	local aimY = math.clamp((point.Y - BALL_RADIUS) / (Goal.Height - 2 * BALL_RADIUS), 0, 1)
	return aimX, aimY
end

function ShotPhysics.ballSpeed(power: number): number
	local p = math.clamp(power, 0, 1)
	return ShotConfig.MinBallSpeed + (ShotConfig.MaxBallSpeed - ShotConfig.MinBallSpeed) * p
end

function ShotPhysics.flightTime(start: Vector3, target: Vector3, power: number): number
	return (target - start).Magnitude / ShotPhysics.ballSpeed(power)
end

-- Initial velocity of a projectile that leaves `start` and is at `target` after `flightTime`.
function ShotPhysics.launchVelocity(start: Vector3, target: Vector3, flightTime: number): Vector3
	return (target - start) / flightTime - GRAVITY * (flightTime / 2)
end

function ShotPhysics.positionAt(start: Vector3, velocity: Vector3, t: number): Vector3
	return start + velocity * t + GRAVITY * (0.5 * t * t)
end

function ShotPhysics.velocityAt(velocity: Vector3, t: number): Vector3
	return velocity + GRAVITY * t
end

function ShotPhysics.gravity(): Vector3
	return GRAVITY
end

local function distanceToSegment(px: number, py: number, ax: number, ay: number, bx: number, by: number): number
	local abx, aby = bx - ax, by - ay
	local t = math.clamp(((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby), 0, 1)
	local dx, dy = px - (ax + abx * t), py - (ay + aby * t)
	return math.sqrt(dx * dx + dy * dy)
end

-- Classifies the ball centre where it crosses the goal plane (Z = 0).
function ShotPhysics.classify(point: Vector3): string
	local postX = Goal.Width / 2 + Goal.PostRadius
	local barY = Goal.Height + Goal.PostRadius
	local x, y = point.X, point.Y

	local frameDistance = math.min(
		distanceToSegment(x, y, -postX, 0, -postX, barY),
		distanceToSegment(x, y, postX, 0, postX, barY),
		distanceToSegment(x, y, -postX, barY, postX, barY)
	)
	if frameDistance < Goal.PostRadius + BALL_RADIUS * (1 - Goal.FrameHitDepth) then
		return ShotPhysics.Zone.Frame
	end
	if math.abs(x) < postX and y < barY then
		return ShotPhysics.Zone.OnTarget
	end
	return ShotPhysics.Zone.Wide
end

return ShotPhysics
