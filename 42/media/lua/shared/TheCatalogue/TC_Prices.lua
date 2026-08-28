--[[ The Catalogue -- the price engine.

     Two layers. TC_Overrides.lua pins the items whose price carries balance weight;
     everything else lands on the formula below, which reads only what a ScriptItem
     will reliably give us: its display category and its weight.

     WHY NOT INSTANTIATE EVERY ITEM. instanceItem() would hand us the full
     InventoryItem API -- damage, nutrition, capacity -- and a far smarter formula.
     It would also mean constructing ~5,000 Java objects during the loading screen to
     read four fields off each and throw them away. The category table below buys most
     of that accuracy for none of that cost, and the overrides cover the rest.

     The index is built lazily on first use, not at file load: getAllItems() is not
     safe to call while scripts are still being parsed.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Base price per display category, before the weight curve.

     Read these as "what a typical, unremarkable member of this category costs".
     Weight then spreads the category out -- see priceFromFormula.

     The categories are the game's own DisplayCategory values, all 80 of them as of
     42.20. An unlisted category falls back to DEFAULT_BASE rather than vanishing,
     so a future patch adding a category leaves those items buyable at a dull price
     rather than silently dropping them out of the catalogue.
]]
local DEFAULT_BASE = 4

local CATEGORY_BASE = {
    -- Food and drink
    Food = 1.1, Cooking = 6, Water = 1, WaterContainer = 8,

    -- Weapons. Weapon is the firearms-and-serious-blades bucket; the rest are the
    -- improvised categories, priced as the scavenged junk they are.
    Weapon = 95, ToolWeapon = 13, WeaponCrafted = 9, WeaponPart = 55,
    MaterialWeapon = 6, HouseholdWeapon = 6, JunkWeapon = 4, SportsWeapon = 12,
    GardeningWeapon = 8, CookingWeapon = 7, InstrumentWeapon = 10,
    AnimalPartWeapon = 4, FishingWeapon = 7, FirstAidWeapon = 5,
    VehicleMaintenanceWeapon = 8, WeaponImprovised = 4, BrokenWeapon = 1,
    Ammo = 9, Explosives = 70,

    -- Tools and hardware
    Tool = 14, Material = 3.5, Household = 5, Electronics = 40,
    VehicleMaintenance = 26, Security = 55, Paint = 5,

    -- Carry
    Container = 5, Bag = 30,

    -- Furniture. Cheap per kilo on purpose: the weight curve does the work, and a
    -- looted couch should not outprice a rifle.
    Furniture = 2.2, Appearance = 5, Memento = 3, Junk = 1, Teddy = 3,

    -- Paper
    Literature = 3.5, SkillBook = 40, RecipeResource = 26, Cartography = 14,
    Entertainment = 9,

    -- Medicine
    FirstAid = 10, Bandage = 1.5,

    -- Worn
    Clothing = 11, ProtectiveGear = 32, Accessory = 7,

    -- Outdoors
    Camping = 16, Fishing = 11, Trapping = 9, Gardening = 4.5,
    LightSource = 14, FireSource = 2.5, AnimalPart = 3,

    -- Signal
    Communications = 40, Instrument = 75, Sports = 13,

    -- Odds and ends
    Bug = 0.5, Generic = 2,
}

TC.CATEGORY_BASE = CATEGORY_BASE

--[[ The weight curve.

     Sub-linear on purpose. A 40 kg generator should not cost fifty times a 0.8 kg can
     of beans purely on mass, but weight is still the only handle the formula has on
     "how much stuff is this", so it has to count for something. w^0.85 splits the
     difference; the 0.55 floor keeps featherweight items from rounding to nothing.
]]
local function weightFactor(w)
    if type(w) ~= "number" or w <= 0 then return 0.55 end
    return 0.55 + 0.45 * (w ^ 0.85)
end

local function roundPrice(p)
    if p < 1 then return 1 end
    return math.floor(p + 0.5)
end

--[[ Formula price for one ScriptItem. Returns nil for anything the catalogue
     refuses to trade, which is how excluded items stay out of the index.

     Material value is ADDED to the formula result rather than replacing it, so a gold
     necklace is worth its gold plus the small amount the piece itself is worth, and a
     gold-set diamond is worth both stones' worth of markup. Without this the weight
     curve prices every piece of jewellery in the game at about four dollars, since
     weight is the only magnitude the formula can see. ]]
local function priceFromFormula(scriptItem, fullType)
    local cat = scriptItem:getDisplayCategory()
    if cat and TC.EXCLUDED_CATEGORIES[cat] then return nil end

    -- A base registered through the API wins, so a mod can name a sensible price for a
    -- DisplayCategory this table has never heard of.
    local base = (cat and TC.REGISTERED_BASES and TC.REGISTERED_BASES[cat])
                 or (cat and CATEGORY_BASE[cat])
                 or DEFAULT_BASE

    local ok, w = pcall(function() return scriptItem:getActualWeight() end)
    if not ok then w = 1 end

    local price = base * weightFactor(w)

    local material = TC.MATERIAL_VALUES and TC.MATERIAL_VALUES[fullType]
    if material then price = price + material end

    return roundPrice(price)
end

-- ---------------------------------------------------------------------------
-- The index
-- ---------------------------------------------------------------------------

TC.entries     = nil   -- array, sorted by display name, for the buy list
TC.priceByType = nil   -- fullType -> base price, for O(1) lookup when selling

--[[ Walk every item the game knows about and price it once.

     getObsolete() and isHidden() are the game's own "this is not a real item" flags.
     They cost nothing to honour and they are the only filter that will keep working
     when the devs retire an item in a future patch.
]]
function TC.buildIndex()
    if TC.entries then return end

    local started = getTimestampMs()

    TC.entries     = {}
    TC.priceByType = {}

    local all = getAllItems()
    if not all then
        TC.warn("getAllItems() returned nil -- index left empty")
        return
    end

    local overrides = TC.PRICE_OVERRIDES or {}
    local skipped = 0
    local n = 0

    for i = 0, all:size() - 1 do
        local si = all:get(i)
        -- getFullName is called directly rather than through pcall. The old form
        -- allocated a fresh closure on every one of eleven thousand iterations purely
        -- to guard a getter that does not throw.
        local fullType = si:getFullName()

        --[[ Category exclusions belong HERE, not inside the formula.

             They used to be checked only by priceFromFormula, which is the last layer
             of four -- so anything the generated table or the modded-item pricer
             answered first slipped straight past them. That is how "Animal Corpse"
             ended up on the shelf: excluded from the generated table by the offline
             generator, then priced anyway by the runtime pricer, which never asked.

             One gate, before any pricing is attempted, so every layer obeys it. ]]
        local category = si:getDisplayCategory()

        if fullType and not TC.EXCLUDED_ITEMS[fullType]
           and not (category and TC.EXCLUDED_CATEGORIES[category])
           and not si:getObsolete() and not si:isHidden() then

            --[[ Four layers, most specific first.

                 TC_Overrides    hand-set, 171 items whose price carries balance weight
                 TC_PriceTable   generated, every vanilla item, priced from everything
                                 the scripts declare (see tools/gen_prices.ps1)
                 priceUnknownItem  modded items: one instance is built so the same
                                 judgements can read BodyLocation, Calories, Capacity
                                 and the rest, which live on InventoryItem and are not
                                 reachable from the ScriptItem this loop walks
                 formula         category and weight -- last resort, for an item that
                                 refuses to instantiate at all
            ]]
            -- Full precedence, and why each layer sits where it does, is documented
            -- at the top of TC_API.lua.
            local price = (TC.REGISTERED_PRICES and TC.REGISTERED_PRICES[fullType])
                          or overrides[fullType]
                          or (TC.PRICE_TABLE and TC.PRICE_TABLE[fullType])
                          or (TC.runValueHandlers and TC.runValueHandlers(si, fullType))
                          or TC.priceUnknownItem(si, fullType)
                          or priceFromFormula(si, fullType)

            if price then
                TC.priceByType[fullType] = price

                local name = si:getDisplayName() or fullType
                local module = si:getModuleName() or "Base"
                n = n + 1
                TC.entries[n] = {
                    fullType = fullType,
                    name     = name,
                    lower    = string.lower(name .. " " .. fullType),
                    price    = price,
                    category = category or "Generic",
                    module   = module,
                    weight   = si:getActualWeight() or 0,
                    -- NO icon here. Resolving getNormalTexture() for every item in the
                    -- game costs eleven thousand texture lookups at load, to draw about
                    -- twenty rows. TC.entryIcon fetches it on first draw instead.
                    script   = si,
                }
            else
                skipped = skipped + 1
            end
        end
    end

    table.sort(TC.entries, function(a, b)
        if a.name == b.name then return a.fullType < b.fullType end
        return a.name < b.name
    end)

    -- Timed because this is the one unavoidable pass over every item in the game, and
    -- if the window ever feels slow to open again this number says whether the cost is
    -- here or in the window.
    TC.log("indexed %d items (%d excluded) in %d ms",
           #TC.entries, skipped, getTimestampMs() - started)
end

--[[ The inventory texture for an entry, resolved on first draw and kept.

     Only the handful of rows actually on screen ever ask, so the cost is paid for
     dozens of items instead of eleven thousand, and spread over the frames the player
     scrolls through rather than landing all at once on the loading of the window. ]]
function TC.entryIcon(e)
    if e.icon == nil then
        if e.script then
            e.icon = e.script:getNormalTexture() or false
        else
            e.icon = false        -- false, not nil, so we never retry a failed lookup
        end
    end
    if e.icon == false then return nil end
    return e.icon
end

--[[ Display price for an entry, straight off the stored base. Saves the fullType table
     lookup that getBuyPrice does, which matters when this is called per row per frame. ]]
function TC.entryPrice(e)
    return roundPrice(e.price * TC.PRICE_SCALE * TC.opt("PriceMultiplier"))
end

-- ---------------------------------------------------------------------------
-- Sorted views of the index
-- ---------------------------------------------------------------------------

local function comparatorFor(key, asc)
    return function(a, b)
        if key == "cat" then
            if a.category ~= b.category then
                if asc then return a.category < b.category end
                return a.category > b.category
            end
            return a.name < b.name
        end

        if key == "mid" then
            local aw, bw = a.weight or 0, b.weight or 0
            if aw ~= bw then
                if asc then return aw < bw end
                return aw > bw
            end
            return a.name < b.name
        end

        if key == "price" then
            -- The stored base, not getBuyPrice(). The sandbox multiplier is positive
            -- and uniform, so it cannot change the ordering, and reading it through a
            -- function for every one of a quarter-million comparisons was most of what
            -- made a price sort expensive.
            if a.price ~= b.price then
                if asc then return a.price < b.price end
                return a.price > b.price
            end
            return a.name < b.name
        end

        if a.name ~= b.name then
            if asc then return a.name < b.name end
            return a.name > b.name
        end
        return a.fullType < b.fullType
    end
end

--[[ The whole index in the requested order.

     Sorting ten thousand entries through a Lua comparator is not cheap on this
     interpreter, so each ordering is built at most once per session and kept. The
     default view -- name, ascending -- is the order buildIndex already leaves the
     index in, so opening the window sorts nothing at all.
]]
function TC.sortedEntries(key, asc)
    TC.buildIndex()

    if key == "name" and asc then return TC.entries end

    TC.sortCache = TC.sortCache or {}
    local cacheKey = key .. (asc and "+" or "-")
    local cached = TC.sortCache[cacheKey]
    if cached then return cached end

    local arr = {}
    for i = 1, #TC.entries do arr[i] = TC.entries[i] end
    table.sort(arr, comparatorFor(key, asc))

    TC.sortCache[cacheKey] = arr
    return arr
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

--[[ Buy price for one unit, with the sandbox multiplier folded in.
     Applied at query time rather than baked into the index, so an admin changing
     PriceMultiplier mid-save takes effect without a rebuild. ]]
function TC.getBuyPrice(fullType)
    TC.buildIndex()
    local base = TC.priceByType[fullType]
    if not base then return nil end
    return roundPrice(base * TC.PRICE_SCALE * TC.opt("PriceMultiplier"))
end

--[[ How intact an item is, as a fraction of 1.

     Four separate vanilla systems model "worn out" and none of them share an
     interface, so each is asked in turn and the first that answers wins:
       condition   -- weapons, clothing, tools
       usedDelta   -- drainables: bleach, fuel, a half-smoked cigarette
       age         -- perishable food, which also has a hard rotten flag
     Anything that models no wear at all is worth full price, which is correct for
     a nail or a can of beans.
]]
--[[ Asked with instanceof rather than by calling a getter inside pcall.

     The old form wrapped each of six getters in its own pcall, because getCondition
     does not exist on a can of beans and isRotten does not exist on an axe, and
     calling a missing method here throws. That meant up to six closure allocations
     per item -- fine once, ruinous when the sell window was valuing every staged item
     on every frame. Asking the item what it IS costs one call and no allocation, and
     these four class names are the same ones the game's own Lua tests against.
]]
function TC.conditionRatio(item)
    if not item then return 1 end

    if instanceof(item, "Food") then
        -- Rotten is worth essentially nothing, however fresh the condition claims.
        if item:isRotten() then return 0.02 end

        local age, offAge, offAgeMax = item:getAge(), item:getOffAge(), item:getOffAgeMax()
        if type(age) == "number" and type(offAge) == "number" and type(offAgeMax) == "number"
           and offAgeMax > offAge and offAgeMax < 1000000 then
            if age <= offAge then return 1 end
            -- Stale but not rotten: fade from full price down to a tenth.
            local decay = (age - offAge) / (offAgeMax - offAge)
            return math.max(0.1, 1 - decay * 0.9)
        end
        return 1
    end

    --[[ B42 fluids are their own system, not drainables.

         A water bottle, a petrol can and a bleach bottle hold a FluidContainer, and
         they are not DrainableComboItems, so the drainable branch never saw them and a
         half-empty bottle sold for the price of a full one. getFilledRatio is what the
         game's own fluid UI reads.

         An empty vessel is still worth something -- the bottle itself is the thing you
         are buying half the time -- so the ratio floors at a quarter rather than at
         nothing. ]]
    local okFluid, fc = pcall(function() return item:getFluidContainer() end)
    if okFluid and fc then
        local okRatio, ratio = pcall(function() return fc:getFilledRatio() end)
        if okRatio and type(ratio) == "number" then
            return 0.25 + 0.75 * math.max(0, math.min(1, ratio))
        end
        return 1
    end

    if instanceof(item, "DrainableComboItem") then
        local used = item:getUsedDelta()
        if type(used) == "number" and used >= 0 and used <= 1 then return used end
        return 1
    end

    if instanceof(item, "HandWeapon") or instanceof(item, "Clothing") then
        local cond, condMax = item:getCondition(), item:getConditionMax()
        if type(cond) == "number" and type(condMax) == "number" and condMax > 0 then
            return math.max(0, math.min(1, cond / condMax))
        end
    end

    return 1
end

--[[ Market value of one item and everything inside it, BEFORE the sell spread.

     Kept separate from getSellValue for one reason: the spread must be applied
     exactly once, to the finished total. Folding it in here and then summing would
     charge it again for every level of nesting, so a book in a bag would be paid at
     ratio squared.

     Nesting is bounded by a visited set rather than a depth limit -- see MAX_NODES.
]]
--[[ Guard against a container graph that loops or is absurdly deep.

     The old code capped nesting at three levels, which was fine for vanilla and wrong
     in principle: a mod can nest deeper, and anything past the cap was removed with
     the container WITHOUT being priced -- silent loss, the same failure as selling a
     bag with money in it.

     A visited set is the correct guard. It cannot lose anything to a depth limit, it
     stops a genuine cycle dead, and the counter is only a backstop against a graph
     pathological enough that something else has already gone wrong. ]]
local MAX_NODES = 4096

local function rawValue(item, visited)
    visited = visited or { n = 0 }

    if visited[item] then return nil, "cycle" end
    visited[item] = true
    visited.n = visited.n + 1
    if visited.n > MAX_NODES then
        TC.warn("container graph exceeded %d nodes; valuation stopped at %s",
                MAX_NODES, tostring(item:getFullType()))
        return nil, "toobig"
    end

    local fullType = item:getFullType()
    if TC.EXCLUDED_ITEMS[fullType] then return nil, "excluded" end

    local unit = TC.getBuyPrice(fullType)
    if not unit then return nil, "notlisted" end

    local ratio = TC.conditionRatio(item)
    local minCond = TC.opt("MinConditionToSell")
    if minCond > 0 and ratio < minCond then return nil, "condition" end

    local value = unit * ratio

    -- Contents, when the sandbox allows it. A rifle case full of rifles is worth
    -- the case plus the rifles; this is what makes "sell everything" workable.
    if TC.opt("SellContainerContents") then
        local inv = TC.contentsOf(item)
        if inv then
            local items = inv:getItems()
            for i = 0, items:size() - 1 do
                local subValue = rawValue(items:get(i), visited)
                if subValue then value = value + subValue end
            end
        end
    end

    return value
end

--[[ What the catalogue actually pays for one InventoryItem.

     Returns value, reason. A nil value means it will not be bought, and reason names
     the rule that refused it so the UI can say something useful.
]]
function TC.getSellValue(item)
    if not item then return nil, "invalid" end
    local value, reason = rawValue(item)
    if not value then return nil, reason end
    return value * TC.opt("SellRatio")
end

--[[ Same as getSellValue but rounded to whole dollars.

     FOR DISPLAY ONLY. Never sum these: rounding each line and then adding them up
     destroys the spread on cheap items. Ten $1 items at a 0.9 sell ratio are worth
     $9.00, but each line rounds to $1 and the sum comes to $10 -- the player is paid
     more than the items are worth, and the configured 10% spread silently vanishes on
     exactly the bulk junk sales where it matters most.

     Sum getSellValue instead and round the total once. TC.sumSellValues does that. ]]
function TC.getSellPriceRounded(item)
    local v, reason = TC.getSellValue(item)
    if not v then return nil, reason end
    return math.max(0, math.floor(v + 0.5))
end

--[[ Total payout for a list of items: full precision throughout, rounded once.
     Returns the whole-dollar total and the count of items that were actually worth
     something. ]]
function TC.sumSellValues(items)
    local sum, n = 0, 0
    for _, item in ipairs(items) do
        local v = TC.getSellValue(item)
        if v then sum = sum + v; n = n + 1 end
    end
    return math.max(0, math.floor(sum + 0.5)), n
end

-- ---------------------------------------------------------------------------
-- Protecting what a sale must never destroy
-- ---------------------------------------------------------------------------

--[[ Would selling this item pay for it?

     A nil from rawValue means the catalogue will not pay: currency, an unlisted item,
     something too broken to accept. Selling the BAG such a thing sits in used to
     destroy it anyway, because removing the container removes everything inside it.
     Money was the worst case -- a backpack with $500 in it paid nothing for the notes
     and deleted them.
]]
local function isPaidFor(item)
    return (rawValue(item)) ~= nil
end

--[[ Pull everything a sale must not destroy out of a container and hand it back.

     Walks the whole tree under `item` and moves anything that will not be paid for --
     currency, favourites, the catalogue itself, unlisted or refused items -- into the
     player's inventory before the container is removed. Returns the list of what was
     rescued so the UI can say so.

     Favourites are rescued even though they would be paid for: a favourite is the
     player's own explicit "do not touch this", and honouring it only at the top level
     while quietly selling it out of a bag would be worse than not honouring it at all.
]]
function TC.rescueProtected(item, player, out, guard)
    out = out or {}
    guard = (guard or 0) + 1
    if guard > 16 then return out end          -- pathological nesting or a cycle

    local inv = TC.contentsOf(item)
    if not inv then return out end

    local playerInv = player:getInventory()
    local contents = inv:getItems()

    -- Collected first, moved second: mutating a container while iterating its own
    -- item list is how you skip half the contents.
    local doomed = {}
    for i = 0, contents:size() - 1 do
        table.insert(doomed, contents:get(i))
    end

    for _, sub in ipairs(doomed) do
        TC.rescueProtected(sub, player, out, guard)

        local favourite = false
        local okFav, fav = pcall(function() return sub:isFavorite() end)
        if okFav then favourite = fav end

        -- Wishlisted items are protected exactly like favourites. Strictly the
        -- wishlist is a SHOPPING list, so protecting what you already own from being
        -- sold is a stretch of its meaning -- but a player who put a star on something
        -- reads that star as "I care about this", and a sale that ignores it is a
        -- nasty surprise. Two ways to mark something, one behaviour.
        local wished = TC.isWished(player, sub:getFullType())

        if favourite or wished or sub:getFullType() == TC.ITEM_FULL or not isPaidFor(sub) then
            local c = sub:getContainer()
            if c then c:Remove(sub) end
            playerInv:AddItem(sub)
            table.insert(out, sub)
        end
    end

    return out
end
