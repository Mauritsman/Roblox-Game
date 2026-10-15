# Heists (maps) in code

Elke heist (map) wordt in code gebouwd door `MapService` (`src/server/Services/MapService.luau`).
Deze map is géén service: de server-bootstrap laadt alleen `src/server/Services/*`.

```
Map/
  Registry.luau          lijst van alle heists + DefaultHeist
  Common/                gedeelde bouwstenen voor elke heist
    Builder.luau         blokken, ramen, labels, props (met vervangers), kleuren, GadgetColors
    CanalHouse.luau      Hollands grachtenpand (achtergrond)
    Atmosphere.luau      lichtsfeer; preset Atmosphere.BlueNight
  Heists/
    GoldenWheel/         heist 1 "The Golden Wheel"
      init.luau          de definitie (zie onder)
      Quay.luau          kade, gracht, busje met gadgetrek
      Shop.luau          winkel, beveiligingsruimte, binnenkoer
      Warehouse.luau     rijpingshal, kooi, camera's, kantoor
```

`MapService:Build("GoldenWheel")` bouwt een heist in `Workspace.Level`, zet de sfeer, zet `MapService.Points`
en `MapService.CurrentHeist`, en vuurt `MapService.LevelBuilt`. `MapService:Build()` zonder id bouwt de huidige
heist opnieuw (de eerste keer: `Registry.DefaultHeist`).

## Een nieuwe heist toevoegen

1. Maak een map `Heists/<Id>/` met een `init.luau`. Rojo maakt van die map één ModuleScript `<Id>`; de andere
   bestanden in de map worden zijn kinderen (`require(script.Deel)`). Gedeelde modules haal je uit
   `script.Parent.Parent.Common` (in `init.luau`) of `script.Parent.Parent.Parent.Common` (in een deel).
2. `init.luau` geeft een tabel terug met:

   | Veld | Type | Betekenis |
   |---|---|---|
   | `Id` | string | Zelfde als de mapnaam en de sleutel in `Registry.luau` |
   | `DisplayName` | string | Naam voor spelers (Engels) |
   | `Seed` | number | Vaste seed: `Build` krijgt `Random.new(Seed)`, zodat elke build hetzelfde is |
   | `Atmosphere` | `Atmosphere.Settings` | Tijdstip, lichtkleuren, nevel, …; lege velden komen uit `Atmosphere.BlueNight` |
   | `Points.Spawn` | Vector3 | Waar spelers verschijnen en na "gepakt" terugkomen (bij het busje) |
   | `Points.GuardStart` | Vector3 | Waar de bewaker verschijnt |
   | `Points.GuardRoute` | { Vector3 } | Patrouillepunten in volgorde, **op y = 0** (de bewaker vergelijkt zijn x/z-positie op y 0) |
   | `Build` | `(level: Folder, rng: Random) -> ()` | Bouwt alles in `level` |

3. Zet hem in `Registry.luau` (`<Id> = require(Heists.<Id>)`). Ontbreekt een veld of klopt een type niet, dan meldt
   `sh tools/check.sh` dat in `Registry.luau`.
4. Bekijken zonder Studio-scherm: zet `HEIST` bovenaan `tools/preview/studio_dump.luau` op je id (zie `CLAUDE.md`).

### Regels voor `Build`

- Bouw alles onder `level` (wordt `Workspace.Level`). MapService gooit het oude level weg bij elke nieuwe build.
- Gebruik `rng` voor toeval, niet `math.random`, zodat elke build hetzelfde is. (Uitzondering die al bestond:
  `Builder.window` kiest raamgloed en gordijnen met `math.random`.)
- Terrain (water): maak je eigen gebied eerst leeg (`FillBlock` met `Air`) en vul het dan, zoals `Quay.luau`. Bij een
  wissel naar een andere heist doet MapService `Terrain:Clear()`; water-instellingen (`WaterColor`, …) zet je zelf.
- Props via `Builder.prop` met een `fallback`, zodat de heist ook werkt als de prop niet in `ServerStorage.Props` staat.
- De grondplaat ligt op y −12 (onder de gracht van map 1): bouw je eigen vloeren.
- Level design (zie `.claude/agents/map.md`): deuren ≥ 5 studs breed, vrije hoogte ≥ 8 studs boven loopvloeren
  (anders vindt de padzoeker van de bewaker de weg niet).

## Tags en attributen die de gameplay verwacht

Namen staan in `src/shared/Tags.luau`. Zonder deze markeringen werkt een object niet mee in het spel.

| Wat | Op | Tags | Attributen en kinderen | Wie gebruikt het |
|---|---|---|---|---|
| Lamp | BasePart (Neon) met een `PointLight` | `Lamp`, `Electronic` | `Disabled = false` | GadgetService (EMP zet uit en daarna terug in de eigen kleur), GuardService (binnen `PointLight.Range` = verlicht, je wordt sneller gezien) |
| Bewakingscamera | Model | `SecurityCamera`, `Electronic`, `Spottable` | `Disabled = false`, `SpotKind = "camera"`, `BaseLook` (Vector3, kijkrichting in rust). Kinderen: `Body` (BasePart die draait, PrimaryPart) met een SpotLight `Cone`; `Led` (BasePart met attribuut `IsLed = true`); andere delen met een WeldConstraint aan `Body` en `Anchored = false` | CameraService, GadgetService (EMP) |
| Openbreekbaar (Crowbar) | BasePart (deur, poort) | `Pryable`, `Spottable` | `PrySeconds` (seconden; anders `Config.Gadgets.Crowbar.DoorSeconds`), `SpotKind = "lock"`. De deur draait open rond haar rand aan de lokale −Z-kant: breedte langs de lokale Z-as | GadgetService (knop + openen), DevService (`DevPry` op naam) |
| Buit (doel) | Onzichtbare BasePart, `CanCollide = false` | `Goal`, `Spottable` | `SpotKind = "loot"` | RoundService (aanraken = SUCCESS) |
| Gadgetsokkel | BasePart | `GadgetPedestal` | `Gadget` = gadgetnaam uit `Config.GadgetOrder`; kleur uit `Builder.GadgetColors` | LoadoutService (knop om te nemen/terug te leggen) |
| Markeerbaar | Part of model | `Spottable` | `SpotKind`: `"lock"`, `"loot"`, `"camera"` (`"guard"` en `"drone"` zetten de services zelf) | PingService, PingController (icoon), DroneController (zet camera's automatisch op de kaart) |
| Dekking | BasePart (bv. achterwand van een rek) | — | `Cover = true` | Nog door geen service gelezen; zet het toch op dekking |
| Kooi / hekwerk | Folder `Cage` rechtstreeks in `level` | — | — | GuardService en CameraService kijken door alles in die map heen |

## Let op: nog vast voor map 1 buiten deze map

Deze dingen staan (nog) niet in de heist-definitie; een nieuwe heist moet ze laten aanpassen door `mechanics`:

- `RoundService`: bij LOCKDOWN telt "binnen" als x 0..60 en |z| < 25 (de rijpingshal van map 1).
- `RoundService`: de succesmelding noemt "the Golden Gouda".
- `GuardService`: één bewaker per heist (op `Points.GuardStart`).
