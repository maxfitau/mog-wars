# Slices

Small, separately playable steps. Build ONE at a time, in this order. A slice is finished only when its
"done when" list is true, its tests pass, and it is committed. Each slice also respects `DESIGN.md` (read it
first) and `CLAUDE.md`. Cloud sessions cannot run Studio, so every "Test in Studio" step is for a session that
runs on a PC, or for you.

Terms: **pure logic** means Luau modules with no Roblox calls, testable without Studio. **Server owns** means
clients can only ask; the server decides.

| # | Slice | Needs |
|---|---|---|
| 1 | Capture one territory by standing in it | nothing |
| 2 | Factions and spawning | 1 |
| 3 | Contested capture and the capture bar HUD | 2 |
| 4 | Mog Points and saving | 3 |
| 5 | War rounds and winners | 4 |
| 6 | Shove | 3 |
| 7 | Mog-offs | 6 |
| 8 | Ranks and aura power | 4 |
| 9 | Boxes | 5, 8 |
| 10 | Units: tank and horse | 9 |
| 11 | Daily streak and barracks | 4 |
| 12 | Cosmetic shop | 4 |
| 13 | Polish: tutorial, effects, sounds, mobile | 5 |
| 14 | Launch prep | all |
| 15 | Training Arena: treadmill (built) | 8 |
| 16 | Training stations by rank (planned, Update 1, not built) | 15, 8 |
| 17 | Battle pass, cosmetic only (planned, not built) | 12, 18 |
| 18 | Seasons, friends and the squad bonus | 5, 12 |
| 19 | Number pop-ups and big numbers (planned, not built) | 4, 9 |
| 20 | Prestige and the skill tree (planned, Update 2, not built) | 8, 19 |
| 21 | Mog Arena tycoon (planned, Update 3, not built) | 16, 20 |
| 22 | Launch switches and gradual reveal (built) | all |
| 23 | Two islands: War Island and Training Island (built) | 15, 12 |

**Release plan (from the owner):** everything is built, but launch switches on only the war, ranks, boxes and units, the
treadmill, the daily streak and the cosmetic shop. Seasons and the squad bonus are built and switched off; they come on as later
weekly updates. Update 1 = per-rank training stations (slice 16). Update 2 = prestige and the skill tree (slice 20). Update 3 =
the Mog Arena tycoon (slice 21). Switches live in `src/shared/Features.luau`; the first session is kept simple by slice 22.

## 1. Capture one territory by standing in it

**Build (code written, not yet playtested):** `src/server/Systems/PlaceholderMap.luau` makes a baseplate, a spawn and
one zone tagged `Zone`; `CaptureSystem.luau` finds who stands in each zone (`ZoneGeometry`) and runs
`CaptureBar`. No remotes exist, so clients cannot touch zone state.
The zone part changes colour when captured. No factions yet: a single "player team".
**Test:** pure tests for the capture bar (`tests/CaptureBar.test.luau`). In Studio: join, stand in the zone and
watch it fill and capture; step out and watch progress fall back; leave and rejoin and confirm it resets cleanly.
**Done when:** standing in the zone captures it in the expected time from `docs/economy.md`; a client message
cannot change zone state; no errors in Output.

## 2. Factions and spawning

**Build:** four factions with colours, server-side assignment and balancing, a home-base spawn per faction, and
a team colour on each character.
**Test:** pure test for balancing. In Studio with 2 to 4 test clients: factions stay balanced within one player;
each spawns at their base; a player cannot change faction mid-war.
**Done when:** balanced assignment for 1 to 16 players and correct spawns.

## 3. Contested capture and the capture bar HUD

**Build (code written, not yet playtested):** several zones (nine on the placeholder map: eight worth 1, the centre worth double), per-faction presence, teammates stacking, enemies pushing back, per-zone progress sent
to clients, and a simple on-screen bar for the zone you stand in.
**Test:** pure scenarios (alone, two teammates, one enemy, two enemies from different factions, empty zone). In
Studio with 2 clients on different factions.
**Done when:** the outcomes match the capture-bar rules and the HUD never shows a state the server did not send.

## 4. Mog Points and saving

**Build (code written, not yet playtested):** contribution scoring while pushing; payout on capture split by contribution
(`src/shared/ContributionScoring.luau`); a points counter on the HUD; saving points with session locking.
**Test:** pure tests for scoring and payouts. In Studio: capture with a teammate and check the split; rejoin and
check points saved (needs a scratch place with live stores).
**Done when:** payouts never exceed the pool, an idle player earns nothing, and points survive a rejoin.

## 5. War rounds and winners

**Build (code written, not yet playtested):** a 10-minute war timer, zone-control score, a winner and bonus, an intermission, and a map reset.
**Test:** pure tests for scoring and tie-breaks. In Studio: play a full war with two clients.
**Done when:** a war starts, ends, awards the bonus once, and resets without leftovers.

## 6. Shove

**Build (code written, not yet playtested):** a shove ability with a cooldown, validated on the server (range and cooldown), with knockback and a
brief push penalty.
**Test:** pure tests for cooldown and range checks. In Studio: shove an enemy; spam the button and confirm the
cooldown holds.
**Done when:** the server refuses too-early or out-of-range shoves and the effect matches the brief.

## 7. Mog-offs

**Build (code written, not yet playtested):** the 5-second tapping duel when two enemies stay close in a zone: server-counted taps (rate capped),
winner, knockback and brief stun for the loser, cooldown, and a clear on-screen duel.
**Test:** pure tests for duel resolution and tap capping. In Studio with 2 clients: both tap; one taps faster; one
uses an autoclicker-like burst and is capped.
**Done when:** the outcome follows tap counts only and a tap flood cannot win.

## 8. Ranks and aura power

**Build (code written, not yet playtested):** the seven ranks (`src/shared/RankRules.luau`), a rank-up screen, spending Mog Points, and aura power
scaling.
**Test:** pure tests for costs and rank-up. In Studio: earn points, rank up, check the aura effect.
**Done when:** rank-up is server-only, atomic, and the costs match `docs/economy.md`.

## 9. Boxes

**Build (code written, not yet playtested):** earn boxes on captures (Gold, Diamond, Ultra by zone value), a box-opening screen that shows the odds for that tier before opening, server
rolls (`src/shared/BoxRoll.luau`), and the rewards.
**Test:** pure tests for rolls and odds. In Studio: open many boxes and compare the results with the shown odds.
**Done when:** shown odds equal the server's weights, every tier sums to 100 percent, and there is no way to buy a
box with Robux.

## 10. Units: tank and horse

**Build (code written, not yet playtested):** units from boxes, deploy a tank (faster capture in its zone) or ride a horse (faster movement) for one
war, and sell units for Mog Points.
**Test:** pure tests for the boosts and selling. In Studio: deploy, capture faster, sell.
**Done when:** units expire at war end, selling is atomic, and boosts stay inside the limits in the economy file.

## 11. Daily streak and barracks

**Build (code written, not yet playtested):** the 7-day daily box streak and offline barracks income, both on the server clock.
**Test:** pure tests for streak days, resets and the barracks cap. In Studio: change the saved time to simulate days.
**Done when:** a double claim is impossible and income never exceeds the cap.

## 12. Cosmetic shop

**Build (code written, not yet playtested):** a Robux shop for cosmetics only: trails, auras and fixed titles from
`src/shared/CosmeticCatalog.luau`, sold as developer products (ids are 0 until you create them on the Creator
Dashboard). Receipts are applied once; players wear items from the shop screen and everyone sees them.
**Test:** pure tests for the catalog, equip rules and purchases (`tests/CosmeticCatalog.test.luau`). In Studio with
real products: buy once, receive once, rejoin and keep it; confirm a retried receipt does not grant twice.
**Done when:** nothing in the shop changes power, points, ranks, units, boxes or capture speed.

## 13. Polish: tutorial, effects, sounds, mobile

**Build:** a short tutorial, gentle effects and sounds from catalogs, and mobile-friendly controls and UI.
**Test:** Studio on phone, tablet and desktop sizes; no flashing; mute works.
**Done when:** a new player can capture a zone within two minutes without help.

## 14. Launch prep

**Build:** the launch pack and checks.
**Test:** run the launch scan and tick every item in `docs/compliance.md`.
**Done when:** the owner has answered the maturity questionnaire themselves and read the current Roblox rules.

## 15. Training Arena

**Build (code written, not yet playtested):** a row of treadmill belts on Training Island (slice 23; before that, one by each base). Walking on it earns strides
once a second (server counted, 10 minutes a day); strides fill 20 training levels; each level raises aura power.
Aura power now comes from training, not rank. A small panel shows level, progress and time left today.
**Test:** pure tests for level costs, the daily cap and the top level (`tests/TrainingRules.test.luau`). In Studio:
stand on the belt and walk against it, watch the bar fill and the level rise, stop and watch it stop, check a
capture is faster at a higher level, and check the daily time runs out.
**Done when:** only moving on a belt counts, the cap holds, and the capture speed matches the aura level.

## 16. Training stations by rank (planned, Update 1, not built)

The plan comes from `DESIGN.md`. Each rank unlocks a station with its own mini-game; older stations keep working
but give less aura; unlocking is by rank only, never Robux (cosmetic station skins can be sold).

| Rank | Station | Mini-game | Needs from earlier systems |
|---|---|---|---|
| Rookie | Treadmill | Tap to run | The built treadmill uses walking against a belt; change it to tapping |
| Sigma | Sigma Walk Runway | Rhythm poses, others can hype | A rhythm checker, a "hype" action other players can send |
| Chadlite | Spot Me Bench | Timing bar; a friend spotting doubles the aura | The friend lookup (`FriendService`) from the squad work |
| Chad | Mewing Meditation | Hold-and-release meter | A hold-and-release input and meter check |
| Gigachad | Stare-Down Dojo | Practise mog-off duels against dummies | `MogOffRules` against a scripted dummy, no real opponent |
| Mog God | Aura Summit | Passive aura on a peak, boosted by other players' emotes | Emote events, strict limits on boosts |

**Settle before building:** how much aura each station gives and how much less older ones give; whether the
daily training cap is shared or per station; whether NPC rank (the start) can train at all (the plan says
Rookie unlocks the treadmill, the built treadmill works for everyone); how an emote or hype boost is limited so
extra accounts cannot farm it; how a friend spot is checked on the server. All timing and meters are judged on
the server.
**Done when:** each station is rank-gated on the server, older stations give less, and no Robux path unlocks one.

## 17. Battle pass, cosmetic only (planned, not built)

The owner says a battle pass is mandatory at some point. It is the "cosmetic season pass" already on the money list in
`DESIGN.md`, so it follows design rule 1: **cosmetic rewards only** (trails, auras, titles, banners, emotes,
station skins), never points, boxes, units, aura, training speed or anything that wins wars. Ideas to settle:
a free track and a paid track; progress from season points (slice 18) or wars played; every reward shown before
purchase; no countdown pressure; Roblox's current rules read first. Build after the cosmetic shop is tested with
real purchases.

## 18. Seasons, friends and the squad bonus

**Build (code written, not yet playtested):**
- **Friends:** `FriendService` caches which players are Roblox friends. A joining player is placed on a friend's
  faction when that keeps the teams within a couple of players (`FactionRules.pickFaction`); otherwise on the
  smallest faction. Characters now load only after the faction is chosen (the faction system also handles respawns).
- **Squad bonus:** when a zone is captured, each paid player gets +10 percent of their points per friend (same
  faction, also paid for that capture), up to +30 percent (`SquadRules`). It is extra, never taken from anyone.
- **Weekly season:** one UTC week, Monday to Sunday. Players earn season points for their faction from captures
  (per zone value), war wins and mog-off wins (`SeasonRules`). Servers add their points to shared faction
  totals (`SeasonStore`, MemoryStore outside Studio). The winning faction's members who earned enough points get
  the cosmetic "Season Champion" title once. A panel shows factions' scores, time left and your points.
**Test:** pure tests (`tests/SquadSeasonRules.test.luau`, faction preference in `tests/FactionRules.test.luau`). In
Studio: two accounts that are Roblox friends join and land on the same faction; capture together and see the
extra points; check the season panel counts points. Live (needs a published scratch place): two servers add to
the same totals; change the clock or wait for a Monday to see the champion title.
**Done when:** friends land together without unbalancing teams, the squad bonus never exceeds the cap, season
points are counted once, and the champion title is granted once.

## 19. Number pop-ups and big numbers (planned, not built)

From `DESIGN.md`: a floating number on every tap, zone capture, shove that pushes someone out of a zone, mog-off win,
training tap, box opening and rank-up; bigger events get bigger numbers. Size and colour tiers (white, gold, purple),
occasional CRITs (2 to 5 times), combo multipliers for chains, short suffixes (K, M, B, T, Qa) and exponential growth.
**Settle before building:** see `docs/economy.md`, "Big numbers plan". The server decides every amount, CRIT and combo;
the client only shows what the server sent.
**Test:** pure tests for the number formatter (including the 999.95K rollover), the tier colours, CRIT odds and the combo
rules. In Studio: pop-ups stay readable on a phone, never more than a set number on screen, no flashing.
**Done when:** every shown number matches what the server really granted.

## 20. Prestige and the skill tree (planned, Update 2, not built)

- **Altar:** unlocks at Mog God, optional. A confirm screen lists what resets (rank, Mog Points, aura, station unlocks) and what
  is kept (cosmetics, Legacy Points, faction, friends, streak, arena). A server-wide "ascended" message. Each prestige multiplies
  gains.
- **Legacy Points:** 3 per prestige, never sold.
- **Skill tree:** 3 branches of 3 tiers, bought with Legacy Points.
  - **Grind:** Mog Point bonus (+5 percent per level, at most 25 percent); bigger offline arena earnings (takes effect once the
    arena exists in Update 2); capped box luck.
  - **Tactics:** one of two per tier. Faster respawn or longer shove; rally banner or scout; mog-off combo or dash. All combat
    advantage together is capped at about 10 percent.
  - **Swagger:** prestige aura colours, titles and emotes; a legend statue in the hub.
- **Free respec** once a week.
- **Factions auto-balance by prestige level** as well as player count.
- **Mentor bonus:** for helping low-rank teammates capture. Only for real friends, or teammates who have been in the server at
  least 10 minutes, with a daily cap.
**Decided:** a skill costs 1, 2 or 3 Legacy Points by tier; box luck is at most +10 percent chance for better outcomes, with boosted
odds shown on the opening screen; rally banner = small push boost for teammates near it, scout = enemy counts in zones, mog-off
combo = bigger knockback after two wins in a row, dash = short sprint on a cooldown; factions balance by counting each player as
1 plus 0.25 per prestige level, at most 2.5.
**Test:** pure tests for what resets and what is kept, the skill caps (Mog Point bonus 25 percent, combat 10 percent), respec
once a week, the balance rule, and that a prestige is all or nothing.
**Done when:** the reset is atomic on the server, the confirm screen matches what really happens, the caps hold, and nothing
about prestige or the tree can be bought with Robux.

## 21. Mog Arena tycoon (planned, Update 3, not built)

From `DESIGN.md`:
- A plot for each player in the training area. Rank unlocks station types; stations are bought, upgraded and placed with Mog
  Points. Prestige unlocks themes (P1 Neon Gym, P3 Volcano Dojo, P5 Space Summit, prestige-only) and special builds (throne,
  trophy wall, statue spot).
- Recruits train while the owner is offline (this replaces barracks). Recruits are earned from boxes, the daily streak and
  rank-ups, never sold; each trains at one station.
- Friends can train at your arena for a small owner bonus that builds up while the owner is away, capped like barracks.
- Weekly "Best Arena" vote: one vote per player per week, only from players who visited that arena, fixed categories, a
  cosmetic prize.
- The arena is kept through prestige. Extra theme variants and decor can be sold; stations cannot.
**Settle before building:** how recruits pay out and the cap, how placement and part counts are limited on the server and
saved, and how friends visit.
**Done when:** a plot saves and reloads, every placement is validated on the server, stations can only be unlocked by rank and
bought with Mog Points, and no station is for sale.

## 22. Launch switches and gradual reveal (built)

**Build (code written, not yet playtested):**
- `src/shared/Features.luau` holds the launch switches. On: war, ranks, boxes, units, treadmill, daily streak, cosmetic shop. Off:
  seasons, squad bonus, friend placement, barracks (and the unbuilt training stations, prestige and arena). A flag set to `false`
  stops that system from doing anything on the server and hides its screen on the client.
- `src/shared/RevealRules.luau` and `RevealController`: a brand-new player sees only the zone bar ("stand in the zone, watch the
  bar fill"). After the first capture the points counter and war timer appear; after the first finished war, shove, ranks and
  training; after two wars, boxes and units; after three wars, the daily box and the shop. The server counts captures and wars in
  the save and mirrors a stage to the player. Players who already ranked up see everything.
- `TutorialHint` shows "Run to a glowing zone and stand in it!" with an arrow to the nearest zone until the first capture; zones glow.
**Test:** pure tests in `tests/RevealRules.test.luau` and `tests/HintRules.test.luau`. In Studio: join as a new player and check only the zone bar shows; capture a
zone and watch the points counter appear; finish wars and watch the rest appear; flip a flag in `Features.luau` and check it
turns that feature on or off.
**Done when:** a new player is never shown more than the stage allows, and a switched-off feature does nothing.

## 23. Two islands: War Island and Training Island (built)

**Build (code written, not yet playtested):**
- One place, two platforms. **War Island** (the baseplate) has the bases, the nine zones and a TRAIN portal by each base. **Training
  Island** (700 studs east) has all the treadmills in one row, the shop kiosk, a BACK TO WAR portal, and empty reserved space for the
  prestige altar (Update 2) and the Mog Arena plots (Update 3). The old treadmills by the bases are gone.
- `TravelSystem`: walking into a portal, or the big HUD button (`TravelHud`: TRAIN on War Island, BACK TO WAR on Training Island), moves
  you. Everyone still spawns on War Island. Back to war lands you on your faction's front line (home base between wars).
- Rules (`IslandRules.canTravel`): known destination, not already there, not during a mog-off, not right after being shoved or losing a
  duel, and a 3 second cooldown. A new war does not pull players out of Training Island.
- The shop button only shows on Training Island. The TRAIN button joins the gradual reveal (after the first finished war). New screens use
  a chunky rounded style from `src/client/Lib/UiTheme.luau`.
**Test:** pure tests in `tests/IslandRules.test.luau` and `tests/MapLayout.test.luau`. In Studio: see `docs/PLAYTEST.md`.
**Done when:** you can go to Training Island and back instantly, training only counts on the treadmills there, the shop only opens
there, and nothing in the war can be reached from Training Island.
