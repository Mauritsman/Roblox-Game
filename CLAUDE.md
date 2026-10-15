# Crowbar Crew — working agreements for Claude

Roblox co-op stealth heist. Design: `docs/gameplan-roblox.md` and the beta spec (`docs/beta-spec*.md`, once written).
Owner: Maurits, a beginner. **Everything in this project is in English**: player-facing text, code, comments, docs,
commit messages and reports (owner's instruction, 16 Oct 2026).

## Structure
- `default.project.json` — Rojo project. Code in `src/`:
  - `src/server/` → ServerScriptService.Server (bootstrap loads `Services/*`: Init() then Start())
  - `src/client/` → StarterPlayerScripts.Client (bootstrap loads `Controllers/*`; helpers in `Lib/`)
  - `src/shared/` → ReplicatedStorage.Shared (`Config`, `Net`, `Tags`, `Signal`, `Logic/*`)
- The level is built in code: `MapService:Build(heistId?)` builds a heist from `src/server/Map/Registry.luau`.
  One folder per heist in `src/server/Map/Heists/` (map 1 "The Golden Wheel": `Heists/GoldenWheel/` with `init.luau` =
  definition, `Quay`, `Shop`, `Warehouse`); shared building blocks in `src/server/Map/Common/` (`Builder`, `CanalHouse`,
  `Atmosphere`). New heist: `src/server/Map/README.md`. Change the level there, never in Studio.
- AI props (van, street lamp, cheese wheel, …) are models in the place's `ServerStorage.Props`; `Builder.prop` clones them
  and falls back to simple blocks if a prop is missing. IDs and prompts: `tools/props.json`; rebuild:
  `tools/restore_props.luau`. Do not remove gameplay tags/attributes (Lamp, Pryable, Goal, GadgetPedestal, cameras).
- Signs use `Builder.sign` (self-lit text, padding, outline). Every sign must be fully readable from where players stand.
- Generate meshes only in Edit mode (not during Play) and at most 2 at a time (otherwise "Too Many Requests").
- All tunable numbers live in `src/shared/Config.luau`.

## Rules
- The server is authoritative: the client asks (`Net.request`), the server validates and acts.
- Networking only through `Net` (one RemoteEvent pair). New requests: `Net.onRequest` on the server.
- No free chat; pings are fixed words/icons (gameplan §3.5 on preset rules).
- Only funny, non-lethal "weapons" that disable one guard for a window (gameplan §4.8); no real weapons, no blood (rating Mild, §5).
- Change code in the files, never directly in Studio (sync would overwrite it).

## Team
There is an agent team (advisor, mechanics, map, ux, meta, tester): see `docs/team/README.md` and `.claude/agents/`.
Maurits is not asked anything; design questions go to the advisor. Goal: beta-ready with multiple maps.

## Checking and building
- `sh tools/check.sh` — typecheck (luau-lsp), lint (selene), formatting (stylua), unit tests (Lune: `lune run tests/run`). Must be green before a commit.
- Pure logic in `src/shared/Logic/` (no Roblox APIs) with tests in `tests/**/*.spec.luau`.
- `export PATH="$HOME/.rokit/bin:$PATH"; stylua src tests` — apply formatting.
- `rojo build default.project.json -o build/CrowbarCrew.rbxl` — build a place file.

## Studio (through the official Roblox Studio plugin / Studio MCP)
- Requires Studio open with a place, and Assistant → ⋯ → Settings → MCP Servers → "Enable Studio as MCP server" on.
- Code into Studio without a Rojo click: `python3 tools/studio_sync.py` (builds build/studio_payload.json and starts a
  server on 127.0.0.1:34999), then run the contents of `tools/studio_sync_apply.luau` with `execute_luau`
  (datamodel Edit, not during a playtest). The script turns HttpEnabled on briefly and off again.
- In Studio playtests a `DevService` exists (only when RunService:IsStudio()): from the Client datamodel
  `Remotes.ToServer:FireServer("DevTake", "EMP")` and `FireServer("DevPry", "CageDoor")` (or "StaffDoor", "DeliveryGate")
  to test without buttons. Test scenarios: `tools/studio_tests/`.
  ProximityPrompts and screen_capture only work while the Studio window is visible and rendering (macOS).
- What is in Studio only goes live after Maurits does File → Publish (Claude cannot publish).
- Testing: `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`.
- Never start or register a second StudioMCP process (port 13469); the plugin manages it.
- Never close Studio yourself and never edit Studio's settings files (official Roblox rule).

## Looking without a Studio screen (Blender preview)
If `screen_capture` hangs (Studio does not render when its window is not visible), use the Blender preview:
1. `python3 -I tools/preview/receiver.py <dir> 35001 &` (listens on 127.0.0.1 only).
2. Run `tools/preview/studio_dump.luau` with `execute_luau` (Edit): builds the level and sends parts, lights and meshes.
3. `python3 -I tools/preview/to_gltf.py <dir> level.glb`, then import into Blender (glTF) and render.
Clean up afterwards: stop the receiver; leave no DevTools in ServerStorage.

## Tools on this Mac
Rokit (`~/.rokit/bin`): rojo 7.7.1, selene, stylua, luau-lsp, lune 0.11. Blender 5.2 + Blender MCP (telemetry off, safe mode),
RBXMonkey add-on (Blender) + plugin (Roblox inventory), Roblox Blender Plugin (login started on 16 Oct; Maurits still has to
click Authorize in the browser).
