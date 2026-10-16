# Beta spec: meta systems

*Meta agent, 16/10/2026. Scope: saving, economy, progression (ranks, stars, unlocks, perks), the Garage's meta
stations, analytics and monetisation readiness. Follows `docs/research/advisor-brief.md` and
`docs/research/advisor-notoriety.md` (the latter wins where they differ). Round flow, van countdown, voting time,
NEXT JOB, JUMP IN, awards, stars, Mask Up triggers, difficulty and perk **effects** are in `docs/beta-spec.md`
(mechanics); Garage geometry in `beta-spec-maps.md`; screens in `beta-spec-ux.md`. "(advisor)" = decided by the
advisor; "(proposed)" = my assumption, open for the advisor. Every number goes into the **meta block** of
`src/shared/Config.luau`.*

## 0. Decisions at a glance

| Topic | Decision |
|---|---|
| Data library | **Our own layer** (`DataService`), using ProfileStore's proven lock algorithm. Nothing vendored. Plan B: vendor ProfileStore (MIT, one file) behind the same API if the private-test lock scenarios fail, and only before open beta. |
| Data format | One DataStore key per player, a `version` field, ordered migrations, unknown keys kept. The store name never changes (a new name looks like a wipe). |
| Payout | Mechanics sends **facts** (`RoundResult`); meta computes all Cash and Rep (`Logic/Payout`). |
| Heist board | A card per heist (locked ones greyed out) + difficulty, one **Hot Job** every 30 min (+25%), **Fresh** +20% (advisor). |
| Difficulty | Easy / Normal / Hard, ×0.8 / ×1 / ×1.4 Cash and Rep; Hard per heist at 2★ on Normal (advisor). |
| Stars and unlocks | 3★ per heist per tier (27); +300 × tier per new star; heist mask for 3★ on Hard. Praline Palace = 3★ on The Golden Wheel **or** Rank 4; Tulip Auction = 3★ on Praline Palace **or** Rank 7 (advisor). |
| Perks | 3×3 tree, costs 1/2/3, 1 point per rank from Rank 2, max 3 equipped, free respec (advisor). |
| Ranks, prestige | Rank 1–20 in the beta; **no prestige** until "Legend" at Rank 50 later (advisor). |
| Masks | The key cosmetic: 16 of 28 items, fixed prices or rewards, auto Mask Up (advisor). |
| Glovebox | **Not in the beta** (§3.7). |
| Monetisation | Off. `ProcessReceipt` is built and tested with fake receipts in Studio. Private servers are free. |

**Why our own layer:** the risky decisions (taking or stealing a lock, migrating) become pure functions that Lune tests
against a fake store, and ProfileStore can't run in Lune. A vendored 2,000-line file also fights our `--!strict`,
selene and stylua gates. With one place, 4-player servers and a single teleport, the hard cases ProfileStore solves
barely apply, and we keep full control of the record format.

## 1. Player data schema v1

**Stored record** (DataStore `PlayerData`, key `u_<UserId>`); only `DataService` sees the wrapper:

```lua
{ data = PlayerData, lock = { session: string, job: string, place: number, at: number }?,
  savedAt: number, saveCount: number, steals: number }
```

**`PlayerData` v1** (times = `os.time()` UTC seconds; Cash and Rep are integers ≥ 0):

| Field | Type | Default | Meaning |
|---|---|---|---|
| `version` | number | `1` | Schema version |
| `cash` | number | `0` | Spendable Cash |
| `rep` | number | `0` | Lifetime Rep, never decreases. Rank is **derived** (capped at 20 in the beta) |
| `rankRewarded` | number | `1` | Highest rank whose reward was paid (no double rewards) |
| `owned` | `{[itemId]: number}` | `{}` | Items earned or bought with Cash → time. Free items implicit (`Config.Catalog`) |
| `robuxOwned` | `{[itemId]: number}` | `{}` | Reserved for launch; Robux items kept apart (gameplan §8.11), never removed |
| `equipped` | `{Mask: string, Hat: string?, Van: string}` | `{Mask = "PaperBag", Van = "GetawayWhite"}` | Worn cosmetics (always a mask for Mask Up) |
| `loadout` | `{string}` (2) | `{"Noisemaker", "BubbleBlaster"}` | The 2 gadget picks; the Crowbar is always added |
| `perks` | `{unlocked: {[perkId]: true}, equipped: {string}, respecs: number}` | `{{}, {}, 0}` | Perk tree (§4.4) |
| `heists` | `{[heistId]: {stars: {[tier]: number}, clears: {[tier]: number}, bestLoot: number}}` | `{}` | Best stars (0–3) per tier, escapes, top haul |
| `recentHeists` | `{string}` (≤ 2) | `{}` | Heists of your last 2 real rounds (Fresh bonus) |
| `lastDifficulty` | string | `"Normal"` | Preselected tier on the board |
| `onboarding` | `{done: boolean, steps: {[string]: true}}` | `{false, {}}` | Mini-job state, funnel steps logged |
| `daily` | `{day, contracts: {Contract}, firstJobUsed, rerolls}` | `{0, {}, false, 0}` | `Contract = {id, target, progress, reward, done}` |
| `weekly` | `{week: number, mostWantedDone: boolean}` | `{0, false}` | |
| `collection` | `{[lootId]: number}` | `{}` | Times banked per loot type |
| `trophies` | `{Trophy}` | `{}` | Main loot banked, newest last, max 30. `{loot, heist, tier, crew, at}` |
| `stats` | numbers | all `0` | `rounds, escapes, busts, mainLoot, rescues, lootBanked, cashEarned, cashSpent, bestPayout, playSeconds, sessions` |
| `settings` | `{[string]: boolean \| number}` | `{}` | Keys in `Config.Data.SettingsKeys` (ux) |
| `seenTips` | `{[tipId]: number}` | `{}` | First-time tips shown (ux: max 2) |
| `receipts` | `{[purchaseId]: number}` | `{}` | Processed Robux receipts, newest 100 |
| `recentRounds` | `{string}` | `{}` | Last 10 settled `roundId`s |
| `firstSeen`, `lastSeen` | number | now | |

**Per session only:** session id and lock, dirty flag, last write, save failures, rate-limit buckets, job vote, session
start (added to `playSeconds` on leave), rounds this session, last feedback round.

**Migrations** (`Logic/DataSchema.luau`): `migrations[n]` turns version *n* into *n+1* (pure). On load: run every step
up to `CURRENT`, then `reconcile(data, defaults())` fills missing keys deeply and **never deletes unknown keys**.
`version > CURRENT` (a newer server saved it) → kick: *"Crowbar Crew was updated. Please rejoin to keep your
progress."* A stored value that isn't a valid table → raw copy to DataStore `PlayerDataCorrupt`, fresh defaults, log
`DataCorruptReset`. Every migration ships with a Lune test on an old fixture. (Legend prestige, Big Cheese and the
Glovebox each arrive later as a migration.)

## 2. Data layer design

### 2.1 API (`Services/DataService.luau`)

```lua
DataService:WaitForData(player, timeout: number?): PlayerData?  -- nil if failed or left
DataService:Get(player): PlayerData?                 -- live table, READ ONLY by convention
DataService:Update(player, reason: string, fn: (PlayerData) -> ()): boolean  -- the only way to change data
DataService:SaveNowAsync(player, reason: string): boolean   -- yields; after payouts, purchases, receipts
DataService:ReleaseAsync(player): boolean            -- save + unlock (before a teleport)
DataService:OnBeforeShutdown(fn: () -> ())           -- runs (max 5 s) before the final saves
DataService.Loaded: Signal<(Player, PlayerData)>
DataService.Changed: Signal<(Player, string)>
```

`Update` changes memory, marks dirty, fires `Changed` and schedules a `ProfileSync` (max 4 per second).

### 2.2 Backends

- **Real:** `DataStoreService:GetDataStore("PlayerData")`; in Studio with API access the name gets `_Studio`, so tests
  never touch live data.
- **Memory:** Studio without API access (a `GetAsync` probe errors) or `Config.Data.UseMemoryInStudio = true`; prints
  once *"[Data] Studio without API access: memory only, nothing is saved."* Fault injection via
  `Config.Data.Mock = {FailRate, LatencySeconds}`.

Both expose `update(key, transform)` and `get(key)`; Lune tests use a fake backend.

### 2.3 Session locking (`Logic/SessionLock.luau`: pure load/save/release transforms)

Every write uses `UpdateAsync`, never `SetAsync`. Each session gets a GUID (`game.JobId` is empty in Studio).

**Load** (PlayerAdded): up to `LoadAttempts = 6`, `LoadRetrySeconds = 4` apart.
1. No record → create defaults with *my* lock.
2. Lock empty, mine, or older than `StaleLockSeconds = 600` → take it.
3. Fresh foreign lock → return `nil` (cancel) and retry; from attempt `StealAfterAttempts = 5` (≈ 16–20 s) **steal**
   it (`steals += 1`, event `DataLockStolen`).
4. Migrate + reconcile; if the player already left, release at once.
5. All attempts fail → kick: *"We couldn't open your crew file. Please rejoin in a minute."* Never play on defaults
   that could overwrite a real save.

**Why stealing is safe:** a player is only in one server, so the old holder is either finishing its leave-save
(usually 1–2 s) or dead. The **save transform writes only if `lock.session` is still mine**; otherwise it cancels, ends
the session and kicks the player if present (*"Your save was opened in another server."*). Two servers never both
write; payouts and purchases save immediately. **Same-server rejoin** waits for that user's release (≤ 30 s).
**GDPR:** the transform returns `{player.UserId}` as `userIds`. DataStore's own versions (30 days) are the repair path.

### 2.4 Retries, budget, autosave

- Each DataStore call: up to 5 attempts, delay `min(2^(n−1), 16)` s + 0–0.5 s jitter (`Logic/Backoff.luau`).
- ≥ `MinSecondsBetweenWrites = 7` s per key (limit 6); requests in between merge into one save.
- Autosave every `AutosaveSeconds = 120`, spread over the interval, always writing (refreshes `lock.at`); skipped if
  the `UpdateAsync` request budget < 2 × players (limit 60 + 10 × players per minute; we use ≈ 2).
- 3 failed saves in a row → `SaveStatus("Trouble")` (*"Saving is slow — your progress is safe and we keep trying."*).

### 2.5 Leaving, teleports, shutdown

- **PlayerRemoving:** add play time, `ReleaseAsync` (save + `lock = nil`); idempotent.
- **Teleport (Private Crew only):** `ReleaseAsync`, attribute `Teleporting` (now `Update` returns false),
  `TeleportAsync`; on `TeleportInitFailed` load again.
- **BindToClose:** stop new loads, run `OnBeforeShutdown` hooks (≤ 5 s; RoundService settles the running round as
  `Shutdown`), release all sessions in parallel, wait ≤ 25 s. Logs *"[Data] released n/n in x s"*.

### 2.6 Client view and attributes

- `ProfileSync(view)`: `PlayerData` minus `receipts`, `recentRounds` and the wrapper, plus derived `rank`,
  `repIntoRank`, `repForNext`, `title`, `skillPoints`, `heistsUnlocked`, `tiersUnlocked`, `totalStars`, `dayResetsAt`,
  `weekResetsAt`. Under 6 KB, so always the full view. It covers ux's `Contracts`, `Settings` and `Catalog` snapshots
  (the catalog itself is `Config.Catalog`, readable on the client).
- Player attributes: `DataLoaded`, `Cash`, `Rep`, `Rank`, `Title`, `IsNewPlayer`, `RoundsPlayed`, `HeistsUnlocked`,
  `Loadout`, `Perks` (comma lists), `MaskId`. `leaderstats.Rank` for the player list. `Activity` / `InRound` and
  `Masked` are mechanics'.

## 3. Economy

### 3.1 Prices (Cash)

| What | Price | Rank |
|---|---|---|
| Masks and hats | 500–3,000 (§5.4) | 1 / 2 (3,000 items: 7) |
| Van colours | 5,000 each | 4 |
| Sidegrade gadgets: Periscope · Lockpick Set · Fake Delivery (gameplan §4.7) | 2,000 · 3,000 · 4,000 | 2 · 5 · 8 |
| Prank Arsenal sidegrades, other vans (15,000–40,000) | — | After the beta (advisor / needs models) |

A sidegrade **only appears if mechanics defines `Config.Gadgets[<id>]`**. Base gadgets are free; bought items are kept
forever. Perks are never bought (§4.4).

### 3.2 Rewards

| Source | Amount |
|---|---|
| Round payout | §3.4 (≈ 800–1,500 solo on Normal; ≈ 1,100 each in a good crew of four) |
| First **escaped** job of the UTC day | Cash ×2 (proposed: a Busted round never uses it up) |
| New star (per heist × tier, first time) | 300 × tier multiplier (Easy 240, Normal 300, Hard 420) (advisor) |
| Daily contracts | Easy 250 · Medium 350 · Hard 500 |
| Rank-up | 100 × new rank (proposed) |
| Mini-job | Flat 500 "Welcome bonus" + 100 Rep (replaces the formula) |
| Most Wanted | The week's reward cosmetic, or 1,500 if owned |

A daily player (3 rounds) earns ≈ 5,000 a day. The buyable catalog costs ≈ 41,000 (≈ 8 play days), plus 27 stars and
the reward masks to chase. Launch adds vans for 15,000–40,000.

### 3.3 Rep

Rep per round = the round's Cash **before** the daily ×2 + **100 × tier multiplier**, also when Busted (difficulty
scales Cash and Rep, advisor; mechanics' "before ×2" rule confirmed). Star, contract and rank-up Cash give no Rep. Rep
never drops.

### 3.4 Payout handoff from the round

Mechanics calls **once** per round (Getaway, Busted, mini-job end, or the shutdown hook)
`EconomyService:SettleRound(result: RoundResult)`:

```lua
type RoundResult = {
  roundId: string,              -- GUID: idempotency key
  heistId: string,              -- "GoldenWheel" | "PralinePalace" | "TulipAuction" | "MiniJob" (mechanics' text: mapId)
  difficulty: string,           -- "Easy" | "Normal" | "Hard" (mini-job: "Normal")
  modifierId: string?, isHotJob: boolean,
  outcome: "Escaped" | "Busted" | "Aborted" | "Shutdown",
  vanLoot: number,              -- base value in the van at the end
  stars: number,                -- 0–3, mechanics' star rules (1★ needs an escape)
  mainLootBanked: boolean, maxAlarmTier: number, lockdownAtEnd: boolean, durationSeconds: number,
  objectives: { { id: string, bonusPct: number } },   -- optional objectives completed (max 1 per heist)
  banked: { { lootId: string, name: string, class: string, value: number } },
  crew: { { player: Player, inVanAtEnd: boolean, award: string, stats: CrewStats } },
}
-- CrewStats (missing = 0): lootBanked, lootValueBanked, smallBanked, heavyBanked, rescues, bubbledGuards,
-- hidFromChase, boefDistracted, carriedTogether, timesCaught
```

**Formula** (`Logic/Payout.luau`, per crew member, n = `#crew`):
1. `cut = V / n × (1 + 0.15 × (n − 1))`, with `V = vanLoot` (Busted: `V × 0.5`).
2. Escaped but this player is left in the cell → × 0.5 (the lost half goes to nobody, advisor).
3. × tier multiplier (`DifficultyPayout`: 0.8 / 1.0 / 1.4).
4. Not Busted → × (1 + bonuses): Quiet Job +0.20 (`maxAlarmTier ≤ 1`), No One Left Behind +0.10 (n ≥ 2, all in the van;
   proposed: not for solo), **Hot Job +0.25**, **Fresh +0.20** (heist not in *this player's* `recentHeists`; proposed: only once that list holds 2 rounds), and each
   completed objective's `bonusPct` (+0.10).
5. First escaped job today and this player escaped → Cash × 2.
6. **Round half up once per amount** (Cash and Rep separately, never in between; advisor). Four with 3,000 → 1,088.
   Clamp Cash at `MaxPayoutPerRound = 25,000` (log `PayoutClamped`; the realistic max on map 1 is ≈ 20,000).
7. `Aborted` → nothing. `Shutdown` → step 1 only + 100 Rep (proposed: never lose banked loot to our update).

`SettleRound` skips players whose `recentRounds` has the `roundId`, applies everything in **one `Update`** (cash, rep,
stats, stars and star bonuses, unlocks, contracts, Most Wanted, collection, trophies, rank rewards, `recentHeists`),
calls `SaveNowAsync`, logs analytics, and sends each crew member `Payout` (§8.2). Leavers get nothing; their loot stays
for the crew. Awards come in `crew[i].award` (mechanics' `Logic/Awards`) and are passed through.

### 3.5 Daily contracts and reset (UTC)

Kept from the brief. (The advisor's "skip contracts" means PAYDAY-style paid heist contracts; confirm, §open questions.)

- `day = floor(os.time() / 86400)`. When `daily.day ≠ today` (on load, at settlement, every 60 s online): new
  contracts, `firstJobUsed = false`, `rerolls = 0`, `ProfileSync`.
- `Logic/Contracts.generate`, seed `(UserId × 31 + day) mod (2³¹ − 1)` (same in every server): one Easy, one Medium,
  one Hard; max **1** `NeedsCrew` (solo must work); `RequiresHeist` only if the player has it unlocked; no duplicates;
  **1 free reroll per day** (proposed). Progress only from finished rounds; done = paid at once.

| Id | Player text | Tier | Counts | Target | Flag |
|---|---|---|---|---|---|
| `BankItems` | Bank 5 loot items | Easy | `lootBanked` | 5 | |
| `BankValue` | Bank 1,000 Cash of loot | Easy | `lootValueBanked` | 1,000 | |
| `PocketSmall` | Bank 6 small items | Easy | `smallBanked` | 6 | |
| `FinishJobs` | Finish 2 jobs | Easy | rounds finished | 2 | |
| `FreeTeammate` | Free a teammate | Medium | `rescues` | 1 | NeedsCrew |
| `BubbleGuards` | Bubble 3 guards | Medium | `bubbledGuards` | 3 | |
| `BankHeavy` | Bank a heavy item | Medium | `heavyBanked` | 1 | |
| `TwoStars` | Get 2 stars on a job | Medium | rounds with `stars ≥ 2` | 1 | |
| `HideFromGuard` | Lose a chasing guard in a hiding spot | Medium | `hidFromChase` | 1 | |
| `DistractBoef` | Distract Boef | Medium | `boefDistracted` | 1 | RequiresHeist GoldenWheel |
| `HotJob` | Finish the Hot Job | Medium | escaped with `isHotJob` | 1 | |
| `StealGouda` | Escape with the main loot | Hard | `mainLootBanked`, you escaped | 1 | |
| `QuietJob` | Finish a Quiet Job | Hard | escaped, `maxAlarmTier ≤ 1` | 1 | |
| `HardJob` | Escape on Hard | Hard | escaped, `difficulty = "Hard"` | 1 | Needs Hard unlocked |
| `CarryTogether` | Bank a heavy item carried together | Hard | `carriedTogether` | 1 | NeedsCrew |

### 3.6 Weekly "Most Wanted" (proposed: no modifier, since modifiers now come only through the Hot Job)

- `week = floor((os.time() − 345600) / 604800)` (Monday 00:00 UTC).
- Target heist = `Config.MostWanted.Rotation[week % 4 + 1]`: GoldenWheel · PralinePalace · GoldenWheel · TulipAuction
  (map 1 every other week, so newcomers can join in). Locked for you → the board shows its requirement.
- 3★ on it on Normal or Hard, once per player per week → `RewardPool[week % 4 + 1]` (Boef Snout, Night Shift Goggles,
  Karel's Bucket, Siren Hat), or 1,500 Cash if owned.

### 3.7 Glovebox: not in the beta

The beta must show whether the core loop retains **on its own**; contracts, ×2, stars and Most Wanted already give
reasons to return. A free Glovebox adds odds UI and a daily cap; adding it later is a migration with no risk.

### 3.8 Anti-exploit rules

1. Clients never send amounts, prices or results, only ids, tiers and indices.
2. Cash moves only via `EconomyService:Grant` / `:Spend` (inside `Update`, never negative, always an economy event).
3. Round facts come from server state; settlement is idempotent per `roundId`; payouts are clamped.
4. Every meta request is rate-limited per player (`Logic/RateLimit.luau`: burst 5, 2 per second; `Feedback` once per
   round) and type-checked (strings ≤ 40 chars, whole numbers in range, ids in `Config`).
5. Shop, loadout and perk requests are refused while `InRound`; one purchase in flight; price, rank and ownership
   checked on the server; Spend + grant in one `Update`, then `SaveNowAsync`.
6. `DataDevService` only exists when `RunService:IsStudio()`. Dates use server `os.time()` only.

## 4. Progression

### 4.1 Rank curve (capped at 20 in the beta)

Rank *n* → *n+1* costs 1,000 × *n* Rep, so the total for rank *n* = 500 × *n* × (*n* − 1). "≈ rounds" assumes
≈ 1,000 Rep per round on Normal (brief estimate). SP = skill points (one per rank from Rank 2).

| Rank | Total Rep | ≈ rounds | Unlocks | Rank-up Cash | SP |
|---|---|---|---|---|---|
| 1 | 0 | 0 | **The Golden Wheel**; base gadgets + Crowbar; Mask slot; Paper Bag; Getaway White; "Rookie" | — | 0 |
| 2 | 1,000 | 1 | Hat slot + Flat Cap; Periscope | 200 | 1 |
| 3 | 3,000 | 3 | "Pickpocket" | 300 | 2 |
| 4 | 6,000 | 6 | **Praline Palace** (safety net); van colour slot | 400 | 3 |
| 5 | 10,000 | 10 | Lockpick Set; "Cheese Runner" | 500 | 4 |
| 6 | 15,000 | 15 | — | 600 | 5 |
| 7 | 21,000 | 21 | **Tulip Auction** (safety net); gold items (Golden Gouda Mask, Cheese Crown) | 700 | 6 |
| 8 | 28,000 | 28 | Fake Delivery; "Safecracker" | 800 | 7 |
| 9–11 | 36,000 · 45,000 · 55,000 | 36–55 | Rank 10: "Mastermind" | 900–1,100 | 8–10 |
| 12–14 | 66,000 · 78,000 · 91,000 | 66–91 | Rank 12: "Cheese Baron" | 1,200–1,400 | 11–13 |
| 15 | 105,000 | 105 | Free van colour Gouda Gold | 1,500 | 14 |
| 16–19 | 120,000 · 136,000 · 153,000 · 171,000 | 120–171 | Rank 18: "Canal Phantom" | 1,600–1,900 | 15–18 |
| 20 | 190,000 | 190 | "Legend of Polderdam" (max in the beta; Rep keeps counting) | 2,000 | 19 |

Quoted names are titles. Skipping ranks pays every reward in between. Raising the cap later is free (Rep is stored).

### 4.2 Heist unlocking: stars, with a Rank safety net (advisor)

| Heist | Unlocked by |
|---|---|
| The Golden Wheel | Always |
| Praline Palace | **3★ in total** on The Golden Wheel (sum of best stars over the tiers) **or** Rank 4 |
| Tulip Auction | **3★ in total** on Praline Palace **or** Rank 7 |

A heist is open to the whole server when **anyone present** has it. At departure `LobbyService` re-checks the boarders
(*"You need a crew member who unlocked Praline Palace."*). Stars give clear goals; the rank route means solo and weaker
players never get stuck.

### 4.3 Difficulty tiers, stars and records (advisor)

- **Tiers:** Easy / Normal / Hard ("Young / Aged / Extra Aged"); effects in mechanics' table. Easy and Normal come with
  the heist; **Hard after 2★ on Normal on that heist**. A tier is offered when anyone on the board has it. The mini-job
  has no tier. Big Cheese (×2) waits until after the beta.
- **Stars:** `heists[h].stars[tier]` = best stars when escaping (27 in the beta). Each **new** star pays 300 × tier
  multiplier, shown on the payout screen. `clears[tier]` counts escapes; `bestLoot` = top van value.
- **Heist masks:** 3★ on Hard per heist → Gouda Visor / Praline Mask / Bulb Helmet. **Star masks** (proposed): 9★ in
  total → Star Shades; all 27★ → All-Star Mask.

### 4.4 Perk tree (advisor)

Perk ids, effects (each ≤ 15%) and the 3×3 layout are the advisor's; mechanics applies them through `Logic/Perks` /
`LoadoutService:StatsOf`. Meta stores and validates.

| Branch | Row 1 (1 SP) | Row 2 (2 SP) | Row 3 (3 SP) |
|---|---|---|---|
| Sneak | Soft Shoes (crouch 8 → 9) | Barrel Lungs (sneeze at 25 s) | Quiet Crowbar (CRACK 25 → 18) |
| Muscle | Long Arm (throw 10 → 12) | Deep Pockets (4 pocket slots) | Strong Back (heavy alone 7 → 8) |
| Crew | Quick Hands (rescue 2 → 1.5 s) | Escape Artist (self-escape after 12 s) | Spare Batteries (+1 charge on your first gadget) |

- **Points:** `rank − 1` (max 19); spent = sum of unlocked costs (derived, never stored). Everything costs 18 (≈ Rank 19).
- **Unlock** (`UnlockPerk`): a row needs the row above it in the same branch. **Equip** (`EquipPerks`): max 3, from the
  start. `ProgressionService:GetPerks(player)` → `{[perkId]: 1}` for the equipped ones, read at Briefing.
- **Respec** (`RespecPerks`): free and unlimited in the Garage.
- These are small upgrades rather than strict sidegrades (advisor's call); fine because they are earned, never sold.
- Hidden while mechanics' `Config.Features.Perks` is off.

### 4.5 Prestige: after the beta (advisor)

"Legend" at Rank 50 (the rank cap rises then): resets Rank and perk points only; gives a badge, an exclusive mask and
+5% Rep per level (max +25%). Data: a v2 migration adds `legend` and `legendAt`. (Note for the advisor: the Rep bonus
is not purely cosmetic, but Rep only unlocks things and never buys power, so it fits the rules.)

### 4.6 Collection book and trophies

- **Collection:** one entry per loot type per heist (map 1: Cheese Cube, Tip Jar, Cash Drawer, Cheese Wheel, Big
  Wheel, Blue Moon Cheese, Golden Gouda; maps 2–3 from `beta-spec.md`, in `Config.Collection`; keycards excluded).
  Every item in `banked` counts for the whole crew. A full page → reward (Golden Wheel: Cheese Monocle; maps 2–3:
  2,000 Cash, proposed).
- **Trophies:** each escaped round with `mainLootBanked` appends a `Trophy` (30 kept; `stats.mainLoot` = total).

## 5. Garage meta features

The map agent builds and tags the stations; `LobbyService` adds ProximityPrompts (E / ButtonX / tap) that open ux
screens. Meta tags (meta block in `Tags.luau`): `JobBoard`, `GadgetRack`, `Workbench`, `Mirror`, `TrophyWall` (+ 12
children `TrophySlot`), `CollectionBook`, `VanPaint`. Van zone, the 15 s vote/countdown, NEXT JOB and JUMP IN are
mechanics'.

### 5.1 Heist board (advisor)

- **One card per heist** (Registry order). Locked heists are greyed out with their requirement ("3★ on The Golden
  Wheel or Rank 4") or, if a crew member has it, "Unlocked by Sam". Each card has a **tier selector** (Easy ×0.8 ·
  Normal ×1 · Hard ×1.4, Hard only if unlocked), your stars per tier (9 per heist), and chips "FRESH +20%" and
  "MOST WANTED" from your own profile.
- **Hot Job card:** heist + modifier, **+25%**, same on every server, new every 30 min:
  `Logic/HotJob.at(floor(os.time() / 1800), heists, modifiers)`. Pool: 5 modifiers (proposed: no Sleepy Guards, so a
  Hot Job is never easier). Its heist is the first open one in a seeded order (never a locked heist). Shown with a
  "NEW IN 12:00" timer. Proposed: hidden until every player in the server has `stats.rounds ≥ 2` (newcomers learn
  without modifiers).
- **Voting:** `JobVote(cardId, difficulty)` (`cardId` = heistId or `"HotJob"`). At departure
  `LobbyService:GetSelectedJob(boarders)` → `{cardId, heistId, difficulty, modifierId?, isHotJob}`: most votes among
  boarders wins, ties → earliest vote, no votes → The Golden Wheel on Normal (advisor). The crew plays the **lowest
  tier any of that card's voters chose** (proposed: protects the weakest player), re-checked against the boarders'
  unlocks. Solo = your vote.

### 5.2 Gadget rack and Workbench

- **Rack:** the 4 base gadgets plus owned sidegrades (locked ones with rank and price). `SetLoadout({a, b})`: 2
  distinct, owned or free, not the Crowbar (ux's draft calls it `PickGadgets`). At Briefing / JUMP IN mechanics calls
  `ShopService:GetLoadout(player)` → `{"Crowbar", a, b}`. Buying = `BuyItem`.
- **Workbench:** the perk tree (unlock, equip 3, respec), SP counter.

### 5.3 Masks: the key cosmetic (advisor)

Masks are the signature look: 16 of the 28 items, from every source (shop, Most Wanted, collection, heist mastery,
stars). **Auto Mask Up:** you walk in unmasked; mechanics sets character attribute `Masked = true` when you first grab
loot or enter a staff zone; `ShopService` then puts your mask on (ux: "SHING"). Unmasked in the Garage and public zones.
No random safes or rarities, ever.

### 5.4 Mirror catalog (beta, 28 items)

| Id | Name | Slot | Price | Rank | Source |
|---|---|---|---|---|---|
| `PaperBag` | Paper Bag | Mask | free | 1 | Starter |
| `DisguiseGlasses` | Disguise Glasses | Mask | 500 | 1 | Shop |
| `CheeseWedgeMask` | Cheese Wedge Mask | Mask | 750 | 1 | Shop |
| `RubberDuckMask` | Rubber Duck Mask | Mask | 1,000 | 1 | Shop |
| `TulipMask` | Tulip Mask | Mask | 1,500 | 1 | Shop |
| `KlompMask` | Klomp Mask (wooden clog) | Mask | 2,000 | 1 | Shop |
| `KarelMask` | Karel Mask | Mask | 2,500 | 1 | Shop |
| `GoldenGoudaMask` | Golden Gouda Mask | Mask | 3,000 | 7 | Shop |
| `BoefSnout`, `NightShiftGoggles` | Boef Snout, Night Shift Goggles | Mask | — | — | Most Wanted |
| `CheeseMonocle` | Cheese Monocle | Mask | — | — | Collection page (map 1) |
| `GoudaVisor`, `PralineMask`, `BulbHelmet` | Gouda Visor, Praline Mask, Bulb Helmet | Mask | — | — | 3★ on Hard, per heist |
| `StarShades`, `AllStarMask` | Star Shades, All-Star Mask | Mask | — | — | 9★ / 27★ in total |
| `FlatCap` | Flat Cap | Hat | free | 2 | Rank 2 |
| `RedBeanie` | Red Beanie | Hat | 500 | 2 | Shop |
| `ChefToque` | Chef's Toque | Hat | 1,000 | 2 | Shop |
| `CheeseWheelHat` | Cheese Wheel Hat | Hat | 1,500 | 2 | Shop |
| `CheeseCrown` | Cheese Crown | Hat | 3,000 | 7 | Shop |
| `KarelsBucket`, `SirenHat` | Karel's Bucket, Siren Hat | Hat | — | — | Most Wanted |
| `GetawayWhite` | Getaway White | Van | free | 1 | Starter |
| `CheddarOrange`, `CanalBlue`, `TulipRed` | Cheddar Orange, Canal Blue, Tulip Red | Van | 5,000 | 4 | Shop |
| `GoudaGold` | Gouda Gold | Van | — | 15 | Rank 15 |

**Rendering (server-side in `ShopService`, so everyone sees it):**
- Masks and hats are Accessories in `ReplicatedStorage.Cosmetics.<Id>` (replicated so the mirror can preview them in a
  ViewportFrame): masks on `FaceFrontAttachment` (`AccessoryType.Face`, only while `Masked`), hats on `HatAttachment`
  (always), R6 and R15. Equip hides the avatar's own accessories of that type for the session and restores them on
  unequip.
- Missing model → a code-built fallback from `Config.Catalog[id].Fallback = {shape, size, color, offset}` (like
  `Builder.prop`); the game works without assets. Prompts in `tools/cosmetics.json` (meta); the orchestrator or tester
  generates the models in Studio Edit mode, max 2 at a time.
- Van colour: colour + material on every `VanPaint` part; the van shows the colour of the **first boarder** (proposed).

### 5.5 Trophy wall and collection book

The client (ux) draws **your own** trophies from `ProfileSync` on the 12 `TrophySlot` parts plus a counter and your star
total; a server sign beside it lists everyone's main-loot total ("Most Goudas in this Garage"). The book opens at the
`CollectionBook` stand from `collection` + `Config.Collection`.

### 5.6 UI the ux agent builds

Cash/Rank HUD and `SaveStatus` banner; payout extras (contracts, new stars, unlocks, rank-up, new items); heist board
(3 heist cards with lock/requirement, tier selector with multipliers, stars, Fresh and Most Wanted chips, Hot Job card
with timer, votes); gadget rack; Workbench (3×3 tree, SP, 3 slots, respec); mirror (Mask / Hat / Van, preview, buy /
equip; no vests); contracts panel with reset timer and reroll; collection book; trophy wall; feedback tap; Private
Crew invite.

## 6. Analytics plan

All calls go through `AnalyticsTracker` (server only, one `pcall` each, never breaks gameplay). **AnalyticsService only
records in the published game** (dashboards lag about a day); in Studio the tracker prints `[Analytics] …`. Mechanics
reports gameplay moments by **name** (`AnalyticsTracker:OnboardingStep(player, "GoudaLifted")`, `:RoundStep(player,
roundId, "FirstLootBanked")`); the tracker maps names to step numbers, so the order stays meta's. Custom fields stay
low-cardinality (`Enum.AnalyticsCustomFieldKeys.CustomField01–03`).

### 6.1 Onboarding funnel: `LogOnboardingFunnelStepEvent(player, step, name)`

Once per player ever (`onboarding.steps`), skips allowed. The tracker also sends `Onboarding(step)` for ux's hints.
Steps merge the ux and mechanics lists: **1 Spawned · 2 Moved · 3 FirstLootGrabbed · 4 FirstLootBanked ·
5 SneakedPastGuard · 6 GoudaLifted** (mechanics) · **7 MiniJobEscaped** (meta, `SettleRound` of `MiniJob`) ·
**8 GarageReached** (meta, first `Activity = Garage` after the mini-job). Goal: ≥ 70% reach step 7.

### 6.2 Round funnel: `LogFunnelStepEvent(player, "Round", roundId, step, name)`

1 `VanDeparted` (meta, at `GetSelectedJob`; JUMP IN via mechanics) · 2 `FirstLootGrabbed` · 3 `FirstLootBanked` ·
4 `MainLootLifted` (2–4 mechanics) · 5 `Escaped` (meta, settlement) · 6 `NextJob` (meta: departs again within 2 min).

### 6.3 Economy: `LogEconomyEvent(player, flow, "Cash", amount, endingBalance, transactionType, sku)`

| Event | Flow | Type (`Enum.AnalyticsEconomyTransactionType`) | SKU |
|---|---|---|---|
| Round payout | Source | `Gameplay` | heistId |
| Star bonus | Source | `Gameplay` | `StarBonus` |
| Contract reward | Source | `TimedReward` | contract id |
| Most Wanted duplicate | Source | `TimedReward` | `MostWanted` |
| Rank-up Cash, collection page | Source | `Gameplay` | `RankUp` / `Collection` |
| Mini-job welcome | Source | `Onboarding` | `Welcome` |
| Item bought | Sink | `Shop` | item id |

### 6.4 Custom events: `LogCustomEvent(player, name, value, fields)`

| Name | Value | Fields |
|---|---|---|
| `RoundEnded` | duration (s) | heist, outcome, difficulty |
| `JobPicked` | crew size | heist, difficulty, hot job (yes/no) |
| `StarEarned` | stars on that tier | heist, difficulty |
| `HeistUnlocked` | 1 | heist, route (stars/rank) |
| `FirstRealJob` | 1 | heist |
| `RankUp` | new rank | — |
| `PerkUnlocked` / `PerkRespec` | SP spent / respec count | perk id / — |
| `ContractCompleted` | reward | contract id |
| `MostWantedCompleted` | 1 | heist |
| `FeedbackTap` | 1 sad · 2 neutral · 3 happy | tag 1, tag 2, heist |
| `SessionEnded` | session seconds | rounds this session |
| `DataLockStolen`, `DataLoadFailed`, `DataCorruptReset`, `PayoutClamped` | 1 | — |

About 10 events per player per round. Exact quotas: [TO BE CONFIRMED]. Live tuning with Roblox *Configs*: post-beta
[TO BE CONFIRMED]; all values already live in `Config`.

## 7. Monetisation readiness

### 7.1 `ShopReceiptService`

`MarketplaceService.ProcessReceipt` is set **only** here:
1. Player not in this server → `NotProcessedYet` (Roblox retries on a later join).
2. `WaitForData` ≤ 10 s; not loaded → `NotProcessedYet`.
3. `receipts[PurchaseId]` exists → ensure it is saved, return `PurchaseGranted`.
4. Unknown or disabled `ProductId` → log, `NotProcessedYet`.
5. One `Update`: grant (into `robuxOwned`, or a one-off effect) **and** `receipts[PurchaseId] = now`.
6. `SaveNowAsync`: failed → `NotProcessedYet` (the retry lands in step 3); saved → `PurchaseGranted`.

Game passes: `UserOwnsGamePassAsync` on join (cached) + `PromptGamePassPurchaseFinished`; Roblox stores ownership.

### 7.2 Beta settings and placeholders

- `Config.Monetization.Enabled = false`: no buy buttons or prompts; the handler is still installed.
- Test: `DevData fakeReceipt <productKey> <purchaseId>` runs the handler on a fake `receiptInfo`. Optional: Maurits
  creates one hidden dev product "Beta Test Token" for a real (free) Studio test purchase.
- Placeholders (`Id = 0`; the advisor decides at launch): products `CrewFireworks` (25 R$), single cosmetics
  (49–199 R$); passes `CrewWardrobe` (199), `PaintShop` (249), `LoadoutPresets` (99), `SupporterPack` (299).
- Private servers: free (Maurits sets this in Creator Hub).

### 7.3 Rules

Robux buys looks and convenience only, never Cash, boosters, gadgets, perks, skill points, tiers, heists or "get out of
jail". **No paid random items** (banned in Belgium, blocked in the Netherlands), so no `PolicyService` random-item
checks are needed. Robux items are never lost; prices are always visible; no countdown pressure; no rewarded ads.
Experience notifications need an Open Cloud call with API keys, so they are not in the beta.

## 8. Architecture and contracts

### 8.1 Modules (owner: meta)

| File | Role |
|---|---|
| `Services/DataService.luau` | Sessions, backends, autosave, shutdown, `ProfileSync`, attributes |
| `Services/DataDevService.luau` | Studio only: `DevData` (give Cash/Rep/stars, set rank, reset me, time offset, fake round, foreign lock, steal my lock, load fixture, fake receipt, fail rate) |
| `Services/EconomyService.luau` | `SettleRound`, `Grant`/`Spend`, daily/weekly, contracts, collection, trophies, `Payout` |
| `Services/ProgressionService.luau` | Rank, stars, heist and tier unlocks, perks; `GetPerks`, `CrewHeists(players)`, `CrewTiers(players, heistId)`, `IsTutorialDone`, `RoundsCompleted` |
| `Services/LobbyService.luau` | Heist board, Hot Job, votes, `GetSelectedJob`, station prompts, trophy sign, Private Crew |
| `Services/ShopService.luau` | `BuyItem`, `EquipItem`, `SetLoadout`, `GetLoadout`, cosmetics and Mask Up rendering, van paint |
| `Services/ShopReceiptService.luau` | ProcessReceipt, game passes |
| `Services/AnalyticsTracker.luau` | Analytics wrapper (not called `AnalyticsService`, so it can't be mixed up with Roblox's) |

`ProgressionService` is outside the README's `{Data,Economy,Lobby,Shop,Analytics}*` list; mechanics already expects it
(orchestrator: add it to the ownership table).

**Pure logic** (`src/shared/Logic/`, no Roblox APIs, no requires; config and rng come in as arguments; one
`tests/logic/<Name>.spec.luau` each): `DataSchema`, `SessionLock`, `Backoff`, `Calendar` (day, week, 30-min slot),
`Progression` (rank ↔ Rep, cap, unlocks, titles, SP), `HeistRecords` (stars, star bonuses, heist and tier unlocks,
mastery masks), `PerkTree` (unlock, equip, respec rules), `Payout`, `Contracts`, `JobBoard` (cards, tally, lowest
tier), `HotJob`, `Shop`, `Collection`, `RateLimit`.

**Needs from mechanics:** `Activity` / `InRound` and `Masked` attributes; `RoundResult` (§3.4) with `difficulty`,
`isHotJob`, `objectives`, `award` and `CrewStats`; a call to `GetSelectedJob(boarders)` at departure; `GetLoadout`
and `GetPerks` at Briefing; tier effects and perk numbers (`Logic/Difficulty`, `Logic/Perks`); named funnel steps; the
shutdown hook.

### 8.2 Net messages

**Client → server** (`Net.request`, all rate-limited; mechanics owns `NextJob`, `ReturnToGarage`, `JumpIn`):

| Name | Payload | Server checks |
|---|---|---|
| `ProfileRequest` | — | Loaded; max 1 per 2 s → `ProfileSync` |
| `JobVote` | `cardId: string, difficulty: string` | Garage or NextJob phase; card on the board and open; tier offered for that heist |
| `SetLoadout` | `{string, string}` | 2 distinct, owned or free gadgets, in `Config.Gadgets`, not Crowbar, not `InRound` |
| `BuyItem` | `itemId` | In catalog, has a price, not owned, rank ≥ `MinRank`, cash ≥ price, not `InRound` |
| `EquipItem` | `itemId` | Owned or free, slot open; equipping the worn hat removes it (masks and vans swap only) |
| `UnlockPerk` | `perkId` | Free SP ≥ cost, row above unlocked, not `InRound` |
| `EquipPerks` | `{perkId}` (≤ 3) | All unlocked, not `InRound` |
| `RespecPerks` | — | Not `InRound` |
| `RerollContract` | `index: 1–3` | Reroll left, not done |
| `SaveSettings` | `{[string]: boolean \| number}` | Keys in allowlist, numbers clamped; debounced 2 s |
| `TipSeen` | `tipId` | Known tip id |
| `Feedback` | `mood: 1–3, tags: {string}` (≤ 2), `roundId` | Tags from `Config.Analytics.FeedbackTags`; once per round |
| `PrivateCrewStart` / `PrivateCrewAnswer` | — / `yes: boolean` | Garage, published game, 60 s cooldown / open invite |
| `DevData` | `cmd, ...` | Studio only |

**Server → client:**

| Name | Payload |
|---|---|
| `ProfileSync` | §2.6 |
| `Payout` (each crew member) | `{roundId, heistId, difficulty, outcome, stars, items: {{name, class, value}}, vanTotal, crewSize, cut, tierMultiplier, bonuses: {{label, pct}}, busted, caughtHalf, firstJobToday, cash, rep, balance, awards: {{userId, awardId}}, rankBefore, rankAfter, unlocks, newStars: {count, cash}, contracts, contractCash, mostWanted: {done, item?, cash?}, newCollection, trophy}` |
| `RankUp` | `newRank, title, unlocks, skillPoints` |
| `JobBoard` (broadcast) | `{version, heists: {{heistId, name, open, requirement?, unlockedBy?, tiers: {{id, mult}}}}, hotJob: {heistId, modifier, bonusPct, endsAt, open}?, votes: {[userId]: {cardId, difficulty}}, selected?}` |
| `Onboarding` | `step` |
| `MetaResult` | `action ("Buy"/"Equip"/"Loadout"/"Perk"/"Respec"), ok, id, reason ("NotEnoughCash"/"Locked"/"Owned"/"NotOwned"/"NoPoints"/"TooMany"/"Busy"/"InRound")` |
| `SaveStatus` | `"Ok" \| "Trouble" \| "Memory"` |
| `PrivateCrewInvite` | `fromName, seconds` |
| `Toast` (exists) | short refusals, welcome bonus |

### 8.3 Config keys (meta block, defaults)

```lua
Config.Data = { StoreName = "PlayerData", StudioSuffix = "_Studio", KeyPrefix = "u_", AutosaveSeconds = 120,
  MinSecondsBetweenWrites = 7, LoadAttempts = 6, LoadRetrySeconds = 4, StealAfterAttempts = 5,
  StaleLockSeconds = 600, RetryAttempts = 5, RetryMaxSeconds = 16, ShutdownTimeoutSeconds = 25,
  ShutdownHookSeconds = 5, ReceiptHistory = 100, RecentRounds = 10, TrophyLog = 30, UseMemoryInStudio = "auto",
  Mock = { FailRate = 0, LatencySeconds = 0 }, SyncPerSecond = 4, SettingsKeys = { --[[ux]] } }
Config.Economy = { CrewBonusPerExtra = 0.15, BustedFactor = 0.5, CaughtAtEndFactor = 0.5, QuietJobBonus = 0.20,
  QuietJobMaxTier = 1, NoOneLeftBehindBonus = 0.10, HotJobBonus = 0.25, FreshBonus = 0.20, FreshWindow = 2,
  FirstJobMultiplier = 2, RepPerRound = 100, WelcomeBonus = 500, RankUpCashPerRank = 100, StarBonus = 300,
  MaxPayoutPerRound = 25000, MostWantedDuplicateCash = 1500, CollectionPageCash = 2000,
  DifficultyPayout = { Easy = 0.8, Normal = 1.0, Hard = 1.4 } }
Config.Progression = { RepPerRankStep = 1000, MaxRank = 20, SlotRank = { Mask = 1, Hat = 2, Van = 4 },
  HeistUnlock = { GoldenWheel = {}, PralinePalace = { StarsOn = "GoldenWheel", Stars = 3, Rank = 4 },
    TulipAuction = { StarsOn = "PralinePalace", Stars = 3, Rank = 7 } },
  TierOrder = { "Easy", "Normal", "Hard" }, HardNeedsNormalStars = 2,
  MasteryMask = { GoldenWheel = "GoudaVisor", PralinePalace = "PralineMask", TulipAuction = "BulbHelmet" },
  StarMasks = { [9] = "StarShades", [27] = "AllStarMask" },
  Titles = { [1] = "Rookie", --[[ §4.1 ]] }, RankRewards = { [2] = "FlatCap", [15] = "GoudaGold" } }
Config.PerkTree = { Branches = { Sneak = { "SoftShoes", "BarrelLungs", "QuietCrowbar" },
  Muscle = { "LongArm", "DeepPockets", "StrongBack" }, Crew = { "QuickHands", "EscapeArtist", "SpareBatteries" } },
  RowCost = { 1, 2, 3 }, MaxEquipped = 3, FreeRespec = true }   -- perk effects: mechanics' Config.Perks
Config.HotJob = { SlotSeconds = 1800, Modifiers = { "PowerCut", "HealthInspector", "WetFloor", "RushJob", "DoubleShift" },
  ModifiersFromRounds = 2 }
Config.Contracts = { Rewards = { Easy = 250, Medium = 350, Hard = 500 }, MaxNeedsCrew = 1, FreeRerollsPerDay = 1,
  Templates = { --[[ §3.5 ]] } }
Config.MostWanted = { StarsNeeded = 3, Tiers = { "Normal", "Hard" },
  Rotation = { "GoldenWheel", "PralinePalace", "GoldenWheel", "TulipAuction" },
  RewardPool = { "BoefSnout", "NightShiftGoggles", "KarelsBucket", "SirenHat" } }
Config.Lobby = { PrivateCrewInviteSeconds = 10, NextJobWindowSeconds = 120 }
Config.Catalog = { --[[ id = { Kind, Name, Price?, MinRank, Source, Color?, Material?, Fallback? } — §3.1, §5.4 ]] }
Config.Collection = { GoldenWheel = { "CheeseCube", "TipJar", --[[ … ]] }, PageReward = { GoldenWheel = "CheeseMonocle" } }
Config.Monetization = { Enabled = false, Products = { CrewFireworks = { Id = 0 } }, Passes = { CrewWardrobe = { Id = 0 } } }
Config.Analytics = { StudioPrint = true, FeedbackTags = { "Fun", "TooHard", "TooEasy", "Confusing", "Bug", "Laggy" } }
Config.MetaRateLimit = { Burst = 5, PerSecond = 2 }
```

Meta reads mechanics' `Config.Features.Difficulty` / `.Perks`: when off, the board shows Normal only and the Workbench
hides the tree. `Config.Economy.ModifierBonus` from the first draft is dropped: modifiers pay through the Hot Job only.

### 8.4 Private Crew (built last)

`PrivateCrewStart` → the other players get `PrivateCrewInvite` (10 s) → `ReleaseAsync` for each, then
`TeleportAsync(placeId, {starter + yes-players}, TeleportOptions{ShouldReserveServer = true})`. Hidden in a reserved
server (`PrivateServerId ~= ""` and `PrivateServerOwnerId == 0`). In Studio: Toast *"Private Crew works in the live
game."*

## 9. Test plan and build order

### 9.1 Lune unit tests (`sh tools/check.sh`)

- `DataSchema`: defaults complete; reconcile keeps unknown keys; v0 fixture migrates; newer version reported.
- `SessionLock`: two fake servers on one fake store: create; foreign fresh lock → wait; stale → take; attempt 5 →
  steal; a robbed session's save cancels; release clears only its own lock.
- `Payout`: brief examples (solo 1,000 → 1,000; four with 3,000 → 1,088), Busted, left in cell, tiers, Hot Job,
  Fresh, objective, ×2 only on escape, Rep before ×2 and × tier, one rounding, clamp.
- `Progression`: §4.1 exactly; `rankForRep(999) = 1`, `(1000) = 2`; cap 20; SP.
- `HeistRecords`: stars only rise; bonus per new star × tier; Hard at 2★ Normal; Praline at 3★ total or Rank 4;
  mastery and star masks granted once.
- `PerkTree`: row order, costs, max 3, respec refund. `JobBoard`: locked cards, lowest-tier rule, ties, no-vote
  default. `HotJob`: same slot → same job; never a locked heist; never Sleepy Guards.
- `Contracts`, `Calendar`, `Shop`, `Collection`, `RateLimit`, `Backoff`: every rule. `Config`: ids unique, prices in
  the brief's ranges, every reward and perk id exists.

### 9.2 Studio scenarios (tester, `tools/studio_tests/scenarios/1xx_meta_*.luau`)

| # | Scenario | Pass |
|---|---|---|
| 100 | Join without API access | Memory warning once; `DataLoaded`; defaults in `ProfileSync`; no errors |
| 101 | `DevData fakeRound` (solo, Golden Wheel, Normal, 1,000 loot, escaped, tier 2, first round) | Cash 2,000 (×2) + 200 rank-up + 300 (1 new star), plus any finished contract; Rep 1,100; Rank 2, 1 SP, Flat Cap |
| 102 | Same `roundId` twice | Paid once |
| 103 | `fakeRound` Normal, Gouda + 2,600 (3★) | +600 for 2 new stars; Hard offered on that heist; Praline Palace card opens |
| 104 | Buy + equip a mask; set `Masked` true/false; buy without Cash | Mask shows only while masked; `NotEnoughCash` |
| 105 | `UnlockPerk` row 2 before row 1; equip 4; respec | Refused; refused; all SP back |
| 106 | `DevData timeOffset 1` (day) / `+30 min` | New contracts and ×2 again / new Hot Job |
| 107 | `Mock.FailRate = 0.5` / `1` | Retries then saves / kick message on join |
| 108 | Fresh foreign lock, then join; `stealMyLock` then autosave | Waits ≈ 16–20 s and steals; save cancels, kicked, nothing overwritten |
| 109 | Fixture v0 / v99 | Migrated / update kick |
| 110 | `fakeReceipt` twice, same id | Granted once; both `PurchaseGranted` |
| 111 | Stop playtest mid-round | Shutdown settles; "[Data] released n/n" |
| 112 | Server & Clients, 2 players (Rank 1 + Rank 4) | Praline open for both; lowest-tier rule; cosmetics visible to both |

### 9.3 Private published test

Saves survive rejoin; leave and join another server at once (no loss, ≤ 20 s wait); "Shut down all servers" mid-round
(shutdown payout arrives); Private Crew; after 1–2 days funnels and economy events show in Creator Hub.

### 9.4 Build order

| WP | Work | Depends on |
|---|---|---|
| M0 | API stubs with in-memory defaults (`SettleRound`, `GetSelectedJob`, `GetLoadout`, `GetPerks`, `CrewHeists`, `WaitForData`, tracker) so mechanics can call them on day one | — |
| M1 | Pure logic + Lune tests + Config meta block | — |
| M2 | `DataService` + `DataDevService` | M1 |
| M3 | `AnalyticsTracker` | — (parallel) |
| M4 | `EconomyService` + `ProgressionService` (ranks, stars, unlocks) | M1–M3; testable with `fakeRound` before `RoundResult` lands |
| M5 | `ShopService` (cosmetics with fallbacks, Mask Up, loadout, van paint) | M2; map tags; mechanics' `Masked` and `GetLoadout` |
| M6 | `LobbyService` (heist board, Hot Job, votes, `GetSelectedJob`, stations, funnel 7–8) | M4; map's Garage; mechanics' van countdown |
| M7 | `ShopReceiptService` | M2 |
| M8 | Perk tree (Workbench, behind `Features.Perks`) | M4; mechanics `Logic/Perks` |
| M9 | `tools/cosmetics.json`; orchestrator generates models | M5 |
| M10 | Private Crew | M2, M6; published test only |

**Freeze early:** the Net contract (§8.2) and `RoundResult` (§3.4) are frozen once the orchestrator merges the specs, so
ux and mechanics can build in parallel; changes go through the orchestrator.
