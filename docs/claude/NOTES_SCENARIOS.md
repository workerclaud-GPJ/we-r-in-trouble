# Escape scenarios (25 Oct 2026)

Goal: every round the team must escape the kitchen, but the way out changes with the items
that spawn. Behind `Config.Features.NewMission` (needs `CapabilitySpawn` too; without it the
old capability mission runs).

| # | Mission id | Items (fixed spawn) | Steps | Exit |
|---|---|---|---|---|
| 1 | `MidnightKitchen_CallForHelp_Capability` | batteries / cable (random) | wheel + plug in → radios | rescue carrier at the window |
| 2 | `MidnightKitchen_CableWindow` | cable `Scn_UnderTable`, scissors `Scn_CounterW` | hang cable on the cookbook stack (cookbook ramp is hidden this round) → pry latch → push window (2 anchors) | jump out of the window (no carrier) |
| 3 | `MidnightKitchen_Drain` | scissors `Scn_Pantry`, cable `Scn_BackCorner` | pry grate → lift grate (2 anchors) → tie cable | drop into the drain under the step chair |

Pick: equal odds, never the same twice in a row (`Config.Round.SCENARIO_IDS`).
Other items still spawn randomly up to the loot budget (decoys).

## Data (Types.MissionDef)
`exitKind` (nil = carrier, "Window" / "Drain" = direct exit), `exitId` (ExitZone attr ExitId),
`hideParts`, `fixedLoot` ({itemType, spawn} on ScenarioOnly ItemSpawns), `winCamera`.
ObjectiveDef `setsFlag` → `MapService.setFlag` → shows FlagReveal parts with that RevealedBy.

## Map (tools/AddEscapeScenarios.luau, idempotent)
Folder `Scenarios` (Window: CableBridge, HangCable, PryLatch, PushWindow A/B; Drain: shaft, grate
LockedDoor `DrainOpen`, cable, screws, anchors, DrainExitZone, DrainCameraPoint), 4 `Scn_*` ItemSpawns,
floor split around the hole (`Floor`, `Floor_DrainE/N/S`) + `DropArea` (old full floor).
Move the drain: change `DRAIN_CENTER` and re-run (on a map that has not been split yet).

## Debug
`/dbg scenario 1|2|3|window|drain` (next match) · `/dbg startNow` · `/dbg lootCheck 300 all`

## Tested (Studio solo, 25 Oct ~05:00)
- Drain: pick scissors → pry → lift (hold) → pick cable → tie → grate gone, cable shown, Critical,
  drop into hole → zone 1/1 → Departure → win "EscapedDrain".
- Window: cable from under the table → walk ramp1 to the stack → cannot go up (ramp hidden) →
  hang cable → walk up the bridge to the counter → scissors → dish rack ramp → sill → pry → push →
  window opens → walk out to the flower box → win "EscapedWindow".
- Scenario 1: carrier ETA flow unchanged. lootCheck 300 seeds × 3 scenarios: failed=0.
- Not tested: 4 players, old phone FPS, Flood water inside the drain shaft.
