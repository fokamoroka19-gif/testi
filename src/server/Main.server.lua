-- Server entry point: main menu and career (CareerService), shot and pass training (EpisodeService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- First, before anything can yield: no avatar in Stage 1 (fixed camera, and phones would
-- otherwise show the thumbstick and jump button over the goal).
Players.CharacterAutoLoads = false
for _, player in Players:GetPlayers() do
	if player.Character then
		player.Character:Destroy()
	end
end

if ReplicatedStorage:GetAttribute("ShotServerRunning") then
	warn("[Main] Another copy of the Main script is already running. Delete the duplicate.")
	return
end
ReplicatedStorage:SetAttribute("ShotServerRunning", true)

-- Modules are looked up by name anywhere under ServerScriptService, so it doesn't matter
-- whether they sit next to this script or inside a Services folder.
local function requireServerModule(name: string)
	local module = ServerScriptService:FindFirstChild(name, true)
	if not (module and module:IsA("ModuleScript")) then
		error(string.format("[Main] ModuleScript '%s' was not found in ServerScriptService. See README > Setup.", name), 0)
	end
	return require(module)
end

local shared = ReplicatedStorage:FindFirstChild("Shared")
for _, name in { "ShotConfig", "ShotPhysics", "PassConfig", "PassPhysics", "FigureBuilder", "CareerConfig" } do
	if not (shared and shared:FindFirstChild(name)) then
		error(string.format("[Main] ReplicatedStorage > Shared > %s (ModuleScript) is missing. See README > Setup.", name), 0)
	end
end

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
local careerRequest = remotesFolder:FindFirstChild("CareerRequest")
if not careerRequest then
	careerRequest = Instance.new("RemoteFunction")
	careerRequest.Name = "CareerRequest"
	careerRequest.Parent = remotesFolder
end
remotes.CareerRequest = careerRequest

local SceneBuilder = requireServerModule("SceneBuilder")
local KeeperBuilder = requireServerModule("KeeperBuilder")
local EpisodeService = requireServerModule("EpisodeService")
local CareerService = requireServerModule("CareerService")

local scene = SceneBuilder.build()
KeeperBuilder.build(scene)
EpisodeService.init(remotes)
CareerService.init(remotes, EpisodeService)

print("[Main] Main menu, career and training ready")
