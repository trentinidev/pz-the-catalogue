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

## Size is measured against vanilla, in RAW vertex units

This took two wrong answers to get right, and the distinction is the whole of it.

Vanilla's extra-large parcel, `Parcel_Present_1.fbx`, holds vertex data **17.664** units
across, and the file declares its units as inches. Blender helpfully multiplies by 0.0254
and reports 0.449 — **the game does not**. It reads the vertex data and applies only the
`scale` from the model block.

The first attempt built against real-world metres, on the strength of vanilla's remaining
ASCII `.x` models (a canteen 0.122 tall). Those are hand-held models and share no scale
with `WorldStaticModel`. The second built against Blender's post-import 0.449, and shipped
parcels eight times too small.

And then the FBX has to be written in vanilla's convention, not just at vanilla's
numbers. Ours previously declared its units as metres while vanilla declares inches — a
factor of 39.4 that shows up under one reading of the file and not the other, which is
exactly how you get one tier tiny and another enormous.

The export configuration was found by exporting a known cube several ways and re-importing
each. Only `scale_length = 0.0254` with `apply_unit_scale=True` comes back as vanilla does:
raw 17.664 with an object scale of 0.0254. With the convention matched, `scale = 0.2` means
the same thing for both files however the game reads them, and the tier ratios hold either
way.

So every size here is a multiple of 17.664, and the model blocks use vanilla's `scale = 0.2`:

| tier | raw | in game | |
|---|---|---|---|
| vanilla extra large | 17.66 | 3.53 | the reference |
| `parcel25` | 25.61 | 5.12 | 1.45× the extra large |
| `parcel50` | 36.18 | 7.24 | 1.38× the 25 |
| `parcel100` | 48.58 | 9.72 | 1.38× the 50 |

**The step between tiers is a doubling of bulk, not of width.** The brief was "each one
double the last", and taking that literally gave 1.2× / 2.4× / 4.8× — right for capacity,
wrong on screen, because doubling a linear dimension is eight times the volume and the
largest tier swallowed its tile. About ×1.4 linear is what twice the box looks like with
two of them side by side. The three multipliers live in `TIER` at the top of the build
script and are the only numbers to touch.

Y is up in the export, and vanilla confirms it: both ours and `Parcel_Present_1.fbx` carry
`UpAxis = 1` in their headers. The origin sits **on the ground, centred on the footprint**,
so a parcel rests on the tile rather than sinking into it.

## The polygon budget is vanilla's

Every vanilla parcel is **20 triangles** — a plain box with a painted texture doing all the
work. An earlier version here gave every box a two-segment bevel and came out at 324, 1188
and 1836 triangles. That is not a nicer version of the game's art; it is a different game's
art sitting next to it.

| tier | what it is | tris |
|---|---|---|
| `parcel25` | a plain box; the tape cross is painted | 12 |
| `parcel50` | box plus four corner posts | 60 |
| `parcel100` | tapered load, deck slab, three bearer blocks | 60 |

Geometry only where it changes the **silhouette**. The crate's corner posts and the pallet
under the tarp are shape, and read from across a room. Tape, strapping, rails and plank
seams are painted, because at this size on the ground that is where they belong — and it
is where vanilla puts them.

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

Every face is box-projected into its cell by the dominant direction of its normal. Corner
posts and pallet boards take the **trim** strip on every face — nobody paints the end grain
of a pallet block, and it keeps the six body cells for the faces that are seen.

`uv_layout.png` is that grid with the cells labelled: paint over it and delete the guide
layer. It is drawn by `tools/gen_uv_guide.ps1` **from `uv_cells.txt`**, not from a second
copy of the numbers — a guide describing a layout the mesh no longer uses is worse than no
guide, because it will be believed.

Blender does ship a UV layout exporter that would draw the real islands, but it renders
through the GPU and `--background` has none. The build checks instead: every UV coordinate
must land inside a declared cell, or `blender_parcels.py` stops. That is the one thing that
can go wrong in silence — a face projected into the wrong cell paints a shipping label onto
the underside of a pallet and nothing complains.

**Texture size:** cells are square at 3:2, so 192 × 128 or 384 × 256. Vanilla's own parcels
are 64 × 64, so either is generous.

**One texture per model.** A PZ `model` block has a single `texture =` line, so everything
shares one atlas. That is why straps and timber are cells in the same image rather than
separate materials.

## Editing

Open the `.blend`, change what you like, and export FBX with:

- **Scale 1.00**, **apply unit scale ON**, and the scene's unit length set to **0.0254** —
  together these reproduce vanilla's convention, which is the trap described above. Any
  other combination writes a file the game may scale differently from vanilla's
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
