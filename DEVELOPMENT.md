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

**About 16:40 – Stage 3 in progress.**
- The base reacts visibly to power decisions: greenhouse lights, air maker, rover.
- Guided first two days.
- Task markers.
- The C.A.R.L. drone, which points to the shelter during storms.

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
| Roblox Studio as the engine | Team | Team skills; Roblox was used in earlier Space Apps editions. |

## Testing evidence

| What | How | Result |
| :--- | :--- | :--- |
| Mission balance | `lune run tests/balance` | 252 checks pass. |
| Text length and translations | `lune run tests/localization` | All keys in en and es, at most 8 words. |
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
