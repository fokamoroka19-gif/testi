-- Server-only: turns validated shot input into an outcome. Never runs on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local ShotPhysics = require(Shared:WaitForChild("ShotPhysics"))

export type ShotInput = { aimX: number, aimY: number, power: number }
export type ShotStats = { shooting: number, keeperSkill: number }
export type ShotResult = {
	outcome: string, -- "GOAL" | "SAVE" | "POST" | "MISS"
	start: Vector3,
	intended: Vector3, -- aim point before inaccuracy
	target: Vector3, -- where the ball actually crosses the goal plane
	flightTime: number,
	keeperTarget: Vector3, -- where the keeper's body centre gets to (goal plane)
	keeperReaction: number,
}

local ShotResolver = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Standard normal sample (Box-Muller).
local function gaussian(rng: Random): number
	local u1 = math.max(rng:NextNumber(), 1e-9)
	local u2 = rng:NextNumber()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

function ShotResolver.resolve(input: ShotInput, stats: ShotStats, rng: Random): ShotResult
	local accuracy = ShotConfig.Accuracy
	local keeper = ShotConfig.Goalkeeper

	-- 1. Inaccuracy: better shooters scatter less; overpowered shots scatter more and rise.
	local skill = math.clamp(stats.shooting, 0, 100) / 100
	local overpower = math.max(0, (input.power - accuracy.OverpowerFrom) / (1 - accuracy.OverpowerFrom))
	local sigma = lerp(accuracy.ScatterAtZeroSkill, accuracy.ScatterAtMaxSkill, skill)
		+ overpower * accuracy.OverpowerScatter
	local cap = accuracy.MaxSigmas
	local offsetX = math.clamp(gaussian(rng), -cap, cap) * sigma
	local offsetY = math.clamp(gaussian(rng), -cap, cap) * sigma + overpower * accuracy.OverpowerLift

	local intended = ShotPhysics.aimToGoalPoint(input.aimX, input.aimY)
	local target = Vector3.new(
		intended.X + offsetX,
		math.max(ShotConfig.Ball.Radius, intended.Y + offsetY), -- low shots roll along the ground
		0
	)
	local start = ShotPhysics.ballSpot()
	local flightTime = ShotPhysics.flightTime(start, target, input.power)
	local zone = ShotPhysics.classify(target)

	-- 2. Goalkeeper: reacts after a short delay, then moves towards the ball at a skill-based
	-- speed. It is a save if his hands reach the crossing point before the ball does.
	local home = Vector3.new(keeper.HomeX, keeper.HomeY, 0)
	local toBall = Vector3.new(target.X, target.Y, 0) - home
	local reaction = keeper.ReactionTime + (rng:NextNumber() * 2 - 1) * keeper.ReactionJitter
	local diveSpeed = lerp(keeper.DiveSpeedAtZeroSkill, keeper.DiveSpeedAtMaxSkill, math.clamp(stats.keeperSkill, 0, 100) / 100)
	local canTravel = diveSpeed * math.max(0, flightTime - reaction)
	local mustTravel = math.max(0, toBall.Magnitude - keeper.Reach)

	local keeperTarget = home
	if keeper.Enabled and toBall.Magnitude > 1e-3 then
		keeperTarget = home + toBall.Unit * math.min(canTravel, mustTravel)
	end

	local outcome
	if zone == ShotPhysics.Zone.Frame then
		outcome = "POST"
	elseif zone == ShotPhysics.Zone.Wide then
		outcome = "MISS"
	elseif keeper.Enabled and canTravel >= mustTravel then
		outcome = "SAVE"
	else
		outcome = "GOAL"
	end

	return {
		outcome = outcome,
		start = start,
		intended = intended,
		target = target,
		flightTime = flightTime,
		keeperTarget = keeperTarget,
		keeperReaction = reaction,
	}
end

return ShotResolver
