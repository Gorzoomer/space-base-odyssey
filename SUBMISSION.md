# Space Apps 2026 submission drafts

Drafts for every field of the Space Apps project page. Challenge: **Build a Junior Astronaut Mission Trainer**.

Every item marked **TO ADD** still has to be filled in. Features marked **[Stage 2]** are being built now and must be checked in the real game before this text is submitted. Every number below comes from `src/shared/MissionData.luau` and `DATA_SOURCES.md`.

---

## Project Name

Space Base Odyssey

---

## High-Level Project Summary

Space Base Odyssey is a cooperative Roblox game where up to four kids aged 7 to 12 run a base at the Moon's south pole for seven days. Every morning they share four power cells between life support, the greenhouse and science, and no choice is free: power spent on science today means less air or less food tomorrow. Then they suit up for a 150-second shift in real Moon gravity. They clean dusty solar panels, carry ice from a dark crater to make water and air, fix air leaks, point the antenna at Earth, and run to a thick regolith shelter when a solar storm hits. Storms replay real flares from NASA's DONKI database, including real false alarms where a huge flare sent no particles. Nobody gets hurt: if things go wrong, the crew flies home early and a day-by-day report explains why. Every real-world number is cited, and an in-game panel credits each source.

---

## Link to Project Demo

TO ADD: 30-second video link

---

## Link to Final Project

https://github.com/Gorzoomer/space-base-odyssey

---

## Detailed Project Description

### What it does

Space Base Odyssey turns the five topics of the challenge (life support, radiation shielding, power budgeting, food production and communication delay) into one mission that kids play together. One to four players share a single base. The game runs in English or Mexican Spanish, and every gameplay sentence has at most eight simple words so a 7-year-old can read it (the fact and source lines on the Sources panel have at most ten). A friendly base assistant, C.A.R.L., tells the crew what is happening and what to try.

The mission has three meters that the whole crew shares:

- **Air**: made from water using electricity, used up by breathing.
- **Food**: grown in the greenhouse, eaten every day.
- **Radiation**: the crew's dose. It only ever goes up, exactly like a real dose.

Science is not a meter. It is a score that earns stars.

### The mission loop

The mission lasts 7 days. Days 1 and 2 are calm, so new players learn one system at a time. Days 3 to 7 bring events in an order that changes with every new mission, so the game can be replayed: dust on the solar panels (twice), an equipment failure that leaks air, and two solar storm watches.

Each day has three phases:

1. **Planning, with no clock.** At the power board the crew shares power cells between three systems. Each clean solar array gives one cell and the battery gives one more, so a normal day has 4 cells, and each system can take at most 2. That is never enough to run everything at full power. When dust covers an array, there is one cell less, and the board takes power from science first and from life support last.
2. **Shift, 150 seconds in real time.** Players walk around the base in Moon gravity. Outside, the suit's own oxygen runs down, and running uses it twice as fast as walking. Refilling a suit inside the habitat uses some of the base's air. If a suit runs empty, C.A.R.L. brings the astronaut back inside. The tasks are:
   - Clean dusty solar panels so they make power again tomorrow.
   - Drill ice in the permanently shadowed crater and carry it to the water processor. Ice adds air and science points.
   - Fix the air leak when equipment fails.
   - Point the antenna at Earth.
   - Run into the regolith shelter when a particle storm arrives.
3. **End of day.** The server applies the results: oxygen made and breathed, food eaten, plants that will be ready tomorrow, dose received and science earned.

When the 7 days are over, or when a meter forces an early return, the crew sees the **mission report**. It is a timeline with one sentence per day that explains the main cause ("Dusty panels made less power", "The thick dirt shelter kept everyone safe") and a "Try another plan" button.

Failure teaches instead of punishing. If air or food reaches zero, the crew gets one day of grace to fix it. If it is still empty, or if the radiation meter reaches its limit, the crew goes home early, safe, and still earns 1 star. More stars need more science, and only a crew that completes the mission can earn them (2 stars at 10 science points, 3 stars at 18).

### How each challenge topic becomes a decision with a consequence

| Topic | Decision | Consequence | Real data behind it |
| :--- | :--- | :--- | :--- |
| Power budgeting | How many of the 4 power cells each system gets every morning. | A cell given to science is a cell taken from air or food. Dust takes a cell away until someone goes outside and cleans the panel. | The base sits near Shackleton crater, where one spot on the rim is sunlit for about 240 days a year (LRO topography study), so solar power is the obvious choice there. |
| Life support | Power for life support, fetching ice, fixing leaks, and when to go inside for a suit refill. | Each life-support cell makes oxygen by splitting water with electricity. Ice adds water. Breathing, an unrepaired leak and every suit refill take air away. | NASA BVAD 2022: a crew member needs about 0.895 kg of oxygen and 2.5 kg of water per day. The ISS makes its oxygen by electrolysis. LCROSS found water ice at the bottom of a shadowed polar crater. |
| Food production | Power for the greenhouse. | Plants take time to grow: today's greenhouse power becomes food tomorrow, never today. Cutting the greenhouse looks free until the next day. | Lettuce grown in NASA's Veggie unit on the Space Station took 33 days from planting to the first meal. A crew member needs about 3,000 kcal per day. |
| Radiation shielding | Stop working and hide in the shelter, or keep working outside during a storm. | Everyone outside when the particles arrive adds to the crew's dose, and dose never goes down. Too much dose ends the mission early. The shelter protects because of its mass (a thick regolith mound with water tanks inside), not because of power. | Real solar flares from NASA DONKI. On the Moon's surface Chang'e-4 measured about 1.37 mSv per day, compared with about 6.2 mSv per year on Earth. NASA's career limit is 600 mSv. NASA recommends a storm shelter with about 10 cm of water equivalent. |
| Communication delay | Spend shift time pointing the antenna at Earth, or spend it on other tasks. | With the antenna linked, forecasters on Earth warn the crew 45 seconds before the particles arrive. Without the link, the warning comes only 15 seconds before. | A signal takes about 1.3 seconds from the Moon to Earth and 3 to 22 minutes from Mars. **[Stage 2]** When the antenna links, C.A.R.L. says that a signal reaches Earth in 1.3 seconds and that from Mars it can take up to 22 minutes. |

The 45-second and 15-second warnings are game values chosen for playability. They teach the real idea: on the Moon, help from Earth arrives quickly if the link is up, but particles can cross from the Sun in about 30 minutes or less, so every minute of warning matters.

### Solar storms: real flares, honestly labelled

On a storm day, 40 seconds into the shift, a flare is spotted and C.A.R.L. names its real class and date. After the warning time, one of two things happens:

- **Particles arrive.** The storm lasts 25 seconds. Anyone outside the shelter is exposed.
- **Nothing arrives.** Some of the biggest flares in the archive (an X9.0 in October 2024, an X8.7 in May 2024) brought no particle storm near Earth: DONKI links them to no particle event seen by the GOES satellites. The game shows these as real false alarms: a big flare does not always bring particles. Sheltering was still the right call.

The first storm of every mission always brings particles, so players learn why the shelter matters before they meet a false alarm.

DONKI events were observed near Earth, not at the Moon. The game never says a flare hit the base. It presents each storm as a replay: what if a storm like this one reached your base?

- **Archive (works now).** 11 real X-class flares from May 2024 to February 2026, downloaded from DONKI on 14 November 2026. For each one the game knows whether DONKI linked it to a solar particle event seen by the GOES satellites.
- **[Stage 2] Live data.** When the server starts, it asks DONKI for the solar flares and particle events of the last 30 days. Live flares of class M5 or stronger join the pool, are preferred when one qualifies, and are labelled "live NASA data" with their date; the Sources panel shows when the query ran (UTC). A live flare's particle status comes from the same query. A live flare with no linked particle event is only replayed as a false alarm once it is at least two days old, so DONKI has had time to link a particle event to it. If the request fails, times out, or HTTP requests are turned off, the game says it has no live link and uses the saved archive, labelled with the download date. Archived data is never shown as live.

### [Stage 2] The "Real NASA data" panel

A big, scrollable panel opens from a button on the title screen, the power board and the mission report. It shows:

- The space-weather status: how many flares DONKI reported in the last 30 days, the latest one and the time of the query, or a clear "no live link now" message (also shown while the query is still running), plus the date the archive was downloaded.
- Short facts with real numbers: Moon gravity (16.5% of Earth's), signal time to Earth and to Mars, a crew member's daily oxygen, water and food, days for space lettuce to grow, radiation on the Moon compared with Earth, the career limit, how fast storm particles travel, sunlight at the south pole, the coldest temperature measured on the Moon, the ice LCROSS found, and why a big flare does not always mean a storm.
- One line per source, as text (for example "Space weather: NASA / CCMC DONKI"). Roblox does not allow external links inside a game, so the full list with links lives in `DATA_SOURCES.md`.

During a shift, the HUD also shows whether today's flare is live or a replay (with its date) and whether the Earth link is on.

### How it works

- **Server-authoritative.** The server owns the mission. Players only send requests (for example "put 2 cells in the greenhouse"), and the server checks every one before applying it. All players see the same base.
- **Pure simulation.** The mission rules live in one module with no Roblox code (`src/shared/Simulation.luau`), so they run outside Roblox. Automated balance tests (`tests/balance.luau`, 252 checks over 8 random seeds) prove the challenge rule that no choice is free: a crew that never reacts still reaches at least day 5 and earns 1 star, no fixed power plan earns 3 stars (the best one earns 2), a crew that reacts to events can earn 3, cutting the greenhouse shows up as less food on a later day, and skipping life support ends the mission after one day of grace.
- **Real gravity ratio.** Roblox's default gravity stands for Earth. The game keeps the real Moon-to-Earth ratio (1.62 / 9.81), so everyone moves in lunar gravity.
- **Built from code.** The whole base (habitat, greenhouse rack, water processor, solar arrays, antenna, ice crater and regolith shelter) is built by a script from plain parts. There are no Toolbox or Marketplace assets and no NASA logos.
- **Localized.** Every player-facing sentence is a key with an English and a Spanish text. A test checks that both languages define every key and stay short.
- **Data first.** Every number in the game is tagged in `MissionData.luau` as REAL (with the row of `DATA_SOURCES.md` it comes from) or GAME (a tuning value for playability). Meters run from 0 to 100 in game units. The real values behind them are shown on the Sources panel, never mixed into the meters as fake precision.

### Benefits for kids aged 7 to 12

- **Trade-offs they can feel.** Kids do not read that "power is limited". They watch the food meter drop the day after they cut the greenhouse.
- **Real science, simply told.** Plants take time. Oxygen comes from water and electricity. A thick wall stops particles. Radiation dose adds up and never goes away. A big flare is not always dangerous.
- **Teamwork.** Up to four players split the jobs: one cleans panels, one carries ice, one fixes the leak, everyone runs for the shelter together.
- **Safe failure.** Nobody dies. An early return is a mission result with a clear reason and an invitation to try another plan.
- **Real data, honestly labelled.** Kids see the real date of the flare they are replaying and learn the difference between live data and an archive.
- **Bilingual.** English and Mexican Spanish from the first screen.

### Tools

- Roblox Studio and the Roblox engine
- Luau (strict type checking in every file)
- Rojo 7.7.1, to keep the code in files and sync it into Studio
- Lune, to run the simulation and localization tests outside Roblox
- Git and GitHub
- Claude (Anthropic), as described in "Use of Super Intelligence"

### Evidence for judges

- TO ADD: link to the full, uncut playthrough video (English interface).
- `game.rbxl` at the root of the repository opens in Roblox Studio. Press Play to run the full mission.
- `lune run tests/balance` prints the balance results ("252 passed, 0 failed; best static allocation earned 2 stars" at the time of writing).

---

## Use of Super Intelligence

We used **Claude, by Anthropic**, as an AI assistant during the hackathon:

- **Research compilation.** Claude gathered candidate facts and their sources (life support, radiation, power, surface environment, communications) into `DATA_SOURCES.md`.
- **Fact verification.** A separate Claude verification pass re-opened every cited source and marked each fact as verified, corrected or unverified. 9 facts were corrected and 1 could not be confirmed. Unverified facts never appear in the game.
- **Code generation.** Claude wrote most of the Luau code and the tests from our design.
- **Text drafts.** Claude drafted the in-game sentences in English and Spanish, the README and these submission texts.

What the team did:

- The game concept, the setting and the core mechanics came from the team. Where Claude suggested options, the team made the decisions.
- The team tested the game in Roblox Studio and reviewed and approved every number before it went into the game.
- The team reviews the in-game texts and these drafts before they are used.

Disclosure:

- Every AI-assisted code file starts with a disclosure comment ("SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team").
- No AI-generated images are used. The game world is built from plain parts by code.
- TO ADD: confirm that the demo video contains no AI-generated images, video or voices. If any are added, they need a visible watermark.

---

## NASA Data

Each dataset, where it comes from and the exact mechanic it feeds. Full rows, with every value and its verification status, are in `DATA_SOURCES.md`.

| Dataset | URL | What it feeds in the game |
| :--- | :--- | :--- |
| **NASA / CCMC DONKI, solar flares (FLR)** | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR> (tool page: <https://ccmc.gsfc.nasa.gov/tools/DONKI/>) | Storm days. Archive: 11 real X-class flares (May 2024 to February 2026, downloaded 14 November 2026) with their class, peak date and DONKI ID; C.A.R.L. names the real class and date. **[Stage 2]** Live: the last 30 days are requested at server start; live flares of class M5 or stronger can be picked and are labelled live; the Sources panel shows the flare count and the latest flare. |
| **NASA / CCMC DONKI, solar energetic particles (SEP)** | <https://ccmc.gsfc.nasa.gov/DONKI/WS/get/SEP> | Decides whether a flare brings a particle storm (DONKI links the flare to an SEP event seen by GOES) or is a real false alarm. The first storm of each mission always uses a flare with particles. |
| **NASA Solar storms and flares page** | <https://science.nasa.gov/sun/solar-storms-and-flares/> | The storm sequence: the flare's light is seen first (it reaches Earth in about 8 minutes), particles come later (about 30 minutes or less), so there is time to shelter. Sources fact on particle travel time. |
| **NASA Life Support Baseline Values and Assumptions (BVAD) Rev2, 2022** | <https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf> | Daily crew needs on the Sources panel: about 0.9 kg of oxygen (0.895 kg in BVAD), 2.5 kg of water for drinking and food, and about 3,000 kcal of food. They explain why breathing and eating drain the air and food meters every day. |
| **NASA ISS ECLSS fact sheet (2025)** | <https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf> | The life-support rule that oxygen is made from water with electricity: life-support cells and delivered ice both add air. |
| **LCROSS impact results** (Colaprete et al., Science, 2010) | <https://experts.arizona.edu/en/publications/detection-of-water-in-the-lcross-ejecta-plume/> | The ice task: water ice sits in a permanently shadowed crater. Sources fact: about 5.6% water ice by mass at the LCROSS impact site in Cabeus crater. |
| **NASA Veggie fact sheet** | <https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf> | The greenhouse rule that plants take time (food arrives the next day). Sources fact: the first lettuce eaten on the Space Station grew for 33 days. |
| **LRO Diviner temperatures** | <https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf> | Sources fact: 25 K (about -250 C) on the floor of Hermite crater, near the north pole, the coldest temperature measured on the Moon. Context for the frozen, shadowed ice crater. |
| **South-pole illumination from LRO topography** (Mazarico et al., 2011) | <https://ntrs.nasa.gov/citations/20120010094> | The setting: a spot on the Shackleton crater rim is sunlit for about 240 days a year, which is why the base runs on solar arrays. Low Sun and long shadows in the world. Sources fact. |
| **NASA Moon fact sheet (NSSDC)** | <https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html> | Moon gravity 1.62 m/s2, 16.5% of Earth's. The game's gravity uses this exact ratio. Sources fact. |
| **NASA-STD-3001 Volume 1 Rev C** (crew health standard) | <https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf> | Career radiation limit of 600 mSv: the idea behind the radiation meter's limit that sends the crew home early. Storm shelter of about 10 cm water equivalent on a planetary surface: why the shelter is a thick mound with water tanks and protects by mass. Sources facts. |
| **NASA TM-20250003885** (lunar communication latency) | <https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf> | Earth-Moon one-way signal time of 1.3 seconds. **[Stage 2]** Said by C.A.R.L. when the antenna links; Sources fact. |
| **NASA Mars Relay Network page** | <https://science.nasa.gov/mars/mars-relay-network/> | Earth-Mars one-way signal time of 3 to 22 minutes, the comparison that shows why far-away bases cannot wait for Earth. **[Stage 2]** C.A.R.L. line and Sources fact. |

**Live versus archived, honestly.** Without a live connection the game uses the archive and says so, with the date it was downloaded (14 November 2026). **[Stage 2]** With a live connection it labels live flares as live, with their date, and the Sources panel shows the time of the query. In both cases the game says the flare was observed near Earth and asks what would happen if a storm like it reached the base. The live link needs HTTP requests to be allowed in the experience settings.

---

## Space Agency Partner Data

**Canadian Space Agency (CSA).** We read the CSA food-production resources linked by the challenge (<https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/>), the Deep Space Food Challenge and the Naurvik project in Nunavut for background on growing food far from supply lines. We also used the CSA "Eating in space" page (<https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp>), which says astronauts eat 1,900 to 3,200 calories a day, as a cross-check of the 3,000 kcal NASA value shown on the Sources panel.

No CSA number drives a game mechanic. The greenhouse rules come from NASA's Veggie results.

---

## Other References

- **Chang'e-4 Lunar Lander Neutrons and Dosimetry (LND) experiment.** Zhang et al., "First measurements of the radiation dose on the lunar surface", Science Advances, 2020. Average dose equivalent of about 1.37 mSv per day on the lunar surface, shown on the Sources panel. <https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/>
- **US Environmental Protection Agency, "Radiation Sources and Doses".** Average dose of about 6.2 mSv per year per person in the United States, used for the Moon-versus-Earth comparison. <https://www.epa.gov/radiation/radiation-sources-and-doses>
- **Roblox** (engine, Roblox Studio and Luau). <https://create.roblox.com/>
- **Rojo**, file sync between the repository and Roblox Studio. <https://rojo.space/>
- **Lune**, standalone Luau runtime used for the tests. <https://lune-org.github.io/docs>
- **Shackleton Base: A Journey to the Moon** (board game by Fabio Lopiano and Nestore Mangone). Thematic inspiration only, for the idea that a Moon base near Shackleton crater makes a fun game. We did not copy its name, rules, components or art. Space Base Odyssey is a different kind of game: daily resource sharing with delayed consequences, real NASA data, radiation and communication.

---

## Known limitations

- **Kids cannot play the public version yet.** New Roblox experiences are only open to age-checked accounts aged 16 or older until they pass Roblox's evaluation for all ages. Until then, the target players (7 to 12) cannot open the published game. Judges can watch the full playthrough video (TO ADD: link) or open `game.rbxl` in Roblox Studio and press Play.
- **Roblox needs an account and an install.** It is not a browser game without sign-in. This is why the video and the Studio file matter.
- **Storms are replays.** DONKI flares were observed near Earth. The game asks what would happen if a storm like that reached the base. It does not claim a real storm hit the Moon.
- **[Stage 2] Live data can be unavailable.** If HTTP requests are turned off for the experience, or DONKI does not answer within 15 seconds, the game uses the archive and says so.
- **Meters are game units.** Air, food and radiation run from 0 to 100 so kids can read them. The real values are shown separately on the Sources panel. Timings such as the 150-second shift and the 45-second and 15-second warnings are game values chosen for playability.
- **The Moon's signal delay is short.** At 1.3 seconds, the delay itself is not a problem on the Moon, so the game makes the antenna link the decision and compares with Mars, where it would be 3 to 22 minutes.
- **One base per server.** Gravity and lighting are global in Roblox, so each server runs one crew of up to four players.
- **No external links in the game.** Roblox does not allow them, so sources are credited as text and the links are in `DATA_SOURCES.md` and this page.

---

## Still to add before submitting

- TO ADD: 30-second demo video link (public, no sign-in, no minors, no NASA logos).
- TO ADD: full playthrough video link.
- TO ADD: 4 to 6 screenshots for the project page.
- TO ADD: confirm `game.rbxl` is committed at the repository root.
- TO ADD: check every **[Stage 2]** item in the real game, then remove the tags or the items that did not ship.
- TO ADD: update the balance test numbers if the tests change.
