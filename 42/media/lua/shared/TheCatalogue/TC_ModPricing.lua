--[[ The Catalogue -- pricing items that came from other mods.

     Vanilla items are priced offline into TC_PriceTable.lua, where the generator can
     read every property the scripts declare. Items from other mods were never seen by
     that generator, so before this file they fell to the category-and-weight formula --
     the same blind formula that priced a gold necklace and a corkscrew at $4 apiece.

     WHY THIS COSTS SOMETHING. The rich properties -- BodyLocation, Calories, Capacity,
     ConditionMax, the defence ratings -- live on InventoryItem, not on the ScriptItem
     the index walks. The only way to read them is to build one instance of the item.
     So the index does exactly that, once per unknown item, at build time.

     That is a real cost and it is paid on the first open of the buy window in a
     session. It is bounded by how many modded items are installed, and it buys prices
     that are as considered as the vanilla ones. The alternative -- pricing thousands
     of modded items on weight alone -- is what this whole file exists to avoid.

     KEEP IN SYNC with tools/rules.ps1. That file prices vanilla from the raw scripts;
     this one prices everything else from a live instance. They encode the same
     judgements and should be changed together.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

-- Defensive getter: several of these exist on some item classes and not others, and a
-- couple (getBulletDefense, getWeightReduction) are not used anywhere in vanilla's own
-- Lua, so their presence is not something to bet the index on.
local function num(item, getter, default)
    local ok, v = pcall(function() return item[getter](item) end)
    if ok and type(v) == "number" then return v end
    return default
end

local function str(item, getter)
    local ok, v = pcall(function() return item[getter](item) end)
    if ok and type(v) == "string" then return v end
    return nil
end

local function nameHas(fullType, pattern)
    return string.find(fullType, pattern) ~= nil
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(p)
    if p < 1 then return 1 end
    return math.floor(p + 0.5)
end

-- A gentle nudge INSIDE a class. Weight is never the main signal here; see the header.
local function weightNudge(w, pivot, strength)
    if type(w) ~= "number" or w <= 0 then w = pivot end
    local r = clamp(w / pivot, 0.25, 4)
    return 1.0 + strength * (r - 1.0)
end

-- ---------------------------------------------------------------------------
-- Garment prices by body part. Mirrors $script:GarmentBase in tools/rules.ps1.
-- ---------------------------------------------------------------------------

local GARMENT = {
    ["base:tshirt"]=9, ["base:shirt"]=20, ["base:jacket"]=48, ["base:pants"]=26,
    ["base:shoes"]=34, ["base:hat"]=13, ["base:fullhat"]=22, ["base:eyes"]=24,
    ["base:mask"]=14, ["base:maskeyes"]=20, ["base:scarf"]=12, ["base:neck"]=10,
    ["base:hands"]=13, ["base:handsleft"]=7, ["base:handsright"]=7,
    ["base:underwearbottom"]=6, ["base:underwear"]=7, ["base:underweartop"]=7,
    ["base:socks"]=4, ["base:sweater"]=30, ["base:sweaterhat"]=34,
    ["base:jacket_bulky"]=70, ["base:jacket_down"]=78, ["base:dress"]=38,
    ["base:skirt"]=24, ["base:torsoextra"]=26, ["base:torsoextravest"]=34,
    ["base:belt"]=12, ["base:beltextra"]=10, ["base:back"]=30, ["base:legs1"]=14,
    ["base:calf"]=12, ["base:thigh"]=12, ["base:forearm"]=12, ["base:lowerbody"]=20,
    ["base:fullsuit"]=62, ["base:fullsuithead"]=78, ["base:boilersuit"]=46,
    ["base:apron"]=14, ["base:tail"]=8, ["base:ears"]=6, ["base:nose"]=6,
    ["base:makeup"]=5,
    ["base:shortsleeveshirt"]=16, ["base:tanktop"]=10, ["base:jersey"]=18,
    ["base:jacketsuit"]=90, ["base:bathrobe"]=28, ["base:fulltop"]=26,
    ["base:torso1legs1"]=30, ["base:vesttexture"]=20, ["base:torsoextravestbullet"]=180,
    ["base:shortpants"]=18, ["base:shortsshort"]=14, ["base:pants_skinny"]=26,
    ["base:longskirt"]=30, ["base:longdress"]=46, ["base:pantsextra"]=12,
    ["base:calf_left"]=6, ["base:calf_right"]=6, ["base:thigh_left"]=6,
    ["base:thigh_right"]=6, ["base:forearm_left"]=6, ["base:forearm_right"]=6,
    ["base:elbow_left"]=7, ["base:elbow_right"]=7, ["base:knee_left"]=8,
    ["base:knee_right"]=8, ["base:gaiter_left"]=9, ["base:gaiter_right"]=9,
    ["base:leftarm"]=12, ["base:rightarm"]=12,
    ["base:shoulderpadleft"]=10, ["base:shoulderpadright"]=10,
    ["base:sportshoulderpad"]=22, ["base:sportshoulderpadontop"]=22,
    ["base:jackethat"]=56, ["base:jackethat_bulky"]=82, ["base:maskfull"]=20,
    ["base:eartop"]=6, ["base:lefteye"]=14, ["base:righteye"]=14,
    ["base:gorget"]=60, ["base:cuirass"]=140, ["base:scba"]=320, ["base:scbanotank"]=190,
    ["base:necklace"]=4, ["base:necklace_long"]=5, ["base:bellybutton"]=3,
    ["base:left_middlefinger"]=3, ["base:right_middlefinger"]=3,
    ["base:left_ringfinger"]=3, ["base:right_ringfinger"]=3,
    ["base:leftwrist"]=4, ["base:rightwrist"]=4,
    ["base:ammostrap"]=26, ["base:webbing"]=30, ["base:shoulderholster"]=42,
    ["base:ankleholster"]=34, ["base:fannypackfront"]=12, ["base:fannypackback"]=12,
    ["base:satchel"]=22, ["base:underwearextra1"]=6, ["base:underwearextra2"]=6,
    ["base:codpiece"]=8,
}

-- ---------------------------------------------------------------------------
-- The rules, in the same order as tools/rules.ps1
-- ---------------------------------------------------------------------------

local function ruleFood(item, fullType, weight)
    if not instanceof(item, "Food") then return nil end

    local base = 2.0
    if     nameHas(fullType, "Whiskey") or nameHas(fullType, "Bourbon")
        or nameHas(fullType, "Vodka") or nameHas(fullType, "Wine")   then base = 11.0
    elseif nameHas(fullType, "Beer") or nameHas(fullType, "Cider")   then base = 4.0
    elseif nameHas(fullType, "Steak") or nameHas(fullType, "Beef")
        or nameHas(fullType, "Pork") or nameHas(fullType, "Bacon")   then base = 6.5
    elseif nameHas(fullType, "Chicken") or nameHas(fullType, "Fish") then base = 5.0
    elseif nameHas(fullType, "Cheese") or nameHas(fullType, "Milk")
        or nameHas(fullType, "Egg")                                  then base = 2.6
    elseif nameHas(fullType, "Canned") or nameHas(fullType, "Tinned") then base = 1.2
    elseif nameHas(fullType, "Candy") or nameHas(fullType, "Chocolate")
        or nameHas(fullType, "Chips") or nameHas(fullType, "Cookie") then base = 1.2
    elseif nameHas(fullType, "Bread") or nameHas(fullType, "Cereal")
        or nameHas(fullType, "Rice") or nameHas(fullType, "Pasta")   then base = 1.6
    elseif nameHas(fullType, "Coffee") or nameHas(fullType, "Tea")   then base = 3.0
    elseif nameHas(fullType, "Pop") or nameHas(fullType, "Soda")
        or nameHas(fullType, "Juice")                                then base = 1.0
    elseif nameHas(fullType, "Water")                                then base = 0.6
    end

    local cal = num(item, "getCalories", 150)
    local portion = clamp(cal / 250.0, 0.35, 2.2)
    return round(base * (0.55 + 0.45 * portion))
end

local function ruleClothing(item, fullType, weight)
    if not instanceof(item, "Clothing") then return nil end

    local loc = str(item, "getBodyLocation")
    local base = loc and GARMENT[loc] or nil
    if not base then
        -- A modded body location we have never heard of. Priced as a plain garment
        -- rather than dropped, because falling through would put it back on weight.
        base = 18
    end
    base = base + 0.0

    if     nameHas(fullType, "Leather") then base = base * 3.0
    elseif nameHas(fullType, "Fur")     then base = base * 2.6
    elseif nameHas(fullType, "Denim") or nameHas(fullType, "Jean") then base = base * 1.3
    elseif nameHas(fullType, "Suit")    then base = base * 1.8
    elseif nameHas(fullType, "Camo") or nameHas(fullType, "Military")
        or nameHas(fullType, "Army")    then base = base * 1.5
    end

    local bullet  = num(item, "getBulletDefense", 0)
    local bite    = num(item, "getBiteDefense", 0)
    local scratch = num(item, "getScratchDefense", 0)
    if bullet > 0 then base = base + bullet * 2.2 end
    if bite > 40 then base = base + (bite - 40) * 0.6
    elseif scratch > 50 then base = base + (scratch - 50) * 0.25 end

    local ins = clamp(num(item, "getInsulation", 0), 0, 1)
    if ins > 0.5 then base = base * (1.0 + (ins - 0.5) * 0.5) end

    return round(base * weightNudge(weight, 1.0, 0.1))
end

local function ruleLiterature(item, fullType, weight)
    if not instanceof(item, "Literature") then return nil end

    if str(item, "getSkillTrained") then
        local lvl = tonumber(string.match(fullType, "([1-5])$")) or 1
        return round(22 + (lvl - 1) * 12)
    end
    local ok, recipes = pcall(function() return item:getLearnedRecipes() end)
    if ok and recipes and recipes:size() > 0 then return 26 end

    if nameHas(fullType, "Newspaper") or nameHas(fullType, "Note") then return 1 end
    if nameHas(fullType, "Magazine") or nameHas(fullType, "Comic") then return 3 end
    if nameHas(fullType, "Book") or nameHas(fullType, "Manual")    then return 6 end
    return 4
end

local function ruleContainer(item, fullType, weight)
    if not instanceof(item, "InventoryContainer") then return nil end

    local cap = num(item, "getCapacity", 0)
    if cap <= 0 then return nil end

    local price = 6 + cap * 2.6
    local wr = num(item, "getWeightReduction", 0)
    if wr > 0 then price = price * (1.0 + wr / 100.0) end

    if     nameHas(fullType, "Leather")  then price = price * 2.2
    elseif nameHas(fullType, "Military") or nameHas(fullType, "ALICE")
        or nameHas(fullType, "Camo")     then price = price * 1.8
    elseif nameHas(fullType, "Crude") or nameHas(fullType, "Tarp")
        or nameHas(fullType, "Sheet")    then price = price * 0.35
    end
    return round(price)
end

local function ruleWeapon(item, fullType, weight, category)
    if not instanceof(item, "HandWeapon") then return nil end

    -- Building materials that happen to be swingable are not weapons; let them fall
    -- through to the generic rule and be priced as the materials they are.
    if category == "MaterialWeapon" or category == "JunkWeapon"
       or category == "HouseholdWeapon" then return nil end

    if nameHas(fullType, "Crude") or nameHas(fullType, "Improvised")
       or nameHas(fullType, "Makeshift") then
        return round(4 * weightNudge(weight, 1.5, 0.5))
    end

    local base = 10.0
    if     category == "ToolWeapon"       then base = 16.0
    elseif category == "SportsWeapon"     then base = 14.0
    elseif category == "InstrumentWeapon" then base = 45.0
    elseif category == "GardeningWeapon"  then base = 12.0
    elseif category == "BrokenWeapon"     then return 1
    end

    -- getMaxDamage is absent from vanilla's own Lua, so condition carries the sorting
    -- inside the class on its own when damage cannot be read.
    local cond = num(item, "getConditionMax", 10)
    return round(base * (0.7 + 0.03 * cond) * weightNudge(weight, 1.5, 0.3))
end

local function ruleDrainable(item, fullType, weight)
    if not instanceof(item, "DrainableComboItem") then return nil end

    local base = 4.0
    if     nameHas(fullType, "Bleach") or nameHas(fullType, "Cleaner") then base = 3.0
    elseif nameHas(fullType, "Petrol") or nameHas(fullType, "Fuel")    then base = 6.0
    elseif nameHas(fullType, "Paint")                                   then base = 9.0
    elseif nameHas(fullType, "Glue") or nameHas(fullType, "Tape")      then base = 3.5
    elseif nameHas(fullType, "Propane") or nameHas(fullType, "Welding") then base = 18.0
    elseif nameHas(fullType, "Cigarette")                               then base = 2.5
    end
    return round(base * weightNudge(weight, 1.0, 0.4))
end

-- ---------------------------------------------------------------------------

--[[ Price one item the generated table has never seen.

     Returns nil when the item cannot be instantiated at all, which leaves the caller
     to fall back to the old category-and-weight formula. That is a worse price, but a
     price, and it is better than dropping a modded item out of the catalogue entirely.
]]
function TC.priceUnknownItem(scriptItem, fullType)
    local ok, item = pcall(function() return instanceItem(fullType) end)
    if not ok or not item then return nil end

    local weight   = scriptItem:getActualWeight() or 1
    local category = scriptItem:getDisplayCategory() or "Generic"

    local price = ruleFood(item, fullType, weight)
                  or ruleClothing(item, fullType, weight)
                  or ruleLiterature(item, fullType, weight)
                  or ruleContainer(item, fullType, weight)
                  or ruleWeapon(item, fullType, weight, category)
                  or ruleDrainable(item, fullType, weight)

    return price
end
