# Heists (maps) in code

Every heist (map) is built in code by `MapService` (`src/server/Services/MapService.luau`).
This folder is *not* a service: the server bootstrap only loads `src/server/Services/*`.

```
Map/
  Registry.luau          list of all heists + DefaultHeist
  Common/                shared building blocks for every heist
    Builder.luau         blocks, windows, labels, props (with fallbacks), colours, GadgetColors
    CanalHouse.luau      Dutch canal house (background)
    Atmosphere.luau      lighting mood; preset Atmosphere.BlueNight
  Heists/
    GoldenWheel/         heist 1 "The Golden Wheel"
      init.luau          the definition (see below)
      Quay.luau          quay, canal, van with gadget rack
      Shop.luau          shop, security room, courtyard
      Warehouse.luau     ripening hall, cage, cameras, office
```

`MapService:Build("GoldenWheel")` builds a heist in `Workspace.Level`, sets the mood, sets `MapService.Points`
and `MapService.CurrentHeist`, and fires `MapService.LevelBuilt`. `MapService:Build()` without an id rebuilds the
current heist (the first time: `Registry.DefaultHeist`).

## Adding a new heist

1. Create a folder `Heists/<Id>/` with an `init.luau`. Rojo turns that folder into one ModuleScript `<Id>`; the other
   files in the folder become its children (`require(script.Part)`). Shared modules come from
   `script.Parent.Parent.Common` (in `init.luau`) or `script.Parent.Parent.Parent.Common` (in a part).
2. `init.luau` returns a table with:

   | Field | Type | Meaning |
   |---|---|---|
   | `Id` | string | Same as the folder name and the key in `Registry.luau` |
   | `DisplayName` | string | Name shown to players (English) |
   | `Seed` | number | Fixed seed: `Build` gets `Random.new(Seed)`, so every build is identical |
   | `Atmosphere` | `Atmosphere.Settings` | Time of day, light colours, fog, …; empty fields come from `Atmosphere.BlueNight` |
   | `Points.Spawn` | Vector3 | Where players appear and return to after being "caught" (by the van) |
   | `Points.GuardStart` | Vector3 | Where the guard appears |
   | `Points.GuardRoute` | { Vector3 } | Patrol points in order, **at y = 0** (the guard compares its x/z position at y 0) |
   | `Build` | `(level: Folder, rng: Random) -> ()` | Builds everything in `level` |

3. Add it to `Registry.luau` (`<Id> = require(Heists.<Id>)`). If a field is missing or a type is wrong,
   `sh tools/check.sh` reports it in `Registry.luau`.
4. Viewing without a Studio screen: set `HEIST` at the top of `tools/preview/studio_dump.luau` to your id (see `CLAUDE.md`).

### Rules for `Build`

- Build everything under `level` (becomes `Workspace.Level`). MapService throws away the old level on every new build.
- Use `rng` for randomness, not `math.random`, so every build is identical. (Existing exception:
  `Builder.window` picks window glow and curtains with `math.random`.)
- Terrain (water): clear your own area first (`FillBlock` with `Air`) and then fill it, like `Quay.luau`. When
  switching to another heist MapService calls `Terrain:Clear()`; water settings (`WaterColor`, …) you set yourself.
- Props via `Builder.prop` with a `fallback`, so the heist also works if the prop is not in `ServerStorage.Props`.
- The base plate lies at y −12 (below the canal of map 1): build your own floors.
- Level design (see `.claude/agents/map.md`): doors ≥ 5 studs wide, clear height ≥ 8 studs above walkable floors
  (otherwise the guard's pathfinder cannot find the way).

## Tags and attributes the gameplay expects

Names live in `src/shared/Tags.luau`. Without these markers an object does not take part in the game.

| What | On | Tags | Attributes and children | Used by |
|---|---|---|---|---|
| Lamp | BasePart (Neon) with a `PointLight` | `Lamp`, `Electronic` | `Disabled = false` | GadgetService (EMP switches it off and then back on in its own colour), GuardService (inside `PointLight.Range` = lit, you are spotted faster) |
| Security camera | Model | `SecurityCamera`, `Electronic`, `Spottable` | `Disabled = false`, `SpotKind = "camera"`, `BaseLook` (Vector3, resting look direction). Children: `Body` (BasePart that rotates, PrimaryPart) with a SpotLight `Cone`; `Led` (BasePart with attribute `IsLed = true`); other parts with a WeldConstraint to `Body` and `Anchored = false` | CameraService, GadgetService (EMP) |
| Pryable (Crowbar) | BasePart (door, gate) | `Pryable`, `Spottable` | `PrySeconds` (seconds; otherwise `Config.Gadgets.Crowbar.DoorSeconds`), `SpotKind = "lock"`. The door swings open around its edge on the local −Z side: width along the local Z axis | GadgetService (prompt + opening), DevService (`DevPry` by name) |
| Loot (goal) | Invisible BasePart, `CanCollide = false` | `Goal`, `Spottable` | `SpotKind = "loot"` | RoundService (touching = SUCCESS) |
| Gadget pedestal | BasePart | `GadgetPedestal` | `Gadget` = gadget name from `Config.GadgetOrder`; colour from `Builder.GadgetColors` | LoadoutService (prompt to take/put back) |
| Markable | Part or model | `Spottable` | `SpotKind`: `"lock"`, `"loot"`, `"camera"` (the services set `"guard"` and `"drone"` themselves) | PingService, PingController (icon), DroneController (automatically marks cameras on the map) |
| Cover | BasePart (e.g. back wall of a shelf) | — | `Cover = true` | Not read by any service yet; set it on cover anyway |
| Cage / fencing | Folder `Cage` directly in `level` | — | — | GuardService and CameraService see through everything in that folder |

## Note: still hard-coded for map 1 outside this folder

These things are not (yet) in the heist definition; a new heist must have `mechanics` adjust them:

- `RoundService`: during LOCKDOWN "inside" means x 0..60 and |z| < 25 (the ripening hall of map 1).
- `RoundService`: the success message mentions "the Golden Gouda".
- `GuardService`: one guard per heist (at `Points.GuardStart`).
