"""The Catalogue -- build the three parcel meshes in Blender and export them for the game.

    blender --background --factory-startup --python tools/blender_parcels.py

Writes, per tier:

    art/models/<tier>.blend                  the editable source, open it and change it
    42/media/models_X/WorldItems/<tier>.fbx  what the game actually loads

--factory-startup matters: it ignores whatever add-ons and units the machine's Blender
happens to be configured with, so the output does not depend on somebody's preferences.

POLYGON BUDGET IS VANILLA'S. Every vanilla parcel is 20 triangles -- a plain box with a
painted texture doing all the work. An earlier version of this script gave every box a
two-segment bevel and came out at 324, 1188 and 1836 triangles, which is not a nicer
version of the game's art, it is a different game's art sitting next to it.

So: no bevels, and geometry only where it changes the SILHOUETTE -- the crate's corner
posts, the pallet under the tarp. Tape, strapping and rails are painted, because at this
size on the ground that is where they belong and where vanilla puts them.

SIZE IS MEASURED AGAINST VANILLA, NOT AGAINST THE WORLD. An earlier version of this
script modelled at real freight sizes on the strength of vanilla's ASCII .x models -- a
canteen 0.122 tall -- and shipped parcels four to nine times too big. Those .x files are
hand-held models and do not share a scale with WorldStaticModel.

The honest reference is the thing sitting next to it on the ground. Vanilla's extra-large
parcel is Parcel_Present_1 at scale 0.2, and imported it measures 0.449 across: 0.090 in
the game. Everything here is a multiple of that, at vanilla's own scale of 0.2, so the
tiers sit in the same regime as the boxes they are compared to.

Y IS UP in the export, which vanilla's meshes confirm: both ours and Parcel_Present_1
carry UpAxis = 1. These are modelled in Blender's native Z-up and written out Y-up.
"""

import bmesh
import bpy
import os
import sys
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND_DIR = os.path.join(REPO, "art", "models")
FBX_DIR = os.path.join(REPO, "42", "media", "models_X", "WorldItems")

# The UV grid, as (u0, v0, u1, v1). Written down rather than left to an automatic
# unwrap, because the whole point of owning the mesh is knowing where a painted label
# will land. Square-ish cells at a 3:2 texture: 192x128 or 384x256.
CELLS = {
    "front":  (0.0000, 0.665, 0.3333, 1.000),
    "back":   (0.3333, 0.665, 0.6667, 1.000),
    "left":   (0.6667, 0.665, 1.0000, 1.000),
    "right":  (0.0000, 0.330, 0.3333, 0.665),
    "top":    (0.3333, 0.330, 0.6667, 0.665),
    "bottom": (0.6667, 0.330, 1.0000, 0.665),
    "strap":  (0.0000, 0.000, 0.5000, 0.330),
    "timber": (0.5000, 0.000, 1.0000, 0.330),
}

# A face whose normal points mostly along an axis takes that axis's cell. Bevel faces sit
# between two of them and will pick whichever dominates; at six millimetres nobody will
# ever know which.
AXIS_CELL = {
    (0, +1): "front",  (0, -1): "right",
    (1, +1): "back",   (1, -1): "left",
    (2, +1): "top",    (2, -1): "bottom",
}

BODY = None                       # None means "use the face's own axis cell"
STRAP = "strap"
TIMBER = "timber"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def dominant_axis(normal):
    """Which axis this face mostly faces, as (index, sign)."""
    values = [abs(normal.x), abs(normal.y), abs(normal.z)]
    index = values.index(max(values))
    sign = 1 if normal[index] >= 0 else -1
    return index, sign


def assign_uvs(mesh_obj, forced_cell):
    """Box-project every face into its cell.

    Each face is flattened along its dominant axis, normalised against the object's own
    bounding box on the other two axes, and dropped into the cell rectangle. That gives
    the documented layout exactly, where an automatic unwrap would give something
    plausible and unrepeatable.
    """
    bm = bmesh.new()
    bm.from_mesh(mesh_obj.data)
    uv_layer = bm.loops.layers.uv.verify()

    verts = [v.co for v in bm.verts]
    lo = Vector((min(v.x for v in verts), min(v.y for v in verts), min(v.z for v in verts)))
    hi = Vector((max(v.x for v in verts), max(v.y for v in verts), max(v.z for v in verts)))
    size = Vector((max(hi.x - lo.x, 1e-6), max(hi.y - lo.y, 1e-6), max(hi.z - lo.z, 1e-6)))

    for face in bm.faces:
        axis, sign = dominant_axis(face.normal)
        cell = forced_cell or AXIS_CELL[(axis, sign)]
        u0, v0, u1, v1 = CELLS[cell]

        # Inset by a hair: a UV sitting exactly on a cell boundary picks up the
        # neighbouring cell's edge pixels once the texture is filtered, and that shows
        # up as a thin wrong-coloured seam along every edge of every face.
        pad = 0.004
        u0, v0, u1, v1 = u0 + pad, v0 + pad, u1 - pad, v1 - pad

        # The two axes that survive the flattening, in a consistent order.
        a, b = [i for i in (0, 1, 2) if i != axis]

        for loop in face.loops:
            co = loop.vert.co
            s = (co[a] - lo[a]) / size[a]
            t = (co[b] - lo[b]) / size[b]
            loop[uv_layer].uv = (u0 + s * (u1 - u0), v0 + t * (v1 - v0))

    bm.to_mesh(mesh_obj.data)
    bm.free()


# Vanilla's extra-large parcel, in RAW FBX VERTEX UNITS: Parcel_Present_1 measures 17.664
# across in the file, and its model block scales that by 0.2.
#
# Raw units, not what Blender shows after import, and that distinction cost a version.
# Vanilla's FBX declares its units as inches, so Blender helpfully multiplies by 0.0254
# and reports 0.449 -- but the game does not: it reads the vertex data and applies only
# the model block's scale. Building against Blender's 0.449 made parcels eight times too
# small, which is exactly what came back from testing.
#
# So everything here is a multiple of 17.664, and the export below writes raw coordinates
# with no unit conversion of its own.
XL = 17.664
SCALE = 0.2


def add_box(name, cx, cy, bz, sx, sy, sz, cell=BODY):
    """One box, twelve triangles. cx/cy centre the footprint, bz is the BOTTOM.

    Bottom rather than centre because every part of these models is stacked on something,
    and a pallet block is far easier to describe by where its underside sits.
    """
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((cx, cy, bz + sz / 2)), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()

    assign_uvs(obj, cell)
    return obj


def join_all(name):
    """One object, one mesh, one material slot -- which is all a PZ model can have."""
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()

    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name

    # Flat shading, like vanilla. There are no bevels to round off, and smoothing a bare
    # box only makes its corners look soft and wrong.
    bpy.ops.object.shade_flat()
    return joined


def build_parcel25():
    """A taped carton, a shade larger than vanilla's extra large.

    A plain box, exactly as vanilla does it: the tape cross is painted into the texture,
    not modelled. At the size this is drawn on the ground, geometry for a strip of tape
    would cost triangles and change nothing anyone can see.
    """
    w = XL * 1.20
    add_box("carton", 0, 0, 0, w, w, w * 0.78)
    return join_all("parcel25")


def build_parcel50():
    """A crate, twice the carton.

    Four corner posts, and nothing else added. The posts are the one thing here that
    changes the outline -- a crate is a frame with panels between it, and that reads from
    across a room where painted-on rails do not. The rails ARE painted.
    """
    w = XL * 2.40
    h = w * 0.86
    post = w * 0.09
    proud = w * 0.012

    add_box("panels", 0, 0, 0, w, w, h)
    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box("post",
                    sx * (w / 2 - post / 2 + proud), sy * (w / 2 - post / 2 + proud), 0,
                    post, post, h, TIMBER)
    return join_all("parcel50")


def build_parcel100():
    """A tarped load on a pallet, twice the crate -- about a whole tile.

    The pallet is the whole reason this one has geometry at all. Three bearer blocks and
    a deck slab, not nine blocks and five boards: at this size the gaps between deck
    boards are sub-pixel, and the silhouette that matters is "the load is standing on
    something", which three blocks give for twelve triangles each.
    """
    pw = XL * 4.80
    pd = pw * 0.75
    block_h = pw * 0.055
    deck_h = pw * 0.030

    for bx in (-pw / 2 + pw * 0.11, 0.0, pw / 2 - pw * 0.11):
        add_box("block", bx, 0, 0, pw * 0.13, pd, block_h, TIMBER)
    add_box("deck", 0, 0, block_h, pw, pd, deck_h, TIMBER)

    load = add_box("load", 0, 0, block_h + deck_h, pw * 0.92, pd * 0.90, pw * 0.52)

    # Pull the top face in. A tarp over a stack is never a cuboid, and this is the one
    # cheap shape change that stops it reading as a green box sitting on some wood.
    bm = bmesh.new()
    bm.from_mesh(load.data)
    top = max(v.co.z for v in bm.verts)
    for v in bm.verts:
        if v.co.z > top - 1e-4:
            v.co.x *= 0.90
            v.co.y *= 0.90
    bm.to_mesh(load.data)
    bm.free()

    return join_all("parcel100")


def export(obj, name):
    os.makedirs(BLEND_DIR, exist_ok=True)
    os.makedirs(FBX_DIR, exist_ok=True)

    blend_path = os.path.join(BLEND_DIR, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)

    fbx_path = os.path.join(FBX_DIR, name + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=False,
        object_types={"MESH"},
        # Modelled Z-up because that is Blender's native axis; written Y-up because that
        # is what vanilla's meshes use and what the game expects.
        axis_forward="-Z",
        axis_up="Y",
        # No unit conversion: the numbers modelled are the numbers written, because the
        # game reads raw vertices. apply_unit_scale would fold Blender's metre in and
        # silently rescale everything.
        global_scale=1.0,
        apply_unit_scale=False,
        apply_scale_options="FBX_SCALE_NONE",
        bake_space_transform=False,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="STRIP",
    )

    d = obj.dimensions
    print("BUILT %-11s %4d tris  raw %.3f x %.3f x %.3f  ->  %.3f in game (%.1fx vanilla XL)"
          % (name, len(obj.data.loop_triangles), d.x, d.y, d.z,
             max(d) * SCALE, max(d) / XL))


def verify_uvs(obj, name):
    """Every UV must land inside one of the declared cells.

    Blender ships a UV layout exporter, but it draws through the GPU and there is no GPU
    in --background, so a picture of the unwrap is not available here. This is better
    anyway: a picture has to be looked at, and this fails the build. It is the one thing
    that can actually go wrong silently -- a face projected into the wrong cell paints a
    shipping label onto the underside of a pallet and nothing complains.
    """
    rects = list(CELLS.values())
    strays = 0
    for poly in obj.data.polygons:
        for loop_index in poly.loop_indices:
            u, v = obj.data.uv_layers.active.data[loop_index].uv
            if not any(u0 - 1e-4 <= u <= u1 + 1e-4 and v0 - 1e-4 <= v <= v1 + 1e-4
                       for u0, v0, u1, v1 in rects):
                strays += 1
    if strays:
        raise SystemExit("%s: %d UV coordinate(s) outside every declared cell" % (name, strays))
    return len(obj.data.polygons)


def write_cell_table():
    """The cell rectangles, for tools/gen_uv_guide.ps1 to draw and for anyone to read.

    Written out rather than copied into the other script, because the same numbers living
    in two files is exactly how a guide ends up describing a layout the mesh no longer
    uses.
    """
    os.makedirs(BLEND_DIR, exist_ok=True)
    path = os.path.join(BLEND_DIR, "uv_cells.txt")
    with open(path, "w") as f:
        f.write("# The Catalogue -- UV cells, written by tools/blender_parcels.py.\n")
        f.write("# name u0 v0 u1 v1, with v running upward as UV does.\n")
        for cell_name, (u0, v0, u1, v1) in CELLS.items():
            f.write("%s %.4f %.4f %.4f %.4f\n" % (cell_name, u0, v0, u1, v1))
    print("BUILT uv_cells.txt %d cells" % len(CELLS))


def main():
    for name, build in (("parcel25", build_parcel25),
                        ("parcel50", build_parcel50),
                        ("parcel100", build_parcel100)):
        clear_scene()
        obj = build()
        obj.data.calc_loop_triangles()
        faces = verify_uvs(obj, name)
        export(obj, name)
        print("       %-11s %d faces, every UV inside a declared cell" % (name, faces))

    write_cell_table()


main()
