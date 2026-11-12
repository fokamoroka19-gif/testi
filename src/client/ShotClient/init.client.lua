-- Client entry point for the Stage 1 shot: wires input, 3D visuals and HUD to the server remotes.
-- The client sends only aim and power; the server decides the outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))
local InputController = require(script:WaitForChild("InputController"))
local ShotVisuals = require(script:WaitForChild("ShotVisuals"))
local ShotHud = require(script:WaitForChild("ShotHud"))
local ImageLoader = require(script:WaitForChild("ImageLoader"))

local CARD_DELAY = 0.55 -- let the player see the ball hit the net before the card covers the goal

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not Remotes then
	warn("[ShotClient] Still waiting for ReplicatedStorage.Remotes. The server script (Main) has not started; check Output for red [Main] errors.")
	Remotes = ReplicatedStorage:WaitForChild("Remotes")
end
local RequestEpisode = Remotes:WaitForChild("RequestEpisode")
local EpisodeStarted = Remotes:WaitForChild("EpisodeStarted")
local SubmitEpisodeInput = Remotes:WaitForChild("SubmitEpisodeInput")
local EpisodeResult = Remotes:WaitForChild("EpisodeResult")

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

local hud = ShotHud.new()
ImageLoader.watch() -- stadium banners and keeper kit textures
local visuals = ShotVisuals.new()
local input = InputController.new()
local currentEpisode = nil
local waitingForEpisode = false

local function requestEpisode()
	waitingForEpisode = true
	RequestEpisode:FireServer()
end

hud.onContinue = function()
	if waitingForEpisode then
		return
	end
	hud:hideCard()
	requestEpisode()
end

input.onShoot = function(aimX, aimY, power)
	local episode = currentEpisode
	if not episode then
		return
	end
	input:setEnabled(false)
	visuals:onShotReleased()
	hud:setTitle("Flying")
	SubmitEpisodeInput:FireServer(episode.episodeId, aimX, aimY, power)
end

EpisodeStarted.OnClientEvent:Connect(function(episode)
	if typeof(episode) ~= "table" or episode.kind ~= "SHOT" then
		return
	end
	waitingForEpisode = false
	currentEpisode = episode
	input:setEnabled(false)
	visuals:reset()
	hud:hideCard()
	hud:setTitle("Ready")
	hud:setPower(0)
	hud:setSeries(episode.goals, episode.seriesLength, episode.history)
	task.delay(ShotConfig.Input.ReadyDelay, function()
		if currentEpisode == episode then
			input:setEnabled(true)
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

	visuals:playShot(result, function()
		hud:setSeries(result.goals, result.seriesLength, result.history)
		if result.outcome == "GOAL" then
			hud:bumpGoals()
		end
		hud:setTitle("AfterShot")
		task.delay(CARD_DELAY, function()
			if not currentEpisode and not waitingForEpisode then
				local seriesText = if result.seriesOver then hud:seriesText(result.goals, result.seriesLength) else nil
				hud:showResult(result.detail, seriesText, { speedKmh = result.speedKmh })
			end
		end)
	end)
end)

-- Space / Enter / gamepad A press the card button.
UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed or not hud:isCardVisible() then
		return
	end
	local key = inputObject.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA then
		hud:pressContinue()
	end
end)

local wasHolding = false
RunService.RenderStepped:Connect(function(dt)
	visuals:update(dt)
	input:update()
	if input.enabled then
		visuals:updateAiming(true, input.aimX, input.aimY, input.power, input.holding)
		hud:setPower(input.power)
		hud:setTitle(if input.holding then "Holding" else "Ready")
	end
	-- The keeper gets set (hop + lower stance) while the player charges.
	local holding = input.enabled and input.holding
	if holding ~= wasHolding then
		wasHolding = holding
		visuals:setCharging(holding)
	end
end)

requestEpisode()
print("[ShotClient] ready")
