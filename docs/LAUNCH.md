# Mog Wars launch pack

Written with the roblox-launch skill's template and checklists. **Nothing has been tested in Studio yet**, so no feature may
be advertised yet. Titles, icon and thumbnail briefs, and the description draft are in `docs/store-page.md`. Roblox facts here
come from the skill's checklist, last confirmed 2026-11-26. Read the linked Roblox pages again before launch; none of this
guarantees approval, a rating, visibility or revenue.

## Truthful feature list

"Built" means the code is written. "Tested" is only yes after a real Studio playtest. Only rows that are both yes may be advertised.

| Feature | At launch | Built | Tested in Studio | Shown to players | May advertise |
|---|---|---|---|---|---|
| Capture zones by standing in them (9 zones, centre worth double) | on | yes | no | yes | no |
| Four factions, auto-balanced, with bases and team outlines | on | yes | no | yes | no |
| Front-line spawning in a running war | on | yes | no | yes | no |
| War rounds (12 minutes) with winner and bonus | on | yes | no | yes | no |
| Shove with cooldown | on | yes | no | yes | no |
| Mog-offs (5 second tapping duel) | on | yes | no | yes | no |
| Mog Points and saving | on | yes (Studio stand-in only) | no | yes | no (real saving not set up) |
| Ranks NPC to Mog God | on | yes | no | yes | no |
| Boxes (Gold, Diamond, Ultra) with odds shown | on | yes | no | yes | no |
| Units: tank and horse, deploy and sell | on | yes | no | yes | no |
| Training Island with four treadmills raising aura power | on | yes | no | yes | no |
| Portals and TRAIN / BACK TO WAR buttons between War Island and Training Island | on | yes | no | yes | no |
| Daily box with a 7-day streak | on | yes | no | yes | no |
| Cosmetic shop on Training Island (trails, auras, titles) | on | yes | no | yes | no (no products created yet) |
| First-session hint and gradual screens | on | yes | no | yes | no |
| Seasons, squad bonus, friend placement | off | yes | no | no | no (not at launch) |
| Barracks offline income | off | yes | no | no | no (not at launch) |
| Per-rank training stations, prestige, Mog Arena, battle pass, number pop-ups | not built | no | no | no | no |

## Checklist status

done = with evidence, blocked = what is in the way, unknown = nobody checked, user task = only the owner can do it.

| Area | Item | Status |
|---|---|---|
| Rules | Nothing sold gives power (design rule 1) | done by design: shop items are cosmetic only and a test fails if an item gains a gameplay field (`tests/CosmeticCatalog.test.luau`, unrun) |
| Paid random items | Boxes are never sold; no path from Robux to boxes, points or units | done by design; verify in the playtest. No luck boosts at launch; odds are shown for every tier |
| Paid random items | Shop cosmetics never drop from boxes, box cosmetics are never sold | done by design (tested in `CosmeticCatalog.test.luau`, unrun) |
| Monetisation | Every product has a real id | user task: create a developer product per shop item, paste ids into `CosmeticCatalog.luau` (Build Queue item) |
| Monetisation | A purchase only starts from a tap; no pressure tactics | done by design in `ShopHud`; verify in Studio |
| Monetisation | Receipts apply once; real purchase tested | unknown: needs real products and a Studio test |
| Technical | Real ProfileStore vendored; rejoin keeps progress | blocked: the stand-in only works in Studio and refuses to run outside it; vendor the real module (docs/DATA.md in the framework repo), then test a rejoin in a scratch place |
| Technical | Purchase save gap | unknown: check the real module for an immediate-save call and use it after a purchase |
| Technical | Every file in `tests/` run and passing; StyLua and Selene clean | unknown: never run; being run on the Mac |
| Technical | Studio playtest on phone, tablet and desktop sizes | user task |
| Technical | Avatar type R15 in Game Settings | user task |
| Technical | A server with many players, performance | unknown |
| Technical | Soft launch to friends and a parent or guardian for young testers first | user task |
| Kids and social | First session simple, no free-text input, no trading, no wagering | done by design: gradual screens, fixed titles only, no trading |
| Kids and social | No flashing effects, gentle audio, a mute option | unknown: no sounds exist yet, effects are gentle; check in the playtest |
| Originality | Names (game, factions, items) original; assets licensed | unknown: search Roblox for clashes; there are no imported assets yet, only parts |
| Originality | "Aura Collective" faction name | owner decision (design says "Aura Cartel"; see `docs/compliance.md`) |
| Theme | No "Risk", no incel or blackpill language, no ranking of real looks | done in docs and code (grep is clean); recheck before launch |
| Store page | Icon square and at least 512 by 512; thumbnails 16:9 (1920 by 1080); own or licensed art | user task: briefs are in `docs/store-page.md` |
| Maturity | Questionnaire answered by the owner for the final build | user task: use the roblox-launch skill's `maturity-worksheet.md` for the facts; never choose answers to reach a label |
| Final | The description is true of the shipped game; owner read the linked Roblox pages | user task |

## Capture plan (Studio screenshots for your own thumbnails)

1. A wide shot of a side zone mid-capture with two teammates in the ring and the bar half full (camera behind them, UI visible).
2. A mog-off with the "5" countdown panel and the two players facing each other (UI visible, 16:9).
3. The four coloured bases from above, with the glowing centre zone (camera high, UI hidden).
3b. Training Island: the row of treadmills with the "Training Area" sign (UI visible).
4. A box opening with the odds list visible (UI visible).
Export each at 16:9 (1920 by 1080).

## Update notes

Version 1.0: what is really in the game today, from the feature list above once tested. Weekly updates turn on seasons and the squad
bonus (switches in `src/shared/Features.luau`); then per-rank training stations, prestige and the Mog Arena (see `DESIGN.md`).
Never publish update news before it is true.
