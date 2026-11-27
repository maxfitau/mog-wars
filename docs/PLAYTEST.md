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

## Combat and pace (Mog combat): what you are looking for
Needs a Studio playtest (cloud tests cover only the rules and numbers). Start a War Island session (bots fill it). On PC press Q any time to free the mouse for buttons, T to go to Training Island and back.
1. **Speed**: you run clearly faster than before and jump higher (22 and 55). On Training Island you are slower. FAIL: the same speed everywhere, or stuck at 16.
2. **Speed pads**: cyan pads on the paths from each base. Run over one: a light trail and you speed up for about 3 seconds. FAIL: no change in speed.
3. **Dash**: double-tap W, A, S or D (phone: DASH button): a quick burst. A second dash within 4 seconds does nothing. FAIL: dash works every time, or never.
4. **Launch pad**: when you respawn you land on the pink pad by your base and are thrown toward the middle.
5. **Fire**: click (PC) or FIRE (phone). A glowing aura blast in your faction colour, nothing stays on the walls (just a short sparkle). HUD says "Aura charge 12/12" and a bar labelled EGO. FAIL: any old wording from before the Mog retheme anywhere on screen.
6. **Weapons**: 1/2/3 = Aura Blaster, Flex Blast (a cone shockwave, 3 blasts, close range), Side-Eye Sniper (a thin stare beam, zoom). Locked ones are greyed out.
7. **Mog a bot**: 3 hits. Banner MOGGED!, "+2" per hit, "+10", "+5 Mog Points", coins fly to the points counter, the kill feed says "X mogged Y". A fast second hit shows COMBO x2 right of the crosshair. Two mogs in a row: DOUBLE MOG; three: TRIPLE MOG; five: MOG GOD STREAK. After each mog you get AURA RUSH (a quick speed-up). FAIL: no pop-ups, or any pop-up covers the crosshair.
8. **Get mogged**: you turn grey with a blank face and a "..." bubble, banner REDUCED TO NPC, back in 2 seconds on the launch pad. Bots do the same and come back.
9. **Flags**: a Gold flag fills in about 4 seconds with one player; stand there and watch "+1" every second; "+25" and FLAG CAPTURED! with a small screen punch when it flips. Two teammates on a flag fill it faster. With an enemy alive inside: CONTESTED and the bar holds.
10. **Pickups**: about every 30 seconds a glowing orb appears (Protein Shake, Aura Refill, Main Character Mode). Touch it: banner with its name; Main Character Mode gives a golden glow, a spotlight, and doubled aura numbers for 15 seconds.
11. **Overtime**: in the last 60 seconds the timer pulses red and says OVERTIME x2; all aura numbers double.
12. **Results**: when the war ends a 5-second panel shows your totals and each faction's MVP, then the next war starts straight away.
13. **HUD**: scoreboard top left (to the right of Roblox's buttons), capture bar top centre below it, Mog Points top right. Nothing sits under the chat.
## What to tune first
Speed, dash, capture times, overtime, pickups, +1 values and the results screen: `src/shared/Pace.luau`. Damage, fire rates, ego, respawn time, hit and mog aura, combo and bot accuracy: `src/shared/Weapons.luau`. War length and the gap between wars: `EconomyConfig.war`.

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
