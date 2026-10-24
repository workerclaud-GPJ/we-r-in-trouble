# RouteTopple — notes

Feature switch: `Config.Features.RouteTopple` (committed as **false**). When it is false:
`MapService.loadMap` strips every `RouteTopple`-tagged model from the round's map clone, so the
map plays exactly as before. `RouteToppleService.begin`, `RouteToppleService.debugTopple` and
`RouteToppleController.start` also return without doing anything.

## Files

| Repo file | Roblox instance path | Class | Change |
|---|---|---|---|
| `ServerScriptService/Server/Services/RouteToppleService.lua` | `ServerScriptService.Server.Services.RouteToppleService` | ModuleScript | **new**, the server-authoritative topple |
| `StarterPlayer/StarterPlayerScripts/Client/Controllers/RouteToppleController.lua` | `StarterPlayer.StarterPlayerScripts.Client.Controllers.RouteToppleController` | ModuleScript | **new**, client wobble, creak, dust and thud |
| `ReplicatedStorage/Shared/Config/RouteTopple.lua` | `ReplicatedStorage.Shared.Config.RouteTopple` | ModuleScript | **new**, tunables (required directly; `Config.lua` not edited) |
| `ServerStorage/Tools/AddRouteTopples.lua` | `ServerStorage.Tools.AddRouteTopples` | ModuleScript | **new**, Studio map tool that adds the 2 pieces |
| `ReplicatedStorage/Shared/Contract.lua` | `ReplicatedStorage.Shared.Contract` | ModuleScript | +`Tag.RouteTopple`, +`Name.FallenPose`, +`Attr.TopplesOn/ToppleWarning/ToppleFallAt/ToppleFallTime/ToppleLanded` (additive) |
| `ServerScriptService/Server/Services/DisasterService.lua` | `…Services.DisasterService` | ModuleScript | +require, `begin` in `start()`, `onStage` at the end of `enterStage`, `reset` in `stop()` (4 lines) |
| `ServerScriptService/Server/Services/MapService.lua` | `…Services.MapService` | ModuleScript | strips RouteTopple models from the clone when the feature is off (+12 lines) |
| `ServerScriptService/Server/Services/DebugCommands.lua` | `…Services.DebugCommands` | ModuleScript | +`topple [all]` command (additive) |
| `ServerScriptService/Server/Main.lua` | `ServerScriptService.Server.Main` | Script | +require and `RouteToppleService.start()` (boot check only) |
| `StarterPlayer/StarterPlayerScripts/Client/Main.lua` | `StarterPlayer.StarterPlayerScripts.Client.Main` | LocalScript | +`start(RouteToppleController)` |

Not touched: ItemService, Config/Items, Objectives/*, Config/Missions, Config.lua, ToppleController
(tag `Toppleable` is not reused).

## Install in Studio
1. Sync with Rojo, or paste each file into the instance at its path. The 4 new ModuleScripts must exist before Play.
2. In Edit mode, open the Command Bar and run `require(game.ServerStorage.Tools.AddRouteTopples)`.
   It has to run after BuildMidnightKitchen and AddFloodMarkup. It is idempotent: it replaces `ServerStorage.Maps.MidnightKitchen.RouteTopples`.
   `require` caches its result per Studio session, so for a second run in the same session paste the file into the Command Bar instead.
   The output should list `IroningBoard, BreadBoard`.
3. The service is registered in **ServerScriptService.Server.Main** (`RouteToppleService.start()`, which only does a boot check). The round work is driven by DisasterService, so nothing else needs registering.
4. Set `Config.Features.RouteTopple = true` locally to test, then save the place (the map model now contains the pieces).

## Manual test checklist (Studio, `DevMinPlayers = 1`)
- [ ] Flag **off**: no RouteTopple models appear in `Workspace.Map`, no `[RouteTopple]` output, and the round plays exactly as before. The existing decor topple still runs on Big Shake/Critical.
- [ ] Flag on, boot output shows `[RouteTopple] enabled, 2 piece(s) …`.
- [ ] `/dbg startNow`, then `/dbg setStage Active` prints `[RouteTopple] seed=… disaster=… eligible=2` and `… in 12 s`, plus a second piece 5–9 s later when 2 were picked.
- [ ] Warning: the piece wobbles towards its fall side for 3 s. The creak is silent until `Config.Audio.RopeCreak` gets an id.
- [ ] Fall: ~1.2 s, accelerating. A player standing on or next to it during the fall is not flung (it does not collide while moving).
- [ ] Land: the piece lies exactly in its FallenPose (re-run the round to compare), with dust along the board.
- [ ] IroningBoard: walk from the floor (≈125.5, 0, 97) up to the north counter at Z 30 with no jump and no snag at either end.
- [ ] BreadBoard: walk from the counter (≈120, 45, 26) up onto the window sill front edge (Z 10, Y 61) with no jump.
- [ ] Stand under or next to the IroningBoard's landing line: you take 50 dmg + stun (Bonk), and you end up on top of the board, not inside it.
- [ ] Counter route Ramp2 → Radio B/C/D is still walkable with the BreadBoard standing and fallen. Floor routes cage → wheel, charger, shoe rack and table are still walkable with the IroningBoard standing and fallen.
- [ ] `/dbg topple` topples one piece immediately (any disaster). `/dbg topple all` topples the rest. A third call returns "no eligible RouteTopple piece left".
- [ ] Round end and next round: pieces stand again (fresh map clone) and a new seed is printed.
- [ ] `ServerStorage` attribute `DevNoHazards = true`: no automatic topple (`/dbg topple` still works).
- [ ] Flood: no `[RouteTopple]` errors while the water rises around the IroningBoard.
- [ ] 2 clients: both see the wobble, fall and dust, and a late joiner sees the fallen pose with no wobble.

## Design decisions
- **Server-driven fall.** The server calls `Model:PivotTo(start:Lerp(FallenPose, QuadIn(t)))` every Heartbeat on anchored, non-colliding parts, then snaps to the exact FallenPose and restores the authored CanCollide. The result is deterministic and the pose is exact. Clients only see replicated CFrames, so there is no client/server desync to reconcile.
- **Shared hinge.** Standing and fallen pivots share the same point (the hinge on the bottom face), so the Lerp is a pure rotation about the hinge.
- **Landing hit.** Players whose HumanoidRootPart lies inside a colliding part's footprint take `Config.RouteTopple.DAMAGE` through `PlayerStateService.damage` and are stunned if still standing, the same rules as TelegraphedImpact. The footprint is the side padding plus 6 studs under the board's underside and 3 over its top. NoImpact volumes are respected (no damage there). Any character inside is lifted onto the board's top surface.
- **Lifecycle.** DisasterService calls `begin(id, hazardsEnabled)` in `start()`, `onStage(stage)` for stages with a hazard rhythm (Active, or Critical if Active was fast-forwarded), and `reset()` in `stop()`. `reset()` cleans a Cleanup scope. A topple interrupted mid-way is snapped to its FallenPose without damage. The map is re-cloned each round (verified in `MapService.loadMap`/`unloadMap`), so the service keeps no other state.
- **Per-round seed.** Pieces are sorted by full name and then shuffled with `Random.new(seed)`, and the count is 1..`MAX_PER_ROUND`. The seed is printed, so the same seed with the same map reproduces the pick and the timing.
- **Collision on the pieces.** Only the part named `Board` collides or is queryable. Every other part on the pieces is decor.

## Pieces (map-local = world)
| Piece | Hinge pivot | Standing | Fallen top surface | Slope / width |
|---|---|---|---|---|
| IroningBoard (7 × 1.5 × 81.44) | (125.5, -1.2008, 97.0841) | upright, leaning 6° north, top ≈ Y 80, X 122..129 Z 88.6..98.6 | (125.5, 0.05, 97.9) → (125.5, 45, 30) = floor → CounterN_Top south edge | 33.5°, 7 |
| BreadBoard (6 × 1 × 27.86) | (120.1041, 44.2301, 26.0865) | upright on CounterN_Top, leaning 4° SE, top ≈ Y 72 | (120.5, 45.05, 26.5) → (104.7, 61, 10) = counter → WindowSill_Inner front edge | 34.9°, 6 |

Full math is in the header of `AddRouteTopples.lua`. I checked it offline with an oriented-box (SAT) test of the board against every part in `midnightkitchen_map.json`, plus a 1-stud grid walk test (hamster radius 1.2, height 5.5) on the floor and counter:
- No overlap standing, fallen or at any of 40 steps of the fall.
- No overlap with Spawns, ItemSpawns, Objectives, ExitZone, NoImpact or Routes.
- No route is blocked.

## Known risks / not verified (no Studio)
- I could not run any of the code: there is no Luau toolchain here, and type errors could only be checked by eye.
- `Model:PivotTo` every Heartbeat replicates CFrames for 1.2 s. With only 2–6 parts per piece this should be fine, but it can stutter slightly on a high-ping client.
- The creak (`RopeCreak`) and thud (`CarrierLand`) are silent until their Config.Audio ids are filled. To use dedicated sounds, change `Config.RouteTopple.CREAK_SOUND/LAND_SOUND`.
- The IroningBoard's high-end lower corner tucks 0.83 studs into the counter top edge on purpose, to hide the seam. If Humanoid stepping snags there, lower `FallenPose` by ~0.3.
- The fallen IroningBoard sits in the Flood water. That is fine (it is anchored), but in a Flood it becomes a high-ground escape route, which changes Flood difficulty slightly. Remove `Flood` from `TopplesOn` if that is unwanted.
- The standing boards are CanQuery true, so RandomPoint debris (visual only) can land on top of them.
- Players are lifted onto the board with `char:PivotTo` on the server. Characters are client-owned, so a brief snap-back is possible on a laggy client.
- Running `AddRouteTopples` before `AddFloodMarkup` is fine; running `BuildMidnightKitchen` again deletes the pieces, so run AddRouteTopples again after it.
