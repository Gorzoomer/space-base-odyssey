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
| Use a task | Hold E | Tap the prompt |
| Language | EN/ES button | EN/ES button |

## Status

- [x] Project setup, verified data sources
- [x] Stage 1: playable mission loop on the Moon
- [x] Stage 2: live NASA data, real-data screen, Earth link
- [x] Stage 3: base reacts to decisions, guided first days, task markers, C.A.R.L. drone
- [x] Stage 4: training and story missions, hidden secrets, visual identity with icons
- [ ] Playtests with people outside the team
- [ ] Public release

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full development log.

## Running it locally

1. Install [Rojo](https://rojo.space) 7.7.1 and its Roblox Studio plugin.
2. Open an empty Baseplate place in Roblox Studio and enable **Game Settings → Security → Allow HTTP Requests** (needed for live NASA data).
3. Run `rojo serve` in this folder and press **Connect** in the Rojo plugin.
4. Press **Play**.

Tests: `lune run tests/balance` and `lune run tests/localization` ([Lune](https://github.com/lune-org/lune) 0.11).

## Repository layout

| Path | Contents |
| :--- | :--- |
| `src/shared` | Mission rules, data, network contract, text (synced to `ReplicatedStorage.Shared`) |
| `src/server` | World builder, mission and crew services, live NASA data (synced to `ServerScriptService.Server`) |
| `src/client` | Interface and guidance (synced to `StarterPlayer.StarterPlayerScripts.Client`) |
| `tests` | Balance and localization tests |
| `DATA_SOURCES.md` | Every real-world number with its source |
| `THIRD_PARTY_NOTICES.md` | Licences of third-party assets (Tabler Icons) |
| `DEVELOPMENT.md` | Development log: decisions, tests, use of AI |
| `SUBMISSION.md` | Drafts of the Space Apps project page |

## Use of AI (Super Intelligence)

Research compilation, fact verification, code and text drafts are produced with AI assistance (Claude, by Anthropic). Each code file carries a disclosure header. The concept, design decisions, testing and balance calls are made by the team. Details are in [DEVELOPMENT.md](DEVELOPMENT.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
