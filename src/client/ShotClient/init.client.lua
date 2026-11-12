-- Client entry point for the Stage 1 shot training: wires input, 3D visuals, HUD and the finger
-- hint to the server remotes. The client sends only aim and power; the server decides the
-- outcome and the training flow (guided shot -> task -> completed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ShotConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ShotConfig"))
local InputController = require(script:WaitForChild("InputController"))
local ShotVisuals = require(script:WaitForChild("ShotVisuals"))
local ShotHud = require(script:WaitForChild("ShotHud"))
local ImageLoader = require(script:WaitForChild("ImageLoader"))
local TutorialHint = require(script:WaitForChild("TutorialHint"))

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
local hint = TutorialHint.new()
local currentEpisode = nil
local waitingForEpisode = false
local bestSpeed = 0 -- fastest goal in the current task attempt, for the completion menu

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
	hint:hide()
	hud:setPowerZone(nil)
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
	hud:setPower(0)
	hud:setSeries(episode.goals, episode.taskShots, episode.history)
	hud:setTask(episode.mode, episode.shots, episode.taskShots, episode.taskGoals)
	if episode.shots == 0 then
		bestSpeed = 0
	end

	local guide = episode.mode == "TUTORIAL" and episode.hint
	if guide then
		hint:show(guide)
		hud:setPowerZone(guide.powerMin, guide.powerMax)
		input:setGuide({
			aimX = guide.aimX,
			aimY = guide.aimY,
			accepts = function(aimX, aimY)
				return hint:accepts(aimX, aimY)
			end,
			onRejected = function()
				hint:nudge()
			end,
		})
	else
		hint:hide()
		hud:setPowerZone(nil)
		input:setGuide(nil)
	end
	hud:setTitle(if guide then "TutorialReady" else "Ready")

	task.delay(ShotConfig.Input.ReadyDelay, function()
		if currentEpisode == episode then
			input:setEnabled(true)
		end
	end)
end)

-- What the card says after each shot, by the server's training status.
local function showOutcome(result)
	local status = result.status
	local speed = result.speedKmh
	if status == "COMPLETED" then
		hud:showComplete({ goals = result.goals, taskShots = result.taskShots, bestSpeed = bestSpeed })
	elseif status == "TUTORIAL_DONE" then
		hud:showResult(result.detail, {
			subtitle = string.format(hud.text.TutorialDone, result.taskGoals, result.taskShots),
			button = hud.text.ToTask,
			speedKmh = speed,
		})
	elseif status == "TUTORIAL_RETRY" then
		hud:showResult(result.detail, { subtitle = hud.text.TutorialRetry, speedKmh = speed })
	elseif status == "FAILED" then
		hud:showResult(result.detail, {
			subtitle = string.format(hud.text.TaskFailed, result.taskGoals, result.taskShots),
			button = hud.text.Retry,
			speedKmh = speed,
		})
	else
		local left = result.taskGoals - result.goals
		local subtitle = if result.outcome == "GOAL" then string.format(hud.text.TaskLeft, left) else nil
		hud:showResult(result.detail, { subtitle = subtitle, speedKmh = speed })
	end
end

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
	if result.mode == "TASK" and result.outcome == "GOAL" then
		bestSpeed = math.max(bestSpeed, result.speedKmh or 0)
	end

	visuals:playShot(result, function()
		if result.mode == "TASK" then
			hud:setSeries(result.goals, result.taskShots, result.history)
			if result.outcome == "GOAL" then
				hud:bumpGoals()
			end
		end
		hud:setTitle("AfterShot")
		task.delay(CARD_DELAY, function()
			if not currentEpisode and not waitingForEpisode then
				showOutcome(result)
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
		local guided = hint:isActive()
		local demoPower = hint:update(dt, input.holding, input.power)
		visuals:updateAiming(true, input.aimX, input.aimY, input.power, input.holding)
		hud:setPower(if input.holding or not demoPower then input.power else demoPower)
		if guided then
			hud:setTitle(if input.holding then "TutorialHolding" else "TutorialReady")
		else
			hud:setTitle(if input.holding then "Holding" else "Ready")
		end
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
