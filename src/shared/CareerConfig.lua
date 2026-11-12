-- Career setup shared by the server (validation, saves) and the client (menus): the league and its
-- clubs, the player-creation rules and the default settings.

local CareerConfig = {}

CareerConfig.League = "ЛИГА NFS"
CareerConfig.Season = "СЕЗОН 1"
CareerConfig.SchemaVersion = 1

export type Club = {
	id: string,
	name: string,
	short: string, -- 3 letters on the crest
	ovr: number,
	stars: number, -- 0.5 steps, for the club card
	open: boolean, -- can be picked by a new player
	unlockOvr: number?, -- locked clubs: player rating needed (shown on the card)
	shirt: Color3,
	trim: Color3, -- names and numbers on the shirt, crest stripe
	shorts: Color3,
	socks: Color3,
}

local rgb = Color3.fromRGB

-- The eight clubs of the GDD (§ Clubs). A new player (OVR ~40) only gets offers from the three
-- weakest; the others show what there is to play for.
CareerConfig.Clubs = {
	{ id = "ASH", name = "Ashford Town", short = "ASH", ovr = 59, stars = 1.5, open = true,
		shirt = rgb(46, 204, 113), trim = rgb(255, 255, 255), shorts = rgb(20, 70, 45), socks = rgb(46, 204, 113) },
	{ id = "NVL", name = "Northvale FC", short = "NVL", ovr = 60, stars = 2, open = true,
		shirt = rgb(59, 167, 255), trim = rgb(18, 24, 64), shorts = rgb(18, 24, 64), socks = rgb(59, 167, 255) },
	{ id = "NEW", name = "Newford FC", short = "NFC", ovr = 61, stars = 2.5, open = true,
		shirt = rgb(255, 191, 31), trim = rgb(43, 18, 80), shorts = rgb(43, 18, 80), socks = rgb(255, 191, 31) },
	{ id = "RMA", name = "Redmont Athletic", short = "RMA", ovr = 62, stars = 3, open = false, unlockOvr = 55,
		shirt = rgb(232, 58, 58), trim = rgb(255, 255, 255), shorts = rgb(255, 255, 255), socks = rgb(232, 58, 58) },
	{ id = "RIV", name = "Riverside Rovers", short = "RIV", ovr = 63, stars = 3.5, open = false, unlockOvr = 60,
		shirt = rgb(24, 198, 181), trim = rgb(14, 40, 48), shorts = rgb(14, 40, 48), socks = rgb(24, 198, 181) },
	{ id = "EBU", name = "Eastbridge United", short = "EBU", ovr = 64, stars = 4, open = false, unlockOvr = 65,
		shirt = rgb(255, 138, 31), trim = rgb(20, 14, 30), shorts = rgb(20, 14, 30), socks = rgb(255, 138, 31) },
	{ id = "WPC", name = "Westport City", short = "WPC", ovr = 65, stars = 4.5, open = false, unlockOvr = 70,
		shirt = rgb(123, 77, 255), trim = rgb(255, 191, 31), shorts = rgb(43, 18, 80), socks = rgb(123, 77, 255) },
	{ id = "SGF", name = "Southgate FC", short = "SGF", ovr = 66, stars = 5, open = false, unlockOvr = 75,
		shirt = rgb(26, 26, 36), trim = rgb(255, 191, 31), shorts = rgb(26, 26, 36), socks = rgb(255, 191, 31) },
}

CareerConfig.PlayerStartOvr = 40
CareerConfig.Position = "ST" -- the only position until positions matter (GDD: ST, LW/RW, CM/CAM)
CareerConfig.NumberMin = 1
CareerConfig.NumberMax = 99
CareerConfig.NameMinLength = 2
CareerConfig.NameMaxLength = 12
CareerConfig.QuickNumbers = { 7, 9, 10, 11, 17, 99 }

CareerConfig.DefaultSettings = {
	shake = true, -- camera shake on goals and hits
	effects = true, -- confetti and impact puffs
	aimLine = true, -- the dotted flight preview while charging a shot
}

function CareerConfig.club(id: any): Club?
	for _, club in CareerConfig.Clubs do
		if club.id == id then
			return club
		end
	end
	return nil
end

-- Shirt kit for FigureBuilder.
function CareerConfig.kit(club: Club)
	return {
		skin = rgb(214, 132, 82),
		shirt = club.shirt,
		shorts = club.shorts,
		socks = club.socks,
		boots = rgb(20, 14, 30),
		hair = rgb(52, 32, 26),
	}
end

local function isLetter(code: number): boolean
	return (code >= 65 and code <= 90) -- A-Z
		or (code >= 97 and code <= 122) -- a-z
		or (code >= 0x410 and code <= 0x44F) -- А-я
		or code == 0x401 or code == 0x451 -- Ёё
end

-- Checks a first or last name: letters (Latin or Cyrillic) with single inner hyphens or
-- apostrophes. Returns the trimmed name, or nil and a reason for the player.
function CareerConfig.validateName(value: any): (string?, string?)
	if type(value) ~= "string" then
		return nil, "Введи имя"
	end
	local name = string.match(value, "^%s*(.-)%s*$") or ""
	local ok, length = pcall(utf8.len, name)
	if not ok or not length then
		return nil, "Только буквы"
	end
	if length < CareerConfig.NameMinLength then
		return nil, string.format("Минимум %d буквы", CareerConfig.NameMinLength)
	end
	if length > CareerConfig.NameMaxLength then
		return nil, string.format("Максимум %d букв", CareerConfig.NameMaxLength)
	end
	local previous = nil
	for _, code in utf8.codes(name) do
		local joiner = code == 45 or code == 39 -- - '
		if not (isLetter(code) or joiner) then
			return nil, "Только буквы"
		end
		if joiner and (previous == nil or not isLetter(previous)) then
			return nil, "Только буквы"
		end
		previous = code
	end
	if previous and not isLetter(previous) then
		return nil, "Только буквы"
	end
	return name, nil
end

function CareerConfig.validateNumber(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return nil
	end
	if value < CareerConfig.NumberMin or value > CareerConfig.NumberMax then
		return nil
	end
	return value
end

-- Name printed on the back of the shirt: the last name in capitals.
function CareerConfig.shirtName(firstName: string?, lastName: string?): string
	local name = if lastName and lastName ~= "" then lastName else (firstName or "")
	local out = {}
	local ok = pcall(function()
		for _, code in utf8.codes(name) do
			if (code >= 97 and code <= 122) or (code >= 0x430 and code <= 0x44F) then
				code -= 32
			elseif code == 0x451 then
				code = 0x401
			end
			table.insert(out, utf8.char(code))
		end
	end)
	return if ok then table.concat(out) else string.upper(name)
end

return CareerConfig
