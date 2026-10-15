Translated from the original Dutch brief.

# WHERE THE WORK GOES

This game has its own GitHub repo: `Mauritsman/Roblox-Game`. This prompt is stored there as `docs/roblox-prompt.md`. Everything you make for the game (this gameplan, later documents, later the code) belongs in that repo, and nowhere else. The repo `brouwersstraat-21` is my house app and has nothing to do with the game: do not put anything in it.

Put the document you make in the repo as `docs/gameplan-roblox.md`. If that does not work because you do not have access, say so, give me the step to fix it (give the Claude GitHub app access to `Roblox-Game` via https://claude.ai/connect-github), and in the meantime write the document in the chat so I do not lose it.

# MY TOOLS AND PLUGINS

These are the tools and plugins I want to use to build the game. I have not installed or set up any of them yet.

1. Rojo
2. Roblox Studio MCP
3. Claudio
4. Roblox Engineer Skill
5. Vibe Coder
6. Vibe Code City
7. Blender MCP
8. MCPBridge
9. Roblox Blender Plugin
10. Blender Animations Plugin
11. RBXMonkey

Take this toolset into account throughout your design, especially in the build order. Check for each tool exactly what it does. If you do not know a tool, or are not sure it is the tool I mean, say so instead of guessing. Also point out when two tools do the same thing, so I can drop one, and when something important for my game is missing.

# ROLE

You are an experienced Roblox game designer. You have released several successful co-op games on Roblox and know the platform inside out: the audience, the age ratings, the monetisation rules, the limitations of mobile play and what players will and will not put up with. You are honest and critical. If something in my concept does not work on Roblox, you say so and give a better solution instead of glossing over it.

# TASK

Turn my existing game concept into a complete gameplan for Roblox. The concept was designed as a regular PC game. I want the core (what makes the game unique and fun) to stay intact, and everything around it to be adapted to Roblox. Nothing is being built yet: I only want the design, no code.

I am a beginner. Explain every technical Roblox term the first time you mention it in one short sentence (for example: private server, game pass, developer product, TeleportService, age rating, server/client).

Write in Dutch. Text that players see in the game (buttons, notifications, gadget names) you write in English, because the game has to work internationally.

# THE CONCEPT (as it stands now)

If the full gameplan (unpaid-gameplan.md) is attached, that is the source. Below is the summary of the core; if the document and this summary contradict each other, this summary wins, because it is newer.

**Who you are:** four friends with a van, without an employer. You pull off small, clever break-ins (stealth heists) in recognisable, Dutch-feeling places.

**Pillar:** preparation is your only weapon. You win by planning and working together, not by fighting.

**The core, the chain:** every obstacle is solved in three steps: *see → clear → open*, within a window of 8 to 12 seconds. Each gadget only opens a window, never a whole path. Nobody can take one step alone. Example: the EMP knocks out cameras for 8 seconds, but the EMP player cannot see whether the corridor is clear. The drone operator sees that, and has to stand still to look. The drone sees the guard, but cannot get rid of him; the distraction player does that. The door behind it only opens with the crowbar, and that makes noise, so it has to happen exactly during the distraction.

**The six gadgets:**
1. LAN drone: scouting, seeing guards and cameras.
2. Camera set: fixed cameras you hang up yourself to keep an eye on an area.
3. Distraction kit: sound or movement that lures guards away.
4. EMP: knocks out electronics for a few seconds. Including your own drone and cameras! That is deliberate: it is the most important comedy moment of the game.
5. Crowbar: opens doors, cabinets and hatches, but makes noise.
6. Winch: (cable/line) to get loot and players over obstacles or to the van.

**Gear:** there are standard gadgets that the crew divides among themselves at the start of a run, and extra gadgets you buy with in-game money. Extra gadgets are sideways, not stronger: they solve the same three steps in a different way. As a result a new player must never be useless.

**The stake:** if you get caught, you lose the gadget you are carrying at that moment. Rescuing a teammate therefore also means getting back their expensive gadget.

**Carrying loot:** whoever carries loot drops out of the chain (cannot use their gadget). Carrying and being useful exclude each other.

**Opponents:** guards (NPCs), cameras, a dog that hunts the drone, and Asset Recovery, a threat that homes in on active electronics. So your own gadgets give you away; switching them off means going blind. There is an alarm ladder that rises the more you stand out.

**Cover:** you wear work clothes. The information from scouting helps you survive being questioned by an NPC.

**Traces:** you leave traces (footprints, broken glass, moved objects) that guards can find. Wiping traces costs a consumable. There is an NPC Karel who plays a role in this.

**Violence:** there is a little violence and blood where it fits, under one rule: violence is never a solution, always a consequence. Blood is information (a trace), not spectacle.

# ROBLOX CONDITIONS YOU HAVE TO TAKE INTO ACCOUNT

Check every point below yourself; if something no longer matches the current Roblox rules, say so.

- **Audience:** many players are 9 to 15 years old. Choose an age rating (Minimal, Mild, Moderate or Restricted) and explain what that means for the violence and the blood. My preference: the youngest possible audience, with blood as a cartoonish trace or no blood at all. Say what the best choice is.
- **No voice chat for everyone:** players under 13 do not have voice chat. The chain revolves around coordination, so design an extensive ping and quick-communication system (for example tapping a guard, buttons like "NOW!" and "WAIT").
- **Mobile first:** more than half play on phone or tablet. Design the controls for touchscreen, with one clear button per gadget. Say whether the window of 8 to 12 seconds should be longer on mobile.
- **Short sessions:** runs of about 10 to 15 minutes.
- **Friends and strangers:** the game must work with four friends in a private server, but also with strangers via matchmaking and with fewer than four players (1, 2 or 3). How do you handle that without breaking the chain?
- **Earning:** items bought with Robux (real money) must never be lost. Design the stake so that only gear bought with in-game money can be lost. No pay-to-win: with Robux you preferably sell cosmetics (skins for drone, van, outfits) and convenience. Follow the Roblox rules on paid random items.
- **Competition:** Entry Point and Notoriety are existing stealth heist games on Roblox. Explain how my game must be clearly different and how you show that in the first minute.
- **Roblox style:** what needs to change about the art style, the atmosphere and the Dutch setting to stand out in the Roblox catalogue?
- **Feasibility:** I am a beginner and work (almost) alone. Say what is realistic to build first and what can come later.

# WHAT I WANT BACK FROM YOU

Deliver one coherent document with these parts, in this order:

1. **Summary in five sentences:** what is this game on Roblox, who is it for, and why would someone play it instead of Entry Point.
2. **What stays, what changes, what goes:** a table with every part of the concept and for each part: stays / adapted / goes, with a reason.
3. **The chain on Roblox:** how the three steps work with a touchscreen, without voice, and with 1 to 4 players. Including the ping system.
4. **The six gadgets on Roblox:** for each gadget how you use it (PC, mobile, controller), what it does in the chain, and how it can fail. Plus two or three examples of extra gadgets that are sideways.
5. **Violence, blood and age rating:** your advice, and how the traces then work.
6. **Game loop and session:** from lobby to van to run to back, with times in minutes.
7. **Stake, progression and economy:** what you earn, what you can lose, how a new player is immediately useful.
8. **Monetisation:** game passes and developer products with example prices in Robux, and what you deliberately do not sell.
9. **Opponents and alarm ladder:** guards, cameras, the dog, Asset Recovery, adapted to short runs.
10. **First map:** one concrete first location with a floor plan in words, so that the chain occurs in it three times.
11. **The first 5 minutes of a new player:** step by step, including how the game explains the chain without a long tutorial.
12. **Build order for a beginner:** phases (prototype → playable test with friends → first release → updates), with for each phase what is in it, which tools from my list I use for it, and how you know the phase is done.
13. **Risks:** the five biggest reasons why this could fail on Roblox, and for each risk what you do about it.
14. **Title options:** ten names that work on Roblox (short, English, easy to search), with one sentence per name on why. The working title UNPAID no longer fits the concept.
15. **Setup plan for my tools:** a table with, for each tool from the list at the top: what it does, what I use it for in this game, in which build phase I need it, and whether I can skip it. Then the installation order in steps for a beginner: what has to come first (for example Roblox Studio and Blender themselves), which tools depend on each other, and how I check for each tool that it works. For every plugin I get from the Roblox Creator Store or from the internet, state how I check whether it is trustworthy: plugins can contain malicious scripts.

# RULES FOR YOUR ANSWER

- Be concrete: numbers, seconds, prices, examples. No vague sentences like "make sure there is a good balance".
- Actively look for contradictions in my concept and name them.
- If you are not sure about something in the current Roblox rules, say so and say where I can check it.
- Do not write code.
- At the end, ask me at most three questions about choices you cannot make for me.
