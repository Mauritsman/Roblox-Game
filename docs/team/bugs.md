# Bugs

Found by the `tester` role in Roblox Studio. Severity: blocker / high / medium / low. Each bug names the role that
owns the fix. Repro scenarios live in `tools/studio_tests/` (see its README). When a bug is fixed, set the status
to `fixed (<commit>)`; the tester re-runs the scenario and sets `verified`.

| Id | Severity | Title | Owner | Status |
|---|---|---|---|---|
| B-001 | medium | All in-world signs are drawn at 8 px (unreadable) | map | fixed (3b97fb9), verified by orchestrator (all 8 labels TextScaled + TextFits) |
| B-002 | medium | Shop front doorway is too narrow for pathfinding agents with radius 2 | map | open |
| B-003 | low | Guard can catch a player without ever showing "!" (Alert lasts 0 frames) | mechanics | fixed (3bf884f: a grab needs 1 s in Alert within 3.5 studs, so "!" always shows first) |
| B-004 | low | Bubble Blaster is called "BUBBLEBLASTER" in the prompt and toasts but "BUBBLE" on its sign | mechanics | fixed (0a42f2c): "BUBBLE BLASTER" everywhere (`Config.Gadgets.BubbleBlaster.Label`, `Logic/Loadout.label`); the pedestal prompts are gone |
| B-005 | low | Gadget pedestal labels pile up into an unreadable cluster when seen along the rack | map (ux advises) | open |
| B-006 | low | Light count above the provisional mobile budget (69 lights, 25 with shadows) | map | open |
| B-007 | high | Guard climbs on top of the player and never grabs (3D distance stays > 3.5) | mechanics (B) | fixed (pending merge) |
| B-008 | high | Detection too weak: masked player 6 studs in front of a guard → Suspicious, back to Patrol after 8 s | mechanics (B) | fixed (pending merge) |
| B-009 | high | Mask Up on entering StaffZone/SecureZone not implemented yet → unmasked players are ignored by guards everywhere | mechanics (D) | open (pending package D) |
| B-010 | high | Guards/NPCs glitch and jitter (owner playtest) | mechanics | fixed (pending merge) |

---

## B-001 — All in-world signs are drawn at 8 px (unreadable)

- **Severity:** medium (every sign in map 1 is unreadable: THE GOLDEN WHEEL, STAFF ONLY, DELIVERIES, CHEESE,
  the menu board, RIPENING ROOM, KAREL). Regression from 739ff01 "Readable signs".
- **Owner:** map (`src/server/Map/Common/Builder.luau`, `Builder.sign`)
- **Build:** main 021c25d (code unchanged in aeb26a5)
- **Steps:**
  1. Sync main to Studio, start a playtest.
  2. Run `25_signs_readable` (Client), or look at the shop front from the quay.
- **Expected:** the sign text fills its board (TextScaled), readable from the street.
- **Actual:** all 8 SurfaceGui labels have `TextScaled = false` and `TextSize = 8`, e.g. THE GOLDEN WHEEL is 8 px
  high on an 800×110 px board (7%). Only a tiny speck is visible on the green board.
  Screenshot: `tools/studio_tests/screenshots/2026-10-16_shop-signs-unreadable.jpg`.
- **Likely cause:** `Builder.sign` sets `t.TextScaled = true` and then `t.TextWrapped = false`. In Roblox, setting
  `TextWrapped` to false turns `TextScaled` off again. Remove the `TextWrapped = false` line (or set it before
  `TextScaled`, and check the result), then re-run `25_signs_readable`.
- **Note:** the earlier problem (THE GOLDEN WHEEL partly hidden behind the awning) is fixed by 739ff01: the board
  is now fully visible above the awning.

## B-002 — Shop front doorway is too narrow for pathfinding agents with radius 2

- **Severity:** medium (no gameplay impact today: the guard walks with `MoveTo`, not pathfinding. But any
  pathfinding NPC planned for the beta, such as guards chasing into the shop, the dog or Karel, cannot enter the
  shop through its front door.)
- **Owner:** map (`src/server/Map/Heists/GoldenWheel/Shop.luau`, the opening between `FrontPier2` and `FrontPier3`)
- **Build:** main 6060557
- **Steps:**
  1. Start a playtest with all doors closed.
  2. Run `40_pathfinding` (Server).
- **Expected:** the shop (-11, 0, -27) is reachable from the spawn with `AgentRadius = 2` (the Roblox default).
- **Actual:** `NoPath`. With `AgentRadius = 1.5` the path succeeds (12 waypoints). Outside → inside the front door
  fails with radius 2 and works with 1.5. The opening is 5 studs wide (z -28.5..-23.5). The equally wide StaffDoor
  (z -22.5..-17.5) is passable from the hall side, so the grid alignment of the opening matters.
- **Suggestion:** make the front doorway at least 6 studs wide, then re-run `40_pathfinding` (expected with doors closed:
  7/7).

## B-003 — Guard can catch a player without ever showing "!" (Alert lasts 0 frames)

- **Severity:** low (feel/fairness: the player gets no "!" warning before being caught)
- **Owner:** mechanics (`src/server/Services/GuardService.luau`); design question for the advisor (how long the
  "!" moment must last)
- **Build:** main 6060557
- **Steps:**
  1. Playtest, guard on patrol.
  2. Run `50_guard_capture` (Client): it places the player 7 studs in front of the guard and records every
     `GuardState` change on the client.
- **Expected:** clients see `GuardState = "Alert"` (the red "!" icon) for at least a moment before the capture.
- **Actual:** in the undisturbed run the client saw `Patrol → Suspicious → Search`. `GuardAlert` was broadcast and the
  player was caught, but the "Alert" state never replicated. (An earlier, disturbed run did show
  `Suspicious → Alert → Search`: it depends on how close the guard already is.)
- **Cause (from the code):** while Suspicious, the guard walks towards the player. When the vision meter reaches 1
  he is often already within `CaptureDistance` (3.5). `updateVision` then sets Alert and `updateBehaviour` captures
  and sets Search in the same Heartbeat, so both attribute changes replicate as one.
- **Suggestion:** a minimum Alert time (e.g. 0.4 s) before a capture is allowed, or keep the "!" icon visible for a
  short time after a capture.

## B-004 — Bubble Blaster naming is inconsistent

- **Severity:** low
- **Owner:** mechanics (`src/server/Services/LoadoutService.luau`); ux confirms the wording
- **Build:** main 6060557
- **Steps:** run `20_pedestals` (see the ObjectText) or take the Bubble Blaster at its pedestal.
- **Expected:** one player-facing name everywhere (`Config.Gadgets.BubbleBlaster.Label = "BUBBLE"`).
- **Actual:** the sign above the pedestal says "BUBBLE", but the prompt `ObjectText` and the toasts say
  "BUBBLEBLASTER" ("Took the BUBBLEBLASTER (CLEAR)"). `LoadoutService` uses `gadgetName:upper()` instead of the
  `Label`.

## B-005 — Gadget pedestal labels overlap when seen along the rack

- **Severity:** low
- **Owner:** map (labels made with `Builder.label` in `Heists/GoldenWheel/Quay.luau`); ux advises on the
  look
- **Build:** main 6060557 (the Edit-mode level)
- **Steps:** look at the gadget rack from the south end of the quay, around (-46, 12, -34) towards the van.
- **Expected:** each gadget name readable at the angle players approach from.
- **Actual:** CROWBAR, BUBBLE, EMP and THE VAN stack into one unreadable cluster (the billboards are the same size
  at every distance and sit in one line). Screenshot: `tools/studio_tests/screenshots/2026-10-16_pedestal-labels-overlap.jpg`.
- **Suggestion:** show a label only when close (`MaxDistance` ~20), or make them smaller and alternate their heights.

## B-006 — Light count above the provisional mobile budget

- **Severity:** low (needs confirmation on a phone before acting)
- **Owner:** map
- **Build:** main 6060557
- **Steps:** run `95_performance` (Server) during a playtest.
- **Expected (provisional budget):** ≤ 60 lights in Workspace, ≤ 12 lights with `Shadows = true`.
- **Actual:** 69 lights (32 PointLight, 3 SpotLight, 34 SurfaceLight on the lit `WindowGlass` panes); 25 cast
  shadows (22 lamps: StreetBulb1–10, BridgeLamps, GateLantern, Lamp1–4, OfficeLamp, SecurityLamp, ShopLamp1–2,
  YardLamp; plus the guard flashlight and the 2 camera cones). Server frame time is fine in Studio (16.7 ms
  average), so this is about phones.
- **Suggestion:** turn off shadows on the street bulbs that are far from the play area, and consider making the
  lit windows Neon without a SurfaceLight.

---

## Observations (no bug)

- **Someone playing in the Studio window during tests** (16/10): WASD/E input, took the Crowbar, pried the
  DeliveryGate and stopped the playtest twice. The harness now waits for idle, marks disturbed runs as WARN, and
  never stops a playtest that is in use. The first `10_spawn` FAIL that day was caused by this, not by the game.
- **`AlarmLevel` attribute starts as nil** until the first alarm change or reset. The HUD shows QUIET correctly;
  the tests treat nil as 0. Worth initialising to 0 in `AlarmService` when it is next touched (mechanics).
- **One-off `NoPath` to the office** right after the DeliveryGate was opened by hand; not reproducible afterwards
  (courtyard → office succeeds with radius 2). Probably navmesh update lag.
- **`MeshContentProvider failed … rbxruntime://`** (4 lines) appeared once at the start of the session, before the
  sync and during a live-editing session. After the sync no MeshPart in the level uses an `rbxruntime://` mesh and
  the line did not come back.

## B-007 — Guard climbs on top of the player and never grabs

- **Severity:** high (no captures happen when a player stands still in front of a guard).
- **Owner:** mechanics (B) — `GuardService` / `CaptureService`, collision groups.
- **Found by:** orchestrator smoke test, main 559f540, Golden Wheel retrofit.
- **Steps:** set the player's `Masked = true`, put the player 6 studs in front of guard 2, wait until Alert.
- **Expected:** guard grabs within ~1 s once within 3.5 studs.
- **Actual:** guard Alert at WalkSpeed 15 ends up at y 6.96 on top of the player (y 2.9); distance 4.1 > 3.5, never grabs.
- **Fix idea:** guards should not collide with players (collision group), and/or the grab check should use horizontal (XZ)
  distance with a vertical tolerance.
- **Root cause (mechanics):** the "Guards" and "Players" collision groups were never set non-collidable, so a chasing
  guard (WalkSpeed 15) ran into the standing player and stepped up onto him. The grab used the 3D distance between the
  root parts, so a guard on the player's head (dy ≈ 4) stayed "out of reach" (4.1 > 3.5) forever.
- **Fix:** `GuardService:Init` makes "Guards" (every NPC part, set by `Rig.place`) non-collidable with "Players"
  (RoundService already puts every character part in "Players", also parts added later). The grab range is now
  horizontal with up to 4.5 studs height difference (`Logic/Capture.reach`, `Config.Guard.GrabVertical`), so even a
  guard standing on a player grabs. NPC humanoids can no longer trip, ragdoll or climb. Without body-blocking the Alert
  guard walks right into the player's spot and the 1 s grab completes for a standing or slow (crouching) player.
  Tests: `tests/logic/Capture.spec.luau` (reach, guard on the head, slow walker).
- **Status:** fixed (pending merge).

## B-008 — Detection too weak at close range

- **Severity:** high (stealth feels broken: guards ignore a player right in front of them).
- **Owner:** mechanics (B) — `GuardService` vision / `Logic/Detection`.
- **Steps:** as B-007; observe `GuardState` for 40 s.
- **Expected:** meter fills in ~0.8 s at 6 studs (lit or dark) → Alert.
- **Actual:** Suspicious at 0.5 s, back to Patrol at 8.6 s with the player still standing in front; Alert only on a later pass (40 s).
- **Check:** whether the investigate walk turns the guard away / the cone check uses the wrong eye height / the meter decays
  while investigating.
- **Root cause (mechanics), two parts:**
  1. *The investigate walk turned him away.* A Suspicious guard walks to what he saw and, within 3 studs, "arrives" and
     looks around by spinning on the spot at 70°/s. The vision refresh (`arrived = false`) could not stop that: he
     re-arrived in the same frame and kept spinning. Within ~0.5 s the player left his 35° half-cone, the meter
     drained at 0.5/s, every later sweep added only ~0.6, and the 8 s look-around ran out → Patrol. That matches the
     log exactly (Suspicious at 0.5 s, Patrol at 8.6 s).
  2. *The cone lost players up close.* The cone was a 3D cone with the vertical part halved, seen from an eye 2.5 studs
     above the target point. Closer than ~2 studs it narrowed sharply; closer than ~1.5 studs (or with the guard
     standing on the player, B-007) the player was never in view.
  Checked and fine: vision runs every 0.1 s; the meter only decays when he does not see you; `lit` only switches the
  range 35/18 (no effect at 6 studs); the ray ignores the whole guard model and any part of the player counts as seen.
  Hardened anyway: invisible parts (Transparency ≥ 0.95, e.g. trigger boxes or invisible ramps with CanQuery on) no
  longer block the view.
- **Fix:** while a Suspicious/Search guard has seen the player within the last 0.5 s (`Config.Guard.WatchSeconds`) he
  stands still and faces the player (no spinning, no wandering, the search time waits), so the meter keeps filling.
  The cone is now `Logic/Detection.inViewCone`: yaw only on the same floor; targets more than 4 studs above or below the
  eye must also be within 55° up/down (`ConeMaxPitch`); a target within 1 stud horizontally (overlapping) is seen. The
  snitches (Karel, Inspector) use the same cone. Still ignored as before: `SeeThrough` parts (and the `Cage` folder),
  hidden, caught, immune and unmasked (Mask Up) players.
- **Timing now:** masked, unhidden player 6 studs in front → Suspicious at ~0.4 s, Alert at ~1.0 s (lit) / ~1.2 s
  (dark), grab 1 s later. Note: the spec's meter is linear over the range (0.8 s at 0 studs → 2.0 s at the edge), so 6
  studs fills in 1.0–1.2 s, not 0.8 s; no tuning was changed. Tests: `tests/logic/GuardVision.spec.luau`.
- **Status:** fixed (pending merge).

## B-009 — Mask Up on staff zones missing

- **Severity:** high until package D merges (guards ignore unmasked players, so walking through the hall is safe).
- **Owner:** mechanics (D) — set `Masked = true` when a crew member enters a `StaffZone`/`SecureZone` (A already masks on
  first grab and at lockdown).

## B-010 — Guards/NPCs glitch and jitter

- **Severity:** high (the owner's playtest: "the game does not run smoothly, the guards glitch").
- **Owner:** mechanics — `src/server/Npc/Mover.luau` (shared by guards, Karel, the Inspector and Boef), `Rig.luau`,
  `GuardService.luau`.
- **Found by:** owner playtest, reported by the orchestrator (16 Oct).
- **Root causes (from the code):**
  1. *CFrame snapping:* looking around (Suspicious, Search, Stunned) set the root's CFrame every frame on a
     physics-driven humanoid, fighting the Humanoid's own turning.
  2. *MoveTo spam:* `Mover.stop()` called `Humanoid:MoveTo(own position)` every frame from many states (stunned guard,
     stunned Inspector, eating Boef, looking around). `Mover.step` re-issued `MoveTo` whenever the target moved 0.5
     studs (every frame while chasing) and every 2 s.
  3. *One-frame twitch:* a Suspicious guard next to the player got `arrived = false` from every vision update (0.1 s),
     took one `MoveTo` step towards the player and stopped again.
  4. *Stale path start:* paths are computed in a separate thread from where the NPC stood; walking started at waypoint
     2 even when the NPC had passed it meanwhile, so he turned back for a moment.
  5. *Network ownership:* set once at spawn. Welding (the bubble, a carried captive) changes the assembly and can hand
     it back to automatic ownership, so a nearby client simulated the NPC.
  6. *Bumping:* NPCs collided with players (B-007) and with each other (pushing in doorways).
  7. *Walk animation:* started and stopped every frame around 0.5 studs/s and always played at one speed (foot sliding
     at 6, slow motion at 15).
  8. *Vision cost:* every guard raycast in the same frame every 0.1 s and rebuilt the ignore list (4× `GetTagged`)
     each time.
- **Fix:** (1) turning on the spot goes through an `AlignOrientation` in `Mover` (`face`, `turnBy`; max
  `Config.Guard.TurnSpeed`), walking hands turning back to the Humanoid (`AutoRotate`). (2) `stop()` only touches the
  Humanoid when it was walking; `MoveTo` is re-issued only when the target moved more than max(1 stud, 15% of the
  distance), after a `MoveTo` that ended short of the target, or every 6 s (before Roblox's 8 s timeout). (3) the
  arrive check runs before walking. (4) a new path starts after the nearest of its first 4 waypoints. (5) `Mover`
  re-asserts server ownership about once a second and right after weld changes (bubble on/off, carry start/stop).
  (6) "Guards" is non-collidable with "Players" and with itself. (7) the walk animation has separate start/stop
  thresholds and its speed follows the walking speed. (8) each guard looks on his own staggered 0.1 s timer, at most
  `Config.Guard.VisionGuardsPerFrame` (2) guards per frame, taking turns (`Logic/NpcBudget.dueThisFrame`, tested);
  the ignore list is cached (rebuilt when tags, guards or the level change, or every 2 s) and the player snapshot is
  shared. Pathfinding was already asynchronous and throttled (≥ 0.5 s, only when the goal moved > 3 studs); kept.
- **Not changed (follow-ups):** the mini-job's sleeping guard (TutorialService) is anchored and moved with `PivotTo`
  every frame while he follows at lockdown, which looks choppy on clients; Karel and the Inspector have no walk
  animation (they slide).
- **Verify in Studio:** watch a guard look around (smooth turn, no stutter), a Suspicious guard facing a player who
  stands still, a chase into a doorway with two guards, and the bubble/carry (no jitter after the weld changes).
- **Status:** fixed (pending merge).
