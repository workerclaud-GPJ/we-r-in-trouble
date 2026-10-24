# ARCHITECTURE — Deadline contract (We R in Trouble)

> สัญญากลางของทีมสำหรับ Deadline build (GDD v0.5 §8) — UI, Level, Art, QA ใช้ชื่อในเอกสารนี้เท่านั้น
> ชื่อทุกตัวมีอยู่ในโค้ดที่ `src/shared/Contract.luau` (ให้ require แทนการพิมพ์ string เอง)
> ค่าตัวเลขทั้งหมดอยู่ใน `src/shared/Config/` (ห้าม hard-code) · เวลาทุกค่าที่ลงท้าย `At` = `workspace:GetServerTimeNow()`
> ผู้เขียน: Gameplay Scripter · สถานะ: v1 (24 ต.ค.) — ถ้าจะเปลี่ยนชื่อใดๆ แจ้ง Lead ก่อน

Names below follow what the UI agent already assumed in `src/client/UI/StateAdapter.luau`, so the HUD works without renames (differences are listed in §9).

---

## 1. DataModel layout

| Where | What | Owner |
|---|---|---|
| `ReplicatedStorage.Shared` | Rojo `src/shared` (Contract, Types, Remotes, Config, Util) | Scripter/Systems |
| `ReplicatedStorage.Remotes` | Folder of RemoteEvents, **created by the server** at boot (`Remotes.luau`) | Scripter |
| `ReplicatedStorage.RoundState` | Folder; round/match state as **attributes** (§3). Child `Objectives` folder (§4) during a match | Scripter (server writes) |
| `ReplicatedStorage.Assets` | Optional art (confirmed with Art, ArtAudio-deadline.md): `Assets.RescueCarrier` (Model, PrimaryPart **`Base`** pivoted onto `ExitVehicleSpot`, has `RopeAttachment`; all parts non-colliding), `Assets.Items.Battery`, `Assets.Debris.{Apple, SoupCan, Sponge}` (names = DisasterDef `propPool`). Missing assets → simple Part placeholders | Art |
| `SoundService.Audio` | `Sound` instances by name (`QuakeRumble`, `Bonk`, …) — played by client controllers only | Art/UI |
| Character attachments | `Head.StatusFxAttachment` (stars/BONK), `UpperTorso.PoofAttachment` (Poof), `UpperTorso.CarryAttachment` (server welds held items here; fallback `RightHand`) | Art (hamster) |
| `ServerScriptService.Server` | Rojo `src/server` (`Main.server.luau` + `Services/*`) | Scripter |
| `StarterPlayer.StarterPlayerScripts.Client` | Rojo `src/client` (`Main.client.luau`, `Controllers/*`, `UI/*`) | UI + Scripter |
| `ServerStorage.Maps.MidnightKitchen` | The map **Model** (built in Studio by Level/Boss, not in Rojo). Attribute `KillY` (−30) on the root | Level |
| `ServerStorage.DebugInvoke` | BindableFunction created by server for Command-Bar debug (§8) | Scripter |
| `Workspace.Map` | Folder created per match: `Workspace.Map.<MapId>` (clone) + `Workspace.Map.Runtime` (items, carrier). **Destroyed** after Result | Scripter |
| `Workspace.Lobby` | Lobby platform. If it does not exist the server **builds one** (60×60 platform + invisible walls/ceiling with `CanQuery=false`) at `X = LOBBY_OFFSET_X` | Scripter (Level may replace it; keep ≥1 Part tagged `LobbySpawn`) |
| `Players.CharacterAutoLoads` | `false` (set in `default.project.json` and again by server) | Scripter |
| `Workspace.StreamingEnabled` | `false` (set in `default.project.json`; the map is small). Server also calls `RequestStreamAroundAsync` before every character load as a safety net | Scripter |

Collision group `Players` (does not collide with itself) is registered by the server and applied to every character part.

### 1.1 Studio-only dev switches (attributes on `ServerStorage`, ignored on live)

| Attribute | Type | Effect |
|---|---|---|
| `DevMinPlayers` | number | overrides `MIN_PLAYERS_TO_START` (e.g. `1` for solo automation). **Not set = Studio waits for 2 like live** (QA CP0-5/6, S3, E7) |
| `DevNoHazards` | bool | stages still tick (HUD, banner, Critical on exit unlock) but no hazard component runs: no impacts, shake, slow or damage (QA CP1) |

### 1.2 Placement rules (server)

- `RescueCarrier`: bottom of `Base` (PrimaryPart) on the bottom face of `ExitVehicleSpot` (= ground +61).
- Items: resting on the floor at the `ItemSpawn` marker's bottom face (marker sits on the floor).
- `RandomPoint` impacts: x,z inside a Part named `DropArea` if the map has one (its bottom = floor), else inside the map `PrimaryPart` (`Structure.Floor`, top = floor); ray starts at floor + `RANDOM_POINT_RAY_TOP` (120) so counters and the sill are hit.
- Map lights (client, `EffectsController`): `Map.<MapId>.Lights.RescueLight_Red/Blue` (Part + SpotLight, off by default) switch on while `ExitOpen` and sweep/flash; `Lights.Moonlight` is off during `Critical`. The carrier (tag `ExitVehicle`) is lowered locally from `+DescendHeight` over `DescendStartedAt..DescendEndsAt` with a visible rope to its `RopeAttachment`.

---

## 2. Remotes (`src/shared/Remotes.luau`)

All are **RemoteEvent**. No RemoteFunctions. Server never trusts payloads.

| Name | Direction | Payload | Server validation |
|---|---|---|---|
| `ActivityPing` | C→S | *(none)* | accepted at most once per `ACTIVITY_PING_SERVER_MIN_INTERVAL` (5s) per player; only refreshes Lobby AFK timer |
| `DebugCommand` | C→S | `text: string` (e.g. `"setHP 0"`) | type + length ≤ 64, ≤ 5 per second, **`RunService:IsStudio()` or UserId in `Config.Debug.DEV_USER_IDS`** checked every call; otherwise silently ignored |
| `HudBanner` | S→C | `{ key: string, text: string, sub: string?, color: string?, duration: number? }` | — `key` = `Strings.Text` key (`BannerStepComplete`, `BannerWindowOpen`, `BannerCarrier`, `BannerCritical`, `BannerLastCall`, `BannerLastChance`, `Briefing`, `Disaster`); `text`/`sub` = English fallback (for `Disaster`/`Briefing` the text is the def's display text); `color` = `Style.Color` key (`Good`/`Warn`/`Hot`/`Bad`) |
| `Impact` | S→C | `{ position: Vector3, radius: number, telegraph: number, damage: number, prop: string?, dropHeight: number, lifetime: number }` | — client draws the red warning ring at `position` for `telegraph` s and drops `prop` (visual only, non-colliding, fades after `lifetime`). `prop = nil` → ring only |
| `ScreenEffect` | S→C | `{ effect: "Shake", intensity: number (0..1), duration: number }` | — sent to match participants only. Intensity per stage: Warning 0.15 / Active 0.35 / Critical 0.6 / Big Shake 1.0 |
| `PlayerHit` | S→C (all) | `{ userId: number, amount: number, position: Vector3 }` | — "Bonk!" + stars at `position` |

Prompts are **ProximityPrompts** created/configured by the server (not remotes) — see §6.

---

## 3. `ReplicatedStorage.RoundState` attributes (server writes, clients read)

| Attribute | Type | Meaning |
|---|---|---|
| `Phase` | string | `Lobby` (waiting, not enough players) · `Intermission` (counting) · `Match` · `Ending` (win cinematic `WIN_CINEMATIC_TIME` s, win only) · `Result` |
| `PhaseEndsAt` | number? | end of `Intermission` / `Ending` / `Result`; nil otherwise |
| `PlayersReady` | number | non-AFK players in Lobby |
| `PlayersNeeded` | number | `MIN_PLAYERS_TO_START` (2). Studio behaves like live unless `ServerStorage` has attribute `DevMinPlayers` (§1.1) |
| `MaxPlayers` | number | `MAX_PLAYERS` (4) |
| `MatchId` | number | increments per match |
| `MatchStartedAt` / `MatchEndsAt` | number? | match start / Collapse moment (`start + MATCH_HARD_LIMIT`) |
| `Stage` | string | `Calm` / `Warning` / `Active` / `Critical` (`Calm` outside a match) |
| `StageStartedAt` | number? | when the current stage began |
| `DisasterId` / `DisasterName` / `DisasterHint` | string? | set when the **Warning** stage is entered (GDD §12-3: hidden during Calm). Name = `DisasterDef.displayName`, Hint = `warningText` |
| `MissionName` | string? | `MissionDef.displayName` |
| `StepIndex` / `StepCount` | number | current step (1-based); `StepIndex = StepCount + 1` after the last step is done |
| `StepName` | string? | current step displayName |
| `StepOpenedAt` | number? | when the current step opened (override timer base) |
| `LastChance` | bool | true from `LAST_CHANCE_WARNING_AT` (5:20) while the last step is not done |
| `ExitOpen` | bool | exit flag set (window unlocked) |
| `CarrierArrivesAt` | number? | ETA end (carrier starts descending) |
| `CarrierArrived` | bool | carrier descended, Exit Zone `Open = true` |
| `CarrierArrivedAt` | number? | when Exit Zone opened (Last call base) |
| `DepartureRunning` | bool | departure countdown is running |
| `DepartureEndsAt` | number? | valid while running |
| `DepartureRemaining` | number? | seconds left, always rounded up (ceil): nil until the countdown first starts; updated each tick while running; **paused = `CarrierArrived` and not `DepartureRunning` and `DepartureRemaining > 0`** (never resets) |
| `ZoneCount` / `ZoneNeeded` | number | team members in Exit Zone / needed (activeCount, or Last-call quorum) |
| `LastCall` | bool | Last call active |
| `ResultWin` | bool? | set at match end |
| `ResultReason` | string? | `Escaped` / `Collapse` / `Wipe` / `Abandoned` |
| `ResultTime` | number? | match duration (s) |
| `ResultDisaster` | string? | disaster displayName |
| `ResultEscaped` | string? | comma-separated DisplayNames |

---

## 4. Objectives (`RoundState.Objectives.<ObjectiveId>` Configuration + anchor attributes)

One `Configuration` per objective, created at match start, destroyed at cleanup. The same live values are mirrored on every **ObjectiveAnchor** model of that objective (GDD §3.3).

| Attribute | Type | On | Meaning |
|---|---|---|---|
| `DisplayName` | string | cfg + anchor | string key, e.g. `obj.run_wheel` (UI maps via `Strings.objective`) |
| `Kind` | string | cfg + anchor | `Repair` / `Deliver` / `MultiHold` |
| `Step` / `Order` | number | cfg + anchor | step index / order inside step |
| `Optional` | bool | cfg | always false in Deadline build |
| `Active` | bool | cfg + anchor | step open and not done (prompts enabled) |
| `Done` | bool | cfg + anchor | completed (never reverts) |
| `Progress` | number 0–1 | cfg + anchor | Repair / MultiHold progress; Deliver = Delivered/Count |
| `Held` | number | cfg + anchor | MultiHold: anchors with ≥1 holder (incl. debug dummy) |
| `Required` | number | cfg + anchor | MultiHold: needed now (≥1) |
| `BaseRequired` | number | cfg + anchor | MultiHold: `min(anchorCount, activeCount)` before override |
| `Override` | bool | cfg + anchor | MultiHold: Emergency override engaged |
| `Occupied` | bool | anchor | MultiHold: this anchor is held |
| `Delivered` / `Count` | number | cfg + socket anchor | Deliver: delivered / needed |

---

## 5. Player attributes (server writes on `Player`)

| Attribute | Type | Values / meaning |
|---|---|---|
| `State` | string | `Lobby` / `Standing` / `Downed` / `Eliminated` / `Escaped` |
| `HP` / `MaxHP` | number | 0–100 / 100 (`Humanoid.Health` is never used) |
| `SpeedMult` | number | product of active modifiers (Pulse `MoveModifier`, carrying ×0.9) |
| `MoveMode` | string | `Normal` / `Downed` / `Pinned` (being revived) |
| `Inactive` | bool | Lobby AFK only (no in-match AFK system in Deadline build) |
| `Holding` | string | item type held (`"Battery"`) or `""` |
| `ProtectedUntil` | number? | spawn / revive protection end |
| `BleedOutEndsAt` | number? | while Downed; **paused while `MoveMode = Pinned`** (re-published when the revive stops) |
| `ReviveProgress` | number 0–1 | revive progress on the downed player |
| `RespawnAt` | number? | while Eliminated. The character is removed `POOF_DELAY` (0.4) s after `State` becomes `Eliminated` so clients can play the Poof |
| `ReviveCount` / `DownedCount` / `Credits` | number | per-match stats (revives done / times downed / objectives credited) |

**Client is the only writer of `Humanoid.WalkSpeed`/`JumpHeight`** (`Controllers/MovementController.luau`): `Normal` → `max(MIN_MOVE_SPEED, WALK_SPEED × SpeedMult)`, `Downed` → `DOWNED_CRAWL_SPEED` (5) and no jump, `Pinned` → 0. No sprint.

---

## 6. Map markup (tags + attributes) — GDD §7.6 / §8.3

| Tag | On | Attributes (Level sets) | Server sets | Used by |
|---|---|---|---|---|
| `PlayerSpawn` | Part | `Priority` (number, low first), `EnabledBy` (string, optional e.g. `WindowOpen`) | — | Round / respawn: lowest Priority among enabled, tie = random (no hazard check). Floor spawns Priority 2, sill spawns Priority 1 + `EnabledBy = WindowOpen` |
| `ObjectiveAnchor` | Model with child Part **`PromptPart`** | `ObjectiveId` (`RunWheel` / `DeliverBatteries` / `CallForHelp`), `Part` (`A`..`D`, MultiHold) | §4 attrs | Mission. The **socket** is the `DeliverBatteries` anchor |
| `ItemSpawn` | Part | `ItemType` (`Battery`), `Zone` (`T`/`S`/`P`) | — | Deliver: random spawns, max 1 per Zone |
| `LockedDoor` | Model | `UnlockedBy` (`WindowOpen`) | `Unlocked = true`; all its BaseParts → `CanCollide=false, CanQuery=false, Transparency=1` | Extraction |
| `ExitZone` | Part, `CanCollide=false` | — | `Open` (bool) | Departure (HRP inside the part box); `Open=true` ⇒ NoImpact |
| `ExitVehicleSpot` | Part | — | — | carrier spawn point |
| `NoImpact` | Part volume (`CanCollide=false`) | — | — | no impact lands inside. Server **also** rejects points within `NO_IMPACT_SPAWN_RADIUS` (6) of any PlayerSpawn **without** `EnabledBy` |
| `LobbySpawn` | Part (in `Workspace.Lobby`) | — | — | Lobby spawn (only needed if Level builds its own Lobby) |
| *(name)* `WinCameraPoint` | Part anywhere in the map | — | — | client win camera |
| Map root | Model `MidnightKitchen` | `KillY` (number, −30) | — | below KillY: player → Eliminated, item → recovered after 3s |

Runtime tags (server creates): `Item` (item Model/Part in `Map.Runtime`, attrs `ItemType`, `Carrier` = UserId or 0), `ExitVehicle` (carrier model, attrs `DescendStartedAt`, `DescendEndsAt`, `DescendHeight`).

Prompts (server creates or reconfigures, Style Default, `HoldDuration = 0`):

| Prompt name | Parent | Distance | Kind |
|---|---|---|---|
| `ObjectivePrompt` | anchor `PromptPart` | `INTERACT_RANGE` 8 | Repair/MultiHold = server-timed hold (Triggered = start, TriggerEnded = release); socket = press "Insert" |
| `PickupPrompt` | item | 8 | press |
| `RevivePrompt` | downed player's HRP | `REVIVE_PROMPT_RANGE` 7, `RequiresLineOfSight=false` | server-timed hold 4s |

Prompts the server **creates** use `RequiresLineOfSight = false` (PromptParts often sit inside props); a Level-placed prompt keeps its own LOS setting. Client `PromptController` hides locally (by setting local `MaxActivationDistance = 0`): own `RevivePrompt`, `PickupPrompt` while `Holding ≠ ""`, socket prompt while not holding the right item. Server re-validates everything (state, ≤ `INTERACT_SERVER_RANGE` 10 studs, step open, item type).

Raycasts for impacts/item drops use `RespectCanCollide = true` and exclude characters + `Map.Runtime`, so non-collidable volumes (ExitZone, NoImpact) and invisible `CanQuery=false` walls never count as floor.

---

## 7. Config keys (`src/shared/Config/`) — `require(Shared.Config)` returns all modules

| Module | Keys |
|---|---|
| `Round` | `MAX_PLAYERS 4`, `MIN_PLAYERS_TO_START 2`, `INTERMISSION_TIME 30`, `BRIEFING_TIME 5`, `RESULT_TIME 15`, `WIN_CINEMATIC_TIME 3`, `MATCH_HARD_LIMIT 420`, `LAST_CHANCE_WARNING_AT 320`, `LOBBY_OFFSET_X 3000`, `LOBBY_Y 0`, `LOBBY_SIZE 60`, `LOBBY_WALL_HEIGHT 40`, `LOBBY_RELOAD_DELAY 2`, `LOBBY_AFK_AFTER 60`, `ACTIVITY_MOVE_THRESHOLD 2`, `ACTIVITY_SAMPLE_INTERVAL 1`, `ACTIVITY_PING_CLIENT_INTERVAL 10`, `ACTIVITY_PING_SERVER_MIN_INTERVAL 5`, `DISASTER_NO_REPEAT true`, `MATCH_TICK 0.25`, `MISSION_ID` |
| `Player` | `MAX_HP 100`, `SPAWN_PROTECTION 3`, `WALK_SPEED 16`, `MIN_MOVE_SPEED 6`, `JUMP_HEIGHT 7.2`, `DOWNED_CRAWL_SPEED 5`, `BLEED_OUT_TIME 30`, `REVIVE_HOLD 4`, `REVIVE_PROMPT_RANGE 7`, `REVIVED_HP 40`, `REVIVE_PROTECTION 2`, `RESPAWN_BASE 15`, `RESPAWN_STEP 0`, `RESPAWN_MAX 15`, `TEAM_WIPE_RULE "AllDowned"`, `SPAWN_HEIGHT_OFFSET 3` |
| `Interaction` | `INTERACT_RANGE 8`, `INTERACT_SERVER_RANGE 10`, `HOLD_TICK 0.1`, `SMALL_CARRY_SPEED_MULT 0.9`, `ITEM_KILLY_RESPAWN_DELAY 3`, `ITEM_DROP_RAY_DISTANCE 4`, `ITEM_HINT_RADIUS 30`, `MULTIHOLD_ASSIST_AFTER 75`, `MULTIHOLD_ASSIST_MIN 2`, `REPAIR_CREDIT_THRESHOLD 0.25` |
| `Extraction` | `DEPARTURE_COUNTDOWN 10`, `LAST_CALL_AFTER 45`, `LAST_CALL_QUORUM 0.5`, `CARRIER_DESCEND_TIME 3`, `CARRIER_DESCEND_HEIGHT 60`, `EXIT_UNLOCK_FORCES_CRITICAL true` |
| `Stages` | `ORDER {Calm, Warning, Active, Critical}`, `DEFS[id] = {duration, lightingPreset, audioPreset, uiColor}` (30 / 15 / 165 / until Collapse), `WARNING_BANNER_MIN 3` |
| `Impact` | `FLOOR_RAY_START 6`, `FLOOR_RAY_LENGTH 20`, `MAX_FLOOR_DY 4`, `MAX_HIT_DY 6`, `REROLL_ATTEMPTS 5`, `DROP_HEIGHT 30`, `RANDOM_POINT_RAY_TOP 120`, `NO_IMPACT_SPAWN_RADIUS 6`, `BIG_SHAKE_DURATION 4`, `BIG_SHAKE_DAMAGE 15` |
| `Debug` | `DEV_USER_IDS {}`, `ENABLE_IN_STUDIO true`, `CHAT_PREFIX "/dbg"`, `DEV_MIN_PLAYERS_ATTR "DevMinPlayers"`, `DEV_NO_HAZARDS_ATTR "DevNoHazards"` |
| `Missions` | `MidnightKitchen_CallForHelp` (§8.4: RunWheel 45s/maxStack 2, DeliverBatteries clamp(team,1,3), CallForHelp Cumulative 4 anchors 45s assist; exitFlag `WindowOpen`, ETA 60, carrier `RescueCarrier`, disasters `{"Earthquake"}`) |
| `Disasters` | `Earthquake` (Pulse / MoveModifier / ScreenEffect / TelegraphedImpact data incl. Big Shake) |
| `Items` | `Battery` `{ displayName, size = "Small", model = "Battery" }` |

---

## 8. Server services (`src/server/Services/`) — dependency order, no cycles

| Service | Public API (others may call) |
|---|---|
| `RoundState` | `set(attr, value)`, `get(attr)`, `objectivesFolder()`, `clearMatch()` |
| `MapService` | `loadMap(mapId) → Model`, `unloadMap()`, `getMap()`, `getRuntime()`, `tagged(tag) → {Instance}` (only inside current map), `setFlag(name)`, `hasFlag(name)`, `pickSpawn(): CFrame`, `matchSpawns(n): {CFrame}`, `killY()`, `isNoImpact(pos)`, `lobbyCFrame(i)`, `ensureLobby()` |
| `PlayerStateService` | `setLobby(p)`, `beginMatch(participants)`, `endMatch()`, `spawnInMatch(p, cf)`, `damage(p, amount)`, `setHP(p, n)`, `down(p)`, `eliminate(p)`, `revive(target, reviver)`, `getState(p)`, `isStanding(p)`, `teamMembers()`, `teamCount()`, `activeCount()`, `isWiped()`, `setGlobalSpeedModifier(key, mult?)`, `setPlayerSpeedModifier(p, key, mult?)`, `addStat(p, attr, n)`; signals `Downed`, `Eliminated`, `Left` |
| `HoldService` | `register(spec) → HoldTarget`, `unregister(target)`, `release(p)`, `holdStartedAt(p)`, `addTicker(fn(dt)) → remover`, `setKeepAlive(key, bool)`, `reset()` |
| `ItemService` | `spawnItems(itemType, count, ownerKey) → number`, `isHolding(p, itemType?)`, `consume(p) → boolean`, `drop(p)`, `reduce(ownerKey, keep)`, `update(dt)`, `reset()` |
| `DisasterService` | `start(def)`, `stop()`, `setStage(id)` (fast-forward rules §4.1), `currentStage()` |
| `MissionService` | `start(missionDef)`, `stop()`, `update(dt)`, `completeCurrentStep()`, `completeAllSteps()`, `toggleDummyHolder(partLetter) → boolean`; signal `ExitUnlocked` |
| `ExtractionService` | `begin(missionDef)`, `stop()`, `update(dt) → (departed: boolean, inZone: {Player})`, `playersInZone()`, `isCarrierArrived()` |
| `RoundService` | `start()`, `forceStart()`, `forceEnd(win: boolean)` |
| `DebugCommands` | `start()` — channels: chat `/dbg <cmd> [arg]` (TextChatCommand → `DebugCommand` remote), and Command Bar `game.ServerStorage.DebugInvoke:Invoke("setHP 0 PlayerName")` |

Debug commands (case-insensitive): `skipStep`, `setStage <Calm|Warning|Active|Critical>`, `unlockExit`, `setHP <n> [playerName]` (default: caller / first participant), `spawnDummyHolder <A-D>` (toggle), `endMatch <win|lose>`, `startNow` (skip intermission wait; still needs ≥1 player).

Round flow: `Lobby/Intermission` (≥ PlayersNeeded non-AFK → 30s; drop below → back to waiting) → `Match` (random disaster with no-repeat, clone map, LoadCharacter + PivotTo floor spawns, Calm→Warning 0:30→Active 0:45→Critical 3:30 or on exit unlock) → win `Ending` 3s → `Result` 15s (hazards stopped) → destroy `Workspace.Map`, run all match cleanups, reset attributes, LoadCharacter everyone in Lobby.

Win/lose check order every `MATCH_TICK`: Departure complete (Win) → Wipe (`AllDowned`, not when teamCount = 1) → no team members (Abandoned) → time ≥ 420 (Win if carrier arrived and ≥1 in zone, else Collapse).

Solo fallback (§3.5, mid-match only): `teamCount = 1` → downed = Eliminated immediately, no Wipe; MultiHold `required = 1` when `activeCount = 1`; Deliver count shrinks to `max(delivered, min(orig, max(1, teamCount)))`.

---

## 9. Differences from the UI's assumptions (StateAdapter.luau)

- None required for names. `ResultReason` values are `Escaped/Collapse/Wipe/Abandoned` (UI already has all four).
- `HudBanner` payload adds `key` (UI may ignore it and use `text`).
- `Objectives` Configurations always exist during a match, so the anchor fallback is not needed.
- `DisasterName` is empty during Calm (by design).
- New attributes the UI may use: `Holding`, `ProtectedUntil`, `Credits`, `StepOpenedAt`, `CarrierArrivedAt`, `StageStartedAt`, `MatchStartedAt`.
- Impact rings/debris, camera shake and the "Bonk" event are delivered by remotes (§2); a basic implementation lives in `src/client/Controllers/EffectsController.luau` (UI/Art may replace it).

---

## 10. Checks (run before every handoff)

```
bash <scratchpad>/check/run.sh src          # luau-lsp analyze, --!strict, Roblox defs + sourcemap
cd <scratchpad>/selenestd && selene <repo>/src   # selene (robloxmini std; repo selene.toml uses std="roblox", which needs `selene generate-roblox-std` with network)
```
v1 state: 0 type errors, 0 selene warnings over all of `src/` (server, shared, client controllers, UI).
