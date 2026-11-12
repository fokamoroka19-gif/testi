-- Client entry point for the shot and pass training: wires input, both drills' 3D visuals, the
-- HUD and the finger hint to the server remotes. The client sends only its input; the server
-- decides outcomes and the training flow (shot: guided -> task, pass: guided -> task, free play).

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
local PassVisuals = require(script:WaitForChild("PassVisuals"))

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
ImageLoader.watch() -- stadium banners, keeper kit and players' faces
local visuals = ShotVisuals.new()
local passVisuals = PassVisuals.new()
local input = InputController.new()
local hint = TutorialHint.new()
local currentEpisode = nil
local currentKind = "SHOT"
local waitingForEpisode = false
local bestSpeed = 0 -- fastest goal in the current task attempt, for the completion menu

-- choice: "RETRY" or "NEXT" from the completion menu, otherwise nil.
local function requestEpisode(choice: string?)
	waitingForEpisode = true
	RequestEpisode:FireServer(choice)
end

local function continueWith(choice: string?)
	if waitingForEpisode then
		return
	end
	hud:hideCard()
	requestEpisode(choice)
end

hud.onContinue = function()
	continueWith(nil)
end
hud.onRetry = function()
	continueWith("RETRY")
end
hud.onNext = function()
	continueWith("NEXT")
end

-- Goals panel: in a task, one pip per goal / good pass still needed; in free play, the last results.
local function showProgress(info)
	if info.mode == "FREE" then
		hud:setSeries(info.goals, 10, info.history, info.shots)
	else
		local done = {}
		for _ = 1, info.goals do
			table.insert(done, if info.kind == "PASS" then "GOOD" else "GOAL")
		end
		hud:setSeries(info.goals, info.taskGoals, done)
	end
end

-- Switches the 3D drill (camera, ball, players) between the shot and the pass.
local function setKind(kind: string)
	if kind == currentKind then
		return
	end
	currentKind = kind
	if kind == "PASS" then
		visuals:setActive(false)
		passVisuals:enter()
	else
		passVisuals:exit()
		visuals:setActive(true)
	end
end

input.onShoot = function(a, b, power)
	local episode = currentEpisode
	if not episode then
		return
	end
	input:setEnabled(false)
	hint:hide()
	hud:setPowerZone(nil)
	if episode.kind == "PASS" then
		passVisuals:onPassReleased()
		hud:setTitle("PassFlying")
		SubmitEpisodeInput:FireServer(episode.episodeId, a, b, power, passVisuals:clockTime())
	else
		visuals:onShotReleased()
		hud:setTitle("Flying")
		SubmitEpisodeInput:FireServer(episode.episodeId, a, b, power)
	end
end

EpisodeStarted.OnClientEvent:Connect(function(episode)
	if typeof(episode) ~= "table" or (episode.kind ~= "SHOT" and episode.kind ~= "PASS") then
		return
	end
	waitingForEpisode = false
	currentEpisode = episode
	input:setEnabled(false)
	setKind(episode.kind)
	local pass = episode.kind == "PASS"
	if pass then
		passVisuals:reset(episode.layout)
		input:setMode("PASS", episode.layout.origin)
	else
		visuals:reset()
		input:setMode("SHOT")
	end
	hud:hideCard()
	hud:setPower(0)
	showProgress(episode)
	hud:setMode(episode.kind, episode.mode, episode.taskGoals)
	if episode.shots == 0 then
		bestSpeed = 0
	end

	local guide = episode.mode == "TUTORIAL" and episode.hint
	if guide then
		hint:show(episode.kind, guide)
		hud:setPowerZone(guide.powerMin, guide.powerMax)
		input:setGuide({
			aimX = if pass then nil else guide.aimX,
			aimY = if pass then nil else guide.aimY,
			accepts = function(aimX, aimY)
				return hint:accepts(aimX, aimY)
			end,
			acceptsTarget = function(target)
				return hint:acceptsTarget(target)
			end,
			onRejected = function()
				hint:nudge()
			end,
		})
		passVisuals:setHighlight(if pass then guide.targetIndex else nil)
	else
		hint:hide()
		hud:setPowerZone(nil)
		input:setGuide(nil)
		passVisuals:setHighlight(nil)
	end
	hud:setTitle(if pass then (if guide then "PassTutorialReady" else "PassReady") else (if guide then "TutorialReady" else "Ready"))

	task.delay(ShotConfig.Input.ReadyDelay, function()
		if currentEpisode == episode then
			input:setEnabled(true)
		end
	end)
end)

-- What the card says after each attempt, by the server's training status.
local function showOutcome(result)
	local status = result.status
	local pass = result.kind == "PASS"
	local key = if pass then "PASS_" .. result.detail else result.detail
	local speed = result.speedKmh
	if status == "COMPLETED" then
		hud:showComplete({ kind = result.kind, goals = result.goals, shots = result.shots, bestSpeed = if pass then nil else bestSpeed })
	elseif status == "TUTORIAL_DONE" then
		hud:showResult(key, {
			subtitle = string.format(if pass then hud.text.PassTutorialDone else hud.text.TutorialDone, result.taskGoals),
			button = hud.text.ToTask,
			speedKmh = speed,
		})
	elseif status == "TUTORIAL_RETRY" then
		hud:showResult(key, { subtitle = hud.text.TutorialRetry, speedKmh = speed })
	else
		local left = result.taskGoals - result.goals
		local subtitle = nil
		if result.mode == "TASK" and result.outcome == (if pass then "GOOD" else "GOAL") then
			subtitle = string.format(if pass then hud.text.PassLeft else hud.text.TaskLeft, left)
		end
		hud:showResult(key, { subtitle = subtitle, speedKmh = speed })
	end
end

EpisodeResult.OnClientEvent:Connect(function(result)
	if result.rejected then
		warn("[ShotClient] Server rejected the input:", result.reason)
		currentEpisode = nil
		input:setEnabled(false)
		task.delay(0.5, requestEpisode) -- the server resends the open episode or starts a new one
		return
	end
	if not currentEpisode or result.episodeId ~= currentEpisode.episodeId then
		return
	end
	currentEpisode = nil
	local pass = result.kind == "PASS"
	if not pass and result.mode == "TASK" and result.outcome == "GOAL" then
		bestSpeed = math.max(bestSpeed, result.speedKmh or 0)
	end

	local function onDecisive()
		if result.mode ~= "TUTORIAL" then
			showProgress(result)
			if result.outcome == (if pass then "GOOD" else "GOAL") then
				hud:bumpGoals()
			end
		end
		hud:setTitle(if pass then "PassAfter" else "AfterShot")
		task.delay(CARD_DELAY, function()
			if not currentEpisode and not waitingForEpisode then
				showOutcome(result)
			end
		end)
	end
	if pass then
		passVisuals:playPass(result, onDecisive)
	else
		visuals:playShot(result, onDecisive)
	end
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
	local pass = currentKind == "PASS"
	visuals:update(dt) -- keeper (and the camera while the shot drill is active)
	passVisuals:update(dt)
	input:update()
	if input.enabled then
		local guided = hint:isActive()
		local demoPower = hint:update(dt, input.holding, input.power, hud.scale, input.target)
		if pass then
			passVisuals:updateAiming(true, input.target, input.power, input.holding)
		else
			visuals:updateAiming(true, input.aimX, input.aimY, input.power, input.holding)
		end
		hud:setPower(if input.holding or not demoPower then (if input.holding then input.power else 0) else demoPower)
		local prefix = if pass then "Pass" else ""
		if guided then
			hud:setTitle(prefix .. (if input.holding then "TutorialHolding" else "TutorialReady"))
		else
			hud:setTitle(if pass then (if input.holding then "PassHolding" else "PassReady") else (if input.holding then "Holding" else "Ready"))
		end
	end
	-- The keeper gets set (hop + lower stance) while the player charges a shot.
	local holding = input.enabled and input.holding and not pass
	if holding ~= wasHolding then
		wasHolding = holding
		visuals:setCharging(holding)
	end
end)

requestEpisode()
print("[ShotClient] ready")
