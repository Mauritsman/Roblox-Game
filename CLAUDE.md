# Crowbar Crew — werkafspraken voor Claude

Roblox co-op stealth-heist. Ontwerp: `docs/gameplan-roblox.md` (bron van alle getallen en regels).
Gebruiker: Maurits, beginner. Antwoord in het Nederlands (Vlaams); spelerteksten in het spel in het Engels.

## Structuur
- `default.project.json` — Rojo-project. Code in `src/`:
  - `src/server/` → ServerScriptService.Server (bootstrap laadt `Services/*` : Init() dan Start())
  - `src/client/` → StarterPlayerScripts.Client (bootstrap laadt `Controllers/*`; helpers in `Lib/`)
  - `src/shared/` → ReplicatedStorage.Shared (`Config`, `Net`, `Tags`, `Signal`)
- Het level (graybox) wordt in code gebouwd door `MapService` — pas het daar aan, niet in Studio.
- Alle afstelbare getallen staan in `src/shared/Config.luau`.

## Regels
- Server is gezaghebbend: de client vraagt (`Net.request`), de server controleert en voert uit.
- Netwerk alleen via `Net` (één RemoteEvent-paar). Nieuwe verzoeken: `Net.onRequest` op de server.
- Geen vrije chat bouwen; pings zijn vaste woorden/iconen (zie gameplan §3.5 over preset-regels).
- Geen wapens, geen bloed (label Minimal/Mild, gameplan §5).
- Code aanpassen in de bestanden, nooit rechtstreeks in Studio (anders overschrijft sync het).

## Controleren en bouwen
- `sh tools/check.sh` — typecheck (luau-lsp), lint (selene), opmaak (stylua). Moet groen zijn voor een commit.
- `export PATH="$HOME/.rokit/bin:$PATH"; stylua src` — opmaak toepassen.
- `rojo build default.project.json -o build/CrowbarCrew.rbxl` — place-bestand bouwen.

## Studio (via de officiële Roblox Studio-plugin / Studio MCP)
- Vereist: Studio open met een place, en Assistant → ⋯ → Settings → MCP Servers → "Enable Studio as MCP server" aan.
- Code in Studio zetten zonder Rojo-klik: `python3 tools/gen_studio_sync.py` en de inhoud van
  `build/studio_sync.luau` uitvoeren met `execute_luau` (in edit-modus, niet tijdens een playtest).
- Testen: `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`.
- Start of registreer geen tweede StudioMCP-proces (poort 13469); de plugin beheert het.
- Sluit Studio nooit zelf af en pas geen instellingenbestanden van Studio aan (officiële Roblox-regel).

## Tools op deze Mac
Rokit (`~/.rokit/bin`): rojo 7.7.1, selene, stylua, luau-lsp. Blender 5.2 + Blender MCP (telemetrie uit, safe mode),
RBXMonkey-add-on (Blender) + plugin (Roblox-inventaris), Roblox Blender Plugin (nog niet ingelogd).
