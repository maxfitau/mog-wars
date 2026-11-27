# How to playtest in Studio (Mac)

Nothing has been run yet, so expect to find errors. Write down or paste anything red to Claude.

## One-time setup
1. In Terminal, in the project folder: `rokit install`, then `rojo plugin install`.
2. Studio: open a NEW Baseplate place. In the Explorer delete the default **Baseplate** and **SpawnLocation**.
3. Game Settings > Avatar: set the avatar type to **R15**.
4. Terminal: `rojo serve` (leave it running). Studio: Plugins tab > Rojo > **Connect**. The scripts appear in
   ReplicatedStorage, ServerScriptService and StarterPlayer.

## Test 1: first session (solo)
1. Press **Play** (the blue play button on the Home or Test tab, not "Play Here").
2. You should spawn on a coloured base and see **only** a banner "Run to a glowing zone and stand in it!" with an arrow.
3. Follow the arrow to a glowing zone and stand inside. The banner goes away and a bar appears at the top. Stand still about
   25 seconds: the zone turns your faction's colour. A points counter and the war timer should then appear.
4. Output (View > Output) should print `[mog-wars] zone ... captured`. No red text.

## Test 2: two islands
1. Keep playing until a war has finished (about 12 minutes) or, to speed it up, in the server Explorer set the
   attribute `RevealStage` on your player to 4 (Players > your name > Attributes). The **TRAIN** button then shows bottom right.
2. Walk into the orange **TRAIN** portal beside your base, or press the TRAIN button. You should land instantly on Training
   Island: a green platform far away with four treadmills, a green SHOP block, and a **BACK TO WAR** portal behind you.
3. Press **BACK TO WAR** (button or green portal). You should land just outside the zone your faction owns nearest the
   middle (or at your base if you own none, or between wars).
4. Try to travel twice quickly: the second should be refused ("Not so fast!").

## Test 3: training
1. On Training Island stand on a treadmill and hold the walk key (W) so you walk against the belt. The panel at top left
   shows "Training!" and the bar fills. Stand still: it stops. Walk off the belt: it stops.
2. After about 45 seconds of real walking, the aura level goes to 1.

## Test 4: shop
1. On Training Island a **Shop** button is on the left (it is hidden on War Island). Open it. Items say "Not on sale yet"
   because no products exist yet. Box items say "Found in boxes".

## Test 5: two players (factions and fights)
1. Test tab > Clients and Servers > set Players to 2 > **Start**.
2. Each player should be on a different faction (different colour outline) at different bases.
3. Put both in the same zone: the bar should hold still when equal. After a short time close together, a **mog-off** panel
   appears for both: tap **F** (or click TAP) as fast as you can. The winner is shown "You won the mog-off!".
4. Press **E** next to the other player to shove (cooldown 6 seconds).
5. During a mog-off try to travel: it should be refused ("Finish your mog-off first!").

## Test 6: rewards and later screens
1. Finish two or three wars (or set RevealStage to 4). Boxes, Units, Rank, daily box and Shop screens appear.
2. Capture a zone to earn Mog Points, open a box (it shows its odds before opening), press Rank up at 320 points.

## If something goes wrong
- Red text in Output: copy it all to Claude.
- Nothing appears: check Rojo says Connected and `rojo serve` is still running.
- Press Stop and Play again after any change.

## Bots (new)
1. Press **Play** alone. Within about 10 seconds bots start to appear at the four bases, one every second, until 8 fighters stand
   in the war (you plus 7 bots). Each has a small **BOT** tag above their name and a faction outline.
2. Watch them run between the glowing zones. Zones are bright cyan with a tall pillar of light; they turn yellow as they fill and
   take the faction's colour when captured.
3. Stand in a zone with a bot of another faction close to you for about 2 seconds. A **mog-off** starts with "<name> (BOT)" as the
   opponent. Tap **F** (or the big button) as fast as you can. As a new player you should win most duels, and the bot should win
   one now and then.
4. Press **E** next to a bot to shove it back.
5. Start 2 clients (Test tab, Players 2). The bot count should go down by one a second until 6 bots are left: 2 players plus 6
   bots. Start more players to see them leave one at a time.
6. In Output you should see no "[mog-wars] FAILED" lines. Bots must not appear in the Roblox player list (top right).
7. Signs: you should see one clear sign for each place (TRAIN beside each portal, TRAINING AREA over the treadmills, SHOP on the
   kiosk, BACK TO WAR by the return portal), with nothing floating on top of each other.
8. Go to Training Island: the "Run to a glowing zone" hint must not show there.
9. Max players: in Game Settings > Players set **Maximum Players** to 16.

## Territories (new)
1. Play. You should see 6 territories: **Gigachad Gate** (stone fortress, purple banners) in the middle; **Rizz Ravine** (two cliffs, rope
   bridge) to the east; **Locked-In Lighthouse** (red and white tower with a long ramp) to the west; **NPC Village**, **Brainrot Bog**
   and **Cooked Canyon** in the outer ring. Every flag is a bright glowing zone with a light pillar. The portal to Training Island is at
   the top edge.
2. Stand in one flag of Gigachad Gate. The bar shows "Gigachad Gate: 0/3 flags" and the flag's name. Capture it: "1/3 flags". Nothing is
   paid yet. Capture all three (with bots or a second client helping): you should get floating "+... Mog Points", "+1K aura" and
   "+1 Ultra Box" numbers.
3. Capture NPC Village (1 flag): "+100 aura" and a Gold box.
4. Stay in a territory you hold: about every minute a small "+10 aura" (Gold), "+20" (Diamond) or "+50" (Ultra) appears.
5. Bots should spread over a territory's flags, climb the ramps to the cliffs and lighthouse top, and fight over the Gate.
6. The first-session arrow should point to the nearest 1-flag territory (a Gold one).
7. Output: no "[mog-wars] FAILED" lines. Look for "[mog-wars] ASSET 203785492 was found on ..." or "... is not on any server-side object" and the CLIENT version.

## Landmarks (new): what you are looking for
Stand at the middle of the map and turn around. You should be able to see all six landmarks from far away (this is the point: a child should spot where to go).
1. **Gigachad Gate** (middle): a big grey stone face looking south, with black sunglasses, a nose and a square jaw. The mouth is a tunnel: walk into the dark mouth and out the back. FAIL if the mouth is blocked or you can't walk through.
2. **Rizz Ravine** (east): a giant pink heart floating over the rope bridge, with sparkles around it. FAIL if there is no heart or no sparkles.
3. **Locked-In Lighthouse** (west): a red and white tower with a giant gold padlock on top and a long yellow beam shining east. FAIL if the top is just a plain lamp.
4. **NPC Village** (north-west): a giant blocky grey statue with a blank face and a white speech bubble with "...". FAIL if the face has any features.
5. **Brainrot Bog** (south-west): a giant pink brain sitting in bright green goo with bubbles and a dead tree.
6. **Cooked Canyon** (south-east): a giant dark frying pan on pillars with a white fried egg and a yellow yolk, steam rising, lava underneath.
Then check the flags are ON the landmarks and reachable:
- Walk up the long ramps: the Gate ramp (from the north edge up the back of the head), the statue ramp (from the west, up to the head), the brain ramp, the pan ramp, the lighthouse ramp. FAIL if a ramp is too steep to walk or you slide off.
- Each flag is a glowing zone with a light pillar at: both tower bases and the top of the Gate's head; each cliff; the lighthouse base and top; the statue's head; the top of the brain; the yolk.
- A bot should climb each ramp on its own to reach the raised flags. FAIL if bots stand at the bottom of a ramp forever.

## Combat (paintball): what you are looking for
Needs a Studio playtest (cloud tests cover only the rules). Start a War Island session (bots fill it).
1. **Shoot**: click (PC) or press FIRE (phone). A coloured ball flies and leaves a paint splat. Crosshair in the screen centre, ammo "Splatter 12/12" bottom right, health bar bottom middle. FAIL: nothing fires, or ammo never goes down.
2. **Reload**: empty the magazine; it says "Reloading..." for about 1.5 s, then refills. R reloads early. FAIL: you can keep firing while empty or reloading.
3. **Hit a bot**: hitmarker flashes, 4 hits = "SPLAT!" pop-up, +10 aura / a few points pop-ups, a cartoon poof and a kill-feed line top right in faction colours. FAIL: no reward, or the same bot pays again within 20 s.
4. **Get hit**: red screen flash and an arrow toward the shooter. 4 hits = poof, "Splatted! Back in 3", respawn at your faction corner (not the front line) with a shield glow for 2 s. FAIL: you respawn at the front line or can shoot while shielded.
5. **Streaks**: splat 3 different bots in a row without dying: "MOGGING x3!"; 5: "UNSTOPPABLE x5!".
6. **Contested flag**: stand in a flag with an enemy bot also inside: the HUD says CONTESTED and the bar does not move. Splat it, then the bar fills. FAIL: the bar moves while contested.
7. **Defend bonus**: splat an enemy while standing in a zone your faction owns: aura is 15 instead of 10 (5 for a bot).
8. **Weapons**: 1/2/3 switch (a locked one is greyed out). At Rookie Splash Cannon unlocks (3 balls, short range); at Sigma Long Shot (zoom, one 50 hit). FAIL: you can equip a locked weapon.
9. **Phone**: FIRE button bottom right, SWAP cycles blasters, shots drift slightly toward an enemy near the crosshair.
10. **Bots**: they shoot at you in range, strafe, hide behind props when hurt, and miss a fair amount. FAIL: they never shoot, or kill you in under 2 s.
11. **Mog-offs**: no duel prompt should appear during a war.
12. **Training Island**: you cannot shoot or be shot there.
## What to tune first
`src/shared/Weapons.luau`: `botSpreadDeg` (bot accuracy), `botFireIntervalMin/Max`, `damage`, `fireInterval`, `splatPoints`, `splatAura`, `shieldSeconds`, `respawnSeconds`, `aimAssistDegrees`, `farmCooldownSeconds`. Re-run `python3 tools/pacing.py` after changing rewards.

## Visual polish: what to look for (needs Studio)
First, once: Lighting > Technology = Future (a script can't set it). Then play on War Island.
1. **Island**: green grass top, sand beach rim, blue water all around, a few hills near the edge, brown dirt paths from each base toward the middle. FAIL: a flat grey slab, or falling through the ground.
2. **Sky and light**: bright sunny day, soft haze, no grey fog.
3. **Cover**: crates, walls, barrels and bushes near each flag, on the paths and in front of each base. Shots stop on them. FAIL: you can walk through a crate, or bots never hide behind them.
4. **Capture circle**: white ring on the ground at every flag (no neon square). Stand in it: the inside fills from the middle in your colour. When owned, the ring and the flag cloth take the owner's colour. FAIL: a square, or the fill never shrinks when the other team pushes it back.
5. **Beam**: one thin beam per flag, shown only when the flag is neutral or contested. FAIL: giant pillars, or a beam on an owned and quiet flag.
6. **Landmarks**: Gigachad Gate (castle walls, towers with purple banners, face with sunglasses, walk through the mouth), Rizz Ravine (cliffs, rope bridge, pink heart, sparkles), Lighthouse (striped, golden padlock, beam that turns slowly), NPC Village (grey statue + 4 small houses), Brainrot Bog (pink brain in green mud, bubbles), Cooked Canyon (rock walls, lava, pan with egg, steam).
7. **Name signs**: floating panel over each territory, coloured Gold / Diamond / Ultra. FAIL: signs overlapping or unreadable from the middle.
8. **HUD**: Mog Points panel with a gold coin and a bounce when it goes up; war panel with four faction boxes (badge, "N terr.", score); capture bar fills in the capturing colour with a % and turns orange "CONTESTED" when enemies are inside. All in the rounded Fredoka font with white outlines.
9. **Phone** (Studio device emulator, a low-end phone): steady frame rate, nothing flickers; HUD not covered by thumbs.
