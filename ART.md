# Mog Wars art style guide

The goal: cosy, detailed, warm sky-islands, like the reference images. Chunky and a little rounded, never plain boxes.
Every builder follows this file. When in doubt, add one more layer of detail, not one more flat surface.

## Light and mood
- **Golden hour** everywhere above the clouds: low warm sun, peach haze, soft bloom, a slightly warm colour grade (set in `IslandTerrain.lighting()`; Future lighting). No depth of field (phones).
- **Dim and torch-lit** only inside caves and dungeons (Chud Chambers): warm torches, glowing mushrooms, bright warning colours on traps.

## Palette
| Use | Colours |
|---|---|
| Grass | saturated, slightly warm greens: `(110,190,70)`, `(150,205,80)`, `(80,160,70)`; never neon |
| Woods | warm browns: `(176,128,74)`, `(120,84,52)`, `(150,105,62)` |
| Stone | warm greys, never blue-grey: `(150,142,134)`, `(128,122,134)`, dark `(96,90,90)` |
| Roofs | coloured per island: NPC Village terracotta/orange, Lighthouse red, Rizz Ravine pink, Canyon deep red-brown, Bog moss green, Gate purple and gold |
| Accents | lantern amber `(255,190,90)`, gold `(255,200,60)`, flower colours (red, yellow, pink, violet, white) |
| Faction colours | ONLY on flags, banners and team gear. Never on terrain, roofs or props |

## Island ground palettes
NPC Village: grass + cobble paths. Brainrot Bog: mud + moss + lily pads. Cooked Canyon: red sand + cracked rock. Rizz Ravine: pink grass + petals. Lighthouse: sand + pebbles. Gigachad Gate: cobble plaza, flower beds and clipped bushes. Chud Chambers: dark stone, goo and neon.

## Materials (world geometry)
Wood, WoodPlanks, Cobblestone, Slate, Brick, Rock, Basalt, Grass, Sand, Mud, Fabric, Metal, Marble, Glass, Neon (glow only).
**No SmoothPlastic or Plastic on world geometry.** Use `MaterialVariant`s (PBR) for wood, stone, roof tiles and grass once they exist (see Assets below).

## Shape rules
1. Chunky: nothing thinner than 0.4 studs except ropes and cables; props are slightly oversized.
2. Slightly rounded: prefer balls, cylinders and tilted slabs to bare cubes for foliage, rocks, barrels, lanterns.
3. No plain untextured boxes: every wall gets trim, buttresses, window slits or brick courses.
4. No flat empty area larger than a few studs: layer ground variety -> props and clutter -> foliage -> lighting accents -> particles.
5. Rocky island undersides with hanging roots and vines; waterfalls off edges; cloud wisps between islands.
6. Hero landmark on each island is the most detailed thing there.

## Layer recipe for an island pass
1. Ground: paths (cobble/dirt/planks), colour patches. 2. Props: barrels, crates, carts, fences, rocks, logs. 3. Foliage: bushes, flowers, tufts, mushrooms. 4. Light: lantern posts, torches, glowing mushrooms. 5. Particles: fireflies, leaves, steam, bubbles (few, capped).
Shared helpers live in `src/server/Lib/Detail.luau`; use them rather than hand-placing parts.

## Performance
Anchor everything. Merge repeated detail into few parts; scatter functions cap their counts. Particle rates stay under 8 per emitter. Point lights are few and short range. Not using StreamingEnabled yet: server zones, the minimap and the mission bar read parts from the whole map, so streaming must be tested before it is turned on.

## Assets log (Creator Store inserts)
Nothing inserted yet. The cloud session cannot reach the Creator Store; inserts happen through Studio MCP on the Mac.
Rules for every insert: delete every Script, LocalScript and ModuleScript inside; check all descendants for hidden or oddly named scripts and `require` calls; keep only static Parts and MeshParts; log it here.
| Asset | Creator | Date | What was removed | Used on |
|---|---|---|---|---|
