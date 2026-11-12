-- Careers: loads and saves each player's career and settings (DataStore), answers the menu's
-- requests and starts the training. The client only asks; every value is checked here.
--
-- Remote: CareerRequest (RemoteFunction) - (action, payload) -> { ok, error?, career?, settings?, ... }
--   get        -> current career (nil if none), settings, whether saving works
--   create     { clubId, firstName, lastName, number } -> new career; training starts at SHOT
--   continue   -> resumes the training at the saved stage, or reports that it is done
--   retrain    -> training again from the shot stage (career kept)
--   menu       -> leaves the training (back to the main menu)
--   settings   { key, value } -> stores one setting
--   reset      -> deletes the career
--
-- Without DataStore access (Studio with API access off, outages) careers live for the session
-- only; `saveAvailable` tells the menu.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CareerConfig = require(Shared:WaitForChild("CareerConfig"))
local ShotConfig = require(Shared:WaitForChild("ShotConfig"))

local STORE_NAME = "NFS_Careers_v1"
local RETRIES = 3
local MIN_INTERVAL = 0.25 -- seconds between requests per player
local LOAD_WAIT = 15 -- seconds a request waits for the player's data to load

type Career = {
	clubId: string,
	firstName: string,
	lastName: string,
	number: number,
	position: string,
	ovr: number,
	tutorialStage: string, -- SHOT | PASS | DONE
	completedTutorial: boolean,
	createdAt: number,
	lastUpdated: number,
}
type Profile = {
	loaded: boolean,
	saveAvailable: boolean,
	dirty: boolean,
	lastRequest: number,
	data: { schemaVersion: number, career: Career?, settings: { [string]: boolean } },
}

local CareerService = {}

local profiles: { [Player]: Profile } = {}
local episodeService
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[CareerService] DataStore unavailable, careers will last for this session only:", result)
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function defaultData()
	return { schemaVersion = CareerConfig.SchemaVersion, career = nil, settings = table.clone(CareerConfig.DefaultSettings) }
end

-- Old or damaged saves: keep what is valid, default the rest.
local function migrate(raw: any)
	local data = defaultData()
	if type(raw) ~= "table" then
		return data
	end
	if type(raw.settings) == "table" then
		for key, default in CareerConfig.DefaultSettings do
			if type(raw.settings[key]) == type(default) then
				data.settings[key] = raw.settings[key]
			end
		end
	end
	local c = raw.career
	if type(c) == "table" and CareerConfig.club(c.clubId) and CareerConfig.validateName(c.firstName)
		and CareerConfig.validateName(c.lastName) and CareerConfig.validateNumber(c.number) then
		local stage = if c.tutorialStage == "PASS" or c.tutorialStage == "DONE" then c.tutorialStage else "SHOT"
		data.career = {
			clubId = c.clubId,
			firstName = c.firstName,
			lastName = c.lastName,
			number = c.number,
			position = CareerConfig.Position,
			ovr = if type(c.ovr) == "number" then c.ovr else CareerConfig.PlayerStartOvr,
			tutorialStage = stage,
			completedTutorial = stage == "DONE",
			createdAt = if type(c.createdAt) == "number" then c.createdAt else os.time(),
			lastUpdated = if type(c.lastUpdated) == "number" then c.lastUpdated else os.time(),
		}
	end
	return data
end

local function withRetries(label: string, fn: () -> any): (boolean, any)
	local ok, result
	for attempt = 1, RETRIES do
		ok, result = pcall(fn)
		if ok then
			return true, result
		end
		if attempt < RETRIES then
			task.wait(attempt)
		end
	end
	warn(string.format("[CareerService] %s failed: %s", label, tostring(result)))
	return false, result
end

local function load(player: Player)
	local profile: Profile = { loaded = false, saveAvailable = store ~= nil, dirty = false, lastRequest = -math.huge, data = defaultData() }
	profiles[player] = profile
	if store then
		local ok, raw = withRetries("load " .. player.Name, function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			profile.data = migrate(raw)
		else
			profile.saveAvailable = false -- don't overwrite a save we couldn't read
		end
	end
	profile.loaded = true
	local career = profile.data.career
	print(string.format(
		"[CareerService] %s: %s (saving %s)",
		player.Name,
		if career then string.format("career %s %s #%d at %s, %s", career.firstName, career.lastName, career.number, career.clubId, career.tutorialStage) else "no career",
		if profile.saveAvailable then "on" else "off"
	))
end

local function save(player: Player)
	local profile = profiles[player]
	if not (profile and profile.loaded and profile.saveAvailable and profile.dirty) then
		return
	end
	profile.dirty = false
	local data = profile.data
	local ok = withRetries("save " .. player.Name, function()
		store:SetAsync(keyFor(player), data, { player.UserId })
	end)
	if not ok then
		profile.dirty = true
	end
end

local function markChanged(player: Player, now: boolean?)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.dirty = true
	local career = profile.data.career
	if career then
		career.lastUpdated = os.time()
	end
	if now then
		task.spawn(save, player)
	end
end

-- Roblox requires filtering text that players type. Returns the name or nil if it was filtered.
local function filterName(player: Player, name: string): (string?, string?)
	local ok, result = pcall(function()
		local filtered = TextService:FilterStringAsync(name, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		if RunService:IsStudio() then
			return name, nil -- filtering isn't always reachable in Studio
		end
		return nil, "Не удалось проверить имя, попробуй ещё раз"
	end
	if result ~= name then
		return nil, "Это имя нельзя использовать"
	end
	return name, nil
end

local function publicCareer(career: Career?)
	return if career then table.clone(career) else nil
end

local function snapshot(profile: Profile)
	return {
		ok = true,
		career = publicCareer(profile.data.career),
		settings = table.clone(profile.data.settings),
		saveAvailable = profile.saveAvailable,
	}
end

local function fail(message: string)
	return { ok = false, error = message }
end

local actions = {}

function actions.get(player: Player, profile: Profile)
	return snapshot(profile)
end

function actions.create(player: Player, profile: Profile, payload: any)
	if type(payload) ~= "table" then
		return fail("Неверные данные")
	end
	local club = CareerConfig.club(payload.clubId)
	if not club or not club.open then
		return fail("Этот клуб пока недоступен")
	end
	local firstName, firstError = CareerConfig.validateName(payload.firstName)
	if not firstName then
		return fail("Имя: " .. (firstError or ""))
	end
	local lastName, lastError = CareerConfig.validateName(payload.lastName)
	if not lastName then
		return fail("Фамилия: " .. (lastError or ""))
	end
	local number = CareerConfig.validateNumber(payload.number)
	if not number then
		return fail("Номер от 1 до 99")
	end
	local filteredFirst, filterError = filterName(player, firstName)
	if not filteredFirst then
		return fail(filterError or "")
	end
	local filteredLast, filterError2 = filterName(player, lastName)
	if not filteredLast then
		return fail(filterError2 or "")
	end
	local start = if ShotConfig.Training.StartStage == "PASS" then "PASS" else "SHOT"
	profile.data.career = {
		clubId = club.id,
		firstName = filteredFirst,
		lastName = filteredLast,
		number = number,
		position = CareerConfig.Position,
		ovr = CareerConfig.PlayerStartOvr,
		tutorialStage = start,
		completedTutorial = false,
		createdAt = os.time(),
		lastUpdated = os.time(),
	}
	markChanged(player, true)
	print(string.format("[CareerService] %s: new career %s %s #%d at %s", player.Name, filteredFirst, filteredLast, number, club.id))
	episodeService.startTraining(player, start)
	local result = snapshot(profile)
	result.mode = "TRAINING"
	return result
end

function actions.continue(player: Player, profile: Profile)
	local career = profile.data.career
	if not career then
		return fail("Нет сохранённой карьеры")
	end
	local result = snapshot(profile)
	if career.tutorialStage == "DONE" then
		result.mode = "DONE"
	else
		episodeService.startTraining(player, career.tutorialStage)
		result.mode = "TRAINING"
	end
	return result
end

function actions.retrain(player: Player, profile: Profile)
	if not profile.data.career then
		return fail("Нет сохранённой карьеры")
	end
	episodeService.startTraining(player, "SHOT")
	local result = snapshot(profile)
	result.mode = "TRAINING"
	return result
end

function actions.menu(player: Player, profile: Profile)
	episodeService.stopTraining(player)
	return snapshot(profile)
end

function actions.settings(player: Player, profile: Profile, payload: any)
	if type(payload) ~= "table" then
		return fail("Неверные данные")
	end
	local default = CareerConfig.DefaultSettings[payload.key]
	if default == nil or type(payload.value) ~= type(default) then
		return fail("Неверная настройка")
	end
	profile.data.settings[payload.key] = payload.value
	markChanged(player) -- saved on leave / periodically; settings are not critical
	return snapshot(profile)
end

function actions.reset(player: Player, profile: Profile)
	episodeService.stopTraining(player)
	profile.data.career = nil
	markChanged(player, true)
	print(string.format("[CareerService] %s: career deleted", player.Name))
	return snapshot(profile)
end

local function onInvoke(player: Player, action: any, payload: any)
	local profile = profiles[player]
	local waited = 0
	while not (profile and profile.loaded) and waited < LOAD_WAIT do
		waited += task.wait(0.1)
		profile = profiles[player]
	end
	if not (profile and profile.loaded) then
		return fail("Данные ещё загружаются, попробуй ещё раз")
	end
	local handler = type(action) == "string" and actions[action]
	if not handler then
		return fail("Неизвестный запрос")
	end
	local now = os.clock()
	if action ~= "get" and now - profile.lastRequest < MIN_INTERVAL then
		return fail("Слишком часто, попробуй ещё раз")
	end
	profile.lastRequest = now
	return handler(player, profile, payload)
end

local function onStageChanged(player: Player, stage: string)
	local profile = profiles[player]
	local career = profile and profile.data.career
	if not career then
		return
	end
	career.tutorialStage = stage
	career.completedTutorial = career.completedTutorial or stage == "DONE"
	markChanged(player, true)
end

function CareerService.init(remotes, episodes)
	episodeService = episodes
	episodes.onStageChanged = onStageChanged
	remotes.CareerRequest.OnServerInvoke = onInvoke

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
	-- Settings and other small changes are written every minute at most.
	task.spawn(function()
		while true do
			task.wait(60)
			for player in profiles do
				task.spawn(save, player)
			end
		end
	end)
end

return CareerService
