# Space Base Odyssey - Project documentation (English)

NASA Space Apps Challenge 2026, challenge "Build a Junior Astronaut Mission Trainer". This single document gathers all the project documentation: overview, how to play, science and NASA data, technical design, development log, and sources, credits and licenses. A Spanish version is in [DOCUMENTACION.md](DOCUMENTACION.md).

## Contents

- [1. Overview](#1-overview)
  - [What the game is](#what-the-game-is)
  - [Who it is for](#who-it-is-for)
  - [The core idea: every choice costs something](#the-core-idea-every-choice-costs-something)
  - [How the game answers the challenge](#how-the-game-answers-the-challenge)
  - [High-level project summary](#high-level-project-summary)
  - [Benefits for kids](#benefits-for-kids)
  - [The team](#the-team)
  - [Current status](#current-status)
  - [Links](#links)
  - [Evidence for judges](#evidence-for-judges)
- [2. How to play](#2-how-to-play)
  - [2.1 The start menu](#21-the-start-menu)
  - [2.2 Landing](#22-landing)
  - [2.3 The screen (HUD)](#23-the-screen-hud)
  - [2.4 C.A.R.L., the guide robot](#24-carl-the-guide-robot)
  - [2.5 Open world and quests](#25-open-world-and-quests)
  - [2.6 Missions](#26-missions)
  - [2.7 Building in steps](#27-building-in-steps)
  - [2.8 Base levels (the habitat is the town hall)](#28-base-levels-the-habitat-is-the-town-hall)
  - [2.9 Tools](#29-tools)
  - [2.10 Gear](#210-gear)
  - [2.11 Skills](#211-skills)
  - [2.12 Credits, XP, levels and pacing](#212-credits-xp-levels-and-pacing)
  - [2.13 Silo, drills and cargo robot](#213-silo-drills-and-cargo-robot)
  - [2.14 Vehicles and the garage](#214-vehicles-and-the-garage)
  - [2.15 Pets and wardrobe](#215-pets-and-wardrobe)
  - [2.16 Exploring the Moon](#216-exploring-the-moon)
  - [2.17 Secrets, collectibles and codes](#217-secrets-collectibles-and-codes)
  - [2.18 Pressurized modules and walkable tubes](#218-pressurized-modules-and-walkable-tubes)
  - [2.19 Controls](#219-controls)
  - [2.20 Team debug keys](#220-team-debug-keys)
- [3. Science and NASA data](#3-science-and-nasa-data)
  - [3.1 Learning goals](#31-learning-goals)
  - [3.2 Science rules the game keeps](#32-science-rules-the-game-keeps)
  - [3.3 How each challenge topic becomes a decision with a consequence](#33-how-each-challenge-topic-becomes-a-decision-with-a-consequence)
  - [3.4 Live space weather from NASA / CCMC DONKI](#34-live-space-weather-from-nasa--ccmc-donki)
  - [3.5 REAL and GAME numbers](#35-real-and-game-numbers)
  - [3.6 Space agency partner data and other references](#36-space-agency-partner-data-and-other-references)
  - [3.7 Real-world references behind sites, vehicles and gear](#37-real-world-references-behind-sites-vehicles-and-gear)
- [4. Technical design](#4-technical-design)
  - [4.1 Tools](#41-tools)
  - [4.2 Repository layout](#42-repository-layout)
  - [4.3 Running it locally](#43-running-it-locally)
  - [4.4 Architecture](#44-architecture)
  - [4.5 Module reference](#45-module-reference)
  - [4.6 Remotes and actions](#46-remotes-and-actions)
  - [4.7 The save system](#47-the-save-system)
  - [4.8 The world built by code](#48-the-world-built-by-code)
  - [4.9 Testing](#49-testing)
  - [4.10 Performance and safety notes](#410-performance-and-safety-notes)
  - [4.11 Accessibility](#411-accessibility)
  - [4.12 Known technical limitations](#412-known-technical-limitations)
- [5. Development log](#5-development-log)
  - [5.1 Team and roles](#51-team-and-roles)
  - [5.2 Timeline](#52-timeline)
  - [5.3 Decisions](#53-decisions)
  - [5.4 Testing evidence](#54-testing-evidence)
  - [5.5 How AI was used](#55-how-ai-was-used)
  - [5.6 Known issues](#56-known-issues)
- [6. Sources, credits and licenses](#6-sources-credits-and-licenses)
  - [6.1 Data sources](#61-data-sources)
  - [6.2 Third-party notices](#62-third-party-notices)
  - [6.3 License](#63-license)
  - [6.4 Use of Super Intelligence](#64-use-of-super-intelligence)

## 1. Overview

### What the game is

Space Base Odyssey is a cooperative Roblox game where kids aged 7 to 12 land at the Moon's south pole, build a base with their own hands and keep a crew alive through seven-day missions. The lesson behind every system is simple: in space, every choice costs something. Power given to science is power taken from air or food. Nobody gets hurt, and every mistake ends with a clear explanation.

It was built for the NASA Space Apps Challenge 2026, challenge **"Build a Junior Astronaut Mission Trainer"**, at the NASA Space Apps Querétaro 2026 local event (14 and 15 November).

### Who it is for

- **Players:** kids aged 7 to 12, alone or with friends. A mission crew has up to four players sharing one base.
- **Languages:** English and Mexican Spanish from the first screen. Every gameplay sentence has at most eight simple words, so a 7-year-old can read it.
- **Devices:** PC and touch controls.

### The core idea: every choice costs something

Each mission day starts with a calm planning phase with no clock. The crew shares a few power cells between three systems: life support, the greenhouse and science. On a normal day there are 4 cells, and each system can take at most 2, so there is never enough power to run everything at full strength. Then the crew suits up for a 150-second shift in Moon gravity: clean dusty panels, drill ice, fix leaks, align the antenna and run to the shelter when a storm comes. A report then says what happened and why.

The consequences are delayed on purpose, because that is how the real systems work. Plants take time to grow, so cutting the greenhouse today shows up as less food tomorrow. Oxygen comes from water plus electricity, so skipping ice or life support slowly empties the air. Radiation dose only ever goes up, so every storm spent outside counts for the rest of the mission.

### How the game answers the challenge

The challenge asks for a game where kids manage a lunar or Martian outpost and balance life support, radiation shielding, power, food production and communication delay. Each of these became a decision with a visible consequence.

| Challenge ask | What the player decides | What it costs |
| :--- | :--- | :--- |
| Power budgeting | How to share the day's power cells between life support, greenhouse and science. | A cell for science is a cell taken from air or food. Dust takes a cell away until someone cleans the panel. |
| Life support | Power for life support, fetching ice, fixing leaks, when to refill the suit. | Oxygen is made from water with electricity. Breathing, leaks and suit refills use air. |
| Food production | Power for the greenhouse, building more domes. | Food arrives the next day, never today. |
| Radiation shielding | Stop and hide in the shelter, or keep working outside during a storm. | Dose received outside never goes down. The shelter protects by its mass, not by power. |
| Communication delay | Spend shift time aligning the antenna with Earth. | With the link, Earth's forecasters warn the crew 45 seconds before the particles. Without it, only 15 seconds. Science data also needs the link to reach Earth. |

The warning times, the shift length and the 0 to 100 meters are game values chosen for playability. The real numbers behind them (for example, about 0.9 kg of oxygen per crew member per day, and a signal time of about 1.3 seconds from the Moon to Earth) appear on the in-game "Where our numbers come from" screen and, with sources, in `DATA_SOURCES.md`.

### High-level project summary

Space Base Odyssey is a cooperative Roblox game where kids aged 7 to 12 start in the small lander that brought them to the Moon's south pole and grow a base from nothing. They carry parts crates from the lander and assemble each building step by step with a wrench: the habitat, solar panels, a greenhouse, an antenna, a regolith storm shelter, and later a lab, ice drills, a garage with a moon buggy and an ice hauler, a landing pad and a ship for the next mission, to Mars. An open world guided by 21 main quests and 9 side quests teaches one system at a time, and the habitat grows through five base levels, from landing camp to spaceport. Crews also play seven-day missions where every morning they share limited power between life support, food and science. Solar storms replay real flares from NASA's DONKI database, labelled with their real date, including real false alarms where a huge flare brought no particle storm. Every real-world number is cited, and nobody ever gets hurt: a mission that goes wrong ends early, safely, with a report that explains why.

### Benefits for kids

- **Trade-offs they can feel.** They watch the food meter drop the day after they cut the greenhouse.
- **Real science, simply told.** Plants take time. Oxygen comes from water and electricity. A thick wall stops particles. Radiation dose adds up and never goes away. A big flare does not always bring a particle storm.
- **Teamwork.** Up to four players split the jobs: one cleans panels, one carries ice, one fixes the leak, and everyone runs for the shelter together.
- **Safe failure.** An early return is a mission result with a reason and an invitation to try again.
- **Honest data.** Kids see the date of the real flare being replayed and learn the difference between live data and an archive. Each storm is framed as "what if a storm like this reached your base".

### The team

The team of four, credited on the in-game Credits screen:

- Luis Alonzo Hernández Silva
- Ana Paula Navarro López
- Marianita Martínez Ruelas
- Santiago Alvarado Delgadillo

The roles are split this way: one member works in Roblox Studio with an AI coding assistant, and the other three own science and data, game design and playtesting, and presentation and submission. Santiago's tycoon prototype pack provided the four pet models and several ideas used in the base-building loop. The concept, every design decision, the playtests and the balance calls belong to the team. AI assistance (Claude, by Anthropic) was used for research, fact checking, code and text drafts, and is disclosed in every code file.

### Current status

- **Stage 10 is done.** It added playtest polish: smaller text boxes, an always-on vitals panel, quest notices, visible saving and walkable tubes. Two follow-up fixes aligned greenhouse dome A with the hub tube.
- **Playable in Roblox Studio.** It runs from the repository with Rojo (`rojo serve`, then Play), with HTTP requests allowed for live NASA data.
- **Not published yet.** The place has not been published to Roblox, so saves in a Studio test live only in memory ("Saved for this test only"). Real saves use Roblox DataStores once the game is published.
- **Age-check limitation.** New Roblox experiences only open to age-checked accounts aged 16 or older until they pass Roblox's evaluation for all ages. Until then, kids in the target range cannot play the public version. Judges can watch the playthrough video or run the game in Roblox Studio.
- **Still to do:** playtests with people outside the team, a phone layout check on a real device, and the public release.
- **Still to add before submitting:** the 30-second demo video link (public, no sign-in, no minors, no NASA logos), the full playthrough video link, 4 to 6 screenshots for the project page, and the frozen `game.rbxl` place file at the repository root (it is not committed yet; the working place files in `place/` are git-ignored). The demo video must also be checked for AI-generated images, video or voices: any that are added need a visible watermark.

### Links

- **Project demo:** TO ADD: 30-second video link
- **Full playthrough video:** TO ADD: link to the full, uncut playthrough video (English interface).
- **Final project (repository):** https://github.com/Gorzoomer/space-base-odyssey

### Evidence for judges

Automated tests run outside Roblox with Lune, because the mission rules live in a pure module with no Roblox code. All of them pass at the time of writing.

| What is checked | Command | Result |
| :--- | :--- | :--- |
| Mission balance: a crew that never reacts still reaches at least day 5, no fixed power plan earns 3 stars, a crew that reacts to events can, cutting the greenhouse shows up later as less food | `lune run tests/balance` | 671 passed, 0 failed |
| Training missions and story chapters | `lune run tests/missions` | 693 passed, 0 failed |
| Build-and-grow rules: build steps, base levels, skills, pets, drills, gear, quests | `lune run tests/base` | 1686 passed, 0 failed |
| Economy pacing, with a simulated typical kid | `lune run tests/economy` | 221 passed, 0 failed |
| Every text key exists in English and Spanish, at most 8 words | `lune run tests/localization` | 36091 passed, 0 failed |

Playtests in Roblox Studio covered every stage: a full 7-day mission reaching the report with no script errors, the live DONKI query (13 flares returned in the Stage 2 test, with the fetch time shown), the 45-second storm warning with the antenna linked and the flare labelled as a replay with its real date, and the Stage 10 features (vitals panel, quest cards, saving, walkable tubes). Seven rounds of team playtest feedback, and what each changed, are recorded in `DEVELOPMENT.md`.

## 2. How to play

This section follows a player through the current game (Stage 10), from the start menu to the Mars ship. Every number comes from `src/shared/MissionData.luau` (GAME tuning values unless marked REAL) or from the quest list in `src/shared/Quests.luau`. Player-facing names are the English texts from `src/shared/Localization.luau`.

### 2.1 The start menu

The first screen shows a starfield, the turning Earth (NASA Blue Marble map) and a sunrise glow on the Moon's horizon. The player has no character until a world is loaded. The buttons are:

| Button | What it does |
| :--- | :--- |
| Continue | Loads the world played last time. |
| New game | Pick one of 3 worlds. A world already in use asks first: "Start this world again?" |
| Load game | Shows the 3 world cards: base level, player level, credits, when it was last saved and how it was played. |
| Settings | Opens the Settings panel (language, volumes, C.A.R.L. options, codes, "Save now"). |
| Credits | The team, the event, the data and picture credits and the AI disclosure, all as text. |

After picking a world, the player chooses how to play:

- **Just me** (solo): "Your own Moon, just for you". In the published game the player moves to a reserved server of their own.
- **With friends**: "Friends can join your Moon base". The world loads in the current server, and friends join with Roblox's Join button. Structures are shared: each one stands at the highest level any player present has built. Credits, XP, skills, gear and pets belong to each player.

**Saving is automatic and free.** Saves use Roblox DataStores, which have no cost. The start menu and Settings say "Your game saves by itself". A small "Game saved" pill appears after an autosave (at most once every 30 seconds) and after a manual save. Settings also has a **Save now** button, checked and rate limited by the server. When saves can only live in memory (for example an unpublished place in Studio), the pill says "Saved for this test only".

**Cinematic background.** Behind the title and buttons, the menu plays live camera shots of the base in a loop: the Earth rising behind the habitat as the Sun nears it, a close-up of the greenhouse plants, the greenhouse tube, the ice drills in the crater, the antenna, the base from the air, the ship and a pull-back. While nobody in the server has loaded a world, the base is shown finished for these shots; it drops back to the player's real base the moment their world loads. The same shots were used for the 30-second trailer.

### 2.2 Landing

The player spawns inside the **arrival lander**, the only shelter at the start. Outside there are glowing build pads with holograms of the future base. The habitat is the first thing to build. C.A.R.L. greets the player: "You landed! Now let's build our Moon base."

### 2.3 The screen (HUD)

| Part | Where | What it shows |
| :--- | :--- | :--- |
| Quest tracker | Left column, top | The current main quest and open side quests, every step with "have / need". It flashes when something changes. |
| Vitals panel | Left column | Always on while playing: suit air, fresh food from the greenhouse (ready, a countdown, or the energy boost) and silo ice (once a drill stands). |
| Wallet | Left column | Credits (with a "+N" pop), player level with an XP bar, and the base level. |
| Meters | Left column, during a shift | Air, food, radiation, water and "Waiting to send" (data the antenna has not sent yet). |
| C.A.R.L. bubble | Top centre while walking | C.A.R.L.'s messages. An instruction that needs a tool shows that tool's icon. |
| Quest notices | Right side | "New quest!", "New side quest!", "Done: (step)", "Quest complete!" with the credits and XP earned. Steps already done when a quest opens show as "Already done". Notices wait while a full-screen panel is open. |
| Top bar | Top right | Settings, Missions and Wardrobe buttons. |
| Bottom pills | Above the Roblox tool bar | "Carrying ice", "Carrying parts", "Auto-run (X)", the gas tank bar (with gear owned), and a pulsing "Low air! Go inside" when the suit is low outside. |
| Build signs | Over build pads | "Step 1/2" and what is needed next. |

### 2.4 C.A.R.L., the guide robot

C.A.R.L. is a small tracked rover that drives beside the player. The Moon has no air, so it has no propellers: it rolls on treads and hops with small gas thrusters when the player jumps.

- **Colours:** cyan when all is well, orange when suit air is low, a task is urgent or a storm warning is on, red while storm particles are here.
- **Guidance beam:** a cyan beam points exactly where its words send the player: the lander's cargo bay for parts, the build pad for assembling, a dusty panel for cleaning, the mission console for a mission step, the Lab for skills or gear. Outside missions it follows the current quest step.
- **Storm beam:** an orange beam points to the shelter door until the player is inside.
- **Fun facts:** 88 checked facts appear at random without repeats.
- **Rescue:** if the suit air runs out, C.A.R.L. brings the astronaut back inside with a partial refill. Nobody dies.

Fun facts and guidance can each be switched off in Settings.

### 2.5 Open world and quests

There is no mission menu at the start. The game is an open world guided by an ordered line of **21 main quests**. **9 side quests** open along the way. A quest is done when every step is done, and its credits and XP are paid once. Ice, cleaning, silo, meteorite, food, driving and visit steps count only what happens while the quest is active. Scans, skills and collectibles count the player's lifetime totals.

#### Main quests

| # | Base level | Title | Steps | Reward |
| :--- | :--- | :--- | :--- | :--- |
| 1 | 1 | Build your Moon home | Build the habitat. Build a solar panel. Finish the mission First steps. | 10 credits, 20 XP |
| 2 | 1 | Grow your own food | Build the greenhouse. Finish the mission Share the power. Eat fresh food: 1. | 10, 20 |
| 3 | 1 | Talk to Earth | Build the antenna. Finish the mission Base chores. Clean dusty solar panels: 1. | 10, 20 |
| 4 | 1 | Get ready for storms | Build the storm shelter. Finish the mission Storm drill. | 15, 25 |
| 5 | 1 | Ice is treasure | Go to the ice crater. Bring ice home: 4. | 10, 20 |
| 6 | 1 | More power for the base | Build a second solar panel. Finish Chapter 1: New home. | 20, 30 |
| 7 | 2 | Grow your base | Make the habitat level 2. Build the Lab. Go inside the Lab. | 20, 30 |
| 8 | 2 | Learn new skills | Learn skills at the Lab: 1. Upgrade your ice drill to level 2. | 15, 25 |
| 9 | 2 | Drills that work alone | Build ice drill 1. Collect ice from the silo: 2. | 20, 30 |
| 10 | 2 | Storm season | Build a third solar panel. Finish Chapter 2: Storm season. | 25, 40 |
| 11 | 2 | Explore the Moon | Scan places to explore: 2. Scan meteorite craters: 1. | 25, 40 |
| 12 | 2 | A bigger garden | Build the second greenhouse dome. Go inside the greenhouse. Eat fresh food: 3. | 20, 30 |
| 13 | 3 | A mining base | Make the habitat level 3. Build ice drill 2. Build the cargo robot. | 30, 50 |
| 14 | 3 | Wheels on the Moon | Build the rover garage. Go to the garage. Drive a moon car. | 30, 50 |
| 15 | 3 | When things break | Finish Chapter 3: Things break. Make the antenna level 2. | 40, 60 |
| 16 | 3 | Gear up | Buy the air boots at the Lab. Learn skills: 4 in total. | 30, 50 |
| 17 | 4 | Explorer base | Make the habitat level 4. Build the ice truck bay. Bring ice home: 8. | 50, 80 |
| 18 | 4 | A laser to Earth | Make the antenna level 3. Build ice drill 3. | 50, 80 |
| 19 | 4 | A pad for ships | Build the landing pad. Scan meteorite craters: 3. | 60, 100 |
| 20 | 5 | Moon spaceport | Make the habitat level 5. Make ice drill 2 level 3. | 80, 120 |
| 21 | 5 | Next stop: Mars | Build the ship to Mars. | 100, 150 |

When every main quest is done the tracker says: "Main quests done! Find secrets and side quests."

#### Side quests

| Title | Opens after | Steps | Reward |
| :--- | :--- | :--- | :--- |
| Hidden treasures | Get ready for storms | Find hidden treasures: 4. | 40 credits, 60 XP |
| Super astronaut | Learn new skills | Learn every skill level: 15. | 60, 100 |
| Ice master | Drills that work alone | Bring ice home: 40. Collect ice from the silo: 10. | 40, 60 |
| Moon scientist | Explore the Moon | Scan places to explore: 5. | 40, 60 |
| Moon farmer | A bigger garden | Eat fresh food: 10. | 25, 40 |
| A whole week | When things break | Finish the mission Free play. | 60, 100 |
| Fly like a rocket | Gear up | Buy the jetpack at the Lab. | 40, 60 |
| Meteorite hunter | A pad for ships | Scan meteorite craters: 10. | 60, 100 |
| Ice factory | Moon spaceport | Make ice drill 1, 2 and 3 level 3. | 80, 120 |

### 2.6 Missions

Missions are quest steps. They start from the **mission console** inside the habitat or from the **Missions** button in the top bar. Each mission needs certain builds to be standing.

| Mission | Type | Days | What it teaches |
| :--- | :--- | :--- | :--- |
| First steps | Training | 1 | Step out, build the habitat and a solar panel, go back inside. |
| Share the power | Training | 1 | Build the greenhouse, share power on the board, a short 45-second shift. |
| Base chores | Training | 1 | A dust day: build and connect the antenna, clean a panel, drill and deliver ice. |
| Storm drill | Training | 1 | Build the shelter, run inside when warned, stay safe. |
| Chapter 1: New home | Story | 3 | Run the base for 3 days, deliver ice 2 times. |
| Chapter 2: Storm season | Story | 3 | Run the base for 3 days and survive a storm. |
| Chapter 3: Things break | Story | 4 | Fix the air leak and earn at least 2 stars. One big flare is a false alarm. |
| Free play | Free | 7 | The original random week, open after the story. |

Training missions never fail. Chapter 3 ends partially: "Mars is next. But secrets still hide on the Moon..."

#### The mission loop

Each mission day has three parts.

1. **Plan (no clock).** On the power board the player shares power cells between three systems:
   - **Air maker:** turns water into air with electricity.
   - **Greenhouse:** grows food, which arrives the next day, because plants take time.
   - **Science lab:** discoveries that earn stars, but only once the antenna sends them to Earth.

   Each clean, sunlit solar array gives one cell, plus one battery cell. A system takes at most 2 cells. There is never enough power for everything.
2. **Shift (150 seconds, real time).** The player walks the base in Moon gravity. Suit air drains outside (faster when running) and refills inside, using some of the base's air. Tasks, each needing its tool in hand:
   - clean dusty solar panels (brush);
   - drill ice in the shadowed crater and take it to the water machine (ice drill);
   - fix an air leak (repair kit);
   - point the antenna at Earth (tablet).

   Each ice core delivered also adds science points. Science waits on the base until the antenna sends it to Earth.
3. **Report.** The day's results and the reasons, for example "Dusty panels made less power" or "The thick dirt shelter kept everyone safe." At the end of the mission the report shows a day-by-day timeline, the stars and a "Try another plan" button.

#### Meters and events

The **air, food, radiation and water** meters move during the shift toward the end-of-day result. If air or food reaches zero, the crew gets one day of grace to fix it. If it is still empty the next day, or if radiation reaches its limit, the crew goes home early, safe, and the report explains what to try next time. Radiation dose only goes up: background cosmic rays add some every day, and being outside during a particle storm adds much more.

**Stars.** A crew that comes home safely always earns 1 star, even after an early return. A completed mission earns 2 stars with 10 science points sent to Earth and 3 stars with 18.

Day events are a calm day, dust on the panels, an air leak, or a possible Sun storm. In Free play days 1 and 2 are calm, and days 3 to 7 bring dust twice, one air leak and two Sun storm watches, in an order that changes with every new mission.

#### Storms and the shelter

Storms use real solar flares recorded by NASA's DONKI database. The storm card names the flare and its date, and an archived flare is labelled a replay ("Replay of a real Sun flare from (date)"). The game asks: what if a storm like this reached your base? These flares were observed near Earth, not at a Moon base.

- On a storm day the flare is spotted 40 seconds into the shift (12 seconds in the Storm drill), and C.A.R.L. names its real class and date.
- With the antenna connected, Earth's forecasters warn the crew 45 seconds ahead. Without it, the warning is 15 seconds. If particles come, the storm lasts 25 seconds, and anyone outside the shelter is exposed.
- The player runs to the **regolith shelter**. It protects by mass (thick Moon dirt), not by power.
- Some big flares bring no particle storm. These honest false alarms show that a big flare does not always bring a particle storm.

### 2.7 Building in steps

Building happens only at the pads in the world (there is no build menu).

1. Walk to a pad and pay (prompt "Build (N credits)" or "Build (free)"). This starts the level.
2. Take a **parts crate** from the lander's cargo bay ("Take parts crate").
3. Carry it to the pad ("Deliver parts: step N of M").
4. Hold **Assemble** with the **wrench** in hand (a 2.5-second hold, shorter with the Fast builder skill).
5. The structure rises a little with each step.

A new structure takes 3 steps, an upgrade 2. The habitat and the first solar panel take 2, a habitat upgrade (a new base level) takes 4, and the Mars ship takes 6. Every build level gives XP: 10 plus a quarter of its cost.

### 2.8 Base levels (the habitat is the town hall)

The habitat's level is the **base level**. Every structure level needs a minimum base level, and the habitat looks different at each level.

| Base level | Name | Habitat cost | What opens |
| :--- | :--- | :--- | :--- |
| 1 | Landing camp | Free | Solar panels 1-3, greenhouse 1, antenna 1, storm shelter |
| 2 | Science outpost | 15 credits | Lab, ice drill 1 (with the silo), greenhouse 2 |
| 3 | Mining base | 60 | Ice drill 1 level 2, ice drill 2, cargo robot, rover garage 1, antenna 2 |
| 4 | Explorer base | 300 | Ice drill 1 level 3, ice drill 2 level 2, ice drill 3, garage 2, antenna 3, landing pad |
| 5 | Moon spaceport | 800 | Ice drill 2 level 3, ice drill 3 levels 2-3, Mars ship |

The silo holds 20 ice at base levels 1 and 2, then 30, 45 and 60.

#### Every build

| Build | Levels and cost (credits) | Needs | What each level does |
| :--- | :--- | :--- | :--- |
| Habitat | 0 / 15 / 60 / 300 / 800 | Previous base level | Home with air inside; the base level; bigger silo. Unlocks the repair kit. |
| Solar panels | 0 / 25 / 35 | Habitat | Each level is one more array, one more power cell. Unlocks the brush. |
| Greenhouse | 10 / 50 | Solar 1 | Level 2 adds the second dome: fresh food every 60 s instead of 90 s. Unlocks fresh salad. |
| Lab | 30 | Habitat, solar 1 | Skills, tool upgrades, gear, pet adoption. |
| Antenna | 10 / 90 / 200 | Solar 1 | 2 is a bigger dish, 3 a laser link. Linking pays 0 / +3 / +6 extra credits. Unlocks the tablet. |
| Storm shelter | 15 | Antenna 1 | Thick Moon dirt blocks storm particles. |
| Ice drill 1 | 40 / 100 / 220 | Shelter, solar 1 | Digs 1 / 2 / 3 ice per minute into the silo. |
| Ice drill 2 | 120 / 200 / 350 | Drill 1, solar 2 | Same rates. Machines need electricity: one more array. |
| Ice drill 3 | 250 / 400 / 500 | Drill 2, solar 3 | Same rates. |
| Cargo robot | 140 | Drill 1 | Empties the silo for its owner every 60 s. |
| Rover garage | 90 / 220 | Lab, shelter | 1 is the moon buggy bay, 2 the ice truck bay. |
| Landing pad | 300 | Garage 1, antenna 2 | A hard floor so rockets kick up less dust. Needed for the ship. |
| Mars ship | 1000 | Landing pad | A ship for a future trip to Mars: the long-term goal (decoration). |

### 2.9 Tools

Tools sit in the Roblox tool bar. A task needs its tool in hand ("no drill, no ice").

| Tool | Comes with | Use |
| :--- | :--- | :--- |
| Wrench | Start | Assembles each build step. |
| Ice drill | Start | Digs ice cores in the crater. Lab upgrades: level 2 (60 credits, player level 3) and level 3 (150 credits, player level 5) shorten the drilling hold to 70% and then 50%. |
| Panel brush | Solar panels | Sweeps Moon dust off the panels. |
| Repair kit | Habitat | Patches air leaks. |
| Tablet | Antenna | Points the antenna and scans exploration sites and meteorite craters. |
| Fresh salad | Greenhouse | Picked in the greenhouse and eaten inside (helmets stay on outside). It gives a 20-second energy boost (faster walking) and 3 XP. |

### 2.10 Gear

Gear is bought and upgraded at the Lab (Gear tab) and switched on or off with a key. Both pieces share one **gas tank** (100) that refills inside pressurized modules. Real jetpacks such as NASA's MMU and SAFER fly with cold gas jets, because there is no air to push on.

| Gear | Key | Cost per level | Player level | Gas used |
| :--- | :--- | :--- | :--- | :--- |
| Air boots | B | 60 / 100 / 160 | 3 / 5 / 7 | 25 / 18 / 12 per double jump |
| Jetpack | J | 200 / 300 / 400 | 8 / 10 / 12 | 30 / 22 / 15 per second |

The boots give a second jump in the air at 80% of a normal jump. The jetpack climbs while Jump is held in the air. Everyone sees the boot covers and jetpack tanks on the suit.

### 2.11 Skills

Each player level gives **one skill point**. Skills are learned at the Lab. There are 15 skill levels in total, so a player at the top level (15) can have every skill at its top level.

| Skill | Effect per level | Player level for levels 1 / 2 / 3 |
| :--- | :--- | :--- |
| Fast feet | Walk and run faster | 2 / 4 / 6 |
| Big air tank | +25 suit air | 2 / 4 / 6 |
| Fast builder | Assemble hold at 80% / 65% / 50% | 2 / 5 / 8 |
| Credit boost | +10% of every credit reward, rounded up | 3 / 6 / 9 |
| XP boost | +10% of every XP reward, rounded up | 3 / 6 / 9 |

### 2.12 Credits, XP, levels and pacing

A new world starts with 25 credits. Credits and XP come only from useful work:

| Work | Credits | XP |
| :--- | :--- | :--- |
| Ice delivered by hand | 5 | 8 |
| Panel cleaned | 2 | 4 |
| Antenna aligned | 3 (plus the antenna bonus) | 4 |
| Leak repaired | 5 | 8 |
| Mission day finished (every player present) | 5 | 10 |
| Each star in the report (every player present) | 5 | 5 |
| Mission completed (first time / again) | 20 / 5 | 30 / 10 |
| Hidden collectible (first time) | 10 | 20 |
| Exploration site (first scan) | 10 | 20 |
| Meteorite crater scanned | 15 | 25 |
| Silo ice, per core | 1 | 1 |
| Parts crate delivered / build step done | 0 | 2 / 5 |

There are **15 player levels**. Total XP needed: 0, 40, 100, 180, 280, 400, 550, 750, 1000, 1350, 1800, 2400, 3100, 3900, 4800. The player level gates skills, gear, tool upgrades and pets. It does not gate structures; the base level does.

**Pacing.** `tests/economy.luau` simulates a typical kid who follows the quests, plays a mission day about every 5 minutes and never stands still to farm. It fails if the targets are missed. The current run gives:

| Milestone | Minute (typical kid) | Target |
| :--- | :--- | :--- |
| Base level 2 | 6.8 | 4-10 |
| Lab | 16.5 | 8-20 |
| Base level 3 | 33.9 | 20-40 |
| Rover garage | 44.2 | 35-70 |
| Base level 4 | 92.2 | 60-110 |
| Base level 5 | 179.1 | 150-300 |
| Mars ship | 253.9 | 150-300 |

In the same run the player reaches level 15 at about minute 135, and the main quest line ends with the ship at about minute 254. Income never jumps more than 2.5 times from one 10-minute window to the next. These are simulated minutes, not measured playtests.

### 2.13 Silo, drills and cargo robot

Automatic drills on the dark crater floor fill the **silo** while at least one player is in the server. The player walks to the silo and uses "Collect stored ice". Silo ice pays less than ice carried by hand (1 credit instead of 5), so the drills help but playing matters most, and a full silo is worth only a few minutes of drilling. The **cargo robot** empties the silo for its owner every 60 seconds. Silo claims by the robot do not count for quests.

### 2.14 Vehicles and the garage

The rover garage holds two vehicles. Use "Drive" to get in and "Bring it back" to return it.

- **Moon buggy** (garage level 1): an open two-seat car inspired by the Apollo Lunar Roving Vehicle. A friend can ride along.
- **Ice truck** (garage level 2): carries 4 ice cores. "Load ice" at the crater, then "Unload ice" at the water machine.

The camera pulls back to a chase view while driving. A flipped vehicle is put back on its wheels.

### 2.15 Pets and wardrobe

Pets follow the player and are only for looks.

| Pet | How to get it |
| :--- | :--- |
| Laika | Find the Laika secret |
| Moon cheese | Find the cheese secret |
| Moon rabbit | Adopt at the Lab: 120 credits, player level 3 |
| Space chimp | Adopt at the Lab: 200 credits, player level 7 |

The **Wardrobe** keeps the player's own avatar and adds only space gear. Slots: Helmet (Classic, Gold explorer), Backpack (Classic, Laika), C.A.R.L. (Classic, Mini Earth) and Pet (or "No pet"). Rewards can be switched off.

### 2.16 Exploring the Moon

Five **exploration sites**, scanned with the tablet ("Scan"), each show a card with a real fact:

| Site | Based on |
| :--- | :--- |
| Tipped-over robot lander | The Odysseus lander, which landed near the south pole leaning over in 2024 |
| LCROSS crash crater | LCROSS, which crashed into a dark crater in 2009 and found water |
| Rolling boulder tracks | Boulders knocked loose by moonquakes or impacts |
| Lunar Prospector crash site | Lunar Prospector, crashed into a dark crater on purpose in 1999 |
| Sunny peak | Peaks near the south pole that get sunlight for most of the year |

**Meteorites** land at random, every 4 to 7 minutes. There is only a flash, no burning streak, because the Moon has almost no air. The fresh crater stays for 5 minutes. C.A.R.L. points at it, and the tablet scans it.

**Eclipses.** The Sun circles the horizon, as at the real lunar south pole (the game sky is much faster). When it passes behind the turning Earth, the base dims and Earth shows a red-orange ring. C.A.R.L. says "Eclipse! Earth is hiding the Sun!"

### 2.17 Secrets, collectibles and codes

Four collectibles hide around the base: **Mini Earth, Laika, Moon cheese and Mars potato**. Hiding places include a crawl space, a lookout rock, a lava tube and the darkest corners. Each one opens a myth-versus-science card and gives a reward:

| Collectible | Reward |
| :--- | :--- |
| Mini Earth | A spinning Earth head for C.A.R.L. |
| Laika | A magenta air backpack and the Laika pet |
| Moon cheese | Cheese-yellow paint for the science rover and the Moon cheese pet |
| Mars potato | The team flag on the base roof |

Finding all four opens a fifth secret: a hidden **observatory** with a telescope pointed at Mars ("Next mission: Mars"). The Collection screen shows the secrets found.

**Codes.** Settings has a "Have a code?" box. The server checks the code; the codes are never sent to players. The event code gives the "Explorer 2026 gold helmet" (gold visor and trim), a look only, never a gameplay advantage.

**Learning achievements (Stage 10).** The "Achievements" button in the top bar (base mode) opens a panel with 13 achievements. Each one rewards understanding a piece of the science, and the server only unlocks it when it sees the real event. Unlocked ones show what you learned; locked ones show a hint (and progress such as 3/10). Each pays 10 XP once per save slot, with an "Achievement unlocked!" card. When the team creates a matching Roblox badge in Creator Hub, the player also gets the badge.

| Achievement | How to unlock it | What it teaches |
| :--- | :--- | :--- |
| Air from water | Deliver ice in a shift while the air maker has power | Oxygen comes from water plus electricity |
| Patient farmer | Power the greenhouse, then start the next day | Plants take time to grow (ISS lettuce: 33 days) |
| Safe behind thick walls | Stay in the shelter for a whole particle storm | The shelter protects by mass, not power |
| Not every flare brings a storm | Live through a big flare with no particle storm | A big flare does not always bring a particle storm |
| Hello, Earth! | Link the antenna to Earth | Signals take about 1.3 seconds to reach Earth |
| Ice hunter | Deliver 10 ice in total | Polar crater ice can give a base water and air |
| Panel cleaner | Clean 5 dusty solar panels | Dust blocks sunlight, so panels make less power |
| Fact finder | Open the "Real NASA data" screen | Scientists check where their numbers come from |
| Storm ready | Finish the Storm drill training | Particles can arrive in 30 minutes or less |
| Moon builder | Reach base level 3 (in your own world) | Every building costs credits, parts and time |
| Ready for Mars | Build the ship (in your own world) | A message to Mars can take up to 22 minutes |
| Moon explorer | Scan every exploration site | Explorers read the Moon's story in rocks and craters |
| Story hero | Finish the three story chapters | Real crews plan ahead: every choice costs something |

### 2.18 Pressurized modules and walkable tubes

These places count as **inside** once built: the round hub of the habitat, the hub tube, greenhouse domes 1 and 2, the Lab and the lander. Inside, suit air and the gas tank refill and fresh food can be eaten. Outside, suit air drains.

The tubes from greenhouse dome A to dome B and from the hub to the Lab can be walked through, with floors, doorways and a gentle ramp to the Lab floor. Glass hatches close the doorways until greenhouse level 2 and the Lab are built.

### 2.19 Controls

| Action | Keyboard and mouse | Touch |
| :--- | :--- | :--- |
| Move | WASD | Thumbstick |
| Run (suit air drains twice as fast) | LeftShift (switches run and walk) | Run button |
| Use a task, build, collect, scan | Hold E | Tap the prompt |
| Pick a tool | Roblox tool bar | Roblox tool bar |
| Air boots on or off | B | Boot button |
| Jetpack on or off | J | Jetpack button |
| Double jump (air boots) | Space twice | Jump button twice |
| Fly up (jetpack) | Hold Space in the air | Hold the jump button |
| Auto-run | X (X or any WASD key stops it) | Auto-run button |
| Drive | WASD in the driver seat | Thumbstick |
| Get out of a vehicle | Space | Tap jump |
| Missions, Wardrobe, Settings | Buttons at the top right | Same |
| Language | Settings (English or Spanish) | Same |

On a gamepad, A gets out of a vehicle and holding A in the air fires the jetpack. In first person the mouse is freed whenever a card or panel is open.

### 2.20 Team debug keys

These keys work only in Roblox Studio or for the place owner. The server checks every debug action again. They are for testing and recording the demo.

| Key | Effect |
| :--- | :--- |
| F2 | A meteorite lands near the player now. |
| F3 | Finish the build in progress, or build the next structure free, following the base-level order. |
| F4 | Start an eclipse now. |
| F6 | Unlock every mission and get just enough credits and XP for everything. |
| F7 | Get the next hidden collectible the player does not own yet. |
| F8 | Force today's event to a solar storm (before the shift or while planning). |
| F9 | End the current shift now. |

F1, F5, F10, F11 and F12 are not used, because Studio or Windows catch them first.

## 3. Science and NASA data

Space Base Odyssey is a game first, but every rule that touches science has to be true. The full source list, with links, is in section 6 and in `DATA_SOURCES.md`.

### 3.1 Learning goals

After playing, a child should be able to say these five ideas in their own words:

1. **Power is limited.** There is never enough for everything, so you choose, and the choice shows up later.
2. **Air comes from water.** Astronauts make oxygen from water with electricity. No water, less air.
3. **Plants take time.** Food you plant today feeds you tomorrow, not now.
4. **Thick walls protect you, and radiation adds up.** Dose never goes away, so you hide when Sun particles come.
5. **Talking to Earth needs a working link.** From the Moon a signal takes about 1.3 seconds; from Mars, up to 22 minutes.

Kids do not read these ideas in a lesson. They feel them, for example when the food meter drops the day after they cut the greenhouse.

### 3.2 Science rules the game keeps

These rules are written into `CLAUDE.md` and apply to every mechanic, line of text and fun fact.

| Rule | How the game keeps it | Real basis |
| :--- | :--- | :--- |
| The shelter protects by mass, not power. | The shelter is a regolith mound with water tanks inside. It uses no power cells. Being inside it during a particle storm keeps the dose down. An unbuilt shelter (a hologram on its pad) has no mass, so it protects nobody. | NASA-STD-3001 and NASA's OCHMO radiation brief: a storm shelter of about 10 cm water equivalent. |
| Radiation dose never goes down. | `Simulation.luau` only adds dose: a little every day for background cosmic rays, more for each astronaut caught outside in a storm. Nothing lowers it. | Dose adds up; NASA's career limit counts the total. |
| Plants take time to grow. | Greenhouse power on one day becomes food on the next. Fresh food picked in the greenhouse also needs time before the next one is ready. | NASA Veggie: the first lettuce eaten on the Space Station grew for 33 days. |
| Oxygen comes from water plus electricity. | Life-support cells run the air maker, which uses water from the tank. With too little water it makes only part of the air. Ice adds air only when the air maker has power. | NASA ISS ECLSS fact sheet: oxygen is made by splitting water with electricity. |
| A big flare does not always bring a particle storm. | Some storm days are real false alarms: a huge flare that DONKI links to no particle event. Sheltering was still the right call. | NASA / CCMC DONKI, for example the X9.0 flare of 3 October 2024. |
| DONKI events were observed near Earth. | Every storm is a replay: "what if a storm like this reached your base?" The game never says a recorded storm hit the Moon. | DONKI events are observed from near Earth. |
| The Moon has almost no air. | C.A.R.L. drives on treads and hops with gas thrusters, because propellers need air. Meteorites land with a flash and no burning streak. The sky is black and the Sun stays white and low. | NASA "The Moon's Atmosphere"; NASA Glenn; NASA Meteoroid Environment Office. |

The game also keeps the real Moon-to-Earth gravity ratio (1.62 / 9.81). The game sky runs much faster than the real one: at the real south pole the Sun circles the horizon once per lunar day (about 29.5 Earth days). The Sources panel says so.

### 3.3 How each challenge topic becomes a decision with a consequence

| Topic | Decision | Consequence | Real data behind it |
| :--- | :--- | :--- | :--- |
| Power budgeting | Each morning, how many power cells go to life support, greenhouse and science. Each clean solar array the players have built gives one cell and the battery one more, so a full base has 4. Each system takes at most 2. | A cell for science is a cell taken from air or food. Dust takes a cell away until someone cleans the panel. The board cuts science first and life support last. Each automatic ice drill needs one more solar array. | A spot on the Shackleton crater rim is sunlit about 240 days a year (LRO topography), so solar power fits the south pole. |
| Life support | Power for life support, fetching ice, fixing leaks, and when to refill the suit inside. | Life-support cells turn water into air; ice fills the tank. Breathing, an open leak and every suit refill use base air. | NASA BVAD 2022: about 0.895 kg of oxygen and 2.5 kg of water per crew member per day. LCROSS found ice in a shadowed crater. |
| Food production | Power for the greenhouse; building the second dome. | Today's greenhouse power is tomorrow's food. Cutting it looks free until the next day. | NASA Veggie: 33 days to the first lettuce meal. About 3,000 kcal per crew member per day. |
| Radiation shielding | Hide in the shelter during a storm, or keep working outside. | Everyone outside when particles arrive adds to the dose. Reaching the limit sends the crew home early. | Real DONKI flares. Chang'e-4: about 1.37 mSv a day on the Moon, against 6.2 mSv a year in the United States. NASA career limit: 600 mSv. |
| Communication delay | Spend shift time aligning the antenna with the tablet, or do other tasks. | With the link, Earth warns the crew 45 seconds before particles arrive; without it, 15 seconds. The link also sends waiting science. A bigger dish and then a laser link send more data. | 1.3 seconds Moon to Earth; 3 to 22 minutes from Mars. NASA: laser links carry 10 to 100 times more data than radio. |

The 45-second and 15-second warnings are game values. They teach a real idea: the fastest Sun particles can arrive in about 30 minutes or less, so every minute of warning matters. Science also waits on the base until the antenna sends it to Earth; unsent science earns no stars.

### 3.4 Live space weather from NASA / CCMC DONKI

DONKI is the space weather database of NASA's Community Coordinated Modeling Center (CCMC). The game reads solar flares (FLR) and solar energetic particle events (SEP).

#### How it is fetched

`src/server/SpaceWeatherService.luau` runs once when a game server starts:

1. It asks `https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR` and `.../SEP` for the last 30 days. This host needs no API key.
2. It waits at most 15 seconds and needs both answers: without particle events, a flare cannot be called a storm or a false alarm.
3. A flare "has particles" when DONKI links it to an SEP event measured by the GOES satellites. The link is read from both records, because DONKI does not always store it on both.
4. The result stays in server memory for the life of that server. The query does not repeat, so the time shown is the time of that one query.

If HTTP requests are off, a request fails or times out, or the answer cannot be read, the game uses only the saved archive and says so. The live link needs **Allow HTTP Requests** in the experience's security settings.

#### Which flare a storm replays

- Live flares of class M5 or stronger join the pool and are preferred when one fits.
- A live flare with no linked particle event becomes a false alarm only once it is at least two days old, because DONKI links particle events later.
- The first storm of a mission always brings particles, so players learn why the shelter matters before meeting a false alarm. Training and story missions can choose per storm.
- No flare repeats in a mission while another choice exists, and a flare always keeps its real particle status.

#### The saved archive

`src/shared/SpaceWeatherArchive.luau` holds 11 real X-class flares, downloaded from DONKI on 14 November 2026:

| Flare peak (UTC) | Class | Particle event near Earth |
| :--- | :--- | :--- |
| 2024-05-10 06:54 | X3.9 | Yes |
| 2024-05-11 01:23 | X5.8 | Yes (above 100 MeV) |
| 2024-05-14 16:51 | X8.7 | No (false alarm) |
| 2024-10-01 22:20 | X7.1 | No (false alarm) |
| 2024-10-03 12:18 | X9.0 | No (false alarm) |
| 2024-10-09 01:56 | X1.8 | Yes (above 100 MeV) |
| 2024-10-26 07:19 | X1.8 | Yes |
| 2025-11-11 10:04 | X5.1 | Yes (above 100 MeV) |
| 2025-11-14 08:30 | X4.0 | Yes |
| 2026-01-18 18:09 | X1.9 | Yes |
| 2026-02-01 23:57 | X8.1 | No (false alarm) |

Four of the biggest flares brought no particle storm near Earth: flare size alone does not decide the danger.

#### Live and archived, always labelled

A flare is called "live" only when it came from this server's own query, and only with that query's time.

- **During a storm,** C.A.R.L. says "Like the real {class} flare of {date}! To the shelter!" The shift screen shows "Real Sun flare, live NASA data, {date}" or "Replay of a real Sun flare from {date}". After a false alarm: "The real {class} flare of {date} brought no particles!"
- **The "Real NASA data" panel** ("Where our numbers come from") opens from the mission select screen, the power board and the mission report. It shows:
  - The status: "Live from NASA: {n} Sun flares in 30 days", the query time in UTC and the newest flare. While the query runs, or if it failed: "No live link now: using saved NASA data".
  - The archive download date (2026-11-14).
  - 18 short facts, most with a real number from `MissionData.REAL` (section 3.5).
  - One text line per source, such as "Space weather: NASA / CCMC DONKI", and a pointer to `DATA_SOURCES.md`. Roblox does not allow external links inside an experience.

In the Stage 2 Studio test the live query returned 13 flares (strongest M3.5). None reached M5, so the storm replayed the archived X5.1 flare of 11 November 2025, labelled as a replay.

### 3.5 REAL and GAME numbers

Every number lives in `src/shared/MissionData.luau` with a tag:

- **REAL:** a real-world value that must appear in `DATA_SOURCES.md` with its source. Players see REAL values only on the Sources panel and in C.A.R.L.'s lines, never inside the meters.
- **GAME:** a tuning value for playability: the 7-day mission, the 150-second shift, the 0 to 100 meters, the storm warnings, the credit costs.

#### Main REAL values

| Value | What it is | Source |
| :--- | :--- | :--- |
| 1.62 m/s² (16.5%) | Moon surface gravity | NASA Moon fact sheet (NSSDC) |
| 1.3 s | One-way signal time, Moon to Earth | NASA TM-20250003885 |
| 3 to 22 min | One-way signal time, Earth to Mars | NASA Mars Relay Network page |
| 240 days a year | Sunlight at one spot near the Shackleton rim | Mazarico et al. 2011 (LRO) |
| 25 K (about -250 °C) | Coldest Moon temperature measured, Hermite crater | NASA LRO Diviner |
| 29.5 Earth days | One lunar day and night | NASA LRO lithograph; NSSDC |
| 0.895 kg | Oxygen per crew member per day (shown as 0.9) | NASA BVAD Rev2, 2022 |
| 2.5 kg | Water to drink and cook per crew member per day | NASA BVAD Rev2, 2022 |
| 3,000 kcal | Food energy per crew member per day | NASA BVAD Rev2; CSA cross-check |
| 33 days | First Space Station lettuce, planting to meal | NASA Veggie fact sheet |
| 5.6% | Water ice by mass at the LCROSS impact site | Colaprete et al., Science, 2010 |
| 1.37 mSv a day | Dose on the lunar surface | Chang'e-4 LND, Zhang et al. 2020 |
| 6.2 mSv a year | Average dose per person in the United States | US EPA |
| 600 mSv | NASA career radiation limit | NASA-STD-3001 Vol. 1 Rev C |
| 10 cm water equivalent | Recommended storm shelter on a surface | NASA-STD-3001; NASA OCHMO brief |
| About 30 min or less | Fastest Sun particles reaching Earth | NASA "Solar storms and flares" page |
| About 8 min | A flare's light reaching Earth | NASA "Solar storms and flares" page |

A few more REAL values are not on the Sources panel but appear in C.A.R.L.'s fun facts, for example 98% ISS water recovery and Space Station radishes ready in 27 days. C.A.R.L.'s 88 fun facts come only from `DATA_SOURCES.md` rows, and a test checks that every number in them is found there.

#### How the facts were checked

`DATA_SOURCES.md` holds 199 facts: 189 verified, 9 corrected and 1 unverified. AI research gathered them, a separate AI pass re-opened every source, and the team reviews each value before it enters the game. Unverified or dropped facts never appear.

### 3.6 Space agency partner data and other references

**Canadian Space Agency (CSA).** The team read the CSA food-production resources linked by the challenge, the Deep Space Food Challenge and the Naurvik project in Nunavut, as background on growing food far from supply lines. The CSA "Eating in space" page (1,900 to 3,200 calories a day) cross-checks NASA's 3,000 kcal value. No CSA number drives a mechanic; the greenhouse rules come from NASA Veggie.

**Other references:**

- **Chang'e-4 LND experiment** (Zhang et al., 2020) and the **US EPA**: the Moon and Earth radiation doses.
- **NASA Blue Marble** (public domain): the turning Earth in the sky, on the start menu and on C.A.R.L.'s Earth skin, credited in `THIRD_PARTY_NOTICES.md`.
- **Shackleton Base: A Journey to the Moon** (board game by Fabio Lopiano and Nestore Mangone): thematic inspiration only. Nothing from it is copied.

No NASA logos, insignia or mission patches are used. Every source is credited as text.

### 3.7 Real-world references behind sites, vehicles and gear

Sites are stand-ins inspired by real places: the game never says a real lander or crash site is next to the base, and never claims that gear it invents existed.

| In the game | Real reference | What the game takes from it |
| :--- | :--- | :--- |
| Tipped-over robot lander | Odysseus (IM-1), south pole, February 2024 | It came to rest leaning. |
| LCROSS crash crater | LCROSS impact in Cabeus crater, 9 October 2009 | It found water in a shadowed crater. |
| Rolling boulder tracks | LRO camera images | Loose boulders roll and leave tracks. |
| Lunar Prospector crash site | Planned crash near the south pole, 31 July 1999 | Crashed on purpose to look for ice. |
| Sunny peak | Shackleton crater rim | Some peaks get sunlight most of the year. |
| New impact crater (random) | NASA Meteoroid Environment Office; LRO | A flash with no burning streak; new craters keep appearing. |
| Moon buggy and ice truck | Apollo Lunar Roving Vehicle | Wire wheels without air, grip in low gravity, about 16 km/h. |
| Landing pad | NASA rocket exhaust studies; Apollo 12 and Surveyor 3 | Exhaust blasts dust and rocks; a pad stops the spray. |
| Tall solar arrays | NASA vertical solar array projects | The polar Sun stays low, so panels stand tall. |
| Automatic ice drills | PRIME-1 / TRIDENT drill, 2025 | A 1-meter drill was tested near the south pole. |
| C.A.R.L.'s hops, air boots, jetpack | NASA rocket pages; MMU (1984) and SAFER | Gas jets work without air. The boots and the Moon jetpack are game inventions. |
| Moon hops | Apollo Lunar Surface Journal; Apollo 16 | Astronauts mostly loped; John Young jumped about 70 cm. |
| Building with Moon dust | NASA MMPACT | Moon dust could become pads, roads and shelters. |
| Pets | Laika (1957); Ham the chimpanzee (1961); moon rabbit stories | Gentle facts; the space pet is a chimp because Ham was one. |

Each reference is a row in the Stage 6 to 8 sections of `DATA_SOURCES.md`.

## 4. Technical design

This section explains how Space Base Odyssey is built, how to run it, and how the code is organised and tested. It describes the game as it stands at Stage 10 (build `0.10.0-stage10` in `src/shared/Version.luau`).

### 4.1 Tools

| Tool | Version | What it is used for |
| :--- | :--- | :--- |
| Roblox Studio | current | Engine, play testing, publishing |
| Luau | strict mode | Every code file starts with `--!strict` and an AI (SI) disclosure line |
| Rojo | 7.7.1 | Syncs the files in this repository into Studio, and builds a place file |
| Lune | 0.11.1 | Runs the test suites outside Roblox |
| Roblox Studio MCP server | - | Lets the AI assistant start Play mode and read the console during assistant-driven playtests |
| Git and GitHub | - | Version control and the public repository |
| Claude (Anthropic), in Claude Code | - | AI assistance, disclosed in section 6.4 |

The files in the repository are the source of truth. Scripts are never edited inside Studio, and the world is built by code, not by hand-placed parts. No Toolbox or Marketplace assets are used.

### 4.2 Repository layout

| Path | Contents | Synced to |
| :--- | :--- | :--- |
| `src/shared` | Mission rules, numbers, network contract, quests, text, icons, theme | `ReplicatedStorage.Shared` |
| `src/server` | World builder, services, live NASA data, saves | `ServerScriptService.Server` |
| `src/client` | Interface, guidance, C.A.R.L., movement helpers | `StarterPlayer.StarterPlayerScripts.Client` |
| `tests` | Five Lune test suites | not synced |
| `default.project.json` | Rojo project file (the three mappings above) | - |
| `DATA_SOURCES.md` | Every real-world number with its source | - |
| `THIRD_PARTY_NOTICES.md` | Licences of third-party assets (Tabler Icons, NASA Blue Marble map) | - |
| `DEVELOPMENT.md` | Development log, decisions, testing evidence, use of AI | - |
| `README.md` | Short introduction, controls, status and how to run it | - |
| `SUBMISSION.md` | Drafts of the Space Apps project page fields | - |
| `CLAUDE.md` | Project rules for AI coding assistants | - |
| `LICENSE` | Apache License 2.0 | - |

### 4.3 Running it locally

1. Install Rojo 7.7.1 and its Roblox Studio plugin.
2. Open an empty Baseplate place in Roblox Studio.
3. Enable **Game Settings > Security > Allow HTTP Requests**. The live NASA space weather query needs it. Without it the game falls back to the saved archive.
4. Run `rojo serve` in the repository folder and press **Connect** in the Rojo plugin.
5. Press **Play**.

To check that the project still builds into a place file:

```
rojo build default.project.json -o <temp>.rbxl
```

To run the tests (from the repository folder):

```
lune run tests/balance
lune run tests/missions
lune run tests/base
lune run tests/economy
lune run tests/localization
```

### 4.4 Architecture

#### Server authoritative

The server owns the game state: the mission phase, the meters, the builds, the credits and the saves. A client never changes the state directly. It only sends a `Types.Action` table through one RemoteEvent, and the server checks every action before it acts on it (the phase is right, the player owns the item, has the credits, has the tool in hand, is close enough to the prompt, and so on). The server answers with snapshots and per-player state.

#### Pure, testable rules

The game rules that matter most live in pure Luau modules with no Roblox instances, so they run unchanged in Roblox and in Lune:

- `Simulation.luau`: the mission day (begin day, planning, shift result, end day) and the live meters during a shift.
- `BaseBuild.luau`: credits, experience, player level, build costs and gates, skills, pets, gear and drills.
- `Missions.luau` and `Quests.luau`: the mission list and the quest line, as data plus small helpers.
- `Localization.luau` and `PetModels.luau`: text and pet shapes as plain data.

#### One source of numbers

Every number the game uses lives in `src/shared/MissionData.luau`, grouped in tables such as `REAL`, `WORLD`, `MISSION`, `POWER`, `METERS`, `WATER`, `SCIENCE`, `SUIT`, `STORM`, `BASE` and `EVENTS`. Each value is tagged **REAL** (with the `DATA_SOURCES.md` section it comes from) or **GAME** (a tuning value chosen for playability). Two examples: the Moon's surface gravity of 1.62 m/s² is REAL; the 150-second shift is GAME. Roblox's default gravity of 196.2 studs/s² stands for Earth, so the Moon uses 32.4 studs/s², which keeps the real Moon-to-Earth ratio (GAME, derived).

#### Text and languages

All player-facing text travels as localization keys and is translated on the client by `Localization.luau`. English is the default and Mexican Spanish is the second language. Gameplay strings have at most 8 words, in words a 7-year-old understands. A few longer kinds of text have their own limits, all checked by the tests: Sources screen lines (`fact.`, `src.`) up to 10 words, and cards, mission texts, story texts, fun facts, pet facts and exploration facts up to 16.

#### Visual identity "Lunar Sunrise"

`Theme.luau` holds the palette (night blue, cyan, orange, lime, magenta, cream, plus derived red and gold) and semantic roles (`Theme.ROLE`, for example `accent`, `warning`, `danger`, `good`, `reward`). Code uses roles, not raw colours, for UI, lights and base accents. `Theme.FONT` sets two fonts: Fredoka One for titles and buttons, Gotham Bold for body text. The only image assets are 68 white Tabler icons (MIT licence), listed in `Icons.luau` and tinted in game with Theme colours, plus the public-domain NASA Blue Marble Earth map and a near-black skybox face made by the team. There is no emoji anywhere in the UI.

#### Space weather data

`SpaceWeatherService` asks NASA / CCMC DONKI at server start for solar flares (FLR) and solar energetic particle events (SEP) of the last 30 days, with a 15-second budget for both requests. A flare "has particles" only when DONKI links it to a particle event measured by the GOES satellites. Only flares from this server's own successful query are labelled "live". Everything else comes from `SpaceWeatherArchive.luau` (real X-class flares downloaded from DONKI) and is labelled "archive". Storms are always replays framed as "what if a storm like this reached your base", never as an event that hit the Moon. A fresh live flare with no linked particle event is only used as a "false alarm" once it is at least two days old, because particle links can arrive later.

### 4.5 Module reference

#### Shared modules (`src/shared`)

| Module | Job |
| :--- | :--- |
| `BaseBuild` | Pure build-and-grow rules: credits, XP, levels, costs, habitat gates, skills, pets, gear, drills |
| `Icons` | Asset IDs of the Tabler icons and the Earth map |
| `Localization` | Every player-facing string in English and Spanish, looked up by key |
| `MissionData` | Every number in the game, tagged REAL or GAME |
| `Missions` | Training missions, three story chapters and free play, as data |
| `PetModels` | Part data for the four pets, based on a team member's designs |
| `Quests` | Main and side quests as data, with pure helpers |
| `Simulation` | Pure mission rules for one day and the live meters |
| `SpaceWeatherArchive` | Saved real X-class flares from DONKI |
| `Theme` | "Lunar Sunrise" palette, roles and fonts |
| `Types` | Network contract: snapshots, state types, actions, remote names |
| `Version` | Build identifier, used to confirm that Rojo sync reached Studio |

#### Server modules (`src/server`)

| Module | Job |
| :--- | :--- |
| `Main.server` | Entry point: builds the world, creates remotes, starts the services, spawns players after a save slot loads |
| `BaseService` | Building and growing the base in steps: build pads, parts crates, credits, XP, skills, Lab purchases, silo |
| `Codes` | Redeem codes for event cosmetics; server only, so players cannot read them |
| `CrewService` | Suit oxygen per player, pressurized zones, carried ice, C.A.R.L. rescue to the lander |
| `ExploreService` | Exploration site scans with the tablet and random meteorite impacts |
| `MissionService` | The mission loop: phases, power allocation, shift tasks, storms, action dispatch |
| `PetService` | Builds the equipped pet and moves it after its astronaut |
| `ProgressService` | Saves: three slots per player, meta record, migrations, autosave, "Save now", solo teleport |
| `QuestService` | Tracks main and side quests from real events and pays each reward once |
| `SpaceWeatherService` | Live DONKI query with the archive as backup, and flare choice for storms |
| `SuitService` | EVA helmet and life-support backpack welded over the player's own avatar, plus gear models |
| `ToolModels` | Part models of the tools: wrench, ice drill, brush, repair kit, tablet, salad tray |
| `ToolService` | Gives unlocked tools, checks a tool is in hand, handles eating greenhouse food |
| `VehicleModels` | Part models and physics rigs of the moon buggy and the ice hauler |
| `VehicleService` | Garage bays, taking and returning vehicles, flip recovery, the hauler's ice |
| `WorldBuilder` | Builds the south-pole base and its build machinery; uses the World* modules below |
| `WorldParts` | Layout anchors, palette, shared build state and part helpers |
| `WorldSecrets` | Hidden places, the four collectibles, the team flag and the sealed observatory |
| `WorldSites` | Lab, garage, landing pad and ship models, five exploration sites, meteorite craters |
| `WorldSky` | Moon gravity, lighting, black sky, the Earth, Mars, stars, the Sun's horizon track and eclipses |
| `WorldStructures` | Ice drills, conveyor, silo, cargo robot, build pads and holograms, the lander, construction steps, crates |

#### Client modules (`src/client`)

| Module | Job |
| :--- | :--- |
| `Main.client` | Entry point: builds the UI, listens to the server, shows the right screen |
| `BasePanel` | Lab panel: skills, gear, tool upgrades and pets; opens only at the Lab |
| `CarlDrone` | C.A.R.L., the tracked helper rover, with its guidance beam and shelter beam |
| `Collection` | Collectibles screen and the myth-versus-science find card |
| `DemoKeys` | F-key shortcuts for testing and recording, Studio or place owner only |
| `ExploreCard` | Card shown after scanning a site or a meteorite crater |
| `FunFacts` | C.A.R.L.'s short true facts, from a shuffle bag with no repeats |
| `Gear` | Air boots (double jump) and jetpack, their keys, touch buttons and gas tank |
| `Hud` | Shift HUD, always-on vitals panel, wallet, carried ice and pills |
| `Markers` | Floating task markers, shown only when they matter |
| `Messages` | C.A.R.L.'s speech bubble with message and tip queues and tool badges |
| `Meters` | Air, food, radiation and water bars in row and column layouts |
| `MissionSelect` | The habitat's mission console: training, story and free play cards |
| `Movement` | Shorter prompt hold times from the drill level and the builder skill |
| `Objectives` | Mission objectives checklist and the quest tracker |
| `Onboarding` | Guided tips and power-board highlights that never block play |
| `PowerBoard` | Planning overlay where the crew shares power cells between systems |
| `Prompts` | Localizes world prompts and signs from their key attributes |
| `QuestToasts` | "New quest", "Done" and "Quest complete" cards on the right side |
| `Report` | End-of-mission report with stars and a day-by-day timeline of causes |
| `Rewards` | Client-side collectible rewards, such as opening the observatory door |
| `SaveIndicator` | The "Game saved" pill after each save |
| `Settings` | Language, volume, C.A.R.L. options, redeem code, "Save now" |
| `Sources` | "Real NASA data" panel: live or archive status, real facts, source credits |
| `Sprint` | Run toggle, speed bonuses and auto-run |
| `StartMenu` | First screen: Continue, New game, Load game, Settings, Credits, then solo or friends |
| `Store` | Client state: latest snapshot, progress, base state, slots, language, settings |
| `Ui` | Shared UI building blocks: scaled root, panels, labels, buttons, bars, tinted icons |
| `VehicleClient` | Driving input, chase camera and the vehicle panel |
| `Wardrobe` | Choose helmet, backpack, C.A.R.L. skin and pet |

### 4.6 Remotes and actions

The server creates its RemoteEvents in `ReplicatedStorage.Remotes`. Their names are defined once in `Types.Remotes`.

| Remote | Direction | Carries |
| :--- | :--- | :--- |
| `Action` | client to server | `Types.Action`, the only way a client asks for anything |
| `Snapshot` | server to all | Full mission state, sent on every change and to late joiners |
| `PlayerStats` | server to one | That player's suit and field values |
| `AssistantMessage` | server to client | A C.A.R.L. line as a localization key with parameters |
| `Progress` | server to one | Completed missions, collectibles, cosmetics |
| `Collected` | server to one | A collectible pickup, right after it happens |
| `BaseState` | server to one | Credits, XP, builds, skills, tools, gear, pets, quest tracker |
| `Explore` | server to one | A site or meteorite scan result |
| `Slots` | server to one | The three save slots for the start menu |
| `Saved` | server to one | A notice after each save of that player's slot |

Actions fall into groups:

- **Mission:** `SetCells`, `StartMission`, `StartShift`, `Restart`.
- **Player settings:** `SetLanguage`, `RedeemCode`.
- **Saves:** `ChooseSlot`, `RequestSlots`, `SaveNow` (handled by `ProgressService`).
- **Base:** `Build`, `LearnSkill`, `Equip`, `BuyPet`, `ClaimSilo`, `UpgradeTool`, `BuyGear`, `ToggleGear` (validated by `BaseService`).
- **Debug:** `DebugMeteor`, `DebugBuildNext`, `DebugForceEvent`, `DebugEndShift`, `DebugEclipse` and others. They are accepted only in Studio or from the place owner, and are used for testing and recording the demo.

`MissionService` limits each player to 20 actions per second. Slot and save actions have their own limits in `ProgressService` (one slot list request and one "Save now" request per second), and a redeem code can be tried once every 2 seconds.

### 4.7 The save system

`ProgressService` keeps each player's progress in a Roblox DataStore named `SBO_Progress_v1`.

- **Three slots.** Each player has three save slots ("worlds"), keyed `p_<userId>_s<slot>`. A slot holds completed missions, collectibles, cosmetics and the base record (credits, XP, builds, skills, tools, gear, pets, what the player wears, scanned sites and quest progress).
- **Meta record.** `p_<userId>_meta` summarises the slots for the start menu (used or empty, base level, player level, credits, last save time, solo or friends) and remembers the last slot. Event cosmetics are account-wide and live here.
- **Old saves.** The save from before slots (`u_<userId>`) is never deleted and becomes slot 1. Saves from earlier stages are migrated on load so nobody loses their base.
- **No character until a slot loads.** The player spawns only after choosing a slot, so nothing is saved for a player who has not picked one.
- **Solo and friends.** In a published game, "Just me" moves the player to a new reserved server. If the teleport fails, the slot loads in the current server. "With friends" loads in the current server.
- **Autosave.** A changed slot is saved at most once every 10 seconds. The meta record is saved at most every 60 seconds. A safety check every 60 seconds schedules anything still unsaved.
- **Merging.** A save only adds to what is stored, so two servers saving the same slot do not lose progress. New Game and the debug reset are the only writes that replace.
- **Leaving.** A player who leaves counts as a save in flight at once, and `BindToClose` waits for it (up to 25 seconds on a live server).
- **"Save now".** The Settings button sends `SaveNow`. The server writes as soon as the DataStore allows one write per key (about every 6 seconds) and confirms on the `Saved` remote. The client shows "Game saved"; autosave notices show at most once every 30 seconds.
- **Studio behaviour.** If the place is published, Studio uses a separate store, `SBO_Progress_v1_Studio`, so debug credits never reach live saves. One probe read decides; if DataStores do not answer within 8 seconds, memory is used. In an unpublished place, saves live in memory and are lost when Play stops, and the pill says "Saved for this test only". A workspace attribute, `SBO_StudioDataStores`, can force memory (`false`) or the live store (`true`).
- **Limits on stored values.** Credits and XP read from storage are clamped, so a damaged record cannot break the game.

### 4.8 The world built by code

`WorldBuilder.build` creates the whole south-pole base from plain Parts when the server starts: terrain features, the crater with ice, the solar ridge, the arrival lander, build pads with holograms, pressurized zones, exploration sites and secrets. Nothing is placed by hand in Studio.

Roblox refuses to set a script's source when it is longer than 200,000 characters. During Stage 7 the world builder grew to about 238,000 characters, and Rojo live sync stopped working for it. It was split into sibling modules:

| Module | Part of the world |
| :--- | :--- |
| `WorldParts` | Layout anchors, palette and part helpers shared by the others |
| `WorldSky` | Environment: gravity, lighting, sky, Earth, Sun track, eclipses |
| `WorldStructures` | Build-and-grow structures, the lander and construction steps |
| `WorldSecrets` | Hidden places and collectibles |
| `WorldSites` | Lab, garage, landing pad, ship, exploration sites, meteorites |

`WorldBuilder.luau` itself is now about 142,000 characters, and the largest other file, `Localization.luau`, is about 118,000. Both are under the limit.

Some world details carry science rules. The Sun follows a precomputed track along the horizon, as at the real lunar south pole, because Roblox's own Sun model does not circle the pole. The sky stays black because the Moon has no atmosphere. Meteorites land with a flash and dust but no burning streak. The shelter is a mound covered in regolith, because mass protects from radiation, not power.

### 4.9 Testing

All five Lune suites are pure: they load the shared modules directly and need no Roblox. Current results (all pass, 0 failed):

| Suite | Command | Checks | What it proves |
| :--- | :--- | :--- | :--- |
| Localization | `lune run tests/localization` | 36091 | Every key exists in English and Spanish with the same placeholders; word limits; no emoji or symbols outside Latin text; no technical jargon in gameplay text; fun facts do not repeat and only use numbers found in `DATA_SOURCES.md`; source files use only known keys |
| Base | `lune run tests/base` | 1686 | Build data is well formed; XP and the 15 player levels; costs, requirements and habitat gates; shared builds take the highest level; skills, pets, drills, steps, tools, gear, save migration, the habitat tree and quests |
| Missions | `lune run tests/missions` | 693 | Mission ids, schedules and objectives are valid; a careful crew can finish every story chapter; a training day never empties a meter; needed builds exist and can be paid for from mission rewards; tasks come after the build that unlocks their tool |
| Balance | `lune run tests/balance` | 671 | "No choice is free": a passive player still reaches day 5; no fixed plan earns 3 stars; reacting to events can earn 3 stars; cutting the greenhouse shows up as less food later; no ice makes air fall faster; no antenna means science waits |
| Economy | `lune run tests/economy` | 221 | A simulated kid player reaches each base level inside the team's pacing targets; income never jumps more than 2.5 times between 10-minute windows; automatic drills stay a helper, not an idle farm |

Besides the Lune suites, every stage was played in Studio by the AI assistant using real key presses and remote actions, with the console checked for script errors. These playtests are listed in `DEVELOPMENT.md`. Playtests with people outside the team are still to come.

### 4.10 Performance and safety notes

- **Small network updates.** During a shift the snapshot with live meters is pushed at most about four times per second. Pets move only their root part about 20 times per second and turn their joints with `Motor6D`, so very little data is sent.
- **Cheap visuals.** The helmet shell is made once with CSG at server start, cached and cloned per character (plain balls are used if CSG fails). Pets never collide, block rays or cast shadows. The Earth is a cheap rotating disc. Task markers show only when the player is near, when C.A.R.L. points at them, or when the current objective needs them.
- **Fault isolation.** Each service after the core is started inside `pcall`, so a broken piece is reported with a warning and never stops the server.
- **Untrusted clients.** Every action is checked on the server. Redeem codes live only on the server. Debug actions work only in Studio or for the place owner. Builds check level, credits, requirements, ownership and distance.
- **Honest data.** The live label appears only when this server's DONKI query succeeded. Otherwise the archive is used and labelled as such.
- **Client-owned movement.** Roblox gives the client control of its own character. The double jump, the jetpack thrust, running speed and shorter prompt holds are therefore applied on the client, using values the server sets as player attributes.

### 4.11 Accessibility

- **Two languages.** The EN and ES buttons in the Settings panel (also reachable from the start menu) switch between English and Spanish at any time. The choice is sent with `SetLanguage`, and world prompts and signs update at once.
- **Plain words.** Gameplay text is short (at most 8 words) and avoids jargon, and the tests enforce it.
- **Icons with colour.** Meters show an icon, a label and a zone icon as well as the bar colour, and C.A.R.L. shows the icon of the tool a task needs.
- **Touch layout.** On touch screens there are buttons for running, auto-run and the gear (boots and jetpack), placed near the jump button. The save pill and quest cards are positioned so they do not cover Roblox's own buttons.
- **Scaled UI.** The interface is designed for a 720-unit tall screen, and a `UIScale` maps it to the real screen height, so it keeps its proportions on phones and large screens.
- **First person.** Roblox locks the mouse to the screen centre in first person. A hidden modal button frees it whenever a card or panel is open.
- **Calm guidance.** Tips never block play, and fun facts and C.A.R.L.'s guidance beam can be switched off in Settings.

### 4.12 Known technical limitations

- **Age gate.** New Roblox experiences open only to age-checked accounts aged 16 or older until they pass Roblox's evaluation. Kids in the target age range cannot play the public version yet.
- **Roblox needs an account and an install.** It is not a browser game without sign-in, which is why the video and the Studio place file matter for judges.
- **Phones.** The phone layout has not been checked on a real device yet.
- **One base per server.** Gravity and lighting are global in Roblox, so each server runs one shared base.
- **Meters are game units.** Air, food and radiation run from 0 to 100 so kids can read them. The real values are shown separately on the Sources panel.
- **The Moon's signal delay is short.** At 1.3 seconds, the delay itself is not a problem on the Moon, so the game makes the antenna link the decision and compares it with Mars, where it would be 3 to 22 minutes.
- **Sound in vacuum.** There is no sound in space. Outside, world sounds are soft and muffled, as if felt through the suit; radio beeps stay clear. Inside modules sounds are normal. Music is not part of the world.
- **Live data needs HTTP.** Without "Allow HTTP Requests", or if DONKI does not answer within 15 seconds, the game uses the archive. A flare is only replayed as a false alarm once its particle status has had two days to settle.
- **Saves in Studio.** In an unpublished place, saves live in memory and are lost when Play stops. Solo reserved servers work only in the published game.
- **DataStore pace.** Roblox allows about one write per key every 6 seconds, so a "Save now" may wait a few seconds.
- **Shared builds.** Builds in a server stand at the highest level any present player has built. When that player leaves, the structures drop to the level of the players still there.
- **Local-only effects.** Some rewards, such as the opened observatory door and C.A.R.L.'s Earth skin, exist only on that player's client.
- **No external links.** Roblox does not allow links that leave the experience, so sources are credited as text (for example "NASA / CCMC DONKI").
- **Script size.** Roblox's 200,000-character limit on script source means large modules must stay split.

## 5. Development log

How Space Base Odyssey was built during NASA Space Apps 2026 (14–15 November, Querétaro local event). It records what was decided, by whom, what was tested and how AI was used. Times are local (UTC−6).

### 5.1 Team and roles

A team of four:
- One member works in Roblox Studio with an AI coding assistant.
- The other three own science and data, game design and playtesting, and presentation and submission.
- The concept, design decisions, playtests and balance calls belong to the team.

### 5.2 Timeline

#### Saturday 14 November

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
- **Settings:** language, music and effects volume, fun facts and guidance toggles, and a redeem-code box validated on the server.
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

#### Sunday 15 November

**00:45 – Stage 7: lander start, steps, tools, vehicles, exploring.**
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
  - "Done: &lt;step&gt;";
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

### 5.3 Decisions

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

### 5.4 Testing evidence

| What | How | Result |
| :--- | :--- | :--- |
| Mission balance | `lune run tests/balance` | 671 checks pass. |
| Economy pacing | `lune run tests/economy` | 221 checks pass (simulated kid timeline). |
| Missions and the build-and-grow rules | `lune run tests/missions`, `lune run tests/base` | 693 and 1686 checks pass. |
| Text length and translations | `lune run tests/localization` | 36091 checks pass: all keys in en and es, at most 8 words. |
| Full mission in Roblox | Studio playtest driven by the assistant | 7 days, report reached, no script errors. |
| Live NASA data | Studio playtest | 13 flares fetched; fetch time shown. |
| Storm warning with antenna | Studio playtest, real key press | 45 s warning, flare labelled as a replay with its date. |
| Playtest with people outside the team | Planned for Sunday morning | — |

### 5.5 How AI was used

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

Every AI-assisted code file starts with a disclosure line. No AI-generated images or video are used. The music and sound effects are synthesized by the team's own code (written with AI assistance, no generative audio model), and five effects mix in edited CC0 recordings.

### 5.6 Known issues

- New Roblox experiences only open to age-checked 16+ accounts until they pass Roblox's evaluation. Kids in the target age range cannot play the public version yet.
- The phone layout has not been checked on a real device yet.

## 6. Sources, credits and licenses

This section collects every data source, every third-party credit and the license of Space Base Odyssey. Subsection 6.1 reproduces `DATA_SOURCES.md` in full: every number the game shows to players must appear there, and every REAL value in `src/shared/MissionData.luau` points back to one of its rows. Subsection 6.2 reproduces `THIRD_PARTY_NOTICES.md` in full. Subsection 6.3 summarises the license, and subsection 6.4 is the "Use of Super Intelligence" disclosure required by the Space Apps rules.

### 6.1 Data sources

The text below is `DATA_SOURCES.md` as it stands in the repository. Only the heading levels were shifted to fit this document.


Every number shown in Space Base Odyssey must come from this file. If a value is not here, it is not shown to players.

- **Compiled:** 14 November 2026, during NASA Space Apps 2026.
- **Method:** facts were gathered with AI research assistance (Claude, Anthropic). Each fact was then re-checked by an independent AI verification pass that re-opened the cited source. The team reviews every value before it goes into the game.
- **Totals:** 199 facts. 189 verified, 9 corrected during verification, 1 unverified. (The 14 facts of the Stage 6 section were added on 14 November 2026, the 17 facts of the Stage 7 section and the 5 facts of the Stage 8 section on 15 November 2026; dropped candidates are listed in each section's notes and are not counted.)

#### Status legend

| Status | Meaning | May appear in the game? |
| :--- | :--- | :--- |
| Verified | The verifier opened the source and the value matched. | Yes |
| Corrected | The first value was wrong; the row shows the corrected value and source. | Yes |
| Unverified | Not confirmed in any opened source, or not found. | No |

#### Rules for using this data in the game

1. **Real value or game parameter.** Every constant in `src/shared/MissionData.luau` is labelled either as a real value (with the row of this file it comes from) or as a game parameter (a tuning number chosen for playability).
2. **Live versus archived.** Archived data is never presented as live. The in-game sources screen states whether space weather came from a live query, with the fetch time, or from the archive, with the event date.
3. **Observed near Earth.** DONKI events are observed from near Earth. The game says "What if a storm like the one on (date) reached your base?", never that the event hit the base.
4. **Frozen feeds.** The public Mars weather feeds (InSight, Perseverance, Curiosity) stopped updating years ago and must be labelled as archived. See the power and environment section.
5. **Attribution.** Credit sources as text inside the game (for example "Space weather: NASA / CCMC DONKI"). Roblox does not allow external links inside an experience, so URLs live in this file and in the README. No NASA insignia, logos or mission patches anywhere.

#### Space weather endpoint check (14 November 2026, 11:58 UTC-6)

| Endpoint | Result |
| :--- | :--- |
| `https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=...&endDate=...` | HTTP 200, JSON, no API key needed. Use this one. |
| `https://api.nasa.gov/DONKI/FLR?...&api_key=DEMO_KEY` | HTTP 429 (rate limit exceeded). A registered key may work; not tested. |
| `https://kauai.ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?...` | Timed out. |

Example record returned: flare `2026-10-16T15:38:00-FLR-001`, class M1.3, peak 2026-10-16 15:42 UTC, source location S16W15, active region 14551.

#### Life support and food

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Crew metabolic: oxygen consumed | NASA BVAD Rev2 (NASA/TP-2015-218570 Rev2, Feb 2022) Table 3-31 gives nominal oxygen consumed as 0.895 kg per crew member per day (footnote 77 rounds it to 0.90) for an 82 kg reference astronaut doing 30 min aerobic + 60 min resistive exercise per day. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 2 | Crew metabolic: CO2 produced | BVAD Rev2 Table 3-31 gives the nominal carbon dioxide load as 1.085 kg per crew member per day (respiratory quotient 0.86). | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 3 | Crew metabolic: drinking and potable water | BVAD Rev2: 2.00 kg/day drinking water + 0.50 kg/day food rehydration water = 2.50 kg/CM-d total human consumption (Table 4-20, same for ISS, transit and planetary bases); Table 3-31 uses 3.217 kg/CM-d potable water once 0.717 kg extra for exercise perspiration is added. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 4 | Crew water need (simple public figure) | NASA Marshall's ECLSS fact sheet (MSFC-02-2025-G-657270) says each astronaut needs about a gallon of water per day for consumption, food preparation and hygiene, and that astronauts need to drink a half gallon of water each day. | Verified | <https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf> |
| 5 | Total water use incl. hygiene (planetary base) | BVAD Rev2 Table 4-20 total water consumption per crew member per day: ISS 5.38 kg (2.50 human consumption + 0.7 hygiene + 2.18 payload); transit vehicle 3.2 kg (2.50 + 0.7, payload TBD); early planetary base 4.48 kg (2.50 + 1.98 hygiene incl. 1.08 kg shower); mature planetary base 9.12 kg (2.50 + 6.62 hygiene incl. shower 1.08, laundry 1.1, dish wash 3.54). | Corrected | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 6 | Food mass (dry and as-packaged) | BVAD Rev2: ISS food supply planning value is 2.39 kg per crew member per day including packaging (0.43 kg is packaging); 1.56 kg at 48.7% hydration is actually consumed, i.e. 0.80 kg dry food solids per day. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 7 | Food energy / calories per day | BVAD Rev2 sets food energy at 12.778 MJ per crew member per day (about 3,050 kcal, derived) and cites the current NASA requirement of 12.707 MJ/CM-d (~3000 kcal); the Canadian Space Agency says astronauts consume between 1900 and 3200 calories per day depending on weight, gender and specific needs. | Verified | <https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp> |
| 8 | Metabolic heat | BVAD Rev2 Table 3-31 gives total metabolic heat load of 12.426 MJ per crew member per day (sensible 6.308 MJ, latent 6.118 MJ), equivalent to about 144 W continuous (derived). | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 9 | ISS oxygen generation method | On the ISS the Oxygen Generation System makes oxygen by electrolysis: electrical current from the station's solar panels splits water into oxygen (delivered to the cabin) and hydrogen, which is vented to space or fed with crew CO2 to a Sabatier reactor that produces water (kept) and methane (released to space). | Verified | <https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf> |
| 10 | ISS Oxygen Generation Assembly output | The ISS OGA generates oxygen at a selectable rate up to 9.25 kg/day (20.4 lb/day) at 46.9 A, enough for 10.88 crew at an assumed 0.85 kg O2 per person per day; it was designed for a maximum nominal rate of 5.4 kg/day (12 lb/day) on day/night orbital cycles (supporting 4 crew plus specimens and leakage) and a selectable 2.3-9.2 kg/day when run continuously. | Verified | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 11 | ISS CO2 removal (CDRA, LiOH) | The ISS Carbon Dioxide Removal Assembly is a legacy regenerable four-bed molecular sieve (zeolite) that removes 4.2 kg CO2/day at 2 mmHg and 6.5 kg/day at 3 mmHg cabin CO2, and continuously removes six person-equivalents of CO2 with both beds working; lithium hydroxide canisters are the backup and can only be used once. | Verified | <https://ntrs.nasa.gov/api/citations/20260005251/downloads/ICES_CO2_ESM_2026.pdf> |
| 12 | Cabin CO2 limit | NASA-STD-3001 (Vol. 2, V2 6004) requires the average 1-hour CO2 partial pressure in the habitable volume to be no more than 3 mmHg. | Verified | <https://www.nasa.gov/ochmo-tb-004-carbon-dioxide-2/> |
| 13 | ISS water recovery rate (98% milestone) | NASA announced on June 20, 2023 that the ISS ECLSS demonstrated 98% total water recovery thanks to the Brine Processor Assembly; before the BPA total recovery was between 93 and 94%. | Verified | <https://www.nasa.gov/missions/station/iss-research/nasa-achieves-water-recovery-milestone-on-international-space-station/> |
| 14 | ECLSS unit power draw | A published per-unit electrical power figure (kW) for the ISS OGA, CDRA or Water Recovery System was not found in any NASA source opened by the researcher or by me; OGA papers give only cell-stack current (10-46.9 A), and BVAD Rev2 and the 2026 CO2-removal ESM paper do not list ISS rack power. | Unverified | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 15 | MOXIE totals | MOXIE on the Perseverance rover made a total of 122 grams of oxygen over 16 runs, with a peak rate of 12 grams per hour at 98% purity or better; its 16th and final run on Aug. 7, 2023 made 9.8 g, and NASA announced completion on Sept. 6, 2023. | Verified | <https://www.nasa.gov/missions/mars-2020-perseverance/perseverance-rover/nasas-oxygen-generating-experiment-moxie-completes-mars-mission/> |
| 16 | MOXIE power and size | NASA lists MOXIE as a 300-watt instrument with a mass of 17.1 kg (37.7 lb), 23.9 x 23.9 x 30.9 cm, producing up to 10 grams of oxygen per hour, for about one hour of oxygen production per experiment. | Verified | <https://science.nasa.gov/mission/mars-2020-perseverance/science-instruments/> |
| 17 | MOXIE first run and scale-up need | MOXIE's first run on April 20, 2021 (sol 60) made about 5.4 grams of oxygen, enough for about 10 minutes of astronaut breathing; NASA says getting four astronauts off Mars needs about 25 metric tons of oxygen (55,000 lb) while astronauts spending a year on the surface would use maybe one metric ton between them; Mars' atmosphere is 96% CO2. | Verified | <https://www.nasa.gov/news-release/nasas-perseverance-mars-rover-extracts-first-oxygen-from-red-planet/> |
| 18 | Water ice on Mars as a resource | A NASA/JPL map (Dec 10, 2019) shows water ice on Mars as little as an inch (2.5 cm) below the surface, with ice less than one foot (30 cm) deep in mapped zones of Arcadia Planitia, which astronauts could harvest for drinking water and rocket fuel; exposed water does not stay liquid in the thin Martian air. | Verified | <https://www.nasa.gov/solar-system/nasas-treasure-map-for-water-ice-on-mars/> |
| 19 | Water ice at lunar poles | Using the Moon Mineralogy Mapper on Chandrayaan-1, scientists directly confirmed water ice at the surface in permanently shadowed craters at the Moon's poles (PNAS, Aug. 20, 2018), where the warmest temperatures never reach above -250 °F (about -157 °C, derived); the ice is within the top few millimetres, concentrated in craters at the south pole and more widely but sparsely spread at the north pole. | Verified | <https://www.jpl.nasa.gov/news/ice-confirmed-at-the-moons-poles> |
| 20 | LCROSS lunar water measurement | The LCROSS impact into Cabeus crater on Oct. 9, 2009 lofted a maximum of 155 ± 12 kg of water vapor and water ice into the instrument field of view, and the water-ice concentration in the regolith at the impact site is estimated at 5.6 ± 2.9% by mass (Colaprete et al., Science 330, 463-468, Oct. 22, 2010); NASA's Oct. 21, 2010 release adds that as much as 20 percent of the lofted material was volatiles and that the water was mostly pure ice crystals in some places. | Verified | <https://experts.arizona.edu/en/publications/detection-of-water-in-the-lcross-ejecta-plume/> |
| 21 | Veggie: first lettuce eaten and days to harvest | The first crop grown and consumed in NASA hardware was 'Outredgeous' red romaine lettuce in Veggie (VEG-01 B): started by Scott Kelly on July 8, 2015 with six plant pillows, it grew for 33 days and the crew ate half of the leaves on Aug. 10, 2015. | Verified | <https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf> |
| 22 | Veggie: power, size, crops | Veggie runs on about 70 watts for the lights, fans and control electronics, is about the size of a carry-on piece of luggage and typically holds six plants; as of NASA's 2020 fact sheet, 15 different types of plants had grown in Veggie, including eight types of leafy greens eaten by astronauts (three types of lettuce, Chinese cabbage, mizuna mustard, red Russian kale, among others) plus zinnia flowers. | Verified | <https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf> |
| 23 | Advanced Plant Habitat | The Advanced Plant Habitat (launch listed as April 18, 2017) is a fully enclosed, automated growth chamber with more than 180 sensors and red, blue, green and broad-spectrum white LEDs, supporting investigations up to 135 days; it has grown Arabidopsis, dwarf wheat, radishes and New Mexico Hatch green chile peppers. | Verified | <https://smd-cms.nasa.gov/wp-content/uploads/2023/06/advanced-plant-habitat.pdf> |
| 24 | Why fresh crops cannot yet supply all calories | NASA Kennedy plant scientist R. M. Wheeler estimates about 20-25 m2 of crops could provide the oxygen needs for one human and about 50 m2 could provide the food (dietary calories) for one person; a Veggie unit typically holds six plants, and NASA notes the vitamins in prepackaged food break down over time, so fresh crops today are a supplement. | Verified | <https://ntrs.nasa.gov/citations/20205008786> |
| 25 | Lettuce crop cycle in controlled environments | BVAD Rev2 notes that variable spacing or transplanting schemes can cut the lettuce production cycle from 28 to about 14 days (Wheeler et al., 2008), with a seedling nursery needing only 1% to 10% of the mature-plant area; its lettuce growth models are limited to 200-500 µmol/m2/s because a light integral of only 17 mol/m2/d is recommended to prevent leaf tip burn. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 26 | CSA Deep Space Food Challenge | In the Deep Space Food Challenge (Canadian Space Agency and Impact Canada, working with NASA), the jury selected Vancouver-based Ecoation Innovative Solutions Inc. in February 2024 as grand prize winner, with $380,000 in grant funding, for its CANGrow Modular Indoor Food Production System, which could produce over 700 kg of nutrient-dense food annually (strawberries, cherry tomatoes, mycelial meat substitute, etc.). | Verified | <https://www.asc-csa.gc.ca/eng/sciences/food-production/deep-space-food-challenge.asp> |
| 27 | CSA Naurvik project | Naurvik ('the growing place' in Inuktitut) is a community-led food production system in Gjoa Haven, Nunavut, about 250 km north of the Arctic Circle, operating since October 2019 in three recycled shipping containers retrofitted as a Grow Pod, Utility Pod and Power Pod, powered almost entirely by renewable sources such as wind and solar; its first harvest was butter lettuce and microgreens. | Verified | <https://www.asc-csa.gc.ca/eng/sciences/food-production/naurvik-project-in-nunavut.asp> |
| 28 | CHAPEA analog: crew, duration, habitat | NASA's CHAPEA missions each put four crew members in an isolated, 3D-printed 1,700-square-foot (about 158 m2, derived) habitat at Johnson Space Center for 378 days: Mission 1 ran June 25, 2023 to July 6, 2024 and Mission 2 ran Oct. 19, 2025 to Oct. 31, 2026 (now completed); the habitat has private crew quarters, a kitchen, dedicated areas for medical, recreation, fitness, work and crop growth, a technical work area and two bathrooms. | Verified | <https://www.nasa.gov/humans-in-space/chapea/> |
| 29 | CHAPEA communication delay | NASA's July 10, 2024 article on the end of CHAPEA Mission 1 says the mission used Mars-realistic communication delays of up to 44 minutes round trip (i.e. up to 22 minutes one way, derived); a July 11, 2024 NASA feature loosely cites an 'approximately one-hour transmission delay'. NASA's Oct. 19, 2026 Mission 2 article says the data could help support crews facing communication delays lasting up to 45 minutes each way, without stating the delay actually simulated in the habitat; Mission 2 also included a simulated two-week communication blackout. | Corrected | <https://www.nasa.gov/missions/analog-field-testing/chapea/first-mars-crew-completes-yearlong-simulated-red-planet-nasa-mission/> |
| 30 | Real crop growth periods (BVAD Table 4-89) | BVAD Rev2 Table 4-89 lists nominal growth periods in days after planting: lettuce 28, radish 25, spinach 30, chard 45, tomato 85, pepper 85, wheat 75-90, soybean 97, strawberry 100, white potato 132; lettuce and radish use a 16 h/day photoperiod at 23 °C. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 31 | Crop yield, oxygen and water per square metre (BVAD Tables 4-90, 4-91) | BVAD Rev2 nominal crop values per square metre of growing area per day: lettuce yields 131.35 g fresh edible mass (6.57 g dry), produces 7.78 g O2, takes up 10.70 g CO2 and uses 2.10 kg water; radish 91.67 g fresh edible, 11.86 g O2, 1.77 kg water; tomato 173.76 g fresh edible, 26.36 g O2, 2.77 kg water; wheat 20.00 g dry edible, 56.00 g O2, 77.00 g CO2 uptake, 11.79 kg water. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 32 | Plant growth chamber power per area (BVAD Table 4-88) | BVAD Rev2 Table 4-88 (from Drysdale 1999) estimates a plant growth chamber at 2.6 kW of electrical power and 2.6 kW of thermal control per square metre of growing area, of which the lamps are 2.1 kW/m2, with a total mass of 101.5 kg/m2 and 13.1 crew-hours per m2 per year. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 33 | ISRU plant mass, power and output (BVAD Table 4-85) | BVAD Rev2 Table 4-85 lists conceptual ISRU systems: a lunar oxygen-from-polar-water plant producing 1 metric ton O2 and 0.125 t H2 per year has 1.2 t system mass and needs 6.7 kW; a lunar oxygen-from-regolith plant producing 10 t O2/year is 2.7 t and 11.8 kW; a Martian oxygen-only plant producing 22.7 t O2/year is 0.93 t and about 32 kW; a Martian methane + oxygen + water plant (24.6 t O2, 3.1 t H2O, 7.0 t CH4 per year) is 2.2 t and about 80 kW. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 34 | Wastewater streams a recycler collects (BVAD Table 3-31) | BVAD Rev2 Table 3-31 gives per crew member per day: urine water 1.420 kg (range 0.8 to 2.45), respiration and perspiration water 2.946 kg, and fecal water 0.101 kg. | Verified | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> |
| 35 | OGA lifetime oxygen production | As of May 13, 2024 the ISS Oxygen Generation Assembly had produced a total of 13,288 kg (29,296 lbm) of oxygen and 1,661 kg (3,662 lbm) of hydrogen since initial activation in 2007. | Verified | <https://ntrs.nasa.gov/api/citations/20240006776/downloads/ICES%202024%20101%20AOGA%20final.pdf> |
| 36 | Water on the sunlit Moon (SOFIA) | NASA announced on Oct. 26, 2020 that SOFIA detected water molecules in Clavius Crater on the sunlit lunar surface at concentrations of 100 to 412 parts per million, roughly a 12-ounce bottle of water in a cubic metre of soil; the Sahara desert has 100 times that amount. | Verified | <https://www.nasa.gov/news-release/nasas-sofia-discovers-water-on-sunlit-surface-of-moon/> |
| 37 | Radishes and chile peppers in the Advanced Plant Habitat | In the APH, NASA astronaut Kate Rubins harvested 20 radish plants on Nov. 30, 2020 (PH-02; radishes reach maturity in 27 days and were sent back to Earth); PH-04 began July 12, 2021 with 48 Hatch chile pepper seeds planned to grow about four months, and on Oct. 29, 2021 the crew sampled seven peppers, the first time astronauts ate peppers grown in space. | Verified | <https://www.nasa.gov/missions/station/astronauts-harvest-radish-crop-on-international-space-station/> |

<details><summary>Verification notes for this section</summary>

Method: every source was opened by me. NASA PDFs (BVAD Rev2, 2025 ECLSS fact sheet, Veggie and APH fact sheets, ICES 2024 and 2023 OGA papers, 2008 OGS paper, ICES 2026 CO2 paper) were fetched and text-extracted with pdftotext into the session scratchpad only; nothing was written to the project. Web pages were read through a fetch tool that returns short quoted fragments, so on-screen quotes should be rechecked against the page.  Result: 29 researcher facts checked. 26 verified, 2 corrected, 1 kept as NOT FOUND/unverified, 0 dropped. 8 facts added.  Corrections: 1. BVAD Table 4-20: the researcher's "ISS total 3.2 kg/CM-d" is the Transit Vehicle column. The ISS column total is 5.38 kg/CM-d because it includes 2.18 kg/CM-d payload water. Early base 4.48 and mature base 9.12 are confirmed (table-mode extraction of PDF page 86 gives clean columns). 2. CHAPEA comm delay: the 22-minute one-way figure is NASA-backed. NASA's July 10, 2024 Mission 1 completion article says "up to 44-minutes roundtrip". The Oct. 19, 2026 Mission 2 article does not say the crew experienced 45 minutes each way; that sentence is about data helping support crews with delays of that length. Mission 2's simulated delay length was not found. Use 44 minutes round trip.  Upgraded from snippet-only: LCROSS 5.6 ± 2.9% water ice by mass and 155 ± 12 kg are confirmed from the Science paper abstract on the University of Arizona publication record (science.org returned 403; PubMed blocked the fetcher). Applies to the Cabeus impact site only.  Still not found: ISS ECLSS rack power (OGA, CDRA, WRS). Two unopened leads from search snippets disagree (OGA power supply "over 3800 Watts" in ICES-2020-190; "1.5 kW" on a 2025 NIAC poster); both PDFs exceeded the fetch size limit. Do not display either. Real published power figures available instead: MOXIE 300 W, Veggie 70 W, BVAD plant chamber 2.6 kW/m2 (1999 HPS-lamp estimate), BVAD ISRU concept plants (6.7 kW for 1 t O2/yr lunar polar water; ~32 kW for 22.7 t O2/yr Mars).  Currency for late 2026: CHAPEA Mission 2 ended Oct. 31, 2026 (NASA image article Nov 10, 2026), so describe it as completed. MOXIE is finished (last run Aug. 7, 2023). The 98% water recovery is a 2023 milestone and the OGA 13,288 kg total is a May 13, 2024 snapshot; neither is live data. Veggie's "15 plant types / 8 leafy greens" count is as of the 2020 fact sheet.  Derived values (not in sources; label as derived): ~3,050 kcal from 12.778 MJ; ~144 W from 12.426 MJ/day; 3.8 L per gallon; -157 C from -250 F; 158 m2 from 1,700 sq ft; 1.9 kg/day from 700 kg/yr; 22 min one way from 44 min round trip; MOXIE Wh per gram and units per person; 109 days for the first chile harvest; 130 kW for 50 m2 of crops; 16 m2 of wheat per person's oxygen.  Other cautions: the OGS rack moved from Node 3 (Tranquility) to the US Lab in Sept 2022 per the 2024 OGA paper, although the 2025 fact sheet still says the racks are in Tranquility. The 2008 paper gives the OGA current range as 10-55 A, the 2024 paper 10-46.9 A. The BVAD "28 to ~14 days" lettuce figure is time in the main growing area with a separate seedling nursery. The ICES 2026 CO2 source is a slide-style presentation. The OCHMO brief's per-person CO2 table has inconsistent unit headers, so use BVAD's 1.085 kg/day.

</details>

#### Radiation and space weather

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Dose rate - Earth surface | EPA (citing NCRP) states the average annual radiation dose per person in the U.S. is 6.2 mSv (620 mrem). EPA says most of it comes from natural background sources, and that 48 percent comes from medical procedures. | Verified | <https://www.epa.gov/radiation/radiation-sources-and-doses> |
| 2 | Dose rate - ISS | Zhang et al. 2020 (Science Advances) cite a dose equivalent inside the ISS of 731 microsieverts per day, of which 523 microsieverts per day is from galactic cosmic rays, and state the lunar-surface GCR dose equivalent is about a factor of 2.6 higher than inside the ISS. | Verified | <https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/> |
| 3 | Dose rate - deep space transit (MSL RAD cruise) | During Curiosity's cruise to Mars, the RAD instrument inside the spacecraft measured an average galactic-cosmic-ray dose equivalent of 1.8 mSv per day; JPL compares it to a whole-body CT scan once every five or six days and says only about three percent of the dose was from solar particles. | Verified | <https://www.jpl.nasa.gov/news/data-from-nasa-rovers-voyage-to-mars-aids-planning/> |
| 4 | Dose rate - Mars surface (Curiosity RAD) | On the Martian surface (Gale crater), RAD measured an average GCR dose equivalent rate of 0.67 mSv per day from August 2012 to June 2013. | Verified | <https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars> |
| 5 | Dose rate - lunar surface (Chang'e-4 LND) | The Lunar Lander Neutrons and Dosimetry experiment on Chang'e-4 measured an average dose equivalent of 1,369 microsieverts per day on the lunar surface (GCR charged-particle dose equivalent rate 57.1 +/- 10.6 uSv/hour; total absorbed dose rate in silicon 13.2 +/- 1 uGy/hour; average quality factor 4.3 +/- 0.7; neutral particles 23 +/- 8% of total dose), from data taken 3-12 January and 31 January-10 February 2019. | Verified | <https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/> |
| 6 | Dose rate - Moon (LRO CRaTER) | LRO CRaTER (Schwadron et al. 2012, JGR 117, E00H13) reports a maximum observed GCR absorbed dose rate of about 11.7 cGy per year during the deep solar minimum, the highest dose rates observed in the space age. The paper states its dose rates are referenced at the lunar surface (altitude-corrected) and adjusted for dose deposition in water, behind about 0.22 g/cm2 Al. This is absorbed dose (Gy), not dose equivalent (Sv). | Corrected | <https://prediccs.sr.unh.edu/papers/schwadron2011JE003978.pdf> |
| 7 | NASA limit - career | NASA-STD-3001 Volume 1 requirement [V1 4030]: an individual crewmember's total career effective radiation dose due to spaceflight radiation exposure shall be less than 600 mSv; the limit is universal for all ages and sexes (set to keep below 3% mean risk of exposure-induced death from cancer). Identical value in Rev B (2022-01-05) and in the current Rev C (approved 2023-09-15). | Verified | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 8 | NASA limit - 30-day and 1-year | NASA-STD-3001 Vol 1 short-term/career non-cancer dose limits: blood-forming organs 250 mGy-Eq (30 days) and 500 mGy-Eq (1 year), career not applicable; skin 1,500 / 3,000 / 6,000 mGy-Eq; lens 1,000 / 2,000 / 4,000 mGy-Eq; circulatory system 250 / 500 / 1,000 mGy-Eq (30-day / 1-year / career). Table 3 in Rev B; Table 4.8-1 in current Rev C with the same values for these organs. | Verified | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 9 | NASA limit - solar particle event design limit | NASA-STD-3001 [V1 4031]: the program shall protect crewmembers from exposure to the design reference solar particle event environment proton energy spectrum (sum of the October 1989 events) to less than a NASA effective dose of 250 mSv; the OCHMO brief summarises this as 250 mSv per event. | Verified | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 10 | Reference daily environment used by NASA standard | NASA-STD-3001 Vol 1 states that for a surface-based mission (figure source: a human Mars mission analysis) the space radiation environment exposure is approximately 0.5 mSv per day, and uses 1.5 mSv/day in its Mars-transit example (1.5 mSv/day x 90 days = 135 mSv). Rev C additionally identifies 1.5 mSv/day as the free-space, unshielded GCR effective dose rate at solar minimum. | Verified | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 11 | GCR vs SPE | Per NASA OCHMO-TB-020: galactic cosmic rays occur continuously, are omnidirectional, are lower during solar maximum and do not respond to shielding (only an average 7% reduction in dose with aluminum/polyethylene), while solar particle events are infrequent bursts of low-to-medium-energy protons occurring most often during solar maximum, against which aluminum and polyethylene provide an average 50% dose reduction. | Verified | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 12 | Real SPE on Mars - September 2017 | A solar event on 11 September 2017 produced radiation levels on the Martian surface more than double any previously measured by Curiosity's RAD, with high readings lasting more than two days, and a global aurora more than 25 times brighter than any previously seen by MAVEN. | Verified | <https://www.jpl.nasa.gov/news/large-solar-storm-sparks-global-aurora-and-doubles-radiation-levels-on-the-martian-surface/> |
| 13 | Real SPE on Mars - 20 May 2024 | On 20 May 2024 a solar flare later estimated to be an X12 (based on Solar Orbiter data) hit Mars; it was the biggest surge measured by Curiosity's RAD since landing, and an astronaut standing next to the rover would have received 8,100 micrograys, equivalent to 30 chest X-rays; charged particles reached Mars in tens of minutes. | Verified | <https://www.jpl.nasa.gov/news/nasa-watches-mars-light-up-during-epic-solar-storm/> |
| 14 | August 1972 event | A NASA Goddard video states that the intense solar radiation of August 1972 occurred right between the Apollo 16 and Apollo 17 missions, when no astronauts were in its path. | Verified | <https://svs.gsfc.nasa.gov/vis/a010000/a013200/a013275/AstronautRadiation.en_US.srt> |
| 15 | May 2024 G5 geomagnetic storm | The May 2024 storm reached G5, the highest level on the geomagnetic storm scale, not seen since 2003; SDO observed 82 notable flares from 3-9 May 2024, at least seven CMEs headed toward Earth 7-11 May at speeds up to 3 million mph, and DONKI lists Kp 9.0 at 2024-05-11T00:00Z, 03:00Z and 12:00Z (gstID 2024-05-10T15:00:00-GST-001, source NOAA). | Verified | <https://science.nasa.gov/science-research/heliophysics/how-nasa-tracked-the-most-intense-solar-storm-in-decades/> |
| 16 | DONKI real events - strongest flares 2024 | DONKI records an X9.0 flare peaking 2024-10-03T12:18Z from active region 13842 (the strongest in DONKI for 2024-01-01 to 2026-11-14), an X8.7 peaking 2024-05-14T16:51Z from AR 13664, and an X5.8 peaking 2024-05-11T01:23Z from AR 13664. | Verified | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2024-10-01&endDate=2024-10-05> |
| 17 | DONKI real events - November 2025 | DONKI records an X5.1 flare (begin 2025-11-11T09:49Z, peak 10:04Z, AR 14274) and a GOES >100 MeV proton event logged at 2025-11-11T10:20Z, i.e. 31 minutes after flare start and 16 minutes after flare peak. Separately, DONKI records a geomagnetic storm reaching Kp 8.67 at 2025-11-12T03:00Z, which DONKI links to earlier CMEs of 7, 9 and 10 November (the 10 November CME came with an X1.2 flare), not to the X5.1 flare's CME; the X5.1's CME (2025-11-11T10:23Z) is linked to a second storm (gstID 2025-11-12T18:00:00-GST-001) that peaked at Kp 7.33. | Corrected | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/GST?startDate=2025-11-10&endDate=2025-11-14> |
| 18 | DONKI real events - January 2026 (S4 radiation storm) | DONKI records an X1.9 flare peaking 2026-01-18T18:09Z (AR 14341, begin 17:27Z) with a linked CME (start 18:09Z) analysed at 1,820 km/s, a GOES >10 MeV proton event at 2026-01-18T22:55Z, an interplanetary shock at Earth at 2026-01-19T18:55Z (24 h 46 min after CME start) and Kp 8.67 at 2026-01-20T00:00Z; NOAA SWPC reported an S4 (Severe) solar radiation storm in progress on 19 January 2026, a level not observed since October 2003. | Verified | <https://www.spaceweather.gov/news/s4-severe-solar-radiation-storm-progress-january-19th-2026> |
| 19 | DONKI real events - 2026 flares and latest window | DONKI records an X8.1 flare peaking 2026-02-01T23:57Z from AR 14366, which produced six X-class flares on 1-4 February 2026 (X1.0, X8.1, X2.8, X1.6, X1.5, X4.2); for 2026-10-01 to 2026-11-10 DONKI returns 22 flares, strongest M6.7 (peak 2026-10-08T15:48Z, AR 14549), no X-class flares and no SEP events. | Verified | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2026-10-01&endDate=2026-11-10> |
| 20 | Solar flare (one-line definition + arrival) | A solar flare is an intense burst of radiation, or light, on the Sun; its energy travels at the speed of light and reaches Earth about 8 minutes after the flare happens; flares are classed A, B, C, M, X, each higher class a 10-fold increase in energy. | Verified | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 21 | Coronal mass ejection (one-line definition + arrival) | A coronal mass ejection is an enormous cloud of electrically charged gas, called plasma, that erupts from the Sun; when directed at Earth the fastest can arrive in as little as 15 hours and the slowest take several days. | Verified | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 22 | Solar energetic particles (one-line definition + arrival) | In a radiation storm, solar eruptions accelerate charged particles (electrons and protons) into space at very high speeds; the fastest can cross the roughly 93 million miles from the Sun to Earth in about 30 minutes or less. | Verified | <https://science.nasa.gov/sun/solar-storms-and-flares/> |
| 23 | Shielding - storm shelter water-equivalent thickness | NASA OCHMO-TB-020: a storm shelter with an added 10 cm water equivalent protects against a centennial (1-in-100-year) solar particle event and about 20 cm water equivalent is needed for a 1-in-1,000-year event; missions over 6 months should have vehicle shielding of at least 20 g/cm2. NASA-STD-3001 Vol 1 (Table 6 in Rev B, Table 4.8-4 in Rev C) recommends SPE shielding of 10 cm (or g/cm2) water equivalent surrounding the crewmember on a celestial surface (any duration), 15 cm beyond LEO under 6 months, and 20 cm beyond LEO over 6 months. | Verified | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 24 | Shielding - water bags / stowage effect | OCHMO-TB-020 ray-tracing table for an SPE beyond low Earth orbit in a capsule: effective dose by crew location 214 / 210 / 259 / 231 mSv, falling to 68 / 65 / 66 / 66 mSv with optimized pre-launch stowage used as a shelter (83 / 75 / 73 / 83 mSv with optimized return stowage). | Verified | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 25 | Shielding - regolith cover | Matthia and Berger 2024 (Space Weather 22, e2024SW004095; Geant4 model): more than 4 g/cm2 of regolith reduces solar-particle-event dose below the current 30-day limits and more than 10 g/cm2 gives a safety margin factor of two. For GCR at solar minimum the modelled dose equivalent is 0.84 mSv/day (310 mSv/year) unshielded (spacesuit only), dropping to a local minimum of 0.6 mSv/day (220 mSv/year) at about 20 g/cm2, rising to 0.65 mSv/day (240 mSv/year) at 90 g/cm2, and 0.55 mSv/day (200 mSv/year) at 180 g/cm2. The model's regolith density is 3 g/cm3. | Corrected | <https://elib.dlr.de/210448/1/ME-SBA-2024-Matthi%C3%A4-Berger%20Radiation%20Exposure%20and%20Shielding%20Effects%20on%20the%20Lunar%20Surface-SPACE%20WEATHER.pdf> |
| 26 | Orion storm-shelter procedure | During a solar particle event Orion's crew would position themselves in the central part of the crew module and create a shelter using the stowage bags on board, building it within an hour, and may need to stay inside for as long as 24 hours; Orion's built-in Hybrid Electronic Radiation Assessor (HERA) provides a warning if the crew need to take shelter. | Verified | <https://www.nasa.gov/humans-in-space/scientists-and-engineers-evaluate-orion-radiation-protection-plan/> |
| 27 | Warning time / EVA rule | OCHMO-TB-020: timelines of SPEs allow sufficient time for shelter reconfiguration; real-time alert dosimetry provides a very high level of protection if EVA termination occurs within 2 hours; a large majority (~95%) of SPEs require only ALARA considerations and do not approach dose limits; the probability of EVA organ doses above 100 mSv is less than one in a million. | Verified | <https://www.nasa.gov/wp-content/uploads/2023/03/radiation-protection-technical-brief-ochmo.pdf> |
| 28 | DONKI endpoints on api.nasa.gov | api.nasa.gov documents DONKI at https://api.nasa.gov/DONKI/{CME\|CMEAnalysis\|GST\|IPS\|FLR\|SEP\|MPC\|RBE\|HSS\|WSAEnlilSimulations\|notifications} with startDate and endDate (yyyy-MM-dd; default 30 days before current UTC date to current date; 7 days for WSAEnlilSimulations and notifications) and api_key; CMEAnalysis adds mostAccurateOnly, completeEntryOnly, speed, halfAngle, catalog, keyword; IPS adds location and catalog; notifications adds type (all, FLR, SEP, CME, IPS, MPC, GST, RBE, report) and its range is limited to 30 days. | Verified | <https://api.nasa.gov/assets/json/apis.json> |
| 29 | DONKI endpoints on CCMC host (no key) and current status | The same data is served without an API key at https://ccmc.gsfc.nasa.gov/DONKI/WS/get/{FLR\|SEP\|GST\|CME\|CMEAnalysis\|IPS\|notifications}?startDate=...&endDate=... (also https://ccmc.gsfc.nasa.gov/DONKI-API/get/FLR). On 2026-11-14 this host rejected a range over 60 days with HTTP 400 ('API Error: Date range cannot exceed 60 days'), returned an X-Rate-Limit-Remaining: 119 header, and the old kauai.ccmc.gsfc.nasa.gov host timed out; CCMC says to replace kauai.ccmc.gsfc.nasa.gov with ccmc.gsfc.nasa.gov. The researcher's report that https://api.nasa.gov/DONKI/FLR returned 404 while GST and SEP returned 200 could NOT be re-tested. | Verified | <https://ccmc.gsfc.nasa.gov/tools/DONKI/> |
| 30 | api.nasa.gov rate limits | api.nasa.gov documents DEMO_KEY limits of 30 requests per IP address per hour and 50 per IP address per day, versus a default 1,000 requests per hour for a registered key; usage is reported in X-RateLimit-Limit and X-RateLimit-Remaining headers. Live DEMO_KEY responses on 2026-11-14 carried X-Ratelimit-Limit: 10. Per the api.data.gov developer manual the key can be passed in the X-Api-Key HTTP header, as the api_key query parameter, or as the HTTP basic-auth username. | Verified | <https://api.nasa.gov/assets/html/authentication.html> |
| 31 | DONKI JSON fields - FLR | Each FLR record contains flrID, catalog, instruments[].displayName, beginTime, peakTime, endTime, classType (e.g. 'M6.7'), sourceLocation, activeRegionNum, note, link, linkedEvents[].activityID, sentNotifications, submissionTime and versionId; times are UTC strings like 2026-10-08T15:48Z. | Verified | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR?startDate=2026-10-01&endDate=2026-11-10> |
| 32 | DONKI JSON fields - GST and SEP | GST records contain gstID, startTime, allKpIndex[] (each with observedTime, kpIndex such as 8.67, and source 'NOAA'), link, linkedEvents, sentNotifications, submissionTime, versionId; SEP records contain sepID, eventTime, instruments[].displayName (e.g. 'GOES-P: SEISS >10 MeV', 'GOES-P: SEISS >100 MeV', 'SOHO: COSTEP 15.8-39.8 MeV', 'MODEL: REleASE:...'), link, linkedEvents, sentNotifications, submissionTime, versionId. SEP records carry no flux or dose value. | Verified | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/GST?startDate=2024-05-08&endDate=2024-05-14> |
| 33 | Attribution / licence wording | NASA says its content generally is not subject to copyright in the United States and may be used for educational or informational purposes, with NASA acknowledged as the source and no implied endorsement; the NASA Insignia, Logotype and identifiers are not in the public domain. DONKI notifications carry the disclaimer that NOAA's Space Weather Prediction Center is the United States Government official source for space weather forecasts and that DONKI is 'Experimental Research Information' consisting of preliminary NASA research products; the CCMC page says DONKI data is provided 'as is' without warranty and is run primarily by the Moon-to-Mars Space Weather Analysis Office. | Verified | <https://www.nasa.gov/nasa-brand-center/images-and-media/> |
| 34 | RadLab / OSDR ISS dosimetry API | NASA OSDR RadLab offers a GET API at https://visualization.osdr.nasa.gov/radlab/api taking filters such as spacecraft, module (ISS only), instrument and timestamp and returning absorbed_dose_rate (uGy/hour), dose_equivalent_rate (uSv/hour), flux (cm-2 sr-1 s-1) and position fields as csv (default), tsv, json or html; documented example instruments include TEPC, IV-TEPC, ALTEA, Liulin-5, Lidal, REM and DosTel. A live keyless query for ISS instrument=DosTel on 2022-04-01 returned 2,389 readings covering both DosTel1 and DosTel2. | Verified | <https://visualization.osdr.nasa.gov/radlab/gui/data-api/> |
| 35 | Roblox HttpService | Roblox experience servers can send HTTP requests to third-party web services with HttpService GetAsync / PostAsync / RequestAsync; these methods are not enabled by default and require 'Allow HTTP Requests' under File > Experience Settings > Security in Studio. External requests are limited to 500 per minute per game server (Open Cloud requests have a separate 2,500 per minute limit); port 1194 and ports below 1024 except 80 and 443 are blocked; Roblox advises wrapping calls in pcall and planning for failure. Secrets (HttpService:GetSecret) can hold an API key but are not available when the experience runs locally. | Verified | <https://create.roblox.com/docs/cloud-services/http-service> |
| 36 | NASA GCR design limit (current standard) | NASA-STD-3001 Vol 1 Rev C (approved 2023-09-15) adds requirement [V1 4033]: for habitable space systems designed to support crew for more than 60 days, the program shall protect crewmembers from the galactic cosmic ray environment to less than a NASA effective dose rate of 1.3 mSv/day for systems in free space and less than 0.9 mSv/day for systems on planetary surfaces. Rationale: shielding can reduce the free-space unshielded GCR effective dose rate of 1.5 mSv/day by about 15% to 1.3 mSv/day; reductions are achieved with 10-40 g/cm2, while 40-100 g/cm2 has negligible or negative effect. | Verified | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> |
| 37 | NOAA Space Weather Scales (G, S, R) | NOAA scales: geomagnetic storms G1-G5 correspond to Kp 5, 6, 7, 8 (including 9-), and 9; solar radiation storms S1-S5 correspond to >=10 MeV proton flux of 10, 10^2, 10^3, 10^4 and 10^5 pfu, with S3 'radiation hazard avoidance recommended for astronauts on EVA' and S4 'unavoidable radiation hazard to astronauts on EVA'; radio blackouts R1-R5 correspond to GOES X-ray peak class M1, M5, X1, X10 and X20. | Verified | <https://www.spaceweather.gov/noaa-scales-explanation> |
| 38 | World natural background (UNSCEAR 2026) | UNSCEAR's report published 12 February 2026 estimates the worldwide average annual effective dose from natural sources at approximately 3.0 mSv (radon/thoron inhalation 1.8 mSv, ingestion 0.5 mSv, terrestrial external 0.4 mSv, cosmic radiation 0.3 mSv); the increase from the previously reported 2.4 mSv (UNSCEAR 2008) reflects better data and methods, not a real rise. | Verified | <https://unis.unvienna.org/unis/en/pressrels/2026/unisous453.html> |
| 39 | Real-time NOAA SWPC JSON feeds (actually live) | NOAA SWPC serves keyless near-real-time JSON: planetary Kp at https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json (3-hourly values, fields time_tag, Kp, a_running, station_count), GOES integral proton flux at https://services.swpc.noaa.gov/json/goes/primary/integral-protons-1-day.json (5-minute values for >=1, >=10, >=50, >=60, >=100, >=500 MeV channels), GOES X-ray flux at https://services.swpc.noaa.gov/json/goes/primary/xrays-6-hour.json (1-minute values, 0.05-0.4 nm and 0.1-0.8 nm), and current/forecast R, S, G scale levels at https://services.swpc.noaa.gov/products/noaa-scales.json. | Verified | <https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json> |
| 40 | Whole Mars mission dose versus career limit | SwRI (RAD principal-investigator institution) states that at RAD's measured rates the total during just the transit phases of a Mars mission would be approximately 0.66 Sv for a round trip, and a 500-day surface stay would bring the total exposure to around 1 Sv. | Verified | <https://www.swri.org/press-release/swri-scientists-publish-first-radiation-measurements-surface-mars> |
| 41 | Artemis I radiation measurements inside Orion | NASA reports that Artemis I carried 5,600 passive sensors and 34 active radiation detectors inside Orion (including NASA's HERA and Crew Active Dosimeter, ESA's Active Dosimeter, and the MARE manikin torsos), measured different radiation levels in areas with different shielding, and saw radiation levels drop nearly in half when Orion altered its orientation during an Interim Cryogenic Propulsion Stage engine burn. | Verified | <https://www.nasa.gov/humans-in-space/artemis-i-radiation-measurements-validate-orion-safety-for-astronauts/> |
| 42 | Chest X-ray equivalence is inconsistent across NASA pages | NASA's 'Why Space Radiation Matters' page states that astronauts are exposed to effective doses in the range from 50 to 2,000 mSv and that 1 mSv of ionizing radiation is equivalent to about 10 chest x-rays; JPL's May 2024 Mars page equates 8,100 micrograys to 30 chest X-rays (about 0.27 mGy per X-ray). | Verified | <https://www.nasa.gov/analogs/nsrl/why-space-radiation-matters> |
| 43 | DONKI SEP records: many entries per event and threshold-crossing times | In DONKI a single solar particle event appears as multiple SEP records, one per instrument and energy channel, including model entries labelled 'MODEL: REleASE:...'; for example the 10-12 November 2025 activity has 16 SEP records and the 18-21 January 2026 storm has 9. Of the 214 SEP records for 2024-01-01 to 2026-11-14 only 9 are GOES >100 MeV events (2024-02-12, 2024-05-11, 2024-06-08, 2024-07-23, 2024-10-09, 2024-11-21, 2025-11-11, 2026-07-30, 2026-09-05). | Verified | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/SEP?startDate=2025-11-10&endDate=2025-11-13> |

<details><summary>Verification notes for this section</summary>

METHOD. Everything marked verified was opened by me on 2026-11-14: web pages via fetch, PDFs downloaded to the session scratchpad and text-extracted (NASA-STD-3001 Vol 1 Rev B and Rev C, OCHMO-TB-020, Matthia and Berger 2024, Schwadron et al. 2012), and live GET calls to ccmc.gsfc.nasa.gov DONKI, OSDR RadLab and services.swpc.noaa.gov. No project files were written; temporary files are only in the session scratchpad.  RESULT SUMMARY. 35 researcher facts: 32 verified, 3 corrected, 0 dropped. 8 facts added.  CORRECTIONS THAT MATTER FOR THE GAME. 1. November 2025 chain is wrong as implied: DONKI links the Kp 8.67 storm (12 Nov 03:00Z) to CMEs of 7, 9 and 10 November, not to the X5.1 flare. The X5.1's CME is linked to a second storm peaking at Kp 7.33. Also a GOES >10 MeV event was logged at 09:45Z, before the X5.1 began, and DONKI SEP eventTime is a threshold-crossing time. '16 minutes after flare peak' is a true interval (31 minutes after flare start) but not a clean first-particle travel time. 2. LRO CRaTER 11.7 cGy/yr is now verified in the opened paper, but it is NOT a lunar-orbit value: the paper says dose rates are altitude-corrected to the lunar surface and adjusted to water. The proposed orbit-versus-surface use is invalid. 3. Regolith paper: abstract says 180 g/cm2 is 'about 25%' below unshielded, the paper's conclusions say 35% (200 vs 310 mSv/yr; 35% is the arithmetic). Show the absolute values. The model regolith density is stated in the paper (3 g/cm3). 4. NASA-STD-3001 Vol 1 Rev B is superseded by Rev C (approved 2023-09-15). The 600 mSv, 250 mSv, Table values, 10/15/20 cm shielding and 0.5 / 1.5 mSv/day text are unchanged, but table numbers changed (Table 3 -> 4.8-1, Table 6 -> 4.8-4) and Rev C adds a GCR requirement [V1 4033] (1.3 mSv/day free space, 0.9 mSv/day surface). Cite Rev C. I could not open the standards.nasa.gov index page (404) to rule out a later revision. 5. The 10/15/20 shielding table is readable in NASA-STD-3001, not in the OCHMO brief text (image there). 6. World background: UNSCEAR's February 2026 report gives about 3.0 mSv/yr natural average; the 2.4 mSv figure the researcher remembered is the 2008 value.  NOT REPRODUCIBLE / STILL UNVERIFIED. - api.nasa.gov/DONKI/FLR returning 404 while GST/SEP return 200: could not be re-tested. Every DEMO_KEY request from my side (direct and via the fetch tool) returned HTTP 429 OVER_RATE_LIMIT with X-Ratelimit-Limit: 10 and Retry-After about 6 hours. This does confirm DEMO_KEY is unusable; the team must re-test api.nasa.gov with a registered key on the day. - Researcher note 5 says the CCMC API documentation page is 404: true for /tools/DONKI/api/, but https://ccmc.gsfc.nasa.gov/DONKI/api/ returned 200. - CCMC host rate limit: only the X-Rate-Limit-Remaining: 119 header was seen; no documented limit found. - X-Api-Key header: documented in the api.data.gov developer manual (opened) but not tested live against api.nasa.gov, and the Roblox guide's header limitation wording is ambiguous; test before relying on it. - RadLab: description sentence, DosTel module location and citation requirement not found on an opened page. - August 1972 dose estimates (400 rem): no opened source; the old NASA science-news URL is 404. Do not display. - ISS '80-160 mSv per six months': not found on the NASA NSRL page opened. - A NASA-stated SPE warning lead time in minutes: not found (NASA only says crews 'may not have a lot of warning'). - Regolith thickness in metres for real lunar soil: not found in an opened source. - Artemis I numeric doses (26.7-35.4 mSv, fourfold shielding difference) appeared only in search snippets of the Nature paper; not opened, do not display. - No live Roblox-to-NASA HTTP call was tested.  CONFIRMED FROM THE RESEARCHER'S NOTES. DONKI totals for 2024-01-01 to 2026-11-14 reproduced exactly (1,941 FLR, 85 X-class, 214 SEP, 62 GST); the list of 11 storms with max Kp >= 7.67; the 2026 X-flare list; GOES >100 MeV events on 2026-07-30 and 2026-09-05; 60-day range limit (HTTP 400); kauai host timeout; DEMO_KEY header value 10; JPL's 'about three percent' solar-particle share (use 3%, not 5%); the '~22-year cycles' typo in the OCHMO brief (use 11 years); NOAA G-scale mapping now verified on the NOAA page (G5 = Kp 9, G4 = Kp 8).  UNIT AND CONSISTENCY WARNINGS. (a) RAD, LND and ISS values are dose equivalent (Sv); May 2024 Mars, CRaTER and RadLab absorbed_dose_rate are absorbed dose (Gy); NASA organ limits are mGy-Eq; the 600 mSv, 250 mSv, 0.5, 0.9, 1.3 and 1.5 mSv/day NASA values are effective dose. Do not sum or compare across these without a visible caveat. (b) RAD surface (2012-13, near solar maximum) and LND (2019, solar minimum) were measured at opposite solar-cycle phases; avoid a hard 'Moon = 2x Mars' claim. (c) NASA pages disagree on the chest-X-ray equivalence (NSRL: 1 mSv = about 10 X-rays; JPL: 8,100 uGy = 30 X-rays); quote each only with its own source. (d) Derived numbers (0.017 mSv/day, 324 mSv, '70%', '8 days on ISS = 1 Earth year', '25 hours') are team arithmetic and should be labelled as calculated, not as NASA figures.  LIVE VERSUS STATIC. DONKI is a forecaster-curated catalogue (see submissionTime) and RadLab is an archive; neither may be labelled live. If a genuinely live indicator is wanted, the NOAA SWPC JSON feeds added above returned current samples (minutes old) with no key; credit NOAA SWPC and show the sample time.  RELEVANT TEMP FILES (scratchpad, not project): C:\Users\gorzo\AppData\Local\Temp\claude\22c2971da2bfe9d6\af6d9fcb-1657-4dc7-b14b-5abc2bdf34c2\scratchpad\full\all.json (full DONKI pull), C:\Users\gorzo\AppData\Local\Temp\claude\22c2971da2bfe9d6\af6d9fcb-1657-4dc7-b14b-5abc2bdf34c2\scratchpad\revc\revc.pdf (NASA-STD-3001 Vol 1 Rev C).

</details>

#### Power and surface environment

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Mars solar irradiance vs Earth | Solar irradiance at Mars' mean distance is 586.2 W/m2 versus 1361.0 W/m2 at Earth, about 43% of Earth's (percent derived by division). | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 2 | Length of a sol | A Mars mean solar day (sol) lasts 24 h 39 min 35.244 s (88,775.244 seconds). | Verified | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 3 | Mars year length in sols | A Mars tropical year is 668.5921 sols (686.9725 Earth days) per NASA GISS; NASA's public Mars Facts page quotes 669.6 sols / 687 Earth days. | Verified | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 4 | Jezero crater temperatures (Perseverance MEDA) | MEDA at Jezero recorded a high of -22 C (-7.6 F) and a low of -83 C (-117.4 F) on sols 43-44 (April 3-4, 2021); a NASA Science page summarises air temperature as between -83 C and -23 C and surface (ground) temperature as typically -83 C pre-dawn to 5 C at noon. | Verified | <https://www.jpl.nasa.gov/news/nasas-first-weather-report-from-jezero-crater-on-mars/> |
| 5 | Jezero surface pressure and wind (MEDA) | MEDA's first pressure reading at Jezero was 718 Pa (within the predicted 705-735 Pa range), and wind gusts were around 10 m/s (22 mph) on sols 43-44. | Verified | <https://www.jpl.nasa.gov/news/nasas-first-weather-report-from-jezero-crater-on-mars/> |
| 6 | Gale crater temperatures (Curiosity REMS) | REMS air temperatures at Gale from mid-August 2012 to late February 2013 showed daily highs at about 0 C (32 F) and lows at about -70 C (-94 F); the JPL/Mars REMS JSON feed's newest 30 sols (4966-4995, 2026-07-26 to 2026-08-25) show min_temp -78 to -69 and max_temp -11 to -3, pressure 777-791. | Verified | <https://science.nasa.gov/resource/steady-temperatures-at-mars-gale-crater> |
| 7 | Mars surface pressure | Mean surface pressure on Mars is 6.36 mb (636 Pa) at mean radius, variable from 4.0 to 8.7 mb depending on season. | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 8 | Mars atmosphere composition | Mars' atmosphere by volume is 95.1% CO2, 2.59% N2, 1.94% Ar, 0.16% O2 and 0.06% CO. | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 9 | Mars surface gravity | Mars' mean surface gravity is 3.73 m/s2 versus 9.82 m/s2 on Earth, about 38% of Earth's (derived). | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html> |
| 10 | 2018 global dust storm opacity (tau) | JPL reported the 2018 storm at Opportunity's site had an estimated tau of 10.8 on June 10, 2018 (last tau measured), versus 'somewhere above 5.5' in the 2007 storm and a usual average of 0.5; engineers predicted tau had to fall below 2.0 for recharge. The storm grew from more than 18 million km2 (June 8) to 35 million km2 (June 12), a quarter of the planet. A separate NASA Science graphic page gives the June 10 tau as 10.5. | Verified | <https://www.jpl.nasa.gov/news/opportunity-hunkers-down-during-dust-storm/> |
| 11 | Opportunity last contact and end of mission | Opportunity's final communication was received June 10, 2018 (sol 5,111); after more than a thousand commands to restore contact, the last attempt was sent late Feb. 12, 2019 and NASA declared the mission complete on Feb. 13, 2019. Designed for 90 Martian days and 1,000 m (1,100 yards), it operated almost 15 years and travelled more than 45 km (28 miles). | Verified | <https://www.jpl.nasa.gov/news/nasas-opportunity-rover-mission-on-mars-comes-to-end/> |
| 12 | Opportunity solar energy before/during 2018 storm | NASA states Opportunity's energy on June 10, 2018 (sol 5,111) was 21 watt-hours, the lowest ever measured on the rover at that time. The Planetary Society, quoting the MER team, gives around 645 Wh on June 1, 2018 and 22 Wh on June 10, almost 100 Wh below what is considered necessary for survival of a MER-class rover. | Corrected | <https://science.nasa.gov/resource/on-mars-light-is-energy/> |
| 13 | InSight dust on solar panels (Wh per sol) | InSight's two solar panels (each about 2.2 m wide) produced around 5,000 Wh per sol at landing (Nov. 26, 2018) and roughly 500 Wh per sol by May 17, 2022; a regional dust storm (first seen Sept. 21, 2022) then cut power from 425 to 275 Wh per sol. | Verified | <https://www.jpl.nasa.gov/news/nasas-insight-still-hunting-marsquakes-as-power-levels-diminish/> |
| 14 | InSight end of mission | InSight last communicated with Earth on Dec. 15, 2022; NASA announced the mission's retirement on Dec. 21, 2022 after the lander missed two consecutive communication attempts, having detected 1,319 marsquakes in more than four years. | Verified | <https://www.jpl.nasa.gov/news/nasa-retires-insight-mars-lander-mission-after-years-of-science/> |
| 15 | Dust cleaning events (wind / dust devils) | In March 2014 wind cleaned Opportunity's panels, boosting array output by about 10%; combined with seasonal sunlight, daily energy rose more than 70% in two months to more than 615 Wh. For InSight, JPL estimated cleaning 25% of the panels would gain about 1,000 Wh per sol. | Verified | <https://www.jpl.nasa.gov/news/cleaner-nasa-rover-sees-its-shadow-in-martian-spring/> |
| 16 | Mars dust storm season and frequency | Large regional dust storms recur at about the same times each Mars year during southern spring and summer; local storms are smaller than about 2,000 km across and end within a few days, regional storms affect up to a third of the planet and last up to three weeks; global storms occur on average once every three Mars years (about 5.5 Earth years). | Verified | <https://www.jpl.nasa.gov/news/nasa-mars-orbiters-reveal-seasonal-dust-storm-pattern/> |
| 17 | MMRTG output and decay | An MMRTG produces about 110 W of electricity at beginning of life from about 2,000 W of heat (4.8 kg plutonium dioxide, 8 GPHS modules, ~45 kg) and an estimated 72 W at the end of its 17-year design life (which includes 3 years of fueled storage). JPL's Mars 2020 press kit says output declines 'a few percent each year' and that the MMRTG charges two lithium-ion batteries (about 43 Ah each, 26.5 kg total) because demand can reach 900 W during science activities; Perseverance's MMRTG operational lifetime is at least 14 years. | Verified | <https://science.nasa.gov/wp-content/uploads/2024/02/mmrtg-factsheet-updated-5-18-20-1.pdf> |
| 18 | Kilopower / KRUSTY | NASA's Kilopower system can provide up to 10 kW of electrical power continuously for at least 10 years; four units would provide enough power to establish an outpost. The KRUSTY experiment ran November 2017 through March 2018 at the Nevada National Security Site, ending with a 28-hour full-power test, using a solid cast uranium-235 core about the size of a paper towel roll. | Verified | <https://www.nasa.gov/news-release/demonstration-proves-nuclear-fission-system-can-provide-space-exploration-power/> |
| 19 | Fission Surface Power (40 kWe target) | NASA's Fission Surface Power project targets a 40-kW-class system ('at least 40 kilowatts', enough to continuously run 30 households for ten years per the project page; 33 households per NASA Glenn), under six metric tons and able to operate a decade without human intervention; three $5 million Phase 1 contracts were awarded in 2022. | Verified | <https://www.nasa.gov/exploration-systems-development-mission-directorate/fission-surface-power/> |
| 20 | Fission Surface Power status in 2026 | A NASA release of Jan. 13, 2026 announced a NASA-DOE memorandum of understanding supporting development of a lunar surface reactor by 2030; a second MOU signed Oct. 8, 2026 (effective Nov. 1, 2026) names 'Lunar Reactor-1 (LR-1)', the fission surface power system intended to sustain the Moon Base through darkness, and cites a December 2025 Executive Order directing a launch-ready lunar surface reactor by 2030. Neither release states a power level. | Verified | <https://www.nasa.gov/news-release/nasa-energy-department-advance-new-era-of-nuclear-powered-exploration/> |
| 21 | Lunar habitat power need | A NASA Glenn 'Government Reference Example' lists a lunar habitat at 20 kW during habitation and ~2 kW keep-alive (crew of 4 for 30+ days, 4 times per year), ISRU at 60-70 kW peak (~12 kW keep-alive), and rovers/science experiments at 500-1,000 W. | Verified | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 22 | Mars crewed surface power need | NASA's Moon to Mars white paper says a very modest mission of two crew for no more than 30 days needs at least 10 kW of surface power, while larger architectures with cryogenic propellant manufacturing need hundreds of kW, approaching megawatt class; Mars solar flux is 'at most 45 percent' of typical Earth values. | Verified | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 23 | ISS solar array power | The International Space Station's eight solar arrays provide 75 to 90 kW of power; the solar array wingspan is 109 m (356 ft). | Verified | <https://www.nasa.gov/international-space-station/space-station-facts-and-figures/> |
| 24 | Lunar day/night cycle | NASA's LRO lithograph says each lunar day lasts 14 Earth days and a lunar night lasts 14 Earth days; the Moon's synodic period is 29.53 days (NSSDC); NASA Glenn describes lunar nights as 14-and-a-half Earth days. | Verified | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 25 | Lunar equatorial temperatures (LRO Diviner) | Diviner data show daytime temperatures near the lunar equator reach about 120 C (250 F, 400 K) and night temperatures about -130 C (-208 F, 140 K). | Verified | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 26 | Coldest lunar temperatures (Hermite crater, PSRs) | Diviner detected about -250 C (25 K, -410 F) on the floor of Hermite crater, near the Moon's north pole, described by NASA as the coldest temperature measured anywhere in the solar system (other NASA pages give -248 C / -415 F and -249 C); NASA says LRO has measured temperatures lower than -246 C (-410 F) in permanently shadowed polar craters. | Verified | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> |
| 27 | South-pole illumination: Shackleton rim | Using LOLA topography, Mazarico et al. (Icarus 211, 2011) found a location near the Shackleton crater rim that is sunlit continuously for 240 days each year, with a longest continuous period in total darkness of about 1.5 days; permanently shadowed area totals 12,866 km2 (north) and 16,055 km2 (south). Shackleton is 21 km wide and 4 km deep with a floor in perpetual shadow. | Verified | <https://ntrs.nasa.gov/citations/20120010094> |
| 28 | South-pole illumination percentages (connecting ridge) | Simulations for 2017-2037 (Glaser et al.) found average illumination of the best polar sites ranging from 69.5% to 82.9% at surface level and 77.1% to 88.0% for solar panels 2 m above ground, with the maximum on the ridge between Shackleton and de Gerlache craters; LROC notes parts of that ridge are illuminated up to 90% of the time but nowhere is permanently illuminated. | Verified | <https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/20170007365.pdf> |
| 29 | Moon surface gravity | The Moon's surface gravity is 1.62 m/s2, 0.165 of Earth's (about one-sixth). | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html> |
| 30 | Artemis Base Camp concept (2020) | NASA's October 2020 Artemis Base Camp concept at the lunar South Pole includes an open-top lunar terrain vehicle, a pressurized 'mobile home' rover, and a fixed habitat housing up to four astronauts for a month-long stay, with a goal of stays up to two months; NASA was then developing a fission surface power unit that can continuously provide 10 kW, and early systems must store power for up to eight days because no single location avoids periods of darkness. | Verified | <https://www.nasa.gov/blogs/missions/2020/10/28/lunar-living-nasas-artemis-base-camp-concept/> |
| 31 | Moon Base plan (2026) phases and power | NASA's Moon Base plan has three phases: Phase One (Now-2029) 'Gain Reliable Access, Experiment, and Learn'; Phase Two (2029-2032) 'Build and Expand' with initial power infrastructure including solar array and radioisotope power stations and initial pressurized modules for short stays; Phase Three (2032-Beyond) 'Live and Work on the Moon' with operational fission surface power and 100-cubic-meter-class habitat modules. The JAXA pressurized rover supports missions up to 28 days with up to 14 days between cargo resupplies. | Verified | <https://www.nasa.gov/moonbase-phases/> |
| 32 | Artemis schedule as of late 2026 | Artemis II launched April 1, 2026 and splashed down April 10, 2026 (9 days, 1 hour, 32 minutes; Wiseman, Glover, Koch, Hansen); Artemis III (2027) is a four-crew low-Earth-orbit test of rendezvous and docking between Orion and commercial landers; Artemis IV (early 2028) is planned as the first Artemis crewed Moon landing, with two crew spending about a week near the South Pole. | Verified | <https://www.nasa.gov/humans-in-space/artemis/> |
| 33 | Energy storage for lunar night (batteries, fuel cells, solar towers) | NASA Glenn's reference example lists Vertical Solar Array Technology at 10 kW @ 100 VDC (lower TRL, cannot provide year-round power), Fission Surface Power at 40 kW (low TRL, limited number of units, must be located 1 km+ from other assets, provides power during darkness), batteries as heavy and not operating well at extremely low temperatures, and regenerative fuel cells (water electrolysis storing energy as hydrogen) as low TRL. | Verified | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 34 | Mars Trek / Moon Trek as data sources | NASA Solar System Treks (trek.nasa.gov) hosts Moon Trek and Mars Trek, portals built on real spacecraft data, with tools to calculate distance, elevation profiles (exportable to .csv), Sun angle over a chosen date/time range, 3D-print files and VR flyovers; most layers are served via OGC RESTful WMTS in equirectangular, north-pole and south-pole projections. | Verified | <https://trek.nasa.gov/> |
| 35 | Mars weather feeds are NOT live (data-freshness trap) | On 2026-11-14 the api.nasa.gov InSight weather API returned frozen data for sols 675-681 (Oct 19-26, 2020; average air temperature about -62, pressure about 744-751); the Mars 2020 MEDA JSON feed's newest entry was sol 1133 (2024-04-27: min -79.3, max -24.7, pressure 778.9); the Curiosity REMS feed's newest entry was sol 4995 (2026-08-25: min -71, max -5, pressure 777). | Verified | <https://api.nasa.gov/insight_weather/?api_key=DEMO_KEY&feedtype=json&ver=1.0> |
| 36 | Global dust storm frequency and wind strength | NASA says dust storms grow into planet-encircling events on average once every three Mars years (about 5.5 Earth years); winds in the strongest Martian storms top out at about 60 mph, less than half the speed of some hurricane-force winds on Earth, and Mars' atmosphere is about 1 percent as dense as Earth's. | Verified | <https://www.nasa.gov/solar-system/the-fact-and-fiction-of-martian-dust-storms/> |
| 37 | Mars wind is weak - no wind power, small structural push | NASA's Mars surface power white paper says the highest wind speed measured on the Martian surface was about 30 m/s at the Viking 2 lander site, which on a solar array feels like only a 4 m/s wind on Earth; the atmosphere is too thin to generate sufficient wind power for crewed systems. | Verified | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 38 | How fast the 2018 storm hit, and nuclear vs solar | NASA's white paper says Opportunity went from clear skies to the darkest it had previously recorded (tau 4.9) within three Martian sols, then a virtual blackout four sols later; Curiosity's radioisotope power system was unaffected by the same storm. Global storms can persist for several weeks or months. | Verified | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 39 | Mars daylight fraction and temperature extremes | NASA's white paper says typical mid-latitude Mars missions experience a roughly 25-hour day/night cycle with approximately 50 percent of the time under illumination, and Mars surface temperatures vary from as warm as 30 C to as cold as -140 C depending on location and season; Earth departure windows for Mars open every 26 months. | Verified | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-surface-power-generation-challenges-and-considerations.pdf> |
| 40 | Earth reference values for comparison bars | NSSDC Earth Fact Sheet: surface pressure 1014 mb, average temperature 288 K (15 C), atmosphere 78.08% N2 and 20.95% O2, solar irradiance 1361.0 W/m2; Mars average temperature is ~214 K (-59 C) and the Moon receives the same 1361.0 W/m2 as Earth. | Verified | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html> |
| 41 | Reactor siting rule and lunar grid scale | NASA Glenn's reference example says Fission Surface Power units are limited in number and must be located 1 km or more from other assets; its notional lunar grid has about 10 km total line distance and ~100 kW total power, with ISRU excavation in a permanently shadowed region 3-5 km from the production plant on a crater rim. | Verified | <https://ntrs.nasa.gov/api/citations/20250000763/downloads/Csank_Pr_LunarSurfacePowerJAXA20250000763.pdf> |
| 42 | VIPER status (current for late 2026) | NASA's VIPER rover is to be delivered to Mons Mouton near the lunar South Pole by a Blue Origin Blue Moon MK-1 lander under CLPS task order CS-7 (total potential value $190 million), with delivery targeted for late 2027, for a 100-day mission searching for ice and other volatiles. | Verified | <https://science.nasa.gov/mission/viper/> |
| 43 | Opportunity June 10, 2018 on a NASA page (sol, energy, tau) | A NASA Science resource states that on June 10, 2018, the 5,111th sol of Opportunity's operations, the tau measurement (10.5) was higher than any previously measured on Mars and the energy level (21 watt-hours) was the lowest ever measured on Opportunity at that time; the atmosphere began darkening May 30, 2018. | Verified | <https://science.nasa.gov/resource/on-mars-light-is-energy/> |

<details><summary>Verification notes for this section</summary>

METHOD (2026-11-14): Every source listed was opened by me with the fetch tool. Four NASA PDFs (MMRTG fact sheet, LRO Diviner lithograph, Csank lunar power slides, Mars surface power white paper) came back as binary; the fetch tool saved its own copies and I text-extracted those to stdout with pdftotext and read the text directly (no files written by me). All 35 researcher facts were checked: 34 verified (several with wording/attribution fixes folded into the claim), 1 corrected (Opportunity watt-hours), 0 dropped. 8 facts added, all opened.  KEY CORRECTIONS AND NEW CONFLICTS 1. Opportunity energy on June 10, 2018: a NASA primary page exists (science.nasa.gov/resource/on-mars-light-is-energy/) and says 21 Wh and tau 10.5, versus 22 Wh (Planetary Society quoting MER team) and tau 10.8 (two JPL news articles). The 645 Wh 'before' figure is still secondary-only (Planetary Society). Sol 5,111 for last contact is now confirmed on that NASA page. 2. MMRTG attribution: 'a few percent each year', 2 x ~43 Ah batteries and the 900 W peak are on the JPL Mars 2020 press kit power page, not on the MMRTG fact sheet. The ~2.5%/yr figure is derived and must be labelled so. NASA's Pu-238 page says half-life 88 years. 3. Artemis: best single citation is nasa.gov/humans-in-space/artemis/ (updated Oct 21, 2026), which states Artemis IV (2028) is the first crewed landing and Artemis III (2027) a LEO docking test. The Artemis IV mission page (updated Mar 16, 2026) says 'Early 2028' but still carries legacy text referring to Artemis III science, so it is a weaker citation. I could not locate the Oct 23, 2026 NASA blog the researcher cited. 4. Earth pressure: use NSSDC 1014 mb (opened) instead of the from-memory 101,325 Pa. 5. Hermite 'near the north pole' is confirmed on science.nasa.gov/image-detail/hermite (which gives -249 C); NASA therefore has three roundings (-248, -249, -250 C). 25 K from the lithograph is the cleanest. 6. Illumination: 82.9% (surface) and 88.0% (2 m) are tops of ranges across best sites, and 2 m is a lander-deck panel height; do not present as a measured before/after for one mast. Mazarico's 240 days / 1.5 days are computed from LOLA topography; the abstract attaches no height to them. 7. Dust-storm frequency 'once every three Mars years (about 5.5 Earth years)' is now confirmed on an opened NASA page; do not print the 2016 'two global storms since 1997' count.  STILL UNVERIFIED / DO NOT PRINT - 100 kW lunar reactor target: no primary source opened by me or the researcher. (The Csank slide's '~100 kW' is total notional grid power, not a reactor rating.) - Mars gravity 3.71 m/s2, Artemis Base Camp '45 days', the phrase 'habitable mobility platform' in the 2020 blog, and the JPL press-kit '38%' wording were not seen in sources I opened. - Peer-reviewed MEDA climatology (Rodriguez-Manfredi et al. 2023) not opened; Jezero numbers are specific sols (43-44) plus an undated NASA summary. - Published kWh size for lunar-night energy storage: NOT FOUND. - Trek layer IDs and whether the api.nasa.gov WMTS mirror needs a key: not verified.  UNIT / FRESHNESS WARNINGS - mars.nasa.gov weather feeds do not label temperature units (deg C by convention) and min_temp/max_temp are not defined as air temperature in the JSON; pressure text refers to Pascals. Newest entries when read: MSL sol 4995 (2026-08-25, ~81 days old), Mars 2020 sol 1133 (2024-04-27), InSight sols 675-681 (Oct 2020, mission ended Dec 2022). None may be shown as live. - Derived numbers that NASA does not print and that need a 'derived' tag on screen: 43.1% sunlight, 38% gravity, 0.6-0.7% pressure, 2.5%/yr MMRTG decay, 354-hour lunar night, 3% storm output, 90% InSight loss. - Pages describing plans (Artemis IV early 2028, LR-1 by 2030, Moon Base phases, VIPER late 2027, FSP 'early 2030s' on a page last updated Sept 2025) should carry an 'as of Nov 2026' stamp; the FSP project page predates and partly conflicts with the 2026 LR-1 'by 2030' releases. - Fission/Kilopower/FSP figures are design targets or ground tests (KRUSTY 2018), not flown hardware.

</details>

#### Communications and mission operations

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Earth-Mars one-way light time (range, NASA Mars Relay Network page) | NASA's Mars Relay Network page says the Earth-Mars distance varies between 33.9 million miles (54.6 million km, about 3 minutes light time) and 248.7 million miles (400.2 million km, about 22.4 minutes), one way. | Verified | <https://science.nasa.gov/mars/mars-relay-network/> |
| 2 | Earth-Mars one-way light time (range, NASA Goddard rounding) | NASA Goddard says the delay is about four minutes at Mars' closest approach (about 35 million miles) and around 24 minutes at greatest distance (about 250 million miles); astronauts would wait 4 to 24 minutes for a message to reach mission control and another 4 to 24 minutes for a response. | Verified | <https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/> |
| 3 | Earth-Mars light time on a specific real date | On Perseverance landing day, Feb. 18, 2021, the one-way light time Mars to Earth was about 11 minutes 22 seconds, with Mars 127 million miles (205 million km) from Earth. | Verified | <https://www.jpl.nasa.gov/news/press_kits/mars_2020/landing/quick_facts/> |
| 4 | Crewed Mars mission delay profile | A NASA Langley ASCEND 2022 analysis found communication delays vary from 0 to 22 minutes over a crewed Mars mission, peaking while the crew is at or has just departed Mars; the maximum one-way delay is about 22 minutes for any mission and 15 to 20 minutes while the crew is at Mars. | Verified | <https://ntrs.nasa.gov/api/citations/20220013418/downloads/ASCEND-Communication%20Delays,%20Disruptions,%20and%20Blackouts%20for%20Crewed%20Mars%20Missions.pdf> |
| 5 | Mars solar conjunction: frequency and cause | Mars solar conjunction occurs approximately every 26 months, when Mars passes almost directly behind the Sun from Earth's perspective; radio transmissions risk being corrupted, so NASA Mars missions have a moratorium on sending commands. JPL's 2023 release rounds the frequency to 'every two years'. | Verified | <https://science.nasa.gov/resource/geometry-of-mars-solar-conjunction/> |
| 6 | Mars solar conjunction November 2023 (duration of command pause) | For the 2023 conjunction NASA stopped sending commands to its Mars fleet for two weeks, Nov. 11 to 25, 2023, including two days when the agency would not hear from the fleet while Mars was fully behind the Sun; rovers stayed parked and kept monitoring surface conditions, weather and radiation. | Verified | <https://www.jpl.nasa.gov/news/nasas-mars-fleet-will-still-conduct-science-while-lying-low/> |
| 7 | Most recent Mars solar conjunction (Dec 2025 - Jan 2026) | The Curiosity team stated the most recent conjunction would last from Dec. 27 (2025) to Jan. 20 (2026); Curiosity's first post-conjunction Earth planning date was Friday, Jan. 30, 2026. JPL Horizons shows Mars' minimum solar elongation (0.95 degrees) on Jan. 9, 2026, with a one-way light time of about 20.0 minutes. | Verified | <https://science.nasa.gov/blog/curiosity-blog-sols-4750-4762-see-you-on-the-other-side-of-the-sun/> |
| 8 | Next Mars solar conjunction | JPL Horizons (geocentric ephemeris, daily step) shows Mars' next minimum solar elongation, 0.81 degrees, on March 21, 2028, with Mars 2.388 AU from Earth and a one-way light time of 19.86 minutes. | Corrected | <https://ssd.jpl.nasa.gov/api/horizons.api?format=text&COMMAND='499'&OBJ_DATA='NO'&MAKE_EPHEM='YES'&EPHEM_TYPE='OBSERVER'&CENTER='500@399'&START_TIME='2028-03-14'&STOP_TIME='2028-03-28'&STEP_SIZE='1d'&QUANTITIES='20,21,23'> |
| 9 | Conjunction blackout for a crewed Mars mission | NASA's 2023 Moon to Mars architecture white paper says direct spacecraft-to-Earth blackouts on a crewed round-trip Mars mission are inevitable and can last weeks: about 13 days for a representative ~1,000-day minimum-energy (long-stay) mission, occurring in the Mars vicinity, and about three weeks (21 days) for a representative 850-day short-stay mission, occurring during the inbound transit; one-way delay can be upward of 21-23 minutes. | Verified | <https://www.nasa.gov/wp-content/uploads/2024/01/mars-communications-disruption-and-delay.pdf> |
| 10 | NASA statement: Mars crews cannot rely on real-time Mission Control | NASA's 2025 architecture white paper says astronauts at Mars would experience a one-way light-time communications delay between 4 and 24 minutes, making real-time conversation with Earth impractical, and that distance and delays will greatly reduce Earth-based flight control operations support, requiring Earth-independent and autonomous capabilities. | Verified | <https://www.nasa.gov/wp-content/uploads/2025/12/acr25-wp-why-moon-and-mars-v2.pdf> |
| 11 | NASA Human Research Program hazard 'Distance from Earth' | NASA HRP states Mars is on average 140 million miles from Earth, a Mars trip would last roughly three years (versus a three-day lunar trip), and crews face a communication delay of up to 20 minutes one way with minimal support from teams on Earth. | Verified | <https://www.nasa.gov/hrp/hazard-distance-from-earth/> |
| 12 | Earth-Moon communication delay | NASA TM-20250003885 Table 1 lists an Apollo one-way latency of 1.3 seconds and says lunar missions may experience one-way latencies of 3 to 14 seconds once system delays are included; NASA's Radio JOVE activity computes 1.33 s one way for 400,000 km; ESA states 1.27 s on average. | Verified | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 13 | Deep Space Network: three sites and why | The DSN has three sites, Goldstone (near Barstow, California), near Madrid (Spain) and near Canberra (Australia), approximately 120 degrees apart in longitude; each site has one 230-foot (70-meter) antenna and each complex has at least four antenna stations. | Verified | <https://www.nasa.gov/directorates/somd/space-communications-navigation-program/what-is-the-deep-space-network/> |
| 14 | Mars Relay Network orbiters and data volume (2026) | NASA's page (updated Jun 05, 2026) lists Odyssey, MRO and ESA's TGO as relay orbiters with ESA's Mars Express as backup. Feb-May 2026 average relay volumes: TGO 2,228.1 Mb/day, MRO 850.6 Mb/day, Odyssey 107.3 Mb/day, MAVEN 0. Each orbiter has 2-4 passes per day, but passes actually used for relay are Odyssey 0-1, MRO 1-3, TGO 2-4 (Mars Express 1-3 passes, 0 used). | Corrected | <https://science.nasa.gov/mars/mars-relay-network/> |
| 15 | MAVEN status (relay orbiter lost) | MAVEN was last heard from on Dec. 6 (2025); a NASA review board found the spacecraft not recoverable and NASA declared the mission at an end on June 3, 2026. Its relay volume was 0 in Feb-May 2026 versus an 897.5 Mb/day average through 2025. | Verified | <https://science.nasa.gov/mars/mars-relay-network/> |
| 16 | Perseverance radio links (relay vs direct to Earth) | Perseverance's UHF antenna sends up to 2 megabits per second on the rover-to-orbiter relay link, and 99.9% of its science data goes through that antenna to passing orbiters; its X-band high-gain antenna links with Earth at 160/500 bits per second or faster to/from 34 m DSN antennas, or 800/3,000 bits per second or faster to/from 70 m antennas. | Verified | <https://science.nasa.gov/mission/mars-2020-perseverance/rover-components/> |
| 17 | Rover line-of-sight and relay cadence | NASA states the rovers lack line-of-sight to Earth for about 12 hours per day due to Mars' rotation and talk to nearby orbiters at up to 2 Mbps; Mars Relay Network orbiters return rover data to Earth about a dozen times a week. A per-sol data volume specifically for Perseverance was not found. | Verified | <https://science.nasa.gov/mars/mars-relay-network/> |
| 18 | CHAPEA analog: communication delay protocol | NASA's CHAPEA missions put four research volunteers in a roughly 1,700-square-foot habitat at Johnson Space Center for 378 days with communication delays of up to 22 minutes each way; Mission 1 ran June 25, 2023 to July 6, 2024 and Mission 2 ran Oct. 19, 2025 to Oct. 31, 2026. | Verified | <https://www.nasa.gov/centers-and-facilities/johnson/chapea-mission-2-crew-reflects-after-378-days-on-simulated-mars/> |
| 19 | CHAPEA simulated communication blackout | NASA's CHAPEA page says the crew discusses navigating a simulated two-week communication blackout. | Verified | <https://www.nasa.gov/humans-in-space/chapea/> |
| 20 | HERA analog: communication delay protocol | NASA's HERA is a 650-square-foot habitat at Johnson Space Center where crews of four research volunteers spend up to 45 days on simulated deep-space missions, with communication delays of up to five minutes each way with Mission Control. | Verified | <https://www.nasa.gov/humans-in-space/houston-do-you-copy-hera-crew-navigates-communication-delays/> |
| 21 | NASA guidance on communicating under delay | NASA TM-20250003885 (2025) reports that NEEMO and HERA studies with delays of 50 seconds to 5 minutes showed message-thread problems that structured protocols address, says responsibilities must shift to the onboard team as delays increase, and recommends analog delays be increased gradually rather than in sizeable steps (CHAPEA does this; HERA still uses steps). | Verified | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 22 | Mars launch window and transit time | NASA says Earth and Mars align for the most energy-efficient trip about once every 26 months and that the cruise to Mars lasts about 200 days; Perseverance launched July 30, 2020 on a seven-month journey and landed Feb. 18, 2021. | Verified | <https://science.nasa.gov/planetary-science/programs/mars-exploration/mission-timeline/> |
| 23 | Mars mission classes: surface stay and total duration (DRA 5.0) | NASA's Mars Design Reference Architecture 5.0 (2009) gives short-stay (opposition-class) missions 500 to 650 days total with 30 to 90 days in the vicinity of Mars, and long-stay (conjunction-class) missions 890 to 950 days total with 475 to 540 days at Mars and zero-g transits of about 180 days. | Verified | <https://www.nasa.gov/wp-content/uploads/2015/09/373665main_nasa-sp-2009-566.pdf> |
| 24 | Mars crew size in NASA reference architectures | DRA 5.0 (2009) sends a crew of six on each Mars mission; NASA's Deep Space Exploration Plans document lists, as representative initial study assumptions, four crew members to Mars orbit with two descending to live on the surface for a 30-sol stay. | Verified | <https://www.nasa.gov/wp-content/uploads/2023/10/deepspace-exploration-plans-071122.pdf> |
| 25 | Artemis lunar surface stay and crew (current plan, 2026) | Per NASA's mission pages, Artemis III (2027, four crew) is a crewed demonstration carrying out objectives in low Earth orbit, and Artemis IV (early 2028) launches four astronauts in Orion on SLS, with two descending to the surface to spend approximately a week near the Moon's South Pole. | Verified | <https://www.nasa.gov/mission/artemis-iv/> |
| 26 | Longer lunar surface missions (planning figure) | NASA's 2025 architecture white paper projects annual logistics needs of 5,000 to 6,000 kg for four crew members operating on the lunar surface for approximately 30 days, and says Mars missions could last two to three years. | Verified | <https://www.nasa.gov/wp-content/uploads/2025/12/acr25-wp-why-moon-and-mars-v2.pdf> |
| 27 | Science objective: Perseverance sample collection at Jezero | NASA's sample page (updated Jun 20, 2026) shows 30 of 38 sample tubes used (27 rock cores, 2 regolith, 1 atmospheric) plus 3 of 5 witness tubes, out of 43 tubes carried. NASA's May 12, 2026 release says Perseverance had abraded 62 rocks, collected 27 rock cores (25 sealed, 2 unsealed) and driven almost 26 miles (42 km); the Oct. 12, 2026 mission blog still says 29 rock and regolith samples. | Verified | <https://science.nasa.gov/mission/mars-2020-perseverance/mars-rock-samples/> |
| 28 | Science objective: lunar ice prospecting, VIPER status 2026 | NASA's Oct. 20, 2026 update says the VIPER rover is at Johnson Space Center, fully built and undergoing final testing; after delivery by a Blue Moon Mark 1 lander it will embark on a mission to the lunar South Pole region in 2027 and travel more than 18 miles (30 km). | Verified | <https://www.nasa.gov/missions/moon-base/nasa-provides-progress-update-on-moon-base-rovers/> |
| 29 | Science objective: PRIME-1 ice-mining experiment | NASA's PRIME-1 (1-meter TRIDENT drill plus MSOLO mass spectrometer) reached the Moon on Intuitive Machines' Athena lander on March 6, 2025, about 400 meters from its Mons Mouton target; the lander rested on its side in a crater, could not recharge, and gave about 10 hours of operation instead of 10 days, but 100% of the instruments worked. No lunar ice was detected. | Verified | <https://www.nasa.gov/missions/artemis/nasas-lunar-drill-technology-passes-tests-on-the-moon/> |
| 30 | Kid-friendly definition of a Mars day (sol) | A Mars solar day (sol) has a mean period of 24 hours 39 minutes 35.244 seconds (sidereal day 24 h 37 m 22.663 s); the Mars tropical year is 686.9725 days or 668.5921 sols. NASA's Grades K-4 article says a day on Mars is 24.6 hours and a year is 687 Earth days. | Verified | <https://www.giss.nasa.gov/tools/mars24/help/notes.html> |
| 31 | NASA STEM resources and wording for ages 7-12 | NASA publishes paired student explainers in Grades K-4 and Grades 5-8 bands (for example 'What Is Microgravity?' and 'What Is Mars?'); the K-4 version says 'Microgravity is when things seem to be weightless.' NASA's 'Space Faring: The Radiation Challenge' has a Middle School Edition, but its exact grade band was not confirmed. | Corrected | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-microgravity-grades-k-4/> |
| 32 | CSA Junior Astronauts resources | The Canadian Space Agency's Junior Astronauts teamwork and communication activities are designed for groups of kids in Grades 6 to 9 and include 'Survivor: Moon' (90 minutes), in which players prioritize items the crew needs to return safely to a lunar base. | Verified | <https://asc-csa.gc.ca/eng/youth-educators/junior-astronauts/activities/teamwork-and-communication/default.asp> |
| 33 | live source for today's Earth-Mars and Earth-Moon signal time (DSN Now) | NASA's DSN Now ('the real time status of communications with our deep space explorers') has a public XML feed listing, per antenna, the spacecraft target with range and round-trip light time. When opened on Nov. 14, 2026 it showed Mars 2020, Odyssey, MRO and TGO at a range of 197,000,000 with round-trip light time 1,320 (about 11 minutes one way), and LRO at 403,000 with round-trip light time 2.69. | Verified | <https://eyes.nasa.gov/dsn/data/dsn.xml> |
| 34 | computed light time for any date (JPL Horizons) | The JPL Horizons API returns Mars' distance and one-way light time for any date; for example at the Jan. 9, 2026 conjunction Mars was 2.404 AU from Earth with a one-way light time of 19.99 minutes and solar elongation 0.95 degrees. | Verified | <https://ssd.jpl.nasa.gov/api/horizons.api?format=text&COMMAND='499'&OBJ_DATA='NO'&MAKE_EPHEM='YES'&EPHEM_TYPE='OBSERVER'&CENTER='500@399'&START_TIME='2026-01-03'&STOP_TIME='2026-01-15'&STEP_SIZE='1d'&QUANTITIES='20,21,23'> |
| 35 | Moon average distance | NASA says the Moon is an average of 238,855 miles (384,400 kilometers) away; ESA says a radio signal takes on average 1.27 seconds to travel from Moon to Earth. | Verified | <https://science.nasa.gov/moon/facts/> |
| 36 | Artemis-era lunar latency by data type | NASA TM-20250003885 Table 1 estimates one-way lunar latencies for Artemis II-IV between Orion and Mission Control Houston via the DSN: command 2.7 s nominal and 3.9 s worst case; telemetry 5.9 s and 8.6 s; voice and video 5.6 s and 6.5 s; Apollo was 1.3 s. As of 2024, expected Artemis latencies are twice Apollo's, with worst cases up to five times. | Verified | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> |
| 37 | Artemis II has flown | Artemis II launched April 1, 2026 and splashed down April 10, 2026 after 9 days, 1 hour, 32 minutes, with four astronauts: Reid Wiseman, Victor Glover and Christina Koch of NASA and Jeremy Hansen of the Canadian Space Agency. | Verified | <https://www.nasa.gov/mission/artemis-ii/> |
| 38 | Perseverance off-world driving record | On Oct. 11, 2026 (sol 2,006) Perseverance's odometer reached 28.10 miles (45.22 km), passing Opportunity's 28.06 miles (45.16 km); it has driven more than 90% of its distance using AutoNav and as much as 1,351 feet (412 meters) in a single sol. | Verified | <https://science.nasa.gov/blogs/perseverance-mars-rover/2026/10/12/nasas-perseverance-sets-off-world-record-for-total-distance-driven/> |
| 39 | laser communications as a future upgrade (DSOC) | NASA's Deep Space Optical Communications demo on Psyche reached its maximum rate of 267 megabits per second (first on Dec. 11, 2023, from 19 million miles) and could still do so at about 33 million miles; on June 24, 2024, from about 240 million miles, it sustained 6.25 Mbps with a maximum of 8.3 Mbps. JPL says lasers can carry data at rates up to 100 times higher than radio. | Verified | <https://www.jpl.nasa.gov/news/nasas-laser-comms-demo-makes-deep-space-record-completes-first-phase/> |
| 40 | how the relay actually returns data | NASA says Mars Relay Network orbiters collect rover data first and then turn their antennas to Earth, returning data about a dozen times a week; the length of each pass varies from day to day, and the network currently relays for the Curiosity and Perseverance rovers. | Verified | <https://science.nasa.gov/mars/mars-relay-network/> |

<details><summary>Verification notes for this section</summary>

All 32 researcher facts were re-opened: 29 verified, 3 corrected, none dropped or left unverified. I added 8 facts, each opened by me.  METHOD: Web pages were opened with the fetch tool. The six NASA PDFs (ASCEND paper, Mars comms white paper, Why Moon and Mars, TM-20250003885, Deep Space Exploration Plans, DRA 5.0) and the Radio JOVE activity could not be parsed by the fetch tool; I ran pdftotext to stdout on the copies the fetch tool saved and found the quoted sentences. No files were written to the project.  CORRECTIONS: - Relay passes: '2-4 passes per day' is total overflights per orbiter. Passes actually used for relay are Odyssey 0-1, MRO 1-3, TGO 2-4. - Next conjunction: March 21, 2028 is now confirmed with JPL Horizons (minimum elongation 0.81 degrees), so it can be attributed to NASA/JPL. The hour is not verified. - Space Faring radiation unit: the 'grades 6-8' label is not confirmed. NASA's STEM pages returned only a search page, and snippets suggest Grades 5-8.  NUANCES THAT MATTER FOR JUDGES: - The 21-day blackout in the Mars comms white paper happens during the inbound transit of a short-stay mission, not on the surface. Only the 13-day figure is a Mars-vicinity blackout. Both assume a 2-degree Sun-Earth-spacecraft threshold. - At conjunction the one-way delay is about 20.0 minutes (Horizons, Jan. 9, 2026), not the 22.4-minute maximum. - 14 Earth days is about 13.6 sols; do not print '14 sols' as NASA's figure. - The Perseverance X-band pairs (160/500 and 800/3,000 bps) are not labelled uplink or downlink on the page. - 'About 3% longer' for a sol is not a NASA quote; the arithmetic is 2.75%. - The 99.9% UHF figure is from the 2021 landing press kit, which still lists MAVEN as a relay; MAVEN ended June 3, 2026. - The CHAPEA page does not itself tie the two-week blackout to solar conjunction. - Sample count is unchanged as of the Oct. 12, 2026 NASA blog ('29 rock and regolith samples', plus 1 atmospheric = 30), so the label can read 'as of October 2026'. The researcher's 'nothing newer than June 2026' note is superseded.  CONFLICTS CONFIRMED BETWEEN NASA SOURCES: Mars delay range is 3-22.4 min (Mars Relay Network), 4-24 min (Goddard, 2025 white paper), up to 20 min (HRP), up to 22 min (TM, CHAPEA, ASCEND). Recommend 3-22.4 min with km for the simulation. Conjunction frequency is 'approximately every 26 months' (resource page) versus 'every two years' (JPL 2023). DSOC June 24, 2024 distance is 249 million miles on the NASA mission page versus about 240 million in the JPL release.  LIVE VS STATIC: The only live source verified is the DSN Now XML feed (eyes.nasa.gov/dsn/data/dsn.xml). Its units are not stated in the feed; km and seconds are inferred. Everything else is static or a dated snapshot and should carry an as-of date. JPL Horizons values are computed ephemerides, not live measurements.  COULD NOT OPEN OR CONFIRM: science.nasa.gov/mission/msl-curiosity/rover-components/ and /communications/ returned 404, so no per-pass or per-sol megabit figure for any rover is verified (the '100 to 250 megabits per eight-minute pass' and '500 megabits per sol' figures are snippet-only; do not use). The old Radio JOVE HTML URL I tried returned 404 (the PDF activity worked). '2.6 s round trip' to the Moon appears verbatim on no opened NASA page. The '45 minutes each way' snippet and the Blue Moon MK1 contract dependency for VIPER were not checked. Roblox limits and DONKI endpoints were not part of this fact list and were not checked.

</details>

#### Collectible cards (myth vs science)

These facts come from the first fact-check pass of 14 November 2026, run on the team's original design document.

| # | Card | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Mini Earth | At Space Station altitude gravity is still about 90% of Earth's; astronauts float because they are in continuous free fall | Verified (page opened) | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-microgravity-grades-5-8/> |
| 2 | Laika | Laika, launched on Sputnik 2 on 3 November 1957, was the first animal to orbit Earth (not the first living thing in space: fruit flies flew in 1947) | Verified (search snippet of NASA page) | <https://www.nasa.gov/history/60-years-ago-the-first-animal-in-orbit/> |
| 3 | Cheese | Lunar soil is about 40–45% oxygen by mass (the game says about 43%); highlands are anorthosite, maria are basalt | Verified (search snippet of ESA page) | <https://www.esa.int/Enabling_Support/Space_Engineering_Technology/Team_chosen_to_make_first_oxygen_on_the_Moon> |
| 4 | Mars potato | The "Face on Mars" was photographed by the Viking 1 orbiter on 25 July 1976 in Cydonia; later images (1998, 2001) showed an eroded mesa | Verified (search snippet of NASA page) | <https://science.nasa.gov/resource/mars-orbiter-camera-views-the-face-on-mars-comparison-with-viking/> |
| 5 | Mars potato | Phoenix found perchlorates in Martian soil in 2008, about 0.4–0.6% by mass; perchlorate is toxic to people | Verified (search snippet of paper) | <https://ui.adsabs.harvard.edu/abs/2013IJAsB..12..321D> |

#### Base building, rovers and pets (Stage 6)

Facts behind the Stage 6 changes: C.A.R.L. drives on treads and hops with gas puffs, the backpack double jump, the laser antenna, the ice drills, building with Moon dust, tall solar arrays and the four pets. Every source below was opened on 14 November 2026 (date accessed).

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | The Moon has almost no air | NASA's 'The Moon's Atmosphere' page says the Moon has an atmosphere, 'but just barely'; it is mostly an exosphere, 'which itself is mostly empty space', with about one million billion (10^15) times fewer molecules per cubic centimeter than Earth's atmosphere, so a visitor 'might think it had no atmosphere at all'. NASA's Moon facts page adds that this exosphere gives no protection from the Sun's radiation or meteoroid impacts. | Verified | <https://science.nasa.gov/moon/lunar-atmosphere/> |
| 2 | Propellers need air (why C.A.R.L. drives on treads) | NASA Glenn's 'Propeller Thrust' page explains that the engine turns the propeller, which 'does work on the airflow': the surrounding air passes through the spinning propeller and leaves faster than it came in, and that speed-up of the air is what makes thrust. With almost no air (row 1) a propeller has nothing to push, so C.A.R.L. drives on treads. The 'no propeller flight on the Moon' sentence is team reasoning from rows 1 and 2, not a NASA quote. | Verified | <https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/propeller-thrust/> |
| 3 | Rockets and gas thrusters work without air | NASA's kids' page 'What Is a Rocket? (Grades K-4)' says 'A rocket engine doesn't need air' and 'carries with it everything it needs'; 'The rocket pushes on its exhaust. The exhaust pushes the rocket, too', and rockets work by Newton's third law of motion. This is why C.A.R.L.'s hop and the backpack double jump use gas puffs. | Verified | <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-a-rocket-grades-k-4/> |
| 4 | Newton's third law (wording) | NASA Glenn: 'Whenever one object exerts a force on a second object, the second object exerts an equal and opposite force on the first.' | Verified | <https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/newtons-laws-of-motion/> |
| 5 | Laser communication carries more data than radio | NASA Goddard (May 12, 2021, 'Laser Communications: Empowering More Data Than Ever Before'): 'Laser communications will enable 10 to 100 times more data transmitted back to Earth than current radio frequency systems.' NASA's LCRD article (June 28, 2023, 'NASA's Laser Communications Relay: A Year of Experimentation') says infrared lasers let missions send 10 to 100 times more data in a single transmission; NASA's Laser Communications page stresses that laser and radio signals both travel at light speed, so the gain is more data per link, not a faster trip. | Verified | <https://www.nasa.gov/feature/goddard/2021/laser-communications-empowering-more-data-than-ever-before> |
| 6 | The Moon's dark patches (maria) and what the Moon is made of | NASA's Moon facts page: 'The dark features, called maria (Latin for seas), are impact basins that were filled with lava' between 4.2 and 1.2 billion years ago; 'Nearly the entire Moon is covered by a rubble pile of charcoal-gray, powdery dust, and rocky debris' called the lunar regolith, with fractured bedrock (megaregolith) beneath. Consistent with the Cheese card (Collectible cards row 3): the Moon is rock and dust, not cheese. | Verified | <https://science.nasa.gov/moon/facts/> |
| 7 | The rabbit in the Moon (many cultures) | The encyclopedia article 'Moon rabbit' says the dark maria on the Moon's near side are read as a rabbit or hare: in China the Jade Rabbit (Yutu), companion of Chang'e, pounds the elixir of life (earliest source the Chu Ci); in Japan it pounds rice for mochi, in Korea for tteok; Vietnam and the Cree also have moon-rabbit stories; in Aztec (Mexica) tradition the gods throw a rabbit at the face of Tecciztecatl after he becomes the Moon, dimming his light (cited to Michael E. Smith, The Aztecs, 3rd ed., 2012, p. 200). A separate Aztec version in which Quetzalcoatl lifts a kind rabbit to the Moon is marked 'citation needed' there, so the game does not tell it. | Verified (encyclopedia, secondary) | <https://en.wikipedia.org/wiki/Moon_rabbit> |
| 8 | Ham the chimpanzee | NASA image caption: 'Launch of the Mercury-Redstone 2 (MR-2) vehicle on Jan. 31, 1961. The 16-minute suborbital flight carried biomedical test subject chimpanzee (Ham) aboard.' NASA's 'A Brief History of Animals in Space' says Ham performed well, was found only 'slightly fatigued and dehydrated' after the flight, and later lived at the Washington Zoo. Ham was a chimpanzee (an ape), not a monkey. | Verified | <https://www.nasa.gov/image-detail/amf-s61-01942> |
| 9 | Monkeys reached space before people | NASA's 'A Brief History of Animals in Space': 'On June 14, 1949, a second V-2 flight carrying a live Air Force Aeromedical Laboratory monkey, Albert II, attained an altitude of 83 miles.' The Planetary Society: 'Yuri Gagarin became the first human to fly in space on 12 April 1961.' | Verified | <https://www.nasa.gov/history/a-brief-history-of-animals-in-space/> |
| 10 | Laika, first animal in orbit (page now opened) | NASA's '60 years ago: The First Animal in Orbit' (John Uri, Nov. 6, 2017) says Sputnik 2 launched on November 3, 1957 carrying the dog Laika, 'the first animal to orbit the Earth'. This upgrades Collectible cards row 2 from search snippet to page opened. | Verified | <https://www.nasa.gov/history/60-years-ago-the-first-animal-in-orbit/> |
| 11 | Ice drill test at the Moon's south pole (PRIME-1 / TRIDENT) | NASA (Apr. 29, 2025, 'NASA's Lunar Drill Technology Passes Tests on the Moon'): PRIME-1 carried TRIDENT, a 1-meter-long drill by Honeybee Robotics, on Intuitive Machines' IM-2 Athena lander, which touched down March 6, 2025 about 400 m from Mons Mouton near the South Pole and ended on its side in a crater. On command the auger rotated, the drill extended fully and the percussion system hammered; the MSOLO mass spectrometer ran gas scans; '100% of the instruments worked', but operations lasted 'closer to 10 hours' instead of the planned 10 days. Gases detected were mostly human-made (vented propellant, traces of Earth water). The game says the drill was 'tested', never that it found ice (consistent with Communications row 29). | Verified | <https://www.nasa.gov/missions/artemis/nasas-lunar-drill-technology-passes-tests-on-the-moon/> |
| 12 | Building with Moon dust (MMPACT) | NASA's MMPACT project (Marshall) aims to 'create infrastructure on the lunar surface via construction of landing pads, habitats, shelters, roadways, berms and blast shields using lunar regolith-based materials', leveraging NASA's 3D Printed Mars Habitat Challenge (IAC 2022 overview, NTRS 20220013524). The project's ASCEND slides (NTRS 20210022078) list regolith processes 'Cementitious, Geopolymers, Thermosetting materials, including melting, Laser sintered, Microwave sintered', with a goal to 'Demonstrate microwave sintering construction of subscale structures' using lunar regolith simulant, and an initial demonstration mission DM-1 planned for 2026 (a plan in old slides, not a flown result). | Verified | <https://ntrs.nasa.gov/citations/20220013524> |
| 13 | Tall vertical solar arrays for the low polar Sun | NASA (Aug. 23, 2022, 'Three Companies to Help NASA Advance Solar Array Technology for Moon'): the vertical orientation and height of the new designs help prevent loss of power at the lunar poles 'where the Sun does not rise very far above the horizon'; the arrays can autonomously deploy up to 32 feet high (about 9.8 m, derived) and retract for relocation; $19.4 million total to Astrobotic, Honeybee Robotics and Lockheed Martin, with the goal of deploying one near the South Pole near the end of the decade. NASA Johnson (Nov. 19, 2024) tested prototypes in its thermal vacuum Chamber A. Consistent with Power rows 28 and 33 (best ridge sites, panels 2 m up, Vertical Solar Array Technology at 10 kW). | Verified | <https://www.nasa.gov/news-release/three-companies-to-help-nasa-advance-solar-array-technology-for-moon> |
| 14 | Albert II altitude in km | 83 miles is about 134 km (derived: 83 x 1.609). The game does not show this number. | Verified (derived) | <https://www.nasa.gov/history/a-brief-history-of-animals-in-space/> |

<details><summary>Verification notes for this section</summary>

METHOD (2026-11-14, date accessed for every source): NASA pages were opened with a fetch tool that returns short quoted fragments. The MMPACT ASCEND PDF was text-extracted with pdftotext to stdout (the copy stays in the session tool-results folder; nothing extra was written to the project). An encyclopedia source was used only where NASA has no page (rabbit legends).

SECOND SOURCES OPENED: NASA LCRD article <https://www.nasa.gov/missions/tech-demonstration/nasas-laser-communications-relay-a-year-of-experimentation/>; NASA Laser Communications page <https://www.nasa.gov/directorates/spacetech/lasercomms> (no multiplier; stresses more data per link); NASA Moon facts <https://science.nasa.gov/moon/facts/> (exosphere); MMPACT slides <https://ntrs.nasa.gov/api/citations/20210022078/downloads/MMPACT_ASCEND.pdf>; NASA Johnson chamber test <https://www.nasa.gov/centers-and-facilities/johnson/from-houston-to-the-moon-johnsons-thermal-vacuum-chamber-tests-lunar-solar-technology/>; Planetary Society Vostok 1 <https://planetary.org/space-missions/vostok-1>.

CAUTIONS: - The NASA image page for Ham has 'Jan. 21, 1961' in its title but 'Jan. 31, 1961' in its caption; use Jan. 31 (matches the NASA animals history page). - Albert II died at landing per the NASA history page, and Laika did not come back. The game stays gentle: it says they 'reached space' or 'orbited Earth' and never describes their deaths. Ham came back safe. - In the game the 'monkey' pet must be called a space chimp: Ham was a chimpanzee. - The laser gain is 'more data'; the existing fun fact 'up to 100 times faster' rests on the JPL wording 'rates up to 100 times higher' (Communications row 39). - MMPACT dates (DM-1 2026) come from 2021-2022 slides; no 2026 NASA status update was opened, so the game says NASA 'studies' or 'tests' building with Moon dust, never that it has built anything on the Moon. - Deploying a vertical array near the South Pole is a goal; no opened source says it has happened.

DROPPED (not verified, do not show): - Artemis II Optical Communications System (O2O) figures such as 260 Mbps, 4K video and 'over 484 gigabytes' appeared only in news articles and search snippets; no NASA post-flight page was opened. - The Apollo 11 'bunny girl' exchange (Houston telling the crew about Chang'e and her rabbit, July 20, 1969) appeared only on Spacelog and Science Friday, not on an opened NASA transcript page. - The Aztec version with Quetzalcoatl and the rabbit is unsourced in the opened encyclopedia article. - No NASA statement that robots 'cannot fly' on the Moon was found; the treads explanation is team reasoning from rows 1 and 2.

</details>

#### Exploration sites, meteorites, landing pads and moon buggies (Stage 7)

Facts behind the Stage 7 changes: the five exploration sites scanned with the tablet, the random meteorite impact event, the landing pad and ship, the drivable moon buggy and hauler, and their grippy wheels. Every source below was opened on 15 November 2026 (date accessed). The game's sites are stand-ins inspired by these real places; the game never says a real lander or crash site is next to the player's base.

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Robot lander near the south pole: IM-1 Odysseus (site old_lander) | NASA (LRO image release): on Feb. 22, 2024 Intuitive Machines' Nova-C lander Odysseus 'softly landed near crater Malapert A in the South Pole region of the Moon'; LRO imaged it on Feb. 24 from about 90 km up; it came to rest at 80.13 degrees south, 1.44 degrees east, at 2,579 m elevation, inside a degraded crater about 1 km wide, on ground sloped about 12 degrees. NASA's CLPS article says Odysseus 'is gently leaning into the lunar surface', that this was the first time in over 50 years an American organization landed instruments on the Moon, that more than 500 megabytes of data came down, and that operations ended seven days after landing. News reports quoting the company say it tipped onto its side; the game says only that it ended up leaning. See also Stage 6 row 11: IM-2 Athena (March 6, 2025) also ended on its side. | Verified | <https://www.nasa.gov/missions/lro/nasas-lro-images-intuitive-machines-odysseus-lander/> |
| 2 | Chandrayaan-3 near the south pole | NASA ('NASA's LRO Observes Chandrayaan-3 Landing Site', Sep. 5, 2023): ISRO's Chandrayaan-3 touched down on Aug. 23, 2023; the site is about 600 km from the Moon's South Pole; LRO's camera took an oblique view four days later, and 'the bright halo around the vehicle resulted from the rocket plume interacting with the fine-grained regolith'. ISRO's APXS page gives the site as 69.37 degrees S, 32.32 degrees E, measured by the Pragyan rover's instrument. | Verified | <https://www.nasa.gov/image-article/nasas-lro-observes-chandrayaan-3-landing-site/> |
| 3 | LCROSS impact (site impact_crater) | NASA's LCROSS mission page: LCROSS launched June 18, 2009; its spent Centaur rocket stage 'crashed onto the surface of the Moon at 11:31 UT in the Cabeus crater at the lunar south pole' on Oct. 9, 2009, making a crater about 20 m (66 ft) wide; the goal was to confirm water ice in a permanently shadowed crater, and NASA says the data 'indicates that the mission successfully uncovered water'; a 2010 follow-up found that in some places the water is pure ice crystals. Consistent with Life support row 20. | Verified | <https://science.nasa.gov/mission/lcross/> |
| 4 | Rolling boulder tracks (site boulder_tracks) | LROC (the LRO camera team, Arizona State University) 'Rolling Rolling Rolling': boulder trails are often seen on crater walls and central peaks; 'when a boulder is knocked loose by an impact or moonquake, it will keep moving'; the trails look continuous and smooth, like a marble rolled down sand, so the boulders rolled rather than bounced; the four boulders shown are about 7 to 9 m across, on the wall of Pikel'ner S crater. NASA Photojournal (LROC NAC M139802338L, Menelaus crater): boulder trails form 'as materials erode from higher topography and roll toward the crater floor'. | Verified | <https://lroc.im-ldi.com/images/509> |
| 5 | Lunar Prospector crash (site prospector_crash) | NASA NSSDCA: Lunar Prospector launched Jan. 7, 1998; the mission ended on July 31, 1999 at 9:52 UT when the spacecraft was deliberately crashed into a permanently shadowed area of a crater near the lunar south pole, hoping to free water vapor from suspected ice; 'no plume was observed'. NASA's Oct. 13, 1999 release 'No Water Ice Detected From Lunar Prospector Impact' says the impact 'produced no observable signature of water', which does not rule ice out; the crash was planned because Lunar Prospector had measured large amounts of hydrogen at the poles. The June 2, 1999 release put the planned chance of success at about 10 percent. Water was later found by LCROSS (row 3). | Verified | <https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=1998-001A> |
| 6 | Sunny peaks (site sun_peak) | NASA Science ('Shackleton Crater's Illuminated Rim & Shadowed Interior'): 'While peaks along the crater's rim are exposed to almost continual sunlight, the interior is perpetually in shadow'; 'three points on the crater's rim remain collectively sunlit for more than 90% of the year'; this is because the Moon's axis is tilted only 1.5 degrees (Earth 23.5), so at the South Pole the Sun skims the horizon all year. Consistent with Power rows 27 and 28 (240 days a year at one spot; nowhere permanently lit). | Verified | <https://science.nasa.gov/resource/shackleton-craters-illuminated-rim-shadowed-interior/> |
| 7 | Why meteoroids hit the Moon with a flash, not a streak | NASA Meteoroid Environment Office ('About Lunar Impact Monitoring'): 'The Moon, however, has little or no atmosphere, so meteoroids have nothing to stop them from striking the surface'; an impact makes a brief 'brilliant flash at the point of impact', usually less than half a second; the slowest of these rocks travel at 20 km/s and the fastest at over 72 km/s; a 5 kg meteoroid can dig a crater over 9 m across; the lunar impact rate is still very uncertain. The 'no burning streak on the Moon' sentence is team reasoning from this row and row 8. | Verified | <https://www.nasa.gov/meteoroid-environment-office/about-lunar-impact-monitoring> |
| 8 | Meteoroid, meteor, meteorite | NASA Science ('Meteors and Meteorites: Facts'): 'Meteoroids are space rocks that range in size from dust grains to small asteroids'; 'When meteoroids enter Earth's atmosphere, or that of another planet, at high speed and burn up, they're called meteors'; one that survives and hits the ground is a meteorite; about 44,000 kg (48.5 tons) of meteoritic material falls on Earth each day. | Verified | <https://science.nasa.gov/solar-system/meteors-meteorites/facts/> |
| 9 | Moon impact flashes seen from Earth | NASA Watch the Skies blog (Mar. 12, 2026, 'NASA Marshall Lunar, Meteor Observatory Marks 20 Years of Discovery'): Marshall astronomers have observed more than 400 impacts on the lunar surface; the observatory recorded its first lunar impact flash on May 2, 2006; on March 17, 2013 'a bowling ball-sized meteoroid' made a bright flash and a crater about 60 ft wide, later confirmed by LRO. | Verified | <https://www.nasa.gov/blogs/watch-the-skies/2026/03/12/nasa-marshall-lunar-meteor-observatory-marks-20-years-of-discovery/> |
| 10 | The March 17, 2013 impact in numbers | NASA Scientific Visualization Studio: a meteoroid 'roughly a foot (30 to 40 cm) wide' with a mass of about 40 kg hit the Moon at about 25 km/s (60,000 mph); the flash was one of the brightest ever recorded; LRO before (Feb. 12, 2012) and after (July 28, 2013) images show 'a new crater 18 meters (60 feet) wide, with rays of ejecta that extend several kilometers'. | Verified | <https://svs.gsfc.nasa.gov/4242> |
| 11 | New craters keep appearing | NASA (Oct. 2016, 'Earth's Moon Hit by Surprising Number of Meteoroids'): LRO images showed over 200 craters that formed during the mission, about 3 to 43 m wide, about 30 percent more than models expected, plus over 47,000 small surface changes ('splotches'). NASA Science (Sep. 16, 2026, 'NASA's Moon Orbiter Spots New, Once-in-Century Moon Crater'): the LRO team 'has identified at least 1,000 new impact craters throughout the mission'; a crater 728 ft (about 222 m, derived) wide and 141 ft deep formed between April 11 and May 22, 2024, with bright streaks of material flung out in all directions; such an impact happens about once a century or less often. | Verified | <https://science.nasa.gov/solar-system/moon/nasas-moon-orbiter-spots-new-once-in-century-moon-crater/> |
| 12 | Rocket exhaust blasts Moon dust | NASA ('Rocket Exhaust on the Moon: NASA Supercomputers Reveal Surface Effects'): during landing and liftoff, engine plumes hit the surface and 'the intense forces kick up dust and eject rocks or other debris at high speeds', making dust clouds that can interfere with navigation and science instruments; Marshall simulations of Apollo 12 matched the real erosion; it is unknown how much the larger Artemis landers will erode the surface. | Verified | <https://www.nasa.gov/general/rocket-exhaust-on-the-moon-nasa-supercomputers-reveal-surface-effects/> |
| 13 | Apollo 12 sandblasted Surveyor 3 | NASA's 'Recommendations to Space-Faring Entities' (release July 20, 2011; copy uploaded Dec. 2023): plume particles can leave at 300 to 2,000 m/s and keep going because there is negligible air; gravel and rocks 1 to 10 cm across were thrown at 5 to 50 m/s up to 1.5 km away; 'The Apollo 12 LM landed 155 m from the Surveyor 3 spacecraft', and even though Surveyor sat in a crater below the main dust sheet it 'received significant sandblasting and pitting'. | Verified | <https://www.nasa.gov/wp-content/uploads/2023/12/nasa-usg-lunar-historic-sites-reva.pdf> |
| 14 | Landing pads stop the spray | NASA Kennedy Swamp Works (NTRS 20210020967, 'In-situ Lunar Launch and Landing Pad Construction with Regolith-Thermoset Polymer Composite Materials'): pads are 'necessary to mitigate risks to lander/ascent vehicles and surrounding surface assets from rocket plume ejected regolith', with bigger risks for Artemis because of higher thrust; in hot-fire tests on Earth 'all test articles successfully mitigated regolith ejecta from plume effects', though some eroded. Consistent with Stage 6 row 12 (MMPACT studies landing pads made from Moon dust). No opened source says a landing pad has been built on the Moon; the game's pad and ship are decoration and a goal. | Verified | <https://ntrs.nasa.gov/citations/20210020967> |
| 15 | Apollo Lunar Roving Vehicle | NASA NSSDCA ('The Apollo Lunar Roving Vehicle'): three LRVs were driven on the Moon, one each on Apollo 15, 16 and 17; mass 210 kg, designed to carry 490 kg more; frame 3.1 m long; two side-by-side foldable seats; power from two 36-volt non-rechargeable batteries; 'A large mesh dish antenna was mounted on a mast on the front center of the rover'; tires of zinc-coated woven steel strands with titanium chevrons covering 50% of the contact area for traction; driven 27.8 km on Apollo 15, 26.7 km on Apollo 16 and 35.9 km on Apollo 17. | Verified | <https://nssdc.gsfc.nasa.gov/planetary/lunar/apollo_lrv.html> |
| 16 | Why moon wheels need grip, and no air tires | NASA Glenn (NASA/TM-2009-215798, 'The Development of Wheels for the Lunar Roving Vehicle', Dec. 2009): lunar wheels must work in 'a low gravity field (1/6th Earth's gravity)'; wire wheels 'could be designed to deform significantly, thus providing high tractive capability, even under the relatively low weight of lunar vehicles in 1/6th gravity'; 'lunar wheels apply relatively low ground pressure in 1/6th gravity'; air-filled (pneumatic) tires were rejected because of the risk of deflation in the airless Moon and rubber damage by sunlight, and a flat tire 'is not acceptable for a manned vehicle'; Figure 1(a) lists the LRV's max speed as 16 km/hr; the wheel was developed in 17 months, October 1969 to March 1971. The 'wheels need extra grip' line is team wording from these quotes. | Verified | <https://ntrs.nasa.gov/api/citations/20100000019/downloads/20100000019.pdf> |
| 17 | Apollo 17 fender repair | NASA image article 'Duct Tape Saves the Day!': the Apollo 17 rover's replacement fender is at the right rear, held on by two clamps, and 'the gray cross is duct tape used to hold together the four maps from which the fender was made'. NASA APOD (Dec. 14, 2022, 'Lunar Dust and Duct Tape'): Schmitt and Cernan needed to repair a fender to 'keep the rooster tails of dust away from themselves and their gear', using spare maps, clamps and duct tape. | Verified | <https://www.nasa.gov/image-article/duct-tape-saves-day/> |

<details><summary>Verification notes for this section</summary>

METHOD (2026-11-15, date accessed for every source): NASA pages were opened with a fetch tool that returns short quoted fragments. Two NASA PDFs (the LRV wheels technical memorandum and the lunar historic sites recommendations) came back as binary; the fetch tool saved its own copies and I text-extracted them to stdout with pdftotext (no files written to the project). Every row's source was opened; second sources are listed below.

SECOND SOURCES OPENED: NASA CLPS article 'NASA Collects First Surface Science in Decades via Commercial Moon Mission' <https://www.nasa.gov/missions/artemis/clps/nasa-collects-first-surface-science-in-decades-via-commercial-moon-mission/> (row 1); ISRO APXS page <https://www.isro.gov.in/Ch3_Alpha_Particle_X-ray_Spectrometer.html> (row 2); NASA Photojournal Menelaus boulder trails <https://science.nasa.gov/photojournal/boulder-trails-in-menelaus-crater/> (row 4); NASA Oct. 13, 1999 release <https://nssdc.gsfc.nasa.gov/planetary/text/lp_pr_19991013.txt> and June 2, 1999 release <https://nssdc.gsfc.nasa.gov/planetary/news/lp_pr_19990602.html> (row 5); NASA 2016 LRO cratering release <https://nasa.gov/press-release/goddard/2016/lro-lunar-cratering> (row 11); NASA APOD 2022 Dec 14 <https://science.nasa.gov/image-article/apod-2022-december-14-lunar-dust-and-duct-tape/> (row 17).

CAUTIONS: - Odysseus: NASA's own pages say 'leaning'; 'tipped on its side' and the broken landing leg come from news reports quoting Intuitive Machines (about 30 degrees from horizontal in later reports). The game says it ended up leaning. Malapert A being about 300 km from the pole is only in secondary reports; not used. - Chandrayaan-3: the 69.37 degrees S latitude is from ISRO, not NASA; NASA gives 'about 600 km from the South Pole'. No opened source says it was the closest landing to the pole, so the game does not claim a record. - LCROSS crater size: NASA says about 20 m; a later paper gives about 27 m. Use 'about 20 m' or no number. - Lunar Prospector: the NSSDC catalogue does not name the crater (secondary sources say Shoemaker); the game says 'a dark crater'. - Meteor flashes: the brightness of the 2013 flash differs between NASA pages (fourth magnitude in older material, third magnitude in the 2026 blog); not used. The impactor is 'bowling ball-sized' (blog) or '30 to 40 cm' (SVS); both fit. - New craters: 'over 200' (2016) and 'at least 1,000' (2026) are counts at different dates; use the 2026 value. - LRV speed: NASA's NSSDC page gives no top speed; the 16 km/hr value is from the NASA Glenn TM figure. - The game's buggy and hauler are inspired by the LRV; the hauler with a pressurized cab is a game vehicle (no NASA source was opened for a specific pressurized rover), and the in-game maxSpeed values in VEHICLES are GAME parameters. - Landing pads: tests were on Earth; no opened source says a pad has been built on the Moon. - The meteorite event in the game is invented ('what if a space rock landed near your base'); real impacts of this size near any one spot are rare.

DROPPED (not verified, do not show): - Apollo 17 LRV speed record (about 18 km/h) and Apollo 16 '17 km/h' (news and encyclopedia only). - 'Odysseus is the southernmost landing ever' (news only). - LCROSS '350 metric tons of material excavated' (search snippet of a NASA page; not opened). - Exact landing-gear failure details of Odysseus (news only).

</details>

#### Gas jets, jetpacks and Moon hops (Stage 8)

Facts behind the Stage 8 gear: the air boots (double jump with gas puffs from the soles) and the jetpack (cold-gas jets while Jump is held), plus how astronauts really moved on the Moon. Every source below was opened on 15 November 2026 (date accessed). The air boots and the game's jetpack are game inventions inspired by these real devices; no opened source describes gas-jet boots or a jetpack flown on the Moon, and the game never says one existed.

| # | Topic | Fact | Status | Source |
| :--- | :--- | :--- | :--- | :--- |
| 1 | Manned Maneuvering Unit (MMU) flew on nitrogen gas | NASA History SP-4219, chapter 13 ('More Favored than the Birds: The Manned Maneuvering Unit in Space'): the MMU propellant was 'gaseous nitrogen, GN2, stored in two tanks'; the propulsion was split into two parallel sets, each 'operating twelve thrusters', so normally all 24 thrusters were available; two silver-zinc batteries gave electric power; the MMU was meant to work up to 450 feet (about 137 m, derived) from the Space Shuttle and weighed about 340 pounds. NASA's image article calls it a 'nitrogen-propelled, hand-controlled back-pack device'. | Verified | <https://www.nasa.gov/history/SP-4219/Chapter13.html> |
| 2 | First untethered spacewalk: Bruce McCandless, 7 February 1984 | NASA image article ('Astronaut Bruce McCandless Performs the First Untethered Spacewalk'): photo from Feb. 7, 1984, STS-41B, McCandless testing the manned maneuvering unit for the first time near the Space Shuttle Challenger. NASA's second image article ('Astronaut Bruce McCandless on First-ever Untethered Spacewalk') gives the same date and calls it a 'nitrogen-propelled hand-controlled manned maneuvering unit (MMU)'. NASA's STS-41B mission page: launched February 3, 1984; McCandless 'completed the first untethered spacewalk by using the Manned Maneuvering Unit', and Robert Stewart also flew it on the mission. SP-4219 chapter 13 also gives February 7, 1984. | Verified | <https://www.nasa.gov/image-article/astronaut-bruce-mccandless-performs-the-first-untethered-spacewalk/> |
| 3 | SAFER, the small nitrogen jet backpack for emergencies | NASA History ('30 Years Ago: STS-64 Astronauts Test a Spacewalk Rescue Aid'): SAFER (Simplified Aid for EVA Rescue), designed at Johnson Space Center, 'attaches to the spacesuit's Portable Life Support System backpack' and 'contains nitrogen jets that an astronaut can use, should he or she become untethered, to fly back to the vehicle'; 'Astronauts conducting spacewalks from the space station use the SAFER as a standard safety device'; first tested by Mark C. Lee and Carl J. Meade on STS-64 in September 1994, on the first untethered spacewalk since 1984. NASA's kids' page 'What Is a Spacewalk? (Grades K-4)': 'SAFER is worn like a backpack', with small thrusters steered by a joystick. | Verified | <https://www.nasa.gov/history/30-years-ago-sts-64-astronauts-test-a-spacewalk-rescue-aid/> |
| 4 | How Apollo astronauts moved: kangaroo hops and loping | Apollo Lunar Surface Journal, 'Lunar Gaits' (commentary by Eric M. Jones, hosted by NASA): Aldrin on Apollo 11: 'the one-foot-in-front-of-the-other is a much better mode of locomotion than the more stilted kangaroo hop. You can do it, but it doesn't seem to offer any particular advantage'; Armstrong: 'I can best describe a lope as having both feet off the ground at the same time' and 'you are taking advantage of the low gravity'; most astronauts on the later missions favored a loping gait; nobody used the two-footed kangaroo hop on level ground except in play, but Cernan and Schmitt used it coming down a steep hill on Apollo 17. Consistent with Power row 29 (about one-sixth of Earth weight). | Verified | <https://www.nasa.gov/wp-content/uploads/static/history/alsj/a11/a11.gaits.html> |
| 5 | John Young's Moon jumps (Apollo 16) | NASA History ('50 Years Ago: Apollo 16 on the Moon at Descartes'): during the first moonwalk Young planted the flag and he and Duke took turns photographing each other, 'with Young leaping in the air while saluting'; 'More informally, Young did five high jumps, reaching a height of 2.3 feet' (about 70 cm, derived: 2.3 x 30.48 cm = 70.1 cm). NASA image article 'All-American Salute' (AS16-113-18339): Young 'leaps from the lunar surface' during the first Apollo 16 extravehicular activity. | Verified | <https://www.nasa.gov/history/50-years-ago-apollo-16-on-the-moon-at-descartes/> |

<details><summary>Verification notes for this section</summary>

METHOD (2026-11-15, date accessed for every source): NASA pages were opened with a fetch tool that returns short quoted fragments. The 'Lunar Gaits' page at hq.nasa.gov now redirects to the NASA ALSJ landing page, so the NASA-hosted static copy (row 4 link) and the apollojournals.org copy <https://apollojournals.org/alsj/a11/a11.gaits.html> were opened; both give the same quotes.

SECOND SOURCES OPENED: NASA image article <https://www.nasa.gov/image-article/astronaut-bruce-mccandless-first-ever-untethered-spacewalk/> (rows 1, 2); NASA STS-41B mission page <https://www.nasa.gov/mission/sts-41b/> (row 2); NASA kids' page <https://www.nasa.gov/learning-resources/for-kids-and-students/what-is-a-spacewalk-grades-k-4/> (row 3); NASA image article <https://www.nasa.gov/image-article/all-american-salute/> (row 5).

GAME MAPPING AND CAUTIONS: - Gas jets work without air: Stage 6 rows 3 and 4 (a rocket pushes on its exhaust; Newton's third law). The game's gas tank, its refill inside the base and its gas use per jump or per second are game parameters, not real values. - MMU and SAFER flew in orbit, where everything falls together; on the Moon a jetpack must push against gravity, so lifting a person would use gas much faster. That sentence is team reasoning, not a NASA quote, and is why the game's jetpack drains gas every second it fires. - Real spacesuit boots have no gas jets; the air boots are a game invention. - The sources say 'kangaroo hop', not 'bunny hop'; the game should say kangaroo hop (or 'hop'). - Row 5: the page gives no calendar date for the jumps in its text (photo file names suggest April 21, 1972); the game does not show a date. - Row 3: 'standard safety device' is NASA's wording in a 2024 history article; the game says spacewalkers 'wear' SAFER, not that every walk used it.

DROPPED (not verified, do not show): - SAFER figures '24 thrusters', '0.8 lbs' thrust each, 'three-pound supply of nitrogen' and about 13 minutes of use appeared only in search snippets of NASA PDFs (STS-64 press kit, NTRS reports) that were not opened. - McCandless flying out to '320 feet' from the orbiter (search snippet only; the opened captions say only 'a few meters away'). - A NASA chronology line saying the Apollo 11 crew 'tended to move using two-footed kangaroo hops' (search snippet only; it also conflicts with row 4).

</details>

### 6.2 Third-party notices

The text below is `THIRD_PARTY_NOTICES.md` as it stands in the repository. Only the heading levels were shifted to fit this document.


#### Tabler Icons

The game's icons are Tabler Icons (https://tabler.io/icons, version 3.52.0), rendered to white PNG files, uploaded to Roblox and tinted in-game. The asset IDs are listed in `src/shared/Icons.luau`.

```
MIT License

Copyright (c) 2020-2026 Paweł Kuna

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

#### Tools (not redistributed)

- Roblox Studio (Roblox Corporation)
- Rojo (MPL-2.0), https://rojo.space
- Lune (MPL-2.0), https://github.com/lune-org/lune

#### Earth image

The in-game Earth uses NASA's "Blue Marble: Land Surface, Ocean Color and Sea Ice" (NASA Visible Earth, NASA Goddard Space Flight Center), public domain, scaled to 1024x512. Credit: NASA. NASA's use does not imply endorsement. The file was taken from the public-domain copy on Wikimedia Commons ("Whole world - land and oceans.jpg"), because NASA's image server did not respond.

#### Sound recordings (CC0)

The game's music and most sound effects are original audio, synthesized in code by the team. Five effects mix in edited parts of these CC0 1.0 (public domain) recordings from Freesound, found through Openverse. CC0 needs no attribution; they are listed as a courtesy. No sound in the game is CC BY. The Roblox asset IDs are in `src/shared/AudioIds.luau`.

- "Ratchet Wrench Fast Multiple" by Rudmer_Rotteveel, https://freesound.org/people/Rudmer_Rotteveel/sounds/591529 (in `build_step`)
- "Wrench Clanking" by magnuswaker, https://freesound.org/people/magnuswaker/sounds/530074 (in `build_step`)
- "Heavy Metal Thud on Ground" by 7of9Designs, https://freesound.org/people/7of9Designs/sounds/640204 (in `crate_drop`, `shelter_enter` and `meteor_impact`)
- "Footsteps Metallic Muffled.wav" by RutgerMuller, https://freesound.org/people/RutgerMuller/sounds/50723 (in `footstep_inside`)

### 6.3 License

Space Base Odyssey is released under the **Apache License, Version 2.0** (January 2004). The full text is in the `LICENSE` file at the root of the repository. In short:

| Topic | What the license says |
| :--- | :--- |
| Copyright license | Every contributor grants a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable license to reproduce, modify, publicly display, publicly perform, sublicense and distribute the work and works based on it, in source or object form. |
| Patent license | Every contributor also grants a patent license for their contributions. It ends for anyone who starts patent litigation claiming the work infringes a patent. |
| Redistribution | Anyone who shares the work or a modified version must give recipients a copy of the license, mark the files they changed, keep the existing copyright, patent, trademark and attribution notices, and include any NOTICE file's attribution notices. |
| Contributions | Anything submitted for inclusion in the work is under the same license, unless the contributor explicitly says otherwise. |
| Trademarks | The license gives no right to use the licensor's names, trademarks or product names, beyond describing where the work comes from. |
| Warranty | The work is provided "AS IS", without warranties or conditions of any kind. |
| Liability | Contributors are not liable for damages that come from using the work, unless the law requires it or they agreed to it in writing. |
| Extra support | A redistributor may offer support, warranty or liability for a fee, but only on their own behalf. |

The Apache 2.0 license covers the team's own code and text. Third-party material keeps its own terms: the Tabler Icons are under the MIT License, and the Earth image is public domain (see 6.2). Roblox Studio, Rojo and Lune are tools used to build and test the game. They are not redistributed with it.

### 6.4 Use of Super Intelligence

The Space Apps rules call AI "Super Intelligence (SI)" and require teams to disclose how they used it.

#### Which AI was used

We used **Claude, by Anthropic**, working inside **Claude Code**, as an AI assistant during the hackathon.

#### What the AI did

- **Research compilation.** Claude gathered candidate facts and their sources (life support and food, radiation and space weather, power and surface environment, communications, collectible cards, base building, exploration sites, gas jets and Moon hops) into `DATA_SOURCES.md`.
- **Fact verification.** A separate, independent Claude verification pass re-opened every cited source and marked each fact as verified, corrected or unverified. Of 199 facts, 189 were verified, 9 were corrected and 1 could not be confirmed. Unverified facts never appear in the game.
- **Design review.** An audit of the team's first design documents, plan drafts and independent critiques of those plans.
- **Code generation.** Claude wrote most of the Luau code and the automated tests from the team's design, using parallel agents followed by integration reviews.
- **Testing.** Automated tests run in Lune, and playtests in Roblox Studio driven by the assistant.
- **Text drafts.** Claude drafted the in-game sentences in English and Spanish, the README, the development log and the submission texts.

#### What the team did

- The game concept, the setting and the core mechanics, and every design decision. Where Claude suggested options, the team chose.
- Approving every number before it went into the game.
- Reviewing the in-game texts and the documentation drafts.
- Playtesting, publishing, the video and the presentation.

#### Disclosure in the project

- Every AI-assisted code file starts with a disclosure line: "SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team." The archived space weather data file (`src/shared/SpaceWeatherArchive.luau`) says "compiled" instead of "generated", because it holds compiled data rather than written logic.
- No AI-generated images or video are used in the game. The music and sound effects are synthesized by the team's own code (scripts written with AI assistance; no generative audio model), and five effects mix in edited CC0 recordings (6.2). The game world is built from plain parts by code. The only images are the Tabler Icons and the public-domain NASA Earth map listed in 6.2, plus a near-black skybox face made by the team.
- Still to confirm before submitting: the demo video contains no AI-generated images, video or voices. If any are added, they need a visible watermark.
