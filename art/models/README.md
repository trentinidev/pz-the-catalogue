# The parcel meshes

The three oversized parcels have meshes of their own. They are built by
[`tools/blender_parcels.py`](../../tools/blender_parcels.py), which runs Blender headless
and writes both the editable source and the file the game loads:

```sh
blender --background --factory-startup --python tools/blender_parcels.py
```

| output | what it is |
|---|---|
| `parcel25.blend`, `parcel50.blend`, `parcel100.blend` | open these in Blender |
| `42/media/models_X/WorldItems/*.fbx` | what Project Zomboid actually loads |
| `uv_cells.txt` | the UV grid, written from the same table the meshes are unwrapped with |
| `uv_layout.png` | that grid drawn, to paint textures against |

`--factory-startup` is deliberate: it ignores whatever add-ons and unit settings this
machine's Blender happens to have, so the output does not depend on anyone's preferences.

| tier | what it is | size |
|---|---|---|
| `parcel25` | taped carton | 0.43 × 0.43 × 0.35 m, 324 tris |
| `parcel50` | crate with a corner-post frame and rails, two straps | 0.56 × 0.56 × 0.49 m, 1,188 tris |
| `parcel100` | tarped load, tapered, strapped to a modelled half-pallet | 0.80 × 0.60 × 0.56 m, 1,836 tris |

Everything is boxes with bevelled edges. The bevel is not decoration — under the game's
flat lighting a sharp cube reads as a placeholder, and two segments of bevel is most of
what makes it read as an object instead.

## One unit is one metre, and Y is up

Not a guess. Vanilla still ships a handful of **ASCII** `.x` models, and at `scale = 1.0`
they measure like the real objects they are:

| vanilla model | dimensions | what it is |
|---|---|---|
| `Canteen_Military` | 0.042 × 0.122 × 0.072 | a canteen, 12 cm tall |
| `CorkScrew_Hand` | 0.018 × 0.057 × 0.106 | a corkscrew, 10 cm long |
| `Crafting_Parcel4_Small_OPEN` | 0.071 × 0.038 × 0.102 | a small opened parcel |

In all three the tall axis is Y. So the parcels are modelled at real freight sizes and the
model blocks use `scale = 1.0`.

The meshes are modelled in Blender's native **Z-up** and exported **Y-up** — the export
call sets `axis_up="Y"`. Confirmed against vanilla: both our FBX and
`Parcel_Present_1.fbx` carry `UpAxis = 1` in their headers.

The origin sits **on the ground, centred on the footprint**, so a parcel rests on the tile
instead of sinking into it.

## The UV layout

This is what owning the mesh buys. Before, the world textures had to be re-materialised
copies of vanilla's atlas, because vanilla's UV layout lives inside a binary FBX — paint a
label onto it and you find out where it went by dropping a parcel and walking around it.

Now the unwrap is a grid we chose:

```
v 0.665 .. 1.000    FRONT  |  BACK  |  LEFT       each cell one third of the width
v 0.330 .. 0.665    RIGHT  |  TOP   |  BOTTOM
v 0.000 .. 0.330    trim:  straps u 0..0.5  |  bare timber u 0.5..1
```

Every face is box-projected into its cell by the dominant direction of its normal. Straps,
corner posts and pallet boards take the **trim** strip on every face — nobody paints the
end grain of a pallet block, and it keeps the six body cells for the faces that are seen.

`uv_layout.png` is that grid with the cells labelled: paint over it and delete the guide
layer. It is drawn by `tools/gen_uv_guide.ps1` **from `uv_cells.txt`**, not from a second
copy of the numbers — a guide describing a layout the mesh no longer uses is worse than no
guide, because it will be believed.

Blender does ship a UV layout exporter that would draw the real islands, but it renders
through the GPU and `--background` has none. The build checks instead: every UV coordinate
must land inside a declared cell, or `blender_parcels.py` stops. That is the one thing
that can go wrong in silence — a face projected into the wrong cell paints a shipping label
onto the underside of a pallet and nothing complains.

**Texture size:** cells are square at 3:2, so 192 × 128 or 384 × 256. Vanilla's own parcels
are 64 × 64, so either is generous. `tools/gen_parcel_art.ps1` currently fills the cells
with flat material — deliberately flat, because the mesh carries real bevels and a real
frame and the light does the shading; baking shading in as well fights the geometry.

**One texture per model.** A PZ `model` block has a single `texture =` line, so everything
shares one atlas. That is why straps and timber are cells in the same image rather than
separate materials.

## Editing

Open the `.blend`, change what you like, and export FBX with:

- **Scale 1.00**, apply unit scale on
- **Forward -Z, Up Y**
- **Apply modifiers** on, and apply all transforms first (`Ctrl+A`) — a mesh carrying an
  unapplied scale exports at a size nobody can explain later
- Mesh only; no cameras, lamps or armatures

Straight into `42/media/models_X/WorldItems/`, same filename, and the item picks it up on
the next load. Or change the script and re-run it, which does all of that and re-checks
the UVs.

Note that re-running `blender_parcels.py` **overwrites the `.blend`**. Edits made by hand
in Blender live only until the next run: if a change is worth keeping, put it in the
script.
