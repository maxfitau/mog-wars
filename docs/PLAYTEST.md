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
