# Nano Banana 2 Prompts: Base Defense Structures

## Asset Specifications
- **Category**: Base Defense Structures
- **Canvas Sizes**:
  - `barricade_wood`: 128x192 px (ground contact bottom-center at `(64, 192)`)
  - `barricade_metal`: 128x192 px (ground contact bottom-center at `(64, 192)`)
  - `turret_basic`: 128x192 px (ground contact bottom-center at `(64, 192)`)
  - `base_core`: 256x320 px (ground contact bottom-center at `(128, 320)`)
- **Camera/Projection**: Fixed 2:1 game-isometric view, orthographic
- **Style**: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite
- **Output**: Transparent background with real alpha, no baked drop shadows, upper-left lighting

---

## Prompts

### 1. Wooden Barricade (`barricade_wood.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: reinforced wooden barricade wall, thick crossed timber logs, heavy rope lashing, barbed wire trim, defensive fortification.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated defensive barricade, centered on a 128x192 canvas, base contacting ground at exact bottom-center (64, 192), solid defensive silhouette.
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, weathered dark pine wood, steel wire accents.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, border, text, logo, UI, extra objects, cropped parts, watermark.
```

### 2. Metal Barricade (`barricade_metal.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: heavy reinforced steel barricade wall, welded scrap metal plates, corrugated iron, reinforced steel struts, heavy fortification.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated defensive metal wall, centered on a 128x192 canvas, base contacting ground at exact bottom-center (64, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, scratched industrial slate metal, rust and weld seam accents.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, border, text, logo, UI, watermark.
```

### 3. Basic Sentry Turret (`turret_basic.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: automated sentry defense turret, tripod mount base, swiveling dual machine gun barrels, ammo drum, targeting sensor camera with red optic lens.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated sentry turret, centered on a 128x192 canvas, tripod legs contacting ground at exact bottom-center (64, 192).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, dark military gunmetal gray with red optical lens accent.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, border, text, logo, UI, muzzle flash, watermark.
```

### 4. Base Core Generator (`base_core.png`)
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: fortified survival base core reactor generator, 2x2 large footprint, heavy armored housing, cooling conduits, hum energy containment chamber with cyan-blue glow, terminal console.
VIEW: Orthographic 2:1 game-isometric, fixed camera matching Image A.
COMPOSITION: One isolated large core machine, centered on a 256x320 canvas, bottom front footprint contacting ground at exact bottom-center (128, 320).
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, heavy industrial charcoal metal, vibrant cyan containment glow.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, border, text, logo, UI, watermark.
```
