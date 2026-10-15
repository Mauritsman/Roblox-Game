# Crowbar Crew — werkafspraken voor Claude

Roblox co-op stealth-heist. Ontwerp: `docs/gameplan-roblox.md` (bron van alle getallen en regels).
Gebruiker: Maurits, beginner. Antwoord in het Nederlands (Vlaams); spelerteksten in het spel in het Engels.

## Structuur
- `default.project.json` — Rojo-project. Code in `src/`:
  - `src/server/` → ServerScriptService.Server (bootstrap laadt `Services/*` : Init() dan Start())
  - `src/client/` → StarterPlayerScripts.Client (bootstrap laadt `Controllers/*`; helpers in `Lib/`)
  - `src/shared/` → ReplicatedStorage.Shared (`Config`, `Net`, `Tags`, `Signal`)
- Het level wordt in code gebouwd: `MapService:Build(heistId?)` bouwt een heist uit `src/server/Map/Registry.luau`.
  Per heist een map in `src/server/Map/Heists/` (map 1 "The Golden Wheel": `Heists/GoldenWheel/` met `init.luau` =
  definitie, `Quay`, `Shop`, `Warehouse`); gedeelde bouwstenen in `src/server/Map/Common/` (`Builder`, `CanalHouse`,
  `Atmosphere`). Nieuwe heist: `src/server/Map/README.md`. Pas het daar aan, niet in Studio.
- AI-props (busje, lantaarn, kaaswiel, …) staan als modellen in `ServerStorage.Props` van de place; `Builder.prop` kloont ze
  en valt terug op eenvoudige blokken als een prop ontbreekt. ID's en prompts: `tools/props.json`; herstellen:
  `tools/restore_props.luau`. Gameplay-tags en -attributen (Lamp, Pryable, Goal, GadgetPedestal, camera's) niet weghalen.
- Genereer meshes alleen in Edit-modus (niet tijdens Play) en hooguit 2 tegelijk (anders "Too Many Requests").
- Alle afstelbare getallen staan in `src/shared/Config.luau`.

## Regels
- Server is gezaghebbend: de client vraagt (`Net.request`), de server controleert en voert uit.
- Netwerk alleen via `Net` (één RemoteEvent-paar). Nieuwe verzoeken: `Net.onRequest` op de server.
- Geen vrije chat bouwen; pings zijn vaste woorden/iconen (zie gameplan §3.5 over preset-regels).
- Alleen grappige, niet-dodelijke wapens die één bewaker een venster lang uitschakelen (gameplan §4.8); geen echte wapens, geen bloed (label Mild, §5).
- Code aanpassen in de bestanden, nooit rechtstreeks in Studio (anders overschrijft sync het).

## Team
Er is een agent-team (advisor, mechanics, map, ux, meta, tester): zie `docs/team/README.md` en `.claude/agents/`.
Maurits wordt niets gevraagd; ontwerpvragen gaan naar de advisor. Doel: beta-klaar met meerdere maps.

## Controleren en bouwen
- `sh tools/check.sh` — typecheck (luau-lsp), lint (selene), opmaak (stylua), unit-tests (Lune: `lune run tests/run`). Moet groen zijn voor een commit.
- Pure logica in `src/shared/Logic/` (geen Roblox-API's) met tests in `tests/**/*.spec.luau`.
- `export PATH="$HOME/.rokit/bin:$PATH"; stylua src` — opmaak toepassen.
- `rojo build default.project.json -o build/CrowbarCrew.rbxl` — place-bestand bouwen.

## Studio (via de officiële Roblox Studio-plugin / Studio MCP)
- Vereist: Studio open met een place, en Assistant → ⋯ → Settings → MCP Servers → "Enable Studio as MCP server" aan.
- Code in Studio zetten zonder Rojo-klik: `python3 tools/studio_sync.py` (bouwt build/studio_payload.json en start een
  server op 127.0.0.1:34999), daarna de inhoud van `tools/studio_sync_apply.luau` uitvoeren met `execute_luau`
  (datamodel Edit, niet tijdens een playtest). Het script zet HttpEnabled even aan en meteen weer uit.
- In Studio-playtests bestaat `DevService` (alleen als RunService:IsStudio()): vanaf de Client-datamodel
  `Remotes.ToServer:FireServer("DevTake", "EMP")` en `FireServer("DevPry", "CageDoor")` (of "StaffDoor", "DeliveryGate")
  om zonder knoppen te testen.
  ProximityPrompts en screen_capture werken alleen als het Studio-venster vooraan staat (macOS).
- Wat in Studio staat is pas live na File → Publish door Maurits (Claude kan niet publiceren).
- Testen: `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`.
- Start of registreer geen tweede StudioMCP-proces (poort 13469); de plugin beheert het.
- Sluit Studio nooit zelf af en pas geen instellingenbestanden van Studio aan (officiële Roblox-regel).

## Kijken zonder Studio-scherm (Blender-preview)
Als `screen_capture` blijft hangen (Studio tekent niet als het venster niet zichtbaar is), gebruik de preview in Blender:
1. `python3 -I tools/preview/receiver.py <map> 35001 &` (luistert alleen op 127.0.0.1).
2. `tools/preview/studio_dump.luau` uitvoeren met `execute_luau` (Edit): bouwt het level en stuurt parts, lichten en meshes.
3. `python3 -I tools/preview/to_gltf.py <map> level.glb`, daarna in Blender importeren (glTF) en renderen.
Ruim daarna op: receiver stoppen; geen DevTools in ServerStorage laten staan.

## Tools op deze Mac
Rokit (`~/.rokit/bin`): rojo 7.7.1, selene, stylua, luau-lsp. Blender 5.2 + Blender MCP (telemetrie uit, safe mode),
RBXMonkey-add-on (Blender) + plugin (Roblox-inventaris), Roblox Blender Plugin (inloggen gestart op 16/10; Maurits moet in de
browser nog op Authorize klikken).
