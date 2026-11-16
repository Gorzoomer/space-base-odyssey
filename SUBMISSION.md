# Space Apps 2026 submission (final texts)

Copy each block into the matching field of the Space Apps project page. Challenge: **Build a Junior Astronaut Mission Trainer**. Every number comes from `src/shared/MissionData.luau` and `DATA_SOURCES.md`. The full documentation is in `DOCUMENTATION.md` (English) and `DOCUMENTACION.md` (Spanish).

---

## Project Name

Space Base Odyssey

---

## High-Level Project Summary

Space Base Odyssey is a cooperative Roblox game where kids aged 7 to 12 land at the Moon's south pole and grow a base from nothing. They carry parts from their lander and build the habitat, solar panels, a greenhouse, an antenna, a regolith storm shelter, a lab, ice drills, vehicles and finally a ship for Mars. An open world with 21 main quests and 9 side quests teaches one system at a time, and missions ask crews to share limited power between air, food and science every morning: every choice costs something. Solar storms replay real flares from NASA's DONKI database, live or archived and always labelled honestly, including real false alarms. 13 learning achievements reward what kids understand, the game runs in English and Spanish, and nobody ever gets hurt: a mission that goes wrong ends safely with a report that explains why.

---

## Link to Project Demo

TO ADD: YouTube link to `promo/SpaceBaseOdyssey_Trailer_30s.mp4` (30 s, English captions, public or unlisted, opens without sign-in).

---

## Link to Final Project

- Play it on Roblox: https://www.roblox.com/games/98598885274802
- Source code and documentation: https://github.com/Gorzoomer/space-base-odyssey

---

## Detailed Project Description

### What it does

Space Base Odyssey is a 3D outpost trainer built in Roblox Studio for kids aged 7 to 12. Players start in the small lander that brought them to the Moon's south pole, near the rim of Shackleton crater, and build a base step by step with C.A.R.L., a tracked helper robot that guides them, points the way and rescues anyone whose suit runs out of air. Every gameplay sentence has at most eight simple words, in English or Mexican Spanish, so a 7-year-old can read it.

### How each challenge topic becomes a decision with a consequence

| Topic | What the player decides | What it costs |
| :--- | :--- | :--- |
| Power budgeting | How to share the day's power cells (one per clean solar array plus a battery) between life support, greenhouse and science. | A cell for science is a cell taken from air or food. Dust takes a cell away until someone cleans the panel. |
| Life support | Power for life support, fetching ice from a dark crater, fixing leaks, refilling the suit. | Oxygen is made from water with electricity. Breathing, leaks and suit refills use air. |
| Food production | Power for the greenhouse and building more domes. | Food arrives the next day, never today: plants take time. |
| Radiation shielding | Run to the shelter or keep working outside during a solar storm. | Dose received outside rises live and never goes down. The shelter protects by its mass, not by power. |
| Communication delay | Spend shift time aligning the antenna with Earth. | With the link, Earth warns the crew 45 s before the particles; without it, 15 s. Science data needs the link to reach Earth. |

### How it plays

- **Open world:** 21 main quests and 9 side quests teach one system at a time. The habitat grows through five base levels, from landing camp to spaceport.
- **Missions:** training and story missions with a calm planning phase (share the power) and a 150-second work shift (clean panels, carry ice, fix leaks, align the antenna, shelter from storms). A day-by-day report explains every result.
- **Learning achievements:** 13 achievements unlock only when the server sees the real event, and each one says what the kid learned (for example "Oxygen comes from water plus electricity" or "The shelter protects by mass").
- **Worlds and saving:** three save slots per player, saved automatically. Each world runs in its own private server: alone, or with up to 3 Roblox friends.

### Real NASA space weather, honestly labelled

At server start the game asks NASA / CCMC DONKI for the solar flares and solar energetic particle events of the last 30 days. Strong live flares are replayed as storms and labelled "live" with their date; otherwise a saved archive of 11 real X-class flares is used and labelled as a replay. Some are real false alarms (for example the X9.0 flare of October 2024 brought no particle storm), teaching that a big flare does not always mean danger. The game always says the flare was observed near Earth and asks "what if a storm like this reached your base?". It never presents archived data as live.

### How it works

- Roblox Studio and Luau (`--!strict`), synced from the repository with Rojo. The world is built by code.
- Server-authoritative design: clients only send actions, which the server validates.
- A pure simulation module (`Simulation.luau`) and every game number live in shared modules, each number tagged REAL (with its source in `DATA_SOURCES.md`) or GAME (chosen for playability).
- Automated checks run with Lune: 39,477 localization checks (every text in English and Spanish, at most 8 words), plus base 1,711, missions 706, balance 716, economy 221, achievements 227, cinematic 189 and worlds 68. The balance test proves that no fixed power plan earns 3 stars without reacting to events.

### Benefits for kids

- **Trade-offs they can feel:** the food meter drops the day after they cut the greenhouse.
- **Real science, simply told:** plants take time, oxygen comes from water and electricity, a thick wall stops particles, radiation dose never goes away.
- **Teamwork:** up to four players split the jobs and run for the shelter together.
- **Safe failure:** an early return is a result with a reason and an invitation to try again.
- **Honest data:** kids see the date of the real flare and learn the difference between live data and an archive.

### Tools

Roblox Studio, Luau, Rojo, Lune, Git and GitHub, HyperFrames (trailer), Tabler Icons (MIT), and Claude by Anthropic as an AI assistant (see Use of AI).

---

## Use of AI (Super Intelligence)

We used **Claude, by Anthropic** (in Claude Code), as an AI assistant during the hackathon:

- **Research and fact checking:** Claude gathered candidate facts with their sources into `DATA_SOURCES.md`, and a separate verification pass re-opened every source. Facts that could not be verified are not used in the game.
- **Code:** Claude wrote most of the Luau code and the automated tests from the team's design, and tested the game in Roblox Studio.
- **Text drafts:** in-game sentences in English and Spanish, the documentation and these texts.
- **Video:** Claude edited the 30-second trailer in HyperFrames from real in-game footage; its music was synthesized in code.

What the team did: the game concept, the setting, every design decision, playtesting, publishing on Roblox and the presentation. The team reviewed and approved the numbers and texts.

Disclosure: every AI-assisted code file starts with a disclosure line. No AI-generated images are used in the game; the world is built from plain parts by code. The 30-second demo trailer contains no AI-generated images, video or voices. (Our separate promo videos use an AI-generated voiceover made with ElevenLabs, labelled as such where published.)

---

## NASA Data

| Dataset | URL | What it feeds in the game |
| :--- | :--- | :--- |
| NASA / CCMC DONKI, solar flares (FLR) | https://ccmc.gsfc.nasa.gov/DONKI/WS/get/FLR | Storms: live flares of the last 30 days and an archive of 11 real X-class flares, with class, date and DONKI ID. |
| NASA / CCMC DONKI, solar energetic particles (SEP) | https://ccmc.gsfc.nasa.gov/DONKI/WS/get/SEP | Whether a flare brings a particle storm or is a real false alarm. |
| NASA Solar storms and flares | https://science.nasa.gov/sun/solar-storms-and-flares/ | Light first, particles later: there is time to shelter. |
| NASA Life Support Baseline Values and Assumptions (BVAD) 2022 | https://ntrs.nasa.gov/api/citations/20210024855/downloads/BVAD_2.15.22-final.pdf | Daily oxygen, water and food needs per crew member. |
| NASA ISS ECLSS fact sheet (2025) | https://www.nasa.gov/wp-content/uploads/2025/08/g-657270-59-hp-environmental-control-and-life-support-system-eclss.pdf | Oxygen is made from water with electricity. |
| LCROSS impact results (Colaprete et al., Science, 2010) | https://experts.arizona.edu/en/publications/detection-of-water-in-the-lcross-ejecta-plume/ | Water ice in a permanently shadowed crater (about 5.6% by mass in Cabeus). |
| NASA Veggie fact sheet | https://www.nasa.gov/wp-content/uploads/2019/04/veggie_fact_sheet_508.pdf | Plants take time: the first lettuce eaten on the Space Station grew for 33 days. |
| LRO Diviner temperatures | https://science.nasa.gov/wp-content/uploads/2024/01/lrolitho7temperaturevariation27may2014.pdf | The extreme cold of shadowed polar craters. |
| South-pole illumination from LRO topography (Mazarico et al., 2011) | https://ntrs.nasa.gov/citations/20120010094 | A spot on the Shackleton rim is sunlit about 240 days a year, so the base runs on solar power. |
| NASA Moon fact sheet (NSSDC) | https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html | Moon gravity, 16.5% of Earth's, used for the game's gravity. |
| NASA-STD-3001 Volume 1 Rev C | https://standards.nasa.gov/sites/default/files/standards/NASA/C//nasa-std-3001-vol-1-rev-c-signature.pdf | Career radiation limit (600 mSv) and storm shelters that protect by mass. |
| NASA TM-20250003885 (lunar communication latency) | https://ntrs.nasa.gov/api/citations/20250003885/downloads/NASA%20TM20250003885.pdf | Earth-Moon signal time of about 1.3 s. |
| NASA Mars Relay Network | https://science.nasa.gov/mars/mars-relay-network/ | Earth-Mars signal time of 3 to 22 minutes. |
| NASA Blue Marble: Land Surface, Ocean Color and Sea Ice (NASA Visible Earth, Goddard) | https://visibleearth.nasa.gov/ (public-domain copy used: Wikimedia Commons, "Whole world - land and oceans.jpg") | The turning Earth in the game's sky, with its phases and eclipses. |

---

## Space Agency Partner Data

**Canadian Space Agency (CSA).** We read the CSA food-production resources linked by the challenge (https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/), the Deep Space Food Challenge and the Naurvik project for background on growing food far from supply lines, and used the CSA "Eating in space" page (https://www.asc-csa.gc.ca/eng/astronauts/living-in-space/eating-in-space.asp) as a cross-check of the daily calories shown in the game. No CSA number drives a game mechanic.

---

## Other References

- Zhang et al., "First measurements of the radiation dose on the lunar surface" (Chang'e-4 LND), Science Advances, 2020: about 1.37 mSv per day on the Moon. https://pmc.ncbi.nlm.nih.gov/articles/PMC7518862/
- US EPA, "Radiation Sources and Doses": about 6.2 mSv per year in the United States. https://www.epa.gov/radiation/radiation-sources-and-doses
- Roblox Studio and Luau: https://create.roblox.com/ · Rojo: https://rojo.space/ · Lune: https://lune-org.github.io/docs
- Tabler Icons (MIT): https://tabler.io/icons
- Shackleton Base: A Journey to the Moon (board game, Fabio Lopiano and Nestore Mangone): thematic inspiration only; no rules, names or art were copied.

---

## Known limitations

- **Roblox age gate:** new Roblox experiences are open only to age-checked accounts aged 16 or older until Roblox reviews them for all ages, so the target players (7 to 12) cannot open the public game yet. Judges can watch the trailer, read the code and documentation, or open the place in Roblox Studio.
- **Roblox needs an account and an install.**
- **Storms are replays:** DONKI flares were observed near Earth; the game asks what would happen if a storm like that reached the base.
- **Meters are game units (0 to 100);** the real values are shown separately in the game's "Where our numbers come from" screen.
