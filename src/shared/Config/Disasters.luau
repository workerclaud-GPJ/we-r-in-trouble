--!strict
-- DisasterDefs (GDD §4.3.1 Earthquake + §8.6.1 Big Shake, Deadline overrides:
-- debris is visual only (propCollides = false) and fades after 3s).
-- Shake amplitudes per docs/assets/ArtAudio-deadline.md §3.6: 0.15 / 0.35 / 0.6 / Big Shake 1.0.
-- Prop names = ReplicatedStorage.Assets.Debris.<name>.
local Types = require(script.Parent.Parent.Types)
local Impact = require(script.Parent.Impact)

type C = Types.HazardComponent

local PROPS = { "Apple", "SoupCan", "Sponge" }
local DEBRIS_LIFETIME = 3

local function moveModifier(multiplier: number): C
	return { type = "MoveModifier", multiplier = multiplier }
end

local function shake(intensity: number): C
	return { type = "ScreenEffect", effect = "Shake", intensity = intensity }
end

local function nearPlayerImpact(rate: number, telegraph: number, damage: number): C
	return {
		type = "TelegraphedImpact",
		targeting = "NearPlayer",
		rate = rate,
		count = "HalfStanding", -- ceil(standing / 2)
		minDist = 3,
		maxDist = 10,
		telegraph = telegraph,
		radius = 5,
		damage = damage,
		lifetime = DEBRIS_LIFETIME,
		propCollides = false,
		propPool = PROPS,
	}
end

local function randomPointImpact(rate: number, telegraph: number): C
	return {
		type = "TelegraphedImpact",
		targeting = "RandomPoint",
		rate = rate,
		count = 1,
		telegraph = telegraph,
		radius = 5,
		damage = 0, -- visual only (debris all over the kitchen)
		lifetime = DEBRIS_LIFETIME,
		propCollides = false,
		propPool = PROPS,
	}
end

local function pulse(firstDelay: number, interval: number, duration: number, children: { C }): C
	return { type = "Pulse", firstDelay = firstDelay, interval = interval, duration = duration, children = children }
end

local ONCE = 999 -- interval meaning "fire once"

local DISASTERS: { [string]: Types.DisasterDef } = {
	Earthquake = {
		id = "Earthquake",
		displayName = "EARTHQUAKE!",
		warningText = "Watch for red circles. Things will fall!",
		propPool = PROPS,
		stages = {
			Warning = {
				pulse(0, ONCE, 3, { moveModifier(0.85), shake(0.15) }),
			},
			Active = {
				pulse(5, 20, 5, { moveModifier(0.7), shake(0.35), nearPlayerImpact(1.0, 1.5, 30) }),
			},
			Critical = {
				-- Big Shake (Rescue Moment): once, right when Critical starts
				pulse(0, ONCE, Impact.BIG_SHAKE_DURATION, {
					shake(1.0),
					nearPlayerImpact(0.4, 1.5, Impact.BIG_SHAKE_DAMAGE),
					randomPointImpact(0.15, 1.5),
				}),
				pulse(2, 12, 7, { moveModifier(0.6), shake(0.6), nearPlayerImpact(0.7, 1.2, 30) }),
			},
		},
	},
}

return table.freeze(DISASTERS)
