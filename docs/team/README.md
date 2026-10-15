# Het Crowbar Crew-team (agents)

Maurits is eigenaar en beginner. Claude (de hoofdsessie) is **orchestrator**: verdeelt werk, voegt branches samen,
beslist met de adviseur. **Niemand stelt Maurits vragen.** Twijfel over ontwerp, markt of smaak → vraag het de **advisor**.

Doel: een **beta-klare** Roblox-game. Richting (goedgekeurd door Maurits op 16/10/2026):
**"Sluip binnen, pak zoveel kaas als je durft, en ontsnap."** Samenwerken is een *voordeel*, geen verplichting.

## Rollen (definities in `.claude/agents/`)

| Rol | Doet | Bezit (bestanden) |
|---|---|---|
| `advisor` | Research (Roblox-markt, wat werkt, regels), beslist ontwerpvragen, keurt specs en builds | `docs/research/` |
| `mechanics` | Ontwerpt en bouwt gameplay: ronde, buit, dragen, ontsnappen, gepakt/bevrijden, bewakers, hond, Karel, gadgets | `src/server/Services/*` (gameplay), `src/shared/Logic/*`, gameplay-controllers |
| `map` | Level design en bouw: routes, buitplekken, verstopplekken, vluchtroutes, randomisatie-ankers, props | `src/server/Map/*`, `tools/props.json` |
| `ux` | HUD, menu's, onboarding, mobiele knoppen, resultaatscherm, geluid en "juice" | `src/client/Lib/Hud*`, UI-controllers, `src/shared/Sounds.luau` |
| `meta` | Opslag (DataStore), geld, progressie, schuilplaats/lobby, winkel, analytics | `src/server/Services/{Data,Economy,Lobby,Shop,Analytics}*` |
| `tester` | Test in Studio (enige met Studio-toegang), schrijft testscenario's, bugrapporten, previews | `tools/studio_tests/`, `docs/team/bugs.md` |

Gedeelde bestanden (`src/shared/Config.luau`, `Tags.luau`, `Net.luau`, `default.project.json`): iedereen mag erin, maar
alleen in **zijn eigen blok** (een kop-commentaar met de rolnaam). De orchestrator lost merge-conflicten op.

## Werkafspraken

1. Lees eerst `CLAUDE.md`, `docs/beta-spec.md` (zodra die bestaat) en de relevante research in `docs/research/`.
2. Werk in je eigen git-worktree/branch. Commit klein en duidelijk (Nederlands of Engels), met de attributieregels uit `CLAUDE.md`.
3. Voor je "klaar" zegt: `sh tools/check.sh` moet groen zijn (typecheck, lint, opmaak, unit-tests).
4. Pure logica (berekeningen, randomisatie, economie) in `src/shared/Logic/` + een test in `tests/**/*.spec.luau`.
5. **Studio:** alleen de `tester` (of de orchestrator) gebruikt de Roblox Studio-tools, en nooit twee tegelijk.
   Anderen roepen geen `mcp__plugin_roblox-studio_*` aan, tenzij hun opdracht dat uitdrukkelijk toestaat.
6. Nooit publiceren, nooit de game openbaar zetten, nooit wachtwoorden of API-sleutels gebruiken, geen MCP-servers van derden
   installeren, Studio niet afsluiten. Publiceren doet Maurits.
7. Spelersteksten in het **Engels**, documentatie en commentaar in het **Nederlands**.
8. Inhoud: label **Mild** — geen bloed, geen echte wapens; grappen kopen tijd, geen oplossing (gameplan §4.8). Geen vrije chat.
9. Rapporteer kort: wat gedaan, welke bestanden, wat getest (met uitkomst), wat nog open staat.

## Stroom

`advisor` research → `mechanics` + `map` schrijven `docs/beta-spec.md` → `advisor` keurt → bouwen in parallel
(`mechanics`, `map`, `ux`, `meta`) → orchestrator voegt samen → `tester` test in Studio → bugs terug naar de eigenaar →
opnieuw testen → beta-checklist (`docs/beta-checklist.md`) groen → Maurits publiceert.
