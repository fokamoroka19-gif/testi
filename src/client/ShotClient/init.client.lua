-- Client entry point for the Stage 1 shot: wires input and visuals to the server remotes.
-- The client sends only aim and power; the server decides the outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))
local InputController = require(script:WaitForChild("InputController"))
local ShotVisuals = require(script:WaitForChild("ShotVisuals"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	warn("[ShotClient] Still waiting for ReplicatedStorage.Remotes. The server script (Main) has not started; check Output for red [Main] errors.")
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
end
local RequestEpisode = Remotes:WaitForChild("RequestEpisode")
local EpisodeStarted = Remotes:WaitForChild("EpisodeStarted")
local SubmitEpisodeInput = Remotes:WaitForChild("SubmitEpisodeInput")
local EpisodeResult = Remotes:WaitForChild("EpisodeResult")

local HINT = "Hold on the goal to aim and charge, release to shoot"

-- Default movement controls are useless here and would cover the screen on phones.
task.spawn(function()
	local playerModule = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
	if playerModule then
		local ok, err = pcall(function()
			require(playerModule):GetControls():Disable()
		end)
		if not ok then
			warn("[ShotClient] Could not disable default controls:", err)
		end
	end
end)

local visuals = ShotVisuals.new()
local input = InputController.new()
local currentEpisode = nil

local function requestEpisode()
	RequestEpisode:FireServer()
end

input.onShoot = function(aimX, aimY, power)
	local episode = currentEpisode
	if not episode then
		return
	end
	input:setEnabled(false)
	visuals:onShotReleased()
	SubmitEpisodeInput:FireServer(episode.episodeId, aimX, aimY, power)
end

EpisodeStarted.OnClientEvent:Connect(function(episode)
	if typeof(episode) ~= "table" or episode.kind ~= "SHOT" then
		return
	end
	currentEpisode = episode
	input:setEnabled(false)
	visuals:reset()
	task.delay(ShotConfig.Input.ReadyDelay, function()
		if currentEpisode == episode then
			input:setEnabled(true)
			visuals:setHint(HINT)
		end
	end)
end)

EpisodeResult.OnClientEvent:Connect(function(result)
	if result.rejected then
		warn("[ShotClient] Server rejected the shot:", result.reason)
		currentEpisode = nil
		input:setEnabled(false)
		task.delay(0.5, requestEpisode) -- the server resends the open episode or starts a new one
		return
	end
	if not currentEpisode or result.episodeId ~= currentEpisode.episodeId then
		return
	end

	currentEpisode = nil
	visuals:playShot(result)
	requestEpisode()
end)

RunService.RenderStepped:Connect(function(dt)
	visuals:update(dt)
	input:update()
	if input.enabled then
		visuals:updateAiming(true, input.aimX, input.aimY, input.power, input.holding)
	end
end)

requestEpisode()
print("[ShotClient] ready")
