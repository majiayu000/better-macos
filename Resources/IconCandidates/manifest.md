# Better star IP candidate manifest

- Generator: built-in `image_gen`
- Model name: not exposed by the built-in tool schema
- Constraint delivery: main-prompt constraints
- Native dimensions: `1254 × 1254`
- Generation mode: six independent one-pass draws, with no image references, retries, filtering, or post-processing

## Candidate mapping

| Label | Direction and rationale | Corner | Character colors | Background |
|---|---|---|---|---|
| A1 | Chubby five-point North Star; the one focus selected for today | lower-left | warm sunflower yellow + deep plum | gently muted sky blue |
| A2 | Chubby five-point North Star; the one focus selected for today | lower-right | warm sunflower yellow + deep plum | gently muted sky blue |
| B1 | Four-ray guiding star; finding direction inside noise | lower-left | warm coral orange + soft cream | gently muted midnight navy |
| B2 | Four-ray guiding star; finding direction inside noise | lower-right | warm coral orange + soft cream | gently muted midnight navy |
| C1 | Growing five-point star; steady completion compounding over time | lower-left | pale mint + deep forest green | gently muted warm apricot |
| C2 | Growing five-point star; steady completion compounding over time | lower-right | pale mint + deep forest green | gently muted warm apricot |

## Exact prompt template

Each candidate used the following prompt with its assigned values from the table and direction-specific silhouette below.

```text
Create one complete full-bleed 1:1 square image.
Background: fill the entire square with solid <background>. Keep <background> visible in every open area and in the corners not occupied by the character; the <corner> emergence corner must be occupied by the character.
Subject: place one extremely simplified, cute, endearing <direction-specific star character> on the background. <direction-specific silhouette and exact two-character-color assignment>. These two character colors plus the background are the only three semantic colors.
Composition: keep the character upright and emerging from the <corner>, filling about 85–95% of the square. Cropping at the bottom and assigned side is welcome. Never center or bottom-center the character.
Complexity: use only 4–7 large basic shapes and at most two broad internal color regions. Use two simple eyes and one tiny mouth only if it helps the calm friendly expression. Remove every nonessential line, outline, texture, and decoration. Keep the character readable at 32 × 32.
Style: make simplification, cuteness, and lovable baby-like appeal the strongest qualities. Use large soft forms, compact proportions, thick rounded contours, and an ultra-clean graphic treatment. Prefer one clear shape over several explanatory details. Add an extremely, extremely subtle, almost imperceptible sense of depth through a barely-there neo-skeuomorphic treatment.
Finish: show only the character on the full-canvas background, with clean surfaces and normal square outer corners.
Constraints: Use no text or watermark. Add no borders, frames, cards, or presentation masks. Include one character only, with no extra subjects or scenery. Use no fragile lines, sharp tips, unnecessary outlines, tiny details, or decorative marks. Add no photorealistic material, dramatic bevel, glossy hotspot, deep occlusion, extrusion, strong three-dimensional rendering, or external cast shadow. Keep the background solid and uniform, with no texture, vignette, halo, or lighting variation.
```

Direction-specific subject clauses:

- A: `chubby five-point North Star character`; five very thick, evenly rounded, blunt points around one large soft face; warm sunflower yellow dominant body; deep plum broad lower-point region and facial marks.
- B: `four-ray guiding star character`; four broad, soft, blunt rounded rays with a slightly longer upright top ray; warm coral orange outer body; soft cream broad central face region; coral facial marks.
- C: `growing star character`; compact plump five-point silhouette with four broad equal rounded points and one slightly taller, fully blunt upward point; pale mint dominant body; deep forest green broad grounded lower region and facial marks.

## C1 macOS squircle refinement

- Final asset: `C1-macos-squircle.png`
- Generator: built-in `image_gen`; model name not exposed by the tool schema
- Intent: edit C1 into a macOS-native rounded-square composition
- Constraint delivery: main-prompt constraints
- Transparency: generated on a flat magenta surround, then removed with the imagegen chroma-key helper
- Native dimensions: `1254 × 1254`, RGBA

```text
Use case: logo-brand
Asset type: macOS-style rounded square character artwork
Input image: use the supplied C1 image only as the character and palette reference.
Primary request: Redraw the same mint-green five-point star character emerging from the lower-left, but compose it as a polished modern macOS-style rounded-square tile rather than a full-bleed square illustration.
Canvas: one complete 1:1 square image. Outside the tile, use a perfectly flat solid #FF00FF chroma-key color for later removal. Do not use #FF00FF anywhere inside the tile.
Tile: a single centered warm apricot rounded squircle occupying about 86% of the canvas, with generous even margin around it. The outer squircle must have smooth macOS-like continuous curvature and clean crisp edges. No border and no external cast shadow.
Character: preserve the same cute mint star, dark forest-green face and broad lower wave. Make the star smaller and optically balanced inside the squircle, with every point visibly rounded and safely inside the tile. Let it rise from the lower-left but do not crop it against the outer canvas. Keep the face to two oval eyes and one tiny calm smile.
Style: ultra-simple, friendly, weighty, graphic, recognizable at 32×32. Use only warm apricot, mint green, and forest green inside the tile, with very subtle soft depth only. No text, watermark, extra objects, scenery, outline, gloss, bevel, frame, or tiny detail.
Critical invariants: only one star character; keep the C1 personality and color relationship; transparent-ready clean outer corners created by the flat chroma-key surround; the result must look like a native macOS app tile, not a square poster or sticker.
```

## C1 alive-glow refinement

- Final asset: `C1-alive-glow.png`
- Generator: built-in `image_gen`; model name not exposed by the tool schema
- Intent: edit the C1 macOS squircle into a calmer but more alive variant
- Constraint delivery: main-prompt constraints
- Transparency: generated on a flat magenta surround, then removed with the imagegen chroma-key helper
- Native dimensions: `1254 × 1254`, RGBA

```text
Create one complete 1:1 square image by carefully refining the supplied character tile.
Input image role: edit target. Preserve its exact warm-apricot rounded squircle, transparent-ready outer margin, mint five-point star character, forest-green face and broad lower wave, lower-left emergence, proportions, expression, and clean macOS-like continuous curvature.
Primary change: make the star feel quietly alive and more dimensional without using fire or turning it into a fantasy effect.
Living light: add a restrained soft mint-white edge glow only along the upper-left rim and top point of the star. The glow must stay broad, subtle, and integrated into the existing mint color family, never forming an outline around the entire character.
Spark accents: add exactly three sparse, purposeful luminous accents in the open apricot area near the upper-right of the star: one small soft four-point glint and two much smaller round motes. Use pale mint/apricot tonal variations only. Keep them separated, asymmetrical, and clearly readable as energy or aliveness rather than stars in a scene.
Depth: gently improve the existing soft volume with a barely perceptible light falloff across the star and tile. Keep the face matte, simple, and unchanged.
Outside the rounded tile: fill every outer corner and margin with perfectly flat solid #FF00FF chroma-key color for later removal. Do not use #FF00FF inside the tile.
Constraints: one character only; no fire, flame, sparks spraying outward, lens flare, neon, lightning, halo ring, orbit, scenery, text, watermark, border, cast shadow, glossy eyes, extra facial marks, extra objects, texture, or tiny decorative clutter. Keep the original silhouette and three semantic color families. It must remain recognizable at 32 × 32 and feel calm, focused, warm, and subtly alive.
```

## Six-effect expansion

- Generator: built-in `image_gen`; model name not exposed by the tool schema
- Mode: six independent edits, one per original candidate
- Constraint delivery: main-prompt constraints
- Transparency: flat magenta surround removed locally; A/B used a tighter matte threshold to preserve interior purple and coral effects
- Native dimensions: `1254 × 1254`, RGBA

| Output | Source | Effect | Corner |
|---|---|---|---|
| `A1-aurora-left.png` | A1 | broad aurora curtain | lower-left |
| `A2-aurora-right.png` | A2 | reverse aurora curtain | lower-right |
| `B1-magnetic-pulse-left.png` | B1 | two broad magnetic pulses | lower-left |
| `B2-magnetic-pulse-right.png` | B2 | reverse magnetic pulses | lower-right |
| `C1-morning-mist-left.png` | C1 | low morning-mist breath | lower-left |
| `C2-morning-mist-right.png` | C2 | reverse morning-mist breath | lower-right |

The exact six prompts are preserved in [`effect-prompts.md`](effect-prompts.md).
