# The Catalogue -- build the item icon and the world-model texture from the art renders.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_art.ps1 -Source <folder>
#
# WHY THIS IS A SCRIPT. Both outputs are tiny -- 32x32 and 64x64 -- and both are derived
# from 1254px renders by rules that are easy to get subtly wrong and impossible to spot
# afterwards: which rectangle of the sheet is the cover, how the cover is squashed, where
# the page block starts. Written down, the art can be re-rendered and the assets rebuilt
# without anyone having to remember any of it.
#
# THE WORLD TEXTURE IS NOT A FREE CANVAS. It re-skins vanilla's WorldItems/Catalogue
# mesh, so its layout is fixed by that mesh's UVs, measured off vanilla's own 64x64:
#
#     columns 0..56   the cover, squashed to 57x64 (the mesh stretches it back)
#     columns 57..63  the fore-edge, i.e. the block of page ends
#
# Change those and the cover wraps around onto the pages.

param(
    [string]$Source = "$env:USERPROFILE\Downloads"
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root      = Split-Path -Parent $PSScriptRoot
$textures  = Join-Path $root "42\media\textures"
$iconSrc   = Join-Path $Source "catalog_icon.png"
$sheetSrc  = Join-Path $Source "catalog_model.png"

foreach ($f in @($iconSrc, $sheetSrc)) {
    if (-not (Test-Path $f)) { throw "missing source render: $f" }
}

# Panels on the reference sheet, in source pixels. Measured once from the 1254x1254
# render; re-measure if the sheet is ever re-laid-out.
$COVER = @{ x = 654;  y = 67;  w = 239; h = 411 }   # the FRONT panel
$PAGES = @{ x = 1022; y = 542; w = 73;  h = 296 }   # the RIGHT panel, the fore-edge

function New-Canvas([int]$w, [int]$h) {
    $b = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    return $b
}

function New-Graphics($bitmap) {
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    # SourceCopy, so a transparent source pixel stays transparent instead of being
    # blended against the empty (black) canvas and leaving a dark fringe.
    $g.CompositingMode    = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    return $g
}

# TileFlipXY on the draw stops GDI+ sampling past the edge of the source, which is what
# puts a one-pixel dark rim around a downscaled image.
function Draw-Region($g, $src, $dx, $dy, $dw, $dh, $sx, $sy, $sw, $sh) {
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
    $dest = New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)
    $g.DrawImage($src, $dest, $sx, $sy, $sw, $sh, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $attr.Dispose()
}

# ---------------------------------------------------------------------------
# 1. The inventory icon, 32x32
# ---------------------------------------------------------------------------
#
# Down from 1254px in steps rather than in one jump: bicubic over a 39x reduction
# throws away most of the detail it should be averaging, and the result reads as mush
# at the size it will actually be seen.

$icon = New-Object System.Drawing.Bitmap($iconSrc)

# Trim the transparent margin first, so the book fills the 32 pixels instead of sharing
# them with empty space.
$minX = $icon.Width; $minY = $icon.Height; $maxX = 0; $maxY = 0
for ($y = 0; $y -lt $icon.Height; $y += 2) {
    for ($x = 0; $x -lt $icon.Width; $x += 2) {
        if ($icon.GetPixel($x, $y).A -gt 8) {
            if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
$cw = $maxX - $minX + 1
$ch = $maxY - $minY + 1
Write-Host ("icon    content {0}x{1} at ({2},{3})" -f $cw, $ch, $minX, $minY)

# Onto a square canvas, centred, so the shape is not squashed by the square icon slot.
$side   = [Math]::Max($cw, $ch)
$square = New-Canvas $side $side
$g = New-Graphics $square
Draw-Region $g $icon ([int](($side - $cw) / 2)) ([int](($side - $ch) / 2)) $cw $ch $minX $minY $cw $ch
$g.Dispose()

$step = $square
foreach ($size in @(256, 96, 32)) {
    $next = New-Canvas $size $size
    $g = New-Graphics $next
    Draw-Region $g $step 0 0 $size $size 0 0 $step.Width $step.Height
    $g.Dispose()
    $step.Dispose()
    $step = $next
}

$iconOut = Join-Path $textures "Item_ShopCatalogue.png"
$step.Save($iconOut, [System.Drawing.Imaging.ImageFormat]::Png)
$step.Dispose(); $square.Dispose(); $icon.Dispose()
Write-Host "icon    -> $iconOut (32x32)"

# ---------------------------------------------------------------------------
# 2. The world-model texture, 64x64
# ---------------------------------------------------------------------------

$sheet = New-Object System.Drawing.Bitmap($sheetSrc)
$world = New-Canvas 64 64
$g = New-Graphics $world

Draw-Region $g $sheet 0  0 57 64 $COVER.x $COVER.y $COVER.w $COVER.h
Draw-Region $g $sheet 57 0  7 64 $PAGES.x $PAGES.y $PAGES.w $PAGES.h
$g.Dispose()

# Force every pixel opaque. A world model is not alpha-tested, and a stray sub-255 alpha
# from the resample would show as a hole in the mesh rather than as a soft edge.
for ($y = 0; $y -lt 64; $y++) {
    for ($x = 0; $x -lt 64; $x++) {
        $c = $world.GetPixel($x, $y)
        if ($c.A -ne 255) {
            $world.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B))
        }
    }
}

$worldDir = Join-Path $textures "TheCatalogue"
New-Item -ItemType Directory -Force -Path $worldDir | Out-Null
$worldOut = Join-Path $worldDir "ShopCatalogueWorld.png"
$world.Save($worldOut, [System.Drawing.Imaging.ImageFormat]::Png)
$world.Dispose(); $sheet.Dispose()
Write-Host "world   -> $worldOut (64x64, cover 0..56, fore-edge 57..63)"
