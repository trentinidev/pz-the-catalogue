# The Catalogue -- build the three oversized-parcel inventory icons.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_parcel_art.ps1
#
# Sources live in art/, so this is reproducible from a clean clone rather than from
# whatever happens to be in someone's Downloads folder.
#
# ICONS ONLY. World textures were built here too, for meshes of our own. Those were
# abandoned after four attempts at working out how the game scales an FBX, none of which
# survived contact with the box on the tile. The parcels wear vanilla's extra-large model
# now, and the tiers are told apart by these icons -- which is where the difference was
# always going to be read anyway.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root     = Split-Path -Parent $PSScriptRoot
$art      = Join-Path $root "art"
$textures = Join-Path $root "42\media\textures"

$TIERS = @(
    @{ key = "parcel25";  icon = "Item_ParcelXXL"  },
    @{ key = "parcel50";  icon = "Item_Parcel5XL"  },
    @{ key = "parcel100"; icon = "Item_Parcel10XL" }
)

function New-Canvas([int]$w, [int]$h) {
    return New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function New-Graphics($bitmap) {
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    # SourceCopy so a transparent source pixel stays transparent rather than being blended
    # against an empty canvas and leaving a dark fringe.
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

foreach ($tier in $TIERS) {
    $iso = New-Object System.Drawing.Bitmap((Join-Path $art ("{0}_icon.png" -f $tier.key)))

    # Trimmed to its own alpha bounds so the box fills the 32 pixels instead of sharing
    # them with empty margin, squared so a wide pallet is not stretched into a cube, and
    # reduced in steps -- bicubic straight down from 1200 throws away most of the detail
    # it should be averaging, and the result reads as mush at the size it is seen.
    $b = Get-AlphaBounds $iso
    $side   = [Math]::Max($b[2], $b[3])
    $square = New-Canvas $side $side
    $g = New-Graphics $square
    Draw-Region $g $iso ([int](($side - $b[2]) / 2)) ([int](($side - $b[3]) / 2)) $b[2] $b[3] $b[0] $b[1] $b[2] $b[3]
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
    $step.Dispose(); $square.Dispose(); $iso.Dispose()
    Write-Host ("{0,-10} content {1}x{2} -> {3} (32x32)" -f $tier.key, $b[2], $b[3], (Split-Path $iconPath -Leaf))
}
