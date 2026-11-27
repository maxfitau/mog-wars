# Decisions

One line each: what was chosen, and why. Newest at the bottom.

| # | Decision | Reason |
|---|---|---|
| 1 | Built the project in a new folder `/home/user/mog-wars` in the cloud container, not `C:\dev\mog-wars` | The PC folder was not offered to cloud sessions (the app listed it as unavailable), and attaching one needs a person to approve |
| 2 | Clean project layout (no `roblox-framework` template) | The brief asked for a clean client/server/shared layout; shared systems can be added later when a slice needs them |
| 3 | `DESIGN.md` not copied in; `CLAUDE.md` tells sessions to stop if it is missing | The file was never readable from the cloud session |
| 4 | Pinned tools to the same versions as the framework (Rojo 7.7.0, Selene 0.27.1, StyLua 0.20.0) | They were already chosen for the framework, so the two projects behave the same |
| 5 | No GitHub repo created, nothing pushed | The owner said not to push tonight, and creating a repo needs the owner's account |
| 6 | A war lasts 10 minutes, 16 players, 4 factions auto-balanced | A short round suits casual sessions; DESIGN.md may set different numbers |
| 7 | Map: four safe home bases plus five contested zones (centre worth double) | Gives each faction a near target and one shared prize without a complicated layout |
| 8 | Mog-off outcome is decided by tap count only, ties go to the defender, ranks give no advantage | Keeps the signature moment skill-based and clear of any power-for-pay or power-for-grind advantage |
| 9 | Boxes are earned in play and never sold for Robux | Avoids the paid random item rules and any pay-to-win risk |
| 10 | Rank-ups are paid for with Mog Points (a sink), not decided by lifetime points | The brief lists "rank-up costs", which reads as a price; it also keeps points useful at every level |
| 11 | Rank names beyond Chad and Mog God are placeholders and all positive: Rookie, Grunt, Fighter, Veteran, Captain, Warlord, Chad, Alpha, Titan, Mog God | Avoids ranks that demean low-ranked players, which would clash with the appearance-bullying risk in docs/compliance.md |
| 12 | Aura power rises about 10 percent per rank (Mog God about 1.9x a Rookie) | Rewards progress without letting a veteran carry a team alone |
| 13 | Single currency Mog Points; all numbers in `src/shared/EconomyConfig.luau` | One source of truth keeps the sim, code and docs in sync |
| 14 | Full rewards for 8 wars a day, half after; barracks capped at 8 hours | Healthy play for young players, no grind pressure |
| 15 | Rank ladder 250 to 16,000 (casual: Chad day 6, Mog God day 44) | Meets the owner's pacing targets per `tools/pacing.py` |
| 16 | Box odds sum to 100 and are shown; no pity or luck boosts | Matches Roblox paid-random rules even though boxes are never sold |
| 17 | Slice 1 uses a single placeholder team and aura power 1 per player; the map is built by code | No Studio editing is needed to test; factions and rank scaling arrive in slices 2 and 8 |
| 18 | Zone state is exposed as part attributes (`OwnerFaction`, `Progress`) and there are no remotes | Clients can read but never write; a HUD can read attributes later |
| 19 | Faction 4 is named "Aura Collective" in code (placeholder "Aura Cartel" renamed) | Avoids the drug-cartel connotation flagged in docs/compliance.md; one line in FactionRules.luau changes it back |
| 20 | Factions use Roblox Teams and matching spawn pad colours; no remote can change a faction | Built-in spawning does the base routing; server-only assignment stops cheating |
| 21 | The HUD reads zone attributes only (no remotes) and works out "which zone am I in" for display only | The server stays the only source of capture state; nothing the client shows can change a result |
| 22 | Only players on the capturing faction are paid, by pushing time; a player who leaves before the capture loses their share | Simple and cheat-proof; revisit if it feels unfair in playtests |
| 23 | `src/server/Lib/ProfileStore.luau` is a Studio-only mock that errors outside Studio | A published game can never pretend to save; the real module must be vendored first (docs/DATA.md) |
| 24 | A war is a 20-second intermission then a 10-minute war, repeating; zones only move during a war | Gives a clear start and end, and a moment to show the winner and reset |
| 25 | War winner is the highest zone-value total; ties go to more captures; still tied is a draw with no winner bonus | Simple, explainable tie-break (WarRules.winner) |
| 26 | Everyone who contributed at least 5 units gets 20 points; contributors on the winning faction get 60 more | Matches the economy numbers; idle players earn nothing |
| 27 | After 8 finished wars in a UTC day, capture and war rewards are halved (PlayerData v2 adds warsToday and lastWarDay) | Healthy-play rule from the economy doc, enforced by the server |
| 28 | The shove request carries no data; the server picks the nearest living enemy within 8 studs | The client cannot name a target, so it cannot shove across the map or hit teammates |
| 29 | A shove that finds no target does not use the cooldown | Missing should not be punished; the 0.2s spam guard still applies |
| 30 | Knockback is applied by the target's own client from a server message; the push penalty is server side | Character physics is client-owned; the penalty that matters for fairness stays on the server (needs playtest) |
| 31 | A mog-off starts when two enemies in the same zone stay within 6 studs for 1.5 seconds, with a 1-second get-ready; 20 second cooldown per player | Matches the brief ("when two enemies meet in a zone") without surprise instant duels |
| 32 | Ties go to the defender (the duellist whose faction holds the zone); with no defender it is a draw with no loser | Follows decision 8 and avoids punishing anyone when nobody has the advantage |
| 33 | Taps are capped at 10 per second on the server (max about 50 per duel) | A flood or autoclicker cannot win; the cap is in MogOffRules and tested |
| 34 | The loser's messages are gentle ("Nice try! Shake it off.") and they are stunned for 1.5s | Child-friendly tone from docs/compliance.md section 1 |
