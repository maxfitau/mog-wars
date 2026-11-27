# Mog Wars economy

All numbers live in `src/shared/EconomyConfig.luau`. This file explains why. To re-check pacing after any
change, run `python3 tools/pacing.py --ranks` (it reads the config file directly).

> Written without `DESIGN.md`. If it sets different pacing or currency rules, `DESIGN.md` wins.

## Principles

1. **One currency, Mog Points.** Earned only by playing. Robux never buys points, ranks, boxes, units or
   capture speed. (Never pay-to-win.)
2. **Ranks are a sink.** Points are spent to rank up, so they do not pile up unused.
3. **Skill and presence matter more than rank.** Rank gives about +10 percent aura per step (Mog God is 1.9x a
   Rookie), so a new player in a team still matters. Mog-offs ignore rank completely.
4. **Healthy pacing for children.** Full rewards for the first 8 wars a day, half after that. Offline income is
   capped at 8 hours and is small, so there is no reward for grinding or for never leaving.

## Sources and sinks

| Source | Amount |
|---|---|
| Zone capture | Pool of 100 points per zone value (side zone 1, centre zone 2), split by contribution |
| War bonus | 60 for the winning faction, 20 for anyone who contributed at least 5 units |
| Rank-up box | A box on each rank-up (tier rises with rank) |
| War box | One box per war for every contributor: Veteran for the winning faction, Recruit for the rest (max 12 a day) |
| Daily streak | 30, 40, 50, 60, 80, 100, 150 (7-day cycle, then repeats) |
| Barracks | 6 per hour plus 2 per rank, filling up to 8 hours |
| Selling units | Tank 150, horse 100 |

Sinks: rank-up costs (the only big sink). Cosmetics are bought with Robux or are box drops, never with points.

## Capture and contribution

One player with aura power 1 captures an empty zone alone in 24 seconds. Teammates stack, so four players do it
in about 6. A zone pays a pool of `100 x zone value`, split by each player's share of contribution. A player
needs at least 3 contribution units to be paid at all (stops standing at the edge for a free ride) and a paid
player receives at least 5 points. Shoves that help (1.5 units) and mog-off wins (3 units) count as
contribution, so fighting is paid like capturing. The split never exceeds the pool (tested).

## Ranks

| # | Rank | Cost | Total | Box on reaching it |
|---|---|---|---|---|
| 1 | Rookie | 0 | 0 | none |
| 2 | Grunt | 250 | 250 | Recruit |
| 3 | Fighter | 400 | 650 | Recruit |
| 4 | Veteran | 600 | 1,250 | Veteran |
| 5 | Captain | 850 | 2,100 | Veteran |
| 6 | Warlord | 1,100 | 3,200 | Elite |
| 7 | Chad | 1,400 | 4,600 | Elite |
| 8 | Alpha | 3,500 | 8,100 | Elite |
| 9 | Titan | 8,000 | 16,100 | Legend |
| 10 | Mog God | 16,000 | 32,100 | Legend |

The ladder is gentle up to Chad (so the first week is fun and fast) then steep (so the last ranks take weeks and
mean something).

## Boxes

Earned only, never sold, no pity timer, no luck boosts. Each tier's chances add up to exactly 100 and the
opening screen shows them. Expected value in points: Recruit 42.5, Veteran 102.5, Elite 221, Legend 510. Units
and cosmetics are the exciting drops; the tiers keep early boxes modest and late boxes meaningful. A daily box
cap (12) stops farming.

## Pacing simulation

`tools/pacing.py` assumes: a war pays about 100 points of capture share for an active player plus bonuses, win
rate by player type, the daily streak and barracks, a half-rate after 8 wars, and the box expected value on each
rank-up. Results from the current config:

| Player | Wars/day | Days/week | Days to Chad | Days to Mog God |
|---|---|---|---|---|
| Light | 2 | 4 | 16 | 104 |
| **Casual** | **3** | **6** | **6** | **44** |
| Regular | 5 | 7 | 4 | 21 |
| Hardcore | 12 | 7 | 2 | 9 |

Target met: a casual player reaches Chad in about a week (day 6) and Mog God in about six and a half weeks (day
44), inside the one to two month goal. A light player takes about three months, a deliberate choice: they still
progress every session, and no tier is gated by money.

## Risks and what to tune first

- **Hardcore speed.** 9 days to Mog God is fast. If real data shows this, raise Titan and Mog God costs rather
  than cutting rewards.
- **Capture pool vs players.** The pool is fixed, so full servers pay each player less; the sim assumes an
  average share. Watch real averages in the first playtests.
- **Everything here is untested with real players.** Treat it as the first draft to adjust from analytics.
