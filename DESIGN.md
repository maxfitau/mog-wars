# Mog Wars — Design Brief (v0.3, the simple game plus progression)

## One sentence
**Run to a flag, stand on it to win it for your team, and your aura goes up. Get the most aura to go from NPC to Mog God.**

## Design rules (in priority order)
1. Not pay-to-win. Nothing purchasable gives an advantage over another player. Rank only changes your glow, title and name colour, never your power.
2. High playtime. The core loop is fun in under 30 seconds and a little kid can understand it at a glance.
3. High retention. Progress always saves; a daily reward streak; aura and rank to climb.
4. Good monetisation. Cosmetics only: aura colours, trails and titles. Small, repeatable buys.
5. High click-through rate. Clear, bright icon and thumbnail; the game delivers what the thumbnail promises.

## Theme guardrails
"Mog" is an absurd meme (cartoon Chad faces, jawline jokes). No "blackpill" or incel language, no ranking of real looks. Ranks measure aura earned by winning. Don't use "Risk" anywhere (trademark).

## The game
1. Join: you are placed on one of 4 auto-balanced teams (Jawline Legion, Mewing Order, Sigma Syndicate, Aura Collective) and spawn on War Island. **Servers are small: 8 real players at most**, and Moglings fill every team up to 4 fighters (16 in all); they are removed one at a time as real players join. Small servers make every action personal (set Maximum Players to 8 in Creator Hub: Game Settings, Places, Max Players; the project file and the code already say 8).
2. A big arrow points to the nearest Gold flag: "Stand here to capture!". That is the whole tutorial.
3. Stand on a flag to capture it. More teammates on the flag capture it faster (each extra +25%, up to double). Gold flags take 4 seconds, Diamond 6, Ultra 8 (one player alone).
4. A team owns a territory when it holds ALL of its flags.
5. **Shove** is the only way to fight: one big button on mobile, E or click on PC. A short knockback with a funny "BONK!" pop-up, 1.5 second cooldown. Bots shove too.
6. Aura goes up all the time, with big number pop-ups: +1 every second you stand on a flag you are capturing, +25 for every flag captured, a bonus when a territory is captured (Gold +100, Diamond +300, Ultra +1000), and a small trickle every minute while your team holds territories.
7. Ranks are earned by total aura, automatically: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God. A rank never goes down. It changes only your glow, title and name colour.
8. Wars are 6 minutes. The last thing you see is a quick 5-second results screen (winning team, MVP of each team), then the next war starts straight away.
9. A daily reward streak (7 days, aura) and a cosmetic shop (aura colours, trails, titles) stay.

## Quick start (the first 10 seconds, and always knowing what to do)
- On first load a big card says "MOG POWER UNLOCKED: SHOVE!" with a flash, confetti and a 3-second demo, then you are in the war. Rookie comes after about a minute of play. Each rank unlocks one ability button, earned and never sold: NPC Shove, Rookie Dash (4 second cooldown), Sigma Mog Stare (a short beam that freezes one enemy for 1 second, 8 second cooldown). Each unlock gets the same card. At most three ability buttons, bottom right.
- A mission bar (top centre, under the scoreboard) always shows ONE goal: "Defend Rizz Ravine!", "Capture Brainrot Bog - 80m", "Steal NPC Village from RED - 120m", with a trail of glowing dots on the ground leading to that flag.
- An announcer shows banners: "RED is capturing Rizz Ravine!", "YOUR TEAM took Gigachad Gate!", "1 MINUTE LEFT - DOUBLE AURA!".
- Aura ticks all the time, with small "+N" numbers by the aura counter: +1 every second of the war, +3 a second while you stand on a flag your team is capturing or defending, +1 a second for every territory your team holds. The last 60 seconds are double, with the timer pulsing.
- The fillers are called **Moglings** ("Mogling Jeff"): blocky little characters in their team colour that run to flags, shove, and dash. The word "bot" is never shown.
- 12 hidden Aura Stashes (behind waterfalls, on a rooftop, under bridges, in secret rooms) each give +100 aura once per war; "Stashes found n/12" is under your aura counter and finding all 12 earns the Stash Hunter title.
- Launch pads and ziplines join the islands.

## More reward feedback (dopamine)
Something small every 2-3 seconds (the +X ticks), something bigger every ~30 seconds (a capture, a combo, a quest), something huge every few minutes (a MEGA/ULTRA MOG!, a bounty, a war chest). Any aura gain of 3 or more has a 5% chance to be a MEGA MOG! (x5, gold) and 1% an ULTRA MOG! (x10, rainbow). Captures, shoves, orb pickups and stashes within 4 seconds of each other build a combo (x2, x3, x5, x10) that multiplies aura, with a screen-edge glow that gets hotter and a soft "combo ended +240" summary. Each war gives 3 mini-quests under the aura box. About 30 achievements (saved, some with titles). The rank bar sparkles at every 10% and says what the next ability is ("Mog Stare unlocks in 120 aura!"). After the results a free war chest drops and pops open (aura, a free trail or aura colour, or a title; never sold). Announcer callouts: DOUBLE SHOVE!, ON FIRE!, UNSTOPPABLE!.

## Big numbers, levels and pacing
Aura is shown idle-game style (999, 1.23K, 12.3M ... T, then aa, ab ...; always 3 digits, rolling counters, "NEW TIER" flashes). Each rank has 10 levels (Rookie I-X ... Mog God I-X, then endless Mog God stars); every level multiplies ALL aura income and rewards, and every level takes longer than the last. Pacing for an ACTIVE player: Rookie about 1 minute, Sigma 10 minutes, Chadlite 30, Chad 1 hour, Gigachad 3 hours, Mog God I about 72 hours (`Pace.levels`, `Pace.income`, `tools/pacing_sim.py`). ACTIONS are the main income (flags, captures, stashes, quests, steals, chests, events); passive "just for being here" aura is about 15% of an active player's income, stops at the end of Rookie and is zero while AFK (30 s idle = AFK tag, no passive aura, cannot hold flags; 3 minutes = sent home). Aura and levels never change ability strength, speed or capture speed.

## Weapon collection (free only, never sold)
Nine launch weapons; an equipped weapon REPLACES Shove (the rank abilities are unchanged): Jawline Hammer (Common, slow swing, shoves 2x as far), Mewing Fan (Common, wide gust cone), Sigma Shades (Rare, boomerang sunglasses that hit on the way back), Rizz Rose (Rare, thrown, the target walks toward you for 1 s), Glow-Up Mist (Epic, slippery sparkle puddle), Mirror Shield (Epic, hold to reflect shoves), Protein Shaker (Legendary, shockwave plus a speed boost for you), Main Character Mic (Legendary, nearby enemies freeze and stare for 1.5 s), Gigachad Gauntlet (Mythic, charged giant punch with screen shake and a big knockback). **Same power budget for all**: rarity is only flashier visuals and sounds; cooldowns balance them. Duplicates add stars 1 to 5 (a slightly bigger effect, at most +20%, and a glowing skin at 5 stars). Sources, all free: the War Chest, gold supply drops, quest rewards, the weekly event, achievements, and a guaranteed Rare on login-streak day 7. The chest UI shows the drop odds (`WeaponCatalog.odds`). A Weapon Index screen (key B) shows every weapon (silhouettes for the unfound), stars and an equip button; the collection is saved (save version 14). Moglings carry random Common or Rare weapons. Never in any shop, never pay-to-win.

## Progression layers
- Daily quests (3 a day) and weekly quests (5 a week) with aura and chest rewards; the login streak (7 days) gives a guaranteed Rare weapon on day 7.
- Team League: each week the game counts which team wins the most wars; on Monday the members of the top team get the "League Champion" banner title and a chest.
- Weekly event: **Meteor Storm Saturday** at a fixed UTC time (meteors every 90 s and 2x aura), counted down on the HUD all week and on the event button; a matching event card is created in Creator Hub by the owner.
- Seasons: a season id in settings (`SeasonConfig.current`) swaps decorations on NPC Village (snow in Winter) and names the season on the event button.
- Season Pass: a free track of 20 tiers (titles, trails, weapon skins, aura, chests and one new weapon at tier 20) is BUILT BUT OFF (`Features.seasonPass = false`) for Update 1.
- Reactions: winners strike a smug pose with sunglasses when their team captures; players knocked into the clouds flail and cry with a "NOOO".
- **Update 2: Rebirth** (reset your level for a permanent cosmetic and weapon-star bonus). Not built; noted here only.

## Abilities (rank-unlocked, never sold; Shove plus your two newest on screen)
NPC Shove. Rookie Glow-Up Dash (4 s). Sigma Mog Stare (freezes one enemy 1 s, 8 s). Chadlite Jawline Slam (jump + ground pound, knocks back everyone within ~10 studs, 10 s). Chad Hair Flip (a cone gust that pushes enemies back and off flags, 12 s). Gigachad Mewing Shield (3 s immune to shove, stare and knockback, 18 s). Mog God Total Mog (enemies within ~20 studs are REDUCED TO NPC for 2 s: grey, half speed, cannot capture; 30 s). Moglings use them too, at the players' average rank. Rank pacing aims at Rookie ~1 min, Sigma ~10 min, Chadlite ~30 min, Chad ~1 hour, Gigachad ~3 hours, Mog God multi-day.

## Aura stealing and the bounty
Knock someone off an island, or freeze them and then shove them, and they drop glowing aura orbs worth 10% of the aura they earned THIS WAR (never their saved total). Orbs float and magnet to whoever touches them first ("+45 STOLEN!"); the victim just sees "-45 aura". The player with the most aura this war wears a crown, a tall light beam and a "MOST AURA" tag; knocking them out steals 20% and announces "BOUNTY CLAIMED!". The results screen shows aura stolen.

## Rifts and ziplines
Seven glowing purple-and-gold rifts throw you into the sky; you glide down with a small glider and land anywhere; a used rift flickers out for 20 seconds. Ziplines work both ways: walk onto a platform (or press E) and the server carries you along the cable.

## HUD (three things)
- Top left: your aura and rank, with a bar toward the next rank.
- Top centre: the war timer and the four team scores, and the capture bar when you stand on a flag.
- Bottom right: the big shove button.
(Plus the small Shop button, a Daily reward button that only shows while a reward is waiting, and the "Stand here to capture!" arrow for new players.)

## Territories
Seven territories, twelve capture flags, each on its own floating island (Chud Chambers is a cave under the Gate island). Names, positions, flag counts and rewards live in one settings file (`src/shared/Territories.luau`). Each is a big landmark you can see from anywhere on the island, with an inside (rooms, tunnels, stairs, rooftops), flags in exciting spots, its own colours, ground and particles, a secret spot with a free Aura Stash (a little aura), and plenty of cover. Built from simple parts and Terrain; no Toolbox models.
- Centre: **Gigachad Gate** (Ultra, 3 flags). A giant stone face with sunglasses; its mouth is a tunnel you walk through; inside the head is a throne room; two towers with spiral stairs and a flag on each roof.
- **Rizz Ravine** (Diamond, 2 flags). A deep pink ravine with a rope bridge, a flag on each cliff top, and a giant hollow balloon-heart over the bridge with jump pads either side.
- **Locked-In Lighthouse** (Diamond, 2 flags). A striped lighthouse on a rocky island in a moat; a spiral staircase inside; the base flag is by the door and the top flag is in a golden-padlock lamp room with a turning beam.
- **NPC Village** (Gold, 1 flag). A blocky village of enterable houses and a giant grey NPC statue climbed by wooden scaffolding; the flag is on its head; a secret room under the well.
- **Brainrot Bog** (Gold, 1 flag). A foggy green swamp with lily pads and dead trees; a giant hollow pink brain with fleshy tunnels; the flag is in its centre; a hollow log is the secret.
- **Chud Chambers** (Diamond, 2 flags, +300 aura). A cave hanging UNDER Gigachad Gate, lit by warm torches and glowing mushrooms. A great hall with a giant, grumpy, cartoon stone face carved into the wall (glowing eyes, a scowl, a beard of hanging roots, an occasional "..." bubble). Two chambers: the Snack Hoard (a mountain of crisp packets and cans; flag 1 on top) and the Gamer Throne (a glowing chair facing a wall of screens; flag 2 behind the throne). Entrances: spiral stairs and a drop down a shaft in the castle courtyard, and a rope ladder from the island's edge. Every ~2 minutes the torches flicker, the face groans "bro...", and a gentle wind pushes players toward the exits. Secret: a narrow tunnel behind a snack pile with a small Aura Stash. Two cave dwellers wander about ("touch grass? never heard of it", "it's not a phase").
- **Cooked Canyon** (Gold, 1 flag). A red canyon with a lava river and rock jumps up to a giant frying pan; the flag is in the egg yolk; a cave behind a lava fall is the secret.
- Faction spawns are in the 4 corners. Dirt paths, with speed pads on them, join the bases to the territories.
- Small name signs over each landmark fade in only when you are close.

## Look: Sky Islands (art direction, in progress)
Golden hour: a low warm sun, a hazy golden atmosphere so far islands fade into it, a warm colour grade, subtle bloom and sun rays, and a peach-white cloud sea far below, so the void looks like endless sky. Each territory becomes its own floating island at its own height with a tapering rocky underside, dangling roots and small waterfalls; Gigachad Gate is the biggest and highest, in the centre; two Diamond islands at mid height; three Gold islands lower near the spawns; four team spawn islands with banners. Islands are joined by wooden rope bridges, ziplines and launch pads (any island reachable in about 20 seconds). Falling off is a quick WHOOSH into the clouds and a respawn at your team island after 2 seconds, no damage; shove can knock people off edges. Decoration: airships (balloon and wooden gondola), birds, floating mini rocks. Dense timber villages with coloured roofs around each hero landmark, built from wood planks, slate, cobblestone, grass and rock (no plain smooth plastic), and a short, soft green for grass. Ambient villager NPCs (clearly not players) make each island feel alive. Stage 1 (done): lighting, cloud sea, the floating Gate island, the fall-into-clouds respawn. Stage 2 (done): every territory is its own island at its own height (Gate 110, Diamond 70, Gold 35, team islands 20), rope bridges join them, airships circle, and Chud Chambers hangs under the Gate. Next: ziplines and launch pads, ambient NPCs on every island, and Creator Store building packs (audited first).

## Switched off (built, hidden, behind flags in `src/shared/Features.luau`)
The OLD combat weapons (aura blasters, ego, mogging, kill feed; not the new weapon collection above), mog-off duels, Training Island and every training station, loot boxes, units (tanks and horses), pickups, dash, discovery cards, overtime, seasons, the old Mog Points currency, the squad bonus, prestige and the skill tree, and the Mog Arena tycoon. Flip a flag to bring a feature back; nothing was deleted. The older designs for them are in `docs/` and in the git history.

## Version 1 scope
One map per server, 6 territories, 4 auto-balanced teams, 6-minute wars that reset, join mid-war anytime. Max server size 8 real players (plus Moglings to 4 a team).

## Money (cosmetic only)
Aura colours, trails, titles, and later extra cosmetics. Never power.

## Where we are up to (project paused)
**State of the code:** everything is committed and pushed to `main`. The whole game was written in a cloud session with no Studio and no Luau runtime, so **nothing has been run or playtested**: only `python3 tools/luaucheck.py` (a syntax check) was ever run. The first job when work resumes is a Studio playtest using `docs/MAC_MCP_PROMPT.md` and the checklists at the top of `docs/PLAYTEST.md`, then fixing what breaks. Also run every `tests/*.test.luau` with `luau` (none were run), and `python3 tools/pacing_sim.py`.

**Built (unplayed):** the simple capture-the-flag war on 7 floating-island territories and 4 teams; big numbers and 10 levels per rank; pacing, AFK and a debug command set (Studio only, your user id); bubble lifts; the Chud Chambers trap dungeon; the Aura Meteor and supply drops; name signs, entering cards and the minimap; detail passes on every island; waving flags, mood lighting and team mascots; airship taxis; the sound system; the 9-weapon collection with index, chest and odds; daily and weekly quests and the streak; the weekly Meteor Storm event, season theme and team league; reactions; the Season Pass (built, OFF).

**Known gaps and risks:**
- All sound ids in `src/shared/Sounds.luau` are empty (the game is silent); fill them from Roblox's own audio library and read the Studio sound audit.
- No Creator Store kits, generated meshes or MaterialVariants/PBR; no mobile frame-rate test; StreamingEnabled is off.
- The HUD layout (right column, phone sizes) was checked by arithmetic only.
- League winner is decided per server at the week rollover, and the league chest and weekly reward have no participation threshold (alt-account risk); the gauntlet charge is client-reported. See `docs/decisions.md` 239 and 242.
- The old combat system (off) clashes with the new weapons on the `EquipWeapon` remote and `Weapon` attribute names.
- Creator Hub tasks for the owner: set Maximum Players to 8, create the Meteor Storm Saturday event card, enable Studio access to API services if you want saving tested.
- Not built: tank mode, music, real hit-stop (a camera zoom stands in), Rebirth (Update 2).

