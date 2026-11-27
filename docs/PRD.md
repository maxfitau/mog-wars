# Mog Wars: product brief

> Written before `DESIGN.md` was available, from the owner's defaults. `DESIGN.md` is now in the repo root and
> **wins where they disagree**, including its 5 design rules and theme guardrails. The differences are listed
> in `docs/design-reconciliation.md`.

## One line

A fast faction war: four factions fight for territory in short wars, standing in zones to capture them,
shoving rivals, winning tapping duels called mog-offs, and spending the Mog Points they earn on ranks.

## Who it is for and how a session feels

- Roblox players who like quick team objectives. Assume a wide age range, including under 13, so every
  choice is made to be safe for children.
- A war lasts about 10 minutes. A casual player plays two or three wars, then leaves. Progress is visible
  after every war (points, a box, a step toward the next rank).
- A server holds about 16 players split across 4 factions (auto-balanced).

## Core loop

1. Spawn at your faction's home base and pick a target zone.
2. Run to the zone and stand in it. Your aura power fills the zone's capture bar. Teammates stack. Enemies push
   it back. Use shove (cooldown) to clear a rival. If two enemies meet in a zone, a 5-second mog-off decides who
   is knocked back.
3. When a zone is captured, everyone who contributed earns Mog Points in proportion to their contribution.
4. When the war ends, the faction with the highest zone-control score wins a bonus. Every paid contributor on a capture also earns a box (Gold for
   a side zone, Diamond for the centre).
5. Spend Mog Points to rank up. Open boxes for points, units, and cosmetics. Come back tomorrow for the
   streak reward, and collect barracks income earned while away.

## Systems

| System | What it does | Rules that matter |
|---|---|---|
| Factions | Four placeholder factions: Jawline Legion, Mewing Order, Sigma Syndicate, Aura Cartel (names may change, see `docs/compliance.md`) | Server assigns and balances; a joining player is placed with a friend when that keeps teams within a couple of players; a player cannot switch mid-war |
| Map | Two islands in one place. War Island: four home bases (safe, cannot be captured), nine contested zones (eight worth 1, the centre worth double) and a portal by each base. Training Island: the treadmills and the shop, with room for the prestige altar and Mog Arena plots. Layout is data in `src/shared/MapLayout.luau` | Zones are tagged parts; the server finds them by tag |
| Capture bar | Per zone; stronger faction presence pushes progress; enemies push it back | Pure math in `src/shared`, server runs it every tick (`docs/economy.md` has the numbers) |
| Aura power | Each player's push strength in the capture bar, raised by training in the Training Arena | Capped at about 1.9x; 10 minutes of training count per day; never for sale |
| Shove | Short cooldown ability: knocks a rival back and briefly weakens their push | Server validates range and cooldown |
| Mog-off | When two enemies stay close in a zone, a 5-second tapping duel starts; more taps wins; loser is knocked back and stunned briefly; ties go to the defender | Taps are counted on the server, capped per second, and ranks give no advantage |
| Units | Tank: speeds capture in its zone. Horse: speeds movement. Each lasts one war. | Earned from boxes, sellable for Mog Points, never sold for Robux |
| Bots | A war with fewer than 8 fighters is filled with bots, balanced across factions and removed one at a time as players join. They tap at human-like speeds that depend on the player's rank, wear a "BOT" tag and are never ranked or counted | Not Players; beating a bot pays 40 percent |
| Mog Points | The one currency. Earned from captures by contribution, boxes, streaks, barracks; spent on rank-ups | Granted by the server only |
| Ranks | Seven ranks: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God | Cost curve in `docs/economy.md` |
| Boxes | Earned on captures by territory value (Gold, Diamond, Ultra) and from the daily streak, never bought. Published odds | Odds shown to players, no pity or boosts |
| Squad bonus | Capturing with friends on your faction gives each of you a little extra | +10 percent per friend, at most +30 percent, never taken from others |
| Weekly season | Factions compete for a week; members of the winning faction who took part earn a cosmetic title | Standings show factions only; no power rewards |
| Daily box | A 7-day streak, one box a day | Server clock, UTC day |
| Barracks | Offline income that fills while away, up to a cap, collected on return | Server clock, capped, tiny next to active play |

## What the server owns (everything that matters)

Zone state and capture progress, who is standing where, shove and mog-off outcomes, Mog Points, ranks, box
rolls, unit use and sale, streaks, and barracks income. The client sends requests (move, shove, tap, open
box, rank up) and displays results. Every request is rate limited, validated, and checked against the
player's own data first.

## Monetization

Cosmetics and convenience only (trails, aura colours, name styles, extra cosmetic slots). Robux never buys
power, points, ranks, units, boxes, capture speed, or anything that changes who wins. See `docs/compliance.md`.

## Not in version 1

Trading, free-text chat from the game, player-made content, clans beyond the four factions, ranked seasons,
voice, and any paid random item.

## How we know it works

- A player can capture a zone alone, with teammates faster, and against enemies slower. The numbers match
  `docs/economy.md`.
- No client message can change points, ranks, captures, or box results (checked by tests and Studio playtest).
- A casual player reaches Chad in about a week and Mog God in one to two months (pacing in `docs/economy.md`).
- Every box tier's odds sum to 100 percent and match what the server rolls.

## Open items for the owner

See `docs/morning-notes.md`.
