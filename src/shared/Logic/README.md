# Logic (pure Luau)

Modules here are **pure**: no `game`, no Roblox services, no Roblox types (positions are plain `{x, y, z}` tables).
They get everything through arguments (numbers, tables, a seed, the `Config` table) and return a result.
That means they can be tested without Studio using Lune: `lune run tests/run` (tests in `tests/**/*.spec.luau`).
Server and client code call them through `require(ReplicatedStorage.Shared.Logic.<Name>)`.

**Requiring another Logic module** is allowed, only with this line (works in Roblox and in Lune, and luau-lsp
type-checks it):

```lua
local Rng = if script then require(script.Parent.Rng) else require("./Rng")
```

Never require `Config`, `Net` or anything outside this folder; pass the `Config` table in as an argument instead
(see `RoundPlan.rulesFrom(Config)`, `Perks.defaultsFrom(Config)`, `Difficulty.base(Config)`).

| Module | Owner | What |
|---|---|---|
| `Rng` | mechanics | Deterministic random numbers (seeded) |
| `Movement` | mechanics | Walk speed / jump / may crouch / may use gadgets, by state priority |
| `Detection` | mechanics | Meter fill time, factors, alarm tier, vision range, cone, who is ignored |
| `RoundClock` | mechanics | Police time, shift change, lockdown, JUMP IN window, "JUST MADE IT" |
| `RoundPlan` | mechanics | The seeded round setup: loot, Gouda, entrances, exits, guards, hazards, objectives |
| `NpcBudget` | mechanics | Guard count within the 7-NPC cap |
| `Difficulty` | mechanics | Easy / Normal / Hard effects on the round |
| `Perks` | mechanics | Per-player stats after perks (`LoadoutService:StatsOf`) |
| `Awards` | mechanics | One payout award per crew member |
| `Throw` | mechanics | Throw clamp, flight time, arc, catching |
| `LootRules` | mechanics | Pick-up rules, pockets, fragile/melting value, banking |
| `CrackDevice` | mechanics | The Cheese Grater 3000 on a safe (progress, jams, beeps) |

Meta adds its own (`Payout`, `JobBoard`, `HotJob`, `Progression`, `PerkTree`, …; see `docs/beta-spec-meta.md` §8.1).
