--!strict
--[[
	Config — every tunable number (GDD §9 + §8 Deadline overrides).
	require(ReplicatedStorage.Shared.Config).Round.MATCH_HARD_LIMIT etc.
	Never change values here for a local test without reverting (QA smoke S2).
]]

return table.freeze({
	Round = require(script.Round),
	Player = require(script.Player),
	Interaction = require(script.Interaction),
	Extraction = require(script.Extraction),
	Stages = require(script.Stages),
	Impact = require(script.Impact),
	Debug = require(script.Debug),
	Missions = require(script.Missions),
	Disasters = require(script.Disasters),
	Events = require(script.Events),
	Items = require(script.Items),
	Audio = require(script.Audio),
	LightingPresets = require(script.LightingPresets),
	Cosmetics = require(script.Cosmetics),
	Presentation = require(script.Presentation),
	Animation = require(script.Animation),
})
