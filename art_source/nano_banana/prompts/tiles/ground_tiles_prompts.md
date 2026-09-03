# Nano Banana 2 Prompts: Ground Tiles (Grass, Dirt, Asphalt)

## Asset Specifications
- **Category**: Ground Tiles
- **Canvas Size**: 128x64 px
- **Isometric Cell Center Pivot**: `(64, 32)`
- **Diamond Vertices**: Top `(64, 0)`, Right `(127, 31)`, Bottom `(64, 63)`, Left `(0, 31)`
- **Camera/Projection**: Fixed 2:1 game-isometric view, orthographic
- **Export Files**:
  - `ground_grass_01.png`
  - `ground_dirt_01.png`
  - `ground_asphalt_01.png`

---

## Prompts

### 1. Grass Tile (`ground_grass_01.png`)
```text
ROLE: Create one production ground tile for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: overgrown wild grass tile, subtle mossy patches, sparse dry weeds, cool muted green tone.
VIEW: Orthographic 2:1 game-isometric diamond, fixed camera matching Image A.
COMPOSITION: One isolated diamond tile fitting exactly in 128x64 canvas, four diamond vertices at (64,0), (127,31), (64,63), (0,31), center at (64,32).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated cool environment palette, low visual contrast.
OUTPUT: Transparent background outside diamond boundary with real alpha, seamless tiling edges, no baked drop shadow.
MUST NOT INCLUDE: character, prop, building, text, UI, border frame, watermark.
```

### 2. Dirt Tile (`ground_dirt_01.png`)
```text
ROLE: Create one production ground tile for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: dry packed earth and dirt ground tile, small pebbles, dry cracked soil texture, muted brown tone.
VIEW: Orthographic 2:1 game-isometric diamond, fixed camera matching Image A.
COMPOSITION: One isolated diamond tile fitting exactly in 128x64 canvas, four diamond vertices at (64,0), (127,31), (64,63), (0,31), center at (64,32).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated earth palette, low visual contrast.
OUTPUT: Transparent background outside diamond boundary with real alpha, seamless tiling edges, no baked drop shadow.
MUST NOT INCLUDE: character, prop, building, text, UI, border frame, watermark.
```

### 3. Asphalt Tile (`ground_asphalt_01.png`)
```text
ROLE: Create one production ground tile for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: weathered cracked asphalt road tile, dark slate gray, subtle road aggregate texture, decaying urban pavement.
VIEW: Orthographic 2:1 game-isometric diamond, fixed camera matching Image A.
COMPOSITION: One isolated diamond tile fitting exactly in 128x64 canvas, four diamond vertices at (64,0), (127,31), (64,63), (0,31), center at (64,32).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated cool slate palette, low visual contrast.
OUTPUT: Transparent background outside diamond boundary with real alpha, seamless tiling edges, no baked drop shadow.
MUST NOT INCLUDE: character, prop, building, text, UI, border frame, watermark.
```
