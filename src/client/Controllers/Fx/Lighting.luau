--!strict
--[[
	Lighting — tweens Lighting + Atmosphere/ColorCorrection/Bloom between Config.LightingPresets
	(docs/assets/ArtAudio-deadline.md §4.2): 2 s between presets, 1 s into Critical.
	ClockTime is set instantly (tweening 17.6 → 0 would spin through daytime).
	Warning = Calm with TintColor → (255,225,190) in 0.5 s.
]]

local LightingService = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Presets = Config.LightingPresets

local WARNING_TINT = Color3.fromRGB(255, 225, 190)

local Lighting = {}

local current: string? = nil
local tweens: { Tween } = {}

local function ensure<T>(className: string): T
	local existing = LightingService:FindFirstChildOfClass(className :: any)
	if existing then
		return (existing :: any) :: T
	end
	local inst = Instance.new(className :: any)
	inst.Parent = LightingService
	return (inst :: any) :: T
end

local function tween(inst: Instance, time: number, props: { [string]: any })
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	table.insert(tweens, t)
	t:Play()
end

function Lighting.apply(name: string, instant: boolean?)
	if current == name then
		return
	end
	local preset = Presets[name]
	if not preset then
		return
	end
	current = name
	for _, t in tweens do
		t:Cancel()
	end
	table.clear(tweens)
	local time = if instant then 0 elseif name == "Critical" then 1 else 2

	LightingService.ClockTime = preset.ClockTime
	tween(LightingService, time, {
		Brightness = preset.Brightness,
		Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient,
		ColorShift_Top = preset.ColorShift_Top,
		ColorShift_Bottom = preset.ColorShift_Bottom,
		EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
		ExposureCompensation = preset.ExposureCompensation,
	})
	local atmo = ensure("Atmosphere") :: Atmosphere
	tween(atmo, time, {
		Density = preset.Atmosphere.Density,
		Offset = preset.Atmosphere.Offset,
		Color = preset.Atmosphere.Color,
		Decay = preset.Atmosphere.Decay,
		Glare = preset.Atmosphere.Glare,
		Haze = preset.Atmosphere.Haze,
	})
	local cc = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	tween(cc, time, {
		Brightness = preset.ColorCorrection.Brightness,
		Contrast = preset.ColorCorrection.Contrast,
		Saturation = preset.ColorCorrection.Saturation,
		TintColor = if name == "Warning" then WARNING_TINT else preset.ColorCorrection.TintColor,
	})
	local bloom = ensure("BloomEffect") :: BloomEffect
	tween(bloom, time, {
		Intensity = preset.Bloom.Intensity,
		Size = preset.Bloom.Size,
		Threshold = preset.Bloom.Threshold,
	})
end

function Lighting.current(): string?
	return current
end

return Lighting
