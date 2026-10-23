# Code Conventions (Luau + Rojo)

## Repo layout (Rojo)

```
default.project.json
src/
  server/   -> ServerScriptService.Server   (Scripts + server-only ModuleScripts)
  client/   -> StarterPlayer.StarterPlayerScripts.Client
  shared/   -> ReplicatedStorage.Shared     (ModuleScripts used by both sides)
docs/
```

- File suffixes: `*.server.luau` = Script, `*.client.luau` = LocalScript, `*.luau` = ModuleScript.
- One entry Script per side (`Main.server.luau`, `Main.client.luau`) that requires and starts services/controllers. Avoid many loose Scripts.

## Language rules

- `--!strict` at the top of every file. Type exported module tables.
- Modern APIs only: `task.wait/spawn/delay/defer`, never `wait`/`spawn`/`delay`.
- No global state via `_G` / `shared`.
- Names: `PascalCase` for modules/services/types, `camelCase` for locals/functions, `UPPER_SNAKE` for constants.
- Tunable numbers (timers, damage, speeds) live in config modules under `src/shared/Config/`, never hard-coded in logic.
- Theme content (disasters, mission objectives, props) is data-driven so Theme B (Sci-fi) can reuse the same systems.

## Server authority & security

- Server owns all game state (round phase, mission progress, health, rewards). Client only requests and displays.
- All RemoteEvents/Functions are declared in one place (`src/shared/Remotes.luau`) with a documented payload for each.
- Every server handler validates: player state, argument types, ranges, distance/cooldown where relevant. Never trust client-sent positions, damage, or completion flags.
- Prefer RemoteEvent over RemoteFunction server→client (never invoke the client).

## Performance

- No per-frame loops on the server unless necessary; prefer events and `task.delay`.
- Clean up connections (store and `:Disconnect()`), destroy spawned instances when a round ends.
- Disaster effects that are purely visual run on the client.

## Reviewer checklist (Code Reviewer uses this)

1. Matches GDD + architecture contract
2. `--!strict`, no type errors, no deprecated APIs
3. Remote validation present on every handler
4. No leaks (connections, instances) across rounds
5. Config values not hard-coded
6. Readable: small functions, clear names
