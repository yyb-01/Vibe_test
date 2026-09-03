# Nano Banana 2 Prompts: Zombie Enemies (8-Directional Idle Sprites)

## Asset Specifications
- **Category**: Enemy Entity Sprites (CharacterBody2D)
- **Canvas Size**: 128x128 px
- **Ground Contact Pivot**: Bottom-center at `(64, 128)`
- **Camera/Projection**: Fixed 2:1 game-isometric view, orthographic
- **Directions (8-Way)**: East (E), South-East (SE), South (S), South-West (SW), West (W), North-West (NW), North (N), North-East (NE)
- **Style**: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite
- **Output**: Transparent background with real alpha, no baked drop shadows, upper-left lighting

---

## 1. Basic Walker Zombie (`zombie_basic`)

### Template Prompt Formula
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: ragged shambling zombie infected walker, torn civilian clothes, decaying gray-green skin, glowing red eye accents, idle feral stance.
VIEW: Orthographic 2:1 game-isometric, facing [DIRECTION_NAME], fixed camera matching Image A.
COMPOSITION: One isolated character, centered horizontally on 128x128 canvas, feet contacting ground at exact bottom-center (64, 128), clear readable silhouette.
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated cool sickly green and ragged cloth palette.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, floor tiles, weapons, border, text, logo, UI, extra characters, cropped parts, watermark.
```

### 8 Direction Prompts
- **South (`idle_s`)**:
  `ROLE: Create one production candidate for a Godot 4 2D isometric survival game. REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting. SUBJECT: ragged shambling zombie infected walker, torn civilian clothes, decaying gray-green skin, glowing red eye accents, idle feral stance. VIEW: Orthographic 2:1 game-isometric, facing South directly towards camera, fixed camera matching Image A. COMPOSITION: One isolated character, centered horizontally on 128x128 canvas, feet contacting ground at exact bottom-center (64, 128), clear readable silhouette. STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated cool sickly green and ragged cloth palette. OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow. MUST NOT INCLUDE: ground plane, environment, floor tiles, weapons, border, text, logo, UI, extra characters, cropped parts, watermark.`
- **South-East (`idle_se`)**:
  `... facing South-East (down and right along isometric axis) ...`
- **East (`idle_e`)**:
  `... facing East (directly right) ...`
- **North-East (`idle_ne`)**:
  `... facing North-East (up and right along isometric axis) ...`
- **North (`idle_n`)**:
  `... facing North directly away from camera ...`
- **North-West (`idle_nw`)**:
  `... facing North-West (up and left along isometric axis) ...`
- **West (`idle_w`)**:
  `... facing West (directly left) ...`
- **South-West (`idle_sw`)**:
  `... facing South-West (down and left along isometric axis) ...`

---

## 2. Brute Runner Zombie (`zombie_brute`)

### Template Prompt Formula
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: mutated massive brute runner zombie, heavily muscled hunched torso, thickened mutated gray-slate flesh, bone spikes on shoulders, ferocious predatory stance.
VIEW: Orthographic 2:1 game-isometric, facing [DIRECTION_NAME], fixed camera matching Image A.
COMPOSITION: One isolated large muscular brute infected, centered on 128x128 canvas, heavy feet contacting ground at exact bottom-center (64, 128), broad hulking silhouette.
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, slate gray skin with bruised purple veins and glowing red eyes.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow.
MUST NOT INCLUDE: ground plane, environment, floor tiles, weapons, border, text, logo, UI, extra characters, cropped parts, watermark.
```

### 8 Direction Prompts
- **South (`idle_s`)**:
  `ROLE: Create one production candidate for a Godot 4 2D isometric survival game. REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting. SUBJECT: mutated massive brute runner zombie, heavily muscled hunched torso, thickened mutated gray-slate flesh, bone spikes on shoulders, ferocious predatory stance. VIEW: Orthographic 2:1 game-isometric, facing South directly towards camera, fixed camera matching Image A. COMPOSITION: One isolated large muscular brute infected, centered on 128x128 canvas, heavy feet contacting ground at exact bottom-center (64, 128), broad hulking silhouette. STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, slate gray skin with bruised purple veins and glowing red eyes. OUTPUT: Transparent background with real alpha, clean edge colors, no baked ground shadow. MUST NOT INCLUDE: ground plane, environment, floor tiles, weapons, border, text, logo, UI, extra characters, cropped parts, watermark.`
- **South-East (`idle_se`)**:
  `... facing South-East (down and right along isometric axis) ...`
- **East (`idle_e`)**:
  `... facing East (directly right) ...`
- **North-East (`idle_ne`)**:
  `... facing North-East (up and right along isometric axis) ...`
- **North (`idle_n`)**:
  `... facing North directly away from camera ...`
- **North-West (`idle_nw`)**:
  `... facing North-West (up and left along isometric axis) ...`
- **West (`idle_w`)**:
  `... facing West (directly left) ...`
- **South-West (`idle_sw`)**:
  `... facing South-West (down and left along isometric axis) ...`
