# The Catalogue -- how big is a mesh, in its own units?
#
#     powershell -ExecutionPolicy Bypass -File tools/fbx_bbox.ps1 -Path some.fbx
#
# WHY THIS EXISTS. The scale in a PZ model block is a number nobody can check by reading
# it: a mesh that is twice too big and a scale that is half too small look exactly like a
# correct pair until the thing is on a tile in front of you. The oversized parcels cost a
# round of that -- custom meshes, four readings of how PZ scales an FBX, none of them
# holding up, and the meshes pulled in the end.
#
# So: measure the new mesh, measure the vanilla one whose scale is known to work, and if
# they are the same size the known-good scale carries over. That is how 0.10.2-beta settled
# the catalogue on 0.125 without a single launch of the game.
#
# It also reports the axis ORDER, which is the other half of the answer -- two meshes can
# be the same size and still disagree about which way is up.
#
# Finds the "Vertices" node by name and decodes just that one array. No tree walking: the
# property layout after a node name is fixed, and a full FBX parser is a lot of PowerShell
# to answer one question.
param([string]$Path)
$b = [System.IO.File]::ReadAllBytes($Path)
$needle = [System.Text.Encoding]::ASCII.GetBytes("Vertices")

for ($i = 0; $i -lt $b.Length - 40; $i++) {
    $hit = $true
    for ($j = 0; $j -lt $needle.Length; $j++) { if ($b[$i+$j] -ne $needle[$j]) { $hit = $false; break } }
    if (-not $hit) { continue }
    # the byte before the name is its length; the byte after the name should be a type char
    if ($b[$i-1] -ne $needle.Length) { continue }

    $p = $i + $needle.Length
    $type = [char]$b[$p]
    if ($type -ne 'd' -and $type -ne 'f') { continue }

    $len  = [BitConverter]::ToUInt32($b, $p+1)
    $enc  = [BitConverter]::ToUInt32($b, $p+5)
    $clen = [BitConverter]::ToUInt32($b, $p+9)
    Write-Output ("found Vertices: type={0} count={1} encoding={2}" -f $type, $len, $enc)

    $raw = New-Object byte[] $clen
    [Array]::Copy($b, $p+13, $raw, 0, $clen)

    if ($enc -eq 1) {
        $in = New-Object System.IO.MemoryStream(,$raw)
        $null = $in.ReadByte(); $null = $in.ReadByte()
        $ds = New-Object System.IO.Compression.DeflateStream($in, [System.IO.Compression.CompressionMode]::Decompress)
        $out = New-Object System.IO.MemoryStream
        $ds.CopyTo($out); $ds.Dispose()
        $raw = $out.ToArray()
    }

    $n = [int]($len / 3)
    $minx=1e30;$miny=1e30;$minz=1e30;$maxx=-1e30;$maxy=-1e30;$maxz=-1e30
    for ($k = 0; $k -lt $n; $k++) {
        if ($type -eq 'd') {
            $x=[BitConverter]::ToDouble($raw,($k*3)*8); $y=[BitConverter]::ToDouble($raw,($k*3+1)*8); $z=[BitConverter]::ToDouble($raw,($k*3+2)*8)
        } else {
            $x=[BitConverter]::ToSingle($raw,($k*3)*4); $y=[BitConverter]::ToSingle($raw,($k*3+1)*4); $z=[BitConverter]::ToSingle($raw,($k*3+2)*4)
        }
        if($x -lt $minx){$minx=$x}; if($x -gt $maxx){$maxx=$x}
        if($y -lt $miny){$miny=$y}; if($y -gt $maxy){$maxy=$y}
        if($z -lt $minz){$minz=$z}; if($z -gt $maxz){$maxz=$z}
    }
    Write-Output ("vertices {0}" -f $n)
    Write-Output ("X {0:N4} .. {1:N4}  size {2:N4}" -f $minx,$maxx,($maxx-$minx))
    Write-Output ("Y {0:N4} .. {1:N4}  size {2:N4}" -f $miny,$maxy,($maxy-$miny))
    Write-Output ("Z {0:N4} .. {1:N4}  size {2:N4}" -f $minz,$maxz,($maxz-$minz))
    exit 0
}
Write-Output "no Vertices array found"
