# HUD declutter, AFK, pacing: what you are looking for (read this first)
Needs playtest (written without Studio). See `docs/HUD_LAYOUT.md` for the slot map.
1. Top centre: tiles + timer only. Directly below: ONE line (mission bar, or a banner for 3 s replacing it). Meteor warnings, RANK UP, MEGA MOG all share that line, never stacked.
2. Entering a territory shows a small card for 1.5 s just below the mission bar, only on a real new entry. Unlock and achievement cards wait their turn.
3. Left: aura box, a small "Quests 0/3" pill (tap to open), the combo counter beside it, aura pop-ups (max 3) underneath. Right: a smaller minimap. The middle of the screen stays clear. No "MOST AURA" banner; the leader wears the tag in the world.
4. AFK after 30 s idle: tag over the head, no passive ticks, cannot hold a flag; back at your island after 3 minutes.
5. Pacing (active): Rookie about 1 min, Sigma 10 min, Chadlite 30 min, Chad 1 hr, Gigachad 3 hr, Mog God I about 72 hr. An idle player stops at Rookie X after about an hour. `python3 tools/pacing_sim.py` prints the model; `luau tests/Pacing.test.luau` checks it.

---
# Visual pass, Brainrot Bog, Cooked Canyon, spawn islands: what you are looking for (read this first)
Needs playtest (written without Studio).
1. **Bog:** moss patches over the mud, boardwalks toward the brain from the north-west and south-east with green lanterns, reeds and frogs by the ponds, glowing green, magenta and cyan mushrooms, hanging moss on the dead trees, green glows with fireflies. The brain is no longer shiny plastic.
2. **Canyon:** dark cracked rock and packed earth patches on the red floor, cacti, stone paths to the stepping stones, wagons, rails, barrels and torch posts, bones and a skull, fire under the pan, bacon beside the egg, giant salt and pepper shakers and a spatula, hot orange glows along the lava river.
3. **Spawn islands:** a cobble path from the spawn pad toward the middle of the map, lantern posts at the pad corners, flower beds, a fence, trees, bushes, flowers and fireflies, plus the mascot statue and NPC.
**Check:** nothing blocks a spawn pad, lift, launch pad or the Bog and Canyon lifts and routes; Moglings can still reach the brain and the pan.

---
# Flags, lighting, team mascots: what you are looking for (read this first)
Needs playtest (written without Studio). Screenshot each spawn island and a few flags from far away.
1. **Flags** from another island: a tall pole with a big waving cloth in the owner's colour (white while neutral), a tall light beam (it pulses while contested), a pie of coloured spokes on the ground that fills as a team captures, and a flag icon with the capture percent that shows through walls within about 150 studs. When a flag changes owner the cloth whips, the colour changes and confetti bursts.
2. **Lighting:** a lower sun with longer shadows, violet-blue shade (cool fill), only neon and beams bloom, soft sun rays. Walking into the Bog (green), Canyon (orange), Rizz Ravine (pink sparkle), Lighthouse (cool sea) and Chud Chambers (dim, torchlit) blends the mood over 2 seconds. On a phone emulator the sun rays are off.
3. **Mascots:** each spawn island has a giant statue beside the spawn pad (red lion with a huge square jaw, blue owl meditating with its beak pressed shut, yellow-scarf wolf in sunglasses, purple glowing phoenix) on a plinth with two team banners, and a small mascot NPC that bobs, waves when you walk within about 30 studs, and hops, spins and throws confetti for 5 seconds when its team captures a territory.
4. **Team tiles** at the top show 🦁 🦉 🐺 🔥 instead of letters.
**Check first:** the statue and NPC positions (they might overlap a launch pad or a lift on a spawn island), whether the owl and wolf read well from the spawn pad, and how heavy the extra flag parts feel on a phone.
**Tune:** `STRIPS`, `SPOKES` and the beam size in `FlagVisuals.luau`; moods in `MoodController.luau`; `Lib/IslandTerrain.luau` for the base lighting; positions in `MascotSystem.luau`.

---
# Visual pass, Locked-In Lighthouse (fourth island): what you are looking for (read this first)
Needs playtest (written without Studio). View from the pier, the door path and the gallery.
1. A sandy shore with rock patches, pebbles, dune grass and a few windswept trees (no bare grey rock round the tower).
2. A pebble path from the door to the base flag and on toward the bridge; a plank pier on the south shore with lantern posts and a red-striped rowboat.
3. Shore clutter: barrels, crate stacks, lobster pots, red and white buoys, driftwood, a net, rope coils and a big anchor by the door.
4. The tower has glowing windows up its side, stone door posts with lanterns, pennants on the gallery rail.
5. The padlock (the hero) has a LOCKED IN plaque, gold rivets and a glowing keyhole; the turning beam still sweeps.
6. The lighthouse lifts, the cellar lift and both flags still work; nothing blocks the door.

---
# Visual pass, Rizz Ravine (third island): what you are looking for (read this first)
Needs playtest (written without Studio). View from the western hill, the bridge and under the heart.
1. The cliff tops and the western hill are PINK grass (not green); pink strata on the cliffs as before.
2. Plank paths run from the hill to each flag and from each flag to the bridge; a red torii gate stands at each bridge end; pink-lit lantern posts, flower beds round both flags, rocks, bushes.
3. Cherry-blossom trees along the cliff edges, petals drifting down, fireflies over the flags.
4. Ravine floor: a shallow stream, lily pads, pebbles, flowers on the floor.
5. The giant heart is glossy (foil) with a pink bow and gold knot on top and its sparkles.
6. The jump pads, the heart walk-through and the secret ledge stash still work; nothing blocks the bridge ends.
**Not done yet:** MaterialVariants, Creator Store kits, real meshes. See ART.md.

---
# Visual pass, NPC Village (second island): what you are looking for (read this first)
Needs playtest (written without Studio). View from the plaza, a house front, and the statue.
1. Houses: timber framing, door awnings, shutters, a flower box under the window, chimneys; one-storey houses have pitched coloured roofs with a ridge and stepped gables (nobody can stand on them); two-storey houses keep the flat roof deck (the rooftop stash is still there).
2. Plaza: a cobble square with market stalls (striped awnings, fruit baskets), a hand cart, lantern posts, cobble paths to every door, picket fences, flower beds, bushes, trees round the edge, grass patches round the rim.
3. Statue (the hero): plinth, carved eyes, brows, nose, mouth, ears, shoulder pads, belt and buckle, hands, moss, vines, cracks and block lines. Check the bubble lift at the statue's foot still carries you to the head plate and drops you onto it.
4. Well: little roof and bucket. The secret room under it still works with its lift out.
5. Fireflies and drifting leaves. Nothing blocks the house doors or the lift pads.
**Check:** the loss of the flat roofs on one-storey houses (Moglings and players used to jump onto them); tell me if you miss them.

---
# Visual pass, Gigachad Gate (first island): what you are looking for (read this first)
Needs playtest (written without Studio). Compare with your reference images from three angles (front gateway, a tower, the back courtyard).
1. The face has cheekbones, brow ridges, lips, a chin, sideburns and an amber gleam behind the sunglasses; the jaws have brick lines.
2. A cobble path runs from the gateway to the mouth tunnel, with a cross path to both towers; lantern posts line it (every other one glows with a real light).
3. Flower beds (stone-edged, mixed colours), bushes, barrels, crate stacks and pebbles in both courtyards; flowers and tufts round the island rim.
4. Towers: corner buttresses with gold caps, glowing window slits, brick lines.
5. Fireflies over the gardens and drifting leaves by the towers.
6. Nothing blocks the gateway, the mouth tunnel, the tower doors or the lifts; Moglings still reach the tower flags.
**Not done yet:** MaterialVariants (needs Studio), Creator Store kits, generated hero meshes, real PBR. See ART.md.

---
# Name signs, ENTERING cards, minimap: what you are looking for (read this first)
Needs playtest (written without Studio).
1. **Letters:** each island has its name in big blocky letters on a rock plinth at its far rim, facing the middle of the map, in its own style: Gate stone, Rizz glowing pink, Canyon dark rock with lava seams, Lighthouse red and white stripes, NPC Village coloured wood blocks, Bog slimy green. Chud Chambers has snack-bag letters high on the hall's south wall. Check they read left to right (not mirrored) from the middle of the map.
2. **Arches:** a stone arch with lanterns and a wooden plaque with the name, where you arrive from the middle of the map.
3. **ENTERING card:** crossing into any territory slides "⚔ ENTERING <NAME>" in for 2 s, outlined in the owner's team colour; smaller the second time. The cave says CHUD CHAMBERS, not Gigachad Gate.
4. **Minimap:** top right, below the top bar; Roblox's player list is hidden. Islands recolour as teams capture; flags are diamonds; you are an arrow turning with the camera; teammates are dots; a pulsing ring is your mission flag; a crate icon for supply drops; a comet for the meteor. The coloured "map control" bar above it splits by territories held with a crown over the leader.
5. **Big map:** tap the map or press M: a near-fullscreen map with the names. You can still walk. Tap or M closes it.
**Tune:** letter size is `pixel` in `src/server/Lib/TerritorySigns.luau`; map size is the numbers in `MinimapHud.luau`.

---
# Chud Chambers trap dungeon: what you are looking for (read this first)
Needs playtest (written without Studio). No trap hurts: you get knocked back, flung, or slimed ("TRAPPED!", green glow, 2 s hold, then back to the shaft entrance). Each trap glows or shakes about a second before it fires. Sound ids are empty in `Pace.traps.sounds`, so everything is silent for now.
1. **Boulder:** a striped yellow lane across the hall (south side). Step on the yellow plate: it turns red, the red CHUD CRUNCH bag shakes, then rolls the length of the lane. Dodge sideways.
2. **Swinging chairs:** three red gaming chairs on chains in the north tunnel, swinging across the whole width on a 3 s rhythm; the glow gets brighter at the ends of the swing.
3. **Can avalanche:** west tunnel to the Snack Hoard. A blue plate at the tunnel mouth; cans rattle on the ceiling, then drop and knock you back into the hall unless you sprint through.
4. **Pizza floor:** east tunnel to the Gamer Throne. Tiles turn orange and shake, then some drop into an orange goo pit (one tile per row always stays). Four bubble lifts in the pit float you back up to the hall side.
5. **Laser grid:** the corridor south of the Gamer Throne room. Three rainbow beams sweep slowly; jump them. A hit means "TRAPPED!" and back to the corridor start.
6. **Mimic fridges:** one in the Snack Hoard (west side) and one in the Throne room; get close and its red eyes appear, then it chomps and spits you away.
7. **Treasure room:** end of the laser corridor, golden chest, hold E: big aura burst, once per war.
8. **TRAP SHOVE!** Shove a player into any trap (within 6 s): you get a banner and aura.
9. **Chud flags** pay 1.5x aura.
**Check Moglings:** they should wander into traps now and then (funny) and still capture. If they get stuck in the goo pit or never cross the pizza floor, tell me.
**Tune:** `Pace.traps`, and the numbers in the TRAP DUNGEON block at the end of `ChudChambers.luau`.

---
# Bubble lifts: what you are looking for (read this first)
Needs playtest (written without Studio). Every old staircase, spiral and ladder is now decoration with a glowing bubble lift beside it: a flat glowing pad on the floor and a faint tube of rising bubbles.
1. Walk onto each pad: you float smoothly along the tube, then walk off at the top. Try: Gigachad Gate tower flights (four chained lifts), NPC statue (one big lift to the head), the NPC house stairs, the Lighthouse spiral, Chud Chambers spiral and rope ladder, the well and the Lighthouse cellar ladders.
2. Chud Chambers courtyard hatch: step onto the hatch hole, a green chute lowers you gently into the cave.
3. Moglings should ride a lift when their route walks over the pad. If one stands below a high flag forever, tell me which flag (their routes were built for ramps).
4. Phone emulator: nothing to press, lifts work by walking in.
**Tune:** `SPEED` and `ENTRY_RADIUS` at the top of `src/server/Systems/LiftSystem.luau`.

---
# Big numbers, Aura Meteor, Supply Drops: what you are looking for (read this first)
In Studio press Play; the Output says "Studio debug commands on". Type these in the chat:
`/mog level 25`, `/mog gigachad`, `/mog mogod`, `/mog mogstar 5`, `/mog aura 1e9`, `/mog meteor`, `/mog drop`, `/mog gold`. They do nothing in a live game.
1. **Formatter.** At Gigachad and Mog God the aura counter reads like 1.23K / 4.56M / 7.80T / 1.10aa / 35.8ab, always 3 digits, and rolls up smoothly. Crossing a suffix flashes "NEW TIER: B!" under the counter.
2. **Levels.** Rank shows "ROOKIE III", "MOG GOD X", "MOG GOD ★5". Every level-up shows "LEVEL UP! x1.74 AURA"; each 10th level is the big RANK UP banner. A fresh player levels about every minute at first.
3. **Income scaling.** `/mog mogod` then stand on a flag: the +X ticks are trillions per second. Stash, quest, crit and chest rewards are big too (they are seconds of income).
4. **Fairness.** Your Shove, Dash and capture speed feel the same at level 0 and at Mog God ★5.
5. **Aura Meteor** (`/mog meteor`, or half way through each war): purple sky, a banner "AURA METEOR INCOMING - 15s", a marker with a purple ring on the landing island, a meteor streak, a boom with screen shake and a white flash, a ring of aura orbs, then a "METEOR FLAG x5" for you and the Moglings to fight over. The team holding it 20 seconds in total gets a big aura burst and "METEOR CLAIMED BY RED!". Then it crumbles. There is no minimap in the game yet, so the marker and banner are the guides.
6. **Supply Drops** (`/mog drop`, `/mog gold`, or every ~45s in a war): a crate on a balloon with coloured smoke (gold smoke for gold). Hold E (hold the button on a phone) for 1.5s; get shoved and it cancels. Confetti, then aura / Main Character Mode / Protein Shake / a free trail or title.
**Needs playtest:** everything here (this was written without Studio). No sound ids are set in `Pace.sounds`, so alarm, boom and pop are silent until you add ids. Tune: `Pace.levels`, `Pace.meteor`, `Pace.drops`.

---
# Abilities, stealing, dopamine, rifts, ziplines: what you are looking for (read this first)
Studio must have **Mog War 3** open. Cheat ranks with the server console (set the player's Aura attribute) to reach each ability quickly.
1. **Top HUD.** Four chunky team tiles (colour gradient, white border, shadow, round letter badge, "3/7", a row of pips, a crown over the leader, a pulse when that team captures); a round timer in the middle with "WAR 1" small and a ring that drains, pulsing red in the last minute; under it a dark navy pill with a yellow border, a yellow flag circle, "CAPTURE" and the territory name, and a white "115m ➜" chip; it turns red with "DEFEND ...!" when your territory is attacked. Nothing overlaps Roblox's top-left buttons.
2. **Abilities.** Shove plus your TWO newest only (Q and R on PC, bottom right on phone), each with a cooldown cover that shrinks. Slam knocks back everyone within 10 studs; Flip pushes a cone of enemies back; Shield makes you immune for 3 seconds with a gold bubble (shoves say BLOCKED!); Total Mog greys out enemies within 20 studs for 2 seconds and they cannot capture. Each gets its unlock card the first time.
3. **Stealing.** Shove someone off an island: "YEET!", they drop 6 glowing orbs that fly to whoever is near ("+N STOLEN!" in purple); they see "-N aura". Freeze someone with Mog Stare and then shove them: same. The aura leader gets a crown, a tall beam and "MOST AURA"; knocking them off says "BOUNTY CLAIMED!". The results screen shows aura stolen.
4. **Dopamine.** Small ticks every second; MEGA MOG! / ULTRA MOG! now and then (banner, flash, big number); combos ("COMBO x3") with a glowing screen edge and "Combo ended +240"; three mini-quests under the aura box that tick and pay; achievement cards sliding in from the right; the rank bar sparkles at each 10% and shows "Mog Stare unlocks in 120 aura!"; after the results a war chest drops, shakes and pops open. Count how often something rewarding happens in 3 minutes (the goal: something every 2-3 s, something bigger every ~30 s).
5. **Ziplines (both ways).** Walk onto a zipline platform or press E: you are carried along the cable with speed lines and a wider view, and let go at the end (jump to let go early). Try every one in both directions, on PC and a phone emulator.
6. **Rifts.** Seven purple-and-gold portals (beside each spawn, two on far islands, under the Gate by the rope-ladder walkway). Touch one: you shoot up, then glide down with a small glider and steer with normal movement; the rift flickers out for 20 seconds. Moglings use them too.
7. **Gate and Rizz.** Walk all the way round the Gate: the back has a courtyard wall with its own gateway, gold pillars with torches, banners, tower banners on every face, hair ridges and ears on the head. Rizz Ravine: layered pink cliffs, a plank bridge with rope rails and hanging lanterns, the heart in the middle, flowers on the cliffs, a waterfall into the ravine.
**Not built yet:** airship taxis, tank mode, music and sounds (no licensed ids), slow-motion and hit-stop, phone haptics (Roblox has no phone vibration), more foliage and birds.

---
# Fast start, abilities, mission bar, Moglings, stashes: what you are looking for (read this first)
Make sure Studio has **Mog War 3** open (not Place1) and the Rojo plugin is connected to it. To be a brand new player, delete your saved data or join with a fresh account.
1. **First 10 seconds.** A card "MOG POWER UNLOCKED: SHOVE!" with a white flash, confetti and a little demo (a figure bonks another). After ~3 seconds it goes away and you are in the war. FAIL: no card, or it never closes.
2. **Mission bar.** Under the scoreboard: one line like "Capture NPC Village - 120m", plus glowing dots on the ground toward that flag. Stand on the flag: "Hold the flag!". When an enemy is capturing one of yours: "Defend ...!". FAIL: the bar is empty or covers the scoreboard.
3. **Constant +X.** Small cyan "+1" (and +3, +4...) ticks appear every second under the aura counter (top left), never in the middle. About a minute on a flag takes you to Rookie.
4. **Rookie = Dash.** On ranking up you get a RANK UP banner and a "DASH!" card; a green DASH button (key Q) appears next to SHOVE; 4 second cooldown. **Sigma = Mog Stare** (blue STARE button, key F): a quick beam, the nearest enemy in front freezes for 1 second; 8 second cooldown.
5. **Announcer.** Banners like "JAWLINE LEGION is capturing Rizz Ravine!", "YOUR TEAM took Gigachad Gate!", and at 1 minute left "1 MINUTE LEFT - DOUBLE AURA!" (the timer pulses red and aura doubles).
6. **Moglings.** Fillers show a name tag like "Mogling Jeff", have blocky bodies in their team colour, walk with swinging arms and legs, go to flags, shove you, and dash. The word BOT appears nowhere. FAIL: any "BOT" text.
7. **Stashes.** 12 hidden glowing crates (behind the Gate and Rizz waterfalls on ledges, the NPC Village roof, under the west and east bridges, and the secret rooms). Each gives +100 aura once per war. "Stashes found 3/12" under the aura counter. You must not get stuck on a crate (they are not solid).
8. **Launch pads and ziplines.** Pink pads near island rims throw you to the next island (you land on it, no WHOOSH). Ziplines from the Gate island rim down to the other islands: hold the prompt on the handle and ride; jump to let go.
9. **Rebuilt places.** Locked-In Lighthouse: a round, tapered red/white tower with a gallery balcony, a golden padlock lamp room on top, rocky base, spiral stairs inside (walk all the way up). Cooked Canyon: layered red rock cliffs with coloured strata bands, glowing lava river, rock bridges, the giant frying pan with a fried egg, steam and embers.
10. **Grass.** If the grass is still tall and neon: in Studio select Workspace > Terrain and untick **Decoration**, then save the place (a script cannot always do it). Output prints a warning if so.
**What to tune first:** `Pace.presence` (the +X rates), `EconomyConfig.ranks` (Rookie 150), `Pace.abilities`, `Pace.stash`, `Pace.zipline`, `Pace.speed`.

---
