# The Catalogue -- build the three oversized-parcel icons and world textures.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_parcel_art.ps1
#
# Sources live in art/, so this is reproducible from a clean clone rather than from
# whatever happens to be in someone's Downloads folder.
#
# ---------------------------------------------------------------------------
# WHY THE WORLD TEXTURE IS NOT SIMPLY THE ART
# ---------------------------------------------------------------------------
#
# The face sheets give six flat faces -- exactly what you would paint onto a UV atlas.
# But the atlas belongs to vanilla's Parcel_Present_1 mesh, and that mesh's UV layout
# lives inside a binary FBX. Guessing which rectangle of the atlas is which face is how
# a shipping label ends up wrapped around a corner, and it is not the kind of mistake
# that shows up until someone drops a parcel in front of a window.
#
# So the layout is never touched. Vanilla's own atlas is already correct for that mesh,
# and this re-materialises it:
#
#   - the MATERIAL comes from the tier's own art -- cardboard, planks, olive canvas
#   - vanilla's per-face SHADING is kept, so the box still reads as lit rather than flat
#   - vanilla's TAPE, the brightest thing in the atlas, is repainted as the tier's own
#     banding, and it lands correctly on the mesh precisely because it IS vanilla's tape
#
# What this cannot give is a silhouette. The crate has no corner brackets and the pallet
# load has no pallet, because those are shape and not texture. The icons have all of it,
# and the icon is where the difference is actually read.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root     = Split-Path -Parent $PSScriptRoot
$art      = Join-Path $root "art"
$textures = Join-Path $root "42\media\textures"
$worldDir = Join-Path $textures "TheCatalogue"
$GAME     = "S:\SteamLibrary\steamapps\common\ProjectZomboid\media\textures\WorldItems"

New-Item -ItemType Directory -Force -Path $worldDir | Out-Null

# Banding colour per tier, read off the art: translucent packing tape on the carton,
# near-black webbing on the crate, dark brown canvas strap on the pallet load.
$TIERS = @(
    @{ key = "parcel25";  icon = "Item_ParcelXXL";  world = "Parcel25World";  band = @(214, 198, 170); timber = @(150, 116,  76) },
    @{ key = "parcel50";  icon = "Item_Parcel5XL";  world = "Parcel50World";  band = @( 46,  44,  48); timber = @(146, 102,  56) },
    @{ key = "parcel100"; icon = "Item_Parcel10XL"; world = "Parcel100World"; band = @( 74,  62,  50); timber = @(158, 116,  70) }
)

$TAPE_SD = 1.5    # how far above mean luminance counts as vanilla's tape

# The UV grid the Blender meshes are unwrapped to. Must stay in step with CELLS in
# tools/blender_parcels.py -- the two describe the same layout from opposite ends.
$CELLS_UV = @{
    front  = @(0.0000, 0.665, 0.3333, 1.000)
    back   = @(0.3333, 0.665, 0.6667, 1.000)
    left   = @(0.6667, 0.665, 1.0000, 1.000)
    right  = @(0.0000, 0.330, 0.3333, 0.665)
    top    = @(0.3333, 0.330, 0.6667, 0.665)
    bottom = @(0.6667, 0.330, 1.0000, 0.665)
    strap  = @(0.0000, 0.000, 0.5000, 0.330)
    timber = @(0.5000, 0.000, 1.0000, 0.330)
}

function New-Canvas([int]$w, [int]$h) {
    return New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics($bitmap) {
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    # SourceCopy so a transparent source pixel stays transparent rather than being
    # blended against an empty canvas and leaving a dark fringe.
    $g.CompositingMode    = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    return $g
}

# TileFlipXY stops GDI+ sampling past the edge of the source, which is what puts a
# one-pixel dark rim around a downscaled image.
function Draw-Region($g, $src, $dx, $dy, $dw, $dh, $sx, $sy, $sw, $sh) {
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $dest = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
    $g.DrawImage($src, $dest, $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $attr.Dispose()
}

function Get-AlphaBounds($bmp) {
    $minX = $bmp.Width; $minY = $bmp.Height; $maxX = 0; $maxY = 0
    for ($y = 0; $y -lt $bmp.Height; $y += 2) {
        for ($x = 0; $x -lt $bmp.Width; $x += 2) {
            if ($bmp.GetPixel($x, $y).A -gt 96) {
                if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    return @($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

# The flattest fully-opaque patch of the render.
#
# Found rather than hand-picked, because hand-picked coordinates are magic numbers that
# silently start pointing at a shipping label the next time the art is re-rendered.
# Flattest means lowest colour variance, which is what picks bare cardboard over a
# FRAGILE stamp, bare planks over a corner bracket, bare canvas over a strap buckle.
#
# Fully opaque matters as much as flat: a window overlapping the transparent background
# would be extremely flat and would sample nothing at all.
function Find-MaterialPatch($bmp, $size, $stride) {
    $bounds = Get-AlphaBounds $bmp
    $best = $null; $bestVar = [double]::MaxValue

    for ($y = $bounds[1]; $y + $size -lt $bounds[1] + $bounds[3]; $y += $stride) {
        for ($x = $bounds[0]; $x + $size -lt $bounds[0] + $bounds[2]; $x += $stride) {

            $n = 0; $sum = 0.0; $sumSq = 0.0; $opaque = $true
            for ($sy = 0; $sy -lt $size -and $opaque; $sy += 8) {
                for ($sx = 0; $sx -lt $size; $sx += 8) {
                    $c = $bmp.GetPixel($x + $sx, $y + $sy)
                    if ($c.A -lt 250) { $opaque = $false; break }
                    $v = 0.299*$c.R + 0.587*$c.G + 0.114*$c.B
                    $sum += $v; $sumSq += $v*$v; $n++
                }
            }
            if (-not $opaque -or $n -eq 0) { continue }

            $mean = $sum / $n
            $var  = $sumSq/$n - $mean*$mean
            if ($var -lt $bestVar) { $bestVar = $var; $best = @($x, $y) }
        }
    }

    if (-not $best) { throw "no fully opaque material patch found" }
    return @($best[0], $best[1], $size, $size, [Math]::Sqrt($bestVar))
}

$vanilla = New-Object System.Drawing.Bitmap((Join-Path $GAME "Parcel1.png"))

# Luminance of vanilla's atlas and its statistics, so the tape threshold is derived
# rather than guessed and survives a vanilla art change.
$lum = New-Object 'double[,]' 64,64
$sum = 0.0; $sumSq = 0.0
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 64; $x++) {
        $c = $vanilla.GetPixel($x, $y)
        $v = 0.299*$c.R + 0.587*$c.G + 0.114*$c.B
        $lum[$x,$y] = $v; $sum += $v; $sumSq += $v*$v
    }
}
$lumMean = $sum / 4096
$lumSd   = [Math]::Sqrt($sumSq/4096 - $lumMean*$lumMean)
$tapeAt  = $lumMean + $TAPE_SD * $lumSd

foreach ($tier in $TIERS) {

    $iso = New-Object System.Drawing.Bitmap((Join-Path $art ("{0}_icon.png" -f $tier.key)))

    # ---------------------------------------------------------------- the icon
    #
    # Trimmed to its own alpha bounds so the box fills the 32 pixels instead of sharing
    # them with empty margin, squared so a wide pallet is not stretched into a cube, and
    # reduced in steps -- bicubic straight down from 1200 throws away most of the detail
    # it should be averaging, and the result reads as mush at the size it is seen.

    $b = Get-AlphaBounds $iso
    $side   = [Math]::Max($b[2], $b[3])
    $square = New-Canvas $side $side
    $g = New-Graphics $square
    Draw-Region $g $iso ([int](($side-$b[2])/2)) ([int](($side-$b[3])/2)) $b[2] $b[3] $b[0] $b[1] $b[2] $b[3]
    $g.Dispose()

    $step = $square
    foreach ($size in @(256, 96, 32)) {
        $next = New-Canvas $size $size
        $g = New-Graphics $next
        Draw-Region $g $step 0 0 $size $size 0 0 $step.Width $step.Height
        $g.Dispose(); $step.Dispose(); $step = $next
    }
    $iconPath = Join-Path $textures ("{0}.png" -f $tier.icon)
    $step.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $step.Dispose(); $square.Dispose()
    Write-Host ("{0,-10} icon   content {1}x{2} -> {3}" -f $tier.key, $b[2], $b[3], (Split-Path $iconPath -Leaf))

    # --------------------------------------------------------- the world texture
    # --------------------------------------------------------- the world texture
    #
    # Painted into OUR grid, not into vanilla's atlas. The meshes in
    # tools/blender_parcels.py are unwrapped to the layout in $CELLS, so for the first
    # time a pixel put in the FRONT cell comes out on the front of the box.
    #
    # Flat material per cell, and deliberately flat: the mesh now carries real bevels and
    # a real frame, so the light does the shading. Baking shading in as well would fight
    # the geometry and look painted-on from every angle but one.
    #
    # This is the starting texture, not the finished one. art/models/uv_layout.png is the
    # same grid with the cells labelled -- paint stamps and shipping labels straight onto
    # it and they land where you put them.

    $faces = New-Object System.Drawing.Bitmap((Join-Path $art ("{0}_faces.png" -f $tier.key)))
    $patch = Find-MaterialPatch $faces 160 24
    Write-Host ("{0,-10} material patch ({1},{2}) {3}px, sd {4:N1}" -f $tier.key, $patch[0], $patch[1], $patch[2], $patch[4])

    # 384x256 keeps the six body cells square-ish at 3:2. Vanilla's parcels are 64x64,
    # so this is generous without being wasteful.
    $TW = 384; $TH = 256
    $world = New-Canvas $TW $TH
    $g = New-Graphics $world

    foreach ($cellName in @("front","back","left","right","top","bottom")) {
        $c = $CELLS_UV[$cellName]
        # v runs upward in UV space and downward in pixels.
        $dx = [int]($c[0] * $TW); $dw = [int](($c[2] - $c[0]) * $TW)
        $dy = [int]((1 - $c[3]) * $TH); $dh = [int](($c[3] - $c[1]) * $TH)
        Draw-Region $g $faces $dx $dy $dw $dh $patch[0] $patch[1] $patch[2] $patch[3]
    }

    # The trim strip: strapping on the left half, bare timber on the right. Both are flat
    # colours read off the art, because a strap is a strap from every angle and the posts
    # and pallet boards are too small on screen to carry grain.
    $band = [System.Drawing.Color]::FromArgb(255, $tier.band[0], $tier.band[1], $tier.band[2])
    $wood = [System.Drawing.Color]::FromArgb(255, $tier.timber[0], $tier.timber[1], $tier.timber[2])
    $sc = $CELLS_UV["strap"];  $tc = $CELLS_UV["timber"]
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $band),
                     [int]($sc[0]*$TW), [int]((1-$sc[3])*$TH), [int](($sc[2]-$sc[0])*$TW), [int](($sc[3]-$sc[1])*$TH))
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $wood),
                     [int]($tc[0]*$TW), [int]((1-$tc[3])*$TH), [int](($tc[2]-$tc[0])*$TW), [int](($tc[3]-$tc[1])*$TH))
    $g.Dispose()

    # Every pixel opaque. A world model is not alpha tested, and a stray sub-255 alpha
    # from a resample shows as a hole in the mesh rather than as a soft edge.
    for ($y = 0; $y -lt $TH; $y++) {
        for ($x = 0; $x -lt $TW; $x++) {
            $c = $world.GetPixel($x, $y)
            if ($c.A -ne 255) { $world.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B)) }
        }
    }

    $worldPath = Join-Path $worldDir ("{0}.png" -f $tier.world)
    $world.Save($worldPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("{0,-10} world  -> {1} ({2}x{3}, our UV grid)" -f $tier.key, (Split-Path $worldPath -Leaf), $TW, $TH)

    $world.Dispose(); $faces.Dispose(); $iso.Dispose()
}
