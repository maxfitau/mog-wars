# Compliance review: theme, ranks, boxes, shop

> Written by Claude before `DESIGN.md` was available (see `docs/design-reconciliation.md`) and without reading Roblox's full pages. This is a concerns
> review, **not legal or policy advice and not a promise of approval, a rating or visibility.** Facts marked
> "confirmed" came from search results of Roblox's own documentation on 2026-11-26 (summaries, not the full
> text). Rules change: before launch, read each linked page in its current form. The maturity questionnaire
> must be answered by you, honestly, for the finished game.

Pages to read: [Community Standards](https://about.roblox.com/community-standards) ·
[Paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items) ·
[IP guidelines](https://create.roblox.com/docs/production/publishing/ip-guidelines) ·
[Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)

## Summary of concerns

| # | Area | Concern | Level | Fix |
|---|---|---|---|---|
| 1 | Theme: "mogging" | The word means out-ranking others on looks. Could read as appearance-based bullying or harassment | **High** | Make the game about aura, confidence and teamwork; never rate real looks; see below |
| 2 | Faction "Aura Cartel" | "Cartel" suggests drug crime | **Medium** | Rename (suggest **Aura Collective**) |
| 3 | Other faction names | Jawline Legion, Mewing Order, Sigma Syndicate echo internet slang, not a brand, but "Sigma" and "Mewing" are trend words that date fast | Low | Keep if wanted; check for existing games and trademarks |
| 4 | Rank names | Must not demean or rank people by appearance | Low (positive-only now) | Keep names positive; never show a "lowest" label as an insult |
| 5 | Boxes | Random rewards. Paid random items need odds shown | Low now, **High if ever sold** | Boxes are earned only (decision 9); show odds anyway; never sell boxes or keys |
| 6 | Indirect paid random | Anything random that costs a currency bought with Robux counts | Medium if a Robux currency is added | Keep Mog Points unbuyable (decision 13) |
| 7 | Shop | Pay-to-win | **High if power is sold** | Cosmetics only; see rules below |
| 8 | Mog-off duels | Competitive tapping with a loser "knocked back" | Low | Keep it cartoonish, no gore, no humiliation text |
| 9 | Chat and names | Player-written text can be abusive about looks | Medium | Use Roblox's filtered chat only; no custom free-text; no player-set titles |
| 10 | Young players | Under-13 audience | Medium | No pressure tactics, no fake timers, daily caps (already in economy) |
| 11 | Store page | Misleading images or claims | Medium | Honest images from real gameplay; see `docs/store-page.md` |

## 1. Theme: "mogging"

The idea is the concern, more than the word. If the game asks players to judge each other's faces, bodies or
avatars, or lets one player be labelled "mogged" (beaten on looks), it can look like appearance-based bullying
and could break harassment rules in the Community Standards. Safer design:

- **Aura means confidence and presence, not looks.** The in-game "power" is a number from rank and teamwork,
  never from anyone's real or avatar appearance.
- **Mog-offs are a silly tapping contest**, won by taps only. No scoring of faces, no "rating" screens, no text
  that mocks the loser. Use gentle messages such as "Nice try!" and a quick rematch option.
- **No real-person likeness**, no real streamers or celebrities, no photos.
- **No jokes about body parts, race, health or age.** Keep the loser's reaction a harmless stumble.
- **Explain "mogging" in game as "out-aura-ing a rival"**, in the tutorial, so the meaning stays about
  competition.
- If after seeing the finished game you are unsure, answer the maturity questionnaire conservatively and consider
  choosing a different title word (see `docs/store-page.md`, which offers titles without the slang).

## 2. Faction and rank names

- Rename **Aura Cartel** (suggest **Aura Collective**, or Aura Clan). Update `docs/decisions.md` if you accept.
- All seven ranks come from the design brief (NPC to Mog God) and measure aura earned by winning. "NPC" is the
  friendly starting rank: never use it as an insult in text or UI. Do not add ranks that put anyone down, and do
  not use appearance words as rank insults.
- Do not use another game's, show's or brand's names. Run the launch scan's brand-word check before publishing.

## 3. Boxes (random rewards)

Confirmed (2026-11-26, Roblox paid random items policy): creators offering paid random items bought with
Robux, directly or through in-game currency, must show every possible outcome with actual numerical odds as
percentages totalling 100; luck boosts and pity systems must be explained and shown; indirect purchases count;
there are extra rules for users the platform marks ineligible. Read the page for the current text.

How Mog Wars stays clear:

- Boxes are **earned only** by ranking up and playing. Nothing sells a box, key, or the points to open one.
- Each tier's odds **sum to 100**, are **shown before opening**, and come from the same table the server rolls
  with (`src/shared/BoxRoll.luau` and `EconomyConfig.luau`, tested).
- No pity timers or luck boosts. A daily box cap exists for healthy play.
- Box drops include units and cosmetics. Units can be sold for Mog Points. Neither can be bought with Robux.

Rules to keep: if you ever sell anything random for Robux, stop and re-read the policy first, show the odds,
and handle ineligible users as the policy says. Do not add a "buy Mog Points with Robux" product unless you
accept that boxes then become indirect paid random items.

## 4. Shop and monetisation plan

**What is built (slice 12):** a cosmetic shop sold as developer products. Items are trails, auras and titles
(fixed words chosen in `src/shared/CosmeticCatalog.luau`, never free text from players). A test fails if any item
gains a gameplay field. Banners, emotes, unit skins and box-opening animations from the design brief need art
first. Private servers are a Roblox setting. A cosmetic season pass and **gifting** are not built (see section 9).

Allowed in the shop: cosmetics (trails, auras, titles, and later banners, emotes, skins) and convenience that gives
no advantage. Not allowed:

- Mog Points, ranks, rank discounts, boxes, units, capture speed, extra aura or training speed or training time,
  shove or mog-off advantages.
- Anything random for Robux. Cosmetics found in boxes are never sold, so no paid random item exists.
- Pressure for children: no fake countdowns, no "last chance" scarcity, no guilt text, no purchase prompts on
  join or during a war. A purchase only starts from a tap on a Buy button, and Roblox shows the price.
- Promises of free Robux or items.

Technical: every shop item needs a real product id from the Creator Dashboard (until then it shows "Not on sale
yet" and cannot be bought). `ShopSystem` is the only place that sets `MarketplaceService.ProcessReceipt`. A
purchase is applied to the save exactly once using Roblox's purchase id, and "granted" is answered only after
it is recorded. Test with a real purchase in Studio, including a retried receipt.

Known gaps to read before launch:
- If a server crashes after Roblox takes payment but before the save is written, the item can be lost. Check the
  real ProfileStore module for an immediate-save call and use it right after a purchase is applied.
- If a player buys an item they already own (two prompts open at once), they are charged and nothing more is
  given. The shop hides Buy for owned items, but Roblox's own refund and support routes cover the rare case.

## 5. Safety for young players

- Social features list: team play and a text chat that Roblox filters. No trading, no gifting, no wagering, no
  player-made content in version 1 (PRD).
- No flashing or strobing effects, no jump scares, gentle audio, a mute option (slice 13).
- Rewards are capped (8 full-rate wars a day, 8 hours of barracks) so there is no pressure to play all day.
- A parent or guardian should test the soft launch for young testers.

## 6. Originality and assets

- Game name, faction names, ranks and box names must be original. Search the Roblox catalogue for clashes and
  check trademarks before spending on art.
- Every sound, image and model must be your own or properly licensed, with the source recorded. Do not use a
  free model without opening it and removing scripts.
- The store description must not say "like" or "inspired by" any named game.

## 7. Maturity questionnaire

Done by you, not by Claude. Confirmed (2026-11-26): it is in Creator Hub under the experience's Audience, then
Maturity and Compliance; the account must be old enough (30 days); answers are reviewed against the game; the
genre must not influence the answers; it can be retaken; unrated experiences may become unplayable. Gather the
facts from the finished game (violence level of the mog-off, chat, paid random items, social features) using
`maturity-worksheet.md` in the `roblox-launch` skill. Retake it after any change that adds content.

## 8. Checklist before launch

- [ ] Faction renamed or the name explicitly accepted
- [ ] No appearance-rating features anywhere (screens, text, chat prompts)
- [ ] Every box tier sums to 100, odds shown, no way to buy a box or its points with Robux
- [ ] Shop contains cosmetics only; no power, points, ranks, boxes or units
- [ ] No pressure tactics; purchase starts only from a tap
- [ ] All assets licensed or original, sources recorded
- [ ] Questionnaire answered by you for the final build
- [ ] You read the four pages linked at the top, in their current form

## 9. Gifting and other money ideas from the design brief

Gifting is on the design brief's money list and is **not built**. Before building it, read Roblox's current rules on
gifting, on purchases by minors, and on anything that lets players trade or hand over items of value, because it
can enable scams and pressure between young players. A safe version is a cosmetic gift the buyer picks for a
friend who is online, with no ability to trade it onward. The season pass should likewise be cosmetic only and
should show everything it gives before purchase.

## 10. Training stations and the battle pass (planned, not built)

- **Stations:** unlocked by rank only. Selling a station unlock or training time would be pay-to-win (rule 1);
  only cosmetic station skins may be sold. Aura boosts from other players' emotes and hypes need strict server
  limits so extra accounts cannot farm them, and nobody should be pressured to hype or be hyped.
- **Friend spotting:** uses the friends list on the server and adds no new way to chat or contact.
- **Battle pass:** cosmetic rewards only, everything it gives shown before purchase, no countdown pressure, and
  Roblox's current rules on paid passes read first. It must not be a path to points, boxes, units, aura or training.

## 11. Seasons, friends and the squad bonus (built)

- **Friends:** uses Roblox's friends list on the server to place friends together and to give the squad bonus. It adds
  no new chat, no invites and no way to contact anyone. The bonus is capped at +30 percent and is never taken from others.
- **Seasons:** standings show **factions only**, never individual players, and there is no player leaderboard to
  pressure children. The reward is a cosmetic title (never points, boxes, units, aura or training) that can never
  be bought. The shared totals use Roblox MemoryStore; if it fails the game keeps working and shows standings as zero.
- **Needs a live test:** the MemoryStore part cannot be tested in the cloud or in Studio, only in a published place.
