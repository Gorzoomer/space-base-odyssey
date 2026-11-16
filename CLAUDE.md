# Space Base Odyssey - instructions for AI coding assistants

Roblox (Luau) game for NASA Space Apps 2026, challenge "Build a Junior Astronaut Mission Trainer". Kids aged 7-12 run a base at the Moon's south pole and learn that every choice costs something.

## Workflow

- Files in this folder are the source of truth. Rojo (`rojo serve`, plugin Connect) syncs them into Studio:
  - `src/shared` to `ReplicatedStorage.Shared`
  - `src/server` to `ServerScriptService.Server`
  - `src/client` to `StarterPlayer.StarterPlayerScripts.Client`
- Edit the files, never scripts inside Studio. The world is built by code (`src/server/WorldBuilder.luau`), not by hand-placed parts.
- Tests:
  - `lune run tests/balance`: mission rules. Must pass.
  - `lune run tests/missions`, `lune run tests/base`, `lune run tests/economy` and `lune run tests/cinematic`: missions, build-and-grow rules, economy pacing and the cinematic camera shots. Must pass.
  - `lune run tests/localization`: every key in en and es, at most 8 words.
  - `lune run tests/achievements`: learning achievements (ids, icons, texts, unlock rules, saves). Must pass.
  - `lune run tests/worlds`: private worlds (who may join a world, whose base it shows). Must pass.
  - `lune run tests/daily`: daily supply capsule and Moon Logbook (fixed rewards, one capsule per UTC day, forgiving calendar, milestones, saves). Must pass.
- Check that the project still builds with `rojo build default.project.json -o <temp>.rbxl`.

## Rules

- Every number comes from `src/shared/MissionData.luau`, tagged REAL or GAME. A REAL value must exist in `DATA_SOURCES.md` with its source. No invented statistics.
- `src/shared/Simulation.luau` stays pure: no Roblox instances, so it runs in Lune.
- The server is authoritative. Clients only send `Types.Action`, and the server validates every one.
- Player-facing text uses localization keys (`src/shared/Localization.luau`): English default, Spanish second, at most 8 words, words a 7-year-old understands.
- Science must stay correct:
  - The shelter protects by mass, not power.
  - Radiation dose never goes down.
  - Plants take time to grow.
  - Oxygen comes from water plus electricity.
  - A big flare does not always bring a particle storm.
  - DONKI events were observed near Earth. Say "what if a storm like this reached your base", never that it did.
- Never present archived data as live.
- No NASA logos, insignia or mission patches. Credit sources as text ("NASA / CCMC DONKI"). Roblox does not allow external links inside an experience.
- No Toolbox or Marketplace assets. The only image assets are the team-uploaded Tabler icons (MIT) listed in `src/shared/Icons.luau`; tint them with `src/shared/Theme.luau` colours. Never use emoji in the UI.
- Visual identity "Lunar Sunrise": use `Theme.ROLE` colours and `Theme.FONT` fonts everywhere (UI, lights, base accents).
- Every code file starts with `--!strict` and an SI disclosure line. The hackathon rules require disclosing AI use.
- Everything committed is in English, except `DOCUMENTACION.md`: the Spanish twin of `DOCUMENTATION.md` (team request). Keep both in step. `docs/` (Spanish planning notes) and `promo/` (video recordings) are git-ignored.
