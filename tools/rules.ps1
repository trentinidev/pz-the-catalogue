<#
  Pricing rules.

  NO LONGER GENERATE ANYTHING. tools/gen_prices.ps1 dot-sourced this file to build
  TC_PriceTable.lua; since 0.11.1 that table is imported from the vanilla price study by
  tools/import_prices.sh and the generator is gone.

  This file is kept because it is the readable twin of TC_ModPricing.lua, which prices
  items from OTHER mods at runtime and encodes these same judgements. The study will
  never cover those. Change the two together.

  Everything here is early-90s Kentucky retail, priced by WHAT THE THING IS. Weight is
  used only as a gentle modifier inside a class, never as the main signal -- that was
  the flaw that made a gold necklace and a corkscrew both cost $4.

  Each rule returns a dollar figure for one parsed item, or $null to fall through to
  the next rule. Order matters: Price-Item tries them in the order listed at the bottom.
#>

# ---------------------------------------------------------------------------
# Shared shapes
# ---------------------------------------------------------------------------

# A gentle weight nudge INSIDE a class: a big jacket beats a small one, but not by much.
function WeightNudge { param($it, $pivot = 1.0, $strength = 0.25)
    $w = N $it 'Weight' $pivot
    if ($w -le 0) { $w = $pivot }
    $r = $w / $pivot
    if ($r -gt 4) { $r = 4 }
    if ($r -lt 0.25) { $r = 0.25 }
    return 1.0 + $strength * ($r - 1.0)
}

function Clamp { param($v, $lo, $hi)
    if ($v -lt $lo) { return $lo }
    if ($v -gt $hi) { return $hi }
    return $v
}

# ---------------------------------------------------------------------------
# FOOD -- 1993 grocery prices, scaled by how much food it actually is
# ---------------------------------------------------------------------------

function Rule-Food { param($it)
    if ((P $it 'ItemType') -notmatch 'food') { return $null }

    $cal  = N $it 'Calories' 150
    $name = $it.name

    # Base is the shop price of a typical unit of this kind of food.
    $base = 2.0
    switch -Regex ($name) {
        'Whiskey|Bourbon|Vodka|Gin|Rum|Scotch|Wine|Champagne' { $base = 11.0; break }
        'Beer|Cider|Ale'                                       { $base =  4.0; break }
        'Steak|Beef|Pork|Lamb|Venison|Bacon|Ham(?!burger)'     { $base =  6.5; break }
        'Chicken|Turkey|Duck|Poultry|Rabbit|Fish|Salmon|Trout|Perch|Catfish|Bass|Crappie|Panfish' { $base = 5.0; break }
        'Cheese|Butter|Milk|Cream|Yoghurt|Yogurt|Egg'          { $base =  2.6; break }
        'Canned|Tinned|CannedTin|Jar'                          { $base =  1.2; break }
        'Chocolate|Candy|Sweet|Cookie|Chips|Crisps|Snack|Donut|Cupcake|Muffin|Pie(?!ce)' { $base = 1.2; break }
        'Bread|Baguette|Bagel|Toast|Cereal|Pasta|Rice|Flour|Oats|Noodle' { $base = 1.6; break }
        'Coffee|Tea|Cocoa'                                     { $base =  3.0; break }
        'Pop|Soda|Cola|Juice|Lemonade|Beverage'                { $base =  1.0; break }
        'Water'                                                { $base =  0.6; break }
        'Apple|Banana|Orange|Grape|Berry|Berries|Peach|Pear|Melon|Cherry|Lemon|Lime|Plum|Mango|Fruit' { $base = 1.0; break }
        'Carrot|Potato|Tomato|Cabbage|Lettuce|Onion|Pepper|Broccoli|Bean|Pea(?!nut)|Corn|Radish|Leek|Vegetable|Cucumber|Eggplant|Zucchini' { $base = 0.9; break }
        'Insect|Worm|Grub|Maggot|Cricket|Slug|Snail'           { $base =  0.3; break }
        'Mayonnaise|Ketchup|Mustard|Sauce|Vinegar|Oil|Sugar|Salt|Spice|Herb|Seasoning' { $base = 1.5; break }
    }

    # Calories carry the portion size: a whole ham is not a slice of ham. Capped low,
    # because past a point calories stop tracking price -- a 2,000-calorie tub of lard
    # was never worth four steaks.
    $portion = Clamp ($cal / 250.0) 0.35 2.2
    $price = $base * (0.55 + 0.45 * $portion)

    # A dish someone cooked is worth more than its parts.
    if ((HasTag $it 'base:iscookable') -and $cal -gt 800) { $price *= 1.3 }

    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------
# CLOTHING -- priced as garments, by what body part they cover
# ---------------------------------------------------------------------------

$script:GarmentBase = @{
    'base:tshirt'           = 9;   'base:shirt'        = 20;  'base:jacket'    = 48
    'base:pants'            = 26;  'base:shoes'        = 34;  'base:hat'       = 13
    'base:fullhat'          = 22;  'base:eyes'         = 24;  'base:mask'      = 14
    'base:maskeyes'         = 20;  'base:scarf'        = 12;  'base:neck'      = 10
    'base:hands'            = 13;  'base:handsleft'    = 7;   'base:handsright'= 7
    'base:underwearbottom'  = 6;   'base:underwear'    = 7;   'base:underweartop' = 7
    'base:socks'            = 4;   'base:sweater'      = 30;  'base:sweaterhat'= 34
    'base:jacket_bulky'     = 70;  'base:jacket_down'  = 78;  'base:dress'     = 38
    'base:skirt'            = 24;  'base:torsoextra'   = 26;  'base:torsoextravest' = 34
    'base:belt'             = 12;  'base:beltextra'    = 10;  'base:back'      = 30
    'base:legs1'            = 14;  'base:calf'         = 12;  'base:thigh'     = 12
    'base:forearm'          = 12;  'base:lowerbody'    = 20;  'base:fullsuit'  = 62
    'base:fullsuithead'     = 78;  'base:boilersuit'   = 46;  'base:apron'     = 14
    'base:tail'             = 8;   'base:ears'         = 6;   'base:nose'      = 6
    'base:makeup'           = 5;   'base:zeddmg'       = 0;   'base:wound'     = 0
    'base:bandage'          = 0

    # Every remaining BodyLocation the game actually uses. Enumerated rather than left
    # to a default, because a location that falls through here lands in the generic
    # "normal item" rule and gets priced on weight -- the exact failure this whole file
    # exists to remove. 522 garments were falling through before these were added.

    # Torso variants
    'base:shortsleeveshirt' = 16;  'base:tanktop'      = 10;  'base:jersey'    = 18
    'base:jacketsuit'       = 90;  'base:bathrobe'     = 28;  'base:fulltop'   = 26
    'base:torso1legs1'      = 30;  'base:vesttexture'  = 20
    'base:torsoextravestbullet' = 180              # body armour, priced as equipment

    # Legs
    'base:shortpants'       = 18;  'base:shortsshort'  = 14;  'base:pants_skinny' = 26
    'base:longskirt'        = 30;  'base:longdress'    = 46;  'base:pantsextra'   = 12

    # Limbs, paired left/right -- each half is worth half a pair
    'base:calf_left'        = 6;   'base:calf_right'   = 6
    'base:calf_left_texture'= 6;   'base:calf_right_texture' = 6
    'base:thigh_left'       = 6;   'base:thigh_right'  = 6
    'base:forearm_left'     = 6;   'base:forearm_right'= 6
    'base:elbow_left'       = 7;   'base:elbow_right'  = 7
    'base:knee_left'        = 8;   'base:knee_right'   = 8
    'base:gaiter_left'      = 9;   'base:gaiter_right' = 9
    'base:leftarm'          = 12;  'base:rightarm'     = 12
    'base:shoulderpadleft'  = 10;  'base:shoulderpadright' = 10
    'base:sportshoulderpad' = 22;  'base:sportshoulderpadontop' = 22

    # Head and face
    'base:jackethat'        = 56;  'base:jackethat_bulky' = 82
    'base:maskfull'         = 20;  'base:eartop'       = 6
    'base:lefteye'          = 14;  'base:righteye'     = 14
    'base:makeup_eyes'      = 4;   'base:makeup_eyesshadow' = 4
    'base:makeup_lips'      = 4;   'base:makeup_fullface'   = 6
    'base:neck_texture'     = 8
    'base:gorget'           = 60;  'base:cuirass'      = 140   # armour pieces
    'base:scba'             = 320; 'base:scbanotank'   = 190   # breathing apparatus

    # Jewellery placements. Deliberately near-worthless as GARMENTS: what a gold ring
    # is actually worth comes from TC_Materials.lua, added on top.
    'base:necklace'         = 4;   'base:necklace_long' = 5
    'base:left_middlefinger'= 3;   'base:right_middlefinger' = 3
    'base:left_ringfinger'  = 3;   'base:right_ringfinger'   = 3
    'base:leftwrist'        = 4;   'base:rightwrist'   = 4
    'base:bellybutton'      = 3

    # Carried rigs and holsters
    'base:ammostrap'        = 26;  'base:webbing'      = 30
    'base:shoulderholster'  = 42;  'base:ankleholster' = 34
    'base:fannypackfront'   = 12;  'base:fannypackback'= 12
    'base:satchel'          = 22

    # Underwear extras
    'base:underwearextra1'  = 6;   'base:underwearextra2' = 6;  'base:codpiece' = 8
}

function Rule-Clothing { param($it)
    $loc = P $it 'BodyLocation'
    if ($null -eq $loc) { return $null }

    if (-not $script:GarmentBase.ContainsKey($loc)) { return $null }
    $base = [double]$script:GarmentBase[$loc]
    if ($base -le 0) { return $null }   # wound/bandage overlays are not garments

    # Material. Leather and fur were expensive then and are expensive now.
    switch -Regex ($it.name) {
        'Leather'                 { $base *= 3.0; break }
        'Fur|Shearling|Sheepskin' { $base *= 2.6; break }
        'Denim|Jean'              { $base *= 1.3; break }
        'Suit|Tuxedo|Blazer'      { $base *= 1.8; break }
        'Camo|Military|Army|Combat' { $base *= 1.5; break }
        'Plastic|Paper|Disposable'  { $base *= 0.4; break }
    }

    # Protective gear is priced as equipment, not as clothing: a riot vest was never
    # a garment purchase. Bullet resistance is the expensive part.
    # All three defence ratings run 5..100. A full-rated Kevlar vest lands near $500,
    # which is what body armour cost a civilian in 1993 when it was legal to buy at all.
    $bullet  = N $it 'BulletDefense' 0
    $bite    = N $it 'BiteDefense' 0
    $scratch = N $it 'ScratchDefense' 0
    if ($bullet -gt 0)     { $base += $bullet * 2.2 }
    if ($bite -gt 40)      { $base += ($bite - 40) * 0.6 }
    elseif ($scratch -gt 50) { $base += ($scratch - 50) * 0.25 }

    # Warmth is worth something in a Kentucky winter, but it is not the headline.
    # Insulation runs 0..1, so this is a gentle multiplier and never more than x1.25.
    $ins = Clamp (N $it 'Insulation' 0) 0 1
    if ($ins -gt 0.5) { $base *= (1.0 + ($ins - 0.5) * 0.5) }

    # Barely any weight influence. A heavy coat is worth a little more than a light one
    # of the same kind, but garment weight is close to meaningless as a price signal --
    # left at 0.2 it was applying 1.6x to armour and pushing a vest past an assault
    # rifle, which is not a trade anyone would make.
    $base *= (WeightNudge $it 1.0 0.1)
    return [math]::Max(1, [math]::Round($base))
}

# ---------------------------------------------------------------------------
# LITERATURE -- books, magazines, maps
# ---------------------------------------------------------------------------

function Rule-Literature { param($it)
    if ((P $it 'ItemType') -notmatch 'literature' -and (P $it 'DisplayCategory') -notmatch 'Literature|SkillBook|RecipeResource|Cartography') { return $null }

    if (P $it 'SkillTrained') {
        # Skill books climb with the level they teach; volume 5 is the rare one.
        $lvl = 1
        if ($it.name -match '([1-5])$') { $lvl = [int]$Matches[1] }
        return [math]::Round(22 + ($lvl - 1) * 12)
    }
    if (P $it 'LearnedRecipes') { return 26 }          # how-to magazine
    if ((P $it 'DisplayCategory') -match 'Cartography') { return 9 }
    if (NameLike $it @('Newspaper','Journal','Flyer','Leaflet','Note','Doodle','Letter')) { return 1 }
    if (NameLike $it @('Magazine','Comic')) { return 3 }
    if (NameLike $it @('Book','Novel','Manual','Encyclopedia','Dictionary')) { return 6 }
    return 4
}

# ---------------------------------------------------------------------------
# CONTAINERS -- priced on how much they carry
# ---------------------------------------------------------------------------

function Rule-Container { param($it)
    $cap = N $it 'Capacity' 0
    if ($cap -le 0) { return $null }

    $price = 6 + $cap * 2.6

    # Weight reduction is the premium feature of a good pack.
    $wr = N $it 'WeightReduction' 0
    if ($wr -gt 0) { $price *= (1.0 + $wr / 100.0) }

    switch -Regex ($it.name) {
        'Leather'                    { $price *= 2.2; break }
        'Military|Army|ALICE|Camo|SWAT' { $price *= 1.8; break }
        'Crude|Improvised|Sheet|Tarp|Plastic|Garbage' { $price *= 0.35; break }
    }
    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------
# WEAPONS -- the object's shop price, not its combat stats
# ---------------------------------------------------------------------------

function Rule-Weapon { param($it)
    if ((P $it 'ItemType') -notmatch 'weapon') { return $null }

    #[[ Some categories are building materials that happen to be swingable.
    #
    #   A plank is a plank. The game files it under MaterialWeapon because you CAN hit
    #   something with it, but nobody has ever bought one as a weapon, and pricing it
    #   off MaxDamage put a length of timber at $24. These fall through to the normal
    #   rule, which prices them as the materials they are. ]]
    if ((P $it 'DisplayCategory' '') -match '^(MaterialWeapon|JunkWeapon|HouseholdWeapon)$') {
        return $null
    }

    # Anything hand-made from scrap is worth scrap money, whatever it hits for.
    if (NameLike $it @('Crude','Improvised','Makeshift','_Scrap','Stone$','Bone$','Flint')) {
        return [math]::Max(2, [math]::Round(4 * (WeightNudge $it 1.5 0.5)))
    }

    $dmg  = N $it 'MaxDamage' 1
    $cond = N $it 'ConditionMax' 10
    $cat  = P $it 'DisplayCategory' ''

    # A manufactured tool is priced as a tool; the damage only sorts within the class.
    $base = 10.0
    switch -Regex ($cat) {
        'ToolWeapon'          { $base = 16.0; break }
        'SportsWeapon'        { $base = 14.0; break }
        'HouseholdWeapon|CookingWeapon|JunkWeapon|MaterialWeapon' { $base = 6.0; break }
        'InstrumentWeapon'    { $base = 45.0; break }
        'GardeningWeapon'     { $base = 12.0; break }
        'VehicleMaintenanceWeapon' { $base = 14.0; break }
        'BrokenWeapon'        { return 1 }
    }

    $price = $base * (0.6 + 0.25 * $dmg) * (0.7 + 0.03 * $cond)
    $price *= (WeightNudge $it 1.5 0.3)
    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------
# DRAINABLES -- consumables sold by the bottle
# ---------------------------------------------------------------------------

function Rule-Drainable { param($it)
    if ((P $it 'ItemType') -notmatch 'drainable') { return $null }

    $base = 4.0
    switch -Regex ($it.name) {
        'Bleach|Cleaner|Detergent|Soap|Disinfect' { $base = 3.0; break }
        'Petrol|Gas(?!k)|Fuel|Diesel'             { $base = 6.0; break }
        'Paint'                                   { $base = 9.0; break }
        'Glue|Tape|Twine|Thread|Wire'             { $base = 3.5; break }
        'Propane|Welding|Torch'                   { $base = 18.0; break }
        'Cigarette|Tobacco'                       { $base = 2.5; break }
        'Battery'                                 { $base = 3.0; break }
    }
    $price = $base * (WeightNudge $it 1.0 0.4)
    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------
# FURNITURE -- second-hand prices, because that is what looting is
# ---------------------------------------------------------------------------

function Rule-Moveable { param($it)
    if ((P $it 'DisplayCategory') -notmatch 'Furniture' -and (P $it 'ItemType') -notmatch 'moveable') { return $null }

    $w = N $it 'Weight' 10
    $price = 6 + $w * 1.4

    switch -Regex ($it.name) {
        'Television|TV|Stereo|Hifi|Amplifier|Speaker' { $price *= 3.0; break }
        'Fridge|Freezer|Oven|Stove|Microwave|Washer|Dryer|Dishwasher' { $price *= 2.4; break }
        'Piano|Organ'                  { $price *= 3.5; break }
        'Antique|Ornate|Fancy|Marble'  { $price *= 2.0; break }
        'Broken|Damaged|Burnt|Rusty'   { $price *= 0.25; break }
    }
    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------
# EVERYTHING ELSE -- the 1,099-item "normal" grab bag
# ---------------------------------------------------------------------------

function Rule-Normal { param($it)
    $cat = P $it 'DisplayCategory' 'Generic'
    $w   = N $it 'Weight' 0.5

    #[[ Building material is sold BY QUANTITY, so it is priced linearly by weight.
    #
    #   MetalValue looked like the obvious signal and is not one: it is a crafting
    #   yield, not a price, and it does not even scale consistently -- a box of nails
    #   declares 1.0 while a carton of the same nails declares 1200. Pricing off it put
    #   a carton of nails at $3,002.
    #
    #   Weight is honest here in a way it is nowhere else in this file: a kilo of nails
    #   really is worth about twice what half a kilo of nails is worth. Roughly $2.50 a
    #   kilo puts a plank at $3 and a 20 kg carton of nails at $50, both about right for
    #   1993. ]]
    if ($cat -match '^(Material|MaterialWeapon|JunkWeapon)$') {
        $rate = 2.5
        if ($cat -eq 'JunkWeapon') { $rate = 1.2 }
        return [math]::Max(1, [math]::Round($w * $rate))
    }

    $base = 4.0
    switch -Regex ($cat) {
        'Ammo'           { $base = 9.0;  break }
        'Explosives'     { $base = 65.0; break }
        'Electronics'    { $base = 34.0; break }
        'Communications' { $base = 42.0; break }
        'Instrument'     { $base = 70.0; break }
        'Security'       { $base = 50.0; break }
        'FirstAid'       { $base = 9.0;  break }
        'Bandage'        { $base = 1.5;  break }
        'Tool'           { $base = 13.0; break }
        'VehicleMaintenance' { $base = 24.0; break }
        'Camping'        { $base = 16.0; break }
        'Fishing'        { $base = 11.0; break }
        'Trapping'       { $base = 9.0;  break }
        'LightSource'    { $base = 13.0; break }
        'FireSource'     { $base = 2.5;  break }
        'Gardening'      { $base = 4.5;  break }
        'Cooking'        { $base = 6.0;  break }
        'WaterContainer' { $base = 8.0;  break }
        'Household'      { $base = 5.0;  break }
        'Paint'          { $base = 5.0;  break }
        'Material'       { $base = 3.0;  break }
        'Junk'           { $base = 1.0;  break }
        'Memento'        { $base = 3.0;  break }
        'Teddy'          { $base = 4.0;  break }
        'AnimalPart'     { $base = 3.0;  break }
        'Sports'         { $base = 13.0; break }
        'Entertainment'  { $base = 9.0;  break }
        'Appearance'     { $base = 5.0;  break }
        'Accessory'      { $base = 7.0;  break }
        'Bug'            { $base = 0.5;  break }
        'WeaponPart'     { $base = 48.0; break }
        # Swingable building materials routed here from Rule-Weapon
        'MaterialWeapon' { $base = 2.5;  break }
        'JunkWeapon'     { $base = 1.5;  break }
        'HouseholdWeapon'{ $base = 5.0;  break }
    }

    $price = $base * (WeightNudge $it 1.0 0.45)
    return [math]::Max(1, [math]::Round($price))
}

# ---------------------------------------------------------------------------

$script:Rules = @(
    'Rule-Food', 'Rule-Clothing', 'Rule-Literature', 'Rule-Container',
    'Rule-Weapon', 'Rule-Drainable', 'Rule-Moveable', 'Rule-Normal'
)
