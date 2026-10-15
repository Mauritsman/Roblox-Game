# Advisor brief: from prototype to beta

*Advisor, 16/10/2026. Based on gameplan v1.3, `docs/ontwikkelen.md` and web research (sources at the bottom).
Direction: **"Sneak in, grab as much cheese as you dare, get out."** This brief overrides the gameplan; the mandatory
chain and the 10 s window are dropped. All numbers are starting values and belong in `src/shared/Config.luau`.*

## 0. Decision table

| Topic | Decision |
|---|---|
| Core | Greed versus risk: more loot = slower = easier to catch. Loot in the van is safe. |
| Round length | Max. **8:00** (usually 5–7 min). Session goal **≥ 20 min** = 3 rounds via "NEXT JOB" (10 s). |
| Loot | Small (pocket, max. 3), medium (hands), heavy (slow alone, roll, or carry with two), main loot. Map 1: ±3,900 Cash, more than a crew can take. |
| Main loot | Golden Gouda always present, 1 of 3 spots, visible from the start. Lifting it = LOCKDOWN, **60 s** to escape. |
| Guards | Solo 2 · duo 3 · trio 3 · four 4 (map 1); +1 on maps 2–3. Max. 7 NPCs per server. |
| Caught | Carried to the cell; a teammate frees you (2 s) or you self-escape once per round (15 s). All in the cell = BUSTED (50% of van loot). |
| Alarm | Ladder stays (100/200/300). LOCKDOWN = 60 s chase (was 90), not a loss. |
| Teamwork | A bonus, not a must: carry together (12 vs 7 studs/s), throw, rescue, +15% per extra member. |
| Randomness | Loot spots, Gouda spot, 2 of 4 entrances locked, guard routes, 2nd exit (50%), 3 jobs, 6 modifiers. |
| Hiding, NPCs | 8–12 barrels per map (20 s max); Boef smells cheese; Karel closes doors, returns loot. |
| Maps | **3**: The Golden Wheel (Rank 1), Praline Palace (Rank 3), Tulip Auction (Rank 5). Map 3 is cut first. |
| Lobby | One place, 4-player servers, hideout "The Garage" in the same server; newcomers start in a 3-min mini-job. |
| Progression | Cash + Crew Rank, 3 daily contracts, weekly "Most Wanted", trophy wall. No pay-to-win, no paid randomness. |
| Monetization | Beta: **off** (free private servers). Cosmetics at launch, Crew Pass ±2 months later. |
| Beta | Private → max. 10 Early Testers → open beta 16+ "[BETA]". Goals: D1 ≥ 10%, session ≥ 20 min, ≥ 70% finish the mini-job. |
| Not in the beta | Roles, minigames, Winch, Spy Cams, Asset Recovery, Cover Story. |

## 1. What works on Roblox (2025–2026)

| Game | What works | What we take |
|---|---|---|
| **ROB IT** (Dec. 2025; 6–7 min runs, 20-player servers) | Loot has weight; reach the van before the timer or lose it | Our new core: our most direct competitor. Our edge = co-op and humor |
| **Steal a Brainrot** | A thief walks slowly and drops the item on one hit → chases; loot is visible in your base | Carrying = slow and vulnerable; trophy wall |
| **R.E.P.O.** (Steam, 2025) | Carrying big, fragile items together → physics chaos, viral clips | Heavy = carry with two; fragile loot |
| **Doors** | Elevators for 1–4 players, random rooms; stay ±12 s in a closet and you get pushed out | Barrels with a time limit |
| **Flee the Facility** | Caught player in a freeze pod, teammates rescue them | Cell + rescue |
| **Jailbreak** | Arrested = back to prison, escape again | Caught ≠ out |
| **Dandy's World** | Elevator, random floors, events like "Blackout" | Modifiers |
| **Notoriety / PAYDAY** | Throwing loot bags to a teammate | Throwing medium loot |
| **99 Nights in the Forest** | Co-op, safe camp versus danger, seasonal updates | Safe Garage; weekly job |

**What Roblox rewards** (since 15/06/2026): click-through, few players leaving in the first 60 s–3 min (*first play
bounce*), play days up to D28, playtime, and coming back to play with friends. Games with 19–24 min sessions reach a
median D1 of 11.5%, versus 6.2% for 4–6 min (GameAnalytics 2025; *D1 = share of new players who return the next day*).
**So: short rounds, long sessions.**

**Stealth pitfalls on Roblox and phones**
1. Seen once = lost → players quit. *Fix:* chase and cell.
2. Slow start → players leave in minute one. *Fix:* first loot within 45 s.
3. Unreadable AI on a small screen, or too dark at half brightness. Keep icons and cones; test at 50% brightness.
4. Lag: a 0.6 s meter feels like "I saw nothing". Minimum 0.8 s.
5. Strangers without chat rarely cooperate; trolls trigger alarms. Solo must work; van loot stays safe.
6. Free physics (rolling wheels) causes bugs and cheating: the **server** moves loot. Max. 7 NPCs; pathfinding only
   when chasing.

## 2. Core loop with numbers

**A round**

| Clock | What happens |
|---|---|
| 0:00 | The van stops; the job card shows the Gouda spot and the modifier. No separate scouting phase. |
| 0:00–7:00 | Steal quietly and bring loot to the van ("banking"). |
| Any time | Gouda lifted or alarm tier 3 → LOCKDOWN: "POLICE IN 60". |
| 7:00 | "SHIFT CHANGE IN 60" (if no lockdown is running yet). |
| 8:00 | Police: anyone not in the van is caught. |
| End | Free players in the van + 3 s "HOLD TO DRIVE" → payout (30 s) → "NEXT JOB". |

**Loot on map 1 (per round; walking = 16 studs/s)**

| Class | What | Value | Carrying and speed |
|---|---|---|---|
| Small | Cheese Cube ×6, Tip Jar ×2, Cash Drawer ×1 | 25 / 50 / 150 | In your pocket, max. 3; 16, crouching and gadgets allowed |
| Medium | Cheese wheel ×8 (from 12 spots) | 150 | In your hands; 12, no crouching, no gadget; throw up to 10 studs |
| Heavy | Big Wheel ×2 (from 4) | 400 | Alone 7 · rolling 11 (rumble audible at 15 studs) · with two, 12 each |
| Main loot | Golden Gouda (1 of 3 spots) | 1,500 | As heavy |
| Rare | Blue Moon Cheese (5% chance instead of a wheel) | 500 | As medium |

Total ±3,900. Solo you realistically get 800–1,500, a crew of four 2,500–3,900. Score: 1★ ≥ 500, 2★ ≥ 1,500,
3★ = Gouda + ≥ 2,500.

**Detection and alarm**
- The guard cone stays (70°, 35 studs lit, 18 dark). Meter 0.8 s up close to 2.0 s far (now 0.6–1.9). Carrying medium/
  heavy loot fills it ×1.25 / ×1.5 faster.
- Speeds: patrol 6, investigate 9, chase **15**. Empty hands (16) always escape; carriers must choose: drop, throw or
  hide. After 3 s out of sight the guard searches for 15 s.
- Cameras and alarm points stay as in `Config.Alarm`; `LockdownSeconds` 90 → 60.

**Caught**
- A guard in Alert within 3.5 studs grabs you in 1 s and carries you (8 studs/s) to the cell. A Bubble or Noisemaker
  on him makes him drop you: the hero moment. Your loot drops on the spot; Karel returns it after 30 s.
- In the cell you watch the cameras and ping. Rescue: a teammate holds USE for 2 s. Once per round you can crawl out
  through a loose grate after 15 s.
- Everyone in the cell at once = BUSTED: round over, 50% of the van loot, Rep still counts.

**Scaling and payout**
- Loot stays the same for every crew size (more than you can carry = the greed choice); guards scale (decision table).
- Per player: van loot ÷ crew size × (1 + 0.15 per extra crew member). Solo 1,000 → 1,000 Cash; four with 3,000 →
  1,088 each.
- Bonuses: "No One Left Behind" +10%, "Quiet Job" (never above tier 1) +20%, first job of the day ×2.

**Hiding, dog and Karel**
- Barrels, crates, lockers: 8–12 per map, in/out 0.5 s, only with empty hands or small loot. A guard who saw you get in
  pulls you out. Warning at 15 s; at 20 s you sneeze ("ACHOO", 15 studs) and tumble out.
- **Boef** (map 1, outdoors) smells cheese within 15 studs, follows the carrier and barks every 2 s (guards within
  30 studs come to look). Throw him a small cheese (12 s busy, value lost) or a Noisemaker (8 s). Never bites.
- **Karel** patrols every ±60 s: closes open doors, pockets Noisemakers, puts dropped loot back, shouts at traces (+20).
  Catches nobody. Not in the mini-job.

**Gadgets:** everyone has a Crowbar (door 1.5 s, cage 3 s) and picks 2 of Drone, Noisemaker, EMP, Bubble Blaster.
They don't work with full hands, so a teammate with free hands protects the carriers.

## 3. Maps for the beta

**Advice: 3 maps.** One map gets boring after 5–6 rounds; 4 or more is too much building and testing. 3 maps ×
6 modifiers × randomness gives enough variety plus two maps to unlock. All maps share the same systems plus 1–2 own
rules; maps 2 and 3 are smaller (±80 × 60 studs) and reuse the canal-street parts.

| Map | Theme | Mechanically different | Unlock |
|---|---|---|---|
| 1. **The Golden Wheel** | Cheese shop + ripening hall (exists) | Learning map: wide routes, Boef, wheels roll down the ramp, 2nd exit by boat | Rank 1 |
| 2. **Praline Palace** | Belgian chocolaterie in Polderdam's "Flemish quarter" | Conveyor belts move loot and players; machine noise covers the Crowbar; a "Robo-Mop" (robot vacuum) beeps when it bumps you, EMP stops it; fragile Praline Tower (drop = −25%) | Rank 3 |
| 3. **Tulip Auction** | Flower auction | Fragile bulbs and vases; push carts (4 medium items, 12 studs/s, squeaky wheels); cold rooms whose door shuts after 10 s; auction clock with a rotating spotlight | Rank 5 |

If one crew member has a map unlocked, the whole crew can play it: veterans bring newcomers along. Avoid: casinos
(label Moderate), real brands, tall vertical maps.

**Modifiers (6):** Power Cut (lights and cameras off, guards with flashlights, +20%), Health Inspector (extra snitch,
+15%), Wet Floor (sliding and squeaking, +10%), Rush Job (6:00, +25%), Sleepy Guards (meter 30% slower, −20%), Double
Shift (+1 guard, +30%). The job board always shows 3 jobs (map + modifier); modifiers only from your 3rd round.

## 4. Hideout, session and first minute

- **One place, 4-player servers.** The Garage (an old garage under a bridge) and the 3 maps sit far apart in one world,
  built at server start (`MapService:Build`); each round only resets loot, doors and guards. StreamingEnabled sends only
  your surroundings to your phone. No teleports, so it is all testable in Studio.
- In the Garage: job board, van, gadget rack, mirror (looks), trophy wall, a cheese-throwing practice yard.
- **Starting:** step into the van → 15 s countdown; whole server inside → 3 s. Solo: GO.
- **Friends:** invite button; friends join your server. "Private Crew" = your group to its own closed server
  (*reserved server*, only works in the published game).
- **Strangers** joining mid-round wait in the Garage ("Crew on a job — 3:10 left", TV with the camera feed) or
  "JUMP IN" via the van during the first 2 minutes.
- **A new player's first 60 s** (no Garage): loading screen → on the quay (0:05) → "Grab the cheese", a wheel 15 studs
  away (0:15) → waddle back, "HEAVY!" (0:30) → "+150" with a till sound (0:45) → snoring guard: "Sneak past" (0:60).
  Then Gouda, alarm, roll to the van, payout, Garage: ±3 min. Hints: max. 5 words + icon.

## 5. Progression and meta

- **Cash** (to spend) and **Rep** (Cash earned + 100 per round, also on failure; never drops). Rank n → n+1 costs
  1,000 × n Rep: Rank 3 after ±3 rounds, Rank 5 after ±10, Rank 10 after ±45.
- **Buy with Cash:** sidegrade gadgets 2,000–4,000 (different, not stronger), masks and hats 500–3,000, van colors
  5,000, other vans 15,000–40,000 (looks only).
- **Coming back (D1/D7):** 3 daily contracts (250–500 Cash, e.g. "Free a teammate"), first job of the day ×2, a weekly
  "Most Wanted" job (free cosmetic for 3★), a cheese collection book, a trophy wall of every Gouda you stole.
  Notifications only for opted-in 13+ players, max. 1 per day.
- **Randomness only for free** (rare loot, free Glovebox, visible odds). Nothing random for Robux or Robux-bought
  currency (banned in Belgium, blocked in the Netherlands).

## 6. Monetization

**Beta: off.** The algorithm weighs retention above revenue, and it avoids lost purchases while the data format still
changes. Do: free private servers; build purchase handling (*ProcessReceipt*) and test it with Studio test purchases.
**Launch:** cosmetics only (gameplan §8.3). **Crew Pass** (§8.5) ±2 months later, with ≥ 4 maps and stable D7.
Never for sale: Cash, boosters, "get out of jail", gadgets, maps.

## 7. Beta checklist

| Item | Minimum |
|---|---|
| Data | DataStore with session locking (e.g. the ProfileStore library) and a version number. No wipe. |
| Onboarding | Mini-job measured in 8 steps with `LogOnboardingFunnelStepEvent` (*funnel: how many players reach each step*; server only, published game only). |
| Analytics | A funnel per round (start → 1st loot → banked → escaped) + economy events for Cash. Tune numbers live with *Configs* [TO BE CONFIRMED]. |
| Mobile | Buttons ≥ 48 px (main 64), max. 3 action buttons + 1 context button; test on a cheap Android, a small iPhone, 50% brightness. |
| Performance | ≥ 30 fps on a cheap phone, load < 15 s, max. 7 NPCs. |
| Feedback | One tap after each round (happy/neutral/sad) + fixed tags ("Too hard", "Bug", "Fun"), no free text. Roblox community group + DevForum "Creations Feedback". |
| Game page | Text-free 512×512 icon; 3–5 thumbnails (1920×1080) with Thumbnail Personalization; first line "Co-op cheese heist for 1–4. Sneak in, grab, escape."; title "Crowbar Crew [BETA]". |
| Label | Full questionnaire → expected **Mild**. A shorter publishing flow has been rolling out since 13/10/2026 [TO BE CONFIRMED]. |
| Audience | A new game is first **only for age-checked 16+ players**. Kids & Select only after 250 unique plays by "highly engaged" players in 60 days + ID check, 2FA and a refundable fee (1,000 Robux per gameplan §5.5 [TO BE CONFIRMED]) or 2 months of Plus. |
| Safety | No free chat, Quick Words set up, the server decides everything. |

**How to run the beta**
1. **Private** (week 0): the team tests in Studio (Server & Clients, 4 players); Maurits publishes privately to test
   data saving and Private Crew.
2. **Closed** (weeks 1–2): "Invite Early Testers" in Creator Hub, max. 10 friends [TO BE CONFIRMED: rollout]. Two test
   evenings per week, at least half on phones.
3. **Open beta 16+** (weeks 3–8): public with "[BETA]". Goals: ≥ 70% finish the mini-job, D1 ≥ 10% (aim 15%),
   D7 ≥ 1.5%, session ≥ 20 min, 250 highly engaged plays within 60 days.
4. **Apply for Kids & Select** once that threshold is reached (Maurits decides on ID, 2FA and fee).

## 8. Juice and humor (what players clip)

- Waddling with a big cheese; a wheel rolling down the stairs, Boef chasing it.
- A guard carrying you off, legs kicking, until your teammate bubbles him.
- Karel shutting the door in your face: "WHO LEFT THIS OPEN?!" Sneezing in a barrel at the worst moment.
- Lifting the Gouda: music stops, one "ding", then sirens and chase music.
- Last-second van escape: slow motion + "JUST MADE IT!" and an automatic screenshot (`CaptureService`) the player may
  save or share.
- Payout: money shower, "KA-CHING" per item, awards ("Butterfingers", "Karel's Nemesis", "Self-EMP Award").
- "+150" popup per loot, loot meter on top, 0.08 s freeze when caught, a unique sound per loot type.

## 9. The 5 biggest risks

1. **Too similar to ROB IT** (same core, 300M visits). Carrying together, rescues, Karel and Boef must show in minute
   one and on the thumbnails.
2. **Too much work** for one beta. Order: map 1 complete → map 2 → map 3 only if time allows.
3. **Beta players are 16+**, not 9–15: the humor must land with teens; 250 plays won't come by themselves.
4. **Empty servers:** with few players almost everyone plays solo, so solo must be genuinely fun.
5. **Phones and physics:** rolling, throwing and 7 NPCs on a cheap Android. Server-moved loot; test early.

## Sources (accessed 16/10/2026)

- ROB IT: <https://earnaldo.com/blog/rob-it-vs-jailbreak>
- Steal a Brainrot: <https://games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/> · <https://medium.com/@emtertoszef/steal-a-brainrot-phenomenon-6af7b49081e0>
- R.E.P.O.: <https://en.wikipedia.org/wiki/R.E.P.O.> · <https://www.gfinityesports.com/article/5-reasons-to-play-repo-if-you-love-lethal-company>
- Doors: <https://doors-game.fandom.com/wiki/Hide> · <https://breezewiki.discard.no/doors-game/wiki/Lobby>
- Flee the Facility: <https://www.sportskeeda.com/esports/how-use-freeze-pod-roblox-flee-facility>
- Jailbreak: <https://jailbreak.fandom.com/wiki/Arrest>
- Dandy's World: <https://itemlevel.net/dandys-world-complete-beginners-guide/>
- Notoriety: <https://www.ofzenandcomputing.com/master-notoriety-controls/>
- 99 Nights in the Forest: <https://www.gosugamers.net/entertainment/news/77777-99-nights-in-the-forest-how-this-endless-roblox-game-had-me-addicted-in-2025>
- Algorithm: <https://create.roblox.com/docs/discovery> · <https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575>
- Session length and retention: <https://www.gameanalytics.com/cn/reports/2025-roblox-report>
- Onboarding and Configs: <https://create.roblox.com/docs/production/game-design/onboarding>
- Funnels: <https://create.roblox.com/docs/production/analytics/funnel-events>
- Kids & Select: <https://create.roblox.com/docs/production/publishing/kids-and-select> · <https://devforum.roblox.com/t/highly-engaged-player-threshold-drops-to-250/4820164>
- Publishing flow and Early Testers: <https://www.gamebusiness.jp/article/2026/10/13/28297.html>
- Paid random items: <https://create.roblox.com/docs/production/monetization/paid-random-items>
- Notifications: <https://create.roblox.com/docs/production/promotion/experience-notifications>
- CaptureService: <https://devforum.roblox.com/t/captures-apis-are-now-available/2838188>
