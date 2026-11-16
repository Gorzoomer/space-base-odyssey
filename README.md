# Space Base Odyssey

A cooperative Roblox game where kids aged 7 to 12 run a base at the Moon's south pole and learn that every choice in space has a cost: power, oxygen, food, radiation and contact with Earth.

Built for the NASA Space Apps Challenge 2026, challenge **"Build a Junior Astronaut Mission Trainer"**.

## How it plays

A mission lasts 7 days. Each day has three phases:

1. **Plan (no clock).** Place a few power cells on the power board:
   - **Life support** turns water into air with electricity.
   - **Greenhouse** grows food, which arrives tomorrow because plants take time.
   - **Science** earns stars.

   There is never enough power for everything.
2. **Shift (2.5 minutes, real time).** Walk around the base in Moon gravity. Your suit oxygen drains outside, and refilling it uses the base's air. Tasks:
   - Clean dusty solar panels.
   - Fetch ice from the shadowed crater.
   - Fix air leaks.
   - Align the antenna with Earth.

   When a real solar flare replay comes, run to the regolith shelter. With the antenna aligned, Earth's forecasters warn you sooner.
3. **Report.** Each day shows what happened and why. Then try another plan.

Nobody dies. If a meter runs out, the crew returns home early, and the report explains what to try next time.

Between missions, the base is yours to grow. You land in a small lander and build everything yourself, step by step: carry parts crates from the lander and assemble them with your wrench. Tools unlock as you go (ice drill, tablet, brush, repair kit, fresh food), a garage gives you a moon buggy and an ice hauler to drive, and five real exploration sites and random meteorite craters wait to be scanned. Ice and good work earn credits and experience. Spend them on automatic ice drills, a cargo robot, upgrades, skills (like a double jump from a backpack gas puff) and pets.

## NASA data

- **Live space weather:** at server start the game asks NASA's DONKI database (CCMC) for the last 30 days of solar flares and particle events.
- **Real flares:** storms replay real X-class flares from the DONKI archive and say so with their date. Big flares that brought no particles appear as real "false alarms".
- **Real facts:** astronaut oxygen, water and food (NASA BVAD), Moon light and cold (LRO), lunar ice (LCROSS), space plants (Veggie) and radiation. They appear on the in-game "Where our numbers come from" screen.

Every number and its source is listed in [DATA_SOURCES.md](DATA_SOURCES.md).

## Controls

| Action | PC | Touch |
| :--- | :--- | :--- |
| Move | WASD | Thumbstick |
| Run (uses suit air twice as fast) | LeftShift | Run button |
| Use a task, build, collect ice | Hold E | Tap the prompt |
| Air boots / jetpack on or off (bought at the Lab) | B / J | Gear buttons |
| Double jump (air boots) | Space twice | Jump button twice |
| Fly up (jetpack) | Hold Space in the air | Hold the jump button |
| Auto-run | X (X or WASD to stop) | Auto-run button |
| Drive / get out of a vehicle | WASD / Space | Thumbstick / jump |
| Read C.A.R.L.'s lines again | Replay button by the bubble | Same |
| Answer C.A.R.L.'s question, learn a gold word | Click it | Tap it |
| Settings, missions, wardrobe, achievements | Buttons at the top right | Same |
| Moon Logbook | "Logbook" on the mission screen | Same |
| Language, volume, Helpers (big text, less motion, message time) | Settings | Settings |

There are no debug keys for players: the team's test keys work only in Roblox Studio.

## Status

- [x] Project setup, verified data sources
- [x] Stage 1: playable mission loop on the Moon
- [x] Stage 2: live NASA data, real-data screen, Earth link
- [x] Stage 3: base reacts to decisions, guided first days, task markers, C.A.R.L. drone
- [x] Stage 4: training and story missions, hidden secrets, visual identity with icons
- [x] Stage 5: live meters, water and antenna consequences, real rotating Earth with eclipses, astronaut suit, C.A.R.L. guidance and fun facts, settings and codes
- [x] Stage 6: build and grow the base (tycoon loop with credits, levels, skills, automatic ice drills), pets, wardrobe, helmet that keeps the player's avatar, C.A.R.L. as a tracked rover
- [x] Stage 7: start in the lander, building in steps, tools, lab, garage with drivable rovers, landing pad and ship, exploration sites, meteorites
- [x] Stage 8: pressurized modules, air boots and jetpack with a gas tank, new skills, auto-run
- [x] Stage 9: start menu with three save slots, open world with main quests, habitat base levels 1-5, paced economy
- [x] Stage 10: playtest polish: smaller text boxes, always-on vitals panel, quest notices, visible saving, walkable tubes; then private worlds (up to 4 friends), calmer storm drills with live radiation, learning achievements, cinematic start menu
- [x] Stage 10 release: published to the live experience (16 November 2026)
- [x] Stage 11: overnight overhaul (16 November 2026, version 0.11.0): sound and music with an honest helmet rule, an ice line tycoon you can watch (drills, belt, silo, water plant, cargo robot, "while you were away"), a safer server with save locks, quests that teach (C.A.R.L.'s picture questions, a picture glossary), a start menu without "Load game", saved settings and a Helpers page, a daily supply capsule and the Moon Logbook, celebrations, a safer map, debug keys only in Studio
- [ ] Playtests with people outside the team

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full development log.
All the project documentation in one place: [DOCUMENTATION.md](DOCUMENTATION.md) (English) and [DOCUMENTACION.md](DOCUMENTACION.md) (Spanish).
For teachers: [docs-public/EDUCATOR_GUIDE.md](docs-public/EDUCATOR_GUIDE.md) (English) and [docs-public/GUIA_DOCENTE.md](docs-public/GUIA_DOCENTE.md) (Spanish), three 20-minute lesson plans.

## Running it locally

1. Install [Rojo](https://rojo.space) 7.7.1 and its Roblox Studio plugin.
2. Open an empty Baseplate place in Roblox Studio and enable **Game Settings → Security → Allow HTTP Requests** (needed for live NASA data).
3. Run `rojo serve` in this folder and press **Connect** in the Rojo plugin.
4. Press **Play**.

Tests ([Lune](https://github.com/lune-org/lune) 0.11): `lune run tests/<name>` for `balance`, `missions`, `base`, `economy`, `cinematic`, `worlds`, `achievements`, `daily`, `feel`, `reading` and `localization`.

## Repository layout

| Path | Contents |
| :--- | :--- |
| `src/shared` | Mission rules, data, network contract, text (synced to `ReplicatedStorage.Shared`) |
| `src/server` | World builder, mission and crew services, live NASA data (synced to `ServerScriptService.Server`) |
| `src/client` | Interface and guidance (synced to `StarterPlayer.StarterPlayerScripts.Client`) |
| `tests` | Eleven Lune test suites (rules, economy, worlds, achievements, daily capsule, text) |
| `docs-public` | Educator pack in English and Spanish |
| `DATA_SOURCES.md` | Every real-world number with its source |
| `THIRD_PARTY_NOTICES.md` | Licences of third-party assets (Tabler Icons, NASA Blue Marble, CC0 sounds) |
| `DEVELOPMENT.md` | Development log: decisions, tests, use of AI |
| `SUBMISSION.md` | Drafts of the Space Apps project page |

## Use of AI (Super Intelligence)

Research compilation, fact verification, code and text drafts are produced with AI assistance (Claude, by Anthropic). Each code file carries a disclosure header. The concept, design decisions, testing and balance calls are made by the team. Details are in [DEVELOPMENT.md](DEVELOPMENT.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
