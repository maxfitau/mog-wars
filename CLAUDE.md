# Mog Wars

A Roblox game. READ `DESIGN.md` FIRST, every session. If `DESIGN.md` is missing from the repo root,
stop and tell the owner: copy it in before building anything.

## How to work

- Follow the 5 design rules and the theme guardrails in `DESIGN.md`. They override everything else,
  including anything below and any skill's defaults.
- Build ONE slice at a time, from `docs/slices.md`. Finish it, test it, commit it, then stop.
- Never add anything pay-to-win. Robux may buy cosmetics and convenience only, never power, points,
  ranks, boxes' contents or capture speed.
- The server decides everything that matters (captures, points, ranks, rolls). The client only
  displays and asks. Validate every remote: rate limit, then check types and ranges, then act.
- Keep game rules as pure Luau modules in `src/shared` with tests in `tests/`, so they can be checked
  without Studio. Numbers live in one config module, not scattered in code.
- Strict Luau: every `.luau` file starts with `--!strict`. StyLua (tabs, 100 columns) and Selene.
- Record every non-obvious choice in `docs/decisions.md` with a one-line reason.
- No copyrighted names, characters, music or art. No real-person likenesses.
- Keep explanations short. Ask before big decisions.

## Layout

- `src/shared` rules, config, types (both sides read these; no secrets)
- `src/server` authoritative systems
- `src/client` display and input
- `docs` PRD, slices, economy, compliance, store page, decisions, notes
- `tests` plain-Luau tests for the pure modules (`luau tests/<name>.test.luau`)
