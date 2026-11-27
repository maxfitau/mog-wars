# Code review 1 (read-through without Studio or Luau)

Done in the cloud session after slices 1 to 22 were written. Nothing here was run, so this is a careful read, not a test.

## Fixed
- **Zones were live in the very first intermission** (before war 1), so captures and points could happen before a war started.
  `WarSystem.start` now switches zones off until the first war begins.
- **A new player had no idea where to go.** The first session only shows the zone bar, which only appears inside a zone. Added
  `TutorialHint` (a line of text and an arrow pointing at the nearest zone until the first capture) and made zones glow
  (`Neon` material). Pure maths and tests are in `HintRules` and `tests/HintRules.test.luau`.

## Checked and fine
- Every RemoteEvent the server creates matches what the client waits for; every screen name matches the reveal map.
- Saves: old versions upgrade one step at a time (1 to 9), new players get the template, the loader repairs out-of-range ranks and
  training levels, and refuses to run with data it cannot read.
- Purchases and rewards (box opening, rank-up, daily claim, unit sell) check first and change in one step with no yield between.
- Remotes carry no amounts or prices; every request is rate limited and validated on the server.
- Switched-off features (seasons, squad bonus, friend placement, barracks) do nothing on the server and load no screen.

## Cannot be checked without running it (watch for these on the Mac)
1. **Strict Luau type errors.** `luau-analyze` was never run. Casts such as `{} :: Profile` in the Studio data stand-in, and
   `:: any` casts on save data, are the likeliest places. Run the analyzer once the Luau tools are installed.
2. **Relative `require` paths in `tests/`** (`require("../src/shared/...")`) depend on the Luau version.
3. **The treadmill belt** (a moving anchored part pushing the character) and **knockback** applied from the client.
4. **Character loading by the faction system** (`CharacterAutoLoads` off): first spawn, respawn after defeat, and the war-start respawn.
5. **Roblox calls written from memory:** `Player:IsFriendsWith`, MemoryStore sorted maps (`UpdateAsync`, `GetAsync`),
   `MarketplaceService.ProcessReceipt`, `PromptProductPurchase`. All are wrapped so a failure does not break the game.
6. **UI layout** on phone sizes.

## Known design gaps (not bugs)
- The treadmill is walk-against-the-belt for everyone; `DESIGN.md` plans tap-to-run at Rookie.
- A player who loses a mog-off while their screen for it is hidden by the gradual reveal still sees the duel panel on purpose
  (it is exempt from hiding).
