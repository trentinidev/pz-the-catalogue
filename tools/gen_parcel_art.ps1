# The Catalogue -- build the three oversized-parcel inventory icons from the art sheet.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_parcel_art.ps1 -Source <folder>
#
# SOURCE. parcels_exemples.png, the comparison sheet, because it is the only render that
# arrived with an alpha channel. The individual beauty sheets are prettier but sit on an
# opaque vignette, and keying a dark olive tarp out of a dark glow is the kind of job
# that leaves a halo nobody notices until the icon is on a lit inventory background.
#
# The three renders are found by their own alpha rather than by hardcoded rectangles, so
# a re-render that shifts them by a few pixels still works. Only their horizontal split
# is fixed, and only because three boxes on one row is the sheet's layout, not a
# measurement.

param(
    [string]$Source = "$env:USERPROFILE\Downloads"
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root     = Split-Path -Parent $PSScriptRoot
$textures = Join-Path $root "42\media\textures"
$sheetSrc = Join-Path $Source "parcels_exemples.png"

if (-not (Test-Path $sheetSrc)) { throw "missing source render: $sheetSrc" }

# The band of the sheet holding the three large isometric renders, and the column ranges
# each one occupies. Found by scanning the sheet's alpha; see the header.
#
# The band starts below the per-tier captions. Those are grey text with real alpha, so a
# band that includes them makes every icon a box with a line of type floating above it.
$BAND  = @{ top = 92; bottom = 456 }
$TIERS = @(
    @{ name = "Parcel_XXL";  x0 = 105;  x1 = 410;  icon = "Item_ParcelXXL"  },
    @{ name = "Parcel_5XL";  x0 = 591;  x1 = 937;  icon = "Item_Parcel5XL"  },
    @{ name = "Parcel_10XL"; x0 = 1054; x1 = 1453; icon = "Item_Parcel10XL" }
)

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

function Draw-Region($g, $src, $dx, $dy, $dw, $dh, $sx, $sy, $sw, $sh) {
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $dest = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
    $g.DrawImage($src, $dest, $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $attr.Dispose()
}

$sheet = New-Object System.Drawing.Bitmap($sheetSrc)

foreach ($tier in $TIERS) {

    # Vertical bounds from the alpha, so the icon is not padded with the empty space
    # above and below whichever box happens to be shortest. The three tiers are drawn at
    # different heights on the sheet and each one should fill its own 32 pixels.
    $minY = $BAND.bottom; $maxY = $BAND.top
    for ($y = $BAND.top; $y -lt $BAND.bottom; $y++) {
        for ($x = $tier.x0; $x -le $tier.x1; $x += 2) {
            if ($sheet.GetPixel($x, $y).A -gt 96) {
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
                break
            }
        }
    }

    $cw = $tier.x1 - $tier.x0 + 1
    $ch = $maxY - $minY + 1
    Write-Host ("{0,-12} content {1}x{2} at ({3},{4})" -f $tier.name, $cw, $ch, $tier.x0, $minY)

    # Square canvas, centred, so a wide pallet is not stretched into a cube by the
    # square icon slot.
    $side   = [Math]::Max($cw, $ch)
    $square = New-Canvas $side $side
    $g = New-Graphics $square
    Draw-Region $g $sheet ([int](($side - $cw) / 2)) ([int](($side - $ch) / 2)) $cw $ch $tier.x0 $minY $cw $ch
    $g.Dispose()

    # Reduced in steps. Bicubic straight down to 32 from 400 throws away most of the
    # detail it should be averaging, and the result reads as mush at the size it is
    # actually seen.
    $step = $square
    foreach ($size in @(256, 96, 32)) {
        $next = New-Canvas $size $size
        $g = New-Graphics $next
        Draw-Region $g $step 0 0 $size $size 0 0 $step.Width $step.Height
        $g.Dispose()
        $step.Dispose()
        $step = $next
    }

    $outPath = Join-Path $textures ("{0}.png" -f $tier.icon)
    $step.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $step.Dispose()
    Write-Host ("{0,-12} -> {1} (32x32)" -f $tier.name, $outPath)
}

$sheet.Dispose()

# ---------------------------------------------------------------------------
# The 50's world texture: a wooden crate on vanilla's cardboard-box mesh
# ---------------------------------------------------------------------------
#
# WHY NOT JUST USE THE ART. The reference sheet gives six flat faces, which is what you
# would paint onto a UV atlas -- and the atlas here belongs to vanilla's Parcel_Present_1
# mesh, whose UV layout is inside a binary FBX. Guessing which rectangle is which face is
# how you ship a box with a shipping label wrapped around a corner.
#
# So this never moves a pixel. It takes vanilla's own Parcel1 atlas, which is already
# correct for that mesh, and swaps the MATERIAL underneath it:
#
#   - the wood comes from vanilla's CrateBasic, a real plank texture
#   - vanilla's per-face shading is kept as a multiplier, so the crate still reads as a
#     lit box rather than as a flat sticker
#   - the tape, the brightest thing in the atlas, becomes the dark strapping the art
#     shows -- and it lands correctly on the mesh precisely because it is vanilla's tape
#
# What it does not get is the art's own plank spacing, corner brackets and FRAGILE stamp.
# Those need the real UVs, or a mesh of our own.

$GAME     = "S:\SteamLibrary\steamapps\common\ProjectZomboid\media\textures\WorldItems"
$STRAP    = [System.Drawing.Color]::FromArgb(255, 46, 44, 46)
$TAPE_SD  = 1.5      # how far above mean luminance counts as tape; measured, see above

$vanilla = New-Object System.Drawing.Bitmap((Join-Path $GAME "Parcel1.png"))
$plankSrc = New-Object System.Drawing.Bitmap((Join-Path $GAME "CrateBasic.png"))

# The planks, taken as a 1:1 CROP of the 128px source rather than a downscale of the
# whole thing. Downscaled, four planks became eight smeared ones and the crate read as
# brown noise; cropped, the grain survives at the size it will be drawn. Offset past the
# top rail so the tile is planks and nothing else.
$wood = New-Canvas 64 64
$g = New-Graphics $wood
Draw-Region $g $plankSrc 0 0 64 64 4 26 64 64
$g.Dispose()

# Luminance statistics of the vanilla atlas, so the tape threshold is derived rather
# than guessed at, and survives a vanilla art change.
$sum = 0.0; $sumSq = 0.0
$lum = New-Object 'double[,]' 64,64
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 64; $x++) {
        $c = $vanilla.GetPixel($x, $y)
        $v = 0.299*$c.R + 0.587*$c.G + 0.114*$c.B
        $lum[$x,$y] = $v
        $sum += $v; $sumSq += $v*$v
    }
}
$mean = $sum / 4096
$sd   = [Math]::Sqrt($sumSq/4096 - $mean*$mean)
$tapeAt = $mean + $TAPE_SD * $sd

$crate = New-Canvas 64 64
$straps = 0
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 64; $x++) {
        if ($lum[$x,$y] -gt $tapeAt) {
            $crate.SetPixel($x, $y, $STRAP)
            $straps++
        } else {
            # Wood, carrying vanilla's per-face shading -- but COMPRESSED into a narrow
            # band. Used raw, the ratio runs from 0.33 to 1.34 and the dark faces come
            # out as mud; the point is to keep the faces distinguishable, not to repaint
            # the wood with vanilla's cardboard tones.
            $w = $wood.GetPixel($x, $y)
            $t = ($lum[$x,$y] - ($mean - 1.5*$sd)) / (3.0*$sd)
            if ($t -lt 0) { $t = 0 }; if ($t -gt 1) { $t = 1 }
            $k = 0.78 + 0.44 * $t
            $r = [Math]::Min(255, [int]($w.R * $k))
            $gg= [Math]::Min(255, [int]($w.G * $k))
            $b = [Math]::Min(255, [int]($w.B * $k))
            $crate.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $r, $gg, $b))
        }
    }
}

$worldDir = Join-Path $textures "TheCatalogue"
New-Item -ItemType Directory -Force -Path $worldDir | Out-Null
$cratePath = Join-Path $worldDir "Parcel5XLWorld.png"
$crate.Save($cratePath, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host ("Parcel_5XL   -> {0} (64x64, {1} strap px, tape threshold {2:N1})" -f $cratePath, $straps, $tapeAt)

$crate.Dispose(); $wood.Dispose(); $vanilla.Dispose(); $plankSrc.Dispose()
