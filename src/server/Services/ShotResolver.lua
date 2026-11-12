-- Server-only: turns validated shot input into a fully simulated shot. Never runs on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))
local ShotPhysics = require(Shared:WaitForChild("ShotPhysics"))

local Goal = ShotConfig.Goal
local Keeper = ShotConfig.Goalkeeper

export type ShotInput = { aimX: number, aimY: number, power: number }
export type ShotStats = { shooting: number, keeperSkill: number }
export type ShotResult = {
	outcome: string, -- "GOAL" | "SAVE" | "POST" | "MISS" (series history / scoring)
	detail: string, -- GOAL | POST_IN | CATCH | PARRY | POST | BAR | WIDE | OVER (what the player sees)
	start: Vector3,
	target: Vector3, -- where the unobstructed flight would cross the goal plane
	velocity: Vector3,
	spin: Vector3,
	speedKmh: number,
	sim: ShotPhysics.SimResult,
	decisiveTime: number, -- moment the result is clear (goal, save, frame or the ball passing the line)
	keeperTarget: Vector3, -- where the keeper's body centre gets to (logic coordinates)
	keeperReaction: number,
	keeperDives: boolean,
}

local ShotResolver = {}

-- Speed readout: the goal is oversized for readability, so use a fixed, believable scale.
local KMH_PER_STUD_PER_SECOND = 1.0

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

	-- 1. Inaccuracy: better shooters scatter less; overpowered shots scatter more and rise.
	local skill = math.clamp(stats.shooting, 0, 100) / 100
	local overpower = math.max(0, (input.power - accuracy.OverpowerFrom) / (1 - accuracy.OverpowerFrom))
	local sigma = lerp(accuracy.ScatterAtZeroSkill, accuracy.ScatterAtMaxSkill, skill)
		+ overpower * accuracy.OverpowerScatter
	local cap = accuracy.MaxSigmas
	local offsetX = math.clamp(gaussian(rng), -cap, cap) * sigma
	local offsetY = math.clamp(gaussian(rng), -cap, cap) * sigma + overpower * accuracy.OverpowerLift

	local intended = ShotPhysics.aimToGoalPoint(input.aimX, input.aimY)
	local target = Vector3.new(intended.X + offsetX, math.max(ShotConfig.Ball.Radius, intended.Y + offsetY), 0)

	-- 2. Spin and the launch velocity that flies (with drag and curl) to the target.
	local jitter = ShotConfig.Physics.SpinJitter
	local spin = ShotPhysics.spinFor(input.aimX, input.power, (rng:NextNumber() * 2 - 1) * jitter, (rng:NextNumber() * 2 - 1) * jitter)
	local start = ShotPhysics.ballSpot()
	local velocity = ShotPhysics.solveLaunch(start, target, input.power, spin)

	-- 3. Goalkeeper: reacts after a short delay, then moves at a skill-based speed. He only
	-- dives for shots heading for the frame; when the ball reaches him he catches or parries.
	local reaction = Keeper.ReactionTime + (rng:NextNumber() * 2 - 1) * Keeper.ReactionJitter
	local diveSpeed = lerp(Keeper.DiveSpeedAtZeroSkill, Keeper.DiveSpeedAtMaxSkill, math.clamp(stats.keeperSkill, 0, 100) / 100)
	local zone = ShotPhysics.classify(target)
	local keeperDives = Keeper.Enabled
		and (zone ~= ShotPhysics.Zone.Wide or (math.abs(target.X) < Goal.Width / 2 + 2.5 and target.Y < Goal.Height + 2.5))
	local home = Vector3.new(Keeper.HomeX, Keeper.HomeY, 0)
	local keeperTarget = home

	local function keeperResponse(t: number, at: Vector3, vel: Vector3)
		if not Keeper.Enabled then
			return nil
		end
		local toBall = Vector3.new(at.X, at.Y, 0) - home
		local distance = toBall.Magnitude
		local direction = if distance > 1e-3 then toBall / distance else Vector3.zero
		local canTravel = diveSpeed * math.max(0, t - reaction)
		local mustTravel = math.max(0, distance - Keeper.Reach)
		if not keeperDives then
			keeperTarget = home + direction * math.min(canTravel, 1.5) -- a step towards it, then watches it go
			return nil
		end
		keeperTarget = home + direction * math.min(canTravel, mustTravel)
		if canTravel < mustTravel then
			return nil -- beaten
		end

		local speed = vel.Magnitude
		local atBody = distance < Keeper.Reach * 0.7 and speed <= Keeper.CatchMaxSpeed * 1.3
		local comfortable = canTravel - mustTravel >= Keeper.CatchMargin and speed <= Keeper.CatchMaxSpeed
		if atBody or comfortable then
			return { kind = "CATCH" }
		end
		-- Parry: tip high balls over the bar, push the rest wide and back out.
		local side = math.sign(at.X - Keeper.HomeX)
		if side == 0 then
			side = if rng:NextNumber() < 0.5 then -1 else 1
		end
		local parried
		if at.Y > Goal.Height - 2.5 and math.abs(at.X) < Goal.Width / 2 - 3 then
			parried = Vector3.new(vel.X * 0.2 + (rng:NextNumber() * 2 - 1) * 3, 16 + rng:NextNumber() * 6, vel.Z * 0.12)
		else
			parried = Vector3.new(side * (10 + rng:NextNumber() * 8), 5 + rng:NextNumber() * 7, 2 - vel.Z * 0.18)
		end
		return { kind = "PARRY", velocity = parried }
	end

	local sim = ShotPhysics.simulate(start, velocity, spin, Keeper.HomeZ, keeperResponse)

	-- 4. Outcome from what actually happened in the simulation.
	local outcome, detail, decisiveTime
	if sim.keeperKind == "CATCH" then
		outcome, detail, decisiveTime = "SAVE", "CATCH", sim.keeperTime
	elseif sim.goalTime then
		outcome, decisiveTime = "GOAL", sim.goalTime
		detail = if sim.frameTime and sim.frameTime < sim.goalTime then "POST_IN" else "GOAL"
	elseif sim.keeperKind == "PARRY" then
		outcome, detail, decisiveTime = "SAVE", "PARRY", sim.keeperTime
	elseif sim.frameTime then
		outcome, decisiveTime = "POST", sim.frameTime
		detail = if sim.framePart == "Crossbar" then "BAR" else "POST"
	else
		outcome = "MISS"
		local cross = sim.crossPoint or target
		detail = if cross.Y > Goal.Height + Goal.PostRadius and math.abs(cross.X) < Goal.Width / 2 + 2 then "OVER" else "WIDE"
		decisiveTime = sim.crossTime or sim.duration
	end

	return {
		outcome = outcome,
		detail = detail,
		start = start,
		target = target,
		velocity = velocity,
		spin = spin,
		speedKmh = math.floor(velocity.Magnitude * KMH_PER_STUD_PER_SECOND + 0.5),
		sim = sim,
		decisiveTime = decisiveTime,
		keeperTarget = keeperTarget,
		keeperReaction = reaction,
		keeperDives = keeperDives,
	}
end

return ShotResolver
