# Space Base Odyssey

A cooperative Roblox game where kids aged 7 to 12 run a base at the Moon's south pole and learn that every choice in space has a cost: power, oxygen, food, radiation and contact with Earth.

Built for the NASA Space Apps Challenge 2026, challenge **"Build a Junior Astronaut Mission Trainer"**.

> Work in progress during the hackathon (14–15 November 2026).

## Status

- [x] Project setup
- [ ] Core simulation
- [ ] Moon base and mechanics
- [ ] NASA data integration
- [ ] Playable release

## Repository layout

| Path | Contents |
| :--- | :--- |
| `src/shared` | Modules shared by server and client (synced to `ReplicatedStorage.Shared`) |
| `src/server` | Server code (synced to `ServerScriptService.Server`) |
| `src/client` | Client code (synced to `StarterPlayer.StarterPlayerScripts.Client`) |
| `DATA_SOURCES.md` | Every real-world number used in the game, with its NASA source |

## Running it locally

1. Install [Rojo](https://rojo.space) 7.7.1 and its Roblox Studio plugin.
2. Open an empty Baseplate place in Roblox Studio.
3. Run `rojo serve` in this folder and press **Connect** in the Rojo plugin.

## Data

All numbers come from NASA and partner sources listed in [DATA_SOURCES.md](DATA_SOURCES.md). Space weather events come from NASA's DONKI database (CCMC).

## Use of AI (Super Intelligence)

Code, data compilation and text drafts are produced with AI assistance (Claude, by Anthropic). Each code file carries a disclosure header. The game concept, design decisions, testing and balance calls are made by the team.

## License

Apache License 2.0. See [LICENSE](LICENSE).
