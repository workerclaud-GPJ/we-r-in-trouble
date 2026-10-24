# Item system (ItemPhysics, Capabilities, CapabilitySpawn) — 25 Oct build

All three features sit behind `Config.Features` switches, and **all of them are committed `false`**.
With every switch off the code paths are byte-for-byte the old behaviour: anchored items, Battery Deliver spawning from `Battery_*` points, and the original mission. Not touched: RouteTopple, ToppleController, AddRouteTopples.

## Files

| File (repo path) | Roblox instance | Class | Change |
|---|---|---|---|
| ReplicatedStorage/Shared/Types.lua | ReplicatedStorage.Shared.Types | ModuleScript | ItemDef: `size: ItemSize`, `capabilities`, `density/friction/elasticity`; ObjectiveDef: `capability?`, `count?`; LootEntry/LootTableDef (additive) |
| ReplicatedStorage/Shared/Contract.lua | ReplicatedStorage.Shared.Contract | ModuleScript | `CollisionGroup.Items`, `Attr.SizeClass`, `Attr.Fallback` (additive) |
| ReplicatedStorage/Shared/Config.lua | ReplicatedStorage.Shared.Config | ModuleScript | `Loot = require(script.Loot)` |
| ReplicatedStorage/Shared/Config/Items.lua | ReplicatedStorage.Shared.Config.Items | ModuleScript | Battery gains capabilities and physics. New: ChargerCable, Scissors (Medium), Bottlecap |
| ReplicatedStorage/Shared/Config/Loot.lua | ReplicatedStorage.Shared.Config.Loot | **new** ModuleScript | MidnightKitchen loot table (budget 8, weights) |
| ReplicatedStorage/Shared/Config/Interaction.lua | ReplicatedStorage.Shared.Config.Interaction | ModuleScript | `MEDIUM_CARRY_SPEED_MULT`, ITEM_PHYSICS_* / ITEM_SHAKE_* / ITEM_STUCK_* tunables |
| ReplicatedStorage/Shared/Config/Round.lua | ReplicatedStorage.Shared.Config.Round | ModuleScript | `NEW_MISSION_ID` |
| ReplicatedStorage/Shared/Config/Missions.lua | ReplicatedStorage.Shared.Config.Missions | ModuleScript | Adds `MidnightKitchen_CallForHelp_Capability` (only used when Features.NewMission). The existing mission is untouched |
| ServerScriptService/Server/Services/ItemService.lua | ServerScriptService.Server.Services.ItemService | ModuleScript | Physics lying state, collision group, network owner, stuck/OOB check, shake kicks, capability API (`spawnAt`, `countType`, `countCapability`, `consumeCapability`, `hasCapability`), Medium carry speed |
| ServerScriptService/Server/Services/LootService.lua | ServerScriptService.Server.Services.LootService | **new** ModuleScript | Seeded capability spawn, verify plus fallback, `reroll`, `check` |
| ServerScriptService/Server/Services/DisasterService.lua | …Services.DisasterService | ModuleScript | `DisasterService.Shake` signal fired with each Shake ScreenEffect (no listener = no effect) |
| ServerScriptService/Server/Services/Objectives/Deliver.lua | …Services.Objectives.Deliver | ModuleScript | `capability` / `count` fields. With CapabilitySpawn it counts loot items instead of spawning |
| ServerScriptService/Server/Services/RoundService.lua | …Services.RoundService | ModuleScript | Mission choice via NewMission. Calls `LootService.spawnRound` before `MissionService.start` (CapabilitySpawn), and `LootService.reset` |
| ServerScriptService/Server/Services/DebugCommands.lua | …Services.DebugCommands | ModuleScript | `/dbg loot <seed>`, `/dbg lootcheck [n]` |
| ServerStorage/Tools/BuildItemAssets.lua | ServerStorage.Tools.BuildItemAssets | **new** ModuleScript (Studio tool) | Builds Assets.Items.{ChargerCable, Scissors, Bottlecap} |
| ServerStorage/Tools/AddItemSpawns.lua | ServerStorage.Tools.AddItemSpawns | **new** ModuleScript (Studio tool) | Adds 6 `Loot_*` ItemSpawns (2 Fallback) and sets SizeClass on `Battery_*` |

Main.lua is unchanged. No new service needs registering: LootService is a plain module required by RoundService and DebugCommands, and ItemService.start registers the collision group.

## Install in Studio (edit mode)

1. Sync or paste the scripts above. Create **ModuleScript `ReplicatedStorage.Shared.Config.Loot`** and **ModuleScript `ServerScriptService.Server.Services.LootService`**. Config.lua errors at require if Loot is missing.
2. Command Bar: `require(game.ServerStorage.Tools.BuildItemAssets)` should print 3 models. Run it after BuildProps, which owns Items.Battery.
3. Command Bar: `require(game.ServerStorage.Tools.AddItemSpawns)` should print 6 points and "SizeClass set on 6".
4. Save or publish. Both tools are idempotent, so re-running them only replaces their own output.
5. To test a feature, set its switch in `Config/Features.lua` to `true` locally. **Do not commit it as true** until the stability checklist passes.

## Design decisions

- **Collision:** lying items are in group `Items`, which collides with Default (world) but **not with `Players`**. Hamsters walk through lying items, so there are no physics fights, no standing on a rolling battery, no character flings, and no item pushed into walls by players. Items still fall off counters, slide, and bump each other. Held items are as before: welded, massless, CanCollide false.
- **Network ownership:** `handle:SetNetworkOwner(nil)` after every unanchor (spawn, drop, respawn). The server simulates, so exploiters cannot fling items, and server-set kick velocities replicate.
- **Cap:** at most `ITEM_PHYSICS_MAX = 20` physics items. Any extra item falls back to the old anchored state.
- **Earthquake kicks:** `DisasterService.Shake` fires per Shake pulse. ItemService only reacts in the Active and Critical stages: up to 3 kicks per pulse, at least 1.5 s apart, each item kicked with 60% chance at 2–5 studs/s horizontal (scaled by intensity, capped ×2), plus a 1.5 studs/s hop. This costs a few velocity writes every 20 s or so.
- **Safety:** KillY is kept (3 s below, then back to origin) for anchored items; physics items return on the first tick below KillY (they would otherwise reach FallenPartsDestroyHeight −80 and be deleted), and a physics item the engine deleted anyway is rebuilt at its origin. Every 1 s, a physics item outside the floor footprint plus exit zone (±10 studs, or above the map top), or with its centre inside an anchored collidable Block, gets a strike. After 2 consecutive strikes it is re-placed at its origin (anchored for the teleport, then physics again).
- **Prompt and pickup:** the prompt is parented to the handle, so it moves with it. Server range checks use the live `item.handle.Position`.
- **Seed algorithm (`LootService.select`, pure):** `Random.new(seed)`. For each Deliver requirement (capability, or itemType; need = `count` → `maxCount` → `minCount` → 1, the worst case at max team), pick need+1 items by weight among loot entries that match. Then fill up to `budget` by weight. Placement order: required items first, Medium items first within each group. Point scoring: non-fallback < fallback, unused Zone < used Zone, and Small items prefer Small points (Medium points accept any item, Small points only Small items). Ties are broken by the RNG. Points are sorted by name, so the same seed gives the same result. Verify step: any shortfall is force-spawned at Fallback points (smallest matching item), with a warning.
- **New ItemSpawns** have `ItemType = "Loot"`, so the legacy Battery spawner never sees them. LootService ignores ItemType.
- **Deliver with CapabilitySpawn:** items are owned by `"Loot"`, so `reduce()` and `removeOwner()` on the objective no longer remove spare items. Extra loot stays in the map, which is intended for the sandbox feel. `count` is capped to the matching items present.
- **Table top** (+38.25) has no spawn: no route reaches it (the chair seat is +23, 6 studs away, and there is no ramp).

### New spawn points (map-local = world)
| Name | Pos | Zone | Size | Fallback |
|---|---|---|---|---|
| Loot_CounterW | 52, 45, 24 | CW | Medium | |
| Loot_CounterNE | 138, 45, 24 | CNE | Small | |
| Loot_CounterE | 140, 45, 42 | CE | Medium | |
| Loot_FloorWheel | 122, 0, 92 | W | Small | |
| Loot_FallbackMid | 56, 0, 40 | M | Medium | yes |
| Loot_FallbackBack | 132, 0, 112 | B | Medium | yes |
Existing: T1/T2/S2/P1 are Medium; S1 and P2 (tight spots) are Small.

Offline check: a Python port of `select()` ran 1000 seeds against these 12 points for both the legacy (Battery×3) and the NewMission (Power×3) requirements. Result: **0 failures and 0 fallback force-spawns needed**.

## Manual test checklist (Studio, DevMinPlayers = 1)

**All switches off (regression)**
- [ ] Round starts and 1–3 batteries spawn only at `Battery_*` points. They are anchored, and the prompt works.
- [ ] Pickup → carry speed ×0.9 → insert at the charger, Deliver counts. Drop on Downed lands anchored on the floor.
- [ ] No `[Loot]` output. `/dbg lootcheck 100` still works (simulation only).

**ItemPhysics = true**
- [ ] Spawned items settle on the floor without jitter or sinking. The Explorer shows Anchored=false and CollisionGroup=Items.
- [ ] Walking into a lying battery: the hamster passes through, and the item does not move or fling.
- [ ] Downed while carrying on the counter edge → the item drops and may roll off. The prompt follows it, and pickup works where it lands.
- [ ] Fling test: in the Command Bar, set `AssemblyLinearVelocity = Vector3.new(500,0,0)` on a lying item. Within about 2 s the OOB check returns it to its origin, with a warning.
- [ ] KillY: CFrame an item to Y −50. After 3 s it is back at its origin.
- [ ] `/dbg setDisaster Earthquake`, `/dbg setStage Active`: on each shake pulse, lying items hop or slide a little, and items on the counter edge sometimes fall. Nothing launches across the room.
- [ ] Network: on the client, the Developer Console shows no ownership warnings. With two clients, no item is owned by a client (Studio "Are Owners Shown" setting).

**CapabilitySpawn = true**
- [ ] Output shows `[Loot] seed=N` and `[Loot] spawned 8/8 …`, with items spread across zones. Scissors appear only on Medium points.
- [ ] `/dbg loot 12345` twice gives an identical layout both times. `/dbg loot 1` gives a different one.
- [ ] `/dbg lootcheck 100` gives `failed=0`.
- [ ] Legacy mission: ≥ need batteries exist, and Deliver count = clamp(team, 1, 3) with no stuck step.
- [ ] Scissors carry is slower (×0.75).

**NewMission = true (+ CapabilitySpawn)**
- [ ] Inserting a ChargerCable or a Battery both count. Bottlecap and Scissors are rejected silently.

## Performance
- Physics items: budget 8 (Config.Loot) plus legacy 0. The hard cap is 20. Expect **8–10 server-owned assemblies** of 4–15 small parts each, mostly sleeping.
- Per tick: KillY loop (unchanged). Once per second, one `GetPartsInPart` per physics item (≈8 queries/s). Shake kicks: ≤3 bursts per pulse.
- No new remotes. Item replication is standard physics replication of ≤10 assemblies.

## Known risks / not verified (no Studio access, nothing was run)
- No Luau type-check or run was possible. Expect possible `--!strict` nits (e.g. the `PhysicalProperties.new` overload, `Signal<string, number, number>` generic) — fix in place.
- Thin item parts (0.18–0.5 studs) can tunnel on very fast falls. The OOB/KillY return covers it, but watch counter drops (45 studs).
- `insideGeometry` only checks anchored Block Parts (not wedges, trusses, or cylinders), so an item stuck in a ramp wedge is only caught if it also leaves bounds or falls below KillY.
- Lying items do not collide with hamsters, so they cannot be pushed or kicked by players (a deliberate trade-off). If design wants pushing, enable `Items`↔`Players` collision, but keep server ownership.
- Flood: items are not buoyant (no water physics; the volume is non-colliding), so they stay on the floor underwater. Pickup still works.
- Item procedural models (BuildItemAssets) have not been viewed in Studio. Proportions may need a tweak; handles are invisible blocks, so placement is safe.
- CapabilitySpawn with the legacy mission leaves spare batteries in the map after Deliver completes (not removed, because they are owned by "Loot").
- The RouteTopple agent may also touch DisasterService, Contract, or DebugCommands. Our edits are small additive hunks, so expect trivial merges.
