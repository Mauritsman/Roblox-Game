# Beta checklist

Orchestrator, 16 Oct 2026. Source: `docs/research/advisor-brief.md` §7 and the beta specs. Status: ✅ done and tested ·
🟡 built, not yet verified in Studio · ⬜ open · 👤 needs Maurits (publishing / Creator Hub).

## Game

| Item | Status | Notes |
|---|---|---|
| Core loop: sneak in, grab loot (pocket/hands/heavy/main), bank at the van, escape | 🟡 | Mechanics A; smoke-tested in Studio on the fallback layout (bank + payout work) |
| Round flow: Garage → Briefing → Heist ⇄ Lockdown → Getaway → Payout → Next Job | ✅ | Full loop ran in Studio without errors (police at 8:00 → payout → next briefing) |
| Guards (2–4 by crew size), detection, chase, search | 🟡 | Mechanics B |
| Captured → carried to the cell → rescue / self-escape; BUSTED | 🟡 | Mechanics B; needs map cells |
| Hiding spots with the 20 s sneeze | 🟡 | Mechanics B |
| Boef the dog, Karel the caretaker, Inspector | 🟡 | Mechanics B; need map anchors |
| Gadgets: Crowbar + 2 picks, loud +1 charge | 🟡 | Mechanics C |
| Objectives: keycard, safe with jamming device, radio check | 🟡 | Mechanics C |
| Difficulty tiers Easy/Normal/Hard, Hot Job, perks | 🟡 | Meta + mechanics |
| Mini-job tutorial (first loot ≤ 45 s, cannot fail) | 🟡 | Mechanics C + map B |
| The Garage hideout (board, rack, mirror, trophies, practice yard) | ⬜ | Map B building |
| Map 1 The Golden Wheel retrofit (loop, cell, exits, hide spots, chute) | ⬜ | Map A building |
| Map 2 Praline Palace (MELTDOWN, barge escape) | ⬜ | Map C building |
| Map 3 Tulip Auction (FLOWER FRENZY, balloon escape) | ⬜ | Map D building |
| Map runtime: rides, rhythm machines, zones, lockdown switches | ⬜ | Mechanics D building |
| All signs readable and English | ✅ | `Builder.sign` fixed (B-001); new maps follow the sign table |

## Platform

| Item | Status | Notes |
|---|---|---|
| Saving: DataStore with session lock, retries, migrations, Studio fallback | 🟡 | Meta; real DataStores only testable in the published game |
| Onboarding funnel (8 steps) + round funnel + economy events | 🟡 | Meta AnalyticsTracker; records only in the published game |
| Mobile: buttons ≥ 48 px (main 64–72), max 3 actions + context | 🟡 | UX touch arc; to verify on a phone |
| Performance: ≥ 30 fps on a cheap phone, ≤ 7 NPCs, part budgets | ⬜ | Tester + phone test |
| Feedback: one tap after each round + fixed tags | 🟡 | UX payout screen |
| No free chat; Quick Words; server decides everything | ✅ | Pings are fixed words; all requests validated server-side |
| Monetisation off; ProcessReceipt built and testable | 🟡 | Meta |
| StreamingEnabled on | ⬜ | Workspace property (project file) |

## Game page and publishing (👤 Maurits)

| Item | Status | Notes |
|---|---|---|
| File → Publish to Roblox (also saves the AI props in the place) | 👤 | Required — props live only in the place file |
| Title "Crowbar Crew [BETA]" + description "Co-op cheese heist for 1–4. Sneak in, grab, escape." | 👤 | Creator Hub → Configure |
| Text-free 512×512 icon + 3–5 thumbnails 1920×1080 | 👤 | Renders provided in `docs/media/` |
| Maturity questionnaire re-check (expected Mild) | 👤 | Was done for the prototype; re-check after the beta content |
| Release: private → max 10 Early Testers → open beta 16+ | 👤 | Manage audience |
