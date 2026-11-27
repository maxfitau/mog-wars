# Morning notes

Good morning. Short version: all eight written tasks are done and committed (nothing pushed), but **slice 1 was
not built or playtested** because I could not reach your PC, Studio or `DESIGN.md`.

> **Update:** `DESIGN.md` is now in the repo and slices 1 to 11 are written. Read `docs/design-reconciliation.md`
> for what differs from the brief. The notes below are from the first night and are kept for history.

## Read this first: where things are
- The project lives in the **cloud container** at `/home/user/mog-wars`, a git repo with 8 commits on `main`.
  It is **not** in `C:\dev\mog-wars` and **not on GitHub**. I delivered a zip of it to you in chat.
- To use it: unzip to `C:\dev\mog-wars` (outside OneDrive), create the private GitHub repo `mog-wars`, then
  `git remote add origin ...` and `git push -u origin main`.
- `DESIGN.md` was **never readable** from the cloud. Copy it into the repo root, then compare it with
  `docs/PRD.md`, `docs/economy.md`, `docs/compliance.md` and the decisions list. **`DESIGN.md` wins.**

## Finished
1. Project skeleton: Rojo layout, strict Luau, StyLua and Selene configs, Rokit pins, `CLAUDE.md`, README.
2. `docs/PRD.md`: product brief.
3. `docs/slices.md`: 14 small playable slices with build, test and done-when.
4. `docs/economy.md` and `src/shared/EconomyConfig.luau`: all numbers in one file, plus `tools/pacing.py`.
   Casual player (3 wars a day, 6 days a week): **Chad about day 6, Mog God about day 44.** Light about 104 days,
   regular 21, hardcore 9.
5. Pure-logic modules in `src/shared`: `CaptureBar`, `ContributionScoring`, `BoxRoll`, `RankRules`, each with a
   test in `tests/`.
6. `docs/compliance.md`: concerns review with fixes.
7. `docs/store-page.md`: 5 titles, 3 icons, 3 thumbnails, description.
8. `docs/decisions.md`: 16 decisions with reasons.

## Not verified (be honest with yourself about these)
- **Luau tests have never run.** No Luau runtime here (and I did not install one). I checked the capture-bar and
  payout-split logic with a Python copy and it passed, but that is not the Luau code. Run each test on your PC:
  `luau tests/CaptureBar.test.luau` (and the other three). Fix anything that fails.
- Nothing has been through StyLua or Selene.
- `tools/pacing.py` is a simple model with guessed play rates. Real players will differ.
- Compliance and Roblox facts come from search summaries dated 2026-11-26, not full pages. Read the linked pages.

## Needs playtest (Studio)
- Slice 1: standing in a zone captures it in about 24 seconds alone; client messages cannot change zone state.
- Everything in `docs/slices.md` marked "In Studio".

## What I assumed (see `docs/decisions.md`)
War 10 minutes, 16 players, 4 factions; four safe bases and (then) five contested zones, now nine; mog-offs decided by taps only;
boxes never sold; ranks paid with Mog Points; positive rank names; aura +10 percent per rank; 8 full-rate wars
a day then half; barracks capped at 8 hours.

## Needs your input
1. Copy `DESIGN.md` in and reconcile (above).
2. Rename "Aura Cartel" (suggest "Aura Collective") or accept the concern.
3. Decide how to handle the "mogging" theme concern: read `docs/compliance.md` section 1.
4. Pick a title (`docs/store-page.md`).
5. Approve installs (Rokit, Rojo, StyLua, Selene, Luau) and connect Studio MCP.
6. Pacing: are about 6 days to Chad and about 6 weeks to Mog God right?

## Skipped because it needed your permission or your PC
- Reading `DESIGN.md`
- Creating `C:\dev\mog-wars` and the private GitHub repo
- Installing Rojo, Rokit, StyLua, Selene or a Luau runtime
- Connecting to Roblox Studio through its MCP server and playtesting

## Build next
1. Do the setup above and run the four Luau tests.
2. Slice 1 (`docs/slices.md`): a baseplate, one `Zone` part, a server system using `CaptureBar`, then playtest.
3. Slices 2 and 3 (factions, contested capture and HUD), then 4 (points and saving).
