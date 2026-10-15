# Ontwikkelen aan Crowbar Crew

*Stand 15 oktober 2026 — fase 0 klaar, fase 1 (prototype van één ketenpunt) geschreven.*

## Wat er op je Mac staat

| Tool | Waarvoor | Staat aan? |
|---|---|---|
| Roblox Studio 0.743 | Het spel bouwen en testen | Ja |
| Officiële Claude Code-plugin "Roblox Studio" | Claude kan Studio bedienen (Studio MCP) | Ja, maar Studio moet de MCP-schakelaar aan hebben (zie onder) |
| Rokit 1.2 + Rojo 7.7.1 | Code als bestanden in deze repo, naar Studio gesynchroniseerd | Ja; Rojo-plugin staat in Studio |
| Selene, StyLua, luau-lsp | Code controleren (fouten, opmaak, types) | Ja (`sh tools/check.sh`) |
| VS Code + 4 extensies | Code lezen met kleuren en uitleg | Ja |
| Blender 5.2 | 3D-modellen | Ja |
| Blender MCP | Claude kan Blender bedienen | Ja (telemetrie uit, safe mode aan) |
| RBXMonkey | Animaties tussen Blender en Studio | Blender-deel aan; Studio-plugin staat in je Roblox-inventaris |
| Roblox Blender Plugin | Modellen uploaden vanuit Blender | Geïnstalleerd; inloggen pas als het nodig is |

Bewust **niet** geïnstalleerd: Claudio, Vibe Coder, Vibe Code City, MCPBridge (zie gameplan §15) en Wally (pas nodig voor pakketten; de Mac-versie vraagt Rosetta).

## Eén keer zelf doen in Studio

**Assistant → ⋯ → Settings → MCP Servers → "Enable Studio as MCP server" aan**, met een place open.
Daarna kan Claude zelf testen, fouten lezen en schermafbeeldingen nemen.

## Het prototype spelen

1. Open `build/CrowbarCrew.rbxl` in Studio (Claude houdt dit bestand bij; `rojo build` maakt het opnieuw).
2. Klik **Play** (alleen) of **Test → Server & Clients** met 2–4 spelers (nepspelers op je eigen computer).
3. Ga bij het oranje busje naar een **gekleurde sokkel** en druk op **E** (of de knop op het scherm) om het gadget te nemen. Nog eens = teruglegen.
4. Doel: de **Golden Gouda** in de kooi achteraan de hal. De bewaker loopt een vaste ronde; twee camera's bewaken de kooi.

### Besturing

| Actie | Pc | Controller | Telefoon/tablet |
|---|---|---|---|
| Gadget kiezen | 1 / 2 / 3 | L1 | kleine knoppen rechts |
| Richten + gooien/schieten (EMP, Noisemaker, Bubble Blaster) | linkermuisknop indrukken, loslaten = gooien | L2 richten, R2 gooien | GADGET (richten aan/uit), THROW |
| Drone starten / landen | klik met Drone geselecteerd / F | R2 / D-pad links | GADGET / BACK |
| Drone vliegen | WASD + muis, spatie omhoog, Ctrl omlaag | sticks | joystick + ▲▼ |
| Kooi openbreken (Crowbar) | E vasthouden bij de kooideur | X vasthouden | knop op het scherm vasthouden |
| Hurken | C | B | CROUCH |
| Markeren (SPOT) | Q (wat onder je muis staat) | R1 | PING |
| Chain Call / I'M IN / GO | G | Y | CALL |
| NOW / WAIT | Z / X | D-pad omhoog / omlaag | NOW / WAIT |
| Run herstarten (testen) | P | — | — |

### Wat je moet zien

- **Bewaker:** geen icoon = patrouille, gele **?** = komt kijken, rode **!** = achtervolgt je, oranje **?!** = zoekt. Het balkje toont hoe vol zijn "ik zie iemand"-meter is. In het donker en gehurkt zie hij je later.
- **Camera's:** rode lichtkegel = waar ze kijken. Ziet een camera je 2 s, dan stijgt het alarm en komt de bewaker kijken.
- **EMP:** blauwe cirkel tijdens het richten. Camera's en lampen erin liggen 10 s plat ("CAMS OFF 10"). Hangt er een drone in, dan zie je "DRONE IN RANGE!", en gooi je toch: "Oops. EMP hits YOUR stuff too."
- **Bubble Blaster** (grappig wapen, gameplan §4.8): raak je de bewaker, dan zit hij ±8 s in een zeepbel ("GUARD BUBBLED"): hij ziet en hoort niets. Daarna komt hij boos terug (+10 alarm). Raak je een teamgenoot, dan zweeft die 3 s in een roze bel.
- **Noisemaker:** de bewaker loopt ernaartoe ("GUARD AWAY 10"). Tijdens die afleiding hoort hij de CRACK van de Crowbar niet.
- **Alarm** linksboven: QUIET → SUSPICIOUS → SEARCHING → LOCKDOWN (90 s om weg te raken).

## Bekende beperkingen van fase 1

- Gepakt = terug naar het busje (de beveiligingsruimte komt in fase 2).
- Geen buit dragen, geen Winch, geen Spy Cams, geen hond, geen Karel, geen opslag. Van de grappige wapens zit alleen de Bubble Blaster erin.
- De bewaker heeft alleen een loopanimatie; eigen animaties komen in fase 3 (RBXMonkey).
- Solo-timers (Noisemaker/EMP met vertraging) komen in fase 2.

## Klaar-criteria fase 1 (uit het gameplan §12)

1. Jij en 2 vrienden spelen het ketenpunt op één avond 10 keer.
2. Van elke mislukking kunnen ze zeggen waarom.
3. Minstens één keer hardop gelachen om de EMP.
4. Het werkt op je eigen telefoon.
5. 10 minuten spelen zonder rode foutmeldingen in de console.
