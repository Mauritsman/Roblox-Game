# Developing Crowbar Crew

*Status 16 October 2026 — phase 0 done, phase 1 tested, map 1 "The Golden Wheel" got an art pass (quay, shop, courtyard, hall).*

## What is on your Mac

| Tool | What for | Enabled? |
|---|---|---|
| Roblox Studio 0.743 | Building and testing the game | Yes |
| Official Claude Code plugin "Roblox Studio" | Claude can operate Studio (Studio MCP) | Yes, but Studio must have the MCP switch on (see below) |
| Rokit 1.2 + Rojo 7.7.1 | Code as files in this repo, synced to Studio | Yes; the Rojo plugin is installed in Studio |
| Selene, StyLua, luau-lsp | Checking code (errors, formatting, types) | Yes (`sh tools/check.sh`) |
| VS Code + 4 extensions | Reading code with colours and explanations | Yes |
| Blender 5.2 | 3D models | Yes |
| Blender MCP | Claude can operate Blender | Yes (telemetry off, safe mode on) |
| RBXMonkey | Animations between Blender and Studio | Blender part on; the Studio plugin is in your Roblox inventory |
| Roblox Blender Plugin | Uploading models from Blender | Installed; login started: click **Authorize** in your browser |

Deliberately **not** installed: Claudio, Vibe Coder, Vibe Code City, MCPBridge (see gameplan §15) and Wally (only needed for packages; the Mac version requires Rosetta).

## Do this once yourself in Studio

**Assistant → ⋯ → Settings → MCP Servers → "Enable Studio as MCP server" on**, with a place open.
After that Claude can test, read errors and take screenshots on its own.

## Playing the prototype

1. Open `build/CrowbarCrew.rbxl` in Studio (Claude keeps this file up to date; `rojo build` recreates it).
2. Click **Play** (solo) or **Test → Server & Clients** with 2–4 players (fake players on your own computer).
3. At the orange van, walk to a **coloured pedestal** and press **E** (or the button on the screen) to take the gadget. Again = put it back.
4. Goal: the **Golden Gouda** in the cage at the back of the ripening hall. There are two ways in:
   - through the **cheese shop** (front door open) and the green **STAFF ONLY** door at the back (Crowbar, 1.5 s);
   - through the **delivery gate** on the quay (Crowbar, 3 s) and the courtyard, then the open back door of the hall.
   The guard walks a fixed round; two cameras watch the cage. The stairs along the north wall take you up to the office.

## The map (map 1, "The Golden Wheel")

- **Code:** every heist (map) has its own folder in `src/server/Map/Heists/`. Map 1 is in
  `src/server/Map/Heists/GoldenWheel/`: `init.luau` (name, seed, atmosphere, spawn and guard points), `Quay` (quay),
  `Shop` (shop) and `Warehouse` (hall). Shared building blocks (`Builder`, `CanalHouse`, `Atmosphere`) are in
  `src/server/Map/Common/`, the list of heists in `src/server/Map/Registry.luau`. `MapService` builds the chosen heist.
  Adding a new heist: see `src/server/Map/README.md`.
- **Quay and canal** (north = −X): canal houses on the far side, elms, lanterns, bollards, bicycles, small boats, a houseboat
  and bridges at both ends. The orange van with the gadget rack (crates with a glowing plate) stands on the brick road.
- **Cheese shop** with awning, shop window, counter, cheese racks, chalkboard and Karel's closet; next to it the **security room**
  (monitors, only reachable from the hall) and the **courtyard** (dog kennel, crates, ivy, string lights).
- **Ripening hall** (20 high): cheese shelving as cover, high windows, pipes, packing table, forklift, the cage with the golden
  gouda on a glowing pedestal, and an **office on a mezzanine**.
- **Night:** "blue night" with moonlight, haze, warm lamps and a little glow (bloom). Lamps with the tag *Lamp*
  go out from an EMP and then get their own colour back.
- **AI models:** 12 props made with Roblox's own 3D generator (see `tools/props.json` for prompts and IDs). They live in
  the place's `ServerStorage.Props`. **Important:** they are only in your place if you save it. So do
  **File → Publish to Roblox** (then everything is online as well). If the folder ever gets lost: `tools/restore_props.luau`.
- Custom materials (`CC_Brick`, `CC_Cobble`, …) could not be made yet: Roblox's material generator returned an internal error.
  The code uses them automatically as soon as they exist; until then you see the built-in Roblox materials.

### Controls

| Action | PC | Controller | Phone/tablet |
|---|---|---|---|
| Choose gadget | 1 / 2 / 3 | L1 | small buttons on the right |
| Aim + throw/shoot (EMP, Noisemaker, Bubble Blaster) | hold left mouse button, release = throw | L2 aim, R2 throw | GADGET (aim on/off), THROW |
| Launch / land drone | click with Drone selected / F | R2 / D-pad left | GADGET / BACK |
| Fly drone | WASD + mouse, space up, Ctrl down | sticks | joystick + ▲▼ |
| Break open the cage (Crowbar) | hold E at the cage door | hold X | hold the on-screen button |
| Crouch | C | B | CROUCH |
| Mark (SPOT) | Q (whatever is under your mouse) | R1 | PING |
| Chain Call / I'M IN / GO | G | Y | CALL |
| NOW / WAIT | Z / X | D-pad up / down | NOW / WAIT |
| Restart run (testing) | P | — | — |

### What you should see

- **Guard:** no icon = patrolling, yellow **?** = coming to look, red **!** = chasing you, orange **?!** = searching. The bar shows how full his "I see someone" meter is. In the dark and crouched he spots you later.
- **Cameras:** red light cone = where they are looking. If a camera sees you for 2 s, the alarm rises and the guard comes to look.
- **EMP:** blue circle while aiming. Cameras and lamps inside it are down for 10 s ("CAMS OFF 10"). If a drone is inside it, you see "DRONE IN RANGE!", and if you throw anyway: "Oops. EMP hits YOUR stuff too."
- **Bubble Blaster** (funny weapon, gameplan §4.8): if you hit the guard, he sits in a soap bubble for ±8 s ("GUARD BUBBLED"): he sees and hears nothing. Afterwards he comes back angry (+10 alarm). If you hit a teammate, they float in a pink bubble for 3 s.
- **Noisemaker:** the guard walks towards it ("GUARD AWAY 10"). During that distraction he does not hear the CRACK of the Crowbar.
- **Alarm** top left: QUIET → SUSPICIOUS → SEARCHING → LOCKDOWN (90 s to get away).

## Known limitations of phase 1

- Caught = back to the van (the security room comes in phase 2).
- No carrying loot, no Winch, no Spy Cams, no dog, no Karel, no saving. Of the funny weapons only the Bubble Blaster is in.
- The guard only has a walk animation; custom animations come in phase 3 (RBXMonkey).
- Solo timers (Noisemaker/EMP with a delay) come in phase 2.

## Done criteria for phase 1 (from gameplan §12)

1. You and 2 friends play the chain point 10 times in one evening.
2. For every failure they can say why.
3. At least one laugh out loud at the EMP.
4. It works on your own phone.
5. 10 minutes of play without red error messages in the console.
