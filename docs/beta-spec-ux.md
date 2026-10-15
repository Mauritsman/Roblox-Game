# Beta spec: UI/UX, onboarding, audio and game feel

*Owner: ux. 16/10/2026. Builds on `docs/research/advisor-brief.md` (advisor decisions win). The final Net contract
and rules live in `docs/beta-spec.md` (mechanics) and `docs/beta-spec-meta.md` (meta); names below are what ux
**expects** and may be renamed if the data stays the same. Tunable UI numbers go in a new `Config.UX` block.*

**Design rules:** landscape, designed for a 640 × 360 phone first · one goal on screen at a time · hints max 5 words
+ icon, no text walls · touch: max **3 action buttons + 1 context button** (plus Roblox's jump button), ≥ 48 px, main
64 · colour is never the only signal · every action gets sound + motion within 100 ms · state from attributes
(late-join safe), moments from Net events.

**Retired from the prototype** (chain and 10 s window are dropped): Chain Call panel/controller, window ring (becomes
"effect chips", §1.7), CALL / NOW / WAIT buttons, the `P` restart key, the start-up toasts.

---

## 1. Screen inventory

Layout terms: **status bar** = top-centre; **crew list** = top-right; **cluster** = the touch buttons bottom-right;
the top-left stays free for Roblox's chat window and top-bar buttons.

### 1.1 Loading screen
- **Purpose:** cover the load (< 15 s); new players then land in the mini-job, others in the Garage.
- **Layout:** full screen, ignores insets. "CROWBAR CREW" logo (FredokaOne), wobbling cheese wheel (static with reduce
  motion), 3 progress pips, one tip line at the bottom (≤ 8 words, e.g. "Heavy cheese? Lift it with a friend").
- **States:** loading → fade out 0.3 s; after 12 s a small "Still loading…" line. No skip button.
- **Data/tech:** `game:IsLoaded()`, `ContentProvider:PreloadAsync` on HUD images + first music track (cap 8 s), player
  attribute `IsNewPlayer` (meta). LocalScript in `ReplicatedFirst` (`RemoveDefaultLoadingScreen()`); needs a
  `ReplicatedFirst` entry in `default.project.json` (ux block, proposed folder `src/first/`).

### 1.2 Garage HUD
- **Purpose:** the safe hub: money, rank, and the way to the job board, gadget rack and van.
- **Phone:** status bar = Cash (coin icon + "2,450") and Rank badge with a thin Rep bar; below it a chip
  "CONTRACTS 1/3" (tap → 3 rows: name, progress, reward). Crew list top-right (shape, name, Garage/van), gear (48) and
  invite (48, `SocialService:PromptGameInvite`). Cluster: context button only (JOBS / GADGETS / MIRROR / START).
  PC/gamepad: world prompt with key cap (E / X).
- **States:** idle · "LEAVING IN 12" banner when someone is in the van · "CREW ON A JOB" (§1.17).
- **Data:** player attributes `Cash`, `Rep`, `Rank` (meta), `CrewColor` (exists); `ReplicatedStorage.VanDepartAt`
  (proposed, server time); `Contracts` snapshot (Net, meta).

### 1.3 Job board
- **Purpose:** pick one of 3 jobs (map + modifier).
- **Phone:** modal, 3 cards (≈ 180 × 210): map picture (placeholder block + icon until thumbnails exist), name,
  modifier pill ("POWER CUT +20%"; "NORMAL" in rounds 1–2), guard icons, lock "RANK 3" or "Unlocked by Sam", gold
  ribbon for "MOST WANTED". Close (48). Gamepad: first card selected, B closes.
- **Voting (proposed):** tap = vote, your crew shape appears on the card; most votes = SELECTED (gold outline), ties
  go to the earliest vote. Solo = instant.
- **Data:** Net `JobBoard` snapshot `{ jobs = { {id, heistId, name, modifier, bonusPct, guards, locked, unlockedBy,
  mostWanted} ×3 }, votes = {[userId] = jobId}, selected }` (meta); request `VoteJob(jobId)`.

### 1.4 Gadget pick
- **Purpose:** choose 2 of Drone, Noisemaker, EMP, Bubble Blaster. The Crowbar is always carried.
- **Phone:** modal. 4 cards (2 × 2 grid if the screen is < 700 px wide, else a row). Card: big icon, name, ≤ 4-word
  line ("Fly and spot guards", "Lures one guard away", "Kills cameras and lamps", "Bubbles a guard 8 s"), charges
  "×3", and small crew shapes of teammates who picked it. Selected cards show "1" / "2"; tapping a third replaces the
  oldest. A strip under the cards: "CROWBAR · always with you". Button "DONE" (64).
- **Default:** a new player gets Noisemaker + Bubble Blaster preselected (proposed: the two easiest to read).
- **Data:** player attribute `Gadgets` (exists), `Charges_*` (exists); request `PickGadgets({a, b})` (mechanics).

### 1.5 Mirror (cosmetics)
- **Purpose:** spend Cash on looks (beta: Cash only, no Robux).
- **Phone:** camera faces your avatar (left half). Right panel: tabs MASKS / HATS / VESTS / VAN (48 px), item grid
  (price / OWNED / EQUIPPED). Tap = preview; button "BUY 1,500" / "EQUIP" / greyed "NEED 300 MORE".
- **Data:** Net `Catalog` (meta) `{ id, category, name, price, owned, equipped }`; requests `BuyItem(id)`,
  `EquipItem(id)`; attribute `Cash`.

### 1.6 Briefing / job card
- **Purpose:** at 0:00 tell the crew where the Golden Gouda is and what the modifier does. No scouting phase.
- **Phone:** centre-top card for 4 s (fades on first movement after 1.5 s): map name, modifier pill + one line, goal
  row "★ 500 · ★★ 1,500 · ★★★ GOUDA + 2,500". A gold beam shows the Gouda spot through walls for 4 s, then a small
  crown marker stays there until it is lifted.
- **Data:** `ReplicatedStorage` attributes `RoundPhase = "Briefing"`, `HeistId`, `Modifier`, `JobName` (mechanics);
  the Gouda model tagged `MainLoot` (proposed tag); star thresholds from `Config` (mechanics).

### 1.7 Heist HUD
- **Purpose:** everything needed while stealing, readable in one glance.
- **Phone (640 × 360):**
  - *Status bar* (top-centre, 340 × 60): row 1 = loot meter (banked van loot, 3 star ticks, "1,250"); row 2 = alarm
    pips + word left, round timer "6:42" right.
  - *Effect chips* under it (28 px): "CAMS OFF 8", "GUARD BUBBLED 6". Then the *hint pill* (onboarding/tips only).
  - *Crew list* (top-right, 150 wide, 28 px rows): crew shape, name (≤ 10 chars), status icon (loot-class shape when
    carrying, bars = cell, van, barrel = hidden). Gear (48) above it.
  - *Carry chip + 3 pocket circles* bottom-centre, between joystick and cluster (§1.8).
  - *Edge arrows:* van (when carrying or in lockdown), caught teammates, the Gouda (until lifted), pings.
  - *Crosshair* (touch/gamepad), banners at 30% height, world pops, cluster (§2.2). PC: no cluster, key caps in world.
- **States:** sneaking · spotted (red edge flash) · lockdown (§1.9) · shift change · hidden · carrying · drone ·
  captured · spectating.
- **Data:** `ReplicatedStorage` attributes `RoundPhase`, `RoundEndsAt`, `VanLoot`, `AlarmLevel` (exists),
  `CrewSize`; character attributes per player (§7.3); Net `Window` (exists, becomes an effect chip).

### 1.8 Carry state
- **Purpose:** make the weight of greed felt and show what the hands can do now.
- **Elements:** carry chip "■ CHEESE WHEEL 150" in the class colour + weight pips (medium ●○○, heavy alone ●●○, heavy
  rolling ●●○ + "LOUD" sound-wave icon in amber, two-player "WITH SAM" + Sam's shape). The cluster morphs (§2.2): the
  GADGET slot becomes THROW (medium) or ROLL (heavy); CROUCH greys out with a padlock; context becomes DROP (or LET GO).
- **Two-player carry:** a teammate near carried heavy loot sees context "LIFT". While lifting, a Beam in both crew
  colours links the two players; partner lets go → toast "SAM LET GO" and the "HEAVY!" pop again.
- **Throw aim:** dotted arc from the hands to a landing ring (max 10 studs, ring red when clamped). A teammate with free
  hands within catch range of the ring turns it green with their shape and "CATCH".
- **Data:** character attributes `CarryClass`, `CarryLoot`, `CarryPartner`, `Rolling`, `Pockets` (§7.3); Net
  `LootPicked`, `LootDropped`, `LootThrown`, `LootCaught`.

### 1.9 Alarm, shift change and lockdown
- **Alarm tier up:** the pip pops (scale 1.4 → 1, 0.2 s) + rising beep. Tier 2 adds a slow amber pulse on the word.
- **Shift change (7:00):** amber banner "SHIFT CHANGE IN 60", timer turns amber.
- **Lockdown (Gouda lifted or tier 3):** full-width banner "LOCKDOWN" (1.5 s), timer becomes "POLICE 0:60" in red
  (last 10 s: one tick per second, bigger), red/blue light sweep on the screen edges (static red frame with reduce
  motion), edge arrows to the van and, if open, the 2nd exit.
- **Data:** `AlarmLevel`, `ShiftChangeAt`, `LockdownEndsAt` (server times, proposed); Net `Lockdown(endsAt, reason)`,
  `ShiftChange(endsAt)`, `Alarm` (exists).

### 1.10 Captured and cell view
- **Grabbed:** 0.08 s freeze, "CAUGHT!" stamp, then the camera pulls back to show the guard carrying you (legs kick).
  The cluster shows only PING (HELP is preselected in the wheel). First time: tip "Crew can bubble him".
- **Cell view (phone):** your camera becomes the security cameras: full-screen feed in a thin "CCTV" frame, label
  "CAM 2/5 · SHOP", arrows ◀ ▶ (56 px) at the sides. Tap a guard in the feed = SPOT ping for the crew. Context
  "CRAWL OUT" is locked behind a 15 s ring ("GRATE 0:12"), then usable once per round. Crew list shows "SAM IS COMING"
  when a free teammate is < 30 studs from the cell.
- **PC/gamepad:** A/D or ←/→ (LB/RB) switch cameras, Q/R1 spot, E/X crawl out.
- **Busted:** everyone in the cell → full-screen "BUSTED" stamp (1.5 s), then payout (§1.13).
- **Data:** character attribute `Captured = "Carried" | "Cell"`, `SelfEscapeAt`, `SelfEscapeUsed` (mechanics); tag
  `SecurityCamera` (exists); request `ViewCam(index)` so the server can `RequestStreamAroundAsync` the camera spot
  (StreamingEnabled; proposed); Net `Captured`, `Rescued`, `Busted`.

### 1.11 Rescue prompt
- **For free players:** toast "SAM CAUGHT" + a persistent edge arrow with a wristband icon to the cell, and a world
  marker "FREE SAM" with distance. While Sam is still being carried and you hold a Bubble Blaster or Noisemaker, the
  guard gets a marker "BUBBLE HIM!".
- **At the cell:** context "FREE" (hold 2 s, ring fills). The captive sees the same ring ("SAM IS FREEING YOU").
- **Data:** ProximityPrompt on the cell door (mechanics, §7.2); `Captured` attributes; Net `Rescued`.

### 1.12 Escape: HOLD TO DRIVE
- **Purpose:** end the round on purpose, with tension.
- **Phone:** inside the van zone the context button becomes "DRIVE" (hold 3 s, ring). A panel under the status bar
  lists the crew: "✓ in van", "caught" (bars icon), or "outside" + direction arrow. If free teammates are outside, the button
  sub-label reads "LEAVES 1 BEHIND" in amber. Every crew member in the van sees the ring.
- **Last second:** escape completes with ≤ `Config.UX.LastSecond` (3 s) left → slow-mo + "JUST MADE IT!" (§4) and an
  automatic `CaptureService` screenshot offered on the payout screen ("SAVE" / "SHARE" chip).
- **Data:** ProximityPrompt `Drive` on the van; character attribute `InVan`; Net `Escaped(secondsLeft)`.

### 1.13 Payout and results
- **Purpose:** the reward moment (30 s), then "NEXT JOB".
- **Phone:** full screen over a blurred van shot. Left 55%: item tally ("■ Cheese Wheel +150", last 6 lines), "VAN
  TOTAL 3,100", bonus lines ("CREW +45%", "QUIET JOB +20%", "FIRST JOB TODAY ×2"), big "YOUR CUT 1,240". Right 45%:
  3 stars, award cards (max 4, one per player), Rep bar + "RANK UP!". Bottom: feedback (§1.14) left; "NEXT JOB 10"
  (64) and "GARAGE" (48) right.
- **Timing:** tally 0–6 s (tap = skip), stars 6–8, awards 8–12, cash/rep 12–14, then the NEXT JOB countdown. All
  crew tapping NEXT JOB starts early.
- **Busted variant:** red "BUSTED" header, "Half the loot saved", 0 stars, awards still shown.
- **Data:** Net `Payout` table (§7.3), requests `NextJob()`, `ReturnToGarage()`.

### 1.14 One-tap feedback
- Three drawn faces (happy / neutral / sad, 56 px, image icons not emoji). After a tap, 6 tag chips slide in: "Fun",
  "Too hard", "Too easy", "Confusing", "Bug", "Laggy" (pick up to 2, auto-sends after 4 s or on NEXT JOB). Never
  blocks NEXT JOB. No free text. Shown after every round; hidden after 3 skipped rounds in a row (proposed).
- **Data:** request `Feedback(mood, tags, jobId)` → meta logs it (custom analytics event).

### 1.15 Settings
- Modal 520 × 300 (scrolls on small phones): Music, SFX (10-step bars with − / + buttons, 48 px), Camera sensitivity
  (0.5–2.0), Reduce motion (default = `GuiService.ReducedMotionEnabled`), Hints, "Mute pings from" (crew chips),
  version string. B / Esc / close (48).
- **Camera sensitivity:** scripts cannot change Roblox's own setting, so our slider scales touch/gamepad look input in
  the PlayerModule camera (verify in WP8). If that needs a PlayerModule fork, replace the slider with "Camera speed:
  Roblox menu".
- **Data:** Net `Settings(table)` on join and request `SaveSettings(table)` (debounced 2 s) → meta stores it in the
  profile.

### 1.16 Mini-job HUD
The heist HUD with progressive disclosure: start = status bar loot meter + hint pill + context button only. CROUCH
appears at the sneak step, the GADGET slot appears as ROLL at the Gouda step, PING after the mini-job. No alarm pips
until the guard stirs. Script: §3.

### 1.17 "Crew on a job" (late joiners)
- **Purpose:** a stranger joining mid-round knows when they can play and is not bored.
- **Phone:** status bar = "CREW ON A JOB · 3:10 LEFT". Round < 2:00 old: gold chip "JUMP IN · 1:12" + edge arrow to
  the Garage van (context "JUMP IN"). Later: "Next job soon" + arrows to the practice yard and gadget rack. Context
  "WATCH" at the Garage TV (or a 48 px "WATCH CREW" button) = full-screen spectate (◀ ▶ switch, B / close leaves).
- **Data:** `RoundPhase`, `RoundStartedAt`, `RoundEndsAt`; `Config` jump-in window (mechanics); request
  `JumpIn()`; request `Spectate(userId)` so the server streams around the target (proposed).

---

## 2. Controls

### 2.1 Mapping

| Action | Touch | Keyboard + mouse | Gamepad |
|---|---|---|---|
| Move / look | Roblox joystick / swipe right half | WASD / mouse (RMB drag) | LS / RS |
| Jump | Roblox jump button | Space | A |
| Crouch (toggle) | CROUCH | C | B |
| Context: grab, drop, bank*, hide, out, lift, let go, pry, free, drive, jump in | CONTEXT (tap or hold) | E (tap or hold) | X (tap or hold) |
| Primary: gadget use, throw (medium), roll toggle (heavy) | GADGET slot: tap = aim, tap again = throw/use, drag off = cancel | LMB: hold = aim, release = throw; tap = use / roll toggle | L2 = aim, R2 = throw / use / roll |
| Cancel aim | drag off the button | R | B (while aiming) |
| Gadget select | swap badge on GADGET | 1 / 2 | L1 cycles |
| Ping (SPOT) | PING tap | Q tap | R1 tap |
| Quick wheel | PING hold 0.3 s, slide, release | Q hold + mouse | R1 hold + RS |
| Quick shortcuts | (wheel only) | Z = GO, X = WAIT | D-pad ↑ GO, ↓ WAIT, ← HELP, → TO THE VAN |
| Drone up / down / back | GADGET ▲ / CROUCH ▼ / CONTEXT BACK | Space / Ctrl / F | A / B / Y |
| Cell: switch camera | ◀ ▶ buttons | A, D or ← → | LB / RB |
| Menus | tap | click | D-pad + A, B = back |
| Settings | gear | gear (click) | Select (proposed; verify no clash with Roblox UI navigation) |

*Banking: walking into the van zone banks automatically (proposed to mechanics: fewer taps on phones). Rescue
(2 s), pry (1.5 / 3 s) and drive (3 s) are holds; nothing needs a hold longer than 3 s.

**One rule for the primary action:** "the primary button does what your hands allow": a gadget with empty hands or
small loot, THROW with medium loot, ROLL with heavy loot. Same button on every platform.

**Quick wheel (6 presets, no end punctuation):** GO · WAIT · HELP · LIFT WITH ME · TO THE VAN · THROW TO ME, each
with an icon and a pitch. Cooldown 10 s per player (`Config.Ping.QuickCooldown = 10`, the safe reading of Roblox's
preset rules), shown as a ring. SPOT icon pings stay at 3 per 2 s. The same words become Roblox Quick Words in
Creator Hub (orchestrator/Maurits task).

### 2.2 Touch cluster (3 + 1)

Offsets in px from the bottom-right corner at UIScale 1, placed in an arc above and left of Roblox's jump button
(read `TouchGui.TouchControlFrame.JumpButton.AbsolutePosition` when present, fall back to these numbers).

| Slot | Size | Position (right, bottom) | Normal | Carry medium | Carry heavy | Drone | Hidden | Cell | In van |
|---|---|---|---|---|---|---|---|---|---|
| CONTEXT | 72 | 110, 22 | context or hidden | DROP | DROP / LET GO | BACK | OUT | CRAWL OUT | DRIVE |
| GADGET (primary) | 64 | 28, 108 | gadget icon | THROW | ROLL | ▲ | hidden | ◀ ▶ arrows replace slots | hidden |
| CROUCH | 56 | 196, 22 | CROUCH | greyed + lock | greyed + lock | ▼ | hidden | hidden | hidden |
| PING | 52 | 110, 112 | PING | PING | PING | SPOT | PING | PING | PING |

- The swap badge (48 px hit area, other gadget's icon) sits on the GADGET rim with 2 gadgets: part of that control,
  not a 4th button.
- Buttons never move; they change icon, label and colour (thumb memory).
- No context → the context button hides (not greyed). Its target gets a white `Highlight` outline.
- A modal hides the cluster and sets `GuiService.TouchControlsEnabled = false`.

---

## 3. Onboarding

### 3.1 Mini-job script (≈ 3:00, first bank ≤ 0:45)

New players (`IsNewPlayer`) skip the Garage and spawn on the mini-job quay. No Karel, no Boef, no gadgets, one sleepy
guard who never goes past "?" before lockdown and never captures (proposed to mechanics).

| Clock | Situation | Hint (≤ 5 words + icon) | Done when | Funnel |
|---|---|---|---|---|
| 0:00 | Spawn by the van, camera faces a market stall with one cheese wheel 15 studs away (beacon) | "Grab the cheese" (wheel) | — | 1 Spawned |
| 0:04 | No movement for 4 s | "Move with the stick" / "Move with WASD" / "Move with left stick" | moved 8 studs | 2 Moved |
| 0:10 | At the wheel: only the context button, pulsing "GRAB" | (same hint) | wheel lifted | 3 Grabbed |
| 0:15 | "HEAVY!" pop, waddle; van glows, dotted ground arrows | "Bring it to the van" (van) | banked (auto) | 4 Banked |
| 0:40 | "+150", ka-ching, loot meter fills to the first star tick | — | — | — |
| 0:45 | Snoring guard ("Zzz") at the shop door; CROUCH button slides in | "Sneak past the guard" (crouch) | passed the door line | 5 Sneaked |
| 1:10 | Cheese cubes on the counter | "Pocket the small cheese" (pocket) | 1 cube pocketed or 10 s | — |
| 1:25 | Mini Golden Gouda on a pedestal (crown beacon) | "Grab the Golden Gouda" (crown) | lifted | 6 Gouda |
| 1:30 | Music stops, ding, sirens, "POLICE 0:60"; GADGET slot appears as ROLL | "Roll it to the van" (roll) | banked | — |
| 2:10 | Gouda banked "+1,500"; context "DRIVE" | "Hold to drive away" (van) | drive complete | 7 Escaped |
| 2:20 | Short payout (15 s): stars, award "Fresh Crook", Cash, feedback faces | — | — | — |
| 2:45 | Van arrives in the Garage → tour (§3.3) | — | in Garage | 8 Garage |

In lockdown the guard follows at 10 studs/s (rolling = 11): thrilling, never fatal. Captured anyway → respawn by the
van with a "Close one!" toast.

### 3.2 Funnel (8 steps)
Logged on the **server** with `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)` by meta's
onboarding/analytics service, based on server-side facts: 1 Spawned · 2 Moved · 3 GrabbedLoot · 4 BankedLoot ·
5 SneakedPastGuard · 6 LiftedGouda · 7 Escaped · 8 ReachedGarage. The server sends `Onboarding(step)` to the client so
ux shows the next hint; the client never logs analytics itself. Goal: ≥ 70% reach step 7.

### 3.3 First Garage tour (once, ≤ 30 s, never blocking)
Three beacons with hint pills: "Pick two gadgets" (rack) → "Choose a job" (board) → "Hop in the van" (van). A later
step skips earlier ones. Mirror, trophy wall and practice yard only get world labels. Welcome-Cash toast on arrival
(amount from meta).

### 3.4 How hints behave
- One hint at a time in the hint pill (0.25 s pop + soft blip). Done → green check 0.4 s, fade 0.2 s, never again.
- Idle 20 s → the pill pulses and the world beacon brightens; repeat every 60 s.
- **First-time tips** in real jobs (max 2 times ever each, max 1 per 30 s): "Too heavy? Lift together", "Hands full:
  throw it", "Hide in a barrel", "Spotted! Drop or run", "Hold FREE at the cell", "Drone: look at guards". Stored as
  `SeenTips` in the profile (meta); the Hints toggle turns them off.

---

## 4. Feedback and juice

All timings start at the server event arriving on the client. "RM" = reduce motion. Pops use FredokaOne with a 2 px
dark stroke and are attached to the world (BillboardGui) unless noted.

| Event | Visual | Sound | Timing |
|---|---|---|---|
| Pickup small | Item shrinks and flies to a pocket circle; "+25" small grey pop | Per type: cube squish, tip-jar coins, drawer slide + bills | fly 0.25 s |
| Pickup medium/heavy | "HEAVY!" pop (heavy: bigger + 2 weight icons); camera dips 0.15 s (RM: none) | Cartoon grunt + item sound; heavy adds waddle thud loop | pop 0→1.15→1 in 0.25 s, hold 0.6, fade 0.3 |
| Bank | "+150" flies from the van to the loot meter; meter springs; teammate banks show "+150 SAM" in their colour | Ka-ching; banks within 2 s pitch up +5% each (max +25%) | fly 0.5 s, spring 0.3 s |
| Throw | Item spins along the arc | Whoosh | instant |
| Catch | "CATCH!" green pop on the catcher, seen by both | Thwap + short cheer sting | 0.4 s |
| Drop | Item bounces; fragile: crack + "-25%" red pop | Thud (per class weight) | instant |
| Spotted (you) | Guard "!" (exists) + red screen-edge flash (RM: static red frame 1 s) | Stinger "dun!" | flash 0.3 s; chase music ≤ 0.5 s later |
| Chase music | Crossfade sneaking → chase when a guard is Alert on you | — | in 1.0 s; out 2 s after 3 s unseen |
| Lockdown | "LOCKDOWN" banner, red/blue edge sweep (RM: static red frame) | Siren loop (2D low + 3D at exits), lockdown music; tick per second in last 10 s | banner 1.5 s |
| Captured | **0.08 s freeze** (local animation speed 0 + camera hold), "CAUGHT!" stamp slams in at −8°, light desaturation | Boing + whistle | stamp 0.15 s, hold 1 s |
| Rescue | "FREE!" pop on the captive, "HERO" pop on the rescuer, toast "SAM FREED ALEX" | Cell door clank + "yay" | 0.5 s |
| Sneeze | 15 s: nose icon fills on the OUT button; sniffs at 15, 17, 19 s; 20 s: "ACHOO!" comic letters at the barrel (visible to all within 15 studs), barrel wobble (RM: no wobble), player tumbles out | Sniff ×3, sneeze | 0.6 s |
| Karel shout | Speech bubble "WHO LEFT THIS OPEN?!" (2 s); loot return: toast "KAREL TOOK IT BACK" | Door slam / "tsk tsk" | 2 s |
| Boef bark | "WOOF!" bubble per bark, paw "?" while sniffing; fed: "nom nom" + hearts | Bark (3D), sniff loop, munch | per bark |
| Gouda lift | Music **hard stop**, 0.6 s silence, golden burst on the Gouda; at +1.2 s LOCKDOWN banner | Silence → one "ding" → sirens + lockdown music | 0 / 0.6 / 1.2 s |
| Last-second escape | Slow-mo: FOV 70→55 push-in, nearby animations at 0.4 speed, music pitch 0.8; "JUST MADE IT!" banner; screenshot (RM: banner only) | Whoosh + choir "aah" | 1.2 s |
| Payout | Money shower (≤ 30 bill images falling, RM: none), tally ka-ching per line, total counts up, stars pop one by one | Ka-ching per line, rising chime per star, fanfare on rank up | lines 0.12 s apart, count-up 1.2 s, stars 0.35 s apart |
| Alarm tier up | Pip pops | Two-tone beep, higher per tier | 0.2 s |
| Hide in / out | Barrel-ring vignette + 20 s ring on OUT | Lid bonk / pop | 0.5 s (matches server) |
| Pry | Progress ring on context | Creak loop, "CRACK" (exists) | hold time |

Implementation notes: no screen shake above 4 px, never shake with RM; the freeze and slow-mo are client-only
illusions (the server keeps running). Pops are pooled (max 8 alive).

---

## 5. Audio list

All sounds live in `src/shared/Sounds.luau` as `{ key = { id = "rbxassetid://TBD", volume, group, looped, note } }`.
**Asset ids are filled in during implementation (WP3).** Rules:
- Roblox audio privacy: audio uploaded by other users is private to their experiences. Use only audio **uploaded by
  the Roblox account** in the Creator Store (licensed library) or audio **we upload ourselves**. Record the source and
  "free to use" in the `note` field. Engine sounds (`rbxasset://sounds/...`) are fine as placeholders.
- Three `SoundGroup`s: Music, SFX, UI. Settings sliders set the group volumes. Music ducks −40% under banners.

**Music (looped, crossfaded by AudioController)**

| Key | Description | When |
|---|---|---|
| `MusicGarage` | Relaxed funky groove, bass + brushed drums, ~90 bpm | Garage, job board, waiting |
| `MusicSneak` | Plucky pizzicato/xylophone stealth loop, sparse, ~100 bpm | Heist and mini-job, alarm 0–2 |
| `MusicChase` | Fast brass + drums, comedic urgency, ~150 bpm; also used for lockdown with sirens on top | Alert on you, lockdown |
| `MusicPayout` | Short triumphant sting into a happy loop | Payout |
| `MusicBusted` | Sad trombone sting (one-shot) | Busted |

**SFX**

| Group | Keys |
|---|---|
| Loot | `PickupCube` (squish), `PickupCoins`, `PickupDrawer`, `PickupWheel` (thump), `PickupGouda` (sparkle), `Grunt`, `WaddleStep`, `RollRumble` (loop), `Throw` (whoosh), `Catch` (thwap), `DropLight`, `DropHeavy`, `FragileCrack`, `KaChing` |
| Stealth | `Spotted` (stinger), `GuardHuh` ("?"), `AlarmBeep`, `SirenLoop`, `ShiftChime`, `CountdownTick`, `Captured` (boing + whistle), `CellDoor`, `Rescue` (yay), `GrateCrawl`, `BarrelIn`, `BarrelOut`, `Sniff`, `Sneeze` |
| NPCs | `KarelShout` (voice-like grumble, no words), `DoorSlam`, `KarelTsk`, `BoefBark`, `BoefSniff`, `BoefMunch`, `GuardSnore` |
| Events | `GoudaDing` (bell), `JustMadeIt` (choir aah), `StarChime`, `RankUpFanfare`, `MoneyShower` |
| Gadgets | `Bzzt` (EMP), `NoisemakerRing`, `BubbleShoot`, `BubblePop`, `DroneHum` (loop), `CrowbarCreak`, `Crack` (exists) |
| UI | `UiTap`, `UiBack`, `HintBlip`, `PingSpot`, `PingGuard` (higher), `PingQuick` (one pitch per preset), `ToastSoft` |

---

## 6. Visual language

**Loot classes (colour + shape, also on the carry chip, crew list and pings)**

| Class | Colour | Shape |
|---|---|---|
| Small | Mint `#5EE6A8` | ● circle |
| Medium | Yellow `#FFD23F` | ■ square |
| Heavy | Purple `#B98CFF` | ⬢ hexagon + weight icon |
| Main (Golden Gouda) | Gold `#FFC21A`, white outline, glow | ♛ crown |
| Rare (Blue Moon) | Sky `#6FD3FF` | ✦ sparkle + shimmer |

**Guard states** keep the current icons, now on a shaped badge: Suspicious "?" on a yellow circle, Alert "!" on a red
triangle, Search "?!" on an orange diamond, Stunned/bubbled "zZ" on a light-blue bubble; the detection bar above the
head stays (yellow → red). Boef: paw badge. Karel: broom badge with name tag "KAREL".

**Alarm:** QUIET green (0 pips, open ring) · SUSPICIOUS yellow (1) · SEARCHING orange (2) · LOCKDOWN red (3 + siren
icon). **Crew:** colour from `CrewColor` (exists) plus a fixed shape per slot (circle, square, triangle, diamond) on
pings, name tags and the crew list.

**Base palette** (from `Hud.Colors`, moved to `Lib/Theme.luau`): panel `#10121A` at 25% transparency, text `#F5F5FA`,
muted `#AAAFBE`, accent crew-orange `#FF8020`, danger `#FF4646`, warn `#FFC83C`, good `#5AD278`. Text on 3D always
gets a dark `UIStroke` (1.5–2 px). Contrast target ≥ 4.5:1 on panels; check every screen at 50% brightness.

**Fonts:** display (banners, pops, numbers) = FredokaOne; UI text = BuilderSans Bold (fallback GothamBold). Minimum
text height 14 px at UIScale 1 (body), 18 px for anything read during action. Honour `GuiService.PreferredTextSize`
by one step up (proposed).

**UIScale:** one `UIScale` per ScreenGui, recomputed on viewport or input change. Touch:
`clamp(viewportHeight / 420, 1.0, 1.4)` (phones stay 1.0 so 48/64 px are real; tablets up to 1.4). Keyboard/gamepad:
`clamp(viewportHeight / 720, 1.0, 1.5)` (1080p ≈ 1.4, readable on a TV). Offsets designed at 640 × 360 + anchor points,
`UIListLayout` for lists, `TextScaled` + `UITextSizeConstraint` (min 12).

**Safe areas:** HUD ScreenGuis use `ScreenInsets = CoreUISafeInsets` (notch, Roblox top bar); full-screen layers
(loading, vignettes, payout backdrop) use `None` + `IgnoreGuiInset = true`. Keep clear: joystick zone (left 35% ×
bottom 50%), jump button, top-left (Roblox chat).

**Reduce motion:** default from `GuiService.ReducedMotionEnabled`; removes shake, camera dips, slow-mo zoom, edge
sweeps/flashes (static frames instead), wobble and money shower. Banners and pops fade without bounce.

---

## 7. Architecture

### 7.1 Client modules (owner ux unless noted)

**Lib (helpers):**
- `Theme` (new): palette, loot/guard/crew styles, fonts, sizes.
- `UiScale` (new): scale formula; root ScreenGuis (HUD, Overlay, Modal, Fullscreen) with their insets.
- `Hud` (change): becomes the UI kit (`make`, `panel`, `text`, `button`, `toast`, `banner`); window ring, chain panel
  and lockdown label move out or go.
- `Screens` (new): one modal at a time, gamepad selection via `GuiService.SelectedObject`, hides the cluster.
- `Juice` (new): `pop`, `flyTo`, `countUp`, `hitstop`, `slowmo`, `edgeFlash`; respects reduce motion.
- `Audio` (new): `play`, `playAt`, music crossfades, SoundGroups. Data in `src/shared/Sounds.luau` (new).
- `RoundState` (new): read-only facade over round attributes with a `Changed` signal; timers from
  `workspace:GetServerTimeNow()`.
- `Settings` (new): local cache + `Changed`; sends `SaveSettings`.
- `ClientState` (change): add `mode` = Explore | Carry | Drone | Hidden | Cell | Van | Menu | Spectate.
- `Actions` (change, shared with mechanics): remove ChainCall/Now/Wait/Restart; add `Use`, `Primary` (replaces
  `Fire`), `PingHold`, `CamPrev`, `CamNext`.

**Controllers:** `HudController` (change: status bar, crew list, chips, edge arrows, alarm/lockdown), `TouchController`
(rewrite: 3 + 1 cluster by `mode`), `ContextController` (new: custom ProximityPrompts → context button, world prompt,
hold ring), `JuiceController` (new: §4), `AudioController` (new: music from `RoundState` + local chase state),
`OnboardingController`, `CellController`, `PayoutController`, `GarageController` (Garage HUD, job board, gadget pick,
mirror, contracts, late join, spectate), `SettingsController` (all new), `PingController` (change: wheel, per-kind
sounds, mute list, spotting from the cell feed). `ChainCallController` is deleted together with `ChainCallService`.
Loading screen: `src/first/Loading.client.luau`.

**Owned by mechanics:** `GadgetController`, `DroneController` and carry input keep sending requests and set
`ClientState.mode`; the throw arc reuses the existing aim visual.

### 7.2 How UI listens
- **Attributes = state.** Everything a late joiner must see (phase, timers, van loot, alarm, carry, captured, in van).
  Read on start, then `GetAttributeChangedSignal`; no polling. Timers are server timestamps (`...EndsAt`).
- **Net events = moments and snapshots** (pickup, bank, spotted, payout, job board). Missing one is cosmetic only.
- **ProximityPrompts = context actions.** Mechanics/meta put prompts on loot, barrels, cells, doors, the van and the
  Garage stations: `Style = Custom`, short `ActionText`, `HoldDuration`, `KeyboardKeyCode = E`,
  `GamepadKeyCode = ButtonX`, attribute `ContextIcon` (proposed). The server handles `Triggered`; ux only renders
  (`PromptShown/Hidden`, `InputHoldBegin/End` from the touch button). Server-authoritative, no extra Net messages.

### 7.3 What ux needs from mechanics and meta (proposed names)

**Attributes on `ReplicatedStorage` (mechanics):** `RoundPhase` ("Garage" | "Briefing" | "Heist" | "Lockdown" |
"Payout"), `RoundStartedAt`, `RoundEndsAt`, `ShiftChangeAt`, `LockdownEndsAt`, `HeistId`, `JobName`, `Modifier`,
`VanLoot`, `CrewSize`, `AlarmLevel` (exists), `VanDepartAt` (meta).

**Character attributes (mechanics):** `CarryClass` ("Small" | "Medium" | "Heavy" | "Main" | nil), `CarryLoot`
(display name), `CarryPartner` (UserId), `Rolling`, `Pockets` (0–3), `Hidden`, `HideEndsAt`, `Captured` ("Carried" |
"Cell" | nil), `SelfEscapeAt`, `SelfEscapeUsed`, `InVan`, plus existing `Crouching`, `Operating`, `Bubbled`.

**Player attributes (meta):** `Cash`, `Rep`, `Rank`, `IsNewPlayer`, `CrewColor` (exists), `Gadgets` / `Charges_*`
(exist).

**Tags (mechanics/map):** `Loot` (with attributes `LootClass`, `Value`, `LootName`), `MainLoot`, `HideSpot`, `Cell`,
`VanZone`, `Karel`, `Dog`; existing `Guard`, `SecurityCamera`.

**Net server → client:**

| Message | Payload | Owner |
|---|---|---|
| `LootPicked` | userId, lootName, class, value | mechanics |
| `LootBanked` | userId, lootName, value, vanTotal | mechanics |
| `LootDropped` / `LootThrown` / `LootCaught` | userId, lootName, (from, to) | mechanics |
| `LootReturned` | lootName (Karel) | mechanics |
| `Spotted` | userId, by ("guard" / "camera" / "dog") — replaces `GuardAlert`/`CameraSpotted` | mechanics |
| `Captured` | userId, stage ("grabbed" / "cell" / "dropped") | mechanics |
| `Rescued` | userId, rescuerId or 0, how ("rescue" / "grate") | mechanics |
| `Sneeze`, `KarelShout`, `BoefBark` | userId or kind, position | mechanics |
| `GoudaLifted` | userId | mechanics |
| `Lockdown` / `ShiftChange` | endsAt, reason | mechanics |
| `Escaped` | secondsLeft | mechanics |
| `Busted` | — | mechanics |
| `Payout` | `{ items = {{name, class, value}}, vanTotal, bonuses = {{label, pct}}, cut, stars, rep, rankBefore, rankAfter, awards = {{userId, awardId}}, busted, firstJobToday }` | meta |
| `Onboarding` | step | meta |
| `JobBoard`, `Catalog`, `Contracts`, `Settings`, `RankUp` | snapshots (§1) | meta |
| `Toast`, `Window`, `Ping`, `Quick`, `Alarm` | exist | — |

**Net client → server:** `Drop()`, `Throw(target)`, `Roll(on)`, `LetGo()` (mechanics, non-prompt actions);
`ViewCam(index)`, `Spectate(userId)` (streaming; mechanics); `VoteJob`, `PickGadgets`, `BuyItem`, `EquipItem`,
`Feedback`, `SaveSettings`, `NextJob`, `ReturnToGarage`, `JumpIn` (meta); `Spot`, `Quick`, `Crouch` (exist).

**Award ids** come from meta (proposed set: Butterfingers, Karel's Nemesis, Self-EMP Award, Hero, Pack Mule, Ninja,
Sneezy, Dog Whisperer, Golden Hands, Fresh Crook); ux maps each id to an icon and a ≤ 6-word line.

---

## 8. Test plan (tester)

**Devices (Studio Device Emulator):** 640 × 360 Android, iPhone SE, iPhone 15 (notch), iPad landscape, 1366 × 768,
1920 × 1080, Xbox 1080p (gamepad only); "Server & 3 Clients" for crew tests. **50% brightness:** temporary
`ColorCorrectionEffect` (Brightness −0.25, Saturation −0.3; proposed dev toggle) + screenshots of every screen.

| Screen / area | Check |
|---|---|
| All | No overlap with the joystick, jump button, Roblox top bar or notch; no text clipped; every touch button `AbsoluteSize ≥ 48` (main ≥ 64) — automate with an `execute_luau` scan of the `TouchButtons` frame (proposed scenario `ux_10_button_sizes`) |
| Loading | Gone within 15 s; new player lands in the mini-job, returning player in the Garage |
| Mini-job | Each hint appears once, ≤ 5 words, disappears on completion; first bank ≤ 45 s on a straight run; funnel prints steps 1–8 in order in the server log |
| Garage | Tour runs once; job board voting with 2 clients; gadget pick max 2; mirror buy/equip with enough and too little Cash |
| Heist HUD | Timer matches between clients (± 1 s); loot meter updates on bank; crew list states (carrying, cell, van, hidden) |
| Carry | Button morphs for each class; CROUCH locked; throw ring clamps at 10 studs and turns green near a teammate; two-player carry tether and LET GO |
| Alarm / lockdown | Each tier visual; Gouda sequence: silence → ding → sirens; "POLICE" countdown; shift change at 7:00 |
| Captured / cell | Freeze is barely visible (not a stutter); feed switches cameras on all 3 input types; crawl-out unlocks at 15 s, once; rescue ring visible to both; Busted with all in the cell |
| Drive | Hold 3 s, release cancels; "LEAVES 1 BEHIND" shown; last-second slow-mo at ≤ 3 s |
| Payout | Tap skips the tally; stars and awards correct; NEXT JOB countdown; feedback sends once and never blocks |
| Settings | Sliders change Music/SFX groups live; values survive a rejoin; reduce motion removes shake, slow-mo zoom, flashes, money shower |
| Controller-only | Every screen opens, navigates and closes without mouse/touch; a selection highlight is always visible; no dead ends |
| Late join | Join at 0:30 → "JUMP IN" visible and works; join at 2:30 → no JUMP IN, timer correct, WATCH works; join during payout → Garage banner; no errors in the client console |
| Audio | No missing ids (Audio warns on `TBD`); music crossfades without gaps; ping sounds differ per kind |

---

## 9. Build order (work packages)

| WP | Content | Depends on |
|---|---|---|
| WP0 | Theme, UiScale, Screens, Settings cache, Audio + `Sounds.luau` with placeholder engine sounds, Juice | — |
| WP1 | Actions remap; TouchController 3 + 1 with modes; ContextController (custom prompts); retire chain/window UI | WP0; mechanics prompts on loot/van (can start with a test prompt) |
| WP2 | Heist HUD: status bar, crew list, carry chip, pockets, effect chips, edge arrows, alarm/shift/lockdown | WP0; mechanics round + carry attributes |
| WP3 | JuiceController + AudioController: every row of §4; source and fill audio ids (§5) | WP2; mechanics Net events |
| WP4 | Captured/cell view, rescue prompt, HOLD TO DRIVE, Busted | WP1, WP2; mechanics capture + escape |
| WP5 | Payout, awards, feedback, capture chip | WP3; meta `Payout` + `Feedback` |
| WP6 | Mini-job onboarding + funnel hints + Garage tour + first-time tips | WP1–WP3; map mini-job area; meta `Onboarding` |
| WP7 | Garage HUD, job board, gadget pick, mirror, contracts, late-join banner + spectate | WP0, WP1; meta lobby/shop/data; mechanics job start |
| WP8 | Loading screen (ReplicatedFirst), settings screen, camera sensitivity check | WP0; meta settings storage |
| WP9 | Polish pass: device matrix, 50% brightness, controller-only, reduce motion, fixes from the tester | all |

WP0–WP2 can start now against placeholder attributes; WP3–WP7 follow the mechanics/meta contracts as they land.
