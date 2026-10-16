# Advisor: what Crowbar Crew borrows from Notoriety (beta)

*Advisor, 16/10/2026. Owner input: "Make a whole game, where you unlock maps and such, maybe kinda like Notoriety
inspiration." Facts come from the Notoriety wiki (read via its API on 16/10/2026, links at the bottom). This note
overrides `advisor-brief.md` and settles `beta-spec.md` §7 and §12.*

## Notoriety in numbers

Notoriety, the official PAYDAY experience on Roblox, has **22 heists**, picked in a lobby (2 are locked behind a
499-Robux pass or Premium).
- **Difficulty:** Normal / Hard / Extreme / Nightmare pays ×1 / ×1.4 / ×2.6 / ×3 Cash and ×1 / ×3 / ×9 / ×11 XP, and
  widens the guards' view from 75° to 195°.
- **Stealth:** "Plan A", with loud as the fallback.
- **Pagers:** must be answered (8 s hold); max. **4 per heist for the whole team**.
- **Drills:** run 3–5 min and break at random until someone fixes them.
- **Other systems:** pickpocketable keycards, a repeat bonus of up to +100% for heists you haven't played lately,
  levels 1–100 (130 skill points over 4 trees), Infamy prestige at level 100 + $20M (resets everything for up to +80%
  Cash/XP), masks from random "safes", daily and weekly challenges, and "mutators".

## Decisions

| # | Topic | Decision for the beta |
|---|---|---|
| 1 | **Heist board** | A Job Board in the Garage shows a card for **every heist** (locked ones greyed out, with their requirement). The crew picks heist + difficulty. One rotating **Hot Job** (heist + modifier, +25%, changes every 30 min). **Fresh bonus +20%** for a heist not in your last 2 rounds. Modifiers come only through the Hot Job in the beta. Skip: contracts, hosting fees, host level limits. |
| 2 | **Difficulty** | **3 tiers in the beta:** Easy / Normal / Hard (subtitles "Young / Aged / Extra Aged"), paying ×0.8 / ×1.0 / ×1.4 Cash and Rep. The brief's numbers = Normal. The silly 4th tier **Big Cheese** (×2.0) comes after the beta. |
| 3 | **Stealth vs loud** | Every heist starts stealthy. Loud = LOCKDOWN: guards hunt, and the **Panic Pack** gives +1 charge of each gadget you picked. No loud-only heists. "Quiet Job" +20% stays. A `LoudOnly` shortcut (1 per heist) is allowed but low priority. |
| 4 | **Objectives** | **Keycard** (required for its door), one optional **Safe + Cheese Grater 3000** (+10%), **radio check**. The van stays parked; on maps 2–3 a fixed lockdown exit replaces the front van during LOCKDOWN (`advisor-maps.md`). |
| 5 | **Loadout + perks** | Crowbar + 2 gadgets + **3 perk slots** + mask. A **3×3 perk tree** (below), 1 point per Rank from Rank 2, free respec. |
| 6 | **Masks** | Pure cosmetics with fixed prices or earned rewards; no safes or rarity rolls. **Auto "Mask Up":** you walk in unmasked; guards ignore you in public zones; the mask snaps on ("SHING") when you first grab loot or enter a staff zone. |
| 7 | **Levels, prestige** | Crew Rank 1–**20** (cost per brief: 1,000 × n Rep). **No prestige in the beta.** Later, "Legend" prestige at Rank 50 (details below). |
| 8 | **Stars** | **3 stars per heist per difficulty** (27 in the beta), a first-time star bonus, and a unique mask per heist for 3★ on Hard. |
| 9 | **Unlocking** | **Unlocked by stars, with a Rank safety net** (below). If one crew member has a heist unlocked, the whole crew can play it. |
| 10 | **Heist count** | Beta **3** + the mini-job. Launch 5 (1 new heist + 1 variant). Then 1 heist every 6–8 weeks. Never sell heists. |

**Difficulty tiers** (these replace the old global `Config.Difficulty` Rookie/Normal/Pro; the mini-job has no tier)

| | Easy | Normal | Hard |
|---|---|---|---|
| Payout and Rep | ×0.8 | ×1.0 | ×1.4 |
| Guard meter fill rate | ×0.8 | ×1.0 | ×1.2 |
| Extra guards (within the cap) | 0 | 0 | +1 |
| Camera meter | 3 s | 2 s | 1.6 s |
| Alarm points | ×0.75 | ×1 | ×1.25 |
| LOCKDOWN timer | 75 s | 60 s | 50 s |
| Self-escapes from the cell | 2 | 1 | 1 |
| Radio checks | no | yes | yes |
| Unlocked (per heist, crew union) | with the map | with the map | **2★ on Normal** on that heist |

**Objectives** (map contract as in `beta-spec.md` §7.3)
- **Keycard:** one per heist, on 1 of N anchors (on 50% of rounds it hangs on a guard: pickpocket it by holding USE
  behind him for 1.5 s, unseen). It opens its `KeycardDoor` (1 s hold); on map 1 that is the office where one of the
  Gouda spots is. It takes a pocket slot and drops if you are caught.
- **Safe + Cheese Grater 3000** (optional, maps 1–2): place it (2 s hold), then it runs **45 s** (Easy 35, Hard 55) and
  jams 1–2× (seeded). While jammed: no progress and a beep every 3 s (noise radius 12) until someone holds "Restart"
  for 1.5 s. Done → bonus loot spawns, plus objective bonus **+10%**. Max. 1 optional objective per heist in the beta.
- **Radio check** (Normal and Hard): 4 s after a guard is bubbled, his radio squawks "Unit 3, report!". A crew member
  holds "Answer" for 2 s on the bubble within 6 s → no alarm points (the +10 is waived). Missed → +40, and the guard
  leaves the bubble angry. **Max. 2 answers per round**; after that every bubble costs +40.

**Perk tree, 3×3** (each perk ≤ 15%; a row needs the row above it in the same branch; cost row 1/2/3 = 1/2/3 points,
so 18 points owns everything, about Rank 19; **max. 3 equipped**)

| Branch | Row 1 (1 pt) | Row 2 (2 pts) | Row 3 (3 pts) |
|---|---|---|---|
| Sneak | Soft Shoes (crouch 8 → 9) | Barrel Lungs (sneeze at 25 s) | Quiet Crowbar (CRACK 25 → 18) |
| Muscle | Long Arm (throw 10 → 12) | Deep Pockets (4 pocket slots) | Strong Back (heavy alone 7 → 8) |
| Crew | Quick Hands (rescue 2 → 1.5 s) | Escape Artist (self-escape after 12 s) | Spare Batteries (+1 charge on your first gadget) |

**Stars.** Thresholds use the loot's base value: 1★ = escape with ≥ 500, 2★ = ≥ 1,500, 3★ = Gouda banked + ≥ 2,500.
Each new star pays +300 Cash × the difficulty multiplier.

**Unlocking:** Praline Palace = 3★ in total on The Golden Wheel **or** Rank 4. Tulip Auction = 3★ in total on Praline
Palace **or** Rank 7. Stars give clear goals; the Rank route stops weaker and solo players from getting stuck.

**After the beta:**
- Big Cheese tier (×2.0, silly rules as in `beta-spec.md` §7.1, unlocked at 3★ on Hard).
- Van recall and arrival timers.
- Prank Arsenal sidegrades.
- "Legend" prestige at Rank 50: resets Rank and perk points only; gives a badge, an exclusive mask and +5% Rep per
  level (max. +25%).

**Skip from Notoriety:** guns, kills, hostages, body bags, loud-only heists, assault waves; random safes and mask
rarities (paid-random-items rules, Belgian/Dutch law); contracts, hosting fees, 2× passes, paid heists; a 100-level
grind and a 130-point skill tree.

## What changes in `advisor-brief.md`

1. **Job board:** "3 random jobs" becomes all heists + difficulty + 1 Hot Job + the Fresh bonus. Modifiers no longer
   roll randomly each round.
2. **Difficulty:** 3 tiers; every number in the brief is now the **Normal** tier.
3. **Objectives, perks, stars, Mask Up:** added as above.
4. **Unlocking:** Rank 3 / Rank 5 becomes stars **or** Rank 4 / Rank 7; Hard is unlocked per heist.

Unchanged: round length, loot classes, getting caught and the cell, 3 maps, the Garage, monetization off.

## Decisions on spec questions (`beta-spec.md` §12)

- **M1 — Pulled out of a hiding spot:** **no straight-to-cell.** Treat it as a normal grab: carried at 8 studs/s, so a
  teammate can still bubble the guard. Same rule everywhere, and the hero moment stays possible.
- **M2 — Karel as a snitch:** **keep** ("I'M TELLING!" +20, the 2 nearest guards investigate). He catches nobody but
  tells on everyone; that is his role. Keep fill ×0.5, range 25 and a 30 s cooldown per player, and show his own meter.
- **M3 — Half share for anyone not in the van at the end:** **confirmed.** The lost half goes to nobody (so there is no
  reason to leave someone behind). Busted = 50% of the van loot for all. "No One Left Behind" +10% stays.
- **M4 — Duplicate gadgets:** **allow them, no cap**, because a cap makes crews of strangers argue over picks. Radio
  checks and the +10 per bubble already limit spam. Log bubbles per round; if 4-player crews average more than 6
  bubbles, add a cap of 2 per kind.
- **M5 — What goes into the beta:**
  - **In:** 3 tiers (Easy/Normal/Hard ×0.8/1.0/1.4; Hard at **2★** on Normal, not 3★); objective bonus +10% (max. 1
    optional objective per heist); radio check (max. 2 answers per round, Normal and Hard only); 3×3 perk tree (costs
    1/2/3, max. 3 equipped); keycard; safe + Grater (45 s); Panic Pack.
  - **Wait:** Big Cheese tier, random van recall, Prank Arsenal. **Update (`advisor-maps.md`):** maps 2–3 do get one
    fixed **lockdown exit** in the beta (Conveyor Express → barge; Tulip Balloon), built with the arrival mechanism.
- **M6 — Payout rounding:** **round half up**, once, on each player's final amount (`math.floor(x + 0.5)`); never round
  in between. 3,000 shared by four → 1,088 each.

## Answers to the UX spec

1. **Banking: automatic, no button.** Walking into the van zone (≤ 6 studs from the open rear doors) banks everything
   you carry, pocket loot included, with a 0.5 s toss animation. Driving off still needs the 3 s hold.
2. **Crew vote, tie → earliest vote: approved.** Voting lasts 15 s and only cast votes count; with no votes, the first
   card picked wins. Solo = instant.
3. **10 s quick-wheel cooldown: approved**, as one shared cooldown for the whole wheel. It matches Roblox's preset rule
   (max. 1 text preset per 10 s). Icon-only SPOT pings keep 3 per 2 s [TO BE CONFIRMED: whether icon pings count as presets].
4. **Mini-job guard that never catches you, walking 10 studs/s: approved.** The rolled Gouda (11) slowly pulls away. If
   the player stops, the guard trips about 4 studs short (slapstick). He never picks up loot.
5. **Feedback after every round, hidden after 3 skips in a row: approved, per session** (it comes back next session).
   One tap, non-blocking, never delaying "NEXT JOB".
6. **Gamepad: gear button only, no Select binding: approved.** Select already starts Roblox's own UI navigation
   (`GuiService.AutoSelectGuiEnabled`). Make the gear `Selectable` and reachable with the D-pad, and add a Settings
   entry on the job board as a backup.

## Sources (accessed 16/10/2026)

- Notoriety wiki: [Difficulty](https://notoriety.fandom.com/wiki/Difficulty) · [Pagers](https://notoriety.fandom.com/wiki/Pagers) · [Stealth](https://notoriety.fandom.com/wiki/Stealth) · [Skills](https://notoriety.fandom.com/wiki/Skills) · [Levelling](https://notoriety.fandom.com/wiki/Levelling) · [Infamy](https://notoriety.fandom.com/wiki/Infamy) · [Repeat](https://notoriety.fandom.com/wiki/Repeat) · [Drill](https://notoriety.fandom.com/wiki/Drill_(gameplay)) · [Keycards](https://notoriety.fandom.com/wiki/Keycards) · [Safes](https://notoriety.fandom.com/wiki/Safes) · [Heists](https://notoriety.fandom.com/wiki/Heists) · [Game Passes](https://notoriety.fandom.com/wiki/Game_Passes) · [Mutators](https://notoriety.fandom.com/wiki/Mutators)
- Preset message rule: <https://create.roblox.com/docs/chat/preset-system-guidelines> (gameplan §3.5)
- Gamepad UI selection: <https://create.roblox.com/docs/reference/engine/classes/GuiService> · <https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278>
- Paid random items: <https://create.roblox.com/docs/production/monetization/paid-random-items>
