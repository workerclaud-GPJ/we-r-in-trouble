--!strict
-- Lighting presets (docs/assets/ArtAudio-deadline.md §4.2). Client tweens between them (Fx/Lighting.luau);
-- tools/BuildProps.luau applies Calm once in Studio. ClockTime is set instantly (never tweened).
export type Preset = {
	ClockTime: number, Brightness: number, Ambient: Color3, OutdoorAmbient: Color3,
	ColorShift_Top: Color3, ColorShift_Bottom: Color3, EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number, ExposureCompensation: number,
	Atmosphere: { Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number },
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: Color3 },
	Bloom: { Intensity: number, Size: number, Threshold: number },
}
local rgb = Color3.fromRGB
local Presets: { [string]: Preset } = {
	Lobby = {
		ClockTime = 17.6, Brightness = 2, Ambient = rgb(150, 135, 150), OutdoorAmbient = rgb(160, 145, 160),
		ColorShift_Top = rgb(255, 214, 170), ColorShift_Bottom = rgb(60, 40, 60),
		EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.2,
		Atmosphere = { Density = 0.25, Offset = 0.1, Color = rgb(255, 214, 170), Decay = rgb(180, 120, 140), Glare = 0.2, Haze = 1 },
		ColorCorrection = { Brightness = 0.03, Contrast = 0.08, Saturation = 0.15, TintColor = rgb(255, 248, 236) },
		Bloom = { Intensity = 0.6, Size = 24, Threshold = 1.8 },
	},
	Calm = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(82, 90, 128), OutdoorAmbient = rgb(95, 105, 145),
		ColorShift_Top = rgb(170, 190, 255), ColorShift_Bottom = rgb(40, 40, 70),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.35,
		Atmosphere = { Density = 0.25, Offset = 0.15, Color = rgb(120, 135, 190), Decay = rgb(60, 60, 110), Glare = 0, Haze = 0.8 },
		ColorCorrection = { Brightness = 0.04, Contrast = 0.12, Saturation = -0.05, TintColor = rgb(225, 232, 255) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 },
	},
	Active = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(96, 84, 104), OutdoorAmbient = rgb(112, 92, 104),
		ColorShift_Top = rgb(255, 190, 140), ColorShift_Bottom = rgb(60, 40, 40),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.3, ExposureCompensation = 0.3,
		Atmosphere = { Density = 0.35, Offset = 0.2, Color = rgb(170, 140, 140), Decay = rgb(90, 60, 70), Glare = 0, Haze = 1.2 },
		ColorCorrection = { Brightness = 0.03, Contrast = 0.18, Saturation = 0, TintColor = rgb(255, 236, 220) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 },
	},
	Critical = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(104, 76, 92), OutdoorAmbient = rgb(124, 84, 104),
		ColorShift_Top = rgb(255, 150, 150), ColorShift_Bottom = rgb(70, 30, 50),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.3,
		Atmosphere = { Density = 0.4, Offset = 0.2, Color = rgb(180, 120, 130), Decay = rgb(110, 50, 70), Glare = 0, Haze = 1.5 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.22, Saturation = 0.1, TintColor = rgb(255, 225, 230) },
		Bloom = { Intensity = 0.8, Size = 28, Threshold = 1.4 },
	},
}
Presets.Warning = Presets.Calm -- + TintColor tween to (255,225,190), see §4.2
return table.freeze(Presets)
