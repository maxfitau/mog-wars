# Mog Wars economy

All numbers live in `src/shared/EconomyConfig.luau`. This file explains why. To re-check pacing after any
change, run `python3 tools/pacing.py --ranks` (it reads the config file directly).

> Matches `DESIGN.md`: seven ranks (NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God) and Gold, Diamond and
> Ultra boxes earned on captures by territory value. If `DESIGN.md` changes, it wins.

## Principles

1. **One currency, Mog Points.** Earned only by playing. Robux never buys points, ranks, boxes, units or
   capture speed. (Never pay-to-win.)
2. **Ranks are a sink.** Points are spent to rank up, so they do not pile up unused.
3. **Skill and presence matter more than rank.** Rank is status. Aura power comes from training in the
   Training Arena (up to 1.9x), so a new player in a team still matters. Mog-offs ignore aura and rank
   completely.
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

One player with aura power 1 (an untrained player) captures an empty zone alone in 24 seconds. Teammates stack, so four players do it
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
weeks and mean something). Ranks measure aura earned by winning, never looks. Rank does not change aura power.

## Squad bonus

Capturing a zone with friends on your faction adds 10 percent of your own points per friend who was also paid for
that capture, at most 30 percent. It is extra points on top of the pool, never taken from other players, and it
only applies to friends (not strangers), so playing with friends is rewarded without making solo play weak. The
pacing simulation assumes no squad, so a player who always plays with three friends earns up to about 30 percent
more from captures and ranks a little faster.

## Training Arena

A treadmill belt sits just outside each home base. The belt pushes you backward, so you walk against it. Each
second you are alive, on a belt and moving earns one stride. Strides fill training levels and each level adds
4.5 percent aura power (1.9x at level 20). Level 1 takes 45 seconds, and each level after needs 60 more
seconds than the one before, so all 20 levels take 12,300 strides, about 3.4 hours. Only 10 minutes a day
count (healthy play), so a full set of levels takes about three weeks. Training costs nothing, can never be
bought, and keeps you away from the front line while you do it, which is the trade-off. Seconds are counted by
the server.

## Boxes

Earned only, never sold, no pity timer, no luck boosts. Each tier's chances add up to exactly 100 and the
opening screen shows them. Expected value in points: Gold 34.4, Diamond 119.5, Ultra 269.5. Units and
cosmetics are the exciting drops; a cosmetic you already own pays 50 points instead. The tier comes from the
zone's value, so fighting for the centre is worth more.

## Pacing simulation

`tools/pacing.py` assumes: a capture share per player type that grows a little with training level (10 minutes
a day for most players, 5 for light ones), win rate, one box per capture (capped at 12 a day)
at the average zone's box value (the zone values come from `src/shared/MapLayout.luau`), the daily box and barracks, and half point rewards after 8 wars. Results from
the current config:

| Player | Wars/day | Days/week | Days to Chad | Days to Mog God |
|---|---|---|---|---|
| Light | 2 | 4 | 18 | 120 |
| **Casual** | **3** | **6** | **6** | **45** |
| Regular | 5 | 7 | 4 | 24 |
| Hardcore | 12 | 7 | 2 | 13 |

Target met: a casual player reaches Chad in about a week (day 6) and Mog God in about six and a half weeks (day 45),
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

## Big numbers plan (planned, not built)

`DESIGN.md` plans floating numbers such as +12, +1.2K and +4.7M, exponential growth and a multiplier for every prestige.
The current economy is much smaller (a rank costs at most 24,000 points), so these need new numbers. Method, from the
simulator-economy skill: choose the numbers with a pacing table first, then build.

| Topic | Plan |
|---|---|
| Growth of prices | `cost = floor(baseCost * costGrowth ^ owned)`. Use about 1.07 to 1.15 for things bought many times; about 1.5 to 3 for rare big ones (arena stations, prestige) |
| Prestige gains | Gains multiplied by `q ^ k` after `k` prestiges (multiplicative, so numbers grow exponentially) |
| Prestige cost growth | Costs after prestige scaled by `g ^ k`. Each prestige climb takes about `g / q` times as long as the last. Aim for `g / q` between 1.0 and 1.25 (for example `q = 2`, `g = 2` to `2.5`), so the start of every climb feels fast and the whole climb stays bounded |
| Offline and recruits | Efficiency 0.25 to 0.5 and an 8 to 12 hour cap, as barracks already does (8 hours) |
| Number format | Round first, then pick the suffix, so 999,950 shows "1.0M" and never "1000.0K". Suffixes K, M, B, T, Qa now; more later. The client formats for display only and never reads text back |
| Precision | Luau numbers are exact only up to about 9e15. Before any balance can pass about 1e15, store large values as a mantissa and exponent (or a base 10 log). Prestige will get there, so build this into slice 19, not later |
| CRITs and combos | Server-rolled; crit chance about 5 percent for 2 to 5 times; combo multiplier rises per chained action inside a short window and is capped. Not purchasable, so no paid random item. Amounts are always whole numbers decided by the server |
| Display scale | Today a capture pays tens to a few hundred points. To show "+1.2K" early, either scale every amount by one global factor, or let prestige multipliers grow them. Decide when building; either way the pacing table is run again |

Tools: run the simulator skill's pacing calculator (`lune run scripts/balance.luau`, needs the free Lune tool) on the new config
before building, and copy its tested number maths into the game rather than rewriting it.
