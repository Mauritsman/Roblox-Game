# Map runtime (mechanics package D)

`MapRuntimeService` gives the map-specific tags their behaviour, so a map package only builds geometry and tags.
`SetupService:Apply` calls `MapRuntimeService:Setup(level, heistInfo, job)` at Briefing and `Clear()` at teardown; in
between the runtime follows `RoundService.PhaseChanged` (Heist, Lockdown, Getaway). Names come from
`src/shared/Tags.luau`, numbers from `Config.MapRuntime` (attributes on your objects override them). Every attribute
is optional unless marked **required**; wrong types are ignored. `tests/map/MapRuntime.spec.luau` checks every heist.

| Module | Tags |
|---|---|
| `Rides.luau` | `Ride` |
| `Rhythm.luau` | `RhythmMachine` |
| `Zones.luau` | `ColdZone`, `GooZone`, `StaffZone`, `SecureZone` |
| `Security.luau` | `LaserGrid`, `LockdownSwitch`, `GuardDoor`, `CellDoor` (motion), `MorningLight`, `RisingPlinth`, `Exit` (arrive/depart) |
| `Effects.luau` | particles and lights for the above |
| `src/client/Controllers/RideController.luau` | smooths cars and the clock beam; turns `Spinner`s |

## Rides (`Ride`)

Build with `Common/Rides.build` (it already follows this contract). A Folder tagged `Ride`:

| Attribute | Meaning |
|---|---|
| `RideId` **required** | key of the path in the heist definition: `Points.Rides[RideId] = { Vector3, … }` (car floor positions) |
| `Seats` | riders or loot per car (default 1) |
| `Speed`, `LockdownSpeed` | studs/s; LOCKDOWN uses `LockdownSpeed` (tag the folder `LockdownSwitch` + `Action = "Speed"` for × 2.5) |
| `Loop` | `true` loop / `false` shuttle; default: a closed path (last point = first) is a loop, an open path a shuttle |
| `Train` | loop cars are coupled: only the front car halts, the train centres on the station |
| `Cars` | number of cars when you give no `Car` models (default 3; a shuttle has 1) |
| `TwoWay` | shuttle can be boarded at both ends |
| `EmptyHands` | riders may only carry pocket loot (Bean Chute) |
| `LockdownOnly` | the whole ride runs only from LOCKDOWN |
| `LockdownPath` | key in `Points.Rides` used from LOCKDOWN (default `<RideId>Lockdown`); it must start on the normal path: cars switch there; an open lockdown path ends in a terminus where cars queue and stay |
| `LootDelay`, `ExitNoise` | shuttle: loot sent alone rolls out `LootDelay` s after leaving, with a "rumble" noise of radius `ExitNoise` (Cheese Chute: 3, 20) |

- **Stations:** Attachments (or parts) named `Station` anywhere in the folder: `Boarding` (default true: board, hop
  off, load loot), `Stop` (STOP window: fast cars slow to `Speed`; riders get `RideStop` = true, guards may grab them
  there), `LockdownOnly`. Keep them ≤ 3 studs from the path.
- **Cars:** Models named `Car` / `Car<n>` (PrimaryPart = body, facing −Z along the path; a `Seat` instance, or a part
  named `Seat` with an Attachment `SeatPoint`). The runtime anchors the PrimaryPart, welds the rest, and moves it by
  CFrame (never physics). Without cars it builds gold boxes.
- **Play:** a car halts `Dwell` s at a Boarding station when a free crew member waits within 12 studs or the car
  carries someone/something. `RidePrompt` ("Ride") seats you; jump to hop off at a station (mid-ride jumps re-seat
  you). Loot **dropped or thrown next to a halted car** is loaded into a free seat and can be grabbed out again.
  Being caught, hiding or freezing takes you off. A shuttle leaves 1 s after boarding/loading, drops riders and
  loot at the far end and returns empty. Character attribute `Riding` = RideId while seated.

## Rhythm machines (`RhythmMachine`)

A part or model with `Kind` **required**, `Period` (s per cycle), `Active` (s of each cycle that are "on"; or a
boolean: `false` = starts switched off), `Radius`, `Offset` (s, to stagger machines), `LockdownPeriod`. Tag it
`LockdownSwitch` too with `Action = "On"`/`"Off"` (switches at LOCKDOWN) or `"Speed"` (period × 0.5 at LOCKDOWN).
Runtime attributes: `Running`, `Pulse` (in its active window). Own ParticleEmitters are switched; otherwise one
phone-friendly emitter is made.

| Kind | Defaults | Behaviour |
|---|---|---|
| `Fountain` | 30 / 4 / 40 | each cycle the nearest patrolling guard within `Radius` walks over to taste for `Active` s |
| `Mixer` | 6 / 2 / 15 | thumps each cycle; for `Active` s a noise within `Radius` is masked: `MapRuntimeService:IsNoiseMasked(pos)` |
| `Wrapper` | 12 / 4 / 4 | during the window an empty-handed crew member within `Radius` is gold-wrapped `WrapSeconds` (8): `Wrapped`, `WrappedUntil`, guards and cameras ignore him; grabbing medium/heavy loot ends it |
| `Mist` | 10 / 4 / 6 | during the window crew inside the machine's parts (or within `Radius`) get `InMist` and are unseen |
| `Steam` | 5 / 2.5 / 5 | MELTDOWN vents: as `Mist`; usually `Action = "On"` |
| `Sprinkler` | always / 8 | while running: running (> 10 studs/s) with medium loot inside → slip, SQUEAK, the loot drops |
| `Clock` | 12 / – / 5 | Tulip clock: a light beam (half-width `Radius`) sweeps from `Center` (Vector3, floor) to an ellipse `RadiusX` × `RadiusZ` once per `Period`; in the beam and in sight of the machine for 0.8 s = spotted (+40 alarm, nearest guards come). Double speed at LOCKDOWN by default |

## Zones

Parts, or models/folders of parts (a `Ball` part counts as a sphere). Read once at setup: zones must not move.

| Tag | Behaviour |
|---|---|
| `ColdZone` | melting loot (loot type `Melts = true`, or a loot model attribute `Melts`) loses 2% of base per second outside every ColdZone once it left its display, never below 50% (`Melting` = true on the model meanwhile). Put one in the van's / barge's cold box |
| `GooZone` | `InGoo`: walk 4, jump 2 (MovementService); a "splosh" noise (radius 15) on entering and every 1.5 s while moving |
| `StaffZone` | entering during a heist puts the mask on (`Masked` = true) |
| `SecureZone` | innermost ring |

Crew characters get `Ring` (`Public` / `Staff` / `Secure`) and `Area` (the zone's `Zone` attribute, else its name);
first entries are round stats (`EnteredStaff`, `EnteredSecure`).

## Security and LOCKDOWN set pieces

| Tag | Attributes | Behaviour |
|---|---|---|
| `LaserGrid` (+ `Electronic`) | beams = parts named `Beam` / `Laser…` (else all parts) | a crew member touching a beam = +40 alarm, the 2 nearest guards come, 3 s rest; EMP (`Disabled`) hides it |
| `LockdownSwitch` `Action = "Close"` | `ClosedCFrame` (+ `OpenCFrame`), `OpenSeconds`; `Group`, `Pick`, `Exclusive` | built open per `Common/Doors.shutter` → drops to `ClosedCFrame` and turns solid. Without `ClosedCFrame`: build it closed; it is hidden until LOCKDOWN (roadblocks) |
| `LockdownSwitch` `Action = "Open"` | `OpenCFrame` or `OpenOffset` (local Vector3), `OpenSeconds` (default 2; Choc-Block 10) | moves there (default: up by its height) and stops colliding; `DoorState` = "Open" when it has one |
| `LockdownSwitch` `Action = "On"` / `"Off"` | lights, sounds, particles, beams inside | off until LOCKDOWN (or on until then); `Active`, `Running` attributes |
| `GuardDoor` | `OpenCFrame` or `OpenOffset`, else slides along its local Z by its width | opens while a guard is within 7 studs, closes 1.5 s later (guards walk through anyway); skipped while `DoorState` = "Open" |
| `CellDoor` | `ClosedCFrame`, `OpenCFrame` | slides open for 2.5 s when the crew is rescued (CaptureService) |
| `MorningLight` | `Step` 1–3 | dark until round end − 3:00 / 2:00 / 1:00 (Tulip 5:00, 6:00, 7:00); step 1 toasts "MORNING AUCTION IN 3:00". Also tag it `Lamp` to count as lit for guards from its step |
| `RisingPlinth` | `RiseHeight` (default 4) | a plinth with the main loot on it starts lower and rises with it (3 s) when the heist starts |
| `Exit` | `LockdownOnly` + `ArrivesAt` (s after LOCKDOWN), `ArriveOffset` (Vector3, default up 60), `DepartOffset` | an arriving exit (Model) waits at the offset and docks exactly at `ArrivesAt` (`Arrived` attribute). When the crew escapes, the exit they sit in leaves with them: `DepartOffset`, else a `Balloon` rises 60 and a `Boat` sails 50 along its look direction; vans stay. Usability (`QuietOnly`, `LockdownOnly`, `ArrivesAt`) is RoundService's |

`Spinner` (map block): a Model/part that turns once per `SpinSeconds` around `SpinAxis` (local) on every client.

## For other packages

- `MapRuntimeService:IsNoiseMasked(position)` — check before `GuardService:HearNoise` for a CRACK.
- `MapRuntimeService:RideOf(player)`, `:RingOf(player)`, `:InColdZone(position)`.
- Character attributes guards may read: `InMist` / `Wrapped` (already ignored through `ImmuneUntil`), `Riding`,
  `RideStop` (a rider outside a STOP window could be made un-grabbable).
