# Studio test scenarios

Reusable playtests for Crowbar Crew that run inside Roblox Studio through the Studio MCP tool `execute_luau`.
Every scenario returns plain text: one line per step (`PASS` / `FAIL` / `WARN` / `INFO`) and a last line
`RESULT: x/y`. Only the `tester` role (or the orchestrator) uses Studio, and never two at the same time.

```
tools/studio_tests/
  bundle.py            pastes the shared helpers in front of a scenario (prints one piece of Luau)
  lib/prelude.luau     shared helpers: table T (waiting, teleporting, DevService remotes, server messages, ...)
  scenarios/*.luau     one scenario per file; the header says in which datamodel it runs
  screenshots/         evidence for bug reports (can be deleted once the bug is closed)
```

## Before you start

1. Studio is open with the place "Crowbar Crew" and Studio-as-MCP-server is on (see `CLAUDE.md`).
2. Get the studio id with `list_roblox_studios` (it changes when Studio reconnects).
3. **Maurits has priority in Studio.** If he is playing or editing, only run non-intrusive checks (Edit
   checks, reading state). Never stop or restart a playtest he is using and never teleport his character.
   Check idle in Edit first: camera and `Selection` unchanged for ~10 s.
4. Sync the code (Edit mode, never during a playtest):
   `python3 tools/studio_sync.py`, then run the contents of `tools/studio_sync_apply.luau` with `execute_luau`
   (datamodel `Edit`). It reports `HttpEnabled=false` at the end.

## Running one scenario

```sh
python3 tools/studio_tests/bundle.py --list                       # all scenarios + datamodel + goal
python3 tools/studio_tests/bundle.py 30 --compact -o /tmp/b.luau  # prelude + scenario 30 in one file
```

Paste the bundle into `execute_luau` with the datamodel from the scenario header (`-- datamodel: Client`).
`execute_luau` only accepts code text, not a file, so the bundle has to be pasted. `--compact` drops comment and
blank lines (about 25% less text). This script deliberately starts no StudioMCP process of its own: a second
StudioMCP process is forbidden (see `CLAUDE.md`).

Scenarios with `play: yes` need a running playtest (`start_stop_play` with `is_start: true`). You can see which
datamodels are available with `get_studio_state`.

## Suite order

| # | Scenario | Datamodel | Notes |
|---|---|---|---|
| 1 | `00_place_check` | Edit | after the sync, before playing |
| 2 | *start the playtest* | | |
| 3 | `10_spawn` | Client | right after the start (forces a fresh spawn with RestartRun if needed, ~8 s) |
| 4 | `20_pedestals` | Client | read-only |
| 5 | `25_signs_readable` | Client | read-only |
| 6 | `30_gadget_take_return` | Client | |
| 7 | `40_pathfinding` | Server | **doors closed**: only the shop may be reachable |
| 8 | `50_guard_capture` | Client | raises the alarm (+40) |
| 9 | `60_emp_lamps` | Client | ~18 s (waits for the 12 s window) |
| 10 | `70_doors` | Client | opens all 3 doors |
| 11 | `40_pathfinding` | Server | **doors open**: everything must be reachable |
| 12 | `80_goal_reset` | Client | ends the run, ~13 s; the reset also clears the test state |
| 13 | `90_console` | Server **and** Client | run it in both datamodels, last |
| 14 | `95_performance` | Server | 5 s measurement after the reset |
| 15 | *stop the playtest* | | |
| 16 | `00_place_check` | Edit | clean-up check |

A full suite takes about 10 minutes, most of it pasting. The alarm ladder reaches LOCKDOWN at 300 points; running
`50_guard_capture` many times in one playtest can trigger a lockdown that ends the run after 90 s. Restart the
playtest or run `80_goal_reset` to reset.

## Reading the output

```
== 60 EMP turns lamps off and restores their colour [Client, 18.4 s]
PASS  take the EMP — EMP
PASS  lamps inside the EMP radius — SecurityLamp(200,225,255, Neon)
...
RESULT: 10/10
```

- `PASS` / `FAIL`: the step with a short explanation after the dash.
- `INFO`: a measurement or context, not counted.
- `WARN`: the step failed, but someone pressed keys in the Studio window during the run (`DISTURBED` line).
  Re-run when nobody is playing before you call it a bug.
- `RESULT: SKIPPED`: a Client scenario waited 30 s and someone kept playing; nothing was changed.
- `scenario ran without a script error` FAIL: the scenario itself crashed (the traceback follows).

Every Client scenario first waits until there has been no keyboard or mouse input for 5 s (`T.waitIdle`).

## Writing a new scenario

1. Create `scenarios/NN_name.luau` (the number sets the order in `--list`). Start with the header:

   ```lua
   -- datamodel: Client          (Edit, Server, Client or e.g. Server/Client)
   -- play: yes                  (yes = needs a running playtest)
   -- goal: one line that says what must be true
   ```

2. The body is one call that returns the result text:

   ```lua
   return T.run("NN short title", "Client", function()
       T.listen()                                   -- record messages from the server
       if not T.step("take the Crowbar", T.take("Crowbar")) then
           return                                   -- stop when a precondition fails
       end
       local ok, detail = T.pry("CageDoor")
       T.step("CageDoor opens", ok, detail)
       T.info("alarm level: " .. tostring(T.alarmLevel()))
   end)
   ```

3. `python3 tools/studio_tests/bundle.py NN --compact -o <scratchpad>/b.luau`, then check it with
   `luau-lsp analyze --platform roblox --definitions @roblox=tools/defs/globalTypes.d.luau <scratchpad>/b.luau`
   and format with `stylua --config-path stylua.toml tools/studio_tests`.
4. Add the scenario to the suite table above.

### Helpers (`lib/prelude.luau`)

| Helper | Where | What |
|---|---|---|
| `T.step(name, ok, detail)` / `T.info(text)` | all | record a result / a note |
| `T.waitFor(fn, timeout, interval)` | all | wait until `fn()` is truthy; returns `(value, seconds)` or `nil` |
| `T.level()`, `T.find(name)`, `T.tagged(tag, name?)`, `T.attr(inst, name)` | all | find things in `workspace.Level` |
| `T.floorAt(pos)` | all | floor below a point (ignores players, guards and non-colliding parts) |
| `T.player()`, `T.character()`, `T.root()`, `T.humanoid()` | Server, Client | the (first) player |
| `T.teleport(pos, lookAt?)` | Server, Client | move the character (from Client it replicates immediately) |
| `T.request(name, ...)` | Client | `Remotes.ToServer:FireServer(name, ...)`, e.g. `DevTake`, `DevPry`, `Throw`, `RestartRun` |
| `T.listen()`, `T.waitMessage(name, timeout, since, predicate)`, `T.toasts(since)` | Client | messages from the server (`Toast`, `RunEnded`, `Caught`, `EMP`, `Window`, `Crack`, ...) |
| `T.take(g)`, `T.drop(g)`, `T.dropAll()`, `T.gadgets()`, `T.has(g)` | Client | gadgets through the Studio-only `DevService` |
| `T.door(name)`, `T.isOpen(door)`, `T.pry(name)` | Client (`pry`) | the Pryable doors (`StaffDoor`, `DeliveryGate`, `CageDoor`) |
| `T.respawn()` | Client | `RestartRun` and wait for the new character (~8 s, rebuilds the level) |
| `T.guard()`, `T.guardState()`, `T.guardRoot()`, `T.alarmLevel()` | all | guard and alarm state from attributes |
| `T.logProblems()` | Server, Client | errors/warnings from our code, unknown errors, ignored Roblox noise |
| `T.P` | all | key positions (copy of the heist `Points`); **update when the map changes** |

### Rules and pitfalls

- **The Server datamodel has its own module cache.** `require`-ing a service there gives you a fresh copy, not the
  running game. Read state through instances, attributes, tags and server→client messages, and act through the
  Studio-only `DevService` remotes from the Client datamodel.
- Fast transitions (Alert → capture takes ~0.3 s) are missed by polling: record them with
  `GetAttributeChangedSignal` and put the connection in `T.conns` (`T.run` disconnects it).
- Leave no trace in Edit: everything a scenario creates in Server/Client disappears when the playtest stops. Do not
  create folders or modules in the Edit place; `00_place_check` looks for leftovers.
- Keep a scenario under ~30 s; split longer flows.
- Some properties cannot be read from `execute_luau` (e.g. `Lighting.Technology`: "lacking capability RobloxScript").
- Pathfinding: the default agent has radius 2; openings narrower than ~6 studs can block it. After a door opens the
  navmesh needs a moment to update; one early `NoPath` right after a manual door opening was not reproducible.
- `screen_capture` only works while Studio renders. Check in Edit that `RunService.RenderStepped` fires (15+ frames
  per second); otherwise use the Blender preview (`tools/preview/`). Passing `camera_position` moves the camera only
  for the shot.

## Baseline (2026-10-16, main 6060557 + regression on 021c25d)

| Scenario | Result |
|---|---|
| 00 place check | 10/10 (before and after) |
| 10 spawn | 12/12 |
| 20 pedestals | 18/18 |
| 25 signs readable | 2/10 on 021c25d: all 8 signs drawn at 8 px (bug B-001) |
| 30 take/return gadgets | 19/19 |
| 40 pathfinding, doors closed | 6/7: shop not reachable with radius 2 (B-002) |
| 40 pathfinding, doors open | 7/7 |
| 50 guard capture | 10/11: Alert not visible to the client before the capture (B-003); earlier run 11/11 |
| 60 EMP lamps | 10/10 |
| 70 doors | 24/24 |
| 80 goal reset | 12/12 |
| 90 console | Server 3/3, Client 3/3 (both builds) |
| 95 performance | parts 3136 (150 MeshParts), lights 69 (25 with shadows), see below |

Performance baseline (Studio play solo on Maurits' Mac, 1 player, 1 guard):

- `workspace.Level`: 3136 BaseParts (150 MeshParts, 0 Unions, 8 invisible); 4159 instances in Workspace.
- Lights: 69 (32 PointLight, 3 SpotLight, 34 SurfaceLight on lit windows); 25 cast shadows (22 lamps, guard
  flashlight, 2 camera cones).
- Server heartbeat over 5 s: 300 frames, average 16.66 ms (60 fps, frame-capped), p95 18.42 ms, max 18.86 ms;
  `HeartbeatTimeMs` 0.29, `PhysicsStepTimeMs` 0.72.
- Memory `Stats:GetTotalMemoryUsageMb()`: 4187 MB. This is the whole Studio process (editor + server + client), so
  it is INFO only. Measure on a phone with the Developer Console (F9 → Memory).

Provisional budgets in `95_performance` (to be confirmed on a phone): ≤ 6000 parts, ≤ 60 lights, ≤ 12 lights with
shadows, heartbeat average ≤ 20 ms, max ≤ 100 ms.
