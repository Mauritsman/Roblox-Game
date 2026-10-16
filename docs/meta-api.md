# Meta API (for mechanics, ux and the tester)

*Meta agent, 16/10/2026. What the meta systems (saving, money, progression, job board, shop, analytics) offer and
expect. Design and numbers: `docs/beta-spec-meta.md` (+ advisor decisions in `docs/research/`). Config lives in
`src/shared/MetaConfig.luau` (economy, progression, prices, contracts, jobs), cosmetics and gadgets in
`src/shared/Catalog.luau`, tag and attribute names in `src/shared/MetaTags.luau`. All three are plain data and can
be required on the client.*

## 1. Files

| File | Role |
|---|---|
| `src/server/Services/DataService.luau` | Profiles: session-locked DataStore records, autosave, shutdown, ProfileSync, attributes |
| `src/server/Services/EconomyService.luau` | `SettleRound`, `Grant` / `Spend`, daily contracts, daily ×2, Most Wanted, `Payout` |
| `src/server/Services/ProgressionService.luau` | Rank, perks (unlock / equip / respec), crew unlocks, `GetPerks` |
| `src/server/Services/LobbyService.luau` | Job board, Hot Job, votes, `GetSelectedJob`, Garage station prompts, Private Crew |
| `src/server/Services/ShopService.luau` | Buy / equip cosmetics, gadget loadout, `GetLoadout`, Mask Up rendering, van paint |
| `src/server/Services/ShopReceiptService.luau` | `ProcessReceipt` (idempotent, off via config), game pass cache |
| `src/server/Services/AnalyticsTracker.luau` | Guarded AnalyticsService calls; funnel steps by name |
| `src/server/Services/MetaDevService.luau` | Studio-only dev remotes (§6) |
| `src/server/Meta/*` | Server helpers: `Clock`, `RequestGuard` (rate limits, type checks), `Access`, `ProfileView`, `Features` |
| `src/shared/Logic/*` | Pure logic + Lune tests: `DataSchema`, `SessionLock`, `Backoff`, `RateLimit`, `Calendar`, `Progression`, `HeistRecords`, `PerkTree`, `Payout`, `Settlement`, `Contracts`, `JobBoard`, `HotJob`, `Shop`, `Collection`, `Ledger` |

## 2. For mechanics (server calls)

```lua
local DataService = require(script.Parent.DataService)        -- from another service
DataService:WaitForData(player, timeout?) -> PlayerData?       -- yields; nil if failed / left
DataService:Get(player) -> PlayerData?                         -- read only
DataService:Update(player, reason, fn(data)) -> boolean        -- the only way to change data; fn must not yield
DataService:SaveNowAsync(player, reason) -> boolean
DataService:OnBeforeShutdown(fn)                               -- settle the running round here (outcome "Shutdown")
DataService.Loaded / .Changed                                  -- Signals (player, data) / (player, reason)

LobbyService:GetSelectedJob(boarders: {Player}, roundId: string?)
  -> { cardId, heistId, difficulty, modifierId?, isHotJob, mostWanted }
ShopService:GetLoadout(player) -> { "Crowbar", a, b }          -- at Briefing and JUMP IN
ProgressionService:GetPerks(player) -> { [perkId] = 1 }        -- empty while Config.Features.Perks is off
ProgressionService:CrewHeists(players) / :CrewTiers(players, heistId) / :IsTutorialDone(player)
ProgressionService:RoundsCompleted(player) / :GetRank(player)
EconomyService:SettleRound(result: RoundResult) -> { [userId] = { cash, rep } }   -- once per round, idempotent
AnalyticsTracker:OnboardingStep(player, name)                  -- names below; once per player ever
AnalyticsTracker:RoundStep(player, roundId, name)              -- once per player and round
```

**RoundResult** (types in `EconomyService.luau`): `roundId` (GUID, the idempotency key), `heistId`
("GoldenWheel" … or "MiniJob"), `difficulty` ("Easy"/"Normal"/"Hard"), `modifierId?`, `isHotJob`, `outcome`
("Escaped"/"Busted"/"Aborted"/"Shutdown"), `vanLoot` (base value), `stars` (0–3), `mainLootBanked`, `maxAlarmTier`,
`lockdownAtEnd`, `durationSeconds`, `objectives = {{id, bonusPct}}`, `banked = {{lootId, name, class, value}}`
(`lootId` = loot type, e.g. "CheeseWheel"), `crew = {{player, inVanAtEnd, award, stats}}`. CrewStats (missing = 0):
`lootBanked, lootValueBanked, smallBanked, heavyBanked, rescues, bubbledGuards, hidFromChase, boefDistracted,
carriedTogether, timesCaught`. Crew members who already left are ignored (their loot stays for the crew).

**Rules applied by meta:** Busted = half the van, no bonuses; not in the van at the end = half share; difficulty
×0.8/1.0/1.4; Quiet Job +20%, No One Left Behind +10% (crews of 2+), Hot Job +25%, Fresh +20% (after 2 rounds of
history), objectives' `bonusPct`; first escaped job of the UTC day ×2 (Busted doesn't use it); round half up once;
Rep = Cash before ×2 + 100 × tier; Shutdown = step-1 share + 100 Rep, nothing else; MiniJob = 500 welcome bonus +
100 Rep once, and `onboarding.done = true`.

**Funnel step names.** Onboarding: `Spawned`, `Moved`, `FirstLootGrabbed`, `FirstLootBanked`, `SneakedPastGuard`,
`GoudaLifted` (mechanics); `MiniJobEscaped`, `GarageReached` (meta). Aliases accepted: `GrabbedLoot`, `BankedLoot`,
`LiftedGouda`, `Escaped`, `ReachedGarage`. Round: `VanDeparted` (meta, at `GetSelectedJob`; call it yourself for
JUMP IN), `FirstLootGrabbed`, `FirstLootBanked`, `MainLootLifted` (mechanics), `Escaped`, `NextJob` (meta).

**Meta reads from mechanics:** player attributes `Activity` ("Garage"/"Crew"/"Tutorial") and/or `InRound` (shop,
loadout, perk and vote requests are refused in a round); character attribute `Masked` (mask goes on);
`ReplicatedStorage.RoundPhase` (votes allowed in Garage/Payout/NextJob); `Config.Features.Difficulty` and
`.Perks` (missing = off: board offers Normal only, perks hidden); `Config.Gadgets[id]` (a catalog gadget only
exists once defined there). Heist cards are playable only when `Map/Registry.get(heistId)` exists.

## 3. For ux: server → client (`Net.on`)

Call `Net.request("ProfileRequest")` once your handler is connected (messages sent before that are lost).

| Message | Payload |
|---|---|
| `ProfileSync` | Full profile view (below), on load and after every change (max 4/s) |
| `Payout` | `{roundId, heistId, heistName, difficulty, modifierId, isHotJob, outcome, stars, items={{name,class,value}}, vanTotal, crewSize, cut, crewBonusPct, tierMultiplier, bonuses={{id,label,pct}}, busted, caughtHalf, firstJobToday, welcome, cash, rep, totalCash, balance, awards={{userId,awardId}}, rankBefore, rankAfter, rankCash, unlocks={{kind,id,name}}, newItems, newStars={count,cash}, contracts={{id,text,reward}}, contractCash, mostWanted={done,item?,cash?}, newCollection, collectionCash, trophy}` |
| `RankUp` | `newRank, title, unlocks ({{kind,id,name}}: Slot/Item/ShopItem/Heist/Title), skillPoints` |
| `JobBoard` | `{version, heists={{cardId, heistId, name, available, open, requirement?, unlockedBy?, mostWanted, tiers={{id,label,mult,open}}}}, hotJob={cardId="HotJob", heistId, name, modifierId, modifierName, bonusPct, endsAt, open, minRounds, tiers}?, mostWanted={heistId,endsAt}, votes={[userIdString]={cardId,difficulty}}, selected={cardId,difficulty,votes}?, difficultyEnabled, serverNow}` (broadcast on every change and each Hot Job slot). `available=false` = "Coming soon" (map not built). Times are `os.time()` seconds; compare with `serverNow` |
| `MetaResult` | `action, ok, id, reason` — actions `Buy`, `Equip`, `Loadout`, `Perk`, `Respec`, `Vote`, `Reroll`; reasons `NotEnoughCash`, `Locked`, `Owned`, `NotOwned`, `NotForSale`, `Unknown`, `Duplicate`, `Invalid`, `TooMany`, `NoPoints`, `Busy`, `InRound`, `NeedRounds` (Hot Job: play 2 rounds first), `NoRerolls`, `Done`, `NoOptions` |
| `Onboarding` | `step, name` (1–8, see §2) — show the next hint |
| `OpenScreen` | `screen` — a Garage station prompt was used: `JobBoard`, `Gadgets`, `Perks`, `Mirror`, `Collection`, `Trophies` |
| `SaveStatus` | `"Ok"` / `"Trouble"` (show "Saving is slow — your progress is safe and we keep trying.") / `"Memory"` (Studio) |
| `PrivateCrewInvite` | `fromName, seconds` |
| `Toast` (exists) | Refusals, welcome bonus, dev feedback |

**ProfileSync view** = PlayerData minus `receipts`/`recentRounds`: `cash, rep, owned, robuxOwned, equipped={Mask,Hat?,Van},
loadout, perks={unlocked,equipped,respecs}, heists={[heistId]={stars={[tier]=n},clears,bestLoot}}, recentHeists,
lastDifficulty, onboarding={done,steps}, daily={day,contracts={{id,tier,target,progress,reward,done}},firstJobUsed,rerolls},
weekly, collection, collectionRewards, trophies={{loot,heist,tier,crew,at}}, stats, settings, seenTips, purchases`,
plus derived `rank, repIntoRank, repForNext, title, skillPoints, skillPointsFree, heistsUnlocked, tiersUnlocked,
freshHeists, totalStars, canVoteHotJob, mostWanted={heistId,item,owned,done}, firstJobBonusAvailable, rerollsLeft,
dayResetsAt, weekResetsAt, serverNow, features={Difficulty,Perks}, saveStatus`. Contract texts:
`MetaConfig.Contracts.Templates[*].Text` by id. Item names, prices, ranks: `Catalog.ById[id]`.

## 4. For ux: client → server (`Net.request`, all rate-limited)

| Request | Args | Notes |
|---|---|---|
| `ProfileRequest` | — | max 1 per 2 s |
| `JobVote` | `cardId` (heistId or `"HotJob"`), `difficulty` | → `MetaResult("Vote")` + `JobBoard` |
| `SetLoadout` | `{a, b}` | 2 distinct owned gadgets, never "Crowbar" (ux's `PickGadgets`) |
| `BuyItem` / `EquipItem` | `itemId` | Equipping the worn hat takes it off |
| `UnlockPerk` / `EquipPerks` / `RespecPerks` | `perkId` / `{perkId…}` (≤ 3) / — | Only while `features.Perks` |
| `RerollContract` | `index` 1–3 | 1 free reroll per day |
| `SaveSettings` | `{Music, Sfx, CameraSensitivity, ReduceMotion, Hints}` | Clamped (`MetaConfig.Data.SettingsKeys`) |
| `TipSeen` | `tipId` | Ids in `MetaConfig.Data.TipIds` |
| `Feedback` | `mood` 1–3, `tags` (≤ 2 of `MetaConfig.Analytics.FeedbackTags`), `roundId` | Once per round |
| `PrivateCrewStart` / `PrivateCrewAnswer` | — / `yes` | Live game only (Studio: toast) |

## 5. Attributes

- **Player (meta):** `DataLoaded`, `Cash`, `Rep`, `Rank`, `Title`, `SkillPoints`, `RepIntoRank`, `RepForNext`,
  `IsNewPlayer`, `RoundsPlayed`, `HeistsUnlocked`, `Loadout`, `Perks` (comma lists), `MaskId`, `HatId` ("" = none),
  `VanId`, `SaveStatus`, `Teleporting`; `leaderstats.Rank`. Game passes later: `Pass_<Key>`.
- **ReplicatedStorage (meta):** `HotJobHeist`, `HotJobModifier`, `HotJobEndsAt`, `MostWantedHeist`, `TrophyLeaders`
  ("Sam 4 · Alex 2").
- **Garage tags (map places them; meta adds prompts):** `JobBoard`, `GadgetRack`, `Workbench`, `Mirror`, `TrophyWall`
  (+ `TrophySlot` children for ux), `CollectionBook`, `VanPaint`. Prompts are `Style = Custom`, E / ButtonX,
  attribute `ContextIcon` = the tag.
- **Cosmetics:** Accessories in `ReplicatedStorage.Cosmetics.<Id>` if present, else a code-built fallback from
  `Catalog` (`Fallback`). Masks only while `Masked`; the avatar's own hats/face accessories are hidden meanwhile.

## 6. Studio dev remotes (tester; `MetaDevService`, Studio only)

From the Client datamodel: `game.ReplicatedStorage.Remotes.ToServer:FireServer("<Name>", ...)`.

| Name | Args | Effect |
|---|---|---|
| `DevGiveCash` / `DevGiveRep` | amount | Cash (negative = take) / Rep (+ rank rewards) |
| `DevSetRank` | rank | Sets Rep to that rank's total (pays rank rewards when going up) |
| `DevResetData` | — | Fresh profile |
| `DevSetStars` | heistId, tier, stars | Best stars on a tier |
| `DevFakeRound` | `{heistId?, difficulty?, outcome?, vanLoot?, stars?, mainLoot?, maxAlarmTier?, inVan?, isHotJob?, roundId?, stats?, objectives?}` | Solo `SettleRound` (scenario 101: `{vanLoot=1000}` → +2,500 Cash, 1,100 Rep, Rank 2) |
| `DevFakeReceipt` | productKey?, purchaseId? | Runs `ProcessReceipt` (same id twice → granted once) |
| `DevTimeOffset` | seconds | Game clock offset (86400 = tomorrow: new contracts and ×2; 1800 = next Hot Job) |
| `DevDataMock` | failRate, latency | DataStore fault injection |
| `DevForeignLock` | — | Foreign lock on my record + reload: waits ≈ 16–20 s, then steals |
| `DevStealMyLock` | — | Another "server" takes my lock: my next save is refused and I'm kicked |
| `DevLoadFixture` | `"v0"` / `"v99"` / `"corrupt"` | Migrates / update kick / backup + fresh profile |
| `DevCompleteOnboarding`, `DevPrintData` | — | Skip the mini-job flag / print my profile JSON |

Without API access (or an unpublished place) Studio uses memory only and prints
*"[Data] Studio without API access: memory only, nothing is saved."* once.
