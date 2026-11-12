-- Owns interactive episodes: hands them out, validates client input and sends back results.
-- The client only ever sends {episodeId, aimX, aimY, power}; it never reports an outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))
local ShotResolver = require(script.Parent.ShotResolver)

type Episode = { id: number, kind: string, seed: number, startedAt: number }
type PlayerState = {
	nextEpisodeId: number,
	active: Episode?,
	lastRemoteAt: number,
	shots: number, -- shots taken in the current series
	goals: number,
	history: { string }, -- outcome of each shot in the current series
}

local SERIES_LENGTH = ShotConfig.Drill.ShotsPerSeries

local EpisodeService = {}

local states: { [Player]: PlayerState } = {}
local seedSource = Random.new()
local remotes

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { nextEpisodeId = 1, active = nil, lastRemoteAt = -math.huge, shots = 0, goals = 0, history = {} }
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

local function sendEpisode(player: Player, state: PlayerState, episode: Episode)
	remotes.EpisodeStarted:FireClient(player, {
		episodeId = episode.id,
		kind = episode.kind,
		shotNumber = state.shots + 1,
		seriesLength = SERIES_LENGTH,
		goals = state.goals,
		history = table.clone(state.history),
	})
end

local function startEpisode(player: Player, state: PlayerState)
	if state.shots >= SERIES_LENGTH then
		state.shots, state.goals, state.history = 0, 0, {}
	end
	local episode = {
		id = state.nextEpisodeId,
		kind = "SHOT",
		-- Logged so any result can be reproduced from (seed, input).
		seed = seedSource:NextInteger(1, 2 ^ 31 - 1),
		startedAt = os.clock(),
	}
	state.nextEpisodeId += 1
	state.active = episode
	print(string.format("[EpisodeService] %s: episode #%d started (SHOT, seed %d)", player.Name, episode.id, episode.seed))
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

local function onRequestEpisode(player: Player)
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
	startEpisode(player, state)
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
	local stats = { shooting = ShotConfig.DefaultShooting, keeperSkill = ShotConfig.Goalkeeper.Skill }
	local result = ShotResolver.resolve(input, stats, Random.new(active.seed))

	state.shots += 1
	if result.outcome == "GOAL" then
		state.goals += 1
	end
	table.insert(state.history, result.outcome)
	local seriesOver = state.shots >= SERIES_LENGTH

	print(string.format(
		"[EpisodeService] %s: episode #%d aim=(%.2f, %.2f) power=%.2f -> %s/%s, %d km/h (%d goals from %d/%d shots)",
		player.Name, active.id, input.aimX, input.aimY, input.power, result.outcome, result.detail, result.speedKmh,
		state.goals, state.shots, SERIES_LENGTH
	))
	if seriesOver then
		print(string.format("[EpisodeService] %s: series finished, %d/%d goals", player.Name, state.goals, SERIES_LENGTH))
	end

	local sim = result.sim
	remotes.EpisodeResult:FireClient(player, {
		episodeId = active.id,
		outcome = result.outcome,
		detail = result.detail,
		speedKmh = result.speedKmh,
		-- The client replays this exact path, so what it shows always matches the outcome.
		path = sim.path,
		sampleStep = ShotConfig.Physics.SampleStep,
		events = sim.events,
		spin = result.spin,
		held = sim.held,
		decisiveTime = result.decisiveTime,
		keeperTime = sim.keeperTime,
		keeperTarget = result.keeperTarget,
		keeperReaction = result.keeperReaction,
		keeperDives = result.keeperDives,
		keeperKind = sim.keeperKind,
		shots = state.shots,
		goals = state.goals,
		seriesLength = SERIES_LENGTH,
		seriesOver = seriesOver,
		history = table.clone(state.history),
	})
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
