"""The Catalogue -- build the three parcel meshes in Blender and export them for the game.

    blender --background --factory-startup --python tools/blender_parcels.py

Writes, per tier:

    art/models/<tier>.blend                  the editable source, open it and change it
    42/media/models_X/WorldItems/<tier>.fbx  what the game actually loads

--factory-startup matters: it ignores whatever add-ons and units the machine's Blender
happens to be configured with, so the output does not depend on somebody's preferences.

WHY THIS REPLACED THE HAND-WRITTEN OBJ. The OBJ generator could only emit boxes -- no
bevel, no bulge, and a UV assignment I had to be careful about by hand. Here the same
geometry gets real edge bevels, which is most of what separates a box that reads as an
object from a box that reads as a placeholder at the angle the game draws items from, and
the FBX comes out the other end without a manual round trip.

ONE UNIT IS ONE METRE, and vanilla's remaining ASCII .x models are the evidence: at
scale 1.0 Canteen_Military is 0.122 tall and CorkScrew_Hand is 0.106 long. They also put
the tall axis on Y, which is what the export settings at the bottom convert to -- these
are modelled in Blender's native Z-up and written out Y-up.
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


def add_box(name, cx, cy, bz, sx, sy, sz, cell=BODY, bevel=0.006):
    """One box. cx/cy centre the footprint, bz is the BOTTOM.

    Bottom rather than centre because every part of these models is stacked on something,
    and a pallet board is far easier to describe by where its underside sits.
    """
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((cx, cy, bz + sz / 2)), verts=bm.verts)

    if bevel > 0:
        # Two segments, not one. A single-segment bevel still reads as a hard edge under
        # the game's flat lighting; two catches a highlight and the box stops looking
        # like a cube primitive.
        bmesh.ops.bevel(
            bm,
            geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
            offset=min(bevel, min(sx, sy, sz) * 0.25),
            segments=2,
            profile=0.5,
            affect="EDGES",
        )

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

    # Shade smooth with an angle threshold, so the bevels round off but the box's own
    # corners stay crisp.
    bpy.ops.object.shade_auto_smooth(angle=0.7)
    return joined


def build_parcel25():
    """A taped carton, 42 x 42 x 34 cm -- about a large moving box."""
    w, d, h = 0.42, 0.42, 0.34
    tape, proud = 0.05, 0.003
    add_box("carton", 0, 0, 0, w, d, h)
    add_box("tape_x", 0, 0, -proud, tape, d + proud * 2, h + proud * 2, STRAP, bevel=0.002)
    add_box("tape_y", 0, 0, -proud, w + proud * 2, tape, h + proud * 2, STRAP, bevel=0.002)
    return join_all("parcel25")


def build_parcel50():
    """A framed wooden crate, 55 x 55 x 48 cm.

    The frame is the whole point: four corner posts and a rail top and bottom on each
    side, all standing a few millimetres proud of the planking. That is what reads as a
    crate rather than as a brown box, and it is exactly what a texture could never fake.
    """
    w, d, h = 0.55, 0.55, 0.48
    post, rail, band = 0.05, 0.045, 0.05
    proud = 0.006

    add_box("planking", 0, 0, 0, w, d, h)

    for sx in (-1, 1):
        for sy in (-1, 1):
            add_box(
                "post", sx * (w / 2 - post / 2 + proud), sy * (d / 2 - post / 2 + proud), 0,
                post, post, h, TIMBER, bevel=0.004,
            )

    for bz in (0.0, h - rail):
        add_box("rail_x", 0, 0, bz, w - post, d + proud * 2, rail, TIMBER, bevel=0.004)
        add_box("rail_y", 0, 0, bz, w + proud * 2, d - post, rail, TIMBER, bevel=0.004)

    add_box("band_a", -w / 4, 0, -proud, band, d + proud * 2, h + proud * 2, STRAP, bevel=0.002)
    add_box("band_b", w / 4, 0, -proud, band, d + proud * 2, h + proud * 2, STRAP, bevel=0.002)
    return join_all("parcel50")


def build_parcel100():
    """A tarped load strapped to a half-pallet.

    Half a pallet, 80 x 60 cm, not a full 120 x 80 euro pallet: a full one is wider than
    the tile it gets dropped on. Three bearer blocks a side, five deck boards across.

    The load tapers slightly toward the top, because a tarp pulled down over a stack is
    never a cuboid, and that taper is the cheapest thing that stops it reading as a green
    box sitting on some wood.
    """
    pw, pd = 0.80, 0.60
    block_h, deck_h = 0.075, 0.022
    band, proud = 0.06, 0.005

    for bx in (-pw / 2 + 0.09, 0.0, pw / 2 - 0.09):
        for by in (-pd / 2 + 0.06, 0.0, pd / 2 - 0.06):
            add_box("block", bx, by, 0, 0.10, 0.12, block_h, TIMBER, bevel=0.004)

    board_w = 0.13
    for i in range(5):
        bx = -pw / 2 + board_w / 2 + i * ((pw - board_w) / 4)
        add_box("deck", bx, 0, block_h, board_w, pd, deck_h, TIMBER, bevel=0.003)

    base = block_h + deck_h
    load_w, load_d, load_h = 0.72, 0.52, 0.46
    load = add_box("load", 0, 0, base, load_w, load_d, load_h)

    # Pull the top face in. Done here rather than by building a frustum, because the
    # bevel has already run and squeezing the top ring keeps its rounded edge.
    bm = bmesh.new()
    bm.from_mesh(load.data)
    top = base + load_h
    for v in bm.verts:
        if v.co.z > top - 0.02:
            v.co.x *= 0.93
            v.co.y *= 0.93
    bm.to_mesh(load.data)
    bm.free()

    add_box("band_a", -load_w / 4, 0, base - proud, band, load_d + proud * 2, load_h + proud * 2, STRAP, bevel=0.002)
    add_box("band_b", load_w / 4, 0, base - proud, band, load_d + proud * 2, load_h + proud * 2, STRAP, bevel=0.002)
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
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        bake_space_transform=False,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="STRIP",
    )

    dims = obj.dimensions
    print("BUILT %-11s %5d tris  %.2f x %.2f x %.2f m  -> %s"
          % (name, len(obj.data.loop_triangles) or len(obj.data.polygons) * 2,
             dims.x, dims.y, dims.z, os.path.basename(fbx_path)))


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
