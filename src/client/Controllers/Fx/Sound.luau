--!strict
--[[
	Sound — builds SoundService.Audio.<Name> from Config.Audio (one Sound per entry) and plays them.
	Sounds whose SoundId is empty (Config id = 0 and nothing placed by hand) are skipped silently.
	2D: played directly. 3D (`spatial`): cloned onto an invisible anchored part at the position.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local A = Config.Audio

local Sound = {}

local audioFolder: Instance? = nil
local recent: { [string]: { number } } = {}
local rng = Random.new()

local function ensureGroup(name: string, volume: number): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = name
	g.Volume = volume
	g.Parent = SoundService
	return g
end

function Sound.init()
	if audioFolder then
		return
	end
	local f = SoundService:FindFirstChild("Audio")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "Audio"
		nf.Parent = SoundService
		f = nf
	end
	audioFolder = f
	local groups: { [string]: SoundGroup } = {}
	for name, vol in A.GROUP_VOLUME do
		groups[name] = ensureGroup(name, vol)
	end
	for name, def in A.SOUNDS do
		local s = f:FindFirstChild(name)
		if not (s and s:IsA("Sound")) then
			local ns = Instance.new("Sound")
			ns.Name = name
			ns.Parent = f
			s = ns
		end
		local snd = s :: Sound
		if def.id ~= 0 then
			snd.SoundId = `rbxassetid://{def.id}`
		end
		snd.Volume = def.volume
		snd.Looped = def.looped == true
		snd.SoundGroup = groups[def.group]
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = A.ROLLOFF_MIN
		snd.RollOffMaxDistance = A.ROLLOFF_MAX
	end
end

-- The configured Sound, or nil when it has no SoundId (id 0) — callers must accept nil.
function Sound.get(name: string): Sound?
	local f = audioFolder
	local s = f and f:FindFirstChild(name)
	if s and s:IsA("Sound") and s.SoundId ~= "" then
		return s
	end
	return nil
end

local function allowJitter(name: string): boolean
	local now = os.clock()
	local list: { number } = recent[name] or {}
	local kept: { number } = {}
	for _, t in list do
		if now - t < A.JITTER_WINDOW then
			table.insert(kept, t)
		end
	end
	if #kept >= A.JITTER_MAX_PLAYS then
		recent[name] = kept
		return false
	end
	table.insert(kept, now)
	recent[name] = kept
	return true
end

-- Plays a one-shot 2D sound (or at `position` when the def is spatial). Returns the playing Sound.
function Sound.play(name: string, position: Vector3?, volumeScale: number?): Sound?
	local src = Sound.get(name)
	local def = A.SOUNDS[name]
	if not src or not def then
		return nil
	end
	local speed = 1
	if def.jitter then
		if not allowJitter(name) then
			return nil
		end
		speed = rng:NextNumber(A.JITTER_MIN, A.JITTER_MAX)
	end
	local s = src:Clone()
	s.Looped = false
	s.PlaybackSpeed = speed
	s.Volume = def.volume * (volumeScale or 1)
	if def.spatial and position then
		local holder = Instance.new("Part")
		holder.Name = "SfxAt_" .. name
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
		holder.Position = position
		holder.Parent = Workspace
		s.Parent = holder
		s:Play()
		Debris:AddItem(holder, math.max(1, s.TimeLength / speed) + 1)
	else
		s.Parent = audioFolder
		s:Play()
		Debris:AddItem(s, math.max(1, s.TimeLength / speed) + 1)
	end
	return s
end

-- Looping sound attached to `parent` (3D) or 2D when parent is nil. Returns nil when unconfigured.
function Sound.loop(name: string, parent: Instance?): Sound?
	local src = Sound.get(name)
	if not src then
		return nil
	end
	local s = src:Clone()
	s.Looped = true
	s.Parent = parent or audioFolder
	s:Play()
	return s
end

-- The shared 2D instance (music/ambience loops that only ever play once at a time).
function Sound.setPlaying(name: string, on: boolean, volume: number?)
	local s = Sound.get(name)
	if not s then
		return
	end
	if volume then
		s.Volume = volume
	end
	if on and not s.IsPlaying then
		s:Play()
	elseif not on and s.IsPlaying then
		s:Stop()
	end
end

return Sound
