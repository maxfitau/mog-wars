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
| 9 | Boxes are earned in play and never sold for Robux | Avoids the paid random item rules and any pay-to-win problem |
| 10 | Rank-ups are paid for with Mog Points (a sink), not decided by lifetime points | The brief lists "rank-up costs", which reads as a price; it also keeps points useful at every level |
| 11 | Rank names beyond Chad and Mog God are placeholders and all positive: Rookie, Grunt, Fighter, Veteran, Captain, Warlord, Chad, Alpha, Titan, Mog God | Avoids ranks that demean low-ranked players, which would clash with the appearance-bullying concern in docs/compliance.md |
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
| 35 | Rank-up reward boxes are stored on the player's save (PlayerData v3 `boxes`) until slice 9 adds opening them | Rewards are never lost between slices; boxes are capped at 1000 per tier |
| 36 | Aura scales a player's push strength in the capture bar; contribution for payouts stays based on time spent pushing | Rank speeds captures a little without letting a high rank take a whole zone's pool |
| 37 | The rank-up request carries no data and is limited to one every 0.5 seconds; a full box stack blocks the rank-up before any points are spent | The server decides everything, and nothing is half-applied |
| 38 | Every war contributor earns one box: Veteran for the winning faction, Recruit for others, up to 12 a day | This is what the pacing simulation already assumed, so the pacing numbers still hold |
| 39 | A duplicate cosmetic or a full unit stack pays Mog Points instead (50 for a cosmetic, the unit's sell value for a unit) | Nothing is wasted and no outcome is ever blocked |
| 40 | The open-box request carries only a tier name, validated against the config; the roll happens after every check and the box is taken in the same step | The client cannot open boxes it does not own or pick an outcome |
| 41 | Deploying a unit uses it up and it lasts until the war phase changes; selling pays the config sell value | Matches "each lasts for one war"; nothing carries over |
| 42 | A tank boosts the whole faction's push in the zone where it is deployed, one tank per faction per zone, 50 percent boost | Gives teams a reason to defend a zone together; the limit stops stacking |
| 43 | Every unit boost must be between 1x and 2x (checked in UnitRules and a test on the real config) | A bad config edit cannot create an unbeatable unit |
| 44 | The horse sets walk speed 30 percent higher and is re-applied after respawn until the war ends; a mog-off stun still stops movement | Speed is a convenience, not a way to dodge the duel rule |
| 45 | The daily streak reward is a box (Recruit days 1 to 3, Veteran 4 to 6, Elite 7), not points | `DESIGN.md` says "Daily box with a 7-day streak" and boxes are earned only; pacing re-checked (casual Chad day 6, Mog God day 43) |
| 46 | The claim day and the box are saved in the same step; the server clock (UTC day) decides; a saved day in the future is refused | A double claim or clock trick cannot pay twice |
| 47 | Barracks starts building on a player's first visit and pays 6 points an hour plus 2 per rank, capped at 8 hours, collected by button | Matches "barracks earn points offline"; small next to active play |
| 48 | `DESIGN.md` is the authority; every difference is listed in docs/design-reconciliation.md and large changes wait for the owner's yes | The brief arrived after slices 1 to 11 were built, so changing ranks and boxes needs the owner's approval of the new numbers |
| 49 | Seven ranks from `DESIGN.md`: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God (costs 350, 800, 1,500, 2,600, 10,000, 24,000); aura +15 percent per rank | The brief overrides the placeholder ten ranks (supersedes decisions 10 to 12 and 35); casual reaches Chad day 6 and Mog God day 43 |
| 50 | Boxes are Gold, Diamond and Ultra, one per paid contributor on a capture by zone value (side Gold, centre Diamond, 3 or more Ultra), 12 a day; rank-up and war-participation boxes are removed; the daily streak box is Gold, Diamond, Ultra | The brief says boxes come from captures by territory value (supersedes decisions 35, 38); pacing refitted |
| 51 | The placeholder map is data in `src/shared/MapLayout.luau`: nine zones (eight worth 1, the centre worth 2) and four corner bases on a 320 stud plate; tests check no zones touch and bases are safe | `DESIGN.md` asks for 8 to 12 territories (supersedes decision 7); data makes it easy to change and lets the pacing tool read the real zone values |
| 52 | During a war, a joining or respawning player appears just outside the owned zone nearest the map centre, on the side facing their base; with no owned zone, or outside a war, they use the home base | `DESIGN.md`: "spawn straight onto your faction's front line in a war already running"; the nearest-to-centre rule is a simple, predictable definition of the front |
| 53 | War length is 12 minutes and always kept between 10 and 15 minutes | `DESIGN.md` says 10 to 15 minute rounds; the bigger map needs a little longer; a bad config value cannot break it |
| 54 | Aura power comes only from training level (1x to 1.9x over 20 levels, 4.5 percent each); rank is status and no longer changes aura | `DESIGN.md`: aura power is raised in the Training Arena, and ranks "measure aura earned by winning" (supersedes the aura parts of decisions 12, 36 and 49); easy to give rank a small bonus again if wanted |
| 55 | A treadmill belt sits beside each home base and works any time, not only between wars | The break between wars is only 20 seconds, so "between wars" would allow almost no training; leaving the front to train is a real trade-off |
| 56 | A stride is one second alive, on a belt and moving (the belt pushes you back, so you must keep walking); only 10 minutes a day count; the full 20 levels take about three weeks | Healthy play, no endless grinding, a medium-term goal between the daily and the long rank goal |
| 57 | Training can never be bought or sped up with Robux | `DESIGN.md` rule 1 (not pay-to-win); added to docs/compliance.md |
