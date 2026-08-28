# The Catalogue -- draw the UV layout guide for the parcel meshes.
#
#     powershell -ExecutionPolicy Bypass -File tools\gen_uv_guide.ps1
#
# Reads art/models/uv_cells.txt, which tools/blender_parcels.py writes from the same
# table it unwraps the meshes with. Reading it rather than repeating the numbers is the
# point: a guide that describes a layout the mesh no longer uses is worse than no guide,
# because it will be believed.
#
# Blender does ship a UV layout exporter, which would draw the actual islands rather than
# the cells they sit in -- but it renders through the GPU and there is no GPU in
# --background. The build verifies instead: every UV coordinate must land inside a
# declared cell or blender_parcels.py fails. This picture is for painting against.

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$root  = Split-Path -Parent $PSScriptRoot
$cells = Join-Path $root "art\models\uv_cells.txt"
if (-not (Test-Path $cells)) {
    throw "missing $cells -- run tools\blender_parcels.py first"
}

# The recommended texture size: the six body cells come out square at 3:2.
# texW/texH, not W/H: PowerShell variable names are CASE-INSENSITIVE, so a $w holding
# a cell width inside the loop IS the $W holding the texture width, and every cell after
# the first was placed against the previous one's size.
$texW = 384; $texH = 256

$tint = @{
    front = @(70,90,120);  back  = @(60,78,104); left   = @(78,70,110)
    right = @(90,72,96);   top   = @(70,110,90); bottom = @(56,64,72)
    strap = @(120,86,54);  timber = @(96,74,44)
}

$guide = New-Object System.Drawing.Bitmap $texW, $texH
$g = [System.Drawing.Graphics]::FromImage($guide)
$g.Clear([System.Drawing.Color]::FromArgb(255, 32, 32, 36))
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$font = New-Object System.Drawing.Font "Consolas", 11, ([System.Drawing.FontStyle]::Bold)
$pen  = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 210, 210, 220)), 1

$n = 0
foreach ($line in [System.IO.File]::ReadAllLines($cells)) {
    if ($line.StartsWith("#") -or $line.Trim() -eq "") { continue }
    $t = $line.Split(" ")
    $name = $t[0]
    $u0 = [double]$t[1]; $v0 = [double]$t[2]; $u1 = [double]$t[3]; $v1 = [double]$t[4]

    # v runs upward in UV space and downward in pixels, hence the flip.
    $x = [int]($u0 * $texW); $y = [int]((1 - $v1) * $texH)
    $cw = [int](($u1 - $u0) * $texW); $ch = [int](($v1 - $v0) * $texH)

    $c = $tint[$name]
    if (-not $c) { $c = @(80,80,88) }
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $c[0], $c[1], $c[2]))
    $g.FillRectangle($brush, $x, $y, $cw, $ch)
    $g.DrawRectangle($pen, $x, $y, $cw, $ch)
    $g.DrawString($name.ToUpper(), $font, [System.Drawing.Brushes]::White, ($x + 6), ($y + 6))
    $n++
}
$g.Dispose()

$out = Join-Path $root "art\models\uv_layout.png"
$guide.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$guide.Dispose()
Write-Host ("uv_layout.png  {0}x{1}, {2} cells from uv_cells.txt" -f $texW, $texH, $n)
