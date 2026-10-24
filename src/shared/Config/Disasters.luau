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

-- minDist/maxDist: landing offset from the target's feet (radius 5 -> a player who
-- stands still is hit by ~(5-1.5)/(8-1.5) = 54% of the impacts aimed at them).
local function nearPlayerImpact(rate: number, telegraph: number, damage: number, minDist: number?, maxDist: number?): C
	return {
		type = "TelegraphedImpact",
		targeting = "NearPlayer",
		rate = rate,
		count = "HalfStanding", -- ceil(standing / 2)
		minDist = minDist or 3,
		maxDist = maxDist or 10,
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
local FOREVER = 1e6 -- pulse duration that outlives the stage (stage end cleans it up)

-- Continuous component(s) that start `firstDelay` s into the stage and run until it ends.
local function stream(firstDelay: number, children: { C }): C
	return pulse(firstDelay, ONCE, FOREVER, children)
end

--[[ Impact tuning (playtest 24 Oct: standing still in Active = ~1 hit / 30 s, too rare).
	count = HalfStanding -> each wave targets ceil(n/2) random standing players, so per player
	one aimed impact every ~2 * rate seconds with 2 or 4 players (solo Studio: every `rate` s).
	  Active   : steady stream, rate 3.5 s  -> ~1 impact near each player / 7 s,   telegraph 1.5 s
	  Critical : steady stream, rate 1.75 s -> ~1 impact near each player / 3.5 s, telegraph 1.2 s
	             (starts after the Big Shake; Big Shake itself unchanged: 0.4 s / 0.15 s, 4 s)
	  Distance 1.5-8 studs (was 3-10), radius 5, damage 30 -> a still player takes a hit
	  ~every 13 s in Active, ~every 6.5 s in Critical. Pulses keep the periodic shake + slow.
	Previous: Active impacts only inside a 5 s pulse every 20 s (rate 1.0, 3-10 studs);
	Critical 7 s pulse every 12 s (rate 0.7).
]]
local ACTIVE_RATE, ACTIVE_TELEGRAPH = 3.5, 1.5
local CRITICAL_RATE, CRITICAL_TELEGRAPH = 1.75, 1.2
local NEAR_MIN, NEAR_MAX = 1.5, 8
local IMPACT_DAMAGE = 30

--[[ Flood (GDD §4.3.2, Deadline cut per Lead 24 Oct: Level 0 = kitchen floor Y 0, counter +45 dry).
	A washing-machine hose bursts. RisingVolume steps (studs above Level 0, linear rise):
	  Warning  : trickle -> 0.3 (puddle, no effect)
	  Active   : +5 s -> 3 over 30 s (wading = Slowed x0.6), +100 s (2:25) -> 8 over 30 s
	             (hamster ~5.5 tall: head under ~2:45, after a typical team finishes the floor step)
	  Critical : -> 20 over 90 s + ceiling drips (NearPlayer, no prop) every 3 s. Never reaches +45.
	Breath 100: 10 s of air underwater, refills in 2.5 s, then 10 dmg/s (-> Downed via damage()).
]]
local FLOOD_MAX_LEVEL = 20

local function rise(steps: { Types.VolumeStep }): C
	return { type = "RisingVolume", steps = steps }
end

local function drips(rate: number, telegraph: number, damage: number): C
	return {
		type = "TelegraphedImpact",
		targeting = "NearPlayer",
		rate = rate,
		count = "HalfStanding",
		minDist = 0,
		maxDist = 6,
		telegraph = telegraph,
		radius = 4,
		damage = damage,
		lifetime = 1,
		propCollides = false,
		propPool = {}, -- ring only (water drop)
	}
end

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
				pulse(5, 20, 5, { moveModifier(0.7), shake(0.35) }),
				stream(3, { nearPlayerImpact(ACTIVE_RATE, ACTIVE_TELEGRAPH, IMPACT_DAMAGE, NEAR_MIN, NEAR_MAX) }),
			},
			Critical = {
				-- Big Shake (Rescue Moment): once, right when Critical starts
				pulse(0, ONCE, Impact.BIG_SHAKE_DURATION, {
					shake(1.0),
					nearPlayerImpact(0.4, 1.5, Impact.BIG_SHAKE_DAMAGE),
					randomPointImpact(0.15, 1.5),
				}),
				pulse(Impact.BIG_SHAKE_DURATION + 2, 12, 7, { moveModifier(0.6), shake(0.6) }),
				stream(Impact.BIG_SHAKE_DURATION, {
					nearPlayerImpact(CRITICAL_RATE, CRITICAL_TELEGRAPH, IMPACT_DAMAGE, NEAR_MIN, NEAR_MAX),
				}),
			},
		},
	},
	Flood = {
		id = "Flood",
		displayName = "FLOOD!",
		warningText = "The hose burst! Get up high before the water covers your head!",
		stages = {
			Warning = { rise({ { delay = 0, level = 0.3, riseTime = 10 } }) },
			Active = {
				rise({
					{ delay = 5, level = 3, riseTime = 30 },
					{ delay = 100, level = 8, riseTime = 30 },
				}),
			},
			Critical = {
				rise({ { delay = 0, level = FLOOD_MAX_LEVEL, riseTime = 90 } }),
				stream(4, { drips(3, 1.5, 20) }),
			},
		},
		volume = {
			maxLevel = FLOOD_MAX_LEVEL,
			tick = 0.25,
			wadeDepth = 1.5,
			wadeSpeedMult = 0.6,
			headHeight = 5.5,
			breathMax = 100,
			breathDrain = 10,
			breathRefill = 40,
			drownDamage = 10,
			drownInterval = 1,
			spawnSafeDepth = 1.5,
			enableFlag = "Flooding", -- counter PlayerSpawns (tools/AddFloodMarkup.luau) use EnabledBy = Flooding
			color = Color3.fromRGB(80, 150, 230),
			transparency = 0.45,
			underwaterTint = Color3.fromRGB(140, 190, 255),
			underwaterBlur = 6,
		},
	},
}

return table.freeze(DISASTERS)
