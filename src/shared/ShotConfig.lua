-- Tuning values for the Stage 1 shot, shared by the server (outcome) and the client (visuals)
-- so both sides agree on goal geometry and ball flight.
--
-- World layout (studs): the goal line is the plane Z = 0, the goal is centred on X = 0,
-- the ground is Y = 0, and the shooter stands at +Z shooting towards -Z.

local ShotConfig = {}

ShotConfig.Goal = {
	Width = 24, -- inside width, post to post
	Height = 8, -- inside height, ground to crossbar
	PostRadius = 0.35,
	NetDepth = 6,
	-- Fraction of the ball radius that must overlap the frame to count as POST;
	-- lighter touches deflect in (goal side) or out (wide side).
	FrameHitDepth = 0.5,
}

ShotConfig.Ball = {
	Radius = 1,
}

ShotConfig.ShotDistance = 36 -- goal line to ball spot

-- Lower than workspace.Gravity on purpose: weak shots get a visible loop, hard shots stay flat.
ShotConfig.Gravity = 60
ShotConfig.MinBallSpeed = 40 -- power 0
ShotConfig.MaxBallSpeed = 110 -- power 1

ShotConfig.Accuracy = {
	-- Standard deviation (studs) of the random offset from the aim point, by Shooting skill.
	ScatterAtZeroSkill = 2.6,
	ScatterAtMaxSkill = 0.5,
	MaxSigmas = 2.5, -- cap so a single shot is never wildly off
	-- Power above this threshold is less accurate and tends to rise over the bar.
	OverpowerFrom = 0.85,
	OverpowerScatter = 1.5,
	OverpowerLift = 2.5,
}

ShotConfig.Goalkeeper = {
	Enabled = true,
	Skill = 60, -- 0..100, opponent goalkeeper rating
	HomeX = 0,
	HomeY = 3.5, -- body centre
	HomeZ = 1.2, -- stands just in front of the line
	Reach = 3, -- distance the hands cover without moving
	ReactionTime = 0.22,
	ReactionJitter = 0.06, -- +/- random part of the reaction time
	DiveSpeedAtZeroSkill = 10,
	DiveSpeedAtMaxSkill = 26,
}

-- Placeholder until career data exists (GDD: new players start around OVR 40).
ShotConfig.DefaultShooting = 42

ShotConfig.Episode = {
	MinThinkTime = 0.3, -- seconds between episode start and an accepted input
	Timeout = 120, -- an unanswered episode expires after this
	MinRemoteInterval = 0.2, -- per-player rate limit for remote calls
	InputTolerance = 1e-3, -- float slack allowed on input ranges
}

ShotConfig.Input = {
	PowerCycleSeconds = 1.6, -- power meter goes 0 -> 1 -> 0 over this time while held
	ReadyDelay = 0.35, -- pause after a new episode before input is accepted
}

ShotConfig.Camera = {
	Position = Vector3.new(0, 4.5, ShotConfig.ShotDistance + 12),
	LookAt = Vector3.new(0, 3, 0),
	FieldOfView = 40,
}

return ShotConfig
