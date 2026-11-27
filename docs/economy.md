# Mog Wars economy

All numbers live in `src/shared/EconomyConfig.luau`. This file explains why. To re-check pacing after any
change, run `python3 tools/pacing.py --ranks` (it reads the config file directly).

> Matches `DESIGN.md`: seven ranks (NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God) and Gold, Diamond and
> Ultra boxes earned on captures by territory value. If `DESIGN.md` changes, it wins.

## Principles

1. **One currency, Mog Points.** Earned only by playing. Robux never buys points, ranks, boxes, units or
   capture speed. (Never pay-to-win.)
2. **Ranks are a sink.** Points are spent to rank up, so they do not pile up unused.
3. **Skill and presence matter more than rank.** Rank gives +15 percent aura per step (Mog God is 1.9x an NPC),
   so a new player in a team still matters. Mog-offs ignore rank completely. (The Training Arena in
   `DESIGN.md` will later become the main way to raise aura power.)
4. **Healthy pacing for children.** Full point rewards for the first 8 wars a day, half after that. Boxes are
   capped at 12 a day. Offline income is capped at 8 hours and is small, so there is no reward for grinding or
   for never leaving.

## Sources and sinks

| Source | Amount |
|---|---|
| Zone capture | Pool of 100 points per zone value (eight zones worth 1, the centre worth 2), split by contribution |
| Capture box | Every paid contributor also earns one box: Gold for a side zone, Diamond for the centre zone, Ultra for a zone worth 3 or more (none yet). Max 12 a day |
| War bonus | 60 for the winning faction, 20 for anyone who contributed at least 5 units |
| Daily box (7-day streak) | Gold on days 1 to 3, Diamond on days 4 to 6, Ultra on day 7, then the cycle repeats. Skipping a day restarts at day 1 |
| Barracks | 6 per hour plus 2 per rank, filling up to 8 hours |
| Selling units | Tank 150, horse 100 |

Sinks: rank-up costs (the only big sink). Cosmetics are bought with Robux or are box drops, never with points.
There are no rank-up boxes and no war-participation boxes.

## Capture and contribution

One player with aura power 1 captures an empty zone alone in 24 seconds. Teammates stack, so four players do it
in about 6. A zone pays a pool of `100 x zone value`, split by each player's share of contribution. A player
needs at least 3 contribution units to be paid at all (stops standing at the edge for a free ride) and a paid
player receives at least 5 points. Shoves that help (1.5 units) and mog-off wins (3 units) count as
contribution, so fighting is paid like capturing. The split never exceeds the pool (tested). Everyone who is
paid also gets the zone's box.

## Ranks

| # | Rank | Cost | Total |
|---|---|---|---|
| 1 | NPC | 0 | 0 |
| 2 | Rookie | 350 | 350 |
| 3 | Sigma | 800 | 1,150 |
| 4 | Chadlite | 1,500 | 2,650 |
| 5 | Chad | 2,600 | 5,250 |
| 6 | Gigachad | 10,000 | 15,250 |
| 7 | Mog God | 24,000 | 39,250 |

The ladder is gentle up to Chad (so the first week is fun and fast) then steep (so Gigachad and Mog God take
weeks and mean something). Ranks measure aura earned by winning, never looks.

## Boxes

Earned only, never sold, no pity timer, no luck boosts. Each tier's chances add up to exactly 100 and the
opening screen shows them. Expected value in points: Gold 34.4, Diamond 119.5, Ultra 269.5. Units and
cosmetics are the exciting drops; a cosmetic you already own pays 50 points instead. The tier comes from the
zone's value, so fighting for the centre is worth more.

## Pacing simulation

`tools/pacing.py` assumes: a capture share per player type, win rate, one box per capture (capped at 12 a day)
at the average zone's box value (the zone values come from `src/shared/MapLayout.luau`), the daily box and barracks, and half point rewards after 8 wars. Results from
the current config:

| Player | Wars/day | Days/week | Days to Chad | Days to Mog God |
|---|---|---|---|---|
| Light | 2 | 4 | 18 | 123 |
| **Casual** | **3** | **6** | **6** | **47** |
| Regular | 5 | 7 | 4 | 25 |
| Hardcore | 12 | 7 | 2 | 13 |

Target met: a casual player reaches Chad in about a week (day 6) and Mog God in about seven weeks (day 47),
inside the one to two month goal. A light player takes about four months, a deliberate choice: they still
progress every session, and no tier is gated by money.

## Concerns and what to tune first

- **Hardcore speed.** 13 days to Mog God is fast. If real data shows this, raise the Gigachad and Mog God costs
  rather than cutting rewards.
- **Capture pool vs players.** The pool is fixed, so full servers pay each player less; the sim assumes an
  average share. Watch real averages in the first playtests.
- **Box value.** Boxes now carry more of the income than before (one per capture). If they feel too strong,
  lower the Diamond or Ultra point amounts first.
- **Everything here is untested with real players.** Treat it as the first draft to adjust from analytics.
