<#
  Regenerate 42/media/lua/shared/TheCatalogue/TC_PriceTable.lua

  WHY THIS EXISTS. The runtime formula can only see an item's DisplayCategory and its
  weight, because that is all a ScriptItem reliably hands to Lua. Weight is a terrible
  proxy for worth -- it priced a gold necklace and a corkscrew both at $4 -- and the
  category alone cannot tell a t-shirt from a leather jacket.

  Offline we can read EVERYTHING the scripts declare: calories and macronutrients on
  food, MaxDamage and ConditionMax on weapons, Insulation and ScratchDefense and
  BodyLocation on clothing, Capacity on containers, SkillTrained on books, MetalValue,
  and the precious-material tags. So prices are computed here, once, and shipped as a
  plain lookup table. The runtime formula stays only as a fallback for modded items.

  Prices are early-90s Kentucky retail. Anchors, chosen with the player:
      canned beans  $1      an axe        $30
      a shotgun     $250    a generator   $600

  Usage:
      pwsh tools/gen_prices.ps1 "S:\...\ProjectZomboid\media\scripts\generated\items"
#>

param(
    [Parameter(Mandatory = $true)][string]$ItemsDir,
    [string]$OutFile = "$PSScriptRoot\..\42\media\lua\shared\TheCatalogue\TC_PriceTable.lua"
)

# ---------------------------------------------------------------------------
# Parse
# ---------------------------------------------------------------------------

function Parse-Items {
    param([string]$dir)

    $items = @()
    foreach ($file in Get-ChildItem $dir -Filter *.txt) {
        $cur = $null
        $depth = 0
        foreach ($raw in Get-Content $file.FullName) {
            $line = $raw.Trim()

            if ($line -match '^item\s+([A-Za-z0-9_]+)$') {
                $cur = @{ name = $Matches[1]; props = @{}; file = $file.BaseName }
                $depth = 0
                continue
            }
            if ($null -eq $cur) { continue }

            if ($line -eq '{') { $depth++; continue }
            if ($line -eq '}') {
                $depth--
                if ($depth -le 0) { $items += ,$cur; $cur = $null }
                continue
            }
            # Only read the item's own top-level properties, never a nested block's.
            if ($depth -eq 1 -and $line -match '^([A-Za-z_]+)\s*=\s*(.+?),?$') {
                $cur.props[$Matches[1]] = $Matches[2].TrimEnd(',').Trim()
            }
        }
    }
    return $items
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function P { param($it, $key, $default = $null)
    if ($it.props.ContainsKey($key)) { return $it.props[$key] }
    return $default
}
<#
  Parse a number from a script property.

  MUST use InvariantCulture. The plain TryParse overload uses the CURRENT culture, and
  on a pt-BR machine the dot is a thousands separator: "1.0" parses as 10, "0.75" as 75
  and "0.05" as 5. Nothing errors, every number is just silently wrong by a factor of
  ten to a hundred. That is how a bulletproof vest came out at $38,051 -- an Insulation
  of 0.75 read as 75 and turned a x1.1 warmth bonus into x38.
#>
function N { param($it, $key, $default = 0.0)
    $v = P $it $key
    if ($null -eq $v) { return [double]$default }
    $out = 0.0
    if ([double]::TryParse($v,
                           [System.Globalization.NumberStyles]::Float,
                           [System.Globalization.CultureInfo]::InvariantCulture,
                           [ref]$out)) { return $out }
    return [double]$default
}
function HasTag { param($it, $tag)
    $t = P $it 'Tags'
    if ($null -eq $t) { return $false }
    return ($t -split ';') -contains $tag
}
function NameLike { param($it, [string[]]$pats)
    foreach ($p in $pats) { if ($it.name -match $p) { return $true } }
    return $false
}

Write-Host "Parsing $ItemsDir ..."
$items = Parse-Items $ItemsDir
Write-Host ("  parsed {0} items" -f $items.Count)

. "$PSScriptRoot\rules.ps1"

# ---------------------------------------------------------------------------
# Read the two hand-maintained Lua tables back in, so they win over the rules
# ---------------------------------------------------------------------------

#[[ Every ["Base.X"] = N pair in a Lua table file.
#
#   Matches ALL pairs on a line, not just the first. The ammunition block in
#   TC_Overrides.lua packs three entries per line to keep the calibre families
#   readable, and an anchored one-per-line regex silently dropped eighteen of them --
#   the ammo prices simply never reached the generated table.
#]]
function Read-LuaTable {
    param([string]$path)
    $out = @{}
    if (-not (Test-Path $path)) { return $out }
    $rx = [regex]'\["Base\.([A-Za-z0-9_]+)"\]\s*=\s*([0-9]+)'
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*--') { continue }     # skip commented-out entries
        foreach ($m in $rx.Matches($line)) {
            $out[$m.Groups[1].Value] = [int]$m.Groups[2].Value
        }
    }
    return $out
}

$shared    = "$PSScriptRoot\..\42\media\lua\shared\TheCatalogue"
$overrides = Read-LuaTable "$shared\TC_Overrides.lua"
$materials = Read-LuaTable "$shared\TC_Materials.lua"
Write-Host ("  {0} hand-set overrides, {1} material values" -f $overrides.Count, $materials.Count)

# ---------------------------------------------------------------------------
# Price everything
# ---------------------------------------------------------------------------

# Categories the catalogue refuses to trade at all -- corpses, severed parts, the
# wound-modelling items, the invisible Hidden bucket and the live-animal carriers.
# Kept in step with TC_Config.lua.
$excludedCats = @(
    'Hidden','Corpse','MaleBody','Ears','Eye','Tail','Wound','ZedDmg',
    'Animal','Bear','Beaver','Badger','Bunny','Dog','Duck','Fox','Frog','Goblin',
    'Hedgehog','Mole','Raccoon','Spider','Squirrel'
)
$excludedItems = @('Money','MoneyBundle','BareHands')

$priced = @{}
$byRule = @{}
$skipped = 0

foreach ($it in $items) {
    $cat = P $it 'DisplayCategory' 'Generic'
    if ($excludedCats -contains $cat -or $excludedItems -contains $it.name) { $skipped++; continue }

    if ($overrides.ContainsKey($it.name)) {
        $priced[$it.name] = $overrides[$it.name]
        $byRule['(hand-set override)'] = 1 + [int]$byRule['(hand-set override)']
        continue
    }

    $price = $null
    $usedRule = 'none'
    foreach ($rule in $script:Rules) {
        $price = & $rule $it
        if ($null -ne $price) { $usedRule = $rule; break }
    }
    if ($null -eq $price) { $price = 4; $usedRule = 'fallback' }

    # Precious material is added on top of whatever the item is worth as an object.
    if ($materials.ContainsKey($it.name)) {
        $price += $materials[$it.name]
        $usedRule = "$usedRule + material"
    }

    $priced[$it.name] = [int]$price
    $byRule[$usedRule] = 1 + [int]$byRule[$usedRule]
}

Write-Host ("  priced {0} items, skipped {1}" -f $priced.Count, $skipped)
foreach ($k in ($byRule.Keys | Sort-Object)) { Write-Host ("    {0,-28} {1}" -f $k, $byRule[$k]) }

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------

$catOf = @{}
foreach ($it in $items) { $catOf[$it.name] = (P $it 'DisplayCategory' 'Generic') }

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine(@'
--[[ The Catalogue -- the generated price table.

     GENERATED FILE. Do not edit by hand: tools/gen_prices.ps1 rewrites it wholesale.
     To change a price permanently, add it to TC_Overrides.lua (which wins over this
     table) or adjust the rule in tools/rules.ps1 and regenerate.

     Every vanilla item is priced here by WHAT IT IS, using everything the item scripts
     declare -- calories and macronutrients on food, MaxDamage and ConditionMax on
     weapons, BodyLocation and the three defence ratings on clothing, Capacity and
     WeightReduction on bags, SkillTrained on books, MetalValue on scrap, and the
     precious-material tags on jewellery.

     The runtime formula in TC_Prices.lua now only ever runs for items this table has
     never heard of, which in practice means items added by other mods.

     Scale is early-90s Kentucky retail:
         canned beans  $1      an axe        $30
         a shotgun     $250    a generator   $600
]]

TheCatalogue = TheCatalogue or {}

TheCatalogue.PRICE_TABLE = {
'@)

$groups = $priced.Keys | Group-Object { $catOf[$_] } | Sort-Object Name
foreach ($g in $groups) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("    -- $($g.Name) ($($g.Count))")
    foreach ($name in ($g.Group | Sort-Object)) {
        [void]$sb.AppendLine(("    [`"Base.{0}`"] = {1}," -f $name, $priced[$name]))
    }
}
[void]$sb.AppendLine("}")

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path $OutFile) | ForEach-Object { Join-Path $_ (Split-Path $OutFile -Leaf) }), $sb.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Host "Wrote $OutFile"
