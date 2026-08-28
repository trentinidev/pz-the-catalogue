# Base meshes for the parcel tiers

Starting points for Blender, not shipped assets. The game loads FBX from
`42/media/models_X/`; these `.obj` files are what you export one **from**.

Rebuild them any time with `powershell -ExecutionPolicy Bypass -File tools\gen_base_models.ps1`
— they are generated, so edit the script if you want different proportions, and edit the
`.obj` in Blender if you want different shape.

| file | what it is | size |
|---|---|---|
| `parcel25.obj` | taped carton | 0.43 × 0.35 × 0.43 m |
| `parcel50.obj` | strapped wooden crate, corner posts standing proud | 0.56 × 0.49 × 0.56 m |
| `parcel100.obj` | tarped load on a half-pallet, blocks and deck boards modelled | 0.80 × 0.56 × 0.60 m |

Each is built from axis-aligned boxes and nothing else. That is deliberate: every part is
separable in Blender, and there is no curve or bevel to fight when you start detailing.

## One unit is one metre, and Y is up

Not a guess. Vanilla still ships a handful of **ASCII** `.x` models, and at `scale = 1.0`
they measure like the real objects they are:

| vanilla model | dimensions | what it is |
|---|---|---|
| `Canteen_Military` | 0.042 × 0.122 × 0.072 | a canteen, 12 cm tall |
| `CorkScrew_Hand` | 0.018 × 0.057 × 0.106 | a corkscrew, 10 cm long |
| `Crafting_Parcel4_Small_OPEN` | 0.071 × 0.038 × 0.102 | a small opened parcel |

In all three the tall axis is Y. So these meshes are built at real freight sizes and
should want `scale = 1.0` — a number to nudge if it looks wrong in game, rather than one
to discover from nothing.

The origin sits **on the ground, centred on the footprint**, so the model rests on the
tile rather than sinking into it.

## The UV layout

This is the part worth caring about. The mod's current world textures are
re-materialised copies of vanilla's atlas, and the only reason for that is that vanilla's
UV layout is locked inside a binary FBX — paint a label onto it and you find out where it
landed by dropping a parcel and walking around it.

These meshes are unwrapped to a layout that is written down, so a texture painted against
it lands where you meant:

```
v 0.665 .. 1.000    FRONT  |  BACK  |  LEFT       each cell one third of the width
v 0.330 .. 0.665    RIGHT  |  TOP   |  BOTTOM
v 0.000 .. 0.330    trim:  straps u 0..0.5  |  bare timber u 0.5..1
```

`uv_layout.png` is that grid, at the recommended size, with the cells labelled. Paint over
it and delete the guide layer.

Straps, corner posts and pallet boards all take the **trim** strip on every face — nobody
is going to paint the end grain of a pallet block, and it keeps the six body cells for the
faces that are actually seen.

**Texture size:** the cells are square at a 3:2 image, so 192 × 128 or 384 × 256. Vanilla's
own parcels are 64 × 64, so either is generous.

**One texture per model.** A PZ `model` block has a single `texture =` line, so everything
must share the one atlas. That is why the `.mtl` here assigns one material per file and
not one per part.

The `.mtl` carries flat placeholder colours rather than the shipped textures on purpose:
those are laid out for vanilla's atlas, and hanging one on this unwrap would look *nearly*
right, which is worse than looking obviously unfinished.

## Blender

Import with **Y up, -Z forward** — the OBJ default, and what these are written in. Blender
works Z-up internally and will convert; leave the same setting on the way out and the round
trip is lossless.

Export FBX with:

- **Scale 1.00**, apply unit scale off
- **Forward -Z, Up Y**
- **Apply modifiers** on, and apply all transforms first (`Ctrl+A`) — a mesh carrying an
  unapplied scale exports at a size nobody can explain later
- Mesh only; no cameras, lamps or armatures

Drop the result in `42/media/models_X/WorldItems/` and point the model at it:

```
    model Parcel50World
    {
        mesh = WorldItems/Parcel50,
        texture = TheCatalogue/Parcel50World,
        scale = 1.0,
    }
```

The `mesh` path is relative to `models_X/` and takes no extension; `texture` is relative
to `textures/` and likewise. Both already exist in
[`42/media/scripts/thecatalogue.txt`](../../42/media/scripts/thecatalogue.txt) — change
the `mesh` line and the `scale`, and the item picks it up on the next load.

## What this unlocks

The silhouette. The current world models are vanilla's box wearing a new coat, so the
crate has no corner brackets and the pallet load has no pallet — those are shape, and no
texture will fake them at the angle the game draws items from. A real mesh gets them, and
gets a UV layout we chose, which means the face art can finally go on the faces it was
drawn for.
