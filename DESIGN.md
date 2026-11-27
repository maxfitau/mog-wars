# Mog Wars — Design Brief (v0.2, the simple game)

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
1. Join: you are placed on one of 4 auto-balanced teams (Jawline Legion, Mewing Order, Sigma Syndicate, Aura Collective) and spawn on War Island. Bots fill every war to at least 8 fighters; they are removed one at a time as real players join.
2. A big arrow points to the nearest Gold flag: "Stand here to capture!". That is the whole tutorial.
3. Stand on a flag to capture it. More teammates on the flag capture it faster (each extra +25%, up to double). Gold flags take 4 seconds, Diamond 6, Ultra 8 (one player alone).
4. A team owns a territory when it holds ALL of its flags.
5. **Shove** is the only way to fight: one big button on mobile, E or click on PC. A short knockback with a funny "BONK!" pop-up, 1.5 second cooldown. Bots shove too.
6. Aura goes up all the time, with big number pop-ups: +1 every second you stand on a flag you are capturing, +25 for every flag captured, a bonus when a territory is captured (Gold +100, Diamond +300, Ultra +1000), and a small trickle every minute while your team holds territories.
7. Ranks are earned by total aura, automatically: NPC, Rookie, Sigma, Chadlite, Chad, Gigachad, Mog God. A rank never goes down. It changes only your glow, title and name colour.
8. Wars are 6 minutes. The last thing you see is a quick 5-second results screen (winning team, MVP of each team), then the next war starts straight away.
9. A daily reward streak (7 days, aura) and a cosmetic shop (aura colours, trails, titles) stay.

## HUD (three things)
- Top left: your aura and rank, with a bar toward the next rank.
- Top centre: the war timer and the four team scores, and the capture bar when you stand on a flag.
- Bottom right: the big shove button.
(Plus the small Shop button, a Daily reward button that only shows while a reward is waiting, and the "Stand here to capture!" arrow for new players.)

## Territories
Six territories, ten capture flags, all on War Island. Names, positions, flag counts and rewards live in one settings file (`src/shared/Territories.luau`). Each is a big landmark you can see from anywhere on the island, with an inside (rooms, tunnels, stairs, rooftops), flags in exciting spots, its own colours, ground and particles, a secret spot with a free Aura Stash (a little aura), and plenty of cover. Built from simple parts and Terrain; no Toolbox models.
- Centre: **Gigachad Gate** (Ultra, 3 flags). A giant stone face with sunglasses; its mouth is a tunnel you walk through; inside the head is a throne room; two towers with spiral stairs and a flag on each roof.
- **Rizz Ravine** (Diamond, 2 flags). A deep pink ravine with a rope bridge, a flag on each cliff top, and a giant hollow balloon-heart over the bridge with jump pads either side.
- **Locked-In Lighthouse** (Diamond, 2 flags). A striped lighthouse on a rocky island in a moat; a spiral staircase inside; the base flag is by the door and the top flag is in a golden-padlock lamp room with a turning beam.
- **NPC Village** (Gold, 1 flag). A blocky village of enterable houses and a giant grey NPC statue climbed by wooden scaffolding; the flag is on its head; a secret room under the well.
- **Brainrot Bog** (Gold, 1 flag). A foggy green swamp with lily pads and dead trees; a giant hollow pink brain with fleshy tunnels; the flag is in its centre; a hollow log is the secret.
- **Cooked Canyon** (Gold, 1 flag). A red canyon with a lava river and rock jumps up to a giant frying pan; the flag is in the egg yolk; a cave behind a lava fall is the secret.
- Faction spawns are in the 4 corners. Dirt paths, with speed pads on them, join the bases to the territories.
- Small name signs over each landmark fade in only when you are close.

## Switched off (built, hidden, behind flags in `src/shared/Features.luau`)
Weapons and combat (aura blasters, ego, mogging, kill feed), mog-off duels, Training Island and every training station, loot boxes, units (tanks and horses), pickups, dash, discovery cards, overtime, seasons, the old Mog Points currency, the squad bonus, prestige and the skill tree, and the Mog Arena tycoon. Flip a flag to bring a feature back; nothing was deleted. The older designs for them are in `docs/` and in the git history.

## Version 1 scope
One map per server, 6 territories, 4 auto-balanced teams, 6-minute wars that reset, join mid-war anytime. Max server size 16.

## Money (cosmetic only)
Aura colours, trails, titles, and later extra cosmetics. Never power.
