# Heists (maps) in code

Every heist (map) is built in code by `MapService` (`src/server/Services/MapService.luau`).
This folder is *not* a service: the server bootstrap only loads `src/server/Services/*`.

```
Map/
  Registry.luau          list of all heists + DefaultHeist (and the Heist definition type)
  Common/                shared building blocks for every heist
    Builder.luau         blocks, windows (rng), far windows, signs, labels, props (with fallbacks), colours
    CanalHouse.luau      Dutch canal house; detail = "far" for background rows (1 block per window, no lights)
    CanalStreet.luau     a canal street (canal, quay, lanterns, far bank, bridges) at any origin; Terrain or part water
    Doors.luau           door leaves, Pryable, entrances with LockedBlocker, roller doors, keycard gate, shutters
    Security.luau        security cameras with ceiling / wall / pole mounts (SecurityCamera contract)
    Anchors.luau         loot anchors, hide spots, exits + bank zones, zone volumes, hazards, point anchors
    Rides.luau           ride track, cars and stations (Ride contract)
    Atmosphere.luau      lighting mood; preset Atmosphere.BlueNight
  Heists/
    GoldenWheel/         heist 1 "The Golden Wheel" (beta-spec-maps §6)
      init.luau          the definition (see below)
      Layout.luau        shared coordinates (spawn, van, chute path, floor heights)
      Quay.luau          canal street, our house rows, neighbour blocks, van exit, spawn
      Shop.luau          shop + closet stairwell, security room + holding cell, courtyard, Golden Wheel landmark
      Warehouse.luau     ripening hall, cage, office (keycard gate, safe, Cheese Chute), dock, fire exit, cameras
      Grounds.luau       the ring: Back Lane, Back Yard + cellar trench, basin + jetty + boat exit, alleys
      Cellar.luau        cold cellar
      Markers.luau       loot anchors, hide spots, hazards, zone volumes, Karel's home
```

`MapService:Build("GoldenWheel")` builds a heist in `Workspace.Level`, sets the mood, sets `MapService.Points`
and `MapService.CurrentHeist`, and fires `MapService.LevelBuilt`. `MapService:Build()` without an id rebuilds the
current heist (the first time: `Registry.DefaultHeist`).

## Adding a new heist

1. Create a folder `Heists/<Id>/` with an `init.luau`. Rojo turns that folder into one ModuleScript `<Id>`; the other
   files in the folder become its children (`require(script.Part)`). Shared modules come from
   `script.Parent.Parent.Common` (in `init.luau`) or `script.Parent.Parent.Parent.Common` (in a part).
2. `init.luau` returns a table with the fields of `Registry.Heist` (`Registry.luau` documents each one):
   `Id`, `DisplayName`, `Seed`, `Atmosphere`, `Points` (`Spawn`, `GuardRoutes`, `KarelRoute`, `DogRoute`, `Rides`,
   plus the prototype fallback `GuardStart` / `GuardRoute`), `Build`, and the beta fields `Rank`, `Description`,
   `GuardBonus`, `HasDog`, `ExtraNpcs`, `Loot`, `Stars`, `Bounds`, `LoudEscape`, `Objectives`.
3. Add it to `Registry.luau` (`<Id> = require(Heists.<Id>)`). If a field is missing or a type is wrong,
   `sh tools/check.sh` reports it in `Registry.luau`.
4. Test it without Studio: copy `tests/map/GoldenWheel.spec.luau` (see "Testing" below).

### Rules for `Build`

- Build everything under `level` (becomes `Workspace.Level`). MapService throws away the old level on every new build.
- Use `rng` for all randomness, never `math.random` (the test harness fails on it), so every build is identical.
  `Builder.window`/`Builder.farWindow` take the rng; without one they seed from the window's position.
- Terrain (water): clear your own area first (`FillBlock` with `Air`) and then fill it, like `CanalStreet` and
  `GoldenWheel/Grounds`. Set the heist's `Bounds` to cover it.
- Props via `Builder.prop` with a `fallback`, so the heist also works if the prop is not in `ServerStorage.Props`.
- The base plate lies at y −12 (below the canal of map 1): build your own floors.
- Level design (beta-spec-maps §2): doors 6 × 9 on loot routes (never under 5 × 8), ≥ 8 studs of clear height above
  walkable floors, guard legs straight and clear, signs per the sign rules (`Builder.sign` with `viewFrom`).
- Budgets per heist: ≤ 4,800 parts (Golden Wheel), ≤ 40 lights, ≤ 9 with shadows. No SurfaceLights on windows.

## Tags and attributes the gameplay expects

The full list is `docs/contracts.md` (§2.5 map-placed attributes, §3 tags); names live in `src/shared/Tags.luau`.
The Common modules set them for you:

| What | Built by | Contract (short) |
|---|---|---|
| Loot anchor | `Anchors.loot` | Invisible point part in `Level.Anchors`, tag `LootAnchor`; `AnchorClass`, `AnchorId`, `Zone`, `Group?`, `Fixed?`, `Opener?` |
| Hide spot | `Anchors.hide` | Model, tag `HideSpot`, `HideKind`; PrimaryPart `Root` with Attachments `Inside`, `Exit` |
| Exit | `Anchors.exit` | Model, tag `Exit`, `ExitKind`, `Optional?`, …; children `BankZone` (tag, `Session`) and `DrivePoint`; the vehicle goes inside |
| Zones | `Anchors.volume` | Invisible boxes: `StaffZone`, `SecureZone`, `DogZone`, `ColdZone`, … |
| Hazard / point anchors | `Anchors.hazard`, `Anchors.point` | `HazardAnchor` (+ `AnchorId`), `KarelHome`, `CellSpot`, `CellDropoff`, `CellExit`, `CellGrate`, … |
| Entrance | `Doors.entrance` | Model, tag `Entrance`, `EntranceId`, child `LockedBlocker` (built solid = locked); put its doors inside |
| Pryable door | `Doors.leaf` + `Doors.pryable` | Tags `Pryable`, `Spottable`; `PrySeconds`, `SpotKind = "lock"`, `DoorState`, `ClosedCFrame`, `LoudOnly?`. Swings 100° into its local +X side around its local −Z edge |
| Keycard gate | `Doors.keycardGate` | Model, tag `KeycardDoor`, `Card`; child `Door` (`ClosedCFrame`, `OpenCFrame`) |
| Shutter | `Doors.shutter` | Tag `LockdownSwitch`, `Action`; built open (`OpenCFrame`), mechanics move it to `ClosedCFrame` |
| Security camera | `Security.camera` | Model, tags `SecurityCamera`, `Electronic`, `Spottable`; `Disabled`, `SpotKind`, `BaseLook`; `Body` (PrimaryPart) with SpotLight `Cone` (no shadows), `Led` (`IsLed`), parts welded to `Body`, anchored `Mount*` bracket |
| Ride | `Rides.build` | Folder, tag `Ride`, `RideId`, `Seats`, `Speed`, `LockdownSpeed?`; Attachments `Station` (`Boarding`, `Stop`, `LockdownOnly?`); cars `Car<n>`; nothing collides; path → `Points.Rides[RideId]` |
| Lamp | heist code | BasePart (Neon) with a `PointLight`, tags `Lamp`, `Electronic`, `Disabled = false` |
| See-through | heist code | Tag `SeeThrough` on cage mesh and cell bars (the old `Cage` folder rule stays as a fallback) |
| Landmark | heist code | Model tagged `Spinner` (`SpinSeconds`, `SpinAxis`): a client turns it |
| Sign | `Builder.sign` | Part `Sign` with SurfaceGui `SignText`; attribute `ViewFrom` for the readability test |

## Testing without Studio

`tests/map/MapHarness.luau` builds a heist in Lune with the real Roblox datatypes and instances of `@lune/roblox`
(property names and types are checked like in Roblox; props are missing, so every fallback is used; `math.random`
is blocked). `tests/map/GoldenWheel.spec.luau` runs with `sh tools/check.sh` and checks anchor counts, every
contract above, budgets, sign rules (rays from `ViewFrom`), a RoundPlan over the real level, and walkability with
any two open entrances (a rough grid stand-in for pathfinding: necessary, not sufficient).

- `lune run tests/map/report GoldenWheel` — parts per folder, lights, anchors per class, tag counts.
- `lune run tests/map/walkmap GoldenWheel [floorY] [radius] [startX startZ]` — ASCII walk map of one floor.

## Note: still hard-coded for map 1 outside this folder

- `RoundService` (prototype): "inside" during LOCKDOWN is the hall box, and success needs the old `Goal` part, which
  the beta retrofit removed (mechanics replace both with loot and exits).
- `LoadoutService` (prototype) reads `GadgetPedestal`s, which are gone from map 1 (meta's Garage rack replaces them).
