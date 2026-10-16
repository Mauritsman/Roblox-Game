# Crowbar Crew: beta specification (maps)

*Map agent, 16 Oct 2026. Level design for the Garage, the mini-job and the three heists. Binding inputs:
`docs/research/advisor-maps.md` (rings, loops, 4-beat escalation, lockdown maps), `advisor-brief.md`,
`advisor-notoriety.md`. Contract names follow `beta-spec.md` (mechanics) and `beta-spec-meta.md`.
**(proposed)** = my decision, open for the orchestrator.*

*Coordinates are (x, y, z) in studs. Ground floors are at y 0–0.3; upper floors at y 9–9.5.
**North = −X** (the van side) on every map.*

## 1. World model

| Area | Origin | Built |
|---|---|---|
| Heist | World origin | `MapService:Build(heistId)` at Briefing; replaces the previous heist (`workspace.Level`) |
| Garage | `Config.World.GarageOrigin` = (2000, 0, 0) | `BuildGarage()` once in `Init` → `workspace.Garage`, never destroyed. This doc gives **local** coordinates |
| Mini-job slots | `Config.World.MiniJobOrigins` = {(0, 0, 2000), (0, 0, −2000)} (proposed) | `BuildMiniJob(slot)` / `DestroyMiniJob(slot)`; the module takes an origin CFrame |

- **Why the origin:** map 1, the routes and the tests already use it, and only one heist exists at a time.
- **Spacing:** areas are ≥ 2,000 studs apart, so with `StreamingEnabled` a phone holds one area at a time.
- **Terrain:** only the heists use Terrain water, and `MapService` clears just the previous heist's `Bounds` (no
  `Terrain:Clear()`). The Garage and the mini-job use **part water** (SmoothPlastic (28, 54, 62), Transparency 0.15,
  top at y −3, invisible edge barrier).
- **Lighting is global**, but a mini-job runs while the crew is in a heist. **(proposed)** The presets become data in
  `ReplicatedStorage.Shared.Atmospheres`, and a client controller (ux) applies the preset of the player's area. Under
  its bridge, the Garage reads well under any preset.
- **Heist definition fields** (`beta-spec.md` §9.7, plus mine):
  - Theirs: `Rank`, `GuardBonus`, `HasDog`, `ExtraNpcs`, `Loot`, `Stars`, `Bounds`, `Points.Spawn`,
    `Points.GuardRoutes`, `Points.KarelRoute`, `Points.DogRoute`.
  - Mine: `Points.Rides` (§3), and route points that may carry y 9 for upper floors (GuardService still compares x/z;
    guards spawn on the floor under their first point).
- **Anchors** go under `Level.Anchors`: invisible anchored parts with `CanCollide`, `CanQuery` and `CanTouch` false.
  A point anchor's CFrame is the item's bottom centre, facing −Z.

## 2. Rules (advisor checklist + engine limits)

Every heist passes the `advisor-maps.md` checklist:
- 3 visible rings: Public → Staff (yellow-striped floor) → Secure (red light + keycard reader on its doors).
- ≥ 4 randomisable entries into Staff (watched, noisy, quiet hatch), 2 locked per round, plus 1 loud-only shortcut.
- No dead-end rooms (hiding nooks excepted), and ≥ 2 chase loops of 40–80 studs.
- Indoor sightlines ≤ 35 studs, and cover every ≤ 12 studs at two heights (crouch and standing).
- Guard loops ≤ 25 s, i.e. ≤ 150 studs at patrol speed 6, with no overlap between routes.
- Max 2 floors (upper ≤ 10), ≥ 2 links between them, no jumps.
- Loot value rises with depth: ≥ 4 small items in Public; heavy loot ≥ 60 studs from an exit with 2 haul routes; main
  loot on 1 of 3 Secure spots, each with 2 exits.
- One landmark, 1–2 secrets (`LootAnchor` `Group = "Secret"`, value 150–500), and the visual language "orange =
  usable, glow = loot".
- Rides and machines move along fixed server paths, never free physics.

Engine and phone rules:
1. Doors are 6 × 9 on loot routes, never under 5 × 8 clear. Roller doors are 8 wide. Nothing stands in a swing arc.
2. Clear height ≥ 8 above every walkable floor (pathfinding uses 4-stud voxels).
3. **Lanes:** each map names corridors ≥ 6 wide that stay free of props, loot, hide spots and carts. Guard legs are
   straight (`MoveTo`) and stay ≥ 2.5 studs from obstacles. The builder may move an anchor ±2 studs to keep this, and
   a Studio test raycasts every leg.
4. Thresholds ≤ 0.3; ramps ≤ 20° where heavy loot travels. Map edges get invisible walls ≥ 14 tall, and fences meant
   to stop players are ≥ 8 tall (jump height is 7.2).
5. Hide spots enclose a standing character (≥ 5.5 tall), so the new `TallCask`, `Dumpster` and `Locker` replace the
   2.4-tall `Barrel`. Every loot cluster has a hide spot within 15 studs.
6. **First loot within 45 s:** ≥ 2 `LootAnchor`s per heist get `Opener = true` (proposed): Public, ≤ 40 studs from the
   spawn, and `RoundPlan` always fills one.
7. **Van to the furthest main-loot spot:** measured at crouch speed (8), including door times. Maps 2–3 ≈ 20–25 s;
   map 1 ≈ 15 s (it is the learning map). See §12 Q1.

**Sign rules** (`Builder.sign`). Each sign carries a `ViewFrom` attribute for the test.
- Board height ≥ viewing distance ÷ 12, and width ≈ 0.55 × characters × height.
- Mounted 0.2 studs proud of a wall face or on a beam; ≥ 0.5 studs clear in front.
- Nothing between `ViewFrom` and the board: no awnings, lintels, beams, lamps or door swings.
- Bottom edge ≥ 8.5 where people pass underneath; ALL CAPS, ≤ 16 characters per line, ≤ 2 lines.
- **New tester test:** rays from `ViewFrom` to the 4 corners and the centre must all hit the board.

## 3. Anchor names

**From mechanics, used as-is:** `LootAnchor` (`AnchorClass`, `AnchorId`, `Zone`, `Group`, `Fixed`), `Entrance`
(`EntranceId`, child `LockedBlocker`), `Exit` (`ExitKind`, `Optional`, children `BankZone` + `DrivePoint`), `HideSpot`
(`HideKind`; attachments `Inside` and `Exit`), the `Cell` folder (`CellSpot` ×4, `CellDoor`, `CellDropoff`,
`CellExit`, `CellGrate`), `DogZone`, `KarelHome`, `HazardAnchor` (10 per heist), `GarageVan`, `TutorialTrigger`
(`Step`), `KeycardDoor` (`Card`), `Safe` (`DeviceSpot`).

**From meta:** `JobBoard`, `GadgetRack`, `Workbench`, `Mirror`, `TrophyWall` + 12 `TrophySlot`, `CollectionBook`,
`VanPaint`, `GarageZone`.

**From the advisor:** `LockdownSwitch` (`Action` = `Close` / `Open` / `Speed` / `On`), and the `Exit` attributes
`QuietOnly`, `LockdownOnly`, `ArrivesAt`.

**Kept:** `Lamp`, `Electronic`, `SecurityCamera`, `Pryable`, `Spottable`, folder `Cage`. A pryable can carry
`LoudOnly`.

**New, proposed by map:**

| Name | On | Attributes | Purpose |
|---|---|---|---|
| `Opener` | `LootAnchor` attr | bool | 45 s rule |
| `StaffZone` / `SecureZone` | volume parts | — | Mask Up (staff); job card and analytics |
| `Ride` | folder per ride | `RideId`; `Seats` (riders or loot per car); `Speed` (+ `LockdownSpeed`); `Points.Rides[RideId]` = path; child attachments `Station` (`Boarding` bool, `Stop` = STOP window, `LockdownOnly`) | Praline Box Rail, Tulip trolley train, Cheese Chute, Bean Chute, Greenhouse Vent: welded seats moved by the server |
| `ColdZone` | volume part | — | Praline: chocolate stops melting |
| `RhythmMachine` | model | `Kind` (`Fountain` / `Mixer` / `Wrapper` / `Mist` / `Clock`), `Period`, `Active`, `Radius` | Rhythm hazards |
| `GooZone` | volume part | — | Chocolate river: walk 4, noise "SPLOSH" 15 |
| `LaserGrid` | model (+ `Electronic`) | — | Tulip vitrine: a touch = +40 alarm; EMP disables it 10 s |
| `MorningLight` | lamp | `Step` (1–3) | Tulip 5:00 event |
| `RisingPlinth` | model | `RiseHeight` | Main loot rises when the round starts |
| `PracticeTarget`, `GarageTV`, `TrophyBoard` | parts | — | Garage |
| `Cell` bars | — | — | Need the same see-through rule as `Cage` (mechanics) |

## 4. The Garage (permanent hideout)

An old brick viaduct over a canal, with the crew's workshop in three arches: warm work lamps and crew orange.

```
local, +(2000,0,0)  z: -50  -38 -34      -14 -10        10 14        34 38            64
x -56..-36  ~~~~~~~~~~~~~~~~~~~~~~~~ CANAL (part water) ~~~~~~~~~~~~~~~~~~~~~~~~
x -36..-20  FORECOURT: cobbles, canal lamps, oil drums                          | fence
x -20       |pier| front+door |pier| ROLLER DOOR (open)  |pier| front+door |pier|
x -20..20   |    | WORKSHOP   | <> | VAN BAY             | <> | LOUNGE     | D  | PRACTICE YARD
            |    | rack,bench,|    | van ▸ zone ▸ spawn   |    | trophies,  |    | line, baskets,
            |    | mirror     |    | JOB BOARD (+X wall)  |    | TV, book   |    | ramp, old van
x 20        +------------------------- back wall ----------------------------+
<> = 6-wide arched passage, x -2..4      D = yard door, x -14..-8
```

| Element | Local position | Detail |
|---|---|---|
| Viaduct | x −20..20, z −50..70; arch crown y 16, deck y 24 | Piers 4 thick at z −38..−34, −14..−10, 10..14, 34..38; interior clear height ≥ 12 |
| Van | Prop at (−9.5, 0, 0), nose toward the roller door (−X), rear doors at x −3 | `VanPaint` body parts |
| `GarageVan` | x −3..9, z −6..6, y 0..8 | `DrivePoint` (−18, 0, 0); orange floor chevrons |
| Job board | Back wall x 19.6, z −5..5, y 3.5..9.5, faces −X | `JobBoard` |
| Spawn / arrival | `SpawnLocation` (12, 0.3, 0) facing +X (board 8 studs ahead); crew back from a job at (−8/−12, 0.3, ±8) | Outside the van zone |
| Gadget rack | Workshop back wall, z −32..−22 | `GadgetRack`; 4 coloured display pedestals; Crowbar on a hook |
| Workbench | x 14..19, z −20.5..−17.5 | `Workbench` (perks) |
| Mirror | (−8, 0.2, −33.4) facing +Z; rug pad at (−8, 0.2, −29) | `Mirror` |
| Trophy wall | Lounge back wall, z 17..31, y 2..10 | `TrophyWall`; 3 shelves × 4 `TrophySlot` |
| Most Goudas board | Pier face z 14, x 10..16, y 3..7, faces +Z | `TrophyBoard`; meta writes the text |
| Book / TV / sofa | Lectern (−12, 0.2, 18) · `CrtTv` (0, 0.2, 32.8) facing −Z · `Sofa` (0, 0.2, 24) | `CollectionBook`, `GarageTV` (WATCH) |
| Practice yard | x −20..20, z 38..64, fence 12 high | See below |
| `GarageZone` | x −36..20, z −50..64 | Meta, funnel step 8 |

**Practice yard contents:**
- Throw line at x −10, running z 42..62.
- `PracticeTarget` baskets at 6, 8 and 10 studs from the line: (−4, 0, 46), (−2, 0, 52), (0, 0, 58).
- 2 wheel `LootAnchor`s (`Fixed`, `Session = Practice`) at (−14, 0.2, 50/54).
- A Big Wheel anchor on a 2-high ramp at x 6..16, z 42..46, for practising rolls.
- The rusty old van (10, 0, 59), whose practice `BankZone` banks nothing.
- 2 `TallCask` hide spots at (18, 0, 50/54) and a `CardboardGuard` at (4, 0, 50).

**How the van starts a job:**
1. Standing in `GarageVan` starts mechanics' countdown.
2. Briefing calls `MapService:Build`, and the screen fades.
3. The server streams around the heist van, then `PivotTo`s the crew to `Points.Spawn`.
4. After the payout the crew lands on the arrival points. A late joiner uses the same zone for JUMP IN.

## 5. Mini-job: "Corner Cheese"

**Decision:** its own tiny map. It runs in parallel slots while the crew uses the heist at the origin, it loads fast
(≤ 1,500 parts), and it is linear. Built from `Common/CanalStreet` + `CanalHouse`, so it looks like Polderdam.
- Playable area ±42 × 36 (local).
- No capture, gadgets, Karel, Boef or cameras (mechanics).
- The guard follows at 10 studs/s in lockdown and never catches (advisor).

```
          z: -22      -10       4..10     10   16        22
x -46..-34  ~~~~~~~~~~~~~~ CANAL (part water) ~~~~~~~~~~~~~
x -34..-12  QUAY   [VAN -26,-10]  ▸ spawn    MARKET STALL (-20,4)
x -12       houses | CORNER CHEESE  front door z 4..10 (sleeping guard -14.5,2) | houses
x -12..8           | counter (cubes, drawer) · display wheel · GOUDA pedestal (4,0)
x   8              +------------- side door x 0..6 in the z 10 wall --------------+
                     ALLEY z 10..16 → quay   (TallCask at -8, 14.5)
```

| ux step | Where | Anchor |
|---|---|---|
| Spawn | (−21, 0.3, −12), facing the stall | `Points.Spawn`; van `Exit` at (−26, 0, −10), rear `BankZone` facing +Z |
| "Grab the cheese" | Stall counter (−20, 2.6, 4): 15 studs away | Medium `Fixed` `Opener` |
| "Sneak past the guard" | Guard on a chair at (−14.5, 0.3, 2), 5 studs from the door's centre line | Point anchor `SleepingGuard`; `TutorialTrigger` Step 5 at x −11..−8, z 4..10 |
| "Pocket the small cheese" | Counter along x −4, z −8..0 | 4 × Small `Fixed` |
| Extra / Gouda | Display table (−6, 0.2, 6); pedestal (4, 0.2, 0) with a crown beacon | Medium / Main `Fixed` (Gouda × 0.6) |
| "Roll it to the van" | Back past the guard (37 studs), or side door → alley → quay (52). Both 6 wide and flat | — |

Backdrop: far-bank house row, our rows at x −12 (z −40..−10 and 16..40), a bridge, road barriers at z ±22.

## 6. The Golden Wheel (map 1): retrofit

Keep today's layout and art: canal x −72..−54, quay x −54..−22, shop A (x −22..0, z −40..−14), security room B
(z −14..4), courtyard C (z 4..40), hall D (x 0..60, |z| ≤ 25), mezzanine office E (x 0..18, z 11..25, y 9.2).
The beats stay simple (timer + chase to the van); the boat is the 50% second exit. The retrofit follows the advisor's
order.

```
          z: -58  -47 -41    -26     -14       4          25/26  40.6 47
x -72..-54   ~~~~~~~~~~~~~~~~~~~~~~ CANAL ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
x -54..-22   QUAY (public)        [VAN -40,4]   handcart         ⟲ wheel on the shop roof
x -22        houses |=E3=|====shop door====|=barred=|====E2======|=E4=| houses
x -22..0            |LANE| A SHOP (public)  | B SEC  | C COURTYARD |ALLEY|
                    |    | ▼closet stair    | +CELL  | Boef  ⟍chute|  ↕  |
 (below the shop:   COLD CELLAR x -22..0, z -46..-20, y -10)            |
x 0                 |    +--E1 staff door--+-open---+--back door--+-gap-+
x 0..60      |BASIN| BACK YARD ▼cellar ramp| D HALL: racks with gaps, cage (2 doors) | BACK ALLEY |
             |~boat| jetty                 | office (keycard gate) ── Fire Exit ▲    |            |
x 60..67     DOCK APRON (ring) — Loading Dock door x 60, z 12..20
```

| # | Change | Coordinates |
|---|---|---|
| 1 | **Close the ring** around the hall | Back Lane x −22..0, z −47..−40.6 · Back Yard x 0..67, z −47..−26 · Dock Apron x 61..67, z −47..47 · Back Alley x 0..67, z 26..47 · Bin Alley x −22..0, z 40.6..47 · 6-wide gap in the courtyard's east wall at z 27..33. **Loading Dock** roller door in the hall's east wall at x 60, z 12..20, `Pryable` 3 (move those crates beside the forklift). Neighbours move: south house row ends at z −47 with depth 22, north row starts at z 47 with depth 22, warehouse to x 67..115, blocks to z ≤ −58 and z ≥ 47 |
| 1 | Loading Basin | Terrain water x 0..67, z −58..−47; jetty x 38..44, z −52..−47, deck y −0.6 |
| 1 | **Second cage door** | Cage's south side, z −6, x 52..57, `Pryable` 3 |
| 2 | **Break up the hall** | Each rack becomes 3 sections (x 10..16.5, 22.5..29, 35..41.5) with 6-wide cross-aisles. Hall cameras hang from the trusses (no floor poles) |
| 3 | **Office = Secure** | Widen the stair to z 18.6..24.6; a 6-wide `KeycardDoor` (`Card = "Office"`) gate at its foot (x 30.5) with a reader and a red lamp |
| 3 | **Cold cellar (Secure)** | x −22..0, z −46..−20, floor y −10, ceiling y −0.5 (cut `GroundEast` around it). Exit 1: a 6-wide ramp trench from the Back Yard, x 0..28, z −40..−34 (y 0 → −10, 19.6°, rails), to the cellar door at x 0 (`Pryable` 3, red light). Exit 2: Karel's closet becomes the stairwell (x −6.5..−0.6, z −40..−26, invisible ramp; closet door z −26, x −6..−1, `Pryable` 1.5, red light). Inside: aging racks, a cheese press, frost-blue light |
| 4 | **Cheese Chute** (ride) | Office west wall opening x −1..0, z 21..24, y 9.2..13 → 2.5 s ride → courtyard (−5, 0.15, 30). Heavy loot sent alone rumbles out after 3 s (noise 20); Boef chases it. The office is no longer a dead end |
| 5 | **Landmark** | Golden Wheel, Ø 10, gold neon rim, on a mast on the shop roof at (−8, 30–40, −27); turns once per 10 s (client) |
| — | Fixes | Shop doorway gets a real door, on the latch (shop = Public). Courtyard barrel at (0.6, 0.15, 8) clips the hall wall: move it. `Builder.window` → `rng`. Camera cones `Shadows = false`. `Builder.boat` gets a rotation parameter. Delete the quay gadget rack and the `Goal` part (mechanics deletes the hard-coded "inside" box) |

**Rings.**
- **Public:** the quay and the shop floor.
- **Staff:** everything behind the four entrances.
- **Secure:** the cage, the office and the cellar.

**Entrances** (each has a `LockedBlocker`: planks + chain + CLOSED board facing the approach):
- **E1 Staff Door** (shop → hall, `Pryable` 1.5): watched by the shop camera.
- **E2 Delivery Gate** (padlock 3 s): noisy.
- **E3 Back Lane gate** (unlocked): quiet → Back Yard.
- **E4 Bin Alley gate** (unlocked): quiet → Back Alley.
- **Loud-only shortcut:** the **Fire Exit** (hall north wall, x 50..56, push bar, `LoudOnly`) → Back Alley.

Each entrance alone reaches the hall (through the back door, the dock door or the staff door).

**Loops:** hall ↔ courtyard ↔ Back Alley (≈ 70 studs); hall ↔ Dock Apron ↔ Back Yard (≈ 80); the hall's
cross-aisles. **Exits:** van; boat (`Optional`, 50%) at the jetty.

**Anchors (map 1)** (mechanics minimum: Small 12, Medium 12, Heavy 4, Main 3):

| Kind | Anchors |
|---|---|
| Main ×3 | G1 cage plinth (55, 1.6, 0) · G2 office strongroom shelf (6, 9.2, 22): keycard; roll it down the stair ramp or send it down the chute · G3 cellar press table (−16, −9.8, −40) |
| Heavy ×4 (Big Wheel, hall) | (25.5, 0.2, −14) · (25.5, 0.2, 16.5) · (46, 0.2, −12) · (8, 0.2, −22) |
| Medium ×12 | Rack sections, aisle side: (13, 0.8, ±8.25), (26, 3.5, ±8.25), (38, 0.8, ±8.25) · courtyard (−10, 0.7, 8), (−17, 0.2, 24) · Back Yard cart (20, 1.4, −44) · Back Alley crate (30, 4, 44) · cellar racks (−18, −7, −28), (−10, −9.8, −24) |
| Small ×14 | **Public:** shop window stand (−20.6, 2.2, −33) `Opener`, counter (−10.5, 3.9, −34), register (−10.5, 5, −29.3) `Group = "Drawer"`, shelf (−5, 4.5, −38.7), quay bench (−49, 1.9, 33) `Opener` · **Staff:** security desk (−7, 3.4, 2.4), packing table (40, 3, −23.4), crate top (57, 8.2, −14), forklift seat (54.5, 3, −19), courtyard crate (−18, 8.15, 36) · **Secure:** office desk (8, 12, 22.6) `Drawer`, filing cabinet (2.2, 14, 13.7), cellar shelf (−21, −7, −36). Plus the quay handcart medium (−30, 2.4, −12) `Opener` |
| Secrets ×2 | Karel's cheese stash under the cellar stair (−3, −9.8, −38), 300 · Boef's buried treasure in the kennel (−4, 0.15, 35), 200 (Boef must be away) |
| Keycard ×5 | Security desk (−5, 3.4, 2.4) · shop counter (−11, 3.9, −31) · packing table (42, 3, −23.6) · Back Alley dumpster lid (20, 5.6, 45) · Back Yard oil drum (8, 3.4, −44) |
| Safe | Office safe (x 1..4, z 21.5..24.5), `DeviceSpot` (2.5, 9.2, 20.5), 2 anchors `Group = "OfficeSafe"` |
| Hide ×12 | Courtyard `TallCask` (−6.5, 0.15, 7), (−19.5, 0.15, 6.5) · hall `TallCask` (42, 0.2, 23), (48, 0.2, −23) · hall big crate (58, 0.2, 23) · shop `Locker` (cheese cabinet) (−3, 0.2, −16) · office `Locker` (16, 9.2, 23) · cellar `TallCask` (−20, −10, −44) · Back Yard `Dumpster` (4, 0, −45) · Back Alley `Dumpster` (20, 0, 45), (50, 0, 45) · `TallCask` at the apron's north end (64, 0, 44) |
| Cell | B's west half, x −21.4..−12, z −13.4..−4: bars on x −12 and z −4, 10 high with a top rail · sliding `CellDoor` x −12, z −10.5..−5.5 · `CellSpot`s (−19/−15, 0.2, −11/−7) · `CellDropoff` (−9.5, 0.2, −8) · `CellExit` (−8, 0.2, −10) · `CellGrate` = drain on the quay (−32, 0, −22), 18 studs away. The desk moves to the north wall; the lamp to (−6, 12, −5) |
| Boef / Karel | `DogZone` = courtyard x −21..−1, z 5..39 (dog-only barriers at the gate and the gap) · `DogRoute` (−5,12) (−19,14) (−10,28) (−4,29) · `KarelHome` (−3.5, 0.2, −24) · `KarelRoute` (−3,−20) (6,−20) (6,0) (−6,−2) (6,0) (6,17) (−6,17) (6,17) (6,13) (44,13) (44,−17) (6,−17) (6,−20) (−3,−20) |
| Exits | Van `Exit` at (−40, 0, 4), rear facing +Z, `BankZone` 10 × 8 × 8 at (−40, 4, 13), `Points.Spawn` (−40, 3, 16) · Boat (`Optional`) along the jetty at (47.5, −2.6, −51.5), `BankZone` x 39..47, z −56..−48 |
| Cameras ×6 | Hall N/S (as today, hung from the trusses) · shop (−20.5, 11, −15.5) → (−10, 0, −30) · yard (−1.5, 9, 5) → (−18, 0, 20) · cellar (−2, −2, −22) → (−16, −10, −36) · Dock Apron (61.5, 9, −45) → (64, 0, 0) |
| Hazards ×10 | (−14,0.2,−24) (−6,0.2,−20) (8,0.2,0) (26,0.2,−14) (26,0.2,14) (40,0.2,0) (−6,0.2,−8) (−10,0.15,15) (24,0,−30) (−11,−10,−30) |

**Guard routes** (points (x, z); ≤ 25 s each):

| Route | P | V1 | V2 |
|---|---|---|---|
| Hall West | 1 | (6,−18) (19.5,−18) (19.5,16) (6,16) | (4,−2) (19.5,−2) (19.5,−18) (4,−18) |
| Hall East | 1 | (32,−18) (47,−18) (47,16) (32,16) | (32,−4) (47,−4) (47,16) (32,16) |
| Shop | 2 | (−3,−20) (−13,−20) | (−3,−25.5) (−13,−25.5) |
| Courtyard | 2 | (−4,16) (−17,11) (−17,19) (−4,19) | (−4,17) (−14,27) |
| Back Alley | 3 | (6,30) (58,30) | (6,40) (58,40) |
| Dock Apron | 3 | (64,−44) (64,8) | (64,−8) (64,36) |
| Back Yard | 3 | (6,−30) (58,−30) | (32,−44) (58,−44) |

Solo = the two hall guards on short loops (advisor). Four players = + Shop and Courtyard.

## 7. Praline Palace (map 2, pressure)

A Belgian chocolaterie on a Flemish street; the canal loading dock is at the back.
- **New pressure:** rhythm machines, a river of molten chocolate, and **melting loot** (chocolate loses 2%/s outside a
  `ColdZone`, min 50%).
- **Loot:** ±5,500. Main loot: Golden Praline (2,200, heavy, rolls, melts). Heavy: Praline Tower (fragile, −25% per
  drop, cannot roll).
- **Guards:** 5 at four players.
- **Footprint:** x −62..62, z −48..48.

```
            z: -48   -40       -24            0             24   32     48
x -62..-40  STREET (public): Flemish façades · [VAN -50,-20] · roadblock spot
x -40       |E2 yard gate|   shop doors (z -3..3)              | SOUTH LANE (public) →
x -40..-22  | COCOA YARD | PRALINE SHOP (public): counters, tasting bar |
x -22..4    |  (staff)   | WEST BAY: fountain · wrapper · Dispatch station · ramp ↗ W gallery (office)
x  4..10    |            | ~~~ CHOCOLATE RIVER ~~~ N-bridge · catwalk (y 9) · rail bridge · S-bridge
x 10..44    |            | EAST BAY: VAULT (keycard) · Big Mixer · COLD ROOM · packing · E gallery
x 44..54    DOCK APRON (staff) ← E4 dock gate at the lane end        ◉ cocoa chimney (landmark)
x 54..72    ~~~ CANAL ~~~  barge "The Sweet Getaway" (lockdown exit)
```

**Zones and rings.**
- **Public:** street x −62..−40; shop x −40..−22, z −24..24 (doors at x −40, z −3..3); South Lane x −40..44, z 24..32.
- **Staff:**
  - Cocoa Yard: x −40..−4, z −40..−24.
  - Factory: x −22..44, z −24..24, walls 18 high.
  - West Gallery (y 9.2): x −22..−6, z −24..−12.
  - Catwalk: x −6..12, z −20..−14.
  - East Gallery (control room): x 12..30, z −24..−12.
  - Dock Apron: x 44..54, z −40..32.
- **Secure:**
  - **Vault:** x 16..28, z −6..6, cold. It has three doors:
    - `KeycardDoor` on the west side (x 16, z −3..3).
    - A north door (z −6, x 19..25, `Pryable` 3).
    - The **Choc-Block Door** on the east side (x 28, z −3..3, loud-only).
  - **Cold Room:** x 34..44, z 12..24, cold. Doors on the west (x 34) and east (x 44) sides, z 14..20, both `Pryable` 3.
  - **Office** on the West Gallery, x −22..−14, z −24..−15. Door on its south side (z −15, x −21..−16) at the ramp
    top, with a 3-stud landing; `Pryable` 1.5, red lamp.
- **Upper-floor links:** the West Ramp (x −22..−16, from z 12 at y 0 to z −12 at y 9.2, 6 wide, 20.5°: heavy loot OK),
  the east stairs (x 30..36, z −20..−14), and the catwalk between the galleries.
- **Landmark:** the cocoa chimney (x 26, z 18), puffing brown steam, visible from every zone.

**Signature set pieces.**
1. **The Chocolate River:** a 6-wide channel of glossy brown neon "chocolate" (x 4..10, all z) behind 4-high rails.
   - Crossings: North Bridge (floor, z −22..−16), South Bridge (floor, z 14..20), the catwalk above (y 9.2) and the
     rail bridge (riders only).
   - A player who falls in lands in a `GooZone` (walk 4, "SPLOSH" heard at 15) and wades out by the steps at either end.
2. **The Praline Box Rail** (`Ride`, the conveyor loop): gold gift-box cars on an overhead track, 1 rider or 1 loot per
   car, 8 studs/s.
   - Path: Station A Packing (ground, along the north wall, x 34..42, z −22) → climbs to y 12 over the vault → cooling tunnel
     (x 12..20, riders hidden) → rail bridge at z 0 → Station C Dispatch (ground, west bay, x −14..2, z 22) → back
     east at y 12 above the South Bridge → Station A.
   - **In stealth:** send loot from the east bay to Dispatch, a short carry from the shop door; ride through the
     tunnel unseen.
   - Station V (ground, x 30..33, z −4..4, just outside the Choc-Block Door) and Station B (Dock Apron canal edge,
     x 50..54, z −6..6) are `LockdownOnly`.
   - A and C are the two STOP windows (cars slow to 8, and guards there can grab riders).
3. **Rhythm machines** (`RhythmMachine`):
   - **Chocolate Fountain** (−4, 0.2, −4): pulls the nearest guard over to taste it every 30 s for 4 s.
   - **Big Mixer** (26, 0.2, 18): thumps every 6 s, and a CRACK within 15 studs during the following 2 s is not
     heard. Time the Cold Room pry (3 s) to end on a thump.
   - **Wrapping Machine** (−4, 0.2, 17): gold-wraps you for 8 s and guards ignore you (empty hands only).
4. **The Vault climax:** the Golden Praline turns on a cake stand under a glass bell, in cold mist, on its
   `RisingPlinth` (M1). Lifting it plays a choir "AAAH", starts LOCKDOWN and starts the melting.

**MELTDOWN (lockdown, `LockdownSwitch`):**
- Red lamps and a siren (`On`).
- Fire shutters close 2 of {North Bridge, South Bridge, Staff Door, Yard Door}: seeded, never both bridges, cannot be
  pried (`Close`).
- 6 steam vents puff every 5 s and block guard vision: bridges (7, 0, −19), (7, 0, 17); vault front (13, 0, 0); cold
  room front (31, 0, 18); packing (38, 0, −14); catwalk (2, 9.2, −17).
- The Choc-Block Door melts open over 10 s, and the Dock Door (x 44, z −20..−12, roller) opens (`Open`). The Cold
  Room's east door is a sliding door, so nothing swings out onto the apron's lane.
- The rail becomes the **Conveyor Express** (`Speed` 20): Stations V and B open. The vault → Station V → Express →
  dock route is the spectacular haul.
- A **roadblock** closes the street around the van (`Close`; the van `Exit` is `QuietOnly`).

**Escape:** the barge "The Sweet Getaway" (`Exit` `Boat`, `LockdownOnly`) at (60, −2.6, 0). Its `BankZone` covers the
gangway and the deck, and it carries a cold box (`ColdZone`), like the van.

**Entrances:**
- **E1 Staff Door:** shop → west bay, x −22, z 14..20, `Pryable` 1.5; watched by the shop camera.
- **E2 Yard Gate** (sliding): street → Cocoa Yard, x −40, z −38..−30, padlock 3; noisy. Then the open Yard Door (x −14..−8,
  under the gallery).
- **E3 Bean Chute:** quiet hatch in the South Lane wall at (−8, 0, 24), a 2 s `Ride` to (−8, 0.2, 19). Empty hands or
  pocket loot only.
- **E4 Dock Gate:** South Lane end → Dock Apron, then the Dock Door or the Cold Room's east door (both `Pryable` 3).
- **Loud-only:** the Choc-Block Door.

**Loops:** west bay ↔ North Bridge ↔ east bay ↔ South Bridge (≈ 75 studs); east bay around the vault (≈ 90);
the catwalk loop over the river (≈ 60).

**Anchors:**

| Kind | Anchors |
|---|---|
| Main ×3 (Golden Praline) | M1 vault cake stand (22, 0.2, 0) · M2 Cold Room cake trolley (40, 0.2, 20) · M3 office tasting table (−17, 9.2, −20) (ramp + catwalk) |
| Heavy ×4 (Praline Tower) | Packing (40, 0.2, −18) next to Station A · Cold Room (36, 0.2, 22) · under the gallery by the yard door (−18, 0.2, −20) · east bay (20, 0.2, 18) |
| Medium ×12 (Chocolate Slab) | Fountain table (−8, 3, −8) · wrapper output (−4, 2, 21) · Dispatch bench (−12, 3, 23) · moulding tables (20, 3, −10), (14, 3, 10) · packing benches (42.5, 3, −10), (42.5, 3, −14) · East Gallery (24, 12, −20) · yard (−12, 3, −39), (−36, 3, −25.5) · Cold Room shelf (42, 3, 13) · street cocoa cart (−44, 2, 14) `Opener` |
| Small ×14 | **Shop (public):** counters (−36/−30/−26, 3.6, −20), tasting bar (−30, 3.6, 21), register (−30, 4.2, −20) `Drawer` · café table (−46, 3, 30) `Opener` · lockers top (−20, 7.2, 22) · catwalk ledge box (2, 9.2, −14.5) · office desk (−15.5, 12, −23) `Drawer` · East Gallery desk (16, 12, −22) · packing (42, 3, −22) · Dock Apron crate (50, 4, −30) · Cold Room (42, 3, 22) · yard crate (−12, 4, −31) |
| Secrets ×2 | Grandma's Recipe Tin under a loose tile behind the tasting bar (−32, 0.2, 22.5), 300 · gold praline stash on the hidden ledge under the catwalk (7, 6, −17), 250 |
| Keycard ×5 | Register · lockers top · East Gallery desk · packing table · Dock Apron crate |
| Safe | Office (−20, 9.2, −22), `DeviceSpot` (−20, 9.2, −20), 2 × `Group = "OfficeSafe"` |
| Hide ×11 | `Locker` (−20, 0.2, 22), (−18, 0.2, 22) · cocoa sack piles (14, 0.2, −22), (24, 0.2, −22) (both under the East Gallery) · `TallCask` (12, 0.2, 22), gallery (−8, 9.2, −23) · yard `Dumpster` (−19, 0, −38) flush against the cage, `TallCask` (−6, 0, −38) · `TallCask` Dock Apron (52, 0, −36), (52, 0, 28) · Cold Room `Locker` (42.5, 0.2, 23) |
| Cell ("Bean Cage") | Wire-mesh cage in the Cocoa Yard, x −30..−22, z −40..−34 (`Cage`-style bars, 10 high) · `CellDoor` on the north side z −34, x −28.5..−23.5 · 4 `CellSpot`s · `CellDropoff` (−26, 0, −32) · `CellExit` (−20, 0, −32) · `CellGrate` = drain in the South Lane (−20, 0, 28) |
| Exits | Van `Exit` (`QuietOnly`) at (−50, 0, −20), rear facing +X; `Points.Spawn` (−45, 3, −20) · barge as above |
| Karel | `KarelHome` closet under the gallery (−11, 0.2, −15) · route (0,−19) (13,−19) (13,−10) (37,−10) (37,9) (13,9) (13,17) (0,17) (−8,10) (−8,−8) (−11,−15). It crosses the river only on the bridges |
| Cameras ×5 | Shop (−23, 10, −23) → (−34, 0, 0) · west bay (−21, 13, 23) → (0, 0, −10) · vault front, under the gallery edge (13.5, 8, −11.5) → (16, 0, 0) · Dock Apron (53, 9, −39) → (49, 0, 0) · Cocoa Yard (−5, 9, −39) → (−30, 0, −30) |
| Hazards ×10 | (−30,0.2,−6) (−30,0.2,10) (−9,0.2,−12) (0,0.2,8) (12,0.2,−10) (12,0.2,9) (37,0.2,0) (20,0.2,−18) (49,0,−10) (−20,0,−32) |
| Zones | `ColdZone`: vault, Cold Room, the van's cold box, the barge · `GooZone`: the river · `StaffZone`: yard, factory, galleries, Dock Apron · `SecureZone`: vault, Cold Room, office |

**Guard routes:**

| Route | P | V1 | V2 |
|---|---|---|---|
| West Bay | 1 | (−8,−8) (0,−8) (0,10) (−8,10) | (−8,−20) (0,−20) (0,10) (−8,10) |
| East Bay | 1 | (13,−10) (13,9) (37,9) (37,−10) | reversed |
| Shop | 2 | (−36,−16) (−26,−16) (−26,16) (−36,16) | reversed |
| Galleries (y 9.2) | 2 | (−8,−17) (28,−17) | (−10,−18) (12,−17) |
| Cocoa Yard | 3 | (−36,−28) (−6,−28) | (−36,−26) (−8,−26) |
| Dock Apron | 3 | (47,−36) (47,28) | (47,−20) (47,20) |

**NPCs:** 5 guards + Karel = 6; Hard adds 1 → 7. The old Robo-Mop is dropped: the rhythm machines replace it, and the
NPC budget has no room for it.

## 8. Tulip Auction (map 3, the finale)

A flower auction at dawn: greenhouses glowing magenta, a windmill on the horizon.
- **New pressure:** a moving light, a moving train and fragile loot. Bulbs and vases lose 25% per drop; the Black
  Tulip's royal pot loses 10% per drop and needs two carriers or a trolley car.
- **Loot:** ±7,000. **Guards:** 5 + the clock spotlight.
- **Footprint:** x −62..56, z −50..50.

```
            z: -50   -44  -32          0           32   44   50
x -62..-40  FORECOURT (public): [VAN -52,-16] · flower trucks · kiosk · roadblock spot
x -40       |E2 yard gate| front doors (z -4..4)                   | SOUTH LANE (public)
x -40..-28  | LOADING    | VIEWING GALLERY (public): coffee bar, souvenirs, glass wall ▸
x -28..8    |  YARD      | AUCTION HALL: desk rows · TRAIN LANE · ◉ CLOCK (x 8) · stage plinth
x  8..20    |  (staff)   | ORCHID cold room | N corridor | ROYAL VAULT | S corridor | BULB cold room
            |            |   └── ROOF GARDEN (y 9.5) on top: planters, balloon dock (south end)
x 20..56    |            | GREENHOUSE WING: table maze, mist lines, train loop, roof ramp ↗
x 56..62    SERVICE PATH (public) — E3 greenhouse vent
```

**Zones and rings.**
- **Public:** forecourt, Viewing Gallery (x −40..−28, z −40..40, front doors at x −40, z −4..4), South Lane
  (z 44..50), Service Path (x 56..62).
- **Staff:**
  - Loading Yard: x −28..8, z −44..−32.
  - Auction Hall: x −28..8, z −32..32, height 22.
  - Corridors: z 5..17 and −17..−5, x 8..20 (12 wide: train lane on the outer 3, a guard walkway around z ±9).
    The hall's east wall opens onto each corridor over z 6..17 (11 wide, 10 high).
  - Bulb Room: x 8..20, z −40..−17.
  - Greenhouse Wing: x 20..56, z −44..44.
  - Roof Garden: y 9.5, x 8..20, z −40..40.
- **Secure:**
  - **Royal Vault** (x 8..20, z −5..5), three doors:
    - `KeycardDoor` from the north corridor (z 5, x 11..17).
    - A south door (z −5, x 11..17, `Pryable` 3).
    - The **Flower Wall** on the east side (x 20, z −3..3, loud-only).
  - **Orchid Room** (x 8..20, z 17..40), cold, two auto-close doors: z 17 and x 20 (z 30..36).
  - **Auction Stage** (x 2..8, z −8..8, 1 high with ramps), behind a red rope with a reader.
- **Upper-floor links:** ladder L1 from the hall at (6, z 28), through an opening in the hall's east wall at y 9.5
  (z 26..30); ladder L2 from the greenhouse at (21, z 30); and the
  **Roof Ramp**: x 22..28, from z −14 at y 0 to z −40 at y 9.5 (20°, 6 wide), with a 2-stud bridge to the garden.
- **Landmark:** the giant Auction Clock (Ø 16, amber ring lights) on the hall's east wall. Outside: a big neon tulip on
  the hall roof.

**Signature set pieces.**
1. **The Auction Clock spotlight** (`RhythmMachine` `Clock`): the hand sweeps a spotlight across the hall every 12 s,
   leaving a dark sector you cross in. Mounted at (7.5, 19, 0); sweep centre (−10, 0, 0); radii 18 (x) × 30 (z);
   light radius 5.
   - Hall: 3 desk rows (3 high = crouch cover) at x −22, −16, −10, in blocks at z ±(4..26). Centre aisle z −4..4;
     front aisle x −28..−23.
   - **5:00 "MORNING AUCTION IN 3:00":** `MorningLight` steps 1–3 at 5:00, 6:00 and 7:00, so the dark sectors shrink.
2. **The Trolley Train** (`Ride`): a tow tractor + 4 flower carts at 8 studs/s on a ≈ 250-stud loop (31 s/lap).
   - Path: hall train lane (x −1, z −14.5 → 14.5) → north corridor (train lane centred on z 14.5) → greenhouse west
     leg (x 33) → north end (z 38) → east leg (x 48) → south end (z −38) → back west → south corridor (z −14.5) → hall.
   - Table rows fill the greenhouse between the lanes; the guard lane is x 38..44.
   - It is moving cover. You can ride a cart past guards' backs, and 2 medium buckets ride on it at round start.
     Carts can carry the Black Tulip.
3. **The Greenhouse maze:** planting tables in rows (two heights of cover), hanging baskets, and 4 **mist lines**
   (`RhythmMachine` `Mist`) along the aisles at z −30, −10, 10, 30: every 10 s, a 4 s mist blocks guard vision inside
   it.
4. **Cold rooms** (Bulb Room, Orchid Room): sliding doors close 10 s after opening (`ColdRoom`; buttons on both sides,
   so nobody is trapped). Fog halves guard range; frost-blue light.
5. **The climax:** the Black Tulip rises out of the floor on a glass plinth (`RisingPlinth`). In the vault it sits in a
   **laser vitrine** (`LaserGrid`: an EMP gives 10 s, a touch = +40). Lifting it rings a "GONG", then LOCKDOWN.

**FLOWER FRENZY (lockdown, `LockdownSwitch`):**
- Sprinklers soak the greenhouse (`On`): running with medium loot = slip and squeak.
- The clock spins at double speed (6 s sweep), and the front doors and the gallery staff door shutter (`Close`).
- A roadblock closes the forecourt (the van is `QuietOnly`).
- The Flower Wall opens (vault → greenhouse).
- The train goes express (`Speed` 22): at the switch (25, 0, −12) it climbs the Roof Ramp to the `LockdownOnly`
  station by the balloon.

**Escape:** the **Tulip Balloon** (`Exit`, `LockdownOnly`, `ArrivesAt` = lockdown + 20 s) docks at the roof garden's
south end (14, 9.5, −36) and lifts off at police time. Its basket is the `BankZone`: walk in, no jumping. The basket is
built from parts; the envelope is the balloon prop.

**Entrances:**
- **E1 Gallery Staff Door:** x −28, z 20..26, `Pryable` 1.5; watched by the spotlight and a camera.
- **E2 Loading Yard Gate:** x −40, z −44..−36, padlock 3; noisy. Then the Loading Bay roller (hall north wall
  z −32, x −20..−12, `Pryable` 3). The foreman hut is at x −8..−2, z −44..−40.
- **E3 Greenhouse Vent:** quiet `Ride` (2 s) from the Service Path at (56, 0, −2) to (52, 0.2, −2).
- **E4 South Door:** South Lane → greenhouse, x 30..36, z 44, `Pryable` 1.5.
- **Loud-only:** the Flower Wall.

**Loops:** hall ↔ north corridor ↔ greenhouse ↔ south corridor (≈ 80); greenhouse aisles (≈ 60); roof garden ↔
ladders ↔ ramp (≈ 75).

**Anchors:**

| Kind | Anchors |
|---|---|
| Main ×3 (Black Tulip) | M1 vault laser vitrine (14, 0.2, 0) · M2 Auction Stage plinth (5, 1.2, 0), in the spotlight · M3 Orchid Room (14, 0.2, 34) |
| Heavy ×4 (Bulb Barrel, rolls) | Bulb Room (14, 0.2, −34) · greenhouse (52, 0.2, 41), (52, 0.2, −41) · Loading Yard (−14, 0, −41.5) |
| Medium ×12 (Delft Vase / Tulip Bucket) | On the train ×2 (moving) · greenhouse tables (52, 3, −20), (52, 3, 0), (30, 3, 20), (52, 3, 30) · Bulb Room (10, 2, −22), (18, 2, −30) · Orchid Room (10, 2, 22) · Loading Yard (−20, 3, −40) · roof garden planter (14, 10.5, 20) · forecourt flower trolley (−44, 2.5, 6) `Opener` |
| Small ×14 | **Gallery (public):** souvenir stand (−34, 3, −20), (−34, 3, −14), coffee bar tip jar (−34, 3.6, 20) · kiosk (−50, 3, 30) `Opener` · desks (−22, 3.2, −10), (−16, 3.2, 14), (−10, 3.2, −20) · stage cash box (6, 3.2, 6) `Drawer` · Bulb Room bags (12, 2, −38), (18, 3, −20) · greenhouse (52, 3, 20), (24, 3, 40) · roof bench (16, 10.5, 0) · Loading Yard hut (−4, 3, −42) `Drawer` |
| Secrets ×2 | Auctioneer's lucky bulb in the clock's maintenance hatch, reached from the roof garden (9, 9.5, 2), 400 · petal purse under a roof-garden bench (12, 9.5, −20), 200 |
| Keycard ×5 | Kiosk · stage cash box · Loading Yard hut · greenhouse potting bench · roof garden bench |
| Safe | Loading Yard foreman hut (−6, 0.2, −42), `DeviceSpot` (−6, 0.2, −39) |
| Hide ×11 | Gallery coat `Locker`s (−39, 0.2, 30), (−39, 0.2, 33) · hall flower crate (−26, 0.2, 30) · greenhouse tarp trolleys (54, 0.2, −30), (54, 0.2, 10) · compost bin (24, 0.2, 30) · Bulb Room `TallCask` (19, 0.2, −39) · Orchid Room `Locker` (19, 0.2, 39) · Loading Yard `Dumpster` (−24, 0, −42.5), (4, 0, −42.5) · roof rain barrel `TallCask` (19, 9.5, 38) |
| Cell ("Chill Cell") | Glass box in the hall's north-west corner, x −28..−20, z −32..−27 · `CellDoor` z −27, x −26..−21 · 4 `CellSpot`s · `CellDropoff` (−23.5, 0.2, −25) · `CellExit` (−26, 0.2, −24) · `CellGrate` = drain in the Loading Yard (−10, 0, −40). Visitors in the gallery can see you sulk |
| Exits | Van `Exit` (`QuietOnly`) at (−52, 0, −16), rear facing +X; `Points.Spawn` (−46, 3, −16) · Balloon as above |
| Karel | `KarelHome` greenhouse potting shed (54, 0.2, −40) · route (44,−30) (44,30) (22.5,9) (10,9) (22.5,9) (22.5,−9) (10,−9) (22.5,−9) (44,−30). The train cars don't collide with NPCs |
| Cameras ×5 | Hall (−27, 14, −31) → (−6, 0, 0) · corridors (19.5, 8.5, 16.5) → (10, 0, 9) · greenhouse (55, 12, −43) → (36, 0, 0) · Loading Yard (−27, 9, −43) → (0, 0, −38) · roof garden (19.5, 14, −39) → (14, 9.5, 0) |
| Hazards ×10 | (−25,0.2,−10) (−25,0.2,10) (−6,0.2,0) (16,0.2,12) (16,0.2,−12) (36,0.2,−10) (44,0.2,20) (14,9.5,−10) (−12,0,−38) (−34,0.2,0) |
| Zones | `StaffZone`: Loading Yard, hall, corridors, Bulb Room, greenhouse, roof garden · `SecureZone`: vault, Orchid Room, stage |

**Guard routes:**

| Route | P | V1 | V2 |
|---|---|---|---|
| Hall Front | 1 | (−25,−24) (−25,24) | (−25,−24) (−25,0) (−6,0) |
| Train Lane | 1 | (−6,−29) (−6,29) | (−6,−29) (−6,0) (−25,0) |
| Corridors | 2 | (10,9) (22.5,9) (22.5,−9) (10,−9) (back) | reversed |
| Greenhouse | 2 | (38,−30) (44,−30) (44,30) (38,30) | (38,−20) (44,−20) (44,20) (38,20) |
| Roof Garden (y 9.5) | 3 | (14,−30) (14,30) | (14,−30) (14,0) |
| Loading Yard | 3 | (−24,−36) (4,−36) | (−24,−34) (4,−34) |

**NPCs:** 5 guards + Karel = 6; Hard adds 1 → 7.

## 9. Art direction

| Map | Time and light | Palette | Landmarks / key props |
|---|---|---|---|
| Garage | Any preset; own tungsten lamps (255, 180, 110) | Brick, concrete, crew orange | Arches, orange van, trophy wall, a train rumbling overhead (sound) |
| Mini-job | BlueNight, exposure +0.1 | As map 1 | Market stall, glowing van |
| Golden Wheel | BlueNight (as today); frost-blue cellar | Blue shadows, warm windows, cheese yellow, gold | Rotating Golden Wheel, canal lamps |
| Praline Palace | Blue hour (`ClockTime` 20.2); gold chandeliers in the shop, cool white factory, amber machine lights; MELTDOWN all red | Chocolate (60, 36, 24), cream, gold, raspberry (210, 70, 110), pistachio façade | Cocoa chimney, chocolate river, gold rail boxes |
| Tulip Auction | Pre-dawn (`ClockTime` 5.4): indigo sky, magenta greenhouse glow, cool fluorescent hall, frost-blue cold rooms; brighter in steps from 5:00 | Steel, safety yellow, flower reds, oranges, pinks, purples | Clock, neon tulip, balloon, windmill (−140, 0, 80) |

## 10. Signs

All `Builder.sign`; positions are the board centre. Every board is sized per §2 for its viewpoint, mounted on a wall
face or beam, and nothing stands in front of it. CLOSED boards (4 × 1.2 at y 4.5, facing the approach) belong to each
`LockedBlocker`.

| Map | Text | Position | Faces | W × H | Read from / clearance |
|---|---|---|---|---|---|
| Garage | THE GARAGE | (−20.3, 15, 0) | −X | 14 × 2.4 | Forecourt; viaduct face above the 12-high roller opening |
| Garage | JOB BOARD | (19.6, 11.2, 0) | −X | 9 × 1.6 | Spawn, 8 studs; above the board (top 9.5) |
| Garage | GEAR · WORKBENCH | (19.6, 9.6, −27) · (19.6, 7.4, −19) | −X | 5 × 1.6 · 6 × 1.1 | Workshop; above the rack / bench |
| Garage | LOOKS | (−8, 9.2, −33.8) | +Z | 5 × 1.4 | Pier face above the mirror (top 7.2) |
| Garage | CREW WALL | (19.6, 11.4, 24) | −X | 9 × 1.6 | Lounge; above the shelves (top 10) |
| Garage | PRACTICE YARD · THROW LINE | (−11, 10.6, 33.8) · (−10, 3, 41.2) | −Z | 9 × 1.4 · 5 × 1 | Above the 9-high yard door · post at the line's end |
| Mini | CORNER CHEESE | (−12.3, 10.4, 0) | −X | 12 × 2 | Spawn, 16 studs; no awning |
| Mini | CHEESE | (−17, 4.5, 0) | −X | 4 × 1.2 | Standing board beside the stall, not under its roof |
| GW | THE GOLDEN WHEEL (keep) | (−22.8, 12.9, −27) | −X | 16 × 2.2 | Van; awning top ≤ 11.3 < board bottom 11.8; clear from x ≤ −33 |
| GW | CHEESE blade / DELIVERIES / RIPENING ROOM (keep) | as today | | | Above the awning / gate beam / hall wall (no new door overlaps it) |
| GW | BEWARE OF / THE DOG | (−22.8, 6.5, 10) | −X | 4.4 × 2 | Quay; YardWallA, clear of the gate posts |
| GW | BACK LANE · BIN ALLEY | (−22.9, 9.6, ∓44) | −X | 6 × 1.1 | Quay; beams over the 8-high gates |
| GW | STAFF ONLY (enlarged) · KAREL | (−0.7, 9.1, −20) · (−3.5, 9.6, −25.8) | −X · +Z | 4.4 × 1 · 3 × 0.9 | Shop floor; lintel above the staff door · closet front (walls raised to 10.5) above the 8-high door |
| GW | SECURITY · HOLDING CELL | (0.2, 11.2, 0) · (−11.6, 10.6, −8) | +X | 6 × 1.2 · 5 × 1 | Hall aisle; lintel above the opening · top rail of the bars (lamp moved) |
| GW | OFFICE | (30.2, 9.6, 21.6) | +X | 5 × 1.1 | Hall; keycard gate beam |
| GW | LOADING DOCK ×2 | (60.3, 10.4, 16) · (59.7, 10.4, 16) | +X / −X | 8 × 1.3 | Dock Apron / hall; above the 9-high roller |
| GW | FIRE EXIT | (53, 10, 24.7) | −Z | 6 × 1.1 | Hall; above the door; RIPENING ROOM ends at x 37 |
| GW | COLD CELLAR | (28.2, 9.6, −37) | +X | 8 × 1.3 | Back Yard; beam over the trench head (8.5 clear), readable from the yard |
| Praline | PRALINE PALACE | (−40.3, 11, 0) | −X | 18 × 2.4 | Street, 20 studs; gilded fascia, no awning |
| Praline | CHOCOLATES blade | (−41.8, 10.5, −22.5) | ±Z | 3.4 × 1.4 | Along the street |
| Praline | COCOA YARD | (−40.3, 9.6, −34) | −X | 7 × 1.2 | Street; beam over the 8-high gate |
| Praline | STAFF ONLY · OFFICE | (−22.3, 10.2, 17) · (−15, 14.5, −14.8) | −X · +Z | 4.4 × 1 · 3.4 × 1 | Shop side of E1, above the door · on the office wall beside its door (the gallery ceiling is too low above it) |
| Praline | VAULT · COLD ROOM | (15.7, 9.4, 0) · (33.7, 10, 17) | −X | 5 × 1.2 · 7 × 1.2 | East bay; on the vault parapet (walls raised to 10.5) / cold-room wall above the doors, red lamps beside |
| Praline | LOADING DOCK | (44.3, 11, −16) | +X | 9 × 1.4 | Dock Apron; above the roller |
| Praline | COOLING TUNNEL | (11.8, 15.5, 0) | −X | 8 × 1.4 | Rail riders and the west bay; tunnel header |
| Praline | HOLDING CELL | (−26, 10.6, −33.8) | +Z | 6 × 1.1 | Cocoa Yard; on the cage's top rail |
| Tulip | TULIP AUCTION | (−40.3, 16, 0) | −X | 20 × 3 | Forecourt, 15–25 studs; no canopy |
| Tulip | VISITORS · STAFF ONLY | (−40.3, 10.2, 0) · (−28.3, 10.2, 23) | −X | 6 × 1.2 · 4.4 × 1 | Forecourt / gallery |
| Tulip | LOADING YARD · LOADING BAY | (−40.3, 9.6, −40) · (−16, 10.4, −32.3) | −X · −Z | 7 × 1.2 · 8 × 1.3 | Beam over the gate · above the roller |
| Tulip | ROYAL / VAULT · ORCHID / ROOM · BULB / ROOM | (18.6, 5.5, 5.2) · (18.6, 5.5, 16.8) · (18.6, 5.5, −16.8) | +Z · −Z · +Z | 2.6 × 2 each (2 lines) | Corridors (≤ 12 studs); beside the doors, because the corridor ceiling (y 9) leaves no room above them |
| Tulip | CHILL CELL | (−23.5, 10.2, −26.7) | +Z | 6 × 1.2 | Hall front aisle; above the glass door |
| Tulip | GREENHOUSE · ROOF GARDEN | (33, 10, 44.3) · (25, 9.5, −13.5) | +Z · +Z | 8 × 1.2 · 8 × 1.3 | South Lane, above the door · arch beam over the ramp foot (8.5 clear) |
## 11. Props

**Reused from `tools/props.json`:**
- `Barrel` and `Crate`: decor; `Crate` × 1.45 doubles as a hide crate.
- `CheeseWheel` (× 1.6 = Big Wheel; blue = Blue Moon), `GoldenGouda` (× 0.6 in the mini-job).
- `Van`: the Garage, every heist, and the rusty practice van.
- `StreetLamp`, `Bicycle`, `TulipBox(Tall)`, `Kennel`, `Forklift`, `PendantLamp`.

**New** (Studio `generate_mesh`, max 2 at a time; the suffix "stylized cartoon game prop, chunky shapes" is implied;
every prop gets a block fallback):

| Batch | Name | Prompt | W×H×D | Use |
|---|---|---|---|---|
| 1 | CheeseCube · TipJar · CashDrawer · Keycard | Cube of yellow cheese with holes · glass tip jar with coins · cash register drawer with play money · yellow keycard with a cheese logo on a red lanyard | 1.2³ · 1×1.4×1 · 2×0.8×1.6 · 0.8×0.2×1.2 | Loot, objective |
| 1 | TallCask · Dumpster · Locker | Tall wooden ripening cask with iron hoops · green metal dumpster with a hinged lid · tall grey staff locker | 3.6×6×3.6 · 6×5.6×4 · 2.4×7×2.4 | Hide spots (~30 in total) |
| 1 | Safe · CheeseGrater | Chunky green steel safe with a big dial · big cheese grater machine with a motor, dials and blinking lights | 3×3.2×3 · 2×2.5×1.5 | Objective |
| 1 | Workbench · Sofa · CrtTv · StandMirror · BasketTarget · CardboardGuard | Cluttered workbench with a vise · worn leather couch · boxy CRT TV on a stand · standing mirror, gold frame · wicker basket target on a post · cardboard cutout of a chubby moustached guard | 6×4×3 · 7×3.5×3.2 · 3×3.6×2.4 · 3×7×0.6 · 3×5×3 · 3×6×0.4 | Garage |
| 1 | MarketStall · CheesePress | Closed Dutch cheese market stall, striped canvas roof · old wooden cheese press with a big screw | 8×7×5 · 4×6×4 | Mini-job · GW cellar |
| 2 | GoldenPraline · PralineTower · ChocolateSlab · PralineBox | Giant golden praline truffle with a chocolate swirl, shiny · tall tiered tower of gold-wrapped pralines on a silver stand · slab of dark chocolate half in gold foil · gold gift box of pralines with a red bow | 3×2.5×3 · 3×6×3 · 3×0.8×2 · 1.4×0.6×1.4 | Loot |
| 2 | ChocolateFountain · BigMixer · WrappingMachine | Three-tier chocolate fountain on a gold base · huge copper chocolate mixer with pistons and a paddle · gold-foil wrapping machine with rollers and a funnel | 4×6×4 · 6×8×6 · 6×6×4 | Rhythm machines |
| 2 | RailBox · CakeStand · DisplayCounter · CocoaSackPile | Gold gift-box cart with a red bow, hanging from a rail, big enough to sit in · ornate rotating cake stand under a glass bell · chocolaterie glass counter with gold trim · pile of burlap cocoa sacks | 4×3×4 · 3×4×3 · 8×4×3 · 5×5.6×4 | Ride, vault, shop, hide |
| 2 | Barge · Chandelier | Dutch canal barge "The Sweet Getaway" painted brown and gold · small gold chandelier | 6×4×18 · 4×3×4 | Exit, shop |
| 3 | BlackTulipPot · DelftVase · TulipBucket · BulbBag · BulbBarrel | Black tulip in an ornate gold royal pot, glowing · blue and white Delft vase · black bucket of tulips · mesh bag of tulip bulbs · wooden barrel of tulip bulbs | 3×5×3 · 1.6×3×1.6 · 1.4×2.4×1.4 · 1.2×1.2×1 · 2.6×3×2.6 | Loot |
| 3 | TowTractor · FlowerTrolley | Small yellow electric tow tractor · Danish flower trolley with three shelves of tulip buckets (+ empty variant) | 4×4×6 · 4.5×6.5×2.2 | Train |
| 3 | AuctionClock · TulipBalloon · FlowerTruck · Windmill | Giant round auction clock with red ring lights · hot-air balloon shaped like a giant red tulip (envelope only) · white flower truck with tulip graphics · Dutch windmill body | 16×16×1.2 · 24×36×24 · 8×9×16 · 20×40×20 | Landmarks, exit, decor |

Built from parts: the job board, lectern, drains, river, rail track, steam vents, laser beams, cell bars, the clock hand
and the balloon basket.

## 12. Performance, reuse and build order

| Budget | Garage | Mini-job | Golden Wheel | Praline | Tulip |
|---|---|---|---|---|---|
| Parts | ≤ 1,200 | ≤ 1,500 | ≤ 4,800 | ≤ 4,000 | ≤ 4,500 |
| Lights / shadowed | ≤ 10 / 3 | ≤ 10 / 2 | ≤ 40 / 9 | ≤ 40 / 9 | ≤ 40 / 9 |

**Performance notes:**
- With streaming off, the worst case (Garage + heist + 2 mini-jobs) is ≈ 10,000 parts, so `StreamingEnabled` on is
  strongly advised.
- `CanalHouse` gets `detail = "far"`: one block per window, no `SurfaceLight`. On map 1 that saves ≈ 800 parts and 30
  lights.
- Greenhouse glass is large single panes; rail and track are few long parts.
- Steam, mist and sprinklers are particle emitters toggled on and off.
- Everything is anchored; rides, loot, the clock and the balloon move by server CFrame. No unions.

**New Common modules:**
- `CanalStreet`: from `Quay.luau`; map 1's look may shift once.
- `Security`: the camera builder with ceiling/wall mounts.
- `Doors`: entrances + blockers, pryables, rollers, the keycard gate, shutters, `LockdownSwitch` helpers.
- `Rides`: track, cars, stations.
- `Anchors`.

| WP | Content | Depends on | Done when |
|---|---|---|---|
| A0 Common | `Config.World`, Registry fields, `MapService` (Garage, mini-job slots, Terrain by bounds), the Common modules above, `CanalHouse` far-LOD, `rng` windows | Mechanics WP0 names | Map 1 builds unchanged; `check.sh` green |
| A1 Golden Wheel | §6 | A0 | Pathfinding reaches every loot room with any 2 entrances; sign test; Blender preview |
| A2 Garage + mini-job | §4–5; props batch 1 | A0; meta tags | Tour beacons hit stations; first bank ≤ 45 s |
| A3 Praline Palace | §7; batch 2 | A1; mechanics: rides, rhythm, melting, `LockdownSwitch` | Express carries a rider + the Golden Praline vault → barge; perf within budget |
| A4 Tulip Auction | §8; batch 3 | A3; mechanics: train, cold rooms, clock, balloon | Train + balloon escape with the pot; 3 different routes seen in 5 rounds |

**Open questions.**
1. **Advisor:** "van → furthest main loot 20–35 s empty-handed": I read it as crouch speed including doors. At walking
   speed it would mean 320–560 studs, which does not fit 130 × 110. Map 1 stays ≈ 15 s.
2. **Advisor:** hide spots must be ≥ 5.5 tall, so the art uses tall casks and dumpsters. Fine, or may hidden
   (transparent) players use 4-tall barrels?
3. **Orchestrator / ux:** client lighting per area (§1).
4. **Mechanics:** reconcile the §3 names (`Ride`, `RhythmMachine`, `ColdZone`, `GooZone`, `LaserGrid`, `MorningLight`,
   `RisingPlinth`, `Opener`, `StaffZone`/`SecureZone`). Also: upper-floor guard routes (y 9), see-through `Cell` bars,
   and guards opening cold-room doors.
