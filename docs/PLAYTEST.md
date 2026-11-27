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
