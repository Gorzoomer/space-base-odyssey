# Development log

How Space Base Odyssey was built during NASA Space Apps 2026 (14–15 November, Querétaro local event). It records what was decided, by whom, what was tested and how AI was used. Times are local (UTC−6).

## Team and roles

A team of four:
- One member works in Roblox Studio with an AI coding assistant.
- The other three own science and data, game design and playtesting, and presentation and submission.
- The concept, design decisions, playtests and balance calls belong to the team.

## Timeline

### Saturday 14 November

**About 11:30 – Research before any code.** Five research tasks ran in parallel:
- The official challenge page and Space Apps rules: deadlines, demo format, AI disclosure, NASA data requirement, judging criteria.
- A fact check of 25 scientific claims in the team's first design document.
- A check of 15 Roblox engine assumptions against current documentation.
- How games are developed in general and in Roblox Studio.
- The Claude Code features available for directing several AI agents.

**Key finding: the first design did not match the challenge.**
- The team's first document described a flight simulator: launch, docking, landing.
- The challenge asks for a game where kids aged 7–12 **manage a lunar or Martian outpost** and trade off life support, radiation shielding, power, food and communication delay.
- An audit of the first document found:
  - 39 differences between its two versions.
  - 15 numeric inconsistencies. For example, the stated scale (1 stud = 0.35 m) disagreed with the gravity values by a factor of 7.
  - 32 underspecified requirements.
  - 123 distinct features: too many for a weekend.
- **Team decision:** pivot to outpost management.

**Planning.**
- A staged plan (vertical slice first, then more content) was written and reviewed by three independent critics: challenge fit, feasibility, design for kids.
- The critique changed the design:
  - Turn-based days instead of a real-time clock.
  - Three systems instead of five.
  - The radiation shelter is a decision during a storm, not a power sink. A shelter protects by mass.
  - Communication delay is felt through Earth's late or early warning.
- **Team decisions:**
  - Name: *Space Base Odyssey*.
  - Setting: the Moon's south pole, near Shackleton crater.
  - Mechanics proposed by a team member's design notes: third-person astronaut, suit oxygen outside, running to a regolith shelter, solar panels on the sunlit ridge, ice in the shadowed crater, greenhouse, the helper "C.A.R.L.".
  - The team accepted the recommended defaults: 7 mission days, three meters, stars for science.

**12:45 – Toolchain.**
- Rojo 7.7.1 syncs files to Studio.
- Lune 0.11.1 runs tests outside Roblox.
- The Roblox Studio MCP server lets the assistant run the game and read the console.
- Public GitHub repository created.

**12:56 – Core rules and data.**
- `Simulation.luau`: pure mission rules.
- `MissionData.luau`: every number tagged REAL or GAME.
- An archive of 11 real X-class flares downloaded from NASA DONKI.
- Balance tests:
  - A passive player still reaches day 5.
  - No fixed allocation earns 3 stars.
  - Only reacting to events earns 3 stars.
  - Cutting the greenhouse shows up as less food the next day.

**13:57 – Stage 1: playable loop.** Built by four parallel AI agents with an integration review:
- The Moon base built from code.
- The power board, shifts with suit oxygen, storms with real flares and honest false alarms.
- The report screen, and English and Spanish text.

Tested in Studio: a full 7-day mission and a storm with an exposed astronaut. The scene was too dark, so the lighting was retuned.

**16:32 – Stage 2: live NASA data.**
- At server start the game queries NASA CCMC DONKI for the last 30 days of flares and particle events. It falls back to the archive and labels which one it used.
- A "Where our numbers come from" screen shows live status with fetch time, real facts and sources.
- Aligning the antenna gives a longer storm warning (45 s instead of 15 s) and teaches the Earth–Moon versus Earth–Mars signal delay.
- English drafts of every submission field.

Tested in Studio:
- The live query returned 13 flares (strongest M3.5, latest M1.7).
- The antenna was aligned with a real key press.
- A 45 s warning appeared for a replay of the real X5.1 flare of 11 November 2025.

**16:53 – Stage 3: the base reacts and guides.**
- Power decisions are visible in the world:
  - Greenhouse grow lights (magenta, like real red and blue LEDs) dim or brighten with its cells.
  - The air maker fan and light speed up with life support.
  - A six-wheeled rover drives the crater rim only while science has power.
- Guided first two days: the power board points at the systems to try first, and the greenhouse is introduced on day 2 ("plants feed you tomorrow").
- Floating markers show every active task during a shift.
- The C.A.R.L. drone follows the astronaut. Its core turns yellow for urgent tasks and purple during storms, and a beam points to the shelter.
- A colour grade keeps the low Sun white and the regolith grey, because the Moon has no atmosphere to tint sunlight orange.
- F8 and F9 shortcuts (Studio only) force a storm or end a shift for recording the demo.

Tested in Studio:
- The guided highlights.
- Task markers on the antenna, a dusty panel and the ice nodes.
- The greenhouse lights.
- F9 and F8 by key press.
- A 15 s storm warning without the antenna, with the drone beam to the shelter and the replay label for the real X3.9 flare of 10 May 2024.

**About 17:15 – Team review of the build.** The team asked for:
- A real visual identity and custom icons instead of emoji.
- Fixes for unpleasant graphics: the habitat was washed out.
- Tutorial missions and a story mode with a partial ending.
- Truly hidden secrets.

The team chose:
- The "Lunar Sunrise" palette.
- The open Tabler icon set, recoloured.
- Their own four original collectibles (Mini Earth, Laika, cheese with a helmet, Mars potato) as hidden secrets. Each gives a reward, and all four open a fifth secret.

**18:42 – Stage 4: missions, secrets and identity.**
- **Visual identity:**
  - `Theme.luau` holds the palette and semantic colours.
  - 45 Tabler icons (MIT) uploaded and tinted in game; no emoji left in the UI.
- **Lighting:**
  - The template's second bloom and blur were removed and the interior lights limited, so the habitat is readable.
  - Outdoor light was rebalanced: grey regolith, hard shadows, black sky.
- **Missions:**
  - Four training missions: first steps, power board, base tasks, storm drill.
  - Three story chapters: arrival, storm season, something breaks.
  - The third chapter ends partially ("Mars is next... and secrets remain").
  - Free play unlocks after the story.
  - Progress is saved with DataStores once the game is published.
- **Secrets:**
  - Mini Earth on hidden ledges behind the antenna.
  - Laika in a lunar lava tube. Real science: LRO imaged lunar pits.
  - Cheese in a niche in the darkest corner of the crater.
  - Mars potato in a crawl space under the habitat.

  Each shows a myth-versus-science card and gives a reward: Earth skin for C.A.R.L., a magenta backpack, cheese-yellow rover paint, the team flag. All four open a hidden observatory with a telescope pointed at Mars ("Next mission: Mars").

Tested in Studio:
- The mission select screen.
- Training 1 completed by walking out and back in.
- Laika picked up in the lava tube with a real key press, then the card.
- The observatory door opening only after all four finds, with the teaser localized.
- The backpack and team flag rewards.

**About 19:00 – Team playtest feedback.** The team asked for:
- Compact meters on the left, and bars that move.
- A reason to link the antenna and to fetch water.
- A real, rotating Earth with phases and eclipses.
- An astronaut suit that fits any avatar.
- C.A.R.L. pointing the way and telling fun facts.
- A settings menu with an event code.
- Simpler words everywhere.

**20:42 – Stage 5: feedback built.**
- **Live meters:** air, food, radiation and water move during the shift toward the end-of-day result. Actions show at once: ice raises water and air, a leak drains air.
- **Water matters:** oxygen is made from water with electricity. Without ice the water tank empties and the air maker makes less air.
- **Antenna matters:** science only counts when it is sent to Earth. Real rovers need a radio link to send data. Without the antenna, data waits and gives no stars.
- **Real Earth:** NASA Blue Marble map (public domain) on a cheap rotating disc. The day/night line follows the Sun.
  - Roblox's Sun model does not circle the pole on its own, so the Sun follows a precomputed horizon track, as at the real lunar south pole.
  - When the Sun passes behind the Earth, an eclipse dims the base and shows Earth's red-orange ring.
  - A plain black skybox keeps the airless sky black.
- **Astronaut suit for every avatar:** bubble helmet with a gold visor, helmet lamp, chest panel, backpack (magenta with the Laika reward).
- **C.A.R.L.:**
  - A guidance beam points to the next task.
  - About 60 verified fun facts appear at random without repeats.
  - The Earth skin now uses the real Earth map.
- **Settings:** language, music and effects volume (ready for future audio), fun facts and guidance toggles, and a redeem-code box validated on the server.
- **Plain-language rewrite** of all texts for ages 7–12.

Tested in Studio:
- Compact HUD with water and the "data waiting" indicator.
- Live meters moving.
- Suit on an R15 avatar.
- Guidance beam.
- Black sky.
- Real Earth with continents and phase shading.
- Eclipse triggered with F10.

**About 21:00 – Team playtest feedback, round 2.** The team asked for:
- Start with an almost empty base: install the antenna and solar panels yourself, then grow the base with ice like a Roblox tycoon (manual ice first, then automatic production lines, upgrades, a currency, experience and skills such as a double jump).
- Keep the player's own avatar. Kids pay for skins, so the suit should only add a detailed helmet and backpack, not replace the avatar.
- A place to see and change what you wear, including turning off rewards you do not like.
- C.A.R.L. should not fly with propellers: there is no air on the Moon.
- No outline around the Earth, and remove the unexplained pink dot near the antenna (it was a secret-entrance hint pebble).
- Use what fits from team member Santiago's prototype pack (tycoon pads, pets, tools).

**Santiago's pack, evaluated.** A complete tycoon prototype: credit pads with hologram previews, seven modules, ranks, four pets, three tools, a suit.
- Kept: the four pet models (converted to data in `src/shared/PetModels.luau`, credited to him) and these ideas: build pads with a hologram of the building, buildings rising from the ground, ranks by experience, the antenna's laser-link upgrade.
- Not kept: the code itself. It duplicated working systems, used emoji, and some lines broke the science rules (C.A.R.L. "scrubbing" radiation from the suit, invented temperatures).

**23:00 – Stage 6: build and grow.**
- **Build your base:** only the habitat and water tank stand at the start. Solar panels (free), greenhouse, antenna and shelter are built on glowing pads that show a hologram first. The training missions ask for each build before using it.
- **Tycoon loop:**
  - Credits come from useful work: ice, repairs, finished days, stars and missions.
  - Experience raises the player level from 1 to 10. Each level unlocks bigger builds and gives a skill point.
  - Up to three automatic ice drills on the dark crater floor fill a silo, and a cargo robot empties it for you.
  - Each drill needs one more solar array, because machines need electricity.
  - The arrays standing are the power cells in missions.
  - The antenna upgrades to a bigger dish, then a laser link.
- **Skills:** faster walking, a bigger air tank, a double jump (a gas puff from the backpack) and faster drilling.
- **Pets:** four pets based on Santiago's models follow you. Laika and the cheese come from the secrets; the moon rabbit and the space chimp (Ham was a chimpanzee) are bought with credits.
- **Suit:** the avatar is never changed. Only a CSG-built helmet (white shell, dark reflective visor, neck ring, lamps) and a backpack with hoses are added. The event code gives a gold visor and trim.
- **Wardrobe:** pick the helmet, backpack, C.A.R.L. skin and pet, or switch rewards off.
- **C.A.R.L.:** now a small tracked rover. It drives beside you and hops with gas thrusters when you jump (thrusters work in a vacuum; propellers need air). In base mode it points to the next build you can afford.
- **Base mode:** the mission screen can be closed to explore, build and collect ice between missions.
- **New verified facts:** propellers and thrusters, laser communication, the moon rabbit legends, Ham, Laika, lunar drills and building with Moon dust. They are listed in `DATA_SOURCES.md`.

Tested in Studio (assistant-driven, real remote actions):
- New player sees only the habitat with holograms.
- Building every structure from the pads' action path.
- The silo filling from drills.
- Buying and equipping a pet that then follows the player.
- Helmet on an R15 avatar.
- The base and wardrobe panels.
- Training 1 starting with the solar build already counted.

Fixed after that playtest: the visor rendered pale grey (now dark and reflective), the helmet was too large, a tab label wrapped mid-word, and the drills were invisible from the rim (beacon masts added).

**About 23:30 – Team playtest feedback, round 3.** The team asked for:
- A longer game with more to do.
- Tools to unlock, each needed for its task (no drill, no ice): a drill, a tablet for the antenna, food from the greenhouse to eat.
- Building in steps instead of all at once.
- More to explore, with real references.
- A drivable rover, a garage for two vehicles, a landing pad and a ship to build (decoration).
- A random meteorite event to investigate.
- A lab building for equipment upgrades.
- Removing the Base menu, because players could upgrade everything while standing still.
- Starting in the lander that brought the crew, and a base layout like a modern lunar base concept (hub, tubes, glass domes, solar rows).
- More detailed pets.
- A bug: in first person the mouse could not reach the buttons of the new-secret card.

**Sunday 15 November, 00:45 – Stage 7: lander start, steps, tools, vehicles, exploring.**
- **First-person fix:** Roblox locks the mouse to the screen centre in first person. A hidden Modal button now frees it whenever a card or panel is open.
- **No Base menu:** building only happens at the pads in the world.
- **Start in the lander:** the player spawns in the arrival lander, the only shelter at first. The habitat is the first build.
- **Building in steps:** paying starts a level. Each step needs a parts crate carried from the lander's cargo bay to the pad, then "Assemble" with the wrench in hand. The structure rises from the ground step by step; the ship takes six steps.
- **Tools in the backpack bar:**
  - The wrench and drill come from the start; the brush comes with the panels, the repair kit with the habitat and the tablet with the antenna.
  - Fresh food is picked in the greenhouse and eaten for a short speed boost.
  - A task needs its tool in hand.
- **Lab:** skills, drill upgrades and pet adoption. It opens only at the lab building.
- **Garage:** a drivable moon buggy inspired by the Apollo Lunar Roving Vehicle, and an ice hauler that carries four ice cores to the water machine.
- **Landing pad and ship:** a long-term build linked to the "next mission: Mars" teaser.
- **Exploring:** five sites based on real south-pole missions and science, scanned with the tablet: a tipped-over robotic lander, the LCROSS impact crater, rolling-boulder tracks, the Lunar Prospector crash site and a peak with sunlight most of the year.
- **Meteorites:** they land at random. There is only a flash, no burning streak: the Moon has almost no air.
- **Base layout:** inspired by a lunar base concept. A hub with a dome and a tube to the greenhouse domes, the shelter as a regolith-covered mound, solar panels in rows. No logos.
- **Other changes:**
  - Pets have about 20–35 parts each, with tail and ear animations.
  - There are 15 player levels.
  - Stage 6 saves keep their base.

Tested in Studio (assistant-driven):
- Clean start in the lander with holograms of every build.
- The habitat build starting from its pad with a real key press.
- Step-by-step reveal of the half-built hub.
- Every structure built through the debug path.
- Both vehicles appearing in the garage; the buggy driving 87 studs in 3 s and staying upright.
- The space chimp pet following the player.
- A meteorite crater appearing, with C.A.R.L. pointing at it.

Found in that test: Roblox refuses to set a script source over 200,000 characters, so the 238,000-character world builder stopped Rojo live sync. It was split into smaller modules.

**02:30 – Team playtest feedback, round 4, and fixes.** The team reported, and the fixes:
- **Overlapping boxes and HUD under the tool bar:** the suit air bar and the carrying pills now stack above the Roblox hotbar. The C.A.R.L. bubble sits at the top centre while playing. The "Step 1/2" sign over a build pad is smaller and higher, so it never covers the pad's prompt.
- **Too many markers on screen:** a marker shows only when the player is close, when C.A.R.L. points at it, or when the current objective needs it.
- **Two tools with the same icon:** the repair kit now uses its own case icon (Tabler briefcase-2), different from the wrench.
- **C.A.R.L. pointed at the wrong place:** its beam now follows what it just said. "Bring parts" points at the lander's cargo bay; carrying parts or assembling points at the build pad, never the structure; cleaning points only at a dusty row.
- **Visual cue for kids:** every C.A.R.L. instruction that needs a tool shows that tool's icon between the robot and the text.
- **Assemble bug:** after delivering parts, holding E with the wrench did nothing until the player walked away. The cause: the pad's single prompt changed its hold time while it was on screen, and Roblox keeps the old hold time. Each pad now has a separate Assemble prompt. Prompt triggers also no longer share a rate limit with other actions.
- **Raw "{n}" in marker labels:** the labels now fill in the numbers.
- **Cheese pet:** the helmet that cut through its body is gone; it has a tiny antenna with a blinking light.

**04:20 – Stage 8: pressurized modules, gear, new skills, auto-run.** From the team's round 5 playtest:
- **Inside zones:** the greenhouse, the lab, the tube and the outer ring of the hub counted as outside (suit air drained, no eating). Each pressurized module now has a shaped zone (box, cylinder or dome) that counts once it is built: the whole round hub, the tube, greenhouse domes 1 and 2, the lab and the lander. A geometry check confirmed the zones overlap along the walking path.
- **Gear, bought and upgraded at the Lab (new Gear tab), switched on with a key:**
  - Air boots (B): a double jump, with gas puffing from the soles.
  - Jetpack (J): hold Jump in the air to fly up with cold gas jets, like NASA's MMU and SAFER.
  - Both share one gas tank with its own bar. It refills inside pressurized modules, and upgrades make each use cost less gas.
  - Everyone sees the boot covers and the two jetpack tanks on the suit.
- **Skills:** the jump skill became the boots; old saves get free boots at that level and their points back. New skills:
  - credits and xp: each level adds 10% of every reward, rounded up, so kids only ever see whole numbers;
  - builder: a shorter Assemble hold.
- **Auto-run:** X walks forward along the camera direction. X or any WASD key cancels it, and Shift still switches run and walk.
- **Fix found in the Studio test:** the HUD called the gear renderer before it was defined, which stopped the HUD at start.
- **Other:** the "Build your base" hint hides once the habitat and panels stand.

Tested in Studio (assistant-driven):
- Inside zones at the hub centre and edges, the tube, both domes and the lab; outside between domes.
- Gear bought at the Lab; the boots and jetpack models visible on the suit.
- Holding Space with the jetpack climbed 42 studs in 2.5 s.
- X auto-run moved 46 studs in 2 s; pressing A stopped it at once.

**About 06:30 – Team feedback, round 6.** The team asked for:
- An open world guided by main quests (like Palworld) instead of a mission menu at the start.
- A start menu with three save slots, for single-player or friends worlds.
- A Clash-of-Clans-style base hierarchy with the habitat as the town hall.
- An economy calibrated so players cannot unlock everything at once.

**07:35 – Stage 9: open-world progression.**
- **Start menu:** Continue, New game, Load game (three slots showing base level, player level, credits and date), Settings and Credits (team, data sources, AI disclosure). Then Solo or With friends.
  - Saves use Roblox DataStores, which have no cost.
  - Solo uses a reserved server in the published game.
  - The character spawns only after a slot loads.
- **Main quests:** 21 main quests and 9 side quests guide every mechanic in order. The existing training and story missions are quest steps, started from the mission console in the habitat. The quest tracker and C.A.R.L.'s beam follow the current step.
- **Base hierarchy:** the habitat is the base level, 1 to 5:
  - 1, landing camp: what one mission day needs;
  - 2, science outpost: lab, first drill, second greenhouse dome;
  - 3, mining base: cargo robot, moon buggy, bigger dish;
  - 4, explorer base: ice hauler, laser link, landing pad;
  - 5, spaceport: the ship.
  - Each habitat level looks different, and each structure level states what it improves.
- **Economy:** a new Lune simulator of a typical kid (tests/economy.luau) asserts the pacing:
  - base level 2 about 7 min, lab 16, base level 3 34, garage 44, base level 4 92, base level 5 179, ship 254;
  - income never jumps more than 2.5x between 10-minute windows;
  - the silo stays a helper, never an idle farm.
- **Debug keys:** F3 now builds in base-level order.

Tested in Studio (assistant-driven):
- The start menu, then New game, slot 1, Solo.
- Spawn in the lander.
- The first main quest shown in the tracker, with no mission menu.
- F3 builds following the base tree.
- The mission console prompt active in the habitat.

**About 08:00 – Team feedback, round 7 (playtest).** The team asked for:
- Smaller text boxes, because they covered the screen.
- A visible way to save: a player pressed Leave in a Studio test and lost the world.
- Walkable tubes between the greenhouse domes and to the lab.
- An air and food panel that stays on screen.
- Notices when a quest opens or is done, because players finished steps without seeing them.

**09:20 – Stage 10: playtest polish.**
- **Smaller boxes:**
  - The C.A.R.L. bubble is about 60% of its old size.
  - The bottom pills (carrying ice, parts, auto-run, gas) are about two thirds as tall.
- **Vitals panel:**
  - A panel in the left column is always on while playing. It shows suit air, fresh food from the greenhouse (ready, a countdown, or the energy boost) and silo ice.
  - The big suit air bar at the bottom is gone. A small pulsing "Low air" pill appears only when the air runs low outside.
- **Quest notices (QuestToasts.luau):** a card on the right says:
  - "New quest!" or "New side quest!";
  - "Done: <step>";
  - "Quest complete!" with the credits and XP earned.
  - Steps that were already done when a quest opened show as "Already done". The quest tracker flashes too.
  - Cards wait while a full-screen panel is open.
- **Saving you can see:**
  - A small "Game saved" pill appears after autosaves (at most every 30 s) and after a manual save.
  - Settings has a "Save now" button (a validated SaveNow action, rate limited for DataStores).
  - The start menu and Settings say "Your game saves by itself".
  - Studio uses a separate real DataStore when the place is published, else memory. When saves only live in memory, the pill says "Saved for this test only".
- **Walkable tubes:**
  - Dome A to dome B and hub to lab are now walk-through tubes with floors, doorways and a gentle ramp to the lab floor.
  - Pressurized zones cover the whole path.
  - Glass hatches close the doorways until the greenhouse level 2 and the lab are built.
  - Team follow-up: greenhouse dome A now sits on the hub tube's line (it was 8 studs off, so the tube met the dome at a slant). Dome B and the lab pad moved with it.
  - Team follow-up: dome A had an opening above the hub tube's doorway (the tube ended before the glass). The tube's upper slats now reach into the dome as glass, and the dome A to B link does the same. Rays cast every stud from above over both doorways found no gap.

Tested in Studio (assistant-driven):
- Start menu, New game, Solo.
- The vitals panel showed suit air, fresh food and silo ice.
- The step and "Quest complete" cards appeared with the reward, and waited behind the mission report.
- "Save now" showed the memory-only pill (the place is not published).
- Walking the hub to the lab and dome A to dome B never counted as outside.
- No script errors.

**Stage 10 follow-up: cinematic start menu.** The team asked for a start menu with live camera shots behind it, shots that also serve the 30-second video and promo material, with contrast and lighting at their best.
- **Shots (src/shared/CinematicShots.luau):** eight named shots, pure data and maths so Lune tests them (tests/cinematic.luau).
  - The Earth about to hide the Sun behind the hub, a plant close-up in dome A, the ice drills in the crater, the base from the air, the greenhouse tube, the antenna, the ship, and a pull-back.
  - The camera follows a Catmull-Rom curve through each shot's keys and slows near the ends but never stops.
  - The Earth shot is framed at run time from the Earth's position.
- **Player (src/client/Cinematic.luau):** plays the shots in a loop with a short night-coloured fade between them.
  - While it plays, C.A.R.L.'s beams, the task markers and the prompts are hidden.
  - A client-side grade adds contrast, a little warmth, bloom and sun rays, and depth of field for the close-up (not on phones). The server's own bloom is off meanwhile, so the two never stack. Lighting values are never changed.
- **Start menu:** the 2D starfield and Earth picture are gone. The shots play behind the title and buttons, with a dark gradient on the left and a light vignette. Every button and screen works as before. The rest of the game UI waits in a hidden holder while the menu is open.
- **Showcase base:** while nobody in the server has loaded a save, the world shows every structure at its top level, so the shots show a finished base.
  - Only the world changes. Saves, quests, mission rules, rewards, prompts and the player's base state keep using the real builds, and nothing announces a build.
  - When a save loads, the world drops back to the real builds at once.
  - The first player who reaches the menu gets an eclipse preview, so the first shot shows the Earth about to hide the Sun. It is skipped in a solo trip's server and when a save is already loading, so it does not land in gameplay.
  - The eclipse dims the sunlight for about 20 seconds, so the lamp-lit shots (greenhouse, tube, crater, antenna) come right after it and the sunlit wide shots after those.
- **Recording (Studio or place owner):** Ctrl+Shift+C plays the shots full screen with every other screen hidden, Ctrl+Shift+G keeps the grade on during play. A Studio command can do the same with the player attribute SBO_Cinematic ("play", "grade", "off").
- **Tested in Studio (assistant-driven):**
  - The first run showed only stars: the place streams, and a player on the menu has no character to stream around. While a player has no character, the server now sets their streaming focus to an invisible part in the middle of the base (Main.server.luau). After that every shot showed the finished base.
  - The Earth shot is now wider and closer (170 studs, field of view 24 to 20): with a long lens the 9-degree Sun filled the frame with yellow. The grade uses the values checked while recording (bloom threshold 1.35, sun rays 0.04).
  - Credits and Settings open over the shots. New game, slot 1, Solo closed the menu, gave back the normal camera, HUD and C.A.R.L.'s beam, removed the grade and lowered the world to the player's empty base. No script errors.

**Stage 10 fix: suit air while driving.** The team found that riding the moon buggy emptied the suit fast. The drain read the character's speed, so a fast vehicle counted as running (2 per second). A player in a vehicle seat now uses the resting rate (`SUIT.DRAIN_SEATED_PER_SECOND`, 0.5 per second, GAME). Tested in Studio: driving the buggy for 8 s took the suit from 93 to 89.

**Stage 10 fix: storms and radiation.** Friends played the published game in a crew of three and reported two problems: solar storms came "very, very often", and the radiation bar barely moved whether they stood inside or outside the shelter (20 to 21 at most).
- **Why storms felt so frequent.** Storms were never rolled per player. A storm day has one storm for the whole crew, set by the mission's schedule. The loop was the Storm drill (training): when any player was caught outside, the drill ran again 12 seconds after the storm ended, every time. With three kids, someone was almost always outside, so the drill never stopped (about one storm every 50 seconds).
- **Drill pacing.** A drill now repeats only after a quiet break (`STORM.RETRY_GAP_SECONDS`, 45 s, GAME), and at most `STORM.MAX_DRILLS` times in one shift (3, GAME). After that, the day ends on the clock. C.A.R.L. says when another drill is coming.
- **Staying safe counts per player.** "Stay safe during the storm" is met when at least one astronaut stayed in the shelter for the whole storm. A teammate who stays outside no longer blocks the others; the cost shows as radiation on the crew meter and in the report. On the last drill, reaching the shelter before the storm ends is enough, so the training can still be finished. If nobody reaches the shelter in three drills, the report lists the missing objective and the crew can try again.
- **Radiation you can see.** The storm dose used to be added only at the end of the day, as one step for anyone who was outside at any moment. Now the server counts exposure second by second while the particles are here (`Simulation.stormExposureStep`): each second adds the share of the crew standing outside. The live meter climbs while someone is outside and does not move for a crew in the shelter. The end of the day uses the same total, so there is no double counting. A whole storm outside adds `METERS.DOSE_PER_EXPOSED_ASTRONAUT` (raised from 18 to 22, GAME) to the crew average. Half a storm outside adds half of that.
- **Feedback.** A player outside during the storm hears "Radiation rising! Get to the shelter!" every 8 seconds (`STORM.OUTSIDE_REMINDER_SECONDS`, GAME). The storm banner says "You are outside! Radiation is rising!". The radiation row flashes red every 3 points it rises.
- **Science rules kept.** The shelter protects by mass: only time outside it adds storm dose. Dose never goes down: a player who leaves keeps their share. A false alarm (a big flare without particles) adds no dose, because exposure is only counted while particles are here.
- **Balance.** A careful crew still earns 3 stars. A crew caught outside in both storms of a free play week ends with much more radiation but still finishes (21 vs 65 points). The worst Storm drill (all three drills outside) stays out of the red zone (69 points).
- **Tests.** `tests/balance` (716 checks): exposure per second, sheltered crew gets no storm dose, the live dose rises during the storm and never goes down, the end of the day equals the live value, false alarms add nothing, drill gap and cap. `tests/missions` (706 checks): the worst drill shift ends within 6 minutes, no story storms on two days in a row, the worst training day stays out of the red zone.

**Stage 10 fix: private worlds.** In the live game, autosave worked (Santi left, pressed Continue and carried on), but Pau pressed New game and landed in Santi's world.
- **Why.** "With friends" loaded the slot in the public server, and the base there was the highest build level of every player present. So anyone matched into that public server saw the most advanced player's base. Players could not keep their own world.
- **Design (rules in `src/shared/Worlds.luau`).** Every world is its owner's save slot and runs in its own reserved server, for both modes.
  - The public server is only a lobby: the start menu and its cinematic. No slot ever loads there, so nobody spawns.
  - Continue, New game or Load, then "Just me" or "With friends", reserves a new server and teleports the player there. If the trip fails, the player goes back to the menu with a message. It never falls back to the lobby.
- **Just me.** Only the owner may stay. Anyone else who arrives is sent back to the lobby with a C.A.R.L. message.
- **With friends.** At most 4 players: the owner and 3 Roblox friends (`MISSION.PLAYERS_MAX`, GAME).
  - The world server keeps an entry in a MemoryStore hash map ("SBO_Worlds", key = owner UserId). It holds the access code, player count and base level, refreshes every 30 s, expires after 120 s, and is removed when the world closes.
  - The new start menu button "Join a friend" lists the player's Roblox friends who host an open friends world (name, base level, players n of 4).
  - Picking one opens "Pick your explorer save": the player chooses which of their own slots comes along. An empty slot starts a new explorer; nothing is ever wiped from this screen.
  - The lobby checks the friendship, that the world is open, and that it has room. The world server checks all of it again on arrival.
  - When the owner leaves, every guest's slot is saved and they go back to the menu ("Your friend left, so their base closed.").
- **Whose base.** The base (builds, builds in progress, silo) is the owner's save. It is no longer the highest of everyone present.
  - Guests keep their own credits, XP, level, skills, gear, tools, pets, wardrobe, quests, collectibles and missions, saved in their own slot.
  - A guest pays for a build with their own credits. The finished level goes into the owner's save, so a guest's own base never changes in a friend's world.
  - The cargo robot takes turns between everyone playing.
  - When the owner changes, builds in progress stop and their payers get the credits back.
- **Studio.** Reserved servers do not exist in Studio, so slots still load in the same server. The first player whose slot loads owns the world and later players are guests. The Join a friend list shows "No friends online with open worlds".
- **Tests.** `tests/worlds` (68 checks): server roles, TeleportData checks, only friends join and never past 4, solo stays private, the base is the owner's builds, stale entries count as closed, list order and cap.

**Stage 10 follow-up: 30-second trailer and one documentation file per language.**
- The trailer was cut in HyperFrames from gameplay captured in Studio (graphics at the top quality level, the cinematic grade on), with an original score synthesized in code. Captions are in English for the global submission; the storm line says "What if a storm like this reached your base?". The raw shots and the render live in `promo/`, which is git-ignored.
- `DOCUMENTATION.md` (English) and `DOCUMENTACION.md` (Spanish) gather the overview, how to play, science and NASA data, technical design, this log, and the sources, credits and licenses.

**Stage 10: learning achievements.** Team request: reward what kids understand, not only what they collect.
- **Design.** 13 achievements in `src/shared/Achievements.luau` (pure, tested in Lune). Each one is tied to an event the server already sees, so it can only be earned by doing the real thing. Each has an icon from `Icons.luau`, a title and a hint (at most 8 words) and a one-sentence "what you learned" fact (at most 16 words, REAL numbers from `MissionData.REAL` as placeholders).
- **Hooks.** `MissionService.onLearn` (new) sends science moments: ice delivered while the air maker has power, a harvest from yesterday's greenhouse power, a whole particle storm in the shelter, a real flare with no particle storm, the antenna linked. Counters use the existing `onIceDelivered` and `onPanelCleaned`. Missions, base level, the ship and scanned sites are read from the save and the world. The Sources screen sends the new `OpenSources` action, which the server accepts only for a loaded slot and at most every 5 seconds. `ExploreService.siteIds` (new) gives the number of sites.
- **Saving.** `src/server/AchievementService.luau` keeps `achievements = { unlocked, counts }` in the player's save slot (`ProgressService`, next to `quest`). An older save without the field loads as nothing unlocked. Merges never lose an unlock or lower a counter. A debug base reset keeps achievements; New game in a slot wipes them with the slot.
- **Reward.** 10 XP each (`MissionData.ACHIEVEMENTS.XP_REWARD`, GAME), no credits, so the build economy and its pacing tests do not change.
- **Screen.** An "Achievements" button joins Missions and Wardrobe in the top bar (base mode). The panel shows every achievement: unlocked ones in gold with the fact, locked ones greyed with the hint and, for counted ones, progress such as 3/10. The quest toast card shows "Achievement unlocked!" with the icon, title and +XP.
- **Roblox badges.** `MissionData.ACHIEVEMENTS.BADGES` maps each id to a badge id (0 = none yet). For ids above 0 the server checks `UserHasBadgeAsync`, then calls `AwardBadge` in pcall with one retry. Players who unlocked an achievement before its badge existed get the badge the next time their slot loads. The team creates the badges in Creator Hub and pastes the ids.
- **Tests.** `tests/achievements`: unique ids, icons exist, every text in en and es, facts quote REAL values found in `DATA_SOURCES.md`, the rules, old saves and merges. `tests/localization` now checks the achievement keys too.

**Stage 10 release (16 November 2026).** Private worlds, the storm and radiation fixes and the learning achievements were tested in Studio (menu with Join a friend, a world owned by the first player, the Fact finder achievement, live radiation rising from 0.5 to 23.1 while standing outside during the training storm) and published to the live experience. The place's server size was set to 4 through Open Cloud.

## Decisions

| Decision | Who decided | Why |
| :--- | :--- | :--- |
| Pivot from flight simulator to outpost management | Team | The challenge asks for outpost trade-offs. |
| Moon south pole, team member's mechanics | Team | Real light and shadow at the pole, water ice, a strong theme. |
| Name *Space Base Odyssey* | Team | — |
| Turn-based planning plus a real-time shift | Team, on AI recommendation | Planning is calm for young kids; the shift is the fun part. |
| Three systems, three meters | Team, on AI recommendation | The challenge advises 2–3 core resources. |
| Shelter as a decision, not a power sink | Team, on AI recommendation | Scientific accuracy: mass protects, not power. |
| Real DONKI flares, replays labelled as replays | Team, on AI recommendation | The challenge forbids presenting static data as live. |
| No NASA logos, text attribution only | Team | NASA brand rules and Space Apps AI rules. |
| Visual identity "Lunar Sunrise", Tabler icons | Team | Consistent, kid-friendly look; human-made MIT icons. |
| Four original collectibles plus an observatory | Team | The team's own first idea, kept without any agency letters. |
| Tutorial plus a 3-chapter story | Team, on AI recommendation | Teaches every mechanic, then lets kids apply it. |
| Water and antenna with real consequences | Team, on AI recommendation | Every task must unlock something or cost something. |
| Real NASA Earth map with eclipses | Team | Gives the base lighting a reason and teaches lunar eclipses. |
| Same astronaut suit for every avatar | Team | Consistent look whatever the player's skin. |
| No Space Apps or NASA shirt as the event reward | Team, on AI recommendation | NASA insignia is not allowed; an original Explorer 2026 look instead. |
| Start with an almost empty base, grow it tycoon-style | Team | More dynamic and attractive for kids; teaches what each system is for. |
| Keep the player's avatar; only a helmet and backpack | Team | Kids paid for their skins. |
| C.A.R.L. as a tracked rover with gas-thruster hops | Team, on AI recommendation | Propellers need air; thrusters work in a vacuum. |
| Space chimp instead of space monkey | AI recommendation, team to confirm | Ham, who flew in 1961, was a chimpanzee. |
| Start in the lander, build in steps, tools needed for tasks | Team | Longer, more hands-on game; teaches what each tool is for. |
| Remove the Base menu; skills only at the Lab | Team | Players upgraded everything while standing still. |
| Real south-pole missions as exploration sites | Team, on AI recommendation | Real references kids can look up. |
| Open world with main quests; three save slots; habitat as base level | Team | Progress as you play, keep progress, coherent growth. |
| Economy paced by a simulated player | Team, on AI recommendation | Stops players from unlocking everything in minutes. |
| Roblox Studio as the engine | Team | Team skills; Roblox was used in earlier Space Apps editions. |

## Testing evidence

| What | How | Result |
| :--- | :--- | :--- |
| Mission balance | `lune run tests/balance` | 716 checks pass. |
| Economy pacing | `lune run tests/economy` | 221 checks pass (simulated kid timeline). |
| Missions and the build-and-grow rules | `lune run tests/missions`, `lune run tests/base` | 609 and 307 checks pass. |
| Text length and translations | `lune run tests/localization` | All keys in en and es, at most 8 words. |
| Private worlds (who may join, whose base) | `lune run tests/worlds` | 68 checks pass. |
| Learning achievements | `lune run tests/achievements` | 227 checks pass. |
| Full mission in Roblox | Studio playtest driven by the assistant | 7 days, report reached, no script errors. |
| Live NASA data | Studio playtest | 13 flares fetched; fetch time shown. |
| Storm warning with antenna | Studio playtest, real key press | 45 s warning, flare labelled as a replay with its date. |
| Playtest with people outside the team | Planned for Sunday morning | — |

## How AI was used

The rules call this "Super Intelligence (SI)".

**What the AI did (Claude, by Anthropic, in Claude Code):**
- Research and fact checking. Each fact was re-checked by an independent AI pass that re-opened the source. Values are in `DATA_SOURCES.md`.
- An audit of the team's first design documents.
- Plan drafts and independent critiques.
- Code generation in parallel agents, with integration reviews.
- Automated tests and playtests in Studio.
- Text drafts.

**What the team did:**
- The concept and every design decision.
- Choosing the setting and the mechanics.
- Approving the numbers.
- Playtesting, publishing, the video and the presentation.

Every AI-assisted code file starts with a disclosure line. No AI-generated images, video or audio are used.

## Known issues

- New Roblox experiences only open to age-checked 16+ accounts until they pass Roblox's evaluation. Kids in the target age range cannot play the public version yet.
- The phone layout has not been checked on a real device yet.
