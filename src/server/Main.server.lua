-- Server entry point for the Stage 1 shot prototype.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SceneBuilder = require(script.Parent:WaitForChild("SceneBuilder"))
local EpisodeService = require(script.Parent:WaitForChild("Services"):WaitForChild("EpisodeService"))

-- No avatar in Stage 1: the shot is played from a fixed camera, and without a character
-- phones don't show the movement thumbstick and jump button over the goal.
Players.CharacterAutoLoads = false

local REMOTE_NAMES = { "RequestEpisode", "EpisodeStarted", "SubmitEpisodeInput", "EpisodeResult" }

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local remotes = {}
for _, name in REMOTE_NAMES do
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	remotes[name] = remote
end

SceneBuilder.build()
EpisodeService.init(remotes)

print("[Main] Stage 1 shot prototype ready")
