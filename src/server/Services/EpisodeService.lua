-- Owns interactive episodes: hands them out, validates client input and sends back results.
-- The client only ever sends {episodeId, aimX, aimY, power}; it never reports an outcome.
--
-- Shot training flow, decided here so the client can't skip it:
--   TUTORIAL  one guided shot (finger hint on the client) that always scores
--   TASK      score Training.TaskGoals goals; misses don't reset anything
--   DONE      task completed; the menu asks for "RETRY" (task again) or "NEXT"
--   FREE      free play with the normal keeper (placeholder until the pass training, stage 2, exists)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))
local ShotResolver = require(script.Parent.ShotResolver)

local Training = ShotConfig.Training

type Episode = { id: number, kind: string, mode: string, seed: number, startedAt: number }
type PlayerState = {
	nextEpisodeId: number,
	active: Episode?,
	lastRemoteAt: number,
	phase: string, -- "TUTORIAL" | "TASK" | "DONE" | "FREE"
	shots: number, -- shots taken in the current task attempt (or in free play)
	goals: number,
	history: { string }, -- outcome of each shot, most recent last (free play keeps the last 10)
}

local EpisodeService = {}

local states: { [Player]: PlayerState } = {}
local seedSource = Random.new()
local remotes

local FREE_HISTORY = 10

local function resetCounters(state: PlayerState)
	state.shots, state.goals, state.history = 0, 0, {}
end

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = {
			nextEpisodeId = 1,
			active = nil,
			lastRemoteAt = -math.huge,
			phase = "TUTORIAL",
			shots = 0,
			goals = 0,
			history = {},
		}
		states[player] = state
	end
	return state
end

local function passesRateLimit(state: PlayerState): boolean
	local now = os.clock()
	if now - state.lastRemoteAt < ShotConfig.Episode.MinRemoteInterval then
		return false
	end
	state.lastRemoteAt = now
	return true
end

-- Rejects non-numbers, NaN, infinities and out-of-range values.
local function isNumberInRange(value: any, min: number, max: number): boolean
	if typeof(value) ~= "number" or value ~= value then
		return false
	end
	local tolerance = ShotConfig.Episode.InputTolerance
	return value >= min - tolerance and value <= max + tolerance
end

local function progress(state: PlayerState)
	return {
		goals = state.goals,
		shots = state.shots,
		taskGoals = Training.TaskGoals,
		history = table.clone(state.history),
	}
end

local function sendEpisode(player: Player, state: PlayerState, episode: Episode)
	local payload = progress(state)
	payload.episodeId = episode.id
	payload.kind = episode.kind
	payload.mode = episode.mode
	if episode.mode == "TUTORIAL" then
		payload.hint = {
			aimX = Training.TutorialAim.X,
			aimY = Training.TutorialAim.Y,
			ringRadius = Training.TutorialRingRadius,
			tapRadius = Training.TutorialTapRadius,
			powerMin = Training.GuidedPowerMin,
			powerMax = Training.GuidedPowerMax,
		}
	end
	remotes.EpisodeStarted:FireClient(player, payload)
end

-- choice: what the completion menu asked for ("RETRY" or "NEXT"); ignored in other phases.
local function startEpisode(player: Player, state: PlayerState, choice: string?)
	if state.phase == "DONE" then
		state.phase = if choice == "NEXT" then "FREE" else "TASK"
		resetCounters(state)
	end
	local episode = {
		id = state.nextEpisodeId,
		kind = "SHOT",
		mode = state.phase,
		-- Logged so any result can be reproduced from (seed, input, mode).
		seed = seedSource:NextInteger(1, 2 ^ 31 - 1),
		startedAt = os.clock(),
	}
	state.nextEpisodeId += 1
	state.active = episode
	print(string.format("[EpisodeService] %s: episode #%d started (SHOT %s, seed %d)", player.Name, episode.id, episode.mode, episode.seed))
	sendEpisode(player, state, episode)
end

local function reject(player: Player, episodeId: any, reason: string)
	warn(string.format("[EpisodeService] %s: rejected input for episode %s (%s)", player.Name, tostring(episodeId), reason))
	remotes.EpisodeResult:FireClient(player, {
		episodeId = if typeof(episodeId) == "number" then episodeId else nil,
		rejected = true,
		reason = reason,
	})
end

local function onRequestEpisode(player: Player, choice: any)
	local state = getState(player)
	if not passesRateLimit(state) then
		return
	end

	local active = state.active
	if active and os.clock() - active.startedAt <= ShotConfig.Episode.Timeout then
		-- Client lost track of it (e.g. after a rejection): resend instead of issuing a new one.
		sendEpisode(player, state, active)
		return
	end
	startEpisode(player, state, if typeof(choice) == "string" then choice else nil)
end

-- Updates the training progress after a shot and returns what happens next:
-- TUTORIAL_DONE | TUTORIAL_RETRY | CONTINUE | COMPLETED
local function advance(state: PlayerState, mode: string, outcome: string): string
	if mode == "TUTORIAL" then
		if outcome ~= "GOAL" then
			return "TUTORIAL_RETRY" -- should not happen: guided shots always score
		end
		state.phase = "TASK"
		resetCounters(state)
		return "TUTORIAL_DONE"
	end

	state.shots += 1
	if outcome == "GOAL" then
		state.goals += 1
	end
	table.insert(state.history, outcome)
	if mode == "FREE" then
		if #state.history > FREE_HISTORY then
			table.remove(state.history, 1)
		end
		return "CONTINUE"
	end
	if state.goals >= Training.TaskGoals then
		state.phase = "DONE"
		return "COMPLETED"
	end
	return "CONTINUE"
end

local function onSubmitEpisodeInput(player: Player, episodeId: any, aimX: any, aimY: any, power: any)
	local state = getState(player)
	if not passesRateLimit(state) then
		return
	end

	local active = state.active
	if not active or episodeId ~= active.id then
		reject(player, episodeId, "unknown or already finished episode")
		return
	end
	if not (isNumberInRange(aimX, -1, 1) and isNumberInRange(aimY, 0, 1) and isNumberInRange(power, 0, 1)) then
		reject(player, episodeId, "invalid input values")
		return
	end

	local elapsed = os.clock() - active.startedAt
	if elapsed < ShotConfig.Episode.MinThinkTime then
		reject(player, episodeId, "input too early")
		return
	end
	if elapsed > ShotConfig.Episode.Timeout then
		state.active = nil
		reject(player, episodeId, "episode expired")
		return
	end

	-- Consume before resolving so the same episode can never produce a second result.
	state.active = nil

	local input = {
		aimX = math.clamp(aimX, -1, 1),
		aimY = math.clamp(aimY, 0, 1),
		power = math.clamp(power, 0, 1),
	}
	local stats = { shooting = ShotConfig.DefaultShooting, keeperSkill = Training.TaskKeeperSkill }
	local options
	if active.mode == "TUTORIAL" then
		options = { guided = { aimX = Training.TutorialAim.X, aimY = Training.TutorialAim.Y } }
	elseif active.mode == "TASK" then
		options = { keeperDelay = Training.TaskKeeperDelay }
	else
		stats.keeperSkill = ShotConfig.Goalkeeper.Skill
	end
	local result = ShotResolver.resolve(input, stats, Random.new(active.seed), options)
	local status = advance(state, active.mode, result.outcome)

	local used = result.input
	print(string.format(
		"[EpisodeService] %s: episode #%d %s aim=(%.2f, %.2f) power=%.2f -> %s/%s, %d km/h, %s (%d goals from %d shots)",
		player.Name, active.id, active.mode, used.aimX, used.aimY, used.power, result.outcome, result.detail, result.speedKmh,
		status, state.goals, state.shots
	))

	local sim = result.sim
	local payload = progress(state)
	payload.episodeId = active.id
	payload.mode = active.mode
	payload.status = status
	payload.outcome = result.outcome
	payload.detail = result.detail
	payload.speedKmh = result.speedKmh
	-- The client replays this exact path, so what it shows always matches the outcome.
	payload.path = sim.path
	payload.sampleStep = ShotConfig.Physics.SampleStep
	payload.events = sim.events
	payload.spin = result.spin
	payload.held = sim.held
	payload.decisiveTime = result.decisiveTime
	payload.keeperTime = sim.keeperTime
	payload.keeperTarget = result.keeperTarget
	payload.keeperReaction = result.keeperReaction
	payload.keeperDives = result.keeperDives
	payload.keeperKind = sim.keeperKind
	remotes.EpisodeResult:FireClient(player, payload)
end

function EpisodeService.init(remoteEvents)
	if remotes then
		warn("[EpisodeService] init called twice; ignoring")
		return
	end
	remotes = remoteEvents
	remotes.RequestEpisode.OnServerEvent:Connect(onRequestEpisode)
	remotes.SubmitEpisodeInput.OnServerEvent:Connect(onSubmitEpisodeInput)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return EpisodeService
