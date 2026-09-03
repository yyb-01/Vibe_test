# Nano Banana 2 Prompts: Player Survivor 8-Direction Idle

## Asset Specifications
- **Category**: Character / Player
- **Canvas Size**: 128x128 px
- **Ground Contact Pivot**: Bottom-center at `(64, 128)`
- **Camera/Projection**: 2:1 Dimetric Isometric (Orthographic, azimuth 45°, fixed game-isometric)
- **Palette**: Cool desaturated clothing with warm yellow backpack accent
- **Export Files**:
  - `player_survivor_e_idle_00.png`
  - `player_survivor_se_idle_00.png`
  - `player_survivor_s_idle_00.png`
  - `player_survivor_sw_idle_00.png`
  - `player_survivor_w_idle_00.png`
  - `player_survivor_nw_idle_00.png`
  - `player_survivor_n_idle_00.png`
  - `player_survivor_ne_idle_00.png`

---

## 8-View Turnaround Prompt Template
```text
ROLE: Create one production candidate for a Godot 4 2D isometric survival game.
REFERENCE: Use Image A only for art style, camera, palette, and upper-left lighting.
SUBJECT: lone survivor character, worn hooded jacket, utility cargo pants, hiking boots, warm yellow backpack accent, survivalist posture.
VIEW: Orthographic 2:1 game-isometric, facing {direction}, fixed camera matching Image A.
COMPOSITION: One isolated character, centered on a 128x128 canvas, ground contact feet at exact bottom-center (64, 128), readable at gameplay size.
STYLE: Dark cartoon survival, stylized low-poly forms rendered as a clean 2D sprite, desaturated cool palette, warm interaction accent, strong silhouette, medium detail.
OUTPUT: Transparent background with real alpha, clean edge colors, no baked shadow.
MUST NOT INCLUDE: environment, floor plane, border, text, logo, UI, extra objects, cropped parts, perspective camera, watermark-shaped decoration.
```

## Direction Breakdown
- **E**: Facing screen right (+X)
- **SE**: Facing screen bottom-right (+X, +Y)
- **S**: Facing screen bottom (+Y)
- **SW**: Facing screen bottom-left (-X, +Y)
- **W**: Facing screen left (-X)
- **NW**: Facing screen top-left (-X, -Y)
- **N**: Facing screen top (-Y)
- **NE**: Facing screen top-right (+X, -Y)
