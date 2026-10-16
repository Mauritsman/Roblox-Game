# Crowbar Crew: contracts (single reference)

*WP0, mechanics, 16 Oct 2026. The one place for every Net message, attribute, tag, prompt and cross-role API name.
Derived from `beta-spec.md` §9.2–9.4 and §13, `beta-spec-ux.md` §7.3, `beta-spec-meta.md` §8 and the advisor's final
decisions. When a spec and this file disagree, **this file wins**; changes go through the orchestrator.*

**Conventions**
- Owner column: **mech** = mechanics, **meta**, **map**, **ux**. Spelling in code comes from `src/shared/Tags.luau`
  (tags and attributes) and `src/shared/Config.luau` (numbers).
- All times in attributes and payloads are server times from `workspace:GetServerTimeNow()` (`…At`, `…Until`,
  `endsAt`). Durations are seconds.
- Networking only through `src/shared/Net.luau`: client → server `Net.request(name, …)`, server → client
  `Net.send(player, name, …)` / `Net.broadcast(name, …)`. The server re-checks every request (types, rate limit,
  state). Clients never send amounts, prices or results.
- **Attributes = state** (late-join safe). **Net = moments and snapshots** (missing one is cosmetic).
  **ProximityPrompts = context actions** (no Net message).
- Ids use `heistId` everywhere (never `mapId`).

---

## 1. Net messages

### 1.1 Client → server

| Name | Payload | Owner | Server checks |
|---|---|---|---|
| `LootThrow` | `target: Vector3` | mech | Holding medium/rare alone; finite; clamp to `StatsOf.ThrowRange`; 0.4 s cooldown |
| `Drop` | — | mech | Leader holding loot (two-carry: drops it) |
| `LetGo` | — | mech | Helper of a two-player carry |
| `Roll` | `on: boolean` | mech | Holding `CanRoll` heavy/main loot alone |
| `HideExit` | — | mech | `Hidden`, ≥ 0.5 s inside |
| `CrawlOut` | — | mech | `Captured = "Cell"`, now ≥ `SelfEscapeAt`, self-escapes left |
| `ViewCam` | `index: number` | mech | In the cell or spectating; 1 per s; server streams around the camera |
| `Spectate` | `userId: number` | mech | `Activity = "Garage"` during a heist; target is crew |
| `JumpIn` | — | mech | `Garage`, now < `JumpInUntil`, crew < 4 |
| `NextJob` | — | mech | Phase `Payout` or `NextJob` |
| `ReturnToGarage` | — | mech | Phase `Payout` or `NextJob` |
| `Crouch` | `on: boolean` | mech | Hands not full (`Logic/Movement`) |
| `Spot` | `inst: Instance, pos: Vector3, camIndex: number?` | mech | With `camIndex`: in the cell, camera enabled, `pos` in its range |
| `Throw` | `gadgetName: string, point: Vector3` | mech | Gadget throw (unchanged) + hands not full, `InRound` |
| `Drone` | `"launch" \| "recall"` | mech | Unchanged + hands not full to launch |
| `DroneSpot` | `target: Instance` | mech | Unchanged |
| `Quick` | `preset: string` | mech/ux | Preset in `Config.Ping.QuickPresets`; one shared cooldown (10 s, ux WP1) |
| `ProfileRequest` | — | meta | Loaded; max 1 per 2 s → `ProfileSync` |
| `JobVote` | `cardId: string, difficulty: string` | meta | `cardId` = heistId or `"HotJob"`; Garage or NextJob phase |
| `SetLoadout` | `{string, string}` | meta | 2 distinct owned/free gadgets, not the Crowbar, not `InRound` (ux's `PickGadgets`) |
| `BuyItem` / `EquipItem` | `itemId: string` | meta | Catalog rules (meta §8.2) |
| `UnlockPerk` | `perkId: string` | meta | Free SP ≥ cost, row above unlocked, not `InRound` |
| `EquipPerks` | `{perkId}` (≤ 3) | meta | All unlocked, not `InRound` |
| `RespecPerks` | — | meta | Not `InRound` |
| `RerollContract` | `index: 1–3` | meta | Reroll left |
| `SaveSettings` | `{[string]: boolean \| number}` | meta | Allowlist, clamped, debounced 2 s |
| `TipSeen` | `tipId: string` | meta | Known tip |
| `Feedback` | `mood: 1–3, tags: {string} (≤ 2), roundId: string` | meta | Once per round |
| `PrivateCrewStart` / `PrivateCrewAnswer` | — / `yes: boolean` | meta | Garage, published game |
| `Dev*` | see §1.4 | mech/meta | Studio only (`RunService:IsStudio()`) |

### 1.2 Server → client

| Name | To | Payload | Owner |
|---|---|---|---|
| `JobCard` | crew | `{heistId, heistName, difficulty, modifierId?, isHotJob, mainLootName, mainZone, mainPos: Vector3, lockedEntrances: {string}, objectives: {{id, type, required, bonusPct}}, stars: {number}, secondExit: boolean}` | mech |
| `LootPicked` | session | `userId, lootName, class, value` | mech |
| `LootBanked` | session | `userId, lootName, class, value, vanTotal` | mech |
| `LootDropped` | session | `userId, lootName, position: Vector3` | mech |
| `LootThrown` | session | `userId, lootName, from: Vector3, to: Vector3, duration` | mech |
| `LootCaught` | session | `userId (catcher), lootName, throwerId` | mech |
| `LootReturned` | session | `lootName, position: Vector3` (Karel put it back) | mech |
| `LootDamaged` | session | `lootName, value, pct` (new value, % of base left) | mech |
| `Spotted` | all | `userId, by: "guard" \| "camera" \| "dog" \| "snitch"` (replaces `GuardAlert`, `CameraSpotted`) | mech |
| `Captured` | all | `userId, stage: "grabbed" \| "cell" \| "dropped"` | mech |
| `Rescued` | all | `userId, rescuerId (0 = grate), how: "rescue" \| "grate"` | mech |
| `MainLootLifted` | all | `userId, lootName` (ux's `GoudaLifted`) | mech |
| `Lockdown` | all | `endsAt, reason: "MainLoot" \| "Alarm" \| "Dev"` (prototype sends `seconds` until M2) | mech |
| `ShiftChange` | all | `endsAt` | mech |
| `DriveWarning` | driver | `userIds: {number}` (free crew outside) | mech |
| `Escaped` | all | `secondsLeft` | mech |
| `Busted` | all | — | mech |
| `Sneeze` | all | `userId, position: Vector3` | mech |
| `BoefBark` | all | `userId?, position: Vector3` | mech |
| `KarelShout` | all | `line: string, position: Vector3` | mech |
| `Hint` | player | `key, text, icon, worldPos: Vector3?` (≤ 5 words) | mech |
| `Objective` | crew | `id, state: "Locked" \| "Active" \| "Running" \| "Jammed" \| "Done" \| "Failed", data: {progress?, jamsLeft?, holderId?, onGuard?}` | mech |
| `RadioCheck` | crew | `guardPos: Vector3, endsAt, answersLeft` | mech |
| `Toast` | player/all | `text` (exists) | mech/meta |
| `Alarm` | all | `points, level, reason, added` (exists) | mech |
| `Window` | all | `label, seconds, position` (exists; ux shows it as an effect chip) | mech |
| `Crack` | all | `position, heard, playerName` (exists) | mech |
| `EMP` | all | `position, radius, cameras, lamps, drones` (exists) | mech |
| `DroneStarted` / `DroneEnded` | owner | `drone: BasePart` / `reason: string` (exist) | mech |
| `Ping` | all | `{id, kind, target, position, from, color, duration, auto}` (exists) | mech |
| `Quick` | all | `fromName, preset, color, userId` (exists) | mech |
| `ProfileSync` | player | meta §2.6 (covers ux's `Contracts`, `Settings`, `Catalog` snapshots) | meta |
| `Payout` | each crew member | meta §8.2 (`awards: {{userId, awardId}}`, …) | meta |
| `RankUp` | player | `newRank, title, unlocks, skillPoints` | meta |
| `JobBoard` | all | meta §8.2 | meta |
| `Onboarding` | player | `step` (meta maps step names to numbers) | meta |
| `MetaResult` | player | `action, ok, id, reason` | meta |
| `SaveStatus` | player | `"Ok" \| "Trouble" \| "Memory"` | meta |
| `PrivateCrewInvite` | player | `fromName, seconds` | meta |

### 1.3 Removed (prototype)

`Caught`, `RunStarted`, `RunEnded`, `GuardAlert`, `CameraSpotted`, `ChainCall`, `ChainCountdown`, `ChainEnd`,
`ChainNow` (server → client); `ChainCall`, `ChainJoin`, `ChainGo`, `RestartRun` (client → server; `RestartRun`
becomes `DevRestart`). They stay in today's code until the work package that replaces them (M2/M5); ux updates
`HudController`.

### 1.4 Studio-only dev requests

Mechanics: `DevJob(heistId, difficulty?, modifierId?, seed?)`, `DevClock(elapsed)`, `DevGive(lootType)`,
`DevAlarm(points)`, `DevCapture()`, `DevFree()`, `DevPhase(phase)`, `DevTutorial()`, `DevRestart()`,
`DevTake(gadget)`, `DevPry(name)`. Meta: `DevData(cmd, …)`.

### 1.5 Prompts (ProximityPrompt, no Net message)

All `Style = Custom`, `KeyboardKeyCode = E`, `GamepadKeyCode = ButtonX`, optional attribute `ContextIcon` (ux).
Proposed `Name`s (for tests and ux): `GrabPrompt` ("Pocket" / "Grab" / "Lift" / "Help carry"; also snatching loot
back from Karel), `HidePrompt`, `FreePrompt` (cell door, 2 s), `DrivePrompt` (3 s), `JumpInPrompt` (Garage van),
`TreatPrompt` ("Give cheese", Boef), `OpenPrompt` (door Karel closed), `KeycardPrompt` (1 s), `DevicePrompt`
("Place" 2 s / "Restart" 1.5 s), `RadioPrompt` ("Answer" 2 s), `PickpocketPrompt` (1.5 s, behind a guard). Meta's
Garage station prompts are meta's.

---

## 2. Attributes

### 2.1 `ReplicatedStorage` (mech)

| Attribute | Values |
|---|---|
| `RoundPhase` | `Garage` · `Briefing` · `Heist` · `Lockdown` · `Getaway` · `Payout` · `NextJob` |
| `RoundId` | GUID string |
| `RoundStartedAt`, `RoundEndsAt`, `ShiftChangeAt`, `LockdownEndsAt`, `PoliceAt` | server time; `PoliceAt` is the one HUD timer |
| `VanDepartAt` | server time of the Garage van departure (nil = no countdown) |
| `ExitArrivesAt` | maps 2–3: when the lockdown exit can be used (replaces the spec's `VanArrivesAt`) |
| `JumpInUntil` | server time |
| `HeistId`, `JobName` | e.g. `GoldenWheel`, `The Golden Wheel` |
| `Difficulty` | `Easy` · `Normal` · `Hard` |
| `Modifier` | modifier id or nil (only on the Hot Job) |
| `Approach` | `Stealth` · `Loud` (Loud from LOCKDOWN) |
| `VanLoot` | banked base value |
| `CrewSize` | number |
| `AlarmLevel` | 0–3 (exists) |

### 2.2 Player

| Attribute | Owner | Values |
|---|---|---|
| `Activity` | mech | `Garage` · `Crew` · `Tutorial` |
| `InRound` | mech | `Activity ~= "Garage"` |
| `SelfEscapeUsed` | mech | count used this round |
| `Gadgets`, `Charges_<Gadget>`, `CrewColor`, `DroneBattery` | mech | exist |
| `Slots` | mech | DEPRECATED (M5) |
| `DataLoaded`, `Cash`, `Rep`, `Rank`, `Title`, `IsNewPlayer`, `RoundsPlayed`, `HeistsUnlocked`, `Loadout`, `Perks`, `MaskId` | meta | meta §2.6 (lists are comma-separated) |

### 2.3 Character (mech)

| Attribute | Values |
|---|---|
| `Caught` | boolean (grabbed, carried or celled) |
| `Captured` | `Carried` · `Cell` · nil |
| `SelfEscapeAt`, `ImmuneUntil`, `HideEndsAt` | server time |
| `Hidden`, `InVan`, `Frozen`, `Slipping`, `Rolling`, `Bubbled`, `Crouching`, `Operating` | boolean |
| `Masked` | boolean — Mask Up: false/nil = unmasked, ignored by guards and cameras; meta renders the mask |
| `CarryClass` | `Medium` · `Heavy` · `Main` · nil (pocket loot is in `Pockets`) |
| `CarryLoot`, `CarryLootId` | display name, `LootId` |
| `CarryPartner` | UserId of the other carrier |
| `CarryRole` | `Lead` · `Help` |
| `Pockets` | count (0 … `StatsOf.PocketSlots`) |
| `PocketItems` | comma-separated display names |

### 2.4 Loot models (mech)

`LootId`, `LootType` (key of `Config.Loot.Types`), `LootName` (display), `LootClass` (`Small` · `Medium` · `Heavy` ·
`Main`), `Value`, `BaseValue`, `LootState` (`Placed` · `Carried` · `Thrown` · `Dropped` · `Returning` · `Banked`),
`CarrierId`, `HomeAnchor` (AnchorId), `DroppedAt`, `Session` (`Crew` · `Tutorial1` · `Tutorial2` · `Practice`).

### 2.5 Map-placed objects (map sets, mech reads)

| On | Attributes |
|---|---|
| `LootAnchor` | `AnchorClass` (`Small`/`Medium`/`Heavy`/`Main`), `AnchorId` (unique), `Zone`, `Group?` (`Keycard`, a safe id, map loot), `Fixed?`, `Opener?` (first-loot spot; `RoundPlan` fills ≥ 1) |
| `Entrance` | `EntranceId`; child `LockedBlocker` |
| `Exit` | `ExitKind` (`Van` · `Boat` · `Bike` · `Balloon`), `Optional?`, `QuietOnly?`, `LockdownOnly?`, `ArrivesAt?` (seconds after LOCKDOWN); children `BankZone` (+ `Session`) and `DrivePoint` |
| `HideSpot` | `HideKind` (`Barrel` · `Crate` · `Locker` · map kinds such as `TallCask`, `Dumpster`); PrimaryPart Attachments `Inside`, `Exit`. Hidden players are made invisible and parked at `Inside`, so a prop only needs to be ≥ 4 studs tall |
| `TutorialTrigger` | `Step` (onboarding step name) |
| `KeycardDoor` | `Card` (keycard objective id) |
| `Safe` | Attachment `DeviceSpot`; loot anchors with `Group = <safe id>` |
| `LockdownSwitch` | `Action` (`Close` · `Open` · `Speed` · `On`) |
| `Ride` (folder) | `RideId`, `Seats` (riders or loot per car), `Speed`, `LockdownSpeed?`; child Attachments named `Station` with `Boarding` (bool), `Stop` (bool: STOP window where guards can grab riders), `LockdownOnly?`; path in the heist's `Points.Rides[RideId]` |
| `RhythmMachine` | `Kind` (`Fountain` · `Mixer` · `Wrapper` · `Mist` · `Clock`), `Period`, `Active`, `Radius` |
| `MorningLight` | `Step` (1–3) |
| `RisingPlinth` | `RiseHeight` |
| `Pryable` doors | `PrySeconds` (exists), `DoorState` (`Closed` · `Open`), `ClosedCFrame`, `LoudOnly?` |
| `Trace` (mech sets) | `TraceKind` (`OpenDoor` · `DroppedLoot` · `Noisemaker`), `TraceBy` (UserId) |
| `Npc` (mech sets) | `NpcKind` (`Karel` · `Boef` · `Inspector`) |
| Guards (mech) | `GuardState` (exists) |

Other existing attributes: `Disabled` (Electronic), `Owner` (drone), `SpotKind` (spottable).

---

## 3. Tags

| Tag | Placed by | Notes |
|---|---|---|
| `Loot`, `MainLoot` | mech | Every loot Model; `MainLoot` also on the heist's main loot (ux beam/crown) |
| `Trace`, `Npc` | mech | Karel's targets; Karel/Boef/Inspector (replaces ux's proposed `Karel` / `Dog` tags) |
| `LootAnchor`, `BankZone`, `Exit`, `Entrance`, `HideSpot` | map | `BankZone` replaces ux's proposed `VanZone` |
| `Cell`, `CellSpot`, `CellDoor`, `CellDropoff`, `CellExit`, `CellGrate` | map | Cell contract (beta-spec §3.4) |
| `DogZone`, `KarelHome`, `HazardAnchor`, `GarageVan`, `TutorialTrigger`, `KeycardDoor`, `Safe` | map | |
| `StaffZone`, `SecureZone` | map | Volumes. Staff: Mask Up (entering puts the mask on; outside = public). Secure: job card, analytics |
| `LockdownSwitch` | map | Maps 2–3 lockdown changes |
| `SeeThrough` | map | Guards and cameras see through it (cage mesh, cell bars): vision raycasts ignore it. Replaces the hard-coded `Cage` folder rule, which stays as a fallback |
| `GuardDoor` | map | Opens automatically for guards (e.g. Tulip cold rooms) |
| `Ride` | map | Server-moved welded seats (Praline Box Rail, Tulip trolley train, chutes, vents); never free physics |
| `ColdZone`, `GooZone` | map | Volumes: melting stops / chocolate river (slow walk, SPLOSH noise) |
| `RhythmMachine`, `LaserGrid` (+ `Electronic`), `MorningLight`, `RisingPlinth` | map | Maps 2–3 set pieces (attributes in §2.5) |
| `PracticeTarget` | map | Garage practice-yard baskets (mechanics) |
| `GarageTV`, `TrophyBoard` | map | Garage: ux WATCH station / meta's "Most Goudas" text (map block) |
| `Electronic`, `SecurityCamera`, `Lamp`, `Guard`, `Pryable`, `Drone`, `Spottable` | exist | Keep; folder `Cage` stays as the see-through fallback |
| `GadgetPedestal`, `Goal` | exist | Removed from map 1 by the retrofit; the tags stay until then |
| `JobBoard`, `GadgetRack`, `Workbench`, `Mirror`, `TrophyWall`, `TrophySlot`, `CollectionBook`, `VanPaint`, `GarageZone` | map/meta | Meta's block in `Tags.luau` |

**Reserved module name:** `src/shared/LightingPresets.luau` (map: lighting presets as data; ux applies them on the
client by the player's area / `Activity`; the server keeps applying the heist preset as a fallback). Not built in
WP0.

**Guard routes** (`Points.GuardRoutes`) may include upper floors (y 9); a leg that changes floor uses pathfinding.

---

## 4. Cross-role server APIs

**Mechanics provides**
- Signals: `RoundService.PhaseChanged(phase)`, `LootService.Banked(player, lootType, value)`,
  `CaptureService.Changed(player, stage)`, `StatsService.Event(name, player, data)`.
- `LoadoutService:StatsOf(player)` → `Logic/Perks` Stats (every per-player number).
- One `EconomyService:SettleRound(result)` call per round (Getaway, Busted, mini-job end, shutdown hook) with
  `RoundResult` exactly as in `beta-spec-meta.md` §3.4: `roundId, heistId, difficulty, modifierId?, isHotJob,
  outcome ("Escaped"|"Busted"|"Aborted"|"Shutdown"), vanLoot, stars, mainLootBanked, maxAlarmTier, lockdownAtEnd,
  durationSeconds, objectives {{id, bonusPct}}, banked {{lootId, name, class, value}}, crew {{player, inVanAtEnd,
  award, stats}}`.

**Meta provides**
- `LobbyService:GetSelectedJob(boarders)` → `{cardId, heistId, difficulty, modifierId?, isHotJob}`.
- `ShopService:GetLoadout(player)` → `{"Crowbar", a, b}`.
- `ProgressionService:GetPerks(player)` → `{[perkId] = 1}` (equipped, ≤ 3); `:CrewHeists(players)`,
  `:CrewTiers(players, heistId)`, `:IsTutorialDone(player)`, `:RoundsCompleted(player)`.
- `EconomyService:SettleRound(result)`; `DataService:WaitForData(player)`, `DataService:OnBeforeShutdown(fn)`.
- `AnalyticsTracker:OnboardingStep(player, name)`, `AnalyticsTracker:RoundStep(player, roundId, name)`.

**Funnel step names (reported by name; meta maps them to numbers)**
- Onboarding — mech: `Spawned`, `Moved`, `FirstLootGrabbed`, `FirstLootBanked`, `SneakedPastGuard`, `GoudaLifted`;
  meta: `MiniJobEscaped`, `GarageReached`.
- Round — mech: `FirstLootGrabbed`, `FirstLootBanked`, `MainLootLifted` (and `VanDeparted` on JUMP IN); meta:
  `VanDeparted`, `Escaped`, `NextJob`.

**Award ids** (`Logic/Awards`, priority order): `GoudaGetter`, `Jailbreaker`, `BubbleHero`, `JustMadeIt`, `SelfEmp`,
`Achoo`, `KarelsNemesis`, `Butterfingers`, `OopsBubbled`, `CheeseCannon`, `DogWhisperer`, `Safecracker`,
`CellRegular`, `Ghost`, `PackMule`, fallback `Sightseer`; mini-job `FreshCrook`. ux maps ids to icons and text.

---

## 5. Config blocks (`src/shared/Config.luau`)

| Block | Owner | Tables |
|---|---|---|
| Mechanics | mech | `Round`, `Movement`, `Loot` (+ `Types`), `Carry`, `Guard`, `SecurityCamera`, `Alarm`, `Gadgets`, `GadgetOrder`, `Loadout`, `Npc`, `Capture`, `Hiding`, `Dog`, `Karel`, `Snitch`, `Modifiers` (effects only), `Tutorial`, `Features`, `Objectives`, `Plan`, `DifficultyTiers`, `Perks` (effects); deprecated prototype keys (`Difficulty`, `WindowSeconds`, `SoloExtraWindow`, `SlotsByCrewSize`, `Player`, `ChainCall`, `windowSeconds`, `slotsFor`) |
| Shared | mech + ux | `Ping` (ux changes presets and the 10 s cooldown in WP1) |
| Map | map | `World` (`GarageOrigin`, `MiniJobOrigins`, …) |
| Meta | meta | `Data`, `Economy` (incl. `DifficultyPayout`, `HotJobBonus`), `Progression`, `PerkTree`, `HotJob`, `Contracts`, `MostWanted`, `Lobby`, `Catalog`, `Collection`, `Monetization`, `Analytics`, `MetaRateLimit` |
| UX | ux | `UX` |
