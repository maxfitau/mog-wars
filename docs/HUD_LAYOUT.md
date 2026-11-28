# HUD layout (strict: nothing overlaps)

| Slot | Where | What may be in it |
|---|---|---|
| Top centre | y 10-106 | team tiles + timer ONLY (`WarHud`) |
| Line slot | y 112-158, centred (width 200-360) | the mission bar; a big banner REPLACES its text for 3 s, then it returns (`HudSlots.line`, drawn by `MissionHud`). Event banners (Meteor incoming / Meteor flag), RANK UP, MEGA MOG, WHOOSH, TRAPPED, announcer lines all use it; one at a time, in order |
| Card slot | y 172, centred, upper third | ONE pop-up card at a time (`HudSlots.card`): ENTERING a territory (smaller, 1.5 s, only on a real new entry, not again for the same place inside 20 s), unlock cards, achievement cards |
| Left column | x 16, y 56 down | aura box (with the combo counter beside the quest pill at y 172), "Quests n/3" pill (tap to open), then the aura pop-ups (max 3, fade in 0.9 s) from y 214 |
| Right column | x right, y 64 | the minimap, 128 px (25% smaller), with the map-control bar |
| Middle third | - | nothing permanent; short pop-ups only (screen punch, white flash, coins flying to the counter) |
| Bounty | in the world | the crown, beam and "MOST AURA" tag above the leader's head; no HUD banner |

Narrow screens: the left column scales to `clamp(width / 1200, 0.6, 1)`, the top-centre block to `clamp((width - 430) / 520, 0.55, 1)`, and the mission bar width to `clamp(width - 640, 200, 360)`.
Checked by arithmetic at 844x390 (a landscape phone): left column right edge 16 + 270 x 0.70 = 205; top-centre block 214 to 630; mission bar 320 to 524; minimap 704 to 832; card 276 wide centred at 422 (284 to 560). At 667x375: left 178, top-centre 190 to 476, mission 233 to 433, minimap 527 to 655. No overlaps.
Needs a real screenshot in Studio (device emulator) to confirm: see `docs/MAC_MCP_PROMPT.md` step 6.
