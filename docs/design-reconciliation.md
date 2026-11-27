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
| 7 | Weekly faction season, join a friend's faction, squad capture bonus, weekly events | Built: season, friend placement and squad bonus (slice 18; decisions 64 to 69). Weekly events are not built | Weekly events (timed special wars) later | Large |
| 8 | Money list: gifting, private servers, cosmetic season pass | Shop built for trails, auras and titles (decisions 58 to 61); gifting, season pass, banners, emotes, skins and box animations not built | Check Roblox rules on gifting before building it (see compliance section 9) | Check first |
| 10 | Training Arena section: a station per rank (Treadmill, Sigma Walk Runway, Spot Me Bench, Mewing Meditation, Stare-Down Dojo, Aura Summit), older ones give less aura, rank-only unlock | Only the treadmill exists, and it is walk-against-the-belt for every rank; rank does not unlock anything yet | Planned as slice 16 in `docs/slices.md`. Not built yet, as asked | Large |
| 11 | Battle pass is mandatory at some point (the owner's note); `DESIGN.md` lists a cosmetic season pass | Not built | Planned as slice 17, cosmetic only | Large |
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
