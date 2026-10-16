# Integration interfaces (wave 1 build)

Orchestrator, 16 Oct 2026. Several agents build in parallel; these are the **cross-service entry points** everyone codes
against. Names of Net messages, attributes, tags and Config keys: `docs/contracts.md`. Specs: `docs/beta-spec*.md`.

## Service entry points (server)

| Service | Owner (package) | Entry points others call |
|---|---|---|
| `RoundService` | mechanics A | `PhaseChanged` (Signal: phase), `GetState()`, `StartLockdown(reason: string)`, `GetCrew(): {Player}`, `IsCrew(player)` |
| `SetupService` | mechanics A | `Apply(job, heistInfo)` (calls the Setup functions below), `Teardown()`, `GetHeistInfo()`, `GetPlan()` |
| `LootService` | mechanics A | `Spawn(planLoot, heistInfo)`, `Clear()`, `ReturnHome(lootPart)`, `ApplyDamage(lootPart, factor, reason)`, `GetVanTotal()`, `Banked` (Signal: player, lootType, value), `MainLootLifted` (Signal: player) |
| `CarryService` | mechanics A | `HandsFull(player)`, `IsCarrying(player)`, `DropAll(player, reason)` |
| `MovementService` | mechanics A | `Refresh(player)` — call after changing any movement attribute (`Hidden`, `Bubbled`, `Captured`, `Slipping`, `Frozen`, …) |
| `StatsService` | mechanics A | `Event(name, player, data)` (round stats for awards/analytics) |
| `GuardService` | mechanics B | `Spawn(plan, heistInfo, job)`, `Clear()`, `HearNoise(...)` (existing, new `kind`s), `SetLockdown(on)` |
| `CaptureService` | mechanics B | `Reset()`, `AllCaught(players)`, `Release(player)`, `Changed` (Signal: player, stage) |
| `AlarmService` | mechanics B | `Add(reason)` (existing), `LevelChanged` (Signal); tier 3 → calls `RoundService:StartLockdown("alarm")` |
| `HidingService`, `NpcService` | mechanics B | `Reset()`, `Spawn(plan, heistInfo, job)`, `Clear()` |
| `GadgetService`, `LoadoutService` | mechanics C | `ResetRound(crew, job)`; gadgets refuse when `CarryService:HandsFull` |
| `ObjectiveService` | mechanics C | `Setup(plan, heistInfo, job)`, `Clear()`, `GetResults(): {[id]: boolean}` |
| `TutorialService` | mechanics C | `Start(player)`, `IsInTutorial(player)` |
| `MapRuntimeService` | mechanics D | `Setup(level, heistInfo, job)`, `Clear()`; listens to `RoundService.PhaseChanged` and lockdown |
| `MapService` | map B | `Build(heistId)` (exists), `BuildGarage()`, `BuildMiniJob(slot)`, `DestroyMiniJob(slot)`, `CurrentHeist`, `Points` |
| Meta services | meta | `DataService`, `EconomyService:SettleRound(result)`, `ProgressionService:GetPerks(player)`, `LobbyService:GetSelectedJob(boarders)`, `ShopService:GetLoadout(player)`, `AnalyticsTracker` — see `docs/beta-spec-meta.md` |

## Calling meta before it is merged

Mechanics code reaches meta only through **`src/server/Lib/Meta.luau`** (owner: mechanics A). It looks the meta services up
with `FindFirstChild` and returns safe defaults when a service or method is missing (solo job on The Golden Wheel /
Normal, default loadout `{ "Noisemaker", "BubbleBlaster" }`, no perks, settle = no-op + warn). Never `require` a meta
service directly from mechanics code.

## Calling a service another package has not written yet

Use `require` only for services that exist on `main`. For services from a parallel package, look them up at runtime
(`script.Parent:FindFirstChild("GuardService")`) and skip gracefully when absent, so every package compiles and runs on its
own. The orchestrator replaces these lookups with direct requires once everything is merged.

## Shared files

- `Config.luau` / `Tags.luau`: edit only your own block; map tunables per heist go in the heist definition, not Config.
  `Config.World` belongs to map B.
- `Registry.luau`: each map package adds exactly one entry line for its heist.
- `default.project.json`: only ux (ReplicatedFirst) and map B (if needed).
