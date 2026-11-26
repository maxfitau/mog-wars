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
