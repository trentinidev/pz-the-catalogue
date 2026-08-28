# The Catalogue -- base meshes for the three parcel tiers, for editing in Blender.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_base_models.ps1
#
# Writes art/models/*.obj, a shared .mtl and a UV layout guide. Nothing here ships with
# the mod: the game loads FBX, and these are the starting point you export one FROM.
#
# ---------------------------------------------------------------------------
# SCALE: ONE UNIT IS ONE METRE
# ---------------------------------------------------------------------------
#
# Not a guess. Vanilla still ships a handful of ASCII .x models, and at scale 1.0 they
# measure as real objects do:
#
#     Canteen_Military          0.042 x 0.122 x 0.072   a canteen, 12 cm tall
#     CorkScrew_Hand            0.018 x 0.057 x 0.106   a corkscrew, 10 cm long
#     Crafting_Parcel4_Small    0.071 x 0.038 x 0.102   a small opened parcel
#
# The same models confirm Y is up. So these are built at real freight sizes and should
# want `scale = 1.0` in the model script -- one number to nudge if it looks off in game,
# rather than a number to discover from scratch.
#
# ---------------------------------------------------------------------------
# UV LAYOUT: THE WHOLE POINT OF DOING THIS
# ---------------------------------------------------------------------------
#
# The reason the world textures are currently re-materialised copies of vanilla's atlas
# is that vanilla's UV layout is locked inside a binary FBX. These meshes are unwrapped
# to a layout that is WRITTEN DOWN, so a texture painted against it lands where intended:
#
#     v 0.665 .. 1.000   FRONT  |  BACK  |  LEFT      each cell 1/3 of the width
#     v 0.330 .. 0.665   RIGHT  |  TOP   |  BOTTOM
#     v 0.000 .. 0.330   trim: straps u 0..0.5, bare timber u 0.5..1
#
# Square-ish cells at a 3:2 texture, so 192x128 or 384x256 keeps them undistorted.
# Vanilla's own parcels are 64x64, so there is plenty of headroom either way.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

# An OBJ is a text file full of numbers, and PowerShell formats numbers in the CURRENT
# culture. On this machine that means "0,21000" -- which Blender reads as two values or
# as nothing, and which no amount of staring at the geometry would explain. The price
# generator was bitten by the same thing from the parsing side once already.
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$root   = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "art\models"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# The six body cells and the two trim cells, as u0,v0,u1,v1.
$UV = @{
    front  = @(0.0000, 0.665, 0.3333, 1.000)
    back   = @(0.3333, 0.665, 0.6667, 1.000)
    left   = @(0.6667, 0.665, 1.0000, 1.000)
    right  = @(0.0000, 0.330, 0.3333, 0.665)
    top    = @(0.3333, 0.330, 0.6667, 0.665)
    bottom = @(0.6667, 0.330, 1.0000, 0.665)
    strap  = @(0.0000, 0.000, 0.5000, 0.330)
    timber = @(0.5000, 0.000, 1.0000, 0.330)
}

# Accumulated OBJ state. Positions and texture coordinates are numbered across the whole
# file, because OBJ indices are global no matter how many objects the file declares.
#
# Named objVerts/objUVs/objFaces rather than verts/uvs/body: PowerShell variable names
# are CASE-INSENSITIVE, so an earlier $BODY holding the face-to-cell map was the same
# variable as $script:body, and Reset-Obj emptied the map instead of the face list.
$script:objVerts = New-Object System.Collections.ArrayList
$script:objUVs   = New-Object System.Collections.ArrayList
$script:objFaces  = New-Object System.Collections.ArrayList

function Reset-Obj {
    $script:objVerts.Clear(); $script:objUVs.Clear(); $script:objFaces.Clear()
}

function Add-Line($text) { [void]$script:objFaces.Add($text) }

#[[ One axis-aligned box.
#
#   cx/cz are the centre of the footprint and BY is the bottom, not the centre: every
#   part of these models is stacked on something, and describing a pallet board by where
#   its underside sits is the only way that stays readable.
#
#   `cells` names the UV cell each face takes. A crate's sides take the six body cells;
#   a strap or a pallet board takes the trim cell for all six, because nobody is going
#   to paint the end grain of a pallet block. ]]
function Add-Box($cx, $by, $cz, $sx, $sy, $sz, $cells) {
    $x0 = $cx - $sx/2; $x1 = $cx + $sx/2
    $y0 = $by;         $y1 = $by + $sy
    $z0 = $cz - $sz/2; $z1 = $cz + $sz/2

    $base = $script:objVerts.Count
    foreach ($p in @(@($x0,$y0,$z0), @($x1,$y0,$z0), @($x1,$y0,$z1), @($x0,$y0,$z1),
                     @($x0,$y1,$z0), @($x1,$y1,$z0), @($x1,$y1,$z1), @($x0,$y1,$z1))) {
        [void]$script:objVerts.Add(("v {0:F5} {1:F5} {2:F5}" -f $p[0], $p[1], $p[2]))
    }

    # Corners of each face, wound counter-clockwise seen from outside so the normals
    # point out and Blender does not open the model inside-out.
    $corners = @{
        front  = @(4,3,7,8);  back   = @(2,1,5,6)
        left   = @(1,4,8,5);  right  = @(3,2,6,7)
        top    = @(5,8,7,6);  bottom = @(1,2,3,4)
    }

    foreach ($name in @("front","back","left","right","top","bottom")) {
        $cell = $UV[$cells[$name]]
        $u0 = $cell[0]; $v0 = $cell[1]; $u1 = $cell[2]; $v1 = $cell[3]

        # Inset by a hair. A UV sitting exactly on a cell boundary picks up the
        # neighbouring cell's edge pixels once the texture is filtered, which shows up as
        # a thin wrong-coloured seam along every edge of every face.
        $pad = 0.004
        $u0 += $pad; $v0 += $pad; $u1 -= $pad; $v1 -= $pad

        $t = $script:objUVs.Count
        foreach ($c in @(@($u0,$v0), @($u1,$v0), @($u1,$v1), @($u0,$v1))) {
            [void]$script:objUVs.Add(("vt {0:F5} {1:F5}" -f $c[0], $c[1]))
        }

        $q = $corners[$name]
        Add-Line ("f {0}/{1} {2}/{3} {4}/{5} {6}/{7}" -f
                  ($base+$q[0]), ($t+1), ($base+$q[1]), ($t+2),
                  ($base+$q[2]), ($t+3), ($base+$q[3]), ($t+4))
    }
}

$CELLS_BODY = @{ front="front"; back="back"; left="left"; right="right"; top="top"; bottom="bottom" }
$CELLS_STRAP  = @{ front="strap";  back="strap";  left="strap";  right="strap";  top="strap";  bottom="strap"  }
$CELLS_TIMBER = @{ front="timber"; back="timber"; left="timber"; right="timber"; top="timber"; bottom="timber" }

function Save-Obj($name, $title, $material) {
    $path = Join-Path $outDir "$name.obj"
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add("# The Catalogue -- $title")
    [void]$lines.Add("# One unit is one metre. Y is up. Origin sits on the ground, centred on the footprint.")
    [void]$lines.Add("# UV: front|back|left over right|top|bottom, with a trim strip along the bottom third.")
    [void]$lines.Add("mtllib parcels.mtl")
    [void]$lines.Add("o $name")
    [void]$lines.Add("usemtl $material")
    foreach ($v in $script:objVerts) { [void]$lines.Add($v) }
    foreach ($t in $script:objUVs)   { [void]$lines.Add($t) }
    foreach ($f in $script:objFaces)  { [void]$lines.Add($f) }

    [System.IO.File]::WriteAllLines($path, $lines)
    Write-Host ("{0,-14} {1,4} verts, {2,3} faces -> {3}" -f $name, $script:objVerts.Count, $script:objFaces.Count, (Split-Path $path -Leaf))
}

# ---------------------------------------------------------------------------
# Parcel - 25: a taped carton
# ---------------------------------------------------------------------------
# 42 x 34 x 42 cm, about a large moving box, with the tape crossing the lid and running
# down two opposite sides the way a real one is sealed.

Reset-Obj
$w = 0.42; $h = 0.34; $d = 0.42; $tape = 0.05; $proud = 0.003
Add-Box 0 0 0 $w $h $d $CELLS_BODY
Add-Box 0 (-$proud) 0 $tape ($h + $proud*2) ($d + $proud*2) $CELLS_STRAP
Add-Box 0 (-$proud) 0 ($w + $proud*2) ($h + $proud*2) $tape $CELLS_STRAP
Save-Obj "parcel25" "Parcel - 25, a taped carton" "cardboard"

# ---------------------------------------------------------------------------
# Parcel - 50: a strapped wooden crate
# ---------------------------------------------------------------------------
# 55 x 48 x 55 cm. Corner posts stand a few millimetres proud of the planking, which is
# what reads as a crate rather than as a brown box, and two steel bands go over the top.

Reset-Obj
$w = 0.55; $h = 0.48; $d = 0.55; $post = 0.05; $band = 0.05; $proud = 0.004
Add-Box 0 0 0 $w $h $d $CELLS_BODY
foreach ($sx in @(-1, 1)) {
    foreach ($sz in @(-1, 1)) {
        Add-Box ($sx * ($w/2 - $post/2 + $proud)) 0 ($sz * ($d/2 - $post/2 + $proud)) `
                ($post) ($h) ($post) $CELLS_TIMBER
    }
}
Add-Box (-$w/4) (-$proud) 0 $band ($h + $proud*2) ($d + $proud*2) $CELLS_STRAP
Add-Box ( $w/4) (-$proud) 0 $band ($h + $proud*2) ($d + $proud*2) $CELLS_STRAP
Save-Obj "parcel50" "Parcel - 50, a strapped wooden crate" "timber"

# ---------------------------------------------------------------------------
# Parcel - 100: a tarped load on a pallet
# ---------------------------------------------------------------------------
# A half-pallet, 80 x 60 cm, rather than a full 120 x 80 euro pallet -- a full one is
# wider than the tile it would be dropped on. Three bearer blocks each side, five deck
# boards across, and the tarped load strapped down over it.

Reset-Obj
$pw = 0.80; $pd = 0.60; $blockH = 0.075; $deckH = 0.022
$loadW = 0.72; $loadD = 0.52; $loadH = 0.46
$band = 0.06; $proud = 0.004

# Bearers: two runners front to back, on three blocks each.
# Parenthesised element by element: in PowerShell the comma binds TIGHTER than
# division, so `0, $pw/2` divides the array (0, $pw) by two.
foreach ($bx in @((-$pw/2 + 0.09), 0, ($pw/2 - 0.09))) {
    Add-Box $bx 0 (-$pd/2 + 0.06) 0.10 $blockH 0.12 $CELLS_TIMBER
    Add-Box $bx 0 0               0.10 $blockH 0.12 $CELLS_TIMBER
    Add-Box $bx 0 ( $pd/2 - 0.06) 0.10 $blockH 0.12 $CELLS_TIMBER
}
# Deck: five boards across the top, with a gap between each.
$boardW = 0.13
for ($i = 0; $i -lt 5; $i++) {
    $bx = -$pw/2 + $boardW/2 + $i * (($pw - $boardW) / 4)
    Add-Box $bx $blockH 0 $boardW $deckH $pd $CELLS_TIMBER
}

$loadBase = $blockH + $deckH
Add-Box 0 $loadBase 0 $loadW $loadH $loadD $CELLS_BODY

# Two straps over the load and down around the pallet, which is what actually holds a
# tarped load together and the one detail that makes it read as freight.
Add-Box (-$loadW/4) ($loadBase - $proud) 0 $band ($loadH + $proud*2) ($loadD + $proud*2) $CELLS_STRAP
Add-Box ( $loadW/4) ($loadBase - $proud) 0 $band ($loadH + $proud*2) ($loadD + $proud*2) $CELLS_STRAP
Save-Obj "parcel100" "Parcel - 100, a tarped load on a pallet" "canvas"

# ---------------------------------------------------------------------------
# The material file
# ---------------------------------------------------------------------------
# Flat colours, not the shipped textures. Those are laid out for VANILLA's atlas, and
# hanging one on this unwrap would show a convincing-looking mess -- worse than an
# obviously untextured model, because it looks like it is nearly right.

$mtl = @(
    "# The Catalogue -- placeholder materials for the base meshes.",
    "# Flat colours on purpose: the shipped textures are laid out for vanilla's UV atlas,",
    "# not for this unwrap, and hanging one here would look nearly right and be wrong.",
    "",
    "newmtl cardboard", "Kd 0.66 0.47 0.29", "Ka 0.1 0.1 0.1", "d 1.0", "illum 1", "",
    "newmtl timber",    "Kd 0.60 0.40 0.21", "Ka 0.1 0.1 0.1", "d 1.0", "illum 1", "",
    "newmtl canvas",    "Kd 0.35 0.36 0.20", "Ka 0.1 0.1 0.1", "d 1.0", "illum 1"
)
[System.IO.File]::WriteAllLines((Join-Path $outDir "parcels.mtl"), $mtl)
Write-Host "parcels.mtl    placeholder colours"

# ---------------------------------------------------------------------------
# The UV guide
# ---------------------------------------------------------------------------
# A picture of the layout above, at the recommended texture size, to paint against.

$gw = 384; $gh = 256
$guide = New-Object System.Drawing.Bitmap($gw, $gh)
$g = [System.Drawing.Graphics]::FromImage($guide)
$g.Clear([System.Drawing.Color]::FromArgb(255, 32, 32, 36))
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Bold)
$pen  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 210, 210, 220)), 1

$tint = @{
    front = @(70,90,120); back = @(60,78,104); left = @(78,70,110); right = @(90,72,96)
    top   = @(70,110,90); bottom = @(56,64,72); strap = @(120,86,54); timber = @(96,74,44)
}
foreach ($name in $UV.Keys) {
    $c = $UV[$name]
    # v runs upward in UV space and downward in pixels, hence the flip.
    $x = [int]($c[0] * $gw); $y = [int]((1 - $c[3]) * $gh)
    $w = [int](($c[2] - $c[0]) * $gw); $h = [int](($c[3] - $c[1]) * $gh)
    $t = $tint[$name]
    $g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,$t[0],$t[1],$t[2]))), $x, $y, $w, $h)
    $g.DrawRectangle($pen, $x, $y, $w, $h)
    $g.DrawString($name.ToUpper(), $font, [System.Drawing.Brushes]::White, ($x + 6), ($y + 6))
}
$g.Dispose()
$guidePath = Join-Path $outDir "uv_layout.png"
$guide.Save($guidePath, [System.Drawing.Imaging.ImageFormat]::Png)
$guide.Dispose()
Write-Host "uv_layout.png  ${gw}x${gh} guide"
