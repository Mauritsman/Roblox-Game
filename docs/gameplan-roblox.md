# Crowbar Crew — gameplan for Roblox

*Version 1.3 — 15 October 2026 (funny weapons; monetisation extended with Crew Pass, shop and Glovebox). Brief: [`docs/roblox-prompt.md`](roblox-prompt.md). Title and Karel's role confirmed by Maurits on 15/10/2026.*

**Source of the concept.** The full old plan (`unpaid-gameplan.md`) was not included with the brief and is not in this repo. This plan is therefore based on the summary in the prompt. Where that summary left something open, there is a proposal. Karel's role (§9.6) and the title (§14) have since been confirmed.

**Facts about Roblox** (rules, prices, tools) were checked on 15 October 2026. The sources are in the appendix at the bottom. Roblox changes its rules often: check the points marked ⚠️ again just before you publish.

**Reading guide.** A Roblox term that appears for the first time gets a one-sentence explanation right away, *in italics between brackets*. Text that players see in the game is in English and in quotes, for example "CAMS OFF 8".

---

## 1. Summary in five sentences

1. **Crowbar Crew** is a co-op stealth heist for 1 to 4 players on Roblox, in which a crew with a van pulls off small, clever break-ins in a playful, Dutch-feeling town, with only funny weapons that never hurt anyone.
2. Every obstacle takes three steps — **see → clear → open** — within a 10-second window, and each gadget does only one of those steps: you only win if you work together.
3. It is made for players aged 9 to 15 (reachable after Roblox's extra review, §5.5) on phone, tablet, PC and console: runs of about 12 minutes, one button per gadget, and a ping and countdown system that works without voice or text chat.
4. The age rating will be Mild, playable from age 5: no blood, only slapstick — a guard floating in a soap bubble for 8 seconds, or your own drone dropping on your head because of your friend's EMP.
5. In Entry Point and Notoriety one good player can do everything alone and there is always a real gun lying ready; here nobody is complete and a prank buys 10 seconds at most, so failing together, laughing together and coming to rescue each other *is* the game.

### Different from Entry Point, Notoriety and ROB IT

You mentioned Entry Point and Notoriety. There is now a third, more direct competitor: **ROB IT** (December 2025). In terms of audience and rating it is the closest to your idea.

| | **Entry Point** | **Notoriety** | **ROB IT** | **Your game** |
|---|---|---|---|---|
| What it is | Stealth and action shooter, 15 missions + PvP | Official PAYDAY heist: co-op shooter, quiet or loud | Break in, steal everything, don't get seen by the guard | Co-op stealth with gadgets and a mandatory chain |
| Weapons | Yes (real ones) | Yes (real ones) | No | **Only funny ones**: bubbles, cheese, a rubber chicken (§4.8) |
| Can one player do everything alone? (estimate based on the game descriptions) | Yes | Mostly | Yes | **No**: each gadget does one step |
| Rating | Moderate | Mild | Minimal | Minimal/Mild |
| Run length | ⚠️ not found | ⚠️ not found | about 6–7 min | ~11 min (cycle 14 min) |
| Status (15/10/2026) | 348 M visits, ~150 players now, last update July 2025 (maintenance mode) | 555 M visits, ~2,500 now, peak 18,500 (July 2026), active | 300 M visits, ~3,300 now, peak ~35,000 (January 2026) | — |
| Earning | Missions as game passes (750–1,200 Robux) | 14 passes (49–599 Robux), incl. 2× XP/Cash | No game passes | Only looks and convenience (§8) |

**What this tells you:**
- The two big heist games are **shooters for older players**. A heist **without real guns, with funny weapons and a mandatory crew chain**, is still an empty spot.
- **ROB IT proves there is a lot of demand** for a kid-friendly break-in game with a Minimal rating (a peak of 35,000 concurrent players). But it is a simple concept you can play solo.
- **Your difference from ROB IT** is exactly your core: in ROB IT you are a clever burglar, here you are **a crew that needs each other**. The EMP that takes down your own drone and the moment you get a friend out of the security room are things ROB IT cannot offer.
- **Your risk:** ROB IT can add co-op, and a second PAYDAY game is coming to Roblox in 2026 (Gamefam). That is why your difference has to be visible in the first minute (§11), not only after an hour.

**The first minute has to show three things:**
1. **No real gun on screen.** Instead a drone, an alarm clock, a crowbar and a Bubble Blaster.
2. **The EMP joke**: your own drone drops out of the air with a "BZZT". In the Practice Yard within 60 seconds (§11).
3. **A door that only opens when someone else gives you the window**: the ring "CAMS OFF 10" and the Chain Call.

On the game page (icon, thumbnails, first sentence of the description) you show the same thing: *"No real guns. No boss. Just your crew, a van, a bubble blaster and an EMP that hits your own drone."*

---

## 2. What stays, what changes, what goes

| Part of the concept | Verdict | Reason |
|---|---|---|
| Four friends with a van, without an employer | **Stays** | Strong, simple fantasy. The van gets three functions: queue in the lobby, gadget cupboard during the run, and exit (loot in the van = secured). |
| Pillar: preparation, not fighting | **Adjusted** (confirmed 15/10/2026) | Weapons yes, but only funny and non-lethal ones (§4.8). A weapon buys a window of ±10 s on one guard, never a solution. No real guns: that remains your difference from Entry Point and Notoriety. |
| The chain *see → clear → open* | **Stays** | This is the core. Everything in this plan revolves around it. |
| Window of 8–12 seconds | **Adjusted** | Default **10 s** for everyone in the server (Rookie 12 s, Pro 8 s). A separate, longer window for mobile is not possible, because the window is one shared state of the world (see §3.3). |
| Each gadget only opens a window, never a path | **Stays** | Becomes a hard design rule: electronic locks do *not* open with an EMP. |
| Nobody can take a step alone | **Adjusted** | True with 3–4 players. With 1–2 players, timers and automatic cameras replace the missing teammates (§3.7). Without solo, your game will be empty at launch. |
| The six gadgets | **Stays** (+1) | Each gadget belongs to one step: 2× see, 2× clear, 2× open. One button per gadget. Added: the Bubble Blaster as the 7th default gadget (CLEAR, §4.8). |
| EMP also hits your own drone and cameras | **Stays** | *The* comedy moment. The range becomes visible before you throw, so it is a consequence of bad coordination and not a random punishment. |
| Default gadgets + sidegrade extra gadgets | **Stays** | Ideal for Roblox: a new player is immediately just as strong. |
| Stake: caught = gadget lost | **Adjusted** | Only gadgets you bought with in-game money can be lost for good. Default gadgets are only lost for the rest of that run. Things bought with Robux are never lost (§7.3). |
| Rescuing a teammate = getting their gadget back | **Stays** (+ extra) | Caught players sit in the security room and watch along through the building's cameras. That way they stay useful instead of watching for 5 minutes. |
| Carrying loot = out of the chain | **Stays** (+ exception) | Big loot (bags, cheese wheels) blocks your gadget; small loot (key, USB stick, petty cash) goes in your pocket and blocks nothing. |
| Guards (NPCs) | **Stays** (simpler) | Four clear states with icons above their heads. Doable for a beginner. |
| Cameras | **Stays** | |
| Dog that hunts the drone | **Stays** (adjusted) | The dog never bites players. It barks (draws guards) and takes your drone if it flies too low. |
| Asset Recovery (comes for active electronics) | **Adjusted, later** | Works with a shared "Signal" meter that fills after about 90 s of uninterrupted electronics. A slowly building threat has to move faster in 12-minute runs. Only comes after the first release (§12). |
| Alarm ladder | **Adjusted** | Four steps. The last step is not police with weapons but a 90 s escape timer. |
| Cover (work clothes, being addressed by an NPC) | **Adjusted, later** | Text conversations do not work for 9-year-olds on a phone in an international game. It becomes a choice of 3 icons, where you saw the right answer during the scouting (§9). |
| Traces (footprints, glass, moved items) | **Stays** (fewer kinds) | Five kinds of traces, all visible and readable, without blood (§5). |
| Wiping traces costs a consumable | **Stays** | The "Clean Spray", only for sale with in-game money, never with Robux. |
| NPC Karel | **Adjusted** | His role was not in the summary. Karel becomes the caretaker who cleans everything up and snitches (§9.6, confirmed). |
| Violence as a consequence, never as a solution | **Adjusted** | New rule: "a prank buys time, not a solution". Slapstick (soap bubble, cheese, stars), nobody gets hurt, and every guard comes back angrier after the window. |
| Blood as information (trace) | **Goes** | Replaced by a small tear from your work vest on barbed wire: the same idea ("someone has been here"), without blood. That way you never have to hesitate about blood in the age rating questionnaire (§5). |
| Working title UNPAID | **Goes** | No longer fits. The new title is **Crowbar Crew** (§14). |
| Coordination by voice (PC design) | **Adjusted** | Becomes a ping system plus the "Chain Call": a shared 3-2-1 countdown (§3.4). |
| PC controls | **Adjusted** | Designed for touchscreen first, then PC and controller (§3.6). |

### Contradictions in the concept

These are the places where the concept contradicts itself, and how this plan resolves them:

1. **"Nobody can take a step alone"** versus **"it must also work with 1 player"**. Both cannot be fully true. *Solution:* solo is a full but different mode, in which your own timers and automatic cameras replace your teammates. The chain stays; you just play it against the clock instead of with people (§3.7).
2. **The EMP knocks out your own drone**, but the drone needs to see whether the corridor is clear precisely *during* the EMP window. Without a rule, every EMP window would switch off your own eyes. *Solution:* the EMP has a visible radius of 14 studs (*a stud is the Roblox unit of length, about 28 cm*). The drone has to keep watching from outside that radius. Placement thus becomes a skill, and the comedy comes when you misjudge it.
3. **A longer window on mobile** is not possible when PC and mobile players are in the same server: a camera that is off is off for everyone for the same length of time. *Solution:* one window for the whole server, tuned for mobile (10 s), plus aids that mainly help mobile: countdown, automatic marking and big buttons.
4. **"Robux purchases are never lost"** clashes with a common Roblox monetisation model: whoever sells in-game money for Robux (or a 2× Cash pass) indirectly lets players buy gadgets with real money that they then lose. *Solution:* you do *not* sell in-game money, and no booster for in-game money either (§8).
5. **"Blood as information"** clashes with **"as young an audience as possible"**. *Solution:* no blood. A small tear from your vest tells the same story.
6. **"Whoever carries loot drops out of the chain"** means that in solo and duo you can almost never carry. *Solution:* small loot in your pocket blocks nothing, and the Winch sends big loot along a cable to the van without anyone carrying it.
7. **"Camera set = fixed cameras that guard an area"** goes against the rule "each gadget only opens a window", because cameras give lasting information. *Solution:* whoever watches the footage has to stand still, and active cameras fill Asset Recovery's Signal meter. So information costs something.
8. **A slowly swelling threat (Asset Recovery)** does not fit in 12-minute runs. *Solution:* it comes after about 90 seconds of uninterrupted electronics, not after a quarter of an hour.
9. **"Four friends"** as a fantasy versus the reality of matchmaking: strangers who leave halfway. *Solution:* gadget slots shift automatically when someone leaves, and during the first minutes new players can join at the van (§3.7).
10. **Karel** has a role "in the traces", but which one was not stated. *Resolved:* he is the caretaker who cleans up traces *and* loudly snitches about them (§9.6).

---

## 3. The chain on Roblox

### 3.1 The rule

Every obstacle (a camera plus a guard plus a closed door) is a **chain point**. You solve it in three steps, in this order:

| Step | Player-facing name in the game | What you do | Gadgets |
|---|---|---|---|
| 1. See | "EYES" | Discover where guards, cameras and the dog are, and show that to the crew | Drone, Spy Cams |
| 2. Clear | "CLEAR" | Open a window: cameras off, or guards away | Noisemaker (distraction kit), EMP |
| 3. Open | "OPEN" | Get through the door, gate or hatch | Crowbar, Winch |

Design rule: **each gadget does exactly one step, and no gadget completes a step entirely without help.** The Drone sees the guard but cannot get him away. The Noisemaker lures him away, but the thrower cannot see whether it worked. The Crowbar opens the door, but makes noise, so it has to happen during the distraction.

### 3.2 What a chain point looks like (readability for children)

- When the Drone or a Spy Cam looks at an obstacle for 1 second, a **chain card** appears above that spot for everyone, with icons of what is needed: for example 📷 + 👮 + 🔒 ("1 camera, 1 guard, locked door").
- On the easiest difficulty (Rookie) those cards also show the three steps in colour: blue = EYES, yellow = CLEAR, red = OPEN. On Normal and Pro only the icons.
- A chain point always has **two possible routes**, for example switching off the camera with the EMP *or* luring the guard away with the Noisemaker. That way every combination of gadgets in your crew works.

### 3.3 The window: 10 seconds for everyone

*(Server/client: the **server** is the Roblox computer on which the game world runs for all players at once; the **client** is one player's device, which shows what the server says and sends input back.)*

A camera that goes down because of an EMP goes down on the **server**, so for all players at the same time and for the same length of time. A longer window just for mobile players is therefore not possible as long as PC and mobile players play together, and on Roblox they almost always do. That is why:

| Difficulty | EMP window | Distraction (guard away) | For whom |
|---|---|---|---|
| Rookie | 12 s | 12 s | First hours, the first map |
| Normal | 10 s | 10 s | Default |
| Pro | 8 s | 8 s | Experienced crews who play together (friends with voice) |

**Advice: keep 10 s as the default and never change that value per device.** Players learn the rhythm ("ten counts") and that rhythm is the core. What *does* help mobile:

- A **shrinking ring with seconds** at the top centre of the screen, for the whole crew: "CAMS OFF 8".
- A **ticking sound** in the last 3 seconds and the message "CLOSING".
- The Crowbar only starts counting from the moment you hold it. You do not have to aim perfectly; pressing at the right moment is enough.
- Delay (lag) does not count against you: the window starts the moment the EMP goes off on the server, and the ring shows the same number of seconds for everyone.

> **Testing tip:** in your first test, measure how many of the 10 seconds mobile players use. If on average less than 2 seconds are left over, go to 11 s. Adjust the number once, not every week.

### 3.4 The Chain Call: counting down without voice

This is the most important invention in the plan. Without voice, a crew has to agree on *who does what and when*. The Chain Call does that with two taps.

1. A player aims at a chain point and **holds the ping button for 0.5 s** → "CHAIN CALL".
2. A bar with three slots appears at the top of everyone's screen: **[EYES] [CLEAR] [OPEN]** and the icon of the chain point.
3. Each teammate gets a big **"I'M IN"** button for 6 seconds. If you tap it, your gadget automatically fills the right slot: whoever has the Drone goes into EYES, and so on.
4. When all three slots are filled (or the caller taps **"GO"**), a **3-2-1 countdown** with sound starts for everyone at the same time.
5. On **0** the window opens: an EMP or Noisemaker that was already aimed and ready goes off automatically. Whoever has a Crowbar sees their gadget button pulse green.
6. During the window all players see the shrinking ring (§3.3).

Important:
- A slot may also be filled by **a thing instead of a person**: a Spy Cam watching the corridor counts as EYES, and a Noisemaker with a timer as CLEAR. That way the Chain Call also works with 1 or 2 players.
- Empty slot = the "GO" button turns orange with "MISSING: OPEN". You may still go; the game only warns you.
- The Chain Call can only be started by one player at a time, and has a 5 s cooldown (so nobody spams the crew).

### 3.5 The ping system

**Why this is needed.** On Roblox, voice chat is only for players aged 13 and up with an age check. Since January 2026, everyone who wants to **text chat** must also do an age check first, and then you only chat with players from your own or an adjacent age group (§5.4). So in a van with strangers, often nobody can talk or type to each other. Everything needed to win has to work **without a single typed word**.

**The Roblox rules for preset messages** (the "Preset system guidelines" page, ⚠️ check before the release):
- Systems that only pass on **actions, confirmations or simple reactions** may be used by everyone, including players without an age check.
- Preset **text** messages (such as "Follow me") are allowed if they are about the game. But: at most **12** per game, at most **one message per 10 seconds** per player, they must go through the Roblox filter (`TextService:FilterStringAsync`), they get the "system preset" label when they appear in the chat, and they contain **no punctuation at the end** (so "NOW", not "NOW!"). Questions, greetings and combinations that together form a secret message are not allowed.
- Whether pings without text (an icon in the world) fall under those text rules, the page does not say clearly. Ask on the Roblox DevForum before you build.

**That is why the timing is *not* in messages**, but in the game itself. The Chain Call (§3.4) is a game mechanic: a shared countdown that the game starts. Even if Roblox limits the quick messages below to 1 per 10 s, the chain keeps working.

**A. The smart ping ("SPOT")** — one tap on the ping button places an **icon in the world** on whatever is in the centre of your screen. The game chooses which icon itself:

| What you aim at | What the crew sees | How long |
|---|---|---|
| Guard | Red guard icon that walks along with him | 5 s, extended as long as the Drone or a camera sees him |
| Camera | Camera icon + its view cone on the floor | 5 s |
| Dog | Paw print icon that walks along | 5 s |
| Door, cupboard, gate, hatch | Lock icon | 10 s |
| Loot | Bag icon | 10 s |
| Floor or wall | Pin with arrow | 8 s |
| Caught teammate | Wristband icon above their chair | until they are rescued |

These are markers of things in the game, not sentences. At most 3 per 2 seconds per player.

**B. The quick wheel** — holding the ping button opens a wheel with **8 preset quick messages** (well under the limit of 12), each with an icon:

"NOW" · "WAIT" · "GO" · "BACK OFF" · "HELP" · "NEED EYES" · "NEED CLEAR" · "NEED OPEN"

- They appear as an icon above the head of whoever sends them, and at the top of the crew's screen. Not in the normal chat, so they are clearly different from free chat.
- "NOW" and "WAIT" are the most important. They get their own small button on mobile and their own key on PC and controller.
- Design them so they also work if Roblox imposes one message per 10 s per player. The fast timing runs through the Chain Call.

**C. Automatic messages** (the game itself, not a player):
- The Drone automatically marks every guard it has in view for 0.5 s.
- "CAMERA REBOOTING 3…2…1" when an EMP window runs out.
- "SIGNAL HIGH" when Asset Recovery gets closer (later, §9).
- "[name] GOT CAUGHT" with an arrow to the security room.

**D. Readability and abuse**
- Each player has a fixed colour, and each ping also has a shape, so colour-blind players can tell them apart.
- Each kind of ping has its own sound, so you hear it without looking.
- Each player can mute another player's pings.
- Players who *do* have voice or text chat may simply use it. Pings remain necessary, because strangers often do not share a common language.

### 3.6 Controls per device

**Mobile (designed first):**

```
┌──────────────────────────────────────────────────────────────┐
│ [Alarm ●○○○]   [ EYES ✓ | CLEAR … | OPEN ✓ ]   [Signal ▮▮▯] │
│                    ( CAMS OFF 8 )                            │
│                                                              │
│                          ·   ← aim point                     │
│                                                              │
│                                          [NOW]  [WAIT]       │
│  ( joystick )                       [PING]       (GADGET 1)  │
│                                [CROUCH]  (USE)   (GADGET 2)  │
└──────────────────────────────────────────────────────────────┘
```

- Bottom left the standard Roblox joystick. On the right, your thumb: GADGET (big, at least 64 px), USE (big: doors, picking up loot, rescuing a teammate), CROUCH, PING, NOW/WAIT (small, 48 px).
- **One button per gadget.** Tap = aim (an arc or radius appears from the aim point); tap again = throw or use; swipe off the button = cancel. No action requires you to hold a button for longer than 3 s.
- With 2 or 3 gadget slots (with 1–3 players, §3.7) there are two or three gadget buttons. Never more than three.
- Jumping is possible with the standard jump button, but it is smaller and higher up: in a stealth game you climb with USE ("vault"). Roblox players do expect to be able to jump, so do not remove it.
- You turn the camera by swiping one finger over the right half (Roblox default).

**PC:** WASD to walk, mouse to look, **E** = USE, **C** = CROUCH, **1/2** = choose gadget, **left mouse button** = use gadget (hold = aim, release = throw), **Q** = ping (hold = wheel), **Z** = "NOW", **X** = "WAIT".

**Controller (Xbox/PlayStation):** left stick to walk, right stick to look, **R2** = use gadget, **L2** = aim, **X/□** = USE, **B/○** = CROUCH, **A/✕** = jump, **R1** = ping (hold = wheel), **L1** = switch gadget, **D-pad up** = "NOW", **D-pad down** = "WAIT", **D-pad left/right** = "NEED EYES"/"HELP".

> Roblox can see which input device a player uses (touch, keyboard or controller), and you show the right buttons accordingly. Design the screen for the smallest phone and test with the **Device Simulator** in Studio (*a feature that shows your game as it would appear on a particular phone or tablet, including touch*). Note: Roblox's default controls take up the bottom-left corner (joystick) and the bottom-right corner (jump button). Place your own buttons in an arc *above* and to the left of the jump button, not below it.

### 3.7 With 1, 2, 3 or 4 players

| Crew | Gadget slots per player | Guards (map 1) | Window (Normal) | What is different |
|---|---|---|---|---|
| 1 (solo) | 3 (one per step) | 3 | 12 s | **Solo Kit**: Noisemaker and EMP get a timer (0–8 s), Spy Cams mark automatically. You are your own crew: you set up the chain and start it with one countdown. Solo gets 2 s extra on every difficulty. |
| 2 | 2 | 4 | 10 s | Spy Cams mark automatically. Each fills two steps; the Chain Call counts timers too. |
| 3 | 2 | 5 | 10 s | All six gadgets in use. |
| 4 | 1 | 6 | 10 s | Two gadgets stay in the van: you can go back during the run to swap. +15% crew bonus (§7). |

**Why this does not break the chain:** the three steps each require something you cannot do at the same time. Whoever flies the Drone or watches camera footage stands still. Whoever uses the Crowbar has to stand at the door. So a player with two gadgets can never see and open at the same time. They have to set up their second step with a timer, or work together.

**Players who leave or join** (with strangers that happens constantly):
- If someone leaves, their gadget drops on the floor (anyone can pick it up) and the remaining players automatically get an extra gadget slot. The number of guards stays the same; the window goes up by 1 s.
- In the first 3 minutes of a run, new players can **join at the van** through matchmaking ("Backup arrived!"). After that no longer, because that would disrupt the plan.
- A player who sets off the alarm on purpose cannot ruin the game completely: the alarm rises in steps (§9.5), and the crew can remove them from the run with a vote (majority: 2 out of 3 or 3 out of 4).

---

## 4. The six gadgets on Roblox

**Agreements for all gadgets**
- You carry each gadget in a slot. Switching slots: 0.5 s.
- Carrying big loot = your gadget button becomes "DROP" (drop it, 0.3 s). You walk 25% slower.
- Each gadget has a fixed number of **charges per run**. That number is shown as dots on the button.
- All numbers below are starting values for the first playtest. Adjust them based on what you see, not on gut feeling.
- The effects are calculated on the **server**; the client only asks "I want to throw the EMP at point X". That way nobody can cheat by modifying their own device.

---

### 4.1 Drone — "Drone" (see)

The Drone hangs on a thin LAN cable. That explains why the pilot has to stand still and why the range is limited.

| | |
|---|---|
| **PC** | **1** to choose → **left mouse button** to launch. WASD to fly, mouse to look, **space/Ctrl** up/down, **left mouse button** = SPOT, **F** = recall. |
| **Mobile** | Tap DRONE → the view jumps to the drone. Joystick = fly, swipe = look, ▲/▼ buttons = altitude, big "SPOT" button, "BACK" button. |
| **Controller** | **R2** to launch, sticks to fly and look, **R1/L1** altitude, **X/□** = SPOT, **B/○** = back. |
| **In the chain** | EYES. Sees guards, cameras and the dog, marks them automatically after 0.5 s for the whole crew, and creates chain cards (§3.2). |
| **Numbers** | Range 45 studs around your body. Battery 40 s of flying, then 20 s of charging. 1 drone per run. Fills the Signal meter (+1 per second). |
| **How it fails** | (1) Your body stands still crouched and sees nothing: a guard can simply pick you up. (2) An EMP within 14 studs: the drone drops out of the air for 10 s with a "BZZT" and a pitiful beep. If it lands on a guard, you see stars around his head and that guard becomes "Alert". (3) Lower than 5 studs near the dog: the dog grabs it and puts it in its basket. You can get it back from there. (4) A guard who sees the drone for 1.5 s: "What's that?" and he comes to look. |

### 4.2 Spy Cams — "Spy Cams" (see)

| | |
|---|---|
| **PC** | **2** to choose → **left mouse button** to stick on a wall or ceiling (green silhouette = allowed). **V** = view footage, **Q/E** = next camera. |
| **Mobile** | Tap CAMS = stick at the aim point. Hold CAMS for 0.5 s = view footage, with arrows to switch and a SPOT button. |
| **Controller** | **R2** to stick, hold **L2** = view footage, **L1/R1** to switch. |
| **In the chain** | EYES, but at a fixed spot. Whoever watches stands still. With 1–2 players the cameras also mark guards automatically when nobody is watching (3 s). |
| **Numbers** | 2 cameras per player carrying them. Sticking range: 6 studs. Each active camera fills the Signal meter (+0.25/s). In the camera view you switch a camera off and on (to spare the meter). |
| **How it fails** | (1) A guard who looks straight at the camera for 2 s within 8 studs removes it (+20 alarm points); you have lost it for that run. (2) An EMP turns them to static for 10 s, your own cameras too. (3) Too many active cameras draw Asset Recovery. |

### 4.3 Noisemaker — "Noisemaker" (clear: people)

This is the distraction kit: a wind-up alarm clock that rings.

| | |
|---|---|
| **PC** | Hold **left mouse button** = throwing arc, release = throw. Scroll wheel = set timer (0, 3, 5 or 8 s). |
| **Mobile** | Tap = throwing arc from the aim point, tap "THROW" = throw. Small "+3s" button next to the gadget button = timer. |
| **Controller** | **L2** to aim, **R2** to throw, **D-pad left/right** = timer. |
| **In the chain** | CLEAR (people and the dog). Guards within 20 studs who hear it walk towards it and search for 10 s (Rookie 12 s, Pro 8 s). |
| **Numbers** | 3 per run. Rings for 6 s. After use you can pick it up again if you can reach it. |
| **How it fails** | (1) Thrown too close to yourself: the guard comes towards *you*. (2) Twice in the same spot within 30 s: "Again?!" — the guard becomes Suspicious and looks the other way (+15 alarm points). (3) Does not work on cameras. (4) Karel picks it up and puts it in his pocket (§9.6). |

### 4.4 EMP — "EMP" (clear: electronics)

| | |
|---|---|
| **PC** | Hold **left mouse button** = aim, with the radius as a blue circle on the ground. Everything that will be hit lights up — **including your crew's drone and cameras**, with a red warning icon "YOUR DRONE!". Release = throw. |
| **Mobile** | Tap = aim (circle visible), tap "THROW" = throw. |
| **Controller** | **L2** to aim, **R2** to throw. |
| **In the chain** | CLEAR (cameras, lamps, alarm sensors). Everything within 14 studs is down for 10 s. Electronic locks stay shut: the EMP never opens a path by itself. |
| **Numbers** | 2 per run, 30 s cooldown. The light in the radius goes out too; dark = guards see you at half the distance. The EMP fills the Signal meter by +15 in one go. |
| **How it fails** | (1) **Your own drone and cameras in the radius go down** (comedy, but also real: your crew is blind for 10 s). (2) "BZZT" is audible within 10 studs: a guard nearby becomes Suspicious. (3) After 10 s the cameras reboot and first look at the spot where they were pointing. |

### 4.5 Crowbar — "Crowbar" (open)

| | |
|---|---|
| **PC** | At a door, cupboard or hatch: hold **left mouse button**. |
| **Mobile** | The gadget button shows the crowbar as soon as you stand next to something that can be opened. Hold it. |
| **Controller** | Hold **R2**. |
| **In the chain** | OPEN. Doors, cupboards and hatches: 1.5 s. Gates and cages: 3 s. At the end there is a loud "CRACK!" (25 studs). |
| **Numbers** | Unlimited use. If you let go too early, the progress is kept for 3 s. |
| **How it fails** | (1) If a guard hears the CRACK, he comes to look (+20 alarm points), unless he has just been distracted. (2) Each use leaves a **pry mark** on the door (§5.3). (3) Whoever carries the Crowbar cannot see or distract: they have to trust the crew. |

### 4.6 Winch — "Winch" (open: routes and loot)

The winch shoots a cable between you and an anchor point.

| | |
|---|---|
| **PC** | **Left mouse button** on an anchor point (valid points light up: roof edge, window, van). **E** at the cable = hang loot on it or slide along yourself. |
| **Mobile** | Tap WINCH → valid anchor points light up → tap an anchor point. USE at the cable = hang loot on it or slide along. |
| **Controller** | **R2** on an anchor point, **X/□** at the cable. |
| **In the chain** | OPEN: a route over a wall, gate or water. Plus transport: big loot slides to the other end in 4 s (the Golden Gouda in 8 s), without anyone carrying it. |
| **Numbers** | 2 cables per run, each staying up for 45 s. Range 40 studs. Sliding along takes 3–5 s; meanwhile you can do nothing else. |
| **How it fails** | (1) A guard who sees the cable follows it (+30 alarm points). (2) Sliding loot makes a "zzzip" (10 studs). (3) The cable has to hang free: a tree or awning in between = no cable. |

---

### 4.7 Extra gadgets: sideways, not stronger

You buy extra gadgets with in-game money (Cash). They solve the same step, but with a different advantage and disadvantage. They are never simply "better".

| Extra gadget | Step | What it does differently | The drawback | Price |
|---|---|---|---|---|
| **"Periscope"** | EYES | Analogue: looks under doors and around corners. Immune to EMP, does not fill the Signal meter, the dog ignores it. | Range only 12 studs, and you have to stand at the door yourself. It can only mark what is close by. | 800 Cash |
| **"Fake Delivery"** | CLEAR | Calls in a fake delivery: after 8 s the doorbell rings and the nearest guard walks to the front door for 14 s. No noise in the building, so no suspicion. | 1× per run, only at a doorbell, and you do not choose which guard goes. After alarm step 1 it no longer works ("Not now!"). | 1,000 Cash |
| **"Lockpick Set"** | OPEN | Silent: no CRACK and no pry mark. | Takes 6 s instead of 1.5 s, so it barely fits in a 10 s window. Does not work on gates and cages. | 900 Cash |

**Why this works for new players:** whoever is just starting has the default gadget for the same step. That is just as useful, only different. A crew without a single extra gadget can finish every map.


### 4.8 Funny weapons — "Prank Arsenal" (added 15/10/2026)

Maurits chose weapons, "but worked in nicely and funny". This is how that fits into the chain without turning it into a shooter:

**The rule: a prank buys time, not a solution.**
- Each weapon is a **CLEAR** gadget that opens a window on **one guard** (Normal 8–10 s). Never lethal, never permanent.
- Afterwards the guard comes **back angrier**: he goes straight to Search (§9.1) and **+10 alarm points** are added. Whoever only shoots ends up in LOCKDOWN.
- **Little ammo** (1–3 per run), and every weapon is **visible or audible**. Sneaking stays better.
- It **also hits your own crew** (like the EMP): a teammate in a soap bubble floats around for 3 s. Harmless, and exactly the kind of joke friends laugh about.
- **Not on Karel** ("Karel has seen worse") and **not on the dog** (you lure that one with a Dog Treat). Guards themselves use **no** weapons.

| Weapon (player-facing name) | What it does (window) | The funny drawback | How you get it |
|---|---|---|---|
| **"Bubble Blaster"** | Shoots a soap bubble: the guard floats around trapped for 8 s and cannot see or shout. | The bubble has to hit (travel time), and pops early if it bumps into a wall or player. | **Default** (the 7th gadget, also in the tutorial) |
| **"Fondue Cannon"** | A puddle of sticky cheese: the guard is stuck for 10 s. | He **can still see and shout**: without EYES you walk right into him (+40 if he sees you). | Extra, 900 Cash |
| **"Tickle Ray"** | The guard is doubled over with laughter for 6 s. | The laughing is **loud**: other guards within 20 studs come to look. | Extra, 1,000 Cash |
| **"Klomp Boomerang"** | A wooden clog: *bonk*, 5 s of stars. Comes back to your hand. | If you do not catch it, a clog lies on the floor: a **trace** (§5.3). | Extra, 800 Cash |
| **"Confetti Popper"** | Blinds a guard **or camera** with confetti for 8 s. | The confetti stays on the floor: a trace, and Karel comes to clean it up *and* snitch. | Extra, 700 Cash |
| **"Rubber Chicken"** | Up close: *SQUEAK*, the guard is dizzy for 4 s. | Super loud sound (25 studs): +20 if anyone hears it. But free to reload. | Extra, 500 Cash |

**Controls** (like Noisemaker and EMP, §3.6): aim and shoot with the gadget button. On mobile you tap GADGET (aim) and THROW (fire); the radius or arc is visible.

**Cosmetics for Robux** (§8): looks only, for example rainbow bubbles, a golden rubber chicken or a clog with tulips. Never a stronger weapon or extra ammo.

**Build order:** the Bubble Blaster is already in the phase 1 prototype (so you can test it right away). The extra weapons follow with the first release and the updates. When testing, check that players still sneak instead of only shooting; if not: less ammo or more alarm points.

---

## 5. Violence, blood and age rating

*(An **age rating** — on Roblox the "content maturity label" — tells players and parents how intense your game is; you get it by filling in the **Maturity & Compliance Questionnaire**, a questionnaire in the Creator Hub about violence, blood, fear, humour and gambling. A game without a label is not normally playable for anyone.)*

### 5.1 The advice in short

**Aim for the Mild label. No blood. Funny weapons and slapstick, never real violence.**

- **Minimal and Mild both reach the youngest groups**: Roblox Kids (ages 5–8) and Roblox Select (ages 9–15), after the review from §5.5. Moderate no longer reaches Kids.
- A stealth game is suspenseful by nature (Roblox literally calls "suspense-building gameplay" **mild fear**), and the funny weapons are **repeated mild, unrealistic violence** (briefly disabling a guard with a bubble or cheese). Together that gives **Mild**. That is not a problem: Mild still reaches Kids (5–8) and Select (9–15).
- **Blood would even be allowed**: Minimal permits "light unrealistic blood" (rare, unrealistic in colour or shape). Even so, I recommend **no blood**. A burglary game with blood quickly feels "wrong" to parents, even if it fits the rules, and it adds nothing that a small tear in your vest cannot tell just as well. That way you never have to hesitate when filling in the questionnaire either.

### 5.2 What the labels say (as of 15/10/2026)

| Label | Violence | Blood | Who may play (default) |
|---|---|---|---|
| **Minimal** | Occasional mild violence | Little unrealistic blood | Kids (5–8), Select (9–15), 16+ |
| **Mild** | Repeated mild violence | Lots of unrealistic blood | Kids, Select, 16+ |
| **Moderate** | Moderate, realistic-looking violence | Little realistic blood | Select (9+), 16+ |
| **Restricted** | Strong violence | Lots of realistic blood | Only 18+ with ID |

- For Roblox, "mild violence" means implied or unrealistic, for example a body that disappears at zero health.
- Be careful with set dressing: an **unplayable casino or card game** as a target makes your game **Moderate** under the rules ("unplayable gambling content"). So do not pick a casino for later maps.
- Theft or burglary as a theme has no category of its own in the questionnaire. Roblox's Community Standards do forbid re-enacting **real** crimes or events. Fictional burglaries in a fictional town do not fall under that. ⚠️ I found no rule that forbids a cartoon burglary game for children, but no explicit permission either. Read the questionnaire's questions yourself before phase 3.

**What violence does look like, then**

**Violence as a consequence (slapstick, nobody gets hurt):**
- Your drone, hit by an EMP, falls on a guard's head: little stars, and the guard is Alert (so it is bad for you).
- A guard floats for 8 s in a bubble from the Bubble Blaster, or is stuck in cheese fondue (§4.8). Afterwards he comes back angrier.
- A guard chasing you bumps into a door that just slammed shut and stands there dazed for a moment.
- A caught player gets plastic zip-tie cuffs and is taken to the security room with a transition effect.

**What never goes in:** real or realistic weapons (no pistols, no knives, no tranquilliser darts), weapons used by guards, players hitting or pushing, a dog that bites, police using force, blood, real brands or real places.

### 5.3 How the traces work (without blood)

Traces are **information for the opponent**. You leave them behind by being sloppy, not through violence.

| Trace | How you leave it | How long visible | Who finds it |
|---|---|---|---|
| **Muddy footprints** | Walking through the mud puddle in the courtyard. You leave 12 footprints behind. | 90 s | Guard, Karel |
| **Pry marks** | Every Crowbar action on a door, cabinet or cage | Whole run | Guard, Karel |
| **Open door or cabinet** | Leaving something open that should be closed | Until someone closes it | Guard, Karel (closes it and reports it) |
| **Torn work vest** | Climbing over the barbed-wire fence. A little orange scrap of fabric stays behind. This replaces "blood as a trace": it tells the same story ("someone came through here"). | Whole run | Guard |
| **Empty shelf** | Taking loot. The empty spot lights up for guards who look straight at it. | Whole run | Guard |

- **Trace found** = the guard becomes Suspicious, adds +20 alarm points and follows the trace (with footprints, in the direction of the steps).
- **Erasing traces:** the **"Clean Spray"** erases one trace in 1 s (a line of footprints counts as one trace). You get 2 free per run; extras cost 60 Cash, never Robux. Closing a door is free (0.5 s).
- **Prevention beats erasing:** walk around the mud puddle, use the Lockpick instead of the Crowbar, the Winch instead of going over the barbed wire.
- **At the end of the run** the payout screen shows a little map with all the traces you left behind ("Your trail"), and whether anyone found them. That way players learn the system without an explanation up front.
- **The Clean Job bonus** (+20%) is yours if nobody found a single trace.

### 5.4 Chat, voice and age: why pings are needed

| What | Rule (as of 15/10/2026) |
|---|---|
| **Voice chat** | Only from age 13, with age verification, in a limited number of countries. **Nobody under 13 has voice.** |
| **Text chat** | Since 7 January 2026, worldwide only after an **age check** (facial age estimation via the camera, or ID from age 13). In the Netherlands already since December 2025. Anyone who has not done a check can play but not chat. |
| **Who you chat with** | Six age groups: under 9, 9–12, 13–15, 16–17, 18–20, 21+. You only chat with your own group and the groups directly next to it. Messages to someone outside those groups simply do not appear. |
| **Under 9** | Chat is off by default; a parent has to give permission. |
| **Quick Words** | A built-in Roblox system with preset messages for **playing together** ("gameplay coordination"). Players of all ages can send them to each other (parents can turn it off). You set up to 3 categories yourself, each with 3–10 words of fewer than 25 characters, in English; Roblox approves them and translates them automatically. They appear in the chat window. |

**What this means for the design:**
1. In a van with strangers aged 10, 14 and 25, often nobody can talk or type to everyone. The game must be fully playable with **icon pings, the Chain Call and automatic markers** (§3.4–3.5).
2. **Also set up Quick Words** (Creator Hub → your game → Configure → Chat → Quick Words), with the same words as your quick wheel, for example the category "Plan": *Wait*, *Go*, *Now*, *Follow me*, *Back off*, and the category "Need": *Need eyes*, *Need clear*, *Need open*, *Help*. It costs you 10 minutes, Roblox translates them for free, and players who use the chat window have them straight away.
3. Build **no free chat of your own**. All free text has to go through Roblox's own chat (*TextChatService*), with the age rules attached.

### 5.5 The extra review to reach 9–15-year-olds (Kids & Select)

This is the most important new Roblox rule for your plan. Since **16 June 2026**, players aged 5–8 have a "Roblox Kids" account and players aged 9–15 a "Roblox Select" account. **A new game is at first only playable for players aged 16+ with an age check.** Only after a review are Kids and Select added.

**What you need as a creator:**
1. An account in good standing, **ID verification** (from age 18 with an identity document) and **two-step verification** (*2FA: an extra code when logging in*).
2. The complete questionnaire, resulting in Minimal, Mild or Moderate.
3. **Either** 2 consecutive months of a Roblox Plus subscription (the paid subscription that replaced Premium), **or** a one-off deposit of **1,000 Robux per game** (confirmed in the Roblox announcement of 16/06/2026). You get the deposit back automatically 90 days after the game is approved (or 90 days after payment if it is never approved). You only lose it if Roblox permanently removes your game for a serious breach of the rules.

**Why that deposit?** Roblox itself gives no reason; it only calls it a requirement. My estimate: it is a threshold against throwaway accounts and bad creators. Anyone who wants to release a game for children has to put up something they can lose if they break the rules. Roblox does write that it "hopes to make the deposit smaller over time".

**What it costs you:**
- **The deposit** (recommended): 1,000 Robux, roughly 10 to 13 euros, depending on the Robux package and your country. You get it back, so in effect you lend Roblox that amount for a few months.
- **Roblox Plus**: 2 months at about 5 dollars a month. You do not get that back. According to the documentation, Roblox checks the subscription every time you publish or update the game for all ages. If it has expired by then, your game stays playable, but ⚠️ it is not entirely clear whether you have to pay again for a next update. Only take this route if you want Plus anyway.
- **When:** only in phase 3b (§12), so only once the game is finished and running for 16+. You do not have to pay anything now.
- **Without a deposit** you can still publish the game, but then it stays limited to players aged 16+.

**How the review works:**
1. **Trial period** with players aged 16+ with an age check.
2. Roblox checks whether the players are real, and assesses the moderation reports and the gameplay.
3. Threshold: **250 unique plays by "highly engaged" players in the last 60 days.** Those are players with an account that has existed for a long time, enough playtime in your game, and a purchase somewhere on Roblox in the last 60 days. You track this in the Creator Hub on the **Audience Reach** dashboard.
4. It can go faster with an "expedited review" for a refundable deposit of **50,000 Robux**. For a beginner that is not realistic.

**What this changes in the plan:**
- Your **first players are 16+**, not 9–15. So the game also has to appeal to teenagers and young adults: humour, a tight chain and a style that is "playful" but not "childish". Think of Among Us, which appeals to all ages.
- The release happens in **two steps** (§12, phase 3): first 16+ (trial), then Kids & Select.
- At launch you need **a group of older testers** who really play: friends, classmates, a Discord group, Roblox players aged 16+ whom you find through the DevForum or a community of your own. 250 real, engaged players in 60 days is achievable, but it does not happen by itself.
- Everything in §5.1–5.3 (no blood, slapstick, readable suspense) helps you get through the safety review smoothly.

---

## 6. Game loop and session

### 6.1 The places

*(An **experience** is your game on Roblox; it can consist of several **places**, separate worlds each with their own servers, between which you move players.)*

- **Place 1 — "The Depot"** (the lobby): a garage yard in the fictional town of **Polderdam** with parked vans, the "Gear Wall" (shop), the "Paint Shop" (appearance) and the "Practice Yard" (tutorial, §11).
- **Place 2 — the job** (the first map, §10). Every later map becomes a place of its own.

*(**TeleportService** is the Roblox service that moves players from one place to another; with a **reserved server** you create an empty, closed server just for your crew. Note: teleporting does not work in Studio, only in the published game. So test it with a privately published version.)*

### 6.2 The van as a queue

Roblox players know the "elevator" or "waiting pad" principle: whoever gets in leaves together. Use that:

- There are 4 vans in the Depot. **Getting in = joining that crew** (maximum 4).
- The first one to get in is the **crew leader**: they pick the job and the difficulty on a board in the van.
- The van leaves as soon as it is full, or **30 s after the leader taps "READY"**, and at the latest 45 s after the first player got in. It also leaves with fewer than 4 players.
- **"GO SOLO"**: a button that immediately gives you a van of your own.
- **"PRIVATE VAN"**: the leader closes the van to strangers and invites friends through the standard Roblox invite. That way you play with four friends **without having to buy a private server** (§8).
- **Roblox Party:** players can form a "party" of up to 6 friends in Roblox itself. If a party of 5 or 6 comes in, the game automatically puts them in two vans side by side, which leave at the same time (two crews, the same job).

*(A **private server** is a server of your game that only you and the people you invite can enter; players can buy one or get one, depending on what you set.)*

### 6.3 One session, minute by minute

| Phase | What happens | Time | Clock |
|---|---|---|---|
| Loading and Depot | You arrive in the Depot. A returning player walks straight to a van. | 0:30 | 0:00–0:30 |
| Forming a crew | Getting into a van, the leader picks the job. Waiting longer than 45 s = leaving with whoever is there. | 0:30–1:00 | until 1:30 |
| The drive (loading screen) | Teleport to the job. In the van: choose the **loadout** (who takes which gadget), look at the job card (loot, known cameras). The loadout bar shows whether all three steps are covered: "EYES ✓ CLEAR ✓ OPEN ✗ — No one can open doors!". | 1:00 | until 2:30 |
| Scouting ("Casing") | The van is parked outside. The drone and Spy Cams are allowed; guards react more slowly outside. A soft timer suggests: "Go in when ready". | ~2:00 | until 4:30 |
| Break-in | The three chain points (§10). This is where the game happens. | ~6:30 | until 11:00 |
| Loot and escape | Loot to the van (carried or via the Winch). Whoever gets into the van is safe. The van leaves as soon as everyone is in or the leader taps "DRIVE". | ~2:30 | until 13:30 |
| Payout | Loot, Cash, Rep, bonuses, and the **funny awards**: "Self-EMP Award" (whoever blinded their own crew most often), "Silent Hands" (not a single CRACK heard). | 0:45 | until 14:15 |
| Next | Big button **"SAME CREW, NEXT JOB"**: you go straight back to the drive, without a lobby. Or "BACK TO DEPOT". | — | — |

**So a run takes about 11 minutes (scouting to escape), a full cycle about 14 minutes.**

That is longer than an average Roblox session (half of the sessions per game last less than about 7 minutes, according to GameAnalytics). That is why there is **a reward every 2 to 3 minutes**: the first chain point around 4:30 ("First chain! +15 Rep"), the first loot in the van around 7:00, the main loot around 10:00. Anyone who has to stop after 7 minutes has already achieved something: what is in the van also counts if you leave early (half the value).

### 6.4 What keeps runs short

- **Shift change:** after 12:00 into the run, "SHIFT CHANGE IN 2:00" appears. After 14:00 two extra guards arrive. After 16:00 the alarm automatically goes to the top rung (§9.5). That way no run lasts longer than about 17 minutes.
- **Minimum loot to win:** the main loot (on map 1 the Golden Gouda) or loot worth 600 Cash. Whoever has the minimum loot gets an arrow to the van. That prevents endless searching.
- **Everyone caught = "BUSTED"**: the run ends immediately, with half the value of what was already in the van.

---

## 7. Stakes, progression and economy

### 7.1 Two kinds of progress

| | **Cash** (in-game money) | **Rep** (reputation, experience points) |
|---|---|---|
| How do you earn it? | Loot in the van + bonuses | Every run, even when you fail |
| What do you use it for? | Extra gadgets, consumables, part of the cosmetics | Levels that unlock new jobs, difficulties and shop items |
| Can you lose it? | Not the Cash itself; what you bought with it sometimes (gadgets) | Never |
| For sale with Robux? | **No** | **No** |

*(**Robux** is Roblox's virtual currency, which players buy with real money.)*

### 7.2 What you earn

**Your share = 25% of the value of the loot in the van**, regardless of how big your crew is. So a solo player who brings in all the loot earns as much as each member of a crew of four. That is fair, and there is no reason to vote someone out to get more.

| Bonus | Condition | Value |
|---|---|---|
| "Quiet Job" | Alarm never above rung 1 | +30% |
| "Clean Job" | Not a single trace found by guards or Karel | +20% |
| "No One Left Behind" | Everyone in the van at the end | +10% |
| Crew bonus | Per extra crew member | +5% (max +15%) |
| First job of the day | Once a day | ×2 |

**On map 1** all the loot together is worth 2,200 Cash (§10.3). So a good run yields about **400–700 Cash** per player, a perfect run with all bonuses about 950.

**Rep:** 100 per run (50 on failure), +15 per solved chain point, +25 per rescued teammate; on average about 160 per run. To go from level n to n+1 you need 150 × n Rep, so you reach level 10 after about 6,750 Rep: some 42 runs, or 10 hours of play.

| Level | What unlocks |
|---|---|
| 1 | All 6 standard gadgets, map 1 on Rookie and Normal |
| 2 | The Gear Wall (buy your first extra gadget) |
| 4 | "Night Shift" (map 1 with different guard routes) |
| 6 | Pro difficulty |
| 8 | "Rush Job" (8 s window, bonus ×1.5) |
| 10+ | Cosmetics for Cash, badges; new maps with updates |

### 7.3 What you can lose: the stake

| What | Caught and **rescued** | Caught and **not rescued** at the end of the run |
|---|---|---|
| Standard gadget | You get it back from the evidence locker | Gone for the rest of that run; back as normal next run |
| Extra gadget (bought with Cash) | You get it back from the evidence locker | **Permanently gone** ("Confiscated") |
| Everything bought with Robux (skins, outfits) | Never lost | **Never lost** — a skin belongs to your account, not to the gadget |
| Your share of the loot | In full | Half ("Busted") |

**Why this is fair for children:** because extra gadgets are sidegrades, a loss **never makes you weaker**, only less varied: you fall back on the standard gadget, which is just as strong. And an extra gadget costs about 2 good runs, not an evening of grinding.

**Why this creates tension:** whoever brings a bought gadget has something to lose. So rescuing a teammate really is "getting their expensive gadget back", as the concept intends.

**Clarity before the run:** in the van, an extra gadget has a yellow border and the text "At risk if caught". Nobody should be caught by surprise.

### 7.4 A new player is useful straight away

- All six standard gadgets are available from level 1 and are as strong as the extra gadgets.
- **Everyone can carry loot and ping.** Even someone who has lost their gadget is useful: as a carrier, or as "eyes" by looking around themselves.
- Whoever is caught watches along through the building's cameras (§9.2), so nobody sits doing nothing for 5 minutes.
- Matchmaking prefers to put level 1–3 players in a van on Rookie.

### 7.5 Where the money goes again (so Cash keeps its value)

- Buying lost extra gadgets again (800–1,000 Cash).
- Consumables: "Clean Spray" (erasing traces, 60 Cash; 2 free per run), "Dog Treat" (keeping the dog busy for 15 s, 40 Cash).
- Cosmetics for Cash: van colours (1,500–5,000), stickers (300), payout dances (2,000). That way someone who plays a lot always has something to save up for, without Robux.

---

## 8. Monetisation

*(A **game pass** is a one-off purchase with Robux that a player keeps forever, for example "all drone skins". A **developer product** is a purchase you can make as often as you like; if it gives something permanent, such as one skin, you store in your DataStore that the player owns it.)*

### 8.1 The ground rules you set yourself

1. **With Robux you only sell appearance and convenience.** Never anything that makes you stronger or skips a step of the chain.
2. **What is bought with Robux, you never lose.** A drone skin belongs to your account, not to a gadget. If you are caught with a "skinned" drone, you lose at most the gadget (if it was a bought extra gadget), never the skin.
3. **In-game money (Cash) is never for sale with Robux**, not even through a 2× Cash pass. Otherwise real money indirectly buys gadgets you can lose (see contradiction 4 in §2).
4. **Playing together with friends never costs anything.** The "Private Van" is free, and so are private servers.
5. **No random paid items** (loot boxes). Chance is only allowed in **free** rewards, such as the Glovebox (§8.7). See also §8.10.
6. **Everything you buy, you see in advance.** No surprises for money, no "last chance" pressure.

### 8.2 How Roblox pays you (as of 15/10/2026)

- Of every Robux a player spends in your game, you get **70%**.
- Converting Robux into real money is called **DevEx** (*Developer Exchange: the Roblox programme that pays out earned Robux in dollars*). The rate is **US$ 0.0038 per Robux**. You must be at least 13 years old and have at least **30,000 earned Robux**.
- **Worked example:** a game pass of 199 Robux → you get 139 Robux → about US$ 0.53. If you sell it 1,000 times, you have 139,300 Robux ≈ US$ 530.
- **Premium Payouts no longer exist.** In July 2025 Roblox replaced them with **Creator Rewards**: you get a small reward per day for active, paying players who play your game among their first games of the day. On top of that you get something when someone takes out a Roblox Plus subscription through your game. ⚠️ These schemes change often; check the "Creator Rewards" page in the Roblox documentation.
- **Regional pricing** is on by default for game passes: Roblox lowers your price in poorer countries (down to 30% of your price). Leave it on; it helps children with few Robux.

**Honest expectation:** a beginner's first game rarely earns much. The goal of this monetisation at release is: to give players who like the game a fair way to support you, and to cover the costs. Not: to squeeze as many Robux as possible out of children.

### 8.3 Game passes (one-off, forever)

| Name in the game | What you get | Price |
|---|---|---|
| **"Crew Wardrobe"** | 8 work outfit styles (vests, caps, overalls) that go over your own avatar, plus a colour picker | 199 Robux |
| **"Drone Garage"** | 6 drone skins (including cheese wheel, duck, disco ball) plus light trail colours | 199 Robux |
| **"Paint Shop"** | Paint your van yourself: colours, rims, stickers, a horn of your own | 249 Robux |
| **"Loadout Presets"** | Save 5 fixed loadouts; in the van you pick your gadget with one tap | 99 Robux |
| **"Supporter Pack"** | A golden name tag in the Depot, a unique horn, your name in the credits | 299 Robux |

### 8.4 Developer products (sold separately)

| What | Price | Note |
|---|---|---|
| Single drone skin | 49–99 Robux | Permanent; stored in your DataStore |
| Single van wrap | 99–199 Robux | Permanent; everyone in the crew sees it |
| Single outfit | 79–149 Robux | Permanent |
| Payout dance (emote on the end screen) | 49 Robux | Permanent |
| **"Crew Fireworks"** | 25 Robux | One-off fireworks above the van for the whole crew after a successful run. Social and harmless. |

### 8.5 The Crew Pass (season pass) — your strongest revenue engine

*(A season pass — "battle pass" — is a list of rewards you unlock by playing; part is free, part only with the paid pass. There is no chance involved: you see in advance exactly what you get.)*

| Part | Agreement |
|---|---|
| Duration | A season of **8 weeks**, with its own theme. S1 "Cheese Season" (The Golden Wheel), S2 "Tulip Night", S3 "Canal Lights" … |
| Tiers | **30 tiers of 600 Crew XP** (18,000 in total). You earn Crew XP with every run (±150 per successful run, 60 on failure) and with 3 weekly challenges of 500 XP ("Bubble 3 guards", "Finish a Quiet Job", "Free a teammate"). With ±6 runs per week plus the challenges, the pass is full in 8 weeks: about 1.5 hours of play per week, achievable for someone who plays regularly. |
| Free track | **10 rewards** (every 3rd tier): Cash, Clean Sprays, 3 cosmetics and a season badge. Even someone who pays nothing has a reason to play. |
| Paid track | **399 Robux** for **all 30 rewards**, appearance only: 4 drone skins, 3 van wraps, 3 outfits, 2 Bubble Blaster skins, emotes, a name title ("Golden Wheel Veteran") and a final reward (for example an animated golden van wrap). |
| Buying late | Whoever buys halfway through **immediately gets all tiers already reached**. Nobody loses anything by deciding later. |
| What not | No skipping tiers for Robux, no weapons or gadgets in the pass, no "2 hours left" notifications. Rewards stay yours forever. |
| When | **Season 1 starts ±2 months after release**, once players are coming back. First there has to be enough to do: at least 2 jobs or 3 variants. |

### 8.6 Shop with rotating offers and bundles

- **"Van Shop"** (the shop in the Depot): **4 items** every day and **2 featured bundles** every week.
- **Single items 49–249 Robux** (drone skins, wraps, outfits, weapon skins, emotes). A few items per day cost only **Cash**, so that those who do not pay also have something to choose.
- **Bundles 349–499 Robux**: a set in one style (van + outfit + drone + Bubble Blaster skin), about 30% cheaper than separately. Examples: "Cheese Crew Bundle", "Night Shift Bundle", "Tulip Bundle".
- **Fair rules:** there is only a small label "Refreshes in 14 h", no countdown with flashing buttons. **Every item comes back later**, so there is no "now or never".
- *(A **bundle** is a set of several items for one price; technically a developer product that adds several skins to your account at once.)*

### 8.7 The Glovebox: excitement without gambling

The exciting feeling of a loot box, but **free and earned**. That means it is not gambling and is allowed everywhere, including in Belgium and the Netherlands.

- After every **successful run** you open the **van's glovebox** with a short animation: the little lid pops open with a *clunk*.
- What is inside is random, and the odds are always visible next to the glovebox:

| Contents | Chance |
|---|---|
| 50–200 Cash | 70% |
| 1 Clean Spray or Dog Treat | 15% |
| Common cosmetic (sticker, ping frame, colour variant) | 12% |
| Rare cosmetic (for example a shiny drone skin) | 3% |

- At most **3 Gloveboxes per day** with a cosmetic chance; after that they only contain Cash.
- **Golden rule, forever:** a Glovebox is **never** for sale, cannot be sped up with Robux, and Cash is never for sale with Robux. If one of those three changes, it becomes a paid random item. That is forbidden in Belgium and the Netherlands, and the questionnaire would have to be updated.

### 8.8 What it could bring in (rough estimate)

An honest worked example. The assumptions are **estimates**, not promises: a beginner's game does not reach these numbers by itself.

| Assumption | Value |
|---|---|
| Different players per 8-week season | 10,000 |
| Share that buys the Crew Pass | 3% → 300 × 399 Robux |
| Share that buys something in the shop | 2% → 200 × an average of 150 Robux |
| Game passes | 100 × an average of 200 Robux |

Together, players spend ±170,000 Robux. You get 70%, so ±119,000 Robux, and through DevEx that is **about US$ 450 per season** (±US$ 225 per month), plus small amounts from Creator Rewards. With 100,000 players per season that becomes about ten times as much. So you do not make the difference with loot boxes, but with **more players who come back**: that is why the first minute and the chain are central to this plan.


### 8.9 Private servers: free

- Roblox lets you choose: private servers for free or for a monthly price in Robux.
- **Advice: free.** Playing together with friends is the core of your game, and the "Private Van" already makes a private server unnecessary for the regular player. Free private servers are a reason for YouTubers and groups of friends to choose your game. Moreover, since June 2026 Roblox's recommendation algorithm counts "intentional co-play days": days on which someone comes back to play with friends (via an invite, joining in or a private server). Making it easy to play together therefore helps your visibility.
- Be aware: if you later set a price after all and then change it again, all running subscriptions lapse.

### 8.10 What you deliberately do *not* sell

| Do not sell | Why not |
|---|---|
| **Cash** (in-game money) for Robux | Real money would indirectly buy gadgets you can lose. And whoever pays buys their way past the progression. |
| **2× Cash / 2× Rep pass** | Entry Point (300 Robux) and Notoriety (499 Robux) do sell them. Here it clashes with rule 3 and feels like pay-to-win for young players. |
| **Gadgets or extra charges** for Robux | Pay-to-win, and it undermines the stake. |
| **"Get out of jail"** or reviving for Robux | That makes being rescued by your teammates, a core moment, worthless. |
| **Insurance** against loss | Buying that you lose nothing = buying off the stake. |
| **Paid maps or jobs** | Entry Point sells missions as game passes (750–1,200 Robux). With few players that splits your audience: whoever wants a paid map cannot find a crew. |
| **Random paid items** (loot boxes) | In Belgium, paid loot boxes have been banned since 2018 (the Gaming Commission sees them as gambling); in the Netherlands, Roblox games were blocked over them in 2022. Roblox switches them off there, so you and your friends would not even be able to buy them. Roblox also requires exact odds up front and a free route. Use the free Glovebox (§8.7) and the Crew Pass (§8.5) instead. Discussed and confirmed on 15/10/2026. |
| **Rewarded ads** ("watch an ad for Cash") | Roblox forbids rewards for getting players under 13 to watch ads. Your core audience is young; so skip ads entirely. |
| **Time-pressure offers** ("5 minutes left!") | Pressure on children. Bad for parents' trust. |

### 8.11 Technical care with purchases

- You process every developer product purchase with **ProcessReceipt** (*the Roblox function that confirms a purchase has arrived correctly*). Only once you have safely stored the purchase do you report "success" to Roblox. Otherwise a player pays for nothing.
- Keep bought items separate from regular progress.
- Test all purchases with **test purchases in Studio** (they cost no real Robux) before you publish.

---

## 9. Opponents and alarm ladder

*(An **NPC** is a character controlled by the computer; Roblox has **PathfindingService**, a built-in service that calculates a walking route around walls for an NPC.)*

### 9.1 Guards — "Guard"

Guards have four states, each with a clear icon above their head. Players must see at a glance what a guard is thinking.

| State | Icon | Behaviour | How he gets into it | How he gets out of it |
|---|---|---|---|---|
| **Patrol** | none | Walks a fixed route with 2–4 stops | Start | — |
| **Suspicious** | yellow "?" + meter | Walks to the spot where he saw or heard something, searches for 8 s | Half sees a player (meter fills in 1.5 s), hears CRACK/BZZT/Noisemaker, finds a trace | Nothing found → back to Patrol |
| **Alert** | red "!" | Runs to the player, calls on the radio (+40 alarm points) | Meter full, or drone falls on his head | Loses the player → Search |
| **Search** | orange "?!" | Searches for 15 s around the last spot, 20% faster | After Alert | After 15 s → Patrol |

- **Sight:** a 70° cone, 35 studs in the light, 18 studs in the dark. Crouching makes you get noticed 50% more slowly.
- **Cover (work clothes):** in public zones (street, shop) a guard does not react to you as long as you do nothing illegal. Illegal = carrying loot, using a gadget or breaking something open. In "Staff Only" zones the meter fills as normal.
- **Arrest:** a guard in Alert who comes within 3 studs catches you in 1 s ("CAUGHT"). You get plastic zip-tie cuffs (cartoon) and are taken to the security room with a transition effect.
- **No weapons.** Guards have a torch and a radio. They do not hit and do not push.

### 9.2 Caught: the security room

- You sit on a chair in the security room. Your gadget lies in the **evidence locker** in the same room.
- **You are not out of the game:** you see the footage from the building's security cameras (switch with arrows) and can place SPOT pings from that footage. You become your crew's "eyes".
- If an EMP hits those cameras, you see static too (another comedy moment).
- **Rescue:** a teammate holds USE for 2 s at your chair ("Cut zip-ties") and 1 s at the evidence locker ("Grab gear"). Then you are free and have your gadget back.
- The security room deliberately has no permanent guard, but a camera watches the door.

### 9.3 Cameras — "Camera"

- Sweep 90° back and forth in 6 s. The meter fills in 2 s (Rookie 3 s).
- A full meter = +40 alarm points and all guards are told the spot ("Camera spotted someone in Warehouse").
- An EMP switches them off for 10 s. After that they restart ("REBOOTING") and first look at the spot where they were pointing.
- A camera always has a **view cone you can see** when it is marked. Children should not have to guess.

### 9.4 The dog — "Boef"

- Only walks outside (on map 1, the courtyard).
- **Hunts the drone:** if the drone flies lower than 5 studs within 20 studs of the dog, he runs over. If the drone stays low for 2 s, he grabs it and puts it in his basket. You can get it back, but the basket is in view of a camera.
- **Barks at players** he sees within 10 studs. He does not bite and does not attack, but the guard who hears it becomes Suspicious and comes to look.
- Can be distracted with the Noisemaker (8 s) or a "Dog Treat" (15 s).

### 9.5 The alarm ladder

Everything that draws attention earns **alarm points**. The ladder only goes up, never down; over 12 minutes that is clearer than a meter that drops again.

| Event | Points |
|---|---|
| Camera fully sees you | +40 |
| Guard becomes Alert | +40 |
| Wrong answer when challenged (later, §9.7) | +40 |
| Guard sees a Winch cable | +30 |
| Guard or Karel finds a trace | +20 |
| Guard hears a CRACK | +20 |
| Spy Cam found | +20 |
| Noisemaker 2× in the same spot | +15 |

| Rung | Points | Player name | What changes |
|---|---|---|---|
| 0 | 0–99 | "QUIET" | Normal |
| 1 | 100–199 | "SUSPICIOUS" | Guards 10% faster, one guard checks traces. "Quiet Job" bonus still possible. |
| 2 | 200–299 | "SEARCHING" | Guards walk the main routes in pairs, cameras sweep 30% faster. "Quiet Job" bonus gone. **Windows stay 10 s**, because the rhythm has to stay reliable. |
| 3 | 300+ | "LOCKDOWN" | Big screen: "POLICE IN 90". Electronic doors to the main loot lock. Whoever is still inside after 90 s is caught. **No police officers arrive**: the police is a timer, not an opponent. |

On Rookie all points count for only half.

### 9.6 Karel — "Karel" (confirmed)

The summary only said that Karel "plays a role" in the traces. The chosen interpretation, because it makes the traces visible and funny in a game for children:

- **Karel is the caretaker.** He is not a guard and cannot catch you.
- He walks around and **tidies up**: he closes doors that are open, picks up Noisemakers and puts them in his pocket, and sweeps traces away.
- But every trace he finds, he **reports loudly** ("WHO LEFT THIS DOOR OPEN?!") and that gives +20 alarm points.
- An EMP does nothing to him. A Noisemaker neither: he pockets it. What *does* work is **mess**: knock over a planter somewhere, and Karel walks over for 12 s to tidy it up. That is how you learn to use him.
- His humour: a grumbling, exaggeratedly tidy man with a broom and a vest with 14 keys. A recognisable "Dutch" figure without stereotypes.
- On map 1 he only appears on Normal and higher (not on Rookie), so that new players do not have to learn too much at once.

### 9.7 Asset Recovery and cover (after the first release)

Both are good ideas, but they make the first version too heavy. They come in the first updates (§12).

**Asset Recovery — the Signal meter**
- The crew shares one **Signal meter** (antenna icon top left). Every active electronic gadget fills it: Drone +1/s, each Spy Cam +0.25/s, each EMP +15 in one go. Nothing on = −2/s.
- At 100: "ASSET RECOVERY INBOUND". 20 s later a **Recovery Agent** steps out of a grey van: a man in a grey suit with a big antenna on his back.
- He walks to the strongest active signal and **confiscates that gadget** (a bought one you lose, a standard gadget for that run). If he sees a player, he reports it to the guards (+40).
- If everything stays off for 20 s, he leaves. **Switching off means going blind**: exactly the choice from the concept.
- With constant use of the drone it takes about 90–100 s before he comes, so in a 12-minute run you see him once or twice.

**Cover — "Cover Story"**
- With this update the rule from §9.1 changes: in a "Staff Only" zone the meter no longer fills immediately as long as you wear work clothes and do nothing illegal. An NPC (guard or Karel) who sees you there for 2 s challenges you: "Hey! Who are you?".
- You get **3 icons** (for example 🔧 "Repairs", 📦 "Delivery", 🧹 "Cleaning") and 5 s to choose.
- The right answer is on the **work order** you can find during scouting: the drone sees a clipboard on the noticeboard ("TODAY: FRIDGE REPAIR").
- Right → "Ah, the fridge guy. Carry on." Wrong or too late → +40 alarm points and the NPC becomes Alert.
- Works everywhere without language: an icon, no text to read.

---

## 10. First map: "The Golden Wheel" (the cheese shop)

**Why a cheese shop:** cheese is recognised worldwide as Dutch, cartoon-friendly and funny. Big cheese wheels are perfect loot to carry (heavy, round, eye-catching). No real brand is attached to it. In the game the cheese shop is called "The Golden Wheel Cheese Shop", in the fictional town of Polderdam.

### 10.1 Floor plan in words

The site is about 120 × 80 studs. North is at the top.

```
                                    N
+----------------------- CANAL (water, houseboat) -----------------------+
| QUAY:   [VAN]   bikes   street lamp                                    |
+--------------------+-------------------+-------------------------------+
| A  SHOP            | B  SECURITY       | C  COURTYARD (outside)        |
| shop window,       |    ROOM           | dog Boef, crates, mud         |
| counter, till,     | monitors, chair   | puddle, delivery gate with    |
| doorbell, door cam | evidence locker   | padlock     <-- CHAIN POINT 1 |
+--------+-----------+-------------------+-----------+-------------------+
| KAREL'S| D  RIPENING HALL                          | E  OFFICE         |
| CLOSET | 8 cheese wheels on racks, wire cage,      | (mezzanine,       |
| broom, | 2 cameras, 1 guard on a loop              |  stairs from D)   |
| junk   |                                           | safe with the     |
|        |               <-- CHAIN POINT 2           | Golden Gouda,     |
|        |                                           | window to yard    |
|        |                                           | <-- CHAIN POINT 3 |
+--------+-------------------------------------------+-------------------+
```

- **Quay (north):** the van is parked by the canal. You scout from here. There are bikes and a street lamp; the houseboat is decoration.
- **A — Shop (northwest):** public zone (your cover works here). The front door has a camera above it and a doorbell (for the "Fake Delivery"). The counter and the till with the **cash drawer** (small loot, 200 Cash).
- **B — Security room (centre-north):** monitors and a chair with wrist straps. The evidence locker. One camera on the door.
- **C — Courtyard (northeast):** outside, fenced in. The dog Boef. A mud puddle by the gate (footprints!). The **delivery gate with padlock** to the street. Stacked crates to hide behind. The back door of the ripening hall.
- **D — Ripening hall (south, the largest room):** long racks with **8 cheese wheels** (100 Cash each, large: carry them or use the Winch). A wire cage with the most expensive wheels. Two cameras that cover each other. One guard on a loop around the racks.
- **E — Office (mezzanine, southeast):** reached by stairs in the ripening hall. The safe with **the Golden Gouda** (main loot, 1,200 Cash, the heaviest loot). A window onto the courtyard.
- **Karel's closet (southwest):** broom, buckets and the junk you can use to distract Karel.

### 10.2 The chain occurs three times

**Chain point 1 — The delivery gate (getting in)**
- *See:* the drone flies over the fence (stay high, or Boef grabs it) and spots the outside guard, the camera above the gate and Boef. Or: a Spy Cam on the street lamp across the street.
- *Clear:* a Noisemaker in the far corner of the courtyard lures Boef and the guard away. Or: the EMP switches off the gate camera, but then the drone has to stay **outside the 14 studs**.
- *Open:* the Crowbar breaks the padlock (3 s, CRACK). That has to happen during the distraction, or the guard hears it. Alternative: the Winch over the fence (no noise, but the cable is visible).
- *Lesson:* "distract + open at the same time". Small chance of getting caught; this point is the tutorial for real.

**Chain point 2 — The ripening hall (the loot)**
- *See:* a Spy Cam by the back door of the hall, or the drone through the ventilation grille. Two cameras cover each other; a guard walks a 25 s loop.
- *Clear:* the EMP right between the two cameras knocks them out **together**. That is also the biggest chance of comedy: the drone that is watching the guard is often hanging just inside the radius.
- *Open:* the Crowbar on the wire cage (3 s, CRACK) while the guard is at the other end of his loop. If you do the honest maths: 10 s window − 3 s prying = 7 s to get in, out and behind a rack.
- *Lesson:* "two clearers at once", and learning to judge the EMP radius.

**Chain point 3 — The office and the escape (the main loot)**
- *See:* the building's own security cameras (if someone has been caught, they can see them anyway) or the drone via the stairs. Karel is cleaning in the office.
- *Clear:* a Noisemaker down in the hall lures the guard away. That does not work on Karel: he needs a mess in his closet, or a "Fake Delivery" sends a guard to the front door.
- *Open:* the Crowbar on the safe (1.5 s). Then the **Winch** opens a route: a cable from the office window across the courtyard to the roof of the van. The Golden Gouda slides across it in 8 s. Boef has to be distracted at that moment, or he barks at the sliding cheese.
- *Lesson:* everything together, with three people working at the same time and one carrying the loot away.

### 10.3 Loot on map 1

| Loot | Count | Value | Type |
|---|---|---|---|
| Golden Gouda | 1 | 1,200 Cash | Large, very heavy (Winch: 8 s) |
| Cheese wheel | 8 | 100 Cash each | Large |
| Cash drawer | 1 | 200 Cash | Small (in your pocket) |
| **Total** | | **2,200 Cash** | Minimum to win: Golden Gouda or 600 Cash |

### 10.4 Why this map

- **Small:** five small rooms and a quay, one floor plus a mezzanine. Doable to build as a beginner and quick enough for 11-minute runs.
- **Little verticality:** only the mezzanine. Flying a drone on a phone in a tall stairwell is tricky.
- **Every step in two ways:** that way every combination of gadgets in your crew works.
- **Variants without new building work:** "Night Shift" (different routes, less light) and "Rush Job" (8 s windows) use the same building. That gets you three "jobs" out of one map.

### 10.5 Style, mood and setting: standing out in the Roblox catalogue

**The problem with the PC concept:** a realistic Dutch burglary game looks dark, busy and "grown-up" on a 6-inch phone screen. In the Roblox catalogue, stylised, bright, readable games do well. 83% of Roblox players play on mobile (Roblox, annual report 2025).

**What changes:**

| Element | PC concept (presumably) | Roblox version |
|---|---|---|
| Art style | Realistic | **"Toy diorama"**: chunky, simple shapes, exaggerated proportions (canal houses that lean, bikes with oversized wheels), little texture |
| Lighting | Dark, night | **"Blue night"**: deep blue shadows with warm orange light from windows and street lamps. Dark enough to hide in, light enough to see on a phone at half brightness |
| Colour | Muted | Bright and saturated. Orange is the crew colour (work vests, the van): a nod to the Netherlands and highly visible |
| Characters | Own crew | **Players keep their own Roblox avatar** with a work vest and cap over it (which is also your cover). Roblox players want to show off their avatar; taking it away costs you players |
| Guards | Realistic | Stocky, moustache, big flashlight, visible vision cone, icon above the head. Funny, not scary |
| Setting | Recognisably Dutch | The fictional town of **Polderdam**: canal houses, bikes everywhere, cheese, tulip crates, a windmill on the horizon, a herring cart. Signage in English with a Dutch wink ("KAAS", "FIETSEN") as decoration. Nowhere any Dutch text you need to understand to play |
| Humour | ? | Karel the caretaker, the dog Boef, cardboard guards in the tutorial, awards on the end screen |

**What you avoid:** real brands, logos or shop names (Roblox removes trademark infringement after a complaint), clichés that hurt people, and "scary" darkness. The Dutch setting is your charm, not a barrier: children all over the world know cheese, bikes, windmills and tulips.

**For the game page:**
- **Icon** (512 × 512, shown at about 150 × 150): one image that shows what makes you different, for example a drone falling out of the sky with sparks and "BZZT", above a cheese wheel. No small text.
- **Thumbnails** (1920 × 1080, up to 10): make 3 to 5 and turn on **Thumbnail Personalization** (Roblox shows each player the thumbnail that works best for them; in Roblox's own tests this gave on average +8.5% more players clicking through). No important text at the bottom, because that is where Roblox puts the player count.
- **First sentence of the description** = the genre: "Co-op stealth heist for 1–4 players. No real guns, only silly ones."
- The game also has to appeal to **teenagers aged 16+**, because they play it first (§5.5). "Playful" works for all ages, "childish" does not.

---

## 11. A new player's first 5 minutes

**Principle:** learning by doing. At most 6 words per hint, always with an icon. No text screens. The first joke comes within 60 seconds.

| Clock | What the player does | What the game shows |
|---|---|---|
| **0:00** | Arrives in the Depot, next to the **Practice Yard** (a small fenced practice yard). | One sentence across the full width: "No boss. One van. Silly weapons only." An arrow to the Practice Yard. |
| **0:10** | Automatically gets the Drone. | Hint: "Fly the drone. Find the guard." The player flies over a low wall and sees a **cardboard guard** on little wheels rolling back and forth. After 0.5 s of looking: red icon. "Spotted!" |
| **0:40** | Gets the EMP; the drone is still hovering above the camera. | Hint: "EMP the camera." The blue radius also hits the drone (red icon "YOUR DRONE!"), but the player throws anyway. **BZZT** — camera off, and the drone falls on the cardboard guard's head. Little stars. Text: "Oops. EMP hits YOUR stuff too." This is the first laugh. |
| **1:10** | Gets the Crowbar; a ring counts down ("CAMS OFF 10"). | Hint: "Open the door now." The player pries the door open within the window. Behind the door is a little cheese (small loot). "Chain complete: EYES → CLEAR → OPEN." Three little icons click into place. |
| **1:40** | Walks on to the second part. Two cardboard crew members with ping balloons stand here. | A cardboard crew member shows "WAIT", then "NOW". Hint: "Hold PING. Pick NOW." The player sends a ping themselves. That way they learn the two most important pings without any explanation. |
| **2:10** | Leaves the Practice Yard at the vans. Gets 500 Cash ("Welcome bonus") and the Rookie badge. | Two big buttons: "PLAY WITH CREW" (matchmaking) and "GO SOLO". If they choose nothing, they simply walk into a van. |
| **2:30** | The ride: picks a gadget. | By default the game picks the gadget the crew is still missing ("Your crew needs: OPEN") and sets it up. One tap to confirm. |
| **3:30** | The scouting on map 1, Rookie (12 s windows, no Karel, no Asset Recovery). | Colour-coded chain cards (§3.2). At the first chain point the game automatically starts a Chain Call for anyone who has never done a Chain Call: "Tap I'M IN". |
| **5:00** | The first chain point is solved with real people or solo. | "First chain! +15 Rep". From here on the hints disappear, unless the player does nothing for 60 s. |

**What is deliberately not in here:** no explanation of Cash, Rep, the shop or the alarm ladder. You learn those after your first run, on the payout screen (one tip per run, for at most three runs).

**What the first minute does against the competition:** in 60 seconds the player sees what Entry Point and Notoriety don't have: no real gun but a Bubble Blaster, a gadget that takes down your own drone, and a door that only opens when someone else gives you the window.

---

## 12. Build order for a beginner

**Starting point:** you work (almost) alone, about 10 hours a week, and Claude Code writes most of the code through the official Roblox connection. The times below assume that. If you work fewer hours, they stretch proportionally.

**The golden rule:** first build **one chain point** that is fun in grey blocks. Only when three friends laugh about it together do you build a map around it. Almost every beginner project on Roblox dies because it has to be pretty and big first.

*(A **graybox** is a playable version of a level in plain grey blocks, without nice models, to test the gameplay before you put time into art.)*

### Phase 0 — Setup and learning (1–2 weeks)

| | |
|---|---|
| **What's in it** | Installing tools (§15). Getting to know Roblox Studio: flying around, placing blocks, testing. Publishing one empty test project (private). Having Claude build something small through the Studio MCP: "make a door that opens when I press E". |
| **Tools** | Roblox Studio, Roblox Studio MCP (through the official Claude Code plugin), Git + this repo, Rojo (through Rokit). |
| **Done when** | (1) Claude Code can see your open place and change a script. (2) A script that Claude writes in the repo shows up in Studio through Rojo within 2 seconds. (3) You can test in Studio with 2 players at once (*Test → Server & Clients: Studio starts a server and up to 8 fake players on your own computer*). |

### Phase 1 — Prototype: one chain point (4–6 weeks)

| | |
|---|---|
| **What's in it** | One graybox room with chain point 2 from §10: a guard with a fixed route and the four states, two cameras, a cage. Four gadgets: Drone, Noisemaker, EMP, Crowbar. The window with the shrinking ring. The Chain Call and the "NOW" and "WAIT" pings. Caught = back to start. Simple buttons on mobile. |
| **Deliberately not** | No saving, no money, no lobby, no art, no dog, no Karel. |
| **Tools** | Studio + Studio MCP (Claude runs the tests, reads errors in the console, takes screenshots), Rojo + Git (all code in this repo). Optional: the Roblox Engineer Skill (§15). |
| **Done when** | (1) You and 2 friends play the chain point 10 times in one evening. (2) For every failure they can say why they failed. (3) There is at least one laugh out loud about the EMP. (4) It works on your own phone. (5) 10 minutes of play give no red errors in the console. |

> **Stop point:** if phase 1 isn't fun, change the chain (window, radius, sound), not the art. Build nothing from phase 2 until this is right.

### Phase 2 — Playable test with friends (6–10 weeks)

| | |
|---|---|
| **What's in it** | The whole first map in graybox with all three chain points. All six gadgets. The full ping system and the Chain Call. The alarm ladder. Caught → security room → rescue. Carrying loot, the Winch, the van as the exit. Payout screen (still without saving). The Depot with vans and TeleportService. Solo Kit (timers). The dog. First simple art: Roblox materials and a few custom props from Blender. |
| **Tools** | Everything from phase 1, plus **Blender** and **Blender MCP** (Claude makes simple props: cheese wheel, crate, van). Import through Studio's built-in 3D Importer (or the Roblox Blender Plugin, §15). |
| **Done when** | (1) 5 test sessions with 3–4 friends, at least 2 of whom play on a phone. (2) A run lasts 10–15 minutes on average. (3) At least 3 of the 4 testers want "one more go" afterwards. (4) New testers play without you explaining anything (you just watch and stay silent). (5) A solo round can be completed. |

### Phase 3 — First release, in two steps (8–12 weeks + 1–2 months of review)

**Phase 3a — Release for 16+ (the trial period)**

| | |
|---|---|
| **What's in it** | Saving progress (*a **DataStore** is the Roblox database in which you store data per player, such as Cash and bought skins*). Cash, Rep and levels. The Gear Wall with the 3 extra gadgets and the stake ("Confiscated"). Cosmetics, game passes, developer products, the Van Shop and the free Glovebox (§8). The Practice Yard (§11). Rookie and Normal. Karel (simple). Matchmaking with joining in the first 3 minutes, and the vote to kick someone out. Quick Words set up (§5.4). Art pass: the stylised Polderdam (§10.5). Sound and music. The full questionnaire for the age rating. Icon and 3–5 thumbnails. Tracking points (analytics) for the first 5 minutes. First a **closed beta** (20–50 testers), then public for 16+. |
| **Tools** | Everything from before, plus **RBXMonkey / Blender Animations** for custom animations (guard, dog, Karel, crouching). A library for safe saving (§15.2). |
| **Done when** | (1) Two weeks of closed beta without a single case of lost progress or a lost purchase. (2) All purchases tested with test purchases in Studio (they don't cost real Robux). (3) At least 70% of new players get through the Practice Yard (readable from your tracking points). (4) The rating is Minimal or Mild. (5) The game runs smoothly on a cheap Android phone. |

**Phase 3b — The Kids & Select review (ages 9–15)**

| | |
|---|---|
| **What's in it** | ID verification and two-step verification on your account, the deposit or 2 months of Roblox Plus (§5.5). Recruiting 16+ players who actually play: your test group, friends, a Discord group, the DevForum. Following up moderation reports quickly. Meanwhile fixing bugs and shipping small improvements. |
| **Tools** | Creator Hub: the **Audience Reach** dashboard (progress of the review) and the analytics (D1 retention, session length, where players drop off). |
| **Done when** | The game is approved for Kids and Select, so the threshold of 250 unique plays by engaged players in 60 days has been reached. At the same time you follow the two numbers Roblox itself recommends first: **D1 retention** (*the share of new players who come back the next day*) and the **average session length**. Roblox shows benchmarks against similar games once you average 100 players a day. |

### Phase 4 — Updates (every 4–6 weeks)

Order based on what keeps players around the most:

1. **Asset Recovery** (the Signal meter, §9.7) and **Pro** difficulty.
2. **Cover Story** (cover, §9.7) and the job variants "Night Shift" and "Rush Job".
3. **A new map** about every 2 months. Ideas that fit Polderdam: the bike shop (bikes as loot, the Winch across the canal), the flower auction (cold stores, conveyor belts), the stroopwafel factory (noisy machines cover your CRACK), the canal-house office (vertical: only once you have really mastered the drone).
4. **Crew Pass season 1** (§8.5), ±2 months after the release, then a new season every 8 weeks.
5. Translations, weekly challenges, events.

**What is realistic for a beginner, honestly:** NPC behaviour (guards that see, search and follow) and multiplayer (gadgets that work for all players at once) are the two hardest parts. That is why both are already in phase 1, so you find out early whether it works. Art, money and saving are much more predictable and come later.

---

## 13. Risks

The five biggest reasons why this could fail on Roblox, from big to smaller:

| # | Risk | Why it is real | What you do about it |
|---|---|---|---|
| 1 | **The project is too big for one beginner and never gets finished.** | Guards that see and search, gadgets that work in multiplayer, saving and selling: each is a craft of its own. Every week you build without testing, the risk grows. | The phases in §12 with hard "done when" rules. The hardest parts (NPCs and multiplayer) first. Asset Recovery, Cover Story and extra maps deliberately after the release. One map, three variants. Work with Git and in small steps every week. |
| 2 | **Your target audience (9–15) cannot play your game until it passes the Kids & Select review.** | Since June 2026 a new game is at first only for players aged 16+ with an age check. You need 250 unique plays by engaged players in 60 days (§5.5). A children's game that doesn't appeal to over-16s never reaches the children. | A style and humour that work for all ages (§10.5). Release in two steps (phase 3a and 3b). Build up a 16+ test group as early as phase 2 (Discord, friends, DevForum). Check the Audience Reach dashboard weekly. Arrange the deposit in time. |
| 3 | **Empty servers.** A new game has few players online at once at the start; a van of 4 strangers won't fill up. | Anyone who waits 2 minutes for teammates leaves. A game that only works with 4 dies in the first week. | Solo and duo are fully fledged (§3.7). Vans leave after 45 s with whoever is there. Joining is still possible in the first 3 minutes of a run. Only show "X crews playing now" from 20 players. Launch with a fixed test group that plays on agreed evenings. |
| 4 | **Cooperating without voice is too hard; strangers don't cooperate.** | The chain is all about timing. Children under 13 have no voice, text chat only works after an age check and within age groups (§5.4). One player who doesn't cooperate ruins it for three others. | The Chain Call (§3.4) and icon pings. Automatic marking by Drone and Spy Cams. Quick Words. Rookie windows of 12 s. Timers that replace a missing teammate. A vote to kick a player out of the run. An alarm that escalates step by step instead of an instant "game over". **Test this already in phase 1** with friends who are not allowed to talk. |
| 5 | **Nobody finds or remembers the game**: it disappears among ROB IT, Notoriety and dozens of small "X Heist" games, or players drop off in the first minute. | Roblox nowadays counts the "first play bounce rate" (players who leave again within 60 s or 3 minutes) as a negative signal. A stealth game starts slowly by nature. Anyone searching for "heist" first finds games with years of content. | The EMP joke within 60 s (§11). No text screens. Rookie without Karel and Asset Recovery. Tracking points at every step of the first 5 minutes. Show the difference everywhere: only funny weapons, nobody can do it alone, a cheerful toy town instead of a grey bank (§1, §10.5). A title with its own brand name and "heist" as a tag (§14). Several thumbnails with Thumbnail Personalization. |

**Two smaller risks to keep an eye on:**
- **Lost data or purchases.** One story about "I lost the skin I bought" costs you the trust of parents. Use a proven saving library, test with test purchases, and store Robux purchases separately from normal progress (§8.11).
- **Performance on cheap phones.** Many children play on older devices. Keep models simple, at most 8 NPCs per map, and turn on *StreamingEnabled* (*a Roblox setting that only loads the part of the world close to the player*).

---

## 14. Title options

All ten searched in the Roblox search on 15/10/2026: **none of them is used by a well-known game.** Note: Roblox hides inactive games in search results, and no trademark search has been done.

| # | Title | Why |
|---|---|---|
| 1 | **Crowbar Crew** | Short, alliteration, sticks. Immediately says "breaking in together", with a tool instead of a gun. No clashes found. ⚠️ Lacks the keyword "heist", so put it in a tag (see below). |
| 2 | **Gadget Heist** | The easiest to find ("heist") and it immediately names your difference from the shooters: gadgets instead of guns. |
| 3 | **Heist Buddies** | The warmest and youngest: "buddies" says co-op and friendship. Suits an audience of 9–15, but is weaker for the 16+ trial period. |
| 4 | **Heist Van** | The van as an icon. Findable and easy to draw in an icon. |
| 5 | **Van Crew** | The shortest. Says "crew" and "van". Less findable because the keyword "heist" is missing. |
| 6 | **Quiet Job** | Heist jargon for a job done quietly. Sounds cool to older players, but "job" also makes people think of work simulators. |
| 7 | **Sneaky Van** | Playful and funny, good for young players. A smaller game "Sneak In!" already exists, so it stands out less. |
| 8 | **Crew of Four** | Says exactly what it is (co-op for four). Little heist feel, and your game also works with 1–3 players. |
| 9 | **EMP Heist** | Puts your comedy gadget centre stage. But many 9-year-olds don't know what an EMP is. |
| 10 | **Canal Heist** | The Dutch setting in two words, findable through "heist". Works less well if you later make maps outside Polderdam. |

**Deliberately advised against:** "Drone Heist" (already exists as a small game), "Tiny Heist" (a well-known indie game by Terry Cavanagh), "Clean Getaway" (a mission in GTA IV), "Blackout Crew" (a British music group), "Back Door Crew" (ambiguous, and "backdoor" also means malicious code), and titles with "Night Shift", "Lights Out" or "Chain", which get confused with existing horror or obby games.

**Chosen: Crowbar Crew** (15/10/2026). The other options stay here as a reserve, for example in case Roblox does not allow the name after all.

**How to put the title on Roblox:** Roblox titles often carry a short tag. For example **"Crowbar Crew 🚐 [CO-OP HEIST]"**: that puts your brand name first and the keyword after it. Use at most 1–2 emoji. Change the title rarely after that; Roblox itself recommends this.

---

## 15. Setup plan for your tools

*(A **plugin** is an extension for Roblox Studio that adds extra buttons or features; you get them from the **Creator Store**, the official Roblox store for models, plugins and sounds, or from the internet. **MCP** (Model Context Protocol) is a standard way for an AI assistant like Claude to operate another program, for example Roblox Studio or Blender. **Luau** is Roblox's programming language.)*

I looked up every tool on 15 October 2026 (GitHub, Creator Store, Roblox documentation, DevForum). Two findings up front:

1. **Five of your eleven tools do the same thing**: let an AI work in Roblox Studio (Studio MCP, Claudio, Vibe Coder, Vibe Code City, MCPBridge). That is now **built into Roblox Studio** (the Studio MCP), and since 7 October 2026 Roblox has an **official Claude Code plugin** that connects to it directly. That means you no longer need the community tools (Claudio, Vibe Coder, Vibe Code City, MCPBridge). Some of them are risky as well.
2. **"Blender Animations Plugin" and "RBXMonkey" are the same tool.** The plugin was first called "Blender Animations (ultimate edition)" and is now called "RBXMonkey - Blender Animations".

### 15.1 Per tool

| # | Tool | What exactly it does | What it is for in this game | Phase | Skip? |
|---|---|---|---|---|---|
| 1 | **Rojo** (v7.7.1, Oct. 2026) | Syncs a folder of code files on your computer with Roblox Studio, through a small program and a Studio plugin. That way your code lives in Git (and in this repo). | All Luau code lives as files in `Roblox-Game`. Claude writes the files, Rojo puts them in Studio. | 0 | **No, keep it.** ⚠️ Overlaps with *Script Sync* (see below): pick one. |
| 2 | **Roblox Studio MCP** (official, built into Studio) | Lets Claude read and change your open place, run Luau, start tests, read the console, take screenshots and simulate player input (more than 25 functions). You connect with the official Claude Code plugin "Roblox Studio". The old standalone GitHub version was discontinued in April 2026. | Claude tests on its own (walking, using gadgets), reads errors and builds grayboxes. | 0 | **No, the most important tool.** |
| 3 | **Claudio** (alyssagithub/claudio, Sept. 2026) | A chat panel in Studio that wraps Claude Code. One developer, 1 star on GitHub. | — | — | **Yes, drop it.** According to its own manual it only fully works on Windows. Automatically installs the latest code every 3 hours without any check. Does the same as tool 2. |
| 4 | **Roblox Engineer Skill** | ⚠️ **Not sure which one you mean.** Most likely: the skill `roblox-engineer` from the repo `buiphucminhtam/forgewright` (49 stars, no licence). A *skill* is a text file with expert knowledge that Claude Code loads. This one is part of a system of 52 skills and not made to be used on its own. | Extra Roblox knowledge for Claude (security, saving, multiplayer). | 1 (optional) | **Yes, for now.** The official plugin already loads Studio's built-in Roblox skills. If you still want an extra skill pack, send me the link where you found the name. As an alternative, `TabooHarmony/roblox-brain` (MIT licence, 29 skills, including NPC AI and networking) is stronger. Always read a skill first. |
| 5 | **Vibe Coder** (rbxvibecoder.com) | An AI plugin in Studio with 5 free messages a day through the maker's server, or PRO for 2,499 Robux with your own API key. | — | — | **Yes, drop it.** Sends your scripts to the maker's server. On 15/10/2026 the site and the server were down ("application suspended"). Does less than tool 2. |
| 6 | **Vibe Code City** | A plugin into which you paste an AI's answer, and which applies the changes across several scripts. Started as a joke post on the DevForum; the linked item is now a paid, closed plugin (US$5.99, 0 votes) with a different name. | — | — | **Yes, drop it.** Unnecessary now that Claude changes scripts directly. Closed code, impossible to check. |
| 7 | **Blender MCP** (now "MCP for Blender", ahujasid, 30,000+ stars) | Lets Claude operate Blender: create objects, run Python, search free models and textures (Poly Haven, Sketchfab), take screenshots. | Simple props: cheese wheels, crates, the van, the cheese shop's facade. | 2 | **You could.** You can also build the graybox and a first version with Roblox blocks and models from the Creator Store. Keep it for the art pass. Turn off telemetry (anonymous usage data that is on by default). |
| 8 | **MCPBridge** (iamjrmh/MCPBridge, 4 stars) | Yet another bridge between an AI (built around Ollama) and Studio, plus Blender. | — | — | **Yes, drop it.** Everything it does, tool 2 does officially. Unsigned installers. The default model runs in the cloud, so your code leaves your computer. |
| 9 | **Roblox Blender Plugin** (official, v1.0.5) | A Blender add-on that uploads models to your Roblox account as a "Package" with one click. Roblox now only maintains it lightly (bug fixes only). | Props from Blender to Roblox. | 2 | **You could.** Studio's built-in **3D Importer** (File → Import 3D) does the same with an .fbx or .gltf file. Try the importer first. |
| 10 | **Blender Animations Plugin** | = tool 11. | — | — | Listed twice in your list. |
| 11 | **RBXMonkey – Blender Animations** (Cautioned, free, 1,860 thumbs up) | A Studio plugin plus a Blender add-on: make animations in Blender and send them back and forth live with Studio. Not an AI tool. | Custom animations: the guard searching, the dog grabbing the drone, Karel sweeping, crouching with loot. | 3 | **You could at the start.** Phases 1–2 work with Roblox's default animations and Animation Editor. Roblox recently became able to import .fbx animations itself as well. Keep it for phase 3. |

**What you keep:** Rojo, Studio MCP (with the official plugin), Blender MCP, RBXMonkey. The Roblox Blender Plugin is optional; the Roblox Engineer Skill is uncertain.
**Drop:** Claudio, Vibe Coder, Vibe Code City, MCPBridge. The Blender Animations Plugin is the same as RBXMonkey.

### 15.2 What is missing from your list (and important)

| Missing | Why you need it | Phase |
|---|---|---|
| **The official Claude Code plugin "Roblox Studio"** (Roblox/roblox-studio-agent-plugin) | The official, simplest way to connect Claude Code to the Studio MCP. See step 2 below. | 0 |
| **Rokit** | The installer for Rojo (and Selene and StyLua). Recommended by Rojo itself; the old alternatives Aftman and Foreman are no longer recommended. | 0 |
| **Git + GitHub** (you already have it) | Keeping every version of your code. If Claude breaks something, you simply go back. | 0 |
| **A library for safe saving** (e.g. *ProfileStore*) ⚠️ | Progress and purchases must never be lost. Using a bare DataStore correctly is tricky. A proven library prevents players who are in two servers at once from overwriting their data. Have Claude look up the currently recommended library before phase 3. | 3 |
| **A cheap Android phone or tablet** for testing | 83% of Roblox players play on mobile. The Device Simulator in Studio shows the screen, but not the speed or how your thumb hits the buttons. | 1 |
| **Selene, StyLua, VS Code + Luau Language Server** (optional) | Checking and neatly formatting code, and being able to read the code yourself with colours and explanations. | 1–2 |
| **A place for testers** (your own Roblox community or Discord server) | Phases 2 and 3 need 5 to 50 testers. | 2 |
| **A sound source** | The Roblox Creator Store has free licensed sounds. In a stealth game, sound is half the game (CRACK, BZZT, the ticking of the clock). | 2 |

**Script Sync, Rojo's built-in rival.** Since late 2025 Roblox has had *Script Sync*: a feature in Studio that syncs scripts and folders with files on your computer, without any extra installation. Roblox's own guide for AI assistants ("coding harness") recommends Claude Code + Script Sync + Studio MCP + Git. Script Sync only syncs scripts and folders, and on 15/10/2026 may still have been in beta ⚠️. **Advice:** use Rojo, because you had already chosen it, it has been mature for years and it is the standard tool Claude knows the most about. Let Rojo manage only the **code** and keep the map (the buildings) in Studio. Never use Rojo and Script Sync on the same folders.

**One important agreement between Rojo and the Studio MCP:** Claude changes code **in the files** (which Rojo puts into Studio), never directly in Studio. Otherwise Rojo overwrites that change at the next sync. Claude uses the Studio MCP to **test, look and place blocks/models**.

### 15.3 Installation order for a beginner (macOS)

What is already on your Mac (checked on 15/10/2026): **Roblox Studio** (with the built-in MCP), **Git**, **Homebrew** (*an installer for the terminal*), **Claude Code**. This repo is already local in `~/Roblox-Game`.

| Step | What | Depends on | How | How to check that it works |
|---|---|---|---|---|
| 1 | Update **Roblox Studio** and log in | — | Open Studio; it updates itself. Log in with your Roblox account. Create a new "Baseplate" and save it. | Studio opens and you see the baseplate. |
| 2 | **Studio MCP on + official Claude Code plugin** | Step 1 + Claude Code | In Claude Code: type `/plugin`, search for **Roblox Studio** and install it. In Studio: **Assistant → ⋯ → Settings → MCP Servers** → turn on **Enable Studio as MCP server**. Or ask Claude: "Get me set up with Roblox Studio." | In Claude Code, `/mcp` shows the line `plugin:roblox-studio:macos` as connected (the one for Windows may show "failed"). Ask: "List my open Roblox Studio windows" → Claude names your place. |
| 3 | **Rokit** | Terminal | The official install script from the Rokit GitHub page (`rojo-rbx/rokit`). ⚠️ It is a `curl … \| bash` command: that runs a script from the internet. Have Claude read and explain the script first. | `rokit --version` shows a version number. |
| 4 | **Rojo** | Step 3 + step 1 | In `~/Roblox-Game`: `rokit init`, `rokit add rojo-rbx/rojo`, `rojo init`, `rojo plugin install`. Then `rojo serve`, and in Studio click **Connect** in the Rojo plugin. | `rojo --version` shows 7.7.x. The Rojo plugin in Studio shows "Connected". A test line in a script appears in Studio within 2 s. |
| 5 | *(optional)* **VS Code, Luau Language Server, Selene, StyLua** | Step 3 | VS Code from code.visualstudio.com; extension `JohnnyMorganz.luau-lsp`; `rokit add Kampfkarren/selene` and `rokit add JohnnyMorganz/StyLua`. | A `.luau` file in VS Code gets colours and suggestions. |
| — | *Phase 1 starts here. The steps below only in phases 2–3.* | | | |
| 6 | **Blender** | — | Only from **blender.org** (or `brew install --cask blender`). Take version 5.x: the Roblox plugins have been tested on it. | Blender opens; Help → About shows 5.x. |
| 7 | **uv** (needed for Blender MCP) | Homebrew | `brew install uv` | `uv --version` shows a version number. |
| 8 | **Blender MCP** | Step 6 + 7 | `claude mcp add blender uvx mcp-for-blender` (from the official manual). Then `uvx mcp-for-blender install-addon`. In Blender: **Edit → Preferences → Add-ons** → enable "MCP for Blender". In the 3D view **N** → tab "MCP for Blender" → **Start MCP Server**. Telemetry off: set the environment variable `DISABLE_TELEMETRY=true` (ask Claude to set it up correctly). | `claude mcp list` shows "blender". Ask Claude: "What is in my Blender scene?" → it names the default cube, camera and light. |
| 9 | *(optional)* **Roblox Blender Plugin** | Step 6 | The zip from the release page of `Roblox/roblox-blender-plugin` (do not unzip it). Blender → Preferences → Add-ons → **Install from Disk** → enable → in the N panel "Install Dependencies", restart Blender, log in. | After an upload the model is in Studio under **Toolbox → Inventory → My Packages**. First just try **File → Import 3D** in Studio. |
| 10 | **RBXMonkey – Blender Animations** | Step 6 + 1 | Blender part: install and enable the zip from the release page of `Cautioned/Blender-Animations-Plugin`. Studio part: the plugin through the link **in that GitHub manual** (not by searching, because there are copies with similar names). Only grant network access to `localhost`. | In Blender: N → tab "RBXMonkey" → start the server. In Studio: tab "Blender Sync" → Connect → "Connected". A test animation comes through. |

**Dependencies at a glance:**
```
Roblox Studio ──┬── Studio MCP ── official Claude Code plugin ── Claude Code
                ├── Rojo plugin ── Rojo ── Rokit
                └── RBXMonkey plugin ──┐
Blender ────────┬── RBXMonkey add-on ──┘
                ├── Blender MCP ── uv ── Homebrew
                └── Roblox Blender Plugin (optional)
```

### 15.4 How to check whether a plugin is trustworthy

Plugins and free models can contain malicious scripts (*a "backdoor" is hidden code that lets a stranger take over your game or mislead players*). Roblox itself writes that backdoors "are often in models that otherwise look legitimate" and that **popularity is no guarantee**. Do this check for **every** plugin, every model and every Blender add-on.

**Before you install**
1. **Get it through the official link**: the link in the maker's GitHub manual or in the Roblox documentation, not by searching the Creator Store. Copies with almost the same name exist (watch for a lowercase L instead of a capital i).
2. **Look at the maker:** an account that has existed for years and has other well-known plugins. The blue tick (Verified Badge) only means that the maker is real and well known, **not** that Roblox checked the plugin for safety.
3. **Look at the numbers on the Creator Store page:** many votes with a high ratio of thumbs up, recent updates, the reviews, and the **number of scripts** (it is listed there). A simple model with dozens of scripts is suspicious. So is a brand-new plugin with only 5 stars.
4. **Is the source code public?** Rojo, RBXMonkey and Blender MCP are on GitHub with a licence. You cannot check a closed plugin.
5. **Never give out your password or cookie.** A plugin, site or script that asks for your Roblox password, your **.ROBLOSECURITY cookie** (*your login key*) or "free Robux" is always a scam.
6. **No `.rbxm` or `.rbxmx` files from Discord or unknown sites** in your Plugins folder. Such **local plugins skip Studio's permission check**.
7. **Terminal installs** (`curl … | bash`): have Claude open and explain the script before you run it.

**During and after installing (Roblox Studio)**
8. Studio asks for permission when a plugin **wants to talk to the internet**, separately per domain (and per subdomain). Only grant what makes sense: Rojo and RBXMonkey only need `localhost` (your own computer). If a plugin asks for an unknown domain, refuse.
9. Open **Plugins → Manage Plugins**: there you see per plugin which domains it may use and whether it **may change scripts** ("Script Injection"). Turn off Script Injection for every plugin that does not need it. You can revoke everything afterwards.
10. **Free models from the Toolbox:** right-click → **Disable Scripts** before you use them, or delete the scripts in them.
11. **Search your whole place** (Ctrl+Shift+F or ask Claude: "Search my place for suspicious scripts") for what Roblox itself calls dangerous: `require(` followed by a number (loads hidden code from the internet), `loadstring`, `InsertService:LoadAsset`, `getfenv`, `setfenv`, unreadable or encrypted code, code pushed out of view with lots of spaces, and inexplicably large scripts. Also look at where `TeleportService`, `MarketplaceService` or `HttpService` show up in scripts you did not make yourself. Script names like "Vaccine", "Fix" or "Anti-Lag" are a classic trap.

**Blender add-ons**
12. Blender says so itself: Python can do anything on your computer. Preferably get add-ons from **extensions.blender.org** (a moderator reviews them there first) or from the maker's official GitHub page.
13. In Blender, leave **Auto Run Python Scripts** off (it is off by default) and **Allow Online Access** off, unless an add-on really needs it (Blender MCP).
14. Have Claude read through the `.py` files in the zip for `exec`, `eval`, `base64`, `subprocess`, `os.system` and network code (`urllib`, `requests`, `socket`), and be wary of bundled `.pyc`, `.so` or `.dll` files. Scan the zip with a virus scanner.

**Always**
15. **Work with Git and save your place regularly** (File → Save, and publish a version). If something goes wrong, you go back to the previous version.

---

## Questions: current status

1. **Karel** — answered: the caretaker who tidies up and tells on you (§9.6).
2. **The Kids & Select review** — still open: for phase 3b, do you want to have your identity verified, turn on two-step verification and pay the refundable deposit of 1,000 Robux (§5.5)? You only need to decide that once the game is finished. Without the review the game stays 16+, and then the design has to become older (less cardboard humour, more tension).
3. **Title** — answered: **Crowbar Crew** (§14).

---

## Appendix: sources (consulted on 15/10/2026)

**Roblox rules**
- Age ratings and questionnaire: <https://create.roblox.com/docs/production/promotion/content-maturity> · <https://en.help.roblox.com/hc/en-us/articles/8862768451604>
- Kids & Select (review for ages 5–15): <https://create.roblox.com/docs/production/publishing/kids-and-select> · DevForum announcements of 16/06/2026 and 19/08/2026 (threshold from 500 to 250 plays)
- Publishing: <https://create.roblox.com/docs/production/publishing/publish-games-and-places>
- Age check for chat (07/01/2026): <https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat> · <https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101>
- Parental controls and Quick Words for all ages: <https://en.help.roblox.com/hc/en-us/articles/30428310121620>
- Voice chat: <https://create.roblox.com/docs/chat/voice-chat>
- Fixed messages (presets): <https://create.roblox.com/docs/chat/preset-system-guidelines> · Quick Words: <https://create.roblox.com/docs/chat/quick-words>
- Chat rules for creators: <https://create.roblox.com/docs/chat/guidelines>
- Community Standards: <https://about.roblox.com/community-standards> · Trademarks and copyright: <https://create.roblox.com/docs/production/publishing/ip-guidelines>

**Earning**
- Overview: <https://create.roblox.com/docs/get-started/monetization> · game passes, developer products, subscriptions, private servers: <https://create.roblox.com/docs/production/monetization/>
- DevEx (US$0.0038 per Robux since 05/09/2025): <https://create.roblox.com/docs/production/monetization/developer-exchange>
- Creator Rewards (replaces Premium Payouts): <https://create.roblox.com/docs/creator-rewards> · Roblox Plus: <https://create.roblox.com/docs/production/monetization/roblox-plus>
- Regional pricing: <https://create.roblox.com/docs/production/monetization/managed-pricing>
- Paid random items: <https://create.roblox.com/docs/production/monetization/paid-random-items> · Ban in the Netherlands (2022): <https://www.gamedeveloper.com/game-platforms/-i-roblox-i-game-i-adopt-me-i-ends-netherlands-service-due-to-loot-boxes>
- Rewarded ads and age: <https://create.roblox.com/docs/production/promotion/rewarded-video-ads> · <https://en.help.roblox.com/hc/en-us/articles/13722260778260>

**Market and technology**
- Users by age (35% under 13, 38% 13–17, 27% 18+; Q2 2026) and by device (83% mobile, 14% desktop, 3% console; 2025): Roblox's Q2 2026 shareholder letter and 2025 annual report (SEC filings).
- Discovery and recommendations: <https://create.roblox.com/docs/discovery> · DevForum 15/06/2026 ("Recommended for You" and long-term retention)
- Onboarding: <https://create.roblox.com/docs/production/game-design/onboarding>
- Icons and thumbnails: <https://create.roblox.com/docs/production/promotion/game-icons> · <https://create.roblox.com/docs/production/publishing/thumbnails>
- TeleportService: <https://create.roblox.com/docs/projects/teleport> · Matchmaking: <https://create.roblox.com/docs/matchmaking> · Testing in Studio: <https://create.roblox.com/docs/studio/testing-modes>
- Competitors: the Roblox game pages (API) of Entry Point, Notoriety and ROB IT, and Rolimons for peaks and play time.

**Tools**
- Studio MCP: <https://create.roblox.com/docs/studio/mcp> · Official Claude Code plugin: <https://github.com/Roblox/roblox-studio-agent-plugin> · Guide for AI assistants: <https://create.roblox.com/docs/ai/coding-harness>
- Rojo: <https://github.com/rojo-rbx/rojo> · <https://rojo.space/docs/v7/> · Rokit: <https://github.com/rojo-rbx/rokit> · Script Sync: <https://create.roblox.com/docs/scripting/sync>
- Blender MCP: <https://github.com/ahujasid/mcp-for-blender> · Roblox Blender Plugin: <https://github.com/Roblox/roblox-blender-plugin> · 3D Importer: <https://create.roblox.com/docs/art/modeling/3d-importer>
- RBXMonkey / Blender Animations: <https://github.com/Cautioned/Blender-Animations-Plugin>
- Not recommended: Claudio <https://github.com/alyssagithub/claudio> · Vibe Coder <https://rbxvibecoder.com> · Vibe Code City (DevForum, 12/04/2026) · MCPBridge <https://github.com/iamjrmh/MCPBridge> · Roblox Engineer Skill (probably) <https://github.com/buiphucminhtam/forgewright/tree/main/skills/roblox-engineer>
- Plugin safety: <https://create.roblox.com/docs/production/creator-store> · <https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities> · Blender: <https://docs.blender.org/manual/en/latest/advanced/scripting/security.html>
