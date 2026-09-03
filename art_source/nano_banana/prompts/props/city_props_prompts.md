# Nano Banana 2 Prompts: City Props / Resource Nodes

## Asset Specifications
- **Category**: City Resource Props
- **Canvas Size**: 
  - Abandoned car: 256x192 px (ground contact bottom-center at `(128, 192)`)
  - Vending machine, Scrap pile, Loot crate: 128x192 px (ground contact bottom-center at `(64, 192)`)
- **Camera/Projection**: Fixed 2:1 game-isometric view, orthographic
- **Style**: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite
- **Output**: Transparent background with real alpha, no baked drop shadows, upper-left lighting

---

## Prompts

### 1. Abandoned Car (`abandoned_car_01.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: rusted abandoned sedan car, smashed windows, missing front tire, peeling teal-gray paint, scavenging resource.
VIEW: Orthographic 2:1 game-isometric, angled facing South-East, fixed camera matching Image A.
COMPOSITION: One isolated vehicle, centered on a 256x192 canvas, tire contact points aligned with baseline at bottom-center (128, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, weathered industrial metals, desaturated palette with rust accents.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: road, environment, border, text, logo, UI, extra objects, cropped parts, watermark.
```

### 2. Broken Vending Machine (`broken_vending_machine_01.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: damaged retro vending machine, shattered glass display, exposed wires and circuit boards, scavenging electronics resource.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated vending machine cabinet, centered on a 128x192 canvas, bottom base contacting ground at exact bottom-center (64, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated vintage red and steel gray with glowing wire accents.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: environment, floor, border, readable brand text, logo, UI, watermark.
```

### 3. Scrap Metal Pile (`scrap_pile_01.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: dense heap of salvageable scrap metal, bent steel pipes, metal plates, rusty gears and bolts.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated scrap metal mound, centered on a 128x192 canvas, base footprint contacting ground at exact bottom-center (64, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, oxidized iron, scratched metal and industrial grays.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: environment, floor plane, border, text, logo, UI, watermark.
```

### 4. Military Loot Crate (`loot_crate_01.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: rugged military supply crate, reinforced steel corners, latches, stenciled hazard markings, harvestable ammo/medical cache.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated supply crate, centered on a 128x192 canvas, base contacting ground at exact bottom-center (64, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, olive drab and industrial yellow accents.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: environment, floor plane, border, text, logo, UI, watermark.
```
