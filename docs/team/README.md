# The Crowbar Crew team (agents)

Maurits is the owner and a beginner. Claude (the main session) is the **orchestrator**: it assigns work, merges branches
and makes decisions together with the advisor. **Nobody asks Maurits questions.** Doubts about design, market or taste →
ask the **advisor**.

**Language: everything is in English** — player-facing text, code, comments, docs, commit messages and agent reports.

Goal: a **beta-ready** Roblox game with **multiple maps (heists)**. Direction (approved by Maurits on 16 Oct 2026):
**"Sneak in, grab as much cheese as you dare, and escape."** Teamwork is an *advantage*, not a requirement.

## Roles (definitions in `.claude/agents/`)

| Role | Does | Owns (files) |
|---|---|---|
| `advisor` | Research (Roblox market, what works, rules), decides design questions, reviews specs and builds | `docs/research/` |
| `mechanics` | Designs and builds gameplay: round, loot, carrying, escape, capture/rescue, guards, dog, Karel, gadgets | gameplay `src/server/Services/*`, `src/shared/Logic/*`, gameplay controllers |
| `map` | Level design and building: routes, loot spots, hiding spots, escape routes, randomisation anchors, props, new heists | `src/server/Map/*`, `tools/props.json` |
| `ux` | HUD, menus, onboarding, mobile buttons, results screen, sound and "juice" | `src/client/Lib/Hud*`, UI controllers, `src/shared/Sounds.luau` |
| `meta` | Saving (DataStore), money, progression, hideout/lobby, shop, analytics | `src/server/Services/{Data,Economy,Lobby,Shop,Analytics}*` |
| `tester` | Tests in Studio (the only role with Studio access), writes test scenarios, bug reports, previews | `tools/studio_tests/`, `docs/team/bugs.md` |

Shared files (`src/shared/Config.luau`, `Tags.luau`, `Net.luau`, `default.project.json`): everyone may edit them, but only
inside **their own block** (a header comment with the role name). The orchestrator resolves merge conflicts.

## Working agreements

1. Read `CLAUDE.md`, `docs/beta-spec.md` (once it exists) and the relevant research in `docs/research/` first.
2. Work in your own git worktree/branch. Commit small and clear (in English), with the attribution lines from `CLAUDE.md`.
3. Before saying "done": `sh tools/check.sh` must be green (typecheck, lint, formatting, unit tests).
4. Pure logic (calculations, randomisation, economy) goes in `src/shared/Logic/` with a test in `tests/**/*.spec.luau`.
5. **Studio:** only the `tester` (or the orchestrator) uses the Roblox Studio tools, never two at once.
   Others do not call `mcp__plugin_roblox-studio_*` unless their assignment explicitly allows it.
6. Never publish, never make the game public, never use passwords or API keys, never install third-party MCP servers,
   never close Studio. Maurits publishes.
7. Content: rating **Mild** — no blood, no real weapons; pranks buy time, never a solution (gameplan §4.8). No free chat.
8. Report briefly: what was done, which files, what was tested (with results), what is still open.

## Flow

`advisor` research → `mechanics` + `map` write `docs/beta-spec.md` → `advisor` reviews → build in parallel
(`mechanics`, `map`, `ux`, `meta`) → orchestrator merges → `tester` tests in Studio → bugs go back to the owner →
retest → beta checklist (`docs/beta-checklist.md`) green → Maurits publishes.
