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
| B-007 | high | Guard climbs on top of the player and never grabs (3D distance stays > 3.5) | mechanics (B) | open |
| B-008 | high | Detection too weak: masked player 6 studs in front of a guard → Suspicious, back to Patrol after 8 s | mechanics (B) | open |
| B-009 | high | Mask Up on entering StaffZone/SecureZone not implemented yet → unmasked players are ignored by guards everywhere | mechanics (D) | open (pending package D) |

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

## B-008 — Detection too weak at close range

- **Severity:** high (stealth feels broken: guards ignore a player right in front of them).
- **Owner:** mechanics (B) — `GuardService` vision / `Logic/Detection`.
- **Steps:** as B-007; observe `GuardState` for 40 s.
- **Expected:** meter fills in ~0.8 s at 6 studs (lit or dark) → Alert.
- **Actual:** Suspicious at 0.5 s, back to Patrol at 8.6 s with the player still standing in front; Alert only on a later pass (40 s).
- **Check:** whether the investigate walk turns the guard away / the cone check uses the wrong eye height / the meter decays
  while investigating.

## B-009 — Mask Up on staff zones missing

- **Severity:** high until package D merges (guards ignore unmasked players, so walking through the hall is safe).
- **Owner:** mechanics (D) — set `Masked = true` when a crew member enters a `StaffZone`/`SecureZone` (A already masks on
  first grab and at lockdown).
