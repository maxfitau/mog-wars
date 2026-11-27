# DESIGN.md versus what is built

`DESIGN.md` is now in the repo root and it wins. Everything in slices 1 to 11 was written before it was
available, from the owner's defaults. This file lists every difference, what I recommend, and how big the
change is. Sections A and rows 1 to 5 of B (ranks, boxes, the Training Arena, spawning and map size) have been applied. The rest waits for your yes.

## A. Fixed already

| Item | What I did |
|---|---|
| Guardrail: no "Risk" anywhere | Removed the word from all project docs (now "concern" or "problem") |
| Guardrail: no incel language | Removed the one place a doc named an example of it |
| Daily reward | Was points. Now a **daily box** on a 7-day streak, as the brief says (decision 45) |
| Ranks | Now the brief's 7 ranks: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God (decision 49) |
| Boxes | Now Gold, Diamond and Ultra, earned on captures by territory value; rank-up and war boxes removed (decision 50) |

## B. Differences that change the design (need your yes)

| # | DESIGN.md says | Built now | Recommendation | Size |
|---|---|---|---|---|
| 1 | ~~7 ranks~~ | **Done** | | |
| 2 | ~~Boxes from captures: Gold, Diamond, Ultra~~ | **Done** | | |
| 3 | ~~Aura power raised by training in a Training Arena~~ | **Done** (decisions 54 to 57) | | |
| 4 | ~~Join mid-round, front-line spawn, 10 to 15 minute rounds~~ | **Done** | | |
| 5 | ~~8 to 12 territories~~ | **Done** (9 zones) | | |
| 6 | Faction 4 is "Aura Cartel" | Renamed "Aura Collective" (the word "cartel" suggests drug crime, see compliance) | Your call. One line in `src/shared/FactionRules.luau` | Tiny |
| 7 | Weekly faction season, join a friend's faction, squad capture bonus, weekly events | Not built | Add after the build order is done (new slices) | Large |
| 8 | Money list includes **gifting** and **private servers** | PRD lists trading as out of scope; shop not built | Check Roblox's current rules on gifting and on unfair gifting between players before building it. Private servers are a Roblox feature to switch on | Check first |
| 9 | Build order puts the Training Arena before streak, barracks and the shop | Streak and barracks are built first | Fine to leave, but build the arena next | None |

## C. Already matches

- Not pay-to-win; boxes are earned only and never sold.
- Mog Points from captures by contribution; saving; ranks bought with points.
- Shove with a cooldown; 5-second mog-off with a knocked-back loser (taps only, rate capped).
- Tank (faster capture in its zone) and horse (faster movement), one war of use, sellable.
- Server decides everything that matters.
- Barracks earn points offline; 7-day daily streak.
- Four factions auto-balanced, jawline and meme theme with positive-only wording.

## Suggested order if you say yes to everything

1. ~~Ranks (B1) and boxes (B2)~~ done.
2. ~~Spawn and map size (B4, B5)~~ done.
3. ~~Training Arena (B3)~~ done.
4. Cosmetic shop (slice 12), after checking gifting (B8).
5. Seasons, friends and weekly events (B7).
