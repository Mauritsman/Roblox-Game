# Advisor: making heist maps fun, replayable and more intense

*Advisor, 16/10/2026. Owner: "Existing maps are boring… Tulip and Praline: good as a starter, but they can be much
better and more intense." Based on PAYDAY 2's Murky Station postmortem, stealth-design articles, IO Interactive's
Hitman talks, Notoriety and ROB IT (sources at the bottom), plus our limits: phones, 8-minute rounds, 1–4 players,
max. 7 NPCs, Mild. These are decisions, not suggestions.*

## Principles (every heist)

1. **Onion, 3 rings** (PAYDAY 2's layout): Public → Staff → Secure, borders visible (staff = yellow-striped floor,
   secure = red light + keycard reader).
2. **Entries and loops:** ≥ 3 ways into Staff (watched, noisy, quiet hatch) + 1 loud-only shortcut, 1–2 locked at
   random. Every room except hiding nooks has ≥ 2 exits; 2–3 overlapping chase loops of 40–80 studs.
3. **Sightlines and guards:** indoor lines ≤ 35 studs, cover every ≤ 12 studs at two heights; guard loops ≤ 25 s with
   2–3 variants, no overlap.
4. **Height:** max. 2 floors (upper ≤ 10 studs), ≥ 2 links, no jumps; heavy-loot doors ≥ 6 wide, headroom ≥ 8.
5. **Loot by depth:** first small loot ≤ 45 s away; heavy ≥ 60 studs from the exit with 2 haul routes; main loot on
   1 of 3 secure spots with 2 exits each.
6. **One landmark, 1–2 secrets** (stash 150–500), and one visual language (orange = usable, glow = loot).
7. **Randomize only what changes decisions:** entries, main-loot spot, keycard spot, loot subset, guard variants, exits.
8. **Rides and machines are never free physics:** a ride welds the player to a seat the server moves along a fixed
   path. Free physics jitters on phones and invites cheating.

## Checklist per heist (map agent must pass all)

- [ ] 3 visible rings; ≥ 4 small loot in Public; ≥ 4 randomizable entries + 1 loud-only shortcut.
- [ ] No dead-end rooms; ≥ 2 chase loops; sightlines and cover as above; no jumps; heavy-loot doors ≥ 6 wide.
- [ ] 8–12 hiding spots (≥ 1 within 15 studs of every loot cluster); 3 main-loot spots; 1 keycard door; 1 optional safe.
- [ ] Landmark, signature set piece, secrets; maps 2–3 also the 4-beat climax (below).
- [ ] Van → furthest main-loot spot 20–35 s empty-handed; footprint ≤ 130 × 110 studs.
- [ ] Tester: ≥ 30 fps on a cheap phone [TO BE CONFIRMED: part budget]; 3 different routes seen in 5 rounds.

## Escalation: map 1 teaches, map 2 pressures, map 3 is the finale

Every map follows **4 beats**:
1. Calm stealth with rhythmic hazards.
2. A staged main-loot grab.
3. A **lockdown that changes the map**.
4. A **spectacular escape**.

Map 1 keeps beats 3–4 simple (timer + chase to the van). Maps 2 and 3 go all in.

| | The Golden Wheel | Praline Palace | Tulip Auction |
|---|---|---|---|
| Loot per round | ±3,900 | ±5,500 | ±7,000 |
| Main loot | Golden Gouda 1,500 (heavy) | Golden Praline 2,200 (heavy, **melts**) | Black Tulip in its royal pot 3,000 (heavy, **fragile**) |
| Guards (4 players, Normal) | 4 | 5 | 5 + the clock spotlight |
| New pressure | Dog, Karel | Rhythm machines + melting | Moving light + moving train + fragile loot |
| Lockdown | Timer + chase | **MELTDOWN**: factory reconfigures | **FLOWER FRENZY**: auction hall goes wild |
| Escape | Van | Front van **or** Conveyor Express → barge | Front van **or** the Tulip Balloon from the roof |

**Shared rule for maps 2–3:** stealth leaves via the front van. At LOCKDOWN a roadblock closes the front and a
**lockdown exit** activates (exit attributes `QuietOnly` / `LockdownOnly` / `ArrivesAt`). Map changes use one tag,
`LockdownSwitch`, with `Action` = Close / Open / Speed / On. This **replaces "van recall after the beta"**: a fixed
lockdown exit on maps 2–3 is in the beta.

### Praline Palace: pressure

- **Layout:** chocolaterie shop (Public) → factory floor with a conveyor loop, tempering vats and a chocolate fountain
  (Staff) → cold room and praline vault (Secure) → canal loading dock at the back.
- **Rhythm hazards:** the **chocolate fountain** draws the nearest guard to taste it every 30 s for 4 s; the **Big
  Mixer** thumps every 6 s and drowns out a CRACK for 2 s; the **wrapping machine** gold-wraps you so guards ignore
  you for 8 s (not while carrying).
- **Stakes, melting:** chocolate loot outside a cold zone loses 2% of its value per second (min. 50%), with drips and
  a falling value counter: haul it now, together. Cold boxes in the van and at the dock stop it. Praline Tower: drop = −25%.
- **Climax:** the Golden Praline turns on a cake stand in the cold vault. Lifting it plays a choir "AAAH" sting,
  starts LOCKDOWN and starts the melting.
- **MELTDOWN (lockdown):** red lights and siren. Fire shutters close 2 of the 4 factory doorways (seeded, can't be
  pried). Steam vents puff every 5 s and block guard vision. The conveyor becomes **Conveyor Express**: hop on a
  praline box (server-moved ride, 20 studs/s), with or without loot, past two "STOP" windows where guards can grab
  riders, to the dock.
- **Escape:** the barge "The Sweet Getaway" at the dock. Last rider in: slow motion + "JUST MADE IT".

### Tulip Auction: the finale

- **Layout:** auction viewing gallery (Public) → greenhouse wing with misting lines, a trolley-train loop and cold
  rooms (Staff) → the Royal Vault behind the auction hall (Secure). A roof garden at ≤ 10 studs links the wings
  (2 ladders + 1 ramp).
- **Rhythm hazards:** the **auction clock** hand sweeps a spotlight across the hall every 12 s (cross in the dark
  sector); the **trolley train** (tractor + 4 flower carts) loops at 8 studs/s as moving cover, and you can ride it
  past guards' backs; **cold rooms** shut after 10 s, and their fog halves guard range.
- **Stakes, fragile:** bulbs and vases lose 25% per drop (a caught throw is fine); the Black Tulip pot loses 10% per
  drop and needs two carriers or a trolley.
- **Timed event:** at 5:00 "MORNING AUCTION IN 3:00" (instead of the shift change): hall lights rise in steps, so the
  dark sectors shrink.
- **Climax:** the Black Tulip rises out of the floor on a glass plinth. Lifting it rings a "GONG", then LOCKDOWN.
- **FLOWER FRENZY (lockdown):** sprinklers soak the greenhouse (running with medium loot = slip and squeak); the train
  goes express (22 studs/s) to the roof ramp; the clock spins at double speed; the front doors shutter.
- **Escape:** the **Tulip Balloon** (a hot-air balloon shaped like a tulip) docks at the roof garden 20 s into the
  lockdown and lifts off at police time. Its basket is the escape zone; walk in, no jumping. Liftoff: confetti petals
  + "JUST MADE IT".

## The Golden Wheel: keep it, retrofit it

Keep the layout and art. Today every route funnels into one hall, the Gouda always sits in a dead-end cage
(x 50..58), one guard walks a rectangle around two identical racks, and the office is a dead end. Retrofit, in order:
1. **Close the ring:** a back alley along the hall's z +25 side to the yard, a loading dock at x 60, and a second cage door.
2. **Break up the hall:** 2 cross-aisle gaps per rack; 2 guards on ≤ 25 s loops.
3. **3 Gouda spots:** cage / office safe (keycard) / a cold cellar under the shop. Small loot in the shop window,
   medium in the yard, Big Wheels in the hall.
4. **Office exit:** the **Cheese Chute** to the yard (heavy loot rumbles out after 3 s, noise 20; Boef chases it).
5. **Landmark:** a rotating Golden Wheel sign on the roof.

## Sources (accessed 16/10/2026)

- PAYDAY 2, Murky Station postmortem (onion layout, randomization, patrol loops): <https://80.lv/articles/designing-highly-replayable-stealth-levels-for-payday-2/>
- Stealth game design (readable AI, safe zones, recoverable failure): <https://www.gamedeveloper.com/design/stealth-game-design>
- Loops and sightlines: <https://critpoints.net/2018/02/18/good-fps-map-design/>
- Hitman level design (GDC 2016, 2019): <https://gdcvault.com/play/1023849/Level-Design-in-HITMAN-Guiding> · <https://gdconf.com/news/what-makes-hitman-2-levels-tick-find-out-gdc-2019s-level-design-workshop> · <https://en.wikipedia.org/wiki/Sapienza_(Hitman)>
- ROB IT loop: <https://earnaldo.com/blog/rob-it-vs-jailbreak> · Notoriety stealth: <https://notoriety.fandom.com/wiki/Stealth>
- Code reviewed: `src/server/Map/Heists/GoldenWheel/{init,Quay,Shop,Warehouse}.luau`
