# Crowbar Crew: beta specification (core systems)

*Mechanics, 16 Oct 2026. Builds on `docs/research/advisor-brief.md` (overrides `docs/gameplan-roblox.md`) and the code
in `src/` (v0.2.0-fase1). Companions: `beta-spec-maps.md`, `beta-spec-ux.md`, `beta-spec-meta.md` — names here follow
theirs where they exist. **(proposed)** = advisor silent, mechanics decided. **(pending advisor)** = Notoriety-style
extensions awaiting `docs/research/advisor-notoriety.md`. All numbers are starting values in `src/shared/Config.luau`.*

**Direction:** "Sneak in, grab as much cheese as you dare, and escape." More loot = slower = easier to catch. Loot in
the van is safe. Solo must be fun; teamwork is a bonus.

## 0. Changes compared with today's code

| Today (v0.2) | Beta |
|---|---|
| Touch the Gouda = SUCCESS | Loot is carried to the van and banked; round ends with HOLD TO DRIVE or the police |
| 10 s shared window, Chain Call | Removed: fixed gadget durations; `ChainCallService`, `ChainCallController`, `Config.ChainCall`, gadget `Step` deleted |
| One copy per gadget, slots by crew size, Crowbar on a pedestal | Everyone has the Crowbar; each player picks 2 of 4 at meta's Garage rack |
| Caught = back to the van | Carried to the cell; rescue or self-escape; all caught = BUSTED |
| 1 guard, 1 route | 2–5 guards, routes chosen per round |
| Level rebuilt after every run | Garage permanent; heist built at job start |
| `WalkSpeed` written in 4 services | One writer: `MovementService` |
| `Config.Difficulty` Rookie/Normal/Pro (global) | Per-job difficulty tier (§7.1) |
| LOCKDOWN 90 s, hard-coded "inside" box | 60 s; safe = inside an escape zone |

---

## 1. Round flow

### 1.1 World and activity

| Area | Where | Built by |
|---|---|---|
| Heist | `workspace.Level` at the origin | `MapService:Build(heistId)` at every job start (destroys the previous heist) |
| Garage | `workspace.Garage` at `Config.World.GarageOrigin` (2000, 0, 0) | `MapService:BuildGarage()` once in `Init` |
| Mini-job slots | `workspace.MiniJob_<n>` at `Config.World.MiniJobOrigins` | `MapService:BuildMiniJob(slot)` / `DestroyMiniJob(slot)` |

`StreamingEnabled = true`; before every teleport the server calls `RequestStreamAroundAsync(pos, 5)` then `PivotTo`.
`MapService` clears only the heist's `Bounds` in Terrain instead of `Terrain:Clear()` (map).

Player attribute `Activity`: `Garage`, `Crew` or `Tutorial` (plus `InRound = Activity ~= "Garage"` for meta). Guards,
cameras, Boef and Karel only react to `Crew`.

### 1.2 State machine (one crew per server, `RoundService`)

```
Garage ─(van countdown)─▶ Briefing ─(5 s)─▶ Heist ⇄ Lockdown ─(drive / police / all caught)─▶ Getaway ─▶ Payout ─▶ NextJob
  ▲                                           └──────(everyone left: abort)──────▶ Garage                            │
  └──────────────────────────────(nobody ready)──────────────────────────────────────────────────────────────────────┤
                                                                                       (≥ 1 ready) ──▶ Briefing ◀─────┘
```

| State | What happens | Exit |
|---|---|---|
| **Garage** | Meta's job board (votes via `JobVote`). Standing in the `GarageVan` zone starts a 15 s countdown (`VanDepartAt`); 3 s when every Garage player is in it or solo; empty zone cancels | 0 → Briefing with `LobbyService:GetSelectedJob(boarders)` |
| **Briefing** | Boarders → `Crew`, new `RoundId` (GUID), `seed`. `MapService:Build` → `SetupService:Apply(plan)` → stream → crew placed around `Points.Spawn`, `Frozen`. `JobCard` overlay 5 s (heist, difficulty, modifier, Gouda zone, locked entrances, objectives) | → Heist ("GO!") |
| **Heist / Lockdown** | Clock 0 → `RoundSeconds` (480). `RoundPhase` shows `Lockdown` while the police timer runs (§1.3) | Drive, police time, all caught → Getaway; everyone left → Garage (no payout, outcome `Aborted`) |
| **Getaway** | 4 s: van drives off, "JUST MADE IT!" if police ≤ 5 s away. NPCs and loot removed. Mechanics builds `RoundResult` → `EconomyService:SettleRound` | → Payout; crew teleported to the Garage |
| **Payout** | Meta's `Payout` screen, 30 s. `NextJob()` = ready; once every crew member is ready (min 8 s) skip ahead | → NextJob |
| **NextJob** | 10 s; board stays open; `NextJob()` / `ReturnToGarage()` | ≥ 1 ready → Briefing with the ready players as boarders; else Garage |

### 1.3 Heist timeline

| Clock | Event |
|---|---|
| 0:00 | GO. First loot reachable in ±45 s (map rule) |
| any | Gouda lifted or alarm tier 3 → **LOCKDOWN** once: `LockdownEndsAt = now + LockdownSeconds` (60), `PoliceAt = min(RoundEndsAt, LockdownEndsAt)`, `Approach = "Loud"` |
| `RoundSeconds − 60` | `ShiftChange` "SHIFT CHANGE IN 60" (if no lockdown) |
| `PoliceAt` | Police: crew not free inside an escape zone are caught; round ends |

The cap is hard: lockdown at 7:59 leaves 1 s; lockdown during the shift change keeps the earlier time. One HUD timer
reads `PoliceAt`.

### 1.4 Ending

- **Escape zone** = the `BankZone` of an active exit (van always; boat when active). Character attribute `InVan`.
- **HOLD TO DRIVE** prompt on each exit (3 s). Free crew outside → first hold sends `DriveWarning(userIds)`; a second
  hold within 5 s drives. → outcome `Escaped`.
- **Police time:** ≥ 1 crew member in an escape zone → `Escaped`, the rest count as caught; nobody → `Busted`.
- **All caught:** every `Crew` player `Caught` (grabbed, carried or celled) → wait 1.5 s → re-check → `Busted`.
- Payout effects (meta's formula): `Busted` = half the van loot, no bonuses; a crew member not in the van at the end
  gets half their share.

### 1.5 Joining, leaving, dying

| Situation | Rule |
|---|---|
| New player (`onboarding.done = false`) | Mini-job at once (§1.6), whatever the crew does |
| Join during Garage/Payout/NextJob | Garage; can vote and board |
| Join during Briefing/Heist | Garage, "Crew on a job — 3:10 left", `Spectate`/`ViewCam` feed. While elapsed < 120 s (`JumpInUntil`) and crew < 4: **JUMP IN** (Garage van prompt or `JumpIn()`) → `Crew` at the heist van, fresh charges; guard count unchanged (proposed) |
| Leave while carrying | All loot drops at the last root position; helper leaving = lets go; leader leaving = helper takes over alone |
| Leave while caught | Removed from cell/guard; guard → Search; all-caught check |
| Death | Loot drops where you died (void/water → back to its home anchor); respawn at the heist van (or the cell if `Caught`) |
| Reset button | Disabled client-side (ux) |
| Server shutdown mid-round | `RoundService` settles once with outcome `Shutdown` from `DataService:OnBeforeShutdown` |

### 1.6 Mini-job (tutorial)

Solo ±3 min in parallel with the crew (max 2 slots; a third newcomer waits in the Garage).

| System | Detail |
|---|---|
| `TutorialService` | Allocates a slot, builds, places the player (`Activity = Tutorial`), runs steps, calls `SettleRound` with `mapId = "MiniJob"` (meta adds the welcome bonus and `onboarding.done`), frees the slot |
| Sessions | Loot and bank zones carry `Session` (`Crew`, `Tutorial1`, `Tutorial2`, `Practice`); loot banks only in its own session |
| Fixed loot | Anchors with `Fixed = true`: loot on every anchor, no randomness |
| Sleeping guard | Static anchored model, not in `GuardService`, outside the NPC cap. "Zzz"; non-crouching player within 6 studs → "Hmm?" + hint "Crouch!". At lockdown he sits up and turns his 20-stud cone; a full meter only hints "Hide!". **Cannot be failed** |
| Steps | Mechanics fires `AnalyticsTracker:OnboardingStep` 1 Spawned, 2 FirstLootGrabbed ("HEAVY!"), 3 FirstLootBanked ("+150"), 4 SneakedPastGuard (`TutorialTrigger`), 5 GoudaLifted (60 s lockdown, "Roll it!"); meta logs 6–8 |
| Hints | `Hint(key, text, icon, worldPos?)`, ≤ 5 words + icon |
| Not included | Karel, Boef, cameras, modifiers, difficulty, capture, 8:00 cap. Lockdown expiry = automatic drive |

---

## 2. Loot

### 2.1 Classes (map 1 values)

| Class | Map 1 items | Carry | Speed | Crouch / gadgets / Crowbar | Throw |
|---|---|---|---|---|---|
| Small | Cheese Cube ×6 (25), Tip Jar ×2 (50), Cash Drawer ×1 (150) | Pocket, max 3 | 16 | Yes | No |
| Medium | Cheese Wheel ×8 from 12 anchors (150) | Hands | 12 | No | ≤ 10 studs |
| Rare | Blue Moon (500): 5% per wheel, max 1 | As medium | 12 | No | ≤ 10 studs |
| Heavy | Big Wheel ×2 from 4 anchors (400) | Alone / roll / two | 7 / 11 / 12 each | No | No |
| Main | Golden Gouda, 1 of 3 anchors (1,500); lifting = LOCKDOWN | As heavy | 7 / 11 / 12 | No | No |

±3,900 per round for every crew size. Types live in `Config.Loot.Types` (§9.5); maps 2–3 add theirs.

### 2.2 States (never free physics)

Loot = `Model` (PrimaryPart `Handle`) in `Level.Loot`, tag `Loot`.

| `LootState` | Physics |
|---|---|
| `Placed` | Anchored on its anchor |
| `Carried` | Welded to the carrier's root (massless, no collision). Two-player carry: anchored, server sets CFrame each Heartbeat at the carriers' midpoint |
| `Thrown` | Anchored, server moves it along the arc |
| `Dropped` | Anchored on the floor (downward raycast) |
| `Returning` | Welded to Karel |
| `Banked` | Removed; value added to `VanLoot` |

Pocketed items are destroyed and recreated as `Dropped` if they fall out.

### 2.3 Pick up, throw, catch, drop

- **Prompt** `GrabPrompt` (distance 6; hold 0, heavy 0.3): "Pocket" / "Grab" / "Lift" / "Help carry". On `Triggered`
  the server checks: player free and same `Session`; loot `Placed`/`Dropped`/`Returning`; pocket not full or hands
  empty; "Help carry" only on heavy loot held by one other player within 6 studs. First trigger wins; the second gets
  "Too slow!" (or becomes helper on heavy loot).
- **Throw** `LootThrow(target)`: medium/rare; clamp 10 studs; duration = distance / 28 (0.3–0.8 s); arc height 35% of
  distance (min 2). Each step raycasts: a wall hit stops it 0.5 studs off the wall, then it drops straight down.
- **Catch** (automatic): during flight, a free player with empty hands within 3.5 studs (thrower excluded for 0.3 s);
  at landing, within 5 studs. Landing uncaught = "thud" noise radius 12. Water/void → home anchor after 3 s ("Splash!").
- **Drop** `Drop()`: 2 studs in front. Helper uses `LetGo()`.
- **Fragile hook:** `Fragile = true` types lose 25% of base value per uncaught landing, drop on capture or slip; floor
  25% of base (`LootDamaged`). Map 1 has none.

### 2.4 Heavy loot

| Mode | Speed | Extra |
|---|---|---|
| Alone | 7 | Detection ×1.5 |
| Rolling `Roll(true)` (`CanRoll` only) | 11 | Rumble every 1 s, radius 15 (guards investigate 4 s); client spins the mesh |
| Together (leader + helper) | 12 each | Loot at the midpoint; > 9 studs apart → helper loses grip; no rolling; leader `Drop` drops it |

### 2.5 Banking

Every 0.2 s: any loot whose position, or whose carrier's root, is inside a `BankZone` of its session is banked (pocket
and hands at once; a throw landing in the zone counts for the thrower). `LootBanked` ("+150", KA-CHING). Banked loot is
never lost. Practice loot never banks and returns home 10 s after a drop. Anti-teleport (proposed): carrier root moves
> 40 studs in 0.5 s → loot drops at the previous position.

### 2.6 Loot anchor contract (map)

Tag `LootAnchor` on an invisible, anchored, non-colliding, non-query part; CFrame = loot's bottom centre, facing −Z.
Attributes: `AnchorClass` (`Small`/`Medium`/`Heavy`/`Main`), `AnchorId` (unique), `Zone` (job card/analytics), optional
`Group` (map-specific loot or objective rewards), optional `Fixed`. Minimum on map 1: Small 12, Medium 12, Heavy 4,
Main 3; maps 2–3: ≥ 1.5× the item count. Main anchors need a ≥ 6-stud rolling path to an exit (ramps, no stairs).

---

## 3. Detection, guards, alarm, capture

### 3.1 Detection

| Value | Beta |
|---|---|
| Cone / range | 70°, 35 lit, 18 dark (unchanged) |
| Meter, near → far | **0.8 → 2.0 s** (was 0.6 → 1.9) |
| Fill-rate factors (multiply) | Crouch ×0.5 · medium ×1.25 · heavy/rolling/two-carry ×1.5 · Sleepy Guards ×0.7 · Lockdown ×1.33 (proposed) · difficulty (§7.1) |
| Ignored | `Caught`, `Hidden`, `Activity ≠ Crew`, `ImmuneUntil` |

### 3.2 Guards

| State | Speed | Behaviour |
|---|---|---|
| Patrol | 6 (tier 2: 7.5) | `MoveTo` along its route (straight, clear legs) |
| Suspicious | 9 | Investigates, looks around 8 s |
| Alert | **15** | Chases with pathfinding (direct `MoveTo` with clear line of sight; recompute ≤ every 0.5 s). Lost 3 s → Search |
| Search | 9 | 15 s around the last known spot |
| Stunned | 0 | Bubble 8 s; then Search +10 alarm (as today) |
| **Carrying** (new) | 8 | Carries a captive to the cell; no vision |

- **Grab:** Alert guard within 3.5 studs of his target for 1.0 s continuously. Empty hands (16) outrun 15.
- **Count:** map 1 = 2/3/3/4 by crew size at Briefing; maps 2–3 +1; Double Shift +1; difficulty (§7.1); capped (§4.4).
- **Routes:** `RoundPlan` picks routes by lowest `Priority` first (ties shuffled), a variant each and a random start
  waypoint; `Wait` per waypoint ±1 s.

### 3.3 Alarm

Ladder 100/200/300 and points as in `Config.Alarm.Points`. Tier 1: Karel rests half as long (proposed). Tier 2: patrol
7.5, cameras sweep 30% faster (proposed); Quiet Job lost. Tier 3: LOCKDOWN. New: `AlarmService:ForceLockdown(reason)`,
`MaxLevel`. During Lockdown, every 8 s each patrolling guard is radioed the position of the nearest crew member carrying
loot (else any free one) (proposed).

### 3.4 Capture → cell → rescue

| Step | Rule |
|---|---|
| Grabbed | `Caught = true`, `Captured = "Carried"`; freeze frame (ux); all loot drops (pocket scatters within 2 studs); drone recalled; out of hiding |
| Carried | Welded to the guard's back (`PlatformStand`); guard walks at 8 to `CellDropoff`; not there after 40 s → placed in the cell |
| **Hero moment** | Bubble on the carrying guard, or a Noisemaker landing within 20 studs → he drops the captive (3 s immunity) |
| Cell | `Captured = "Cell"`, on a free `CellSpot`, frozen; watches heist cameras (`ViewCam`) and pings from them |
| Rescue | Prompt "Free crew" on `CellDoor`, hold 2 s, any free crew member: frees everyone → `CellExit`, 3 s immunity (`Rescued`) |
| Self-escape | Once per round: `SelfEscapeAt = celled + 15 s`; `CrawlOut()` → `CellGrate`, 3 s immunity |
| Dropped loot | Karel returns it after 30 s |

**Cell contract (map):** `Cell` folder in `Level`, reachable by pathfinding from every patrol area, with `CellSpot` ×≥ 4
(visible through bars), `CellDoor` (bars, holds the prompt), `CellDropoff` (in front of the door), `CellExit`
(outside), `CellGrate` (≥ 15 studs away, ideally another room). Map 1: the security room in `Shop.luau`.

---

## 4. Hiding, Boef, Karel, NPC budget

### 4.1 Hiding

| Rule | Value |
|---|---|
| Spots | 8–12 per map, 1 player each; prompt "Hide" (0.5 s); `HideExit()` (0.5 s); empty hands or small loot only |
| Inside | Placed at `Inside`, transparent, `Hidden = true`, `HideEndsAt`: invisible to guards, cameras, snitches |
| Seen getting in | A guard whose meter on you was ≥ 0.35, or chasing you, walks over; within 4 studs pulls you out = captured |
| Boef | Barks at a spot hiding smelly loot (proposed) |
| Limit | Shake at 15 s; at 20 s **ACHOO** (`Sneeze`, noise radius 15), tumble out at `Exit`; 5 s before hiding again |

Contract: tag `HideSpot` on a Model, `HideKind` (`Barrel`/`Crate`/`Locker`), PrimaryPart Attachments `Inside` and
`Exit`; encloses a standing character (≥ 5.5 studs tall).

### 4.2 Boef (map 1, outdoors)

Wanders `Points.DogRoute` at 6 inside `DogZone` parts (convex; no pathfinding). Crew member with a `Smelly` item
(pocket included) within 15 studs → follows 4 studs behind at 12 and barks every 2 s (`BoefBark`; guards within 30
investigate). Carrier leaves the zone → 3 s edge barking, then gives up. Prompt "Give cheese" (smelly small item, within
10 studs): item consumed, Boef eats 12 s. Noisemaker within 20 studs: chases it 8 s. Immune to Bubble and EMP; never bites.

### 4.3 Karel (every heist except the mini-job)

| Behaviour | Value |
|---|---|
| Cycle | Rests at `KarelHome` 60 s ±15 (tier 1+: halved), walks `Points.KarelRoute` at 7, returns |
| Traces | `Trace`-tagged things within 25 studs in line of sight; detours with pathfinding |
| `OpenDoor` | Closes it (collidable, silent 0.5 s "Open" prompt): "WHO LEFT THIS OPEN?!" +20 |
| `DroppedLoot` (≥ 30 s) | Carries it back to its anchor (`Returning`, `LootReturned`); players may snatch it back |
| `Noisemaker` | Pockets it (ring ends) +20 |
| Snitch (proposed) | Sees crew like a guard (25 studs, fill ×0.5): "I'M TELLING!" +20, 2 nearest guards investigate; once per player per 30 s |
| Immune | Bubble ("Karel has seen worse"), EMP; catches nobody |

Each trace scores once. Only Karel finds traces in the beta. Lines go out as `KarelShout`.

### 4.4 NPC budget (max 7)

`guards = clamp(base + mapBonus + modifier + difficulty, 1, 7 − others)`; `others` = Karel + Boef (map 1) + map
extras (Robo-Mop) + Inspector. The mini-job guard does not count. Map 1, four players, Double Shift: 5 + 2 = 7.

---

## 5. Gadgets and loadout

| Gadget | Numbers | Changes |
|---|---|---|
| **Crowbar** (everyone) | Door 1.5 s, cage 3 s, CRACK 25 (+20 if heard) | No pedestal. Pried door: `Trace` (`OpenDoor`), `DoorState = "Open"`, keeps `ClosedCFrame` |
| **Drone** | Unchanged | Empty hands to launch |
| **Noisemaker** | 3 charges, distracts 8 s, heard within 20 | Fixed 8 s; clock gets `Trace` (`Noisemaker`); drops captives; lures Boef |
| **EMP** | 2 charges, radius 14, 10 s, cooldown 30 | Fixed 10 s; own drone hit → "Self-EMP" stat |
| **Bubble Blaster** | 3 charges, guard 8 s, teammate 3 s | Fixed 8 s; drops captives; triggers a radio check (§7.3); works on the Inspector, not Karel/Boef |

- **Loadout:** meta's Garage rack (`SetLoadout`). At Briefing and JUMP IN, `LoadoutService` reads
  `ShopService:GetLoadout(player)` → `{"Crowbar", a, b}` and resets per-player charges. Duplicates across a crew allowed.
- **Full hands** (medium/heavy, any mode) block every gadget and the Crowbar ("Hands full!"); pocket loot does not.
- **Kept:** projectile arc, "Again?!" repeat rule, EMP on all `Electronic` + BZZT, bubble projectile and friendly fire,
  drone flight/battery/recall/auto-spot, `PrySeconds`, `Window` HUD message (fed by the fixed durations).
- **Removed:** `windowSeconds`, `slotsFor`, `SlotsByCrewSize`, `WindowSeconds`, `SoloExtraWindow`, `GadgetPedestal` use
  in `LoadoutService`, the Quay rack and old `Goal` part on map 1 (map; update the CLAUDE.md tag list).

---

## 6. Randomisation and modifiers

### 6.1 Seed and plan

`RoundService` draws a `seed` at Briefing. `Logic/RoundPlan.generate(seed, heistInfo, crewSize, job)` is deterministic
(`DevJob` replays a seed).

| Randomised | Rule |
|---|---|
| Loot | Per class, `Count` anchors out of the class's anchors; 5% Blue Moon per wheel, max 1 |
| Gouda | 1 `Main` anchor (on the job card) |
| Entrances | 2 of 4 `Entrance`s locked |
| Guards | Routes, variants, start points |
| 2nd exit | Optional exit (boat) active 50% |
| Objectives | Keycard spot, safe jam times (§7.3) |
| Wet Floor | 6 `HazardAnchor`s get puddles |

**Entrance contract:** tag `Entrance` on a Model, `EntranceId`, child `LockedBlocker`. Locked → blocker solid and
visible, `Pryable`s inside disabled; open → blocker destroyed. Any 2 open entrances reach every loot room.
**Exit contract:** tag `Exit` on a Model, `ExitKind` (`Van`/`Boat`), `Optional`, children `BankZone` (±10×8×10, tag
`BankZone`, `Session`) and `DrivePoint`. Inactive optional exits are destroyed.

### 6.2 Modifiers (unlock and board: meta; effects: mechanics)

| Modifier | Effect | Payout |
|---|---|---|
| Power Cut | All `Lamp`s and cameras off for the round; inside a guard's cone the range is 22 (flashlight) | +20% |
| Health Inspector | 1 Inspector snitch NPC on a spare route at 6 (25 studs, fill ×0.67): whistle +20, 2 nearest guards investigate; can be bubbled | +15% |
| Wet Floor | 6 puddles: entering faster than 10 studs/s → 1 s slip, SQUEAK (radius 15), medium loot dropped; crouching is safe | +10% |
| Rush Job | `RoundSeconds` 360 | +25% |
| Sleepy Guards | Fill rate ×0.7 | −20% |
| Double Shift | +1 guard | +30% |

---

## 7. Notoriety-style hooks (pending advisor)

The owner wants "a whole game where you unlock maps and such, kinda Notoriety-inspired". The core above stays; these
are clean extension points with concrete proposals. Each is behind a `Config` switch so the beta can ship without it.

### 7.1 Difficulty tiers per heist

Job = `{heistId, difficulty, modifier?}`. `Logic/Difficulty.apply(base, tier)` scales the round; `Config.Difficulty`
(today a global string) becomes the tier table.

| | Easy | Normal | Hard | **Big Cheese** (silly top tier) |
|---|---|---|---|---|
| Payout multiplier | ×0.8 | ×1.0 | ×1.4 | ×2.0 |
| Guard meter fill rate | ×0.8 | ×1.0 | ×1.2 | ×1.4 |
| Extra guards (within the cap) | 0 | 0 | +1 | +1 |
| Camera fill | 3 s | 2 s | 1.6 s | 1.3 s |
| Alarm points | ×0.75 | ×1 | ×1.25 | ×1.5 |
| `LockdownSeconds` | 75 | 60 | 50 | 40 |
| Self-escapes | 2 | 1 | 1 | 0 |
| Silly rule | — | — | — | Guards wear giant cheese hats, shout "SAY CHEESE!" on a grab, and Boef/Karel get a hat; every loot pickup squeaks (noise radius 6) |
| Unlock (per heist, crew union) | With the map | With the map | 3★ on Normal | 3★ on Hard |

Meta stores best stars per heist and difficulty; `LobbyService` offers difficulties on the board; `RoundResult`
carries `difficulty` and meta multiplies it into the payout.

### 7.2 Stealth vs loud

Every job starts stealthy; LOCKDOWN is the **loud phase** (`Approach = "Loud"`): guards hunt (radio sweeps, faster
meters), the police timer runs, pranks are the only answer — no guns, ever.

| Hook | Proposal |
|---|---|
| Panic Pack | At the start of the loud phase each crew member gets +1 charge of each picked gadget |
| Loud-only actions | `LoudOnly = true` on a `Pryable`: prompt only works in loud (e.g. a noisy shutter shortcut to the van) |
| Prank Arsenal | Gameplan §4.8 pranks (Fondue Cannon, Tickle Ray, Rubber Chicken…) return as loud-leaning sidegrades bought from meta |
| Escape vehicle recall | Per heist `LoudEscape = "Stay"` (map 1) or `"Recall"` (maps 2–3): at lockdown the van flees ("BACK IN 30!") and returns after `VanReturnSeconds` (30; Easy 20, Big Cheese 40) at a random active exit; until then nobody can drive; banked loot stays safe. HUD timer from `VanArrivesAt` |

### 7.3 Objectives beyond loot

`ObjectiveService` (mechanics) runs the heist's `Objectives` list (`{Id, Type, Required, BonusPct?, Group?}`),
replicates a snapshot (`Objective(id, state, data)`), and lists them on the job card. Required objectives gate
something (a vault door); optional ones add `BonusPct` (proposed +10%) through `RoundResult.objectives`.

| Type | Design | Map contract |
|---|---|---|
| **Keycard** | Keycard (small, value 0, not smelly) spawns on 1 of N anchors; a `KeycardDoor` opens with a 1 s hold while it is in your pocket (kept, can be dropped; Karel returns dropped cards) | `LootAnchor` with `Group = "Keycard"`; tag `KeycardDoor`, attribute `Card` |
| **Safe + cracking device** | Hold 2 s (empty hands) to place the "Cheese Grater 3000" on a `Safe`: 0 → 100% in 60 s. It **jams** 1–2 times (seeded); jammed = no progress and a beep every 3 s (noise radius 12). Anyone holds "Restart" 1.5 s at the device — with a crew a teammate keeps watch, solo you run back. Done: the safe opens and its loot spawns | Tag `Safe`, Attachment `DeviceSpot`, loot anchors `Group = <safe id>` inside |
| **Radio check** | 4 s after a guard is bubbled, his radio squawks "Unit 3, report!" (`RadioCheck`): a crew member holds "Answer" 2 s on the bubble within 6 s → no alarm points (the +10 prank points are waived). Missed → +40, guard leaves the bubble angry. Max 2 answers per round; after that every bubble costs +40 | None |
| **Escape vehicle arrival** | Per heist `VanArrival` (e.g. Tulip Auction: getaway boat arrives at 4:00): until `VanArrivesAt` the exit has no drive prompt; same mechanism as the loud recall | `Exit` attribute `ArrivesAt` (seconds) |

### 7.4 Perks / skill tree

Meta grants skill points by rank (proposed 1 per rank from Rank 2) and stores `perks = {[perkId]: level}`. Mechanics
reads them once at Briefing: `ProgressionService:GetPerks(player)` → `Logic/Perks.apply(Config defaults, perks)` →
per-player stats, served by **`LoadoutService:StatsOf(player)`**. Rule for all mechanics code: per-player numbers
(speeds, pocket size, throw range, hide time, rescue/self-escape time, CRACK radius, charges) come from `StatsOf`, never
straight from `Config`. Perks are small sidegrades (each one ≤ 15%), earned by playing, never sold.

| Branch | Perks (one level each, proposed) |
|---|---|
| Sneak | Soft Shoes (crouch 8 → 9) · Barrel Lungs (sneeze at 25 s) · Quiet Crowbar (CRACK 25 → 18) |
| Muscle | Strong Back (heavy alone 7 → 8) · Deep Pockets (4 pocket slots) · Long Arm (throw 10 → 12) |
| Crew | Quick Hands (rescue 2 → 1.5 s) · Escape Artist (self-escape after 12 s) · Spare Batteries (+1 charge on your first gadget) |

---

## 8. Payout inputs, stars, awards

The formula, Rep, daily ×2 and the `Payout` message belong to meta (`EconomyService:SettleRound`, `Logic/Payout`;
`beta-spec-meta.md` §3.4). Mechanics fills `RoundResult` once per round (idempotent by `roundId`), including
`stars`, `maxAlarmTier`, `mainLootBanked`, per-player `inVanAtEnd` and `stats`, plus **`difficulty`**, **`objectives`**
and per-player **`award`** (additions requested from meta). Note: the brief's example "four players, 3,000 → 1,088 each"
needs round-half-up; meta's spec rounds down (1,087).

**Stars** (heist `Stars`, map 1): 1★ van loot ≥ 500 · 2★ ≥ 1,500 · 3★ Gouda banked and ≥ 2,500 (raw value).

**Awards** (`Logic/Awards`): every crew member gets one, in this priority, no duplicates: Gouda Getter (banked the
Gouda) · Jailbreaker (most rescues) · Bubble Hero (dropped a captive off a guard) · Just Made It (entered the van in the
last 5 s) · Self-EMP Award · Achoo! (sneezed out) · Karel's Nemesis (≥ 2 traces cleaned up after you) · Butterfingers
(≥ 2 uncaught drops/throws) · Oops, Bubbled (bubbled a teammate) · Cheese Cannon (≥ 2 throws caught) · Dog Whisperer
(fed Boef) · Safecracker (restarted the device) · Cell Regular (caught ≥ 2) · Ghost (banked loot, never fully seen) ·
Pack Mule (most value banked) · Sightseer (fallback). ux maps ids to icons (reconcile ids with meta/ux).

---

## 9. Architecture and contracts

### 9.1 Server services

| Service | Status | Owner | Responsibility |
|---|---|---|---|
| `RoundService` | Rewrite | mechanics | State machine, timers, Garage van countdown, JUMP IN, drive, end conditions, `RoundResult`, round attributes |
| `SetupService` | New | mechanics | Reads the level into `heistInfo`, runs `RoundPlan`, applies entrances, exits, Gouda, modifiers, difficulty; spawns loot, guards, NPCs, objectives |
| `LootService` | New | mechanics | Registry, anchors, prompts, states, banking, sessions, fragile, Karel return API |
| `CarryService` | New | mechanics | Pocket, hold, throw/catch, drop, roll, two-carry, `DropAll(player, reason)`, `HandsFull(player)` |
| `MovementService` | New | mechanics | Only writer of `WalkSpeed`/`JumpHeight` (`Logic/Movement` + `StatsOf`); handles `Crouch` |
| `CaptureService` | New | mechanics | Grab, carry, cell, rescue, self-escape, hero drop, immunity, all-caught |
| `GuardService` | Changed | mechanics | Many guards from the plan, new numbers, pathfinding on chase/carry, `Carrying`, lockdown radio, modifiers/difficulty, noises `thud`/`rumble`/`bark`/`sneeze`/`squeak`/`beep` |
| `HidingService`, `NpcService` (Boef, Karel, Inspector; `src/server/Npc/*`), `ObjectiveService`, `StatsService`, `TutorialService` | New | mechanics | §4, §7.3, §8, §1.6 |
| `GadgetService`, `AlarmService`, `CameraService`, `PingService` | Changed | mechanics | §5, §3.3, crew-only/Power Cut, spot from a cell camera |
| `LoadoutService` | Rewrite | mechanics | Reads meta loadout, per-player charges, `StatsOf` |
| `DevService` | Extended | mechanics | §10 commands |
| `ChainCallService` | Deleted | mechanics | — |
| `MapService` | Changed | map | `BuildGarage`, `BuildMiniJob`, bounds Terrain clearing |
| Data, Economy, Lobby, Shop, AnalyticsTracker | New | meta | `beta-spec-meta.md` |

Signals for other roles: `RoundService.PhaseChanged(phase)`, `LootService.Banked(player, lootType, value)`,
`CaptureService.Changed(player, stage)`, `StatsService.Event(name, player, data)`.

**Client (mechanics):** `CarryController` (throw aim with the same arc maths, `LootThrow`/`Drop`/`LetGo`/`Roll`, wheel
spin, two-carry smoothing), `HidingController`; `GadgetController`/`DroneController` set `ClientState.mode`. Proposed
keys: Drop G, Roll V, LetGo G (ux owns bindings and all screens).

### 9.2 Net messages

**Client → server** (wrong types ignored, per-player rate limits, state re-checked):

| Name | Payload | Validation |
|---|---|---|
| `LootThrow` | `target: Vector3` | Holding medium/rare alone; finite; clamp 10; 0.4 s cooldown. (ux's draft `Throw` collides with the gadget `Throw`) |
| `Drop` / `LetGo` | — | Leader holding loot / helper |
| `Roll` | `on: boolean` | Holding `CanRoll` heavy alone |
| `HideExit` | — | `Hidden`, ≥ 0.5 s inside |
| `CrawlOut` | — | `Captured = "Cell"`, now ≥ `SelfEscapeAt`, not used |
| `ViewCam` | `index: number` | In the cell or spectating; 1/s; server streams around the camera |
| `Spectate` | `userId: number` | `Garage` during a heist; target is crew |
| `JumpIn` | — | `Garage`, now < `JumpInUntil`, crew < 4 |
| `NextJob` / `ReturnToGarage` | — | Phase Payout or NextJob |
| `Spot` (changed) | `inst, pos, camIndex?` | With `camIndex`: in the cell, camera enabled, `pos` in its range |
| `Crouch` (moved) | `on: boolean` | Not holding medium/heavy |
| `Throw`, `Drone`, `DroneSpot`, `Quick` | unchanged | + hands empty, `InRound` |
| `RestartRun` | — | Becomes Studio-only `DevRestart` |

Prompts (no message): `GrabPrompt`, Hide, Free crew, Drive, JUMP IN, Give cheese, Karel snatch, door Open, keycard door,
safe device Place/Restart, Answer radio. All `Style = Custom` for ux's context button.

**Server → client** (mechanics; meta owns `Payout`, `JobBoard`, `Onboarding`):

| Name | To | Payload |
|---|---|---|
| `JobCard` | crew | `{heistName, difficulty, modifier?, goudaZone, goudaPos, lockedEntrances, objectives, stars, secondExit}` |
| `LootPicked` / `LootBanked` | session | `userId, lootName, class, value` / `+ vanTotal` |
| `LootDropped` / `LootThrown` / `LootCaught` / `LootReturned` / `LootDamaged` | session | `userId?, lootName, from?, to?` |
| `Spotted` | all | `userId, by ("guard"/"camera"/"dog"/"snitch")` — replaces `GuardAlert`, `CameraSpotted` |
| `Captured` / `Rescued` | all | `userId, stage ("grabbed"/"cell"/"dropped")` / `userId, rescuerId or 0, how ("rescue"/"grate")` |
| `GoudaLifted`, `Lockdown`, `ShiftChange` | all | `userId` / `endsAt, reason` / `endsAt` |
| `DriveWarning` | driver | `userIds` |
| `Escaped` / `Busted` | all | `secondsLeft` / — |
| `Sneeze`, `BoefBark`, `KarelShout` | all | `userId or line, position` |
| `Hint`, `Objective`, `RadioCheck` | player / all / all | `key, text, icon, worldPos?` / `id, state, data` / `guardPos, endsAt` |
| `Caught`, `RunStarted`, `RunEnded`, `GuardAlert`, `CameraSpotted`, Chain* | removed | ux updates `HudController` |
| `Toast`, `Alarm`, `Window`, `Crack`, `EMP`, `Drone*`, `Ping`, `Quick` | unchanged | — |

### 9.3 Attributes

| On | Attributes |
|---|---|
| `ReplicatedStorage` | `RoundPhase` (Garage/Briefing/Heist/Lockdown/Getaway/Payout/NextJob), `RoundId`, `RoundStartedAt`, `RoundEndsAt`, `ShiftChangeAt`, `LockdownEndsAt`, `PoliceAt`, `VanDepartAt`, `VanArrivesAt`, `JumpInUntil`, `HeistId`, `JobName`, `Difficulty`, `Modifier`, `Approach`, `VanLoot`, `CrewSize`, `AlarmLevel` (exists). Times = `workspace:GetServerTimeNow()` |
| Player | `Activity`, `InRound`, `SelfEscapeUsed`, existing `Gadgets`/`Charges_*`/`CrewColor`/`DroneBattery` |
| Character | `Caught` (kept), `Captured` (`Carried`/`Cell`/nil), `SelfEscapeAt`, `ImmuneUntil`, `Hidden`, `HideEndsAt`, `InVan`, `Frozen`, `Slipping`, `CarryClass` (`Medium`/`Heavy`/`Main`/nil), `CarryLoot` (display name), `CarryLootId`, `CarryPartner` (UserId), `CarryRole` (`Lead`/`Help`), `Rolling`, `Pockets` (count), `PocketItems` (comma list), existing `Crouching`/`Operating`/`Bubbled` |
| Loot | `LootId`, `LootType`, `LootName`, `LootClass`, `Value`, `BaseValue`, `LootState`, `CarrierId`, `HomeAnchor`, `DroppedAt`, `Session` |
| Doors | `DoorState`, `ClosedCFrame`, `LoudOnly` |

### 9.4 Tags (mechanics block in `Tags.luau`; M = placed by map)

`Loot`, `Trace` (`TraceKind`, `TraceBy`), `Npc`; M: `LootAnchor`, `BankZone`, `Exit`, `Entrance`, `HideSpot`, `Cell`,
`CellSpot`, `CellDoor`, `CellDropoff`, `CellExit`, `CellGrate`, `DogZone`, `KarelHome`, `HazardAnchor` (8–12 per heist),
`GarageVan`, `TutorialTrigger` (`Step`), `KeycardDoor`, `Safe`. Meta's Garage tags (`JobBoard`, `GadgetRack`,
`GarageZone`, …) are in meta's block.

### 9.5 Config (mechanics block; key names and defaults)

```lua
Config.Round = { RoundSeconds = 480, ShiftWarningSeconds = 60, GarageCountdown = 15, AllAboardCountdown = 3,
	BriefingSeconds = 5, StreamTimeout = 5, DriveHoldSeconds = 3, DriveConfirmSeconds = 5, GetawaySeconds = 4,
	JustMadeItSeconds = 5, PayoutSeconds = 30, PayoutMinSeconds = 8, NextJobSeconds = 10, JumpInSeconds = 120,
	BustedDelay = 1.5, MaxCrew = 4 }
Config.Movement = { Walk = 16, Crouch = 8, Medium = 12, HeavySolo = 7, HeavyRoll = 11, TwoCarry = 12, Jump = 7.2,
	MediumJump = 3.5, SlipSeconds = 1 }
Config.Loot = { GrabRange = 6, HeavyGrabHold = 0.3, PocketSlots = 3, RareChance = 0.05, RareMax = 1, ReturnDelay = 30,
	BankCheckInterval = 0.2, FragilePenalty = 0.25, FragileMinFactor = 0.25, ThudRadius = 12, SplashReturn = 3,
	PracticeReturn = 10, TeleportGuardStuds = 40,
	Types = { -- optional per type: Fragile, Prop, Display
		CheeseCube = { Class = "Small", Value = 25, Smelly = true }, TipJar = { Class = "Small", Value = 50 },
		CashDrawer = { Class = "Small", Value = 150 }, Keycard = { Class = "Small", Value = 0 },
		CheeseWheel = { Class = "Medium", Value = 150, Smelly = true, RareSwap = "BlueMoon" },
		BlueMoon = { Class = "Medium", Value = 500, Smelly = true, Rare = true },
		BigWheel = { Class = "Heavy", Value = 400, Smelly = true, CanRoll = true },
		GoldenGouda = { Class = "Main", Value = 1500, Smelly = true, CanRoll = true, Lockdown = true } } }
Config.Carry = { ThrowRange = 10, ThrowSpeed = 28, ThrowMin = 0.3, ThrowMax = 0.8, ThrowArc = 0.35, ThrowCooldown = 0.4,
	CatchFlight = 3.5, CatchLanding = 5, SelfCatchDelay = 0.3, Tether = 9, RumbleRadius = 15, RumbleInterval = 1,
	RumbleSearch = 4 }
-- Config.Guard: FillSecondsNear = 0.8, FillSecondsFar = 2.0, ChaseSpeed = 15; new: CarryFillRate = { Medium = 1.25,
--   Heavy = 1.5 }, LostSeconds = 3, GrabSeconds = 1, CarrySpeed = 8, Tier2PatrolSpeed = 7.5, LockdownFillRate = 1.33,
--   LockdownRadioInterval = 8, PathRecompute = 0.5, CountByCrew = { 2, 3, 3, 4 }, FlashlightRange = 22, SeenEnteringMeter = 0.35
Config.Npc = { Cap = 7 }
Config.Capture = { RescueHold = 2, SelfEscapeAfter = 15, SelfEscapes = 1, ImmuneSeconds = 3, MaxCarrySeconds = 40,
	Scatter = 2, AllCaughtDelay = 1.5 }
Config.Hiding = { Enter = 0.5, Exit = 0.5, WarnAt = 15, SneezeAt = 20, SneezeRadius = 15, Reentry = 5, PullOut = 4 }
Config.Dog = { WanderSpeed = 6, FollowSpeed = 12, FollowDistance = 4, Smell = 15, BarkInterval = 2, BarkRadius = 30,
	EdgeBark = 3, TreatRange = 10, TreatSeconds = 12, NoisemakerSeconds = 8, NoisemakerRadius = 20 }
Config.Karel = { Rest = 60, RestJitter = 15, Tier1RestFactor = 0.5, Speed = 7, Notice = 25 }
Config.Snitch = { Range = 25, KarelFill = 0.5, InspectorFill = 0.67, Points = 20, GuardsAlerted = 2, Cooldown = 30,
	InspectorSpeed = 6 }
Config.Loadout = { Slots = 2, Pickable = { "Drone", "Noisemaker", "EMP", "BubbleBlaster" } }
-- Config.Gadgets: Noisemaker.DistractSeconds = 8, RingSeconds = 8; EMP.DisableSeconds = 10; BubbleBlaster.BubbleSeconds = 8.
-- Config.Alarm.LockdownSeconds = 60. Config.Difficulty becomes the tier table of §7.1 (Default = "Normal").
Config.Modifiers = { PowerCut = { FlashlightRange = 22 }, HealthInspector = {}, WetFloor = { Puddles = 6,
	SlipSpeed = 10, SqueakRadius = 15 }, RushJob = { RoundSeconds = 360 }, SleepyGuards = { FillRate = 0.7 },
	DoubleShift = { ExtraGuards = 1 } } -- payout percentages: meta's Config.Economy.ModifierBonus
Config.Tutorial = { MaxSlots = 2, StirRadius = 6, WakeRange = 20, LockdownSeconds = 60 }
Config.Features = { Difficulty = false, Objectives = false, LoudExtras = false, Perks = false } -- §7 switches
Config.Objectives = { BonusPct = 0.10, DevicePlace = 2, DeviceSeconds = 60, DeviceJams = { 1, 2 }, DeviceRestart = 1.5,
	BeepInterval = 3, BeepRadius = 12, KeycardHold = 1, RadioDelay = 4, RadioWindow = 6, RadioAnswerHold = 2,
	RadioMissPoints = 40, RadioMaxAnswers = 2, VanReturnSeconds = 30, PanicPackCharges = 1 }
```

`Config.World` is in the map block; economy in the meta block.

### 9.6 Pure logic (`src/shared/Logic/`, tests in `tests/logic/<Name>.spec.luau`)

| Module | API | Must test |
|---|---|---|
| `Movement` | `resolve(flags, stats)` → `{walkSpeed, jumpHeight, canCrouch, canGadget}`; priority Frozen > Caught > Hidden > Bubbled > Slipping > Operating > carry > crouch > walk | Every speed row; priority |
| `Detection` | `fillSeconds(distance, range, factors)`, `levelFor(points, thresholds)` | 0.8/2.0; factors multiply |
| `RoundClock` | `status(now, startedAt, roundSeconds, lockdownAt?, lockdownSeconds)` → `{policeAt, shiftChange, remaining}` | Lockdown at 7:59; during shift change; Rush Job |
| `RoundPlan` | `generate(seed, heistInfo, crewSize, job)` → loot, Gouda, entrances, exit, routes, hazards, objectives | Determinism; counts ≤ anchors; ≤ 1 rare; priority routes |
| `NpcBudget` | `guardCount(crew, base, bonuses, others, cap)` | §4.4 |
| `Difficulty` | `apply(base, tier)` | Each column of §7.1 |
| `Perks` | `apply(defaults, perks)` → stats | Each perk; unknown ids ignored |
| `Awards` | `assign(statsByPlayer)` | One each, no duplicates, fallback |
| `Throw` | `clampTarget`, `timing`, `point` on plain `{x, y, z}` tables | Clamp, peak, ends |
| `LootRules` | `canPick`, `pocketAdd`, `fragileValue` | Hands/pocket rules; floor |
| `CrackDevice` | `step(state, dt, jamTimes)` → progress, jammed | Jams stop progress; restart |

(`JobBoard` and `Payout` are meta's.)

### 9.7 Heist definition fields (map adds; `Registry.Heist` type extended)

`Rank` (1/3/5) · `Description` · `GuardBonus` (0; maps 2–3: 1) · `HasDog` · `ExtraNpcs` · `Loot` (`{ {Type, Count} }`)
· `Stars` (`{500, 1500, 2500}`) · `RoundSeconds?` · `Bounds` · `LoudEscape` (`"Stay"`/`"Recall"`) · `Objectives?` ·
`Points.Spawn` (exists) · `Points.GuardRoutes` (`{ {Id, Priority, Variants = { { {Pos, Wait?} } } } }`, ≥ 6 routes,
2 variants, y = 0, straight legs) · `Points.KarelRoute` · `Points.DogRoute`. `GuardStart`/`GuardRoute` stay as a fallback
until map 1 has `GuardRoutes`.

### 9.8 Needs from other roles

- **Map** — per heist: anchors (§2.6), van + optional boat exit, 4 entrances, 8–12 hide spots, cell, routes, `KarelHome`,
  `DogZone` (map 1), hazard anchors, `Bounds`, objectives props (maps 2–3: a safe, a keycard door). Garage: `GarageVan`
  zone (±12×8×12) with a `DrivePoint`, practice yard `BankZone` (`Session = Practice`) + 2 wheel anchors, plus meta's
  tags. Mini-job (±40×30): fixed wheel 15 studs from spawn, Gouda, van exit, sleeping-guard spot, 1 barrel, triggers.
- **UX** — screens for every message and attribute above (job card, POLICE IN/van timers, carry buttons with arc,
  pockets, capture/cell/hide views, drive warning, getaway, objectives list, radio-check prompt, hints).
- **Meta** — `LobbyService:GetSelectedJob(boarders)` returning `{mapId, difficulty, modifierId?, mostWanted}`;
  `ShopService:GetLoadout`; `ProgressionService:GetPerks` (pending); `EconomyService:SettleRound` accepting
  `difficulty`, `objectives`, `award`; `AnalyticsTracker:OnboardingStep`/`:RoundStep`; `DataService:WaitForData`.

---

## 10. Test plan (tester, Studio "Server & Clients", 1–4 players)

Studio-only dev commands: `DevJob(heistId, difficulty?, modifier?, seed?)`, `DevClock(elapsed)`, `DevGive(lootType)`,
`DevAlarm(points)`, `DevCapture()`, `DevFree()`, `DevPhase(phase)`, `DevTutorial()`, `DevRestart()`, existing
`DevTake`/`DevPry`.

| Area | Scenario | Expected |
|---|---|---|
| Flow | Solo steps into the Garage van | 3 s → 5 s job card → GO at the heist van |
| Flow | 2 players, 1 boards | 15 s countdown; other stays Garage with JUMP IN until 2:00; JUMP IN at 1:59 works, at 2:01 gone |
| Flow | Join mid-heist | Garage banner with correct time; spectate works |
| Flow | `DevClock(419)`; wait | Shift change at 7:00; police at 8:00 catch everyone outside the van |
| Flow | Gouda at 3:00 / at 7:59 / lockdown at 7:20 | Police at 4:00 / after 1 s / still 8:00 |
| Flow | Drive with a free teammate outside | Warning; second hold drives; teammate half share |
| Flow | Everyone leaves mid-heist; NextJob with nobody ready | Garage, no errors / Garage |
| Flow | All crew press NEXT JOB at 3 s into Payout | Skips at 8 s; Briefing of the voted job |
| Loot | 4th small item; wheel in hands | "Pocket full"; speed 12, no crouch, gadgets/Crowbar refused |
| Loot | Two players trigger one wheel together | One gets it, other "Too slow!" |
| Loot | Two players on a Big Wheel; walk 10 studs apart | 7 → 12 each; helper loses grip |
| Loot | Roll the Gouda 14 studs from a guard | Guard investigates |
| Loot | Throw into a wall at 2 studs / into the canal / into the van | Lands on the floor, not in the wall / "Splash!", home in 3 s / banked for the thrower |
| Loot | Throw to a teammate 8 studs away; chase your own throw | Teammate catches; thrower can't in the first 0.3 s |
| Loot | Walk into the van with 3 cubes + a wheel | All banked at once, `VanLoot` correct |
| Loot | Same seed twice; 50 seeds | Identical rounds; never > 1 Blue Moon; Gouda on a Main anchor |
| Death/leave | Fall/die while carrying; carrier leaves; two-carry leader leaves | Loot dropped (void → home), respawn at heist van; dropped at last spot; helper keeps it at 7 |
| Guards | Crew 1/2/3/4 (+ Double Shift) | 2/3/3/4 (3/4/4/5) guards on map 1 |
| Guards | Empty hands vs chase; carrying a wheel in view | Escape, 15 s search; meter fills 1.25× faster |
| Capture | Grabbed with a wheel + 2 cubes | Loot scatters; carried at 8 to the cell |
| Capture | Bubble / Noisemaker on the carrying guard | Captive dropped, 3 s immunity |
| Capture | Rescue 2 s; CRAWL OUT at 15 s, then caught again | All freed at `CellExit`; out at `CellGrate`, no second button |
| Capture | Captive leaves while carried; dies in the cell | Guard searches; respawn in the cell |
| Capture | Solo grabbed; all 4 caught | BUSTED after 1.5 s |
| Hiding | With a wheel; unseen; while a meter is at 50%; 20 s | Refused; safe; pulled out → captured; warn 15 s, ACHOO 20 s, 5 s lockout |
| Boef | Cheese past Boef; Cash Drawer only; give a cube | Follows + barks; ignores; busy 12 s |
| Karel | Pry a door; drop a wheel 30 s | Closes it (+20 once, silent reopen); returns it, snatch works |
| Gadgets | Loadout from meta; EMP own drone; gadget while holding | Charges reset each round; Self-EMP award; "Hands full!" |
| Modifiers | Each of 6 via `DevJob` | Effects of §6.2 visible |
| Tutorial | Fresh account; 2 newcomers + running crew | Mini-job at once, steps 1–5 fire, cannot fail, ends in Garage; parallel, third waits |
| §7 (when on) | Each difficulty; safe jams twice solo; radio check answered / missed; keycard door; van recall | Numbers of §7.1; progress stops and restarts; 0 / +40; opens only with the card; no drive until `VanArrivesAt` |
| Perf | 4 players, map 1, Double Shift | 7 NPCs, ≥ 30 fps on a cheap phone |

---

## 11. Build order

| WP | Role | Files | Depends on |
|---|---|---|---|
| **WP0 Contracts** (1 day, merged first) | mechanics + meta stubs | `Tags`, `Config` (all keys), `Registry` type (optional fields), `Logic/*` signatures, Net names list, meta API stubs with defaults | — |
| M1 Movement + loot | mechanics | `MovementService`, `LootService`, `CarryService`, `CarryController`, `Logic/{Movement,LootRules,Throw}` | WP0; A1 anchors (test anchors meanwhile) |
| M2 Round | mechanics | `RoundService`, `SetupService`, `StatsService`, `Logic/{RoundClock,RoundPlan,NpcBudget,Awards}` | M1; meta stubs |
| M3 Guards + capture | mechanics | `GuardService`, `CaptureService`, `AlarmService`, `CameraService`, `PingService`, `Logic/Detection` | M2; A1 cell/routes |
| M4 NPCs, hiding, modifiers | mechanics | `HidingService`, `HidingController`, `NpcService`, `src/server/Npc/*` | M3 |
| M5 Gadgets + tutorial | mechanics | `GadgetService`, `LoadoutService`, delete ChainCall, `TutorialService`, `DevService` | M1–M3; A2 |
| M6 §7 hooks | mechanics | `ObjectiveService`, `Logic/{Difficulty,Perks,CrackDevice}`, loud extras | M5; advisor decision |
| A1–A4 | map | GoldenWheel retrofit → Garage + mini-job → Praline Palace → Tulip Auction (cut first) | WP0 |
| U*, T* | ux, meta | Their specs | WP0 names/stubs |

Merge order: WP0 → A1 + M1 → M2 → M3 → A2 + M4 → M5 → M6 → maps 2–3; ux and meta whenever green. After WP0, shared
files change only inside each role's block; each WP owns its files; only M3 edits `GuardService` (others call
`HearNoise` with new `kind`s).

## 12. Open questions for the advisor

1. Pulled out of a hiding spot = straight to the cell (chosen)?
2. Karel as a snitch (+20 when he sees you): allowed under "catches nobody"?
3. Crew members not in the van at the end get half their share (meta's rule) — confirm.
4. Duplicate gadget picks in one crew (4 × Bubble Blaster = 12 bubbles): allow or cap at 2 per kind?
5. §7: tiers, Big Cheese rules, van recall on maps 2–3, objective bonus +10%, radio-check numbers, perk tree — which go
   into the beta and which wait?
