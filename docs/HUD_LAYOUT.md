# HUD layout (strict: nothing overlaps)

All y numbers are below the Roblox top bar (every HUD ScreenGui uses IgnoreGuiInset = false, so the inset is added for all of them alike; full-screen flashes are the only exception). Sizes come from the code; shared numbers live in `src/client/Lib/HudSlots.luau`.

| Slot | Where | What may be in it |
|---|---|---|
| Top centre | y 10-106 | team tiles + timer ONLY (`WarHud`, scaled by clamp((width - 430) / 520, 0.55, 1)) |
| Line slot | y 112-158, centred, width clamp(width - 640, 200, 360) | the mission bar; a big banner REPLACES its text for 3 s, then the mission returns (`HudSlots.line`, drawn by `MissionHud`; banners stay visible even outside a war). One at a time |
| Capture bar | y 164-240, centred | only while standing on a flag (`CaptureHud`) |
| Card slot | y 250 (`HudSlots.cardY`), centred, below the capture bar | ONE pop-up card at a time (`HudSlots.card`): ENTERING a territory, unlock, achievement, weapon reveal, event, streak |
| Left column | x 16, y 56 down, scaled by clamp(width / 1200, 0.6, 1) | the aura box (y 56-164); under it the Quests row at y 172: "Quests n/3" pill, the "Weapons (B)" pill 126 px to its right, the combo label 234 px right (and the Season Pass button 230 px right, only when the pass is on); the open Quest panel / Quest Board at y 206; aura pop-ups from y 214 |
| Right edge, top | y 64-104, 176x40 | the event pill (tap for its card) |
| Right column | x right, y 112 down | the map-control bar, then the minimap square of `HudSlots.mapSize()` (260 on desktop; about 70-100 on a landscape phone so it ends above the Shove button), then on tall screens the hint and the MUSIC / SFX toggles (on short screens they are in the big map) |
| Bottom right | - | Shove / weapon button (132 px, 88 px on short screens) and the ability buttons to its left (88 px) |
| Middle third | - | nothing permanent; short pop-ups only |
| Bounty | in the world | the crown, beam and "MOST AURA" tag above the leader's head; no HUD banner |

Short screens (height under 500): the minimap shrinks to fit above Shove, the hint and toggles move into the big map, the Shove button is 88 px.
Needs a real screenshot in Studio (device emulator at 844x390 and 667x375, and 1280x720) to confirm; see `docs/MAC_MCP_PROMPT.md` step 6. The layout is computed once at start-up: rotate or resize and rejoin to refresh it.
