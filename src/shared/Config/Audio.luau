--!strict
--[[
	Audio — the ONE table of sound asset IDs (docs/assets/ArtAudio-deadline.md §5.2).
	Client `Controllers/Fx/Sound.luau` creates `SoundService.Audio.<Name>` from this table.

	id = 0  → not confirmed yet: the Sound is created with no SoundId and every play call skips it.
	To fill an ID: Toolbox → Creator Store → Audio → search the keywords in the comment, prefer
	sounds made by "Roblox", press Play IN A PLAYTEST (unpermitted audio is silent), then paste
	the number here. A Sound already placed by hand in SoundService.Audio with a SoundId wins over id 0.
	spatial = true → played at a world position (3D, RollOff 10..120); otherwise 2D.
	jitter  = true → random PlaybackSpeed 0.9–1.15 and max 4 plays per 0.25 s (§5.1).
]]

export type Group = "Music" | "SFX" | "Ambience" | "UI"

export type SoundDef = {
	id: number,
	volume: number,
	group: Group,
	looped: boolean?,
	spatial: boolean?,
	jitter: boolean?,
}

local GROUP_VOLUME: { [Group]: number } = { Music = 0.5, SFX = 0.8, Ambience = 0.6, UI = 0.7 }

local SOUNDS: { [string]: SoundDef } = {
	-- P0 ------------------------------------------------------------------------------------
	QuakeRumble = { id = 0, volume = 0.6, group = "Ambience", looped = true }, -- "earthquake rumble", "low rumble"; volume follows shake 0.3/0.6/0.8/1.0
	DishRattle = { id = 0, volume = 0.5, group = "SFX", looped = true }, -- "dishes rattling", "plates clatter"
	FallWhistle = { id = 0, volume = 0.4, group = "SFX", spatial = true }, -- "falling whistle", "cartoon fall" (~1.2–1.5 s)
	Bonk = { id = 0, volume = 0.7, group = "SFX", spatial = true, jitter = true }, -- "cartoon bonk", "boing hit"
	ImpactThud = { id = 0, volume = 0.5, group = "SFX", spatial = true, jitter = true }, -- "thud", "metal can drop", "squish"
	SqueakHurt = { id = 0, volume = 0.6, group = "SFX", spatial = true, jitter = true }, -- "squeak", "toy squeak"
	DizzyLoop = { id = 0, volume = 0.4, group = "SFX", looped = true, spatial = true }, -- "cartoon dizzy", "birds tweeting dizzy"
	Revive = { id = 0, volume = 0.6, group = "SFX", spatial = true }, -- "sparkle pop", "magic chime"
	Poof = { id = 0, volume = 0.7, group = "SFX", spatial = true }, -- "poof", "smoke puff"
	SirenFar = { id = 0, volume = 0.35, group = "Ambience" }, -- "siren distant"
	SirenNear = { id = 0, volume = 0.3, group = "Ambience", looped = true }, -- "fire truck siren", "siren loop"; ramps 0.3 → 0.8 over the ETA
	RadioStatic = { id = 0, volume = 0.35, group = "SFX", looped = true, spatial = true }, -- "radio static", "walkie talkie static"
	BatteryInsert = { id = 0, volume = 0.7, group = "SFX", spatial = true }, -- "click snap", "plug in"
	StepComplete = { id = 0, volume = 0.7, group = "UI" }, -- "success chime", "achievement"
	HeroArrive = { id = 0, volume = 0.7, group = "Music" }, -- "heroic fanfare short", "brass fanfare"
	WinStinger = { id = 0, volume = 0.7, group = "Music" }, -- "victory fanfare", "cartoon win"
	LoseStinger = { id = 0, volume = 0.6, group = "Music" }, -- "sad trombone", "cartoon fail"
	-- P1 ------------------------------------------------------------------------------------
	MusicLobby = { id = 0, volume = 0.4, group = "Music", looped = true }, -- "playful ukulele" (filter Music)
	MusicMatch = { id = 0, volume = 0.35, group = "Music", looped = true }, -- "sneaky cartoon", "mischief"
	MusicCritical = { id = 0, volume = 0.4, group = "Music", looped = true }, -- "cartoon chase", "hurry up"
	AlarmLoop = { id = 0, volume = 0.2, group = "Ambience", looped = true }, -- "alarm beep loop"
	KitchenNight = { id = 0, volume = 0.3, group = "Ambience", looped = true }, -- "fridge hum", "clock ticking"
	BigShakeBoom = { id = 0, volume = 0.9, group = "SFX" }, -- "explosion rumble", "earthquake hit"
	CarrierLand = { id = 0, volume = 0.6, group = "SFX", spatial = true }, -- "plastic thud", "box drop"
	RopeCreak = { id = 0, volume = 0.5, group = "SFX", spatial = true }, -- "rope creak", "winch"
	RespawnPop = { id = 0, volume = 0.6, group = "SFX", spatial = true }, -- "pop out"
}

return table.freeze({
	GROUP_VOLUME = table.freeze(GROUP_VOLUME),
	SOUNDS = table.freeze(SOUNDS),
	ROLLOFF_MIN = 10,
	ROLLOFF_MAX = 120,
	JITTER_MIN = 0.9,
	JITTER_MAX = 1.15,
	JITTER_MAX_PLAYS = 4, -- per JITTER_WINDOW
	JITTER_WINDOW = 0.25,
	FALL_WHISTLE_RADIUS = 20, -- only for impacts this close to the local player
})
