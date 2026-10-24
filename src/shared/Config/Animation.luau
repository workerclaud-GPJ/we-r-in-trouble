--!strict
--[[
	Procedural animation tunables (Client.Controllers.ProceduralAnimController).
	No uploaded animation assets: poses are layered onto the rig joints in code on every
	client, driven by replicated attributes (Stunned / DashAt on the Player, AnimState +
	AnimStandCF on the character). Angles in degrees.

	HOLD_ANIMS maps an objective's `holdAnim` (Config.Missions) to a pose id. A holdAnim
	with no pose here (e.g. "ShoutRadio") is simply ignored until a pose is added.
	Objectives with a holdAnim use TOGGLE holds (press once = start, again = stop).
]]

return table.freeze({
	BLEND_IN = 12, -- weight per second toward 1 (pose active)
	BLEND_OUT = 8, -- weight per second toward 0
	MAX_DISTANCE = 250, -- studs from the camera: farther characters are not posed (perf)

	HOLD_ANIMS = table.freeze({
		RunInWheel = "RunInWheel",
	}) :: { [string]: string },
	STOP_TEXT = "Stop", -- local prompt ActionText while you run a toggle hold
	EXIT_GRACE = 0.5, -- s after starting before move/jump input stops a toggle hold

	-- Dizzy (stunned): head/torso circle, loose flailing arms, stagger
	DIZZY_SPEED = 5, -- rad/s of the wobble circle
	DIZZY_TORSO = 9,
	DIZZY_HEAD = 18,
	DIZZY_ARM_OUT = 50,
	DIZZY_ARM_FLAIL = 25,

	-- Dash: lean forward, arms swept back, legs stretched
	DASH_LEAN = 28,
	DASH_ARMS_BACK = 70,
	DASH_STRIDE = 40,
	DASH_TRAIL_COLOR = Color3.fromRGB(255, 240, 200),

	-- RunInWheel: fast run cycle
	RUN_CYCLE_HZ = 2.6, -- strides per second (one left + one right)
	RUN_HIP_SWING = 55,
	RUN_KNEE_BEND = 70,
	RUN_ARM_SWING = 55,
	RUN_ELBOW_BEND = 70,
	RUN_LEAN = 14,
	RUN_BOB = 0.18, -- studs
	RUN_ROOT_DROP = 0.2, -- studs the body sits lower while running (feet on the rungs)

	-- Wheel visual spin (client): any Model with attribute SpinFor = <ObjectiveId> spins
	-- around its pivot RightVector while runners are in it.
	SPIN_ATTR = "SpinFor",
	SPIN_PER_RUNNER = 4.5, -- rad/s per active runner
	SPIN_ACCEL = 3, -- how fast the spin speed eases (1/s)
	SPIN_RUNNER_RADIUS = 12, -- runner stand point within this many studs of the wheel pivot
})
