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

**Build (code written, not yet playtested):** five zones (four side, one centre worth double), per-faction presence, teammates stacking, enemies pushing back, per-zone progress sent
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

**Build:** a Robux shop for cosmetics only (trails, aura colours, name styles), with real ids once created.
**Test:** in Studio with real products: buy once, receive once, rejoin and keep it.
**Done when:** nothing in the shop changes power, points, ranks, units, boxes or capture speed.

## 13. Polish: tutorial, effects, sounds, mobile

**Build:** a short tutorial, gentle effects and sounds from catalogs, and mobile-friendly controls and UI.
**Test:** Studio on phone, tablet and desktop sizes; no flashing; mute works.
**Done when:** a new player can capture a zone within two minutes without help.

## 14. Launch prep

**Build:** the launch pack and checks.
**Test:** run the launch scan and tick every item in `docs/compliance.md`.
**Done when:** the owner has answered the maturity questionnaire themselves and read the current Roblox rules.
