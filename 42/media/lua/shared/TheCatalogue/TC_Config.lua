--[[ The Catalogue -- configuration and sandbox access.

     Everything tunable lives here or in sandbox-options.txt. Nothing in this file
     touches the world, so it is safe to load on both client and server.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC.MOD_ID       = "TheCatalogue"
TC.ITEM_FULL    = "Catalogue.Catalogue"
TC.MONEY        = "Base.Money"
TC.MONEY_BUNDLE = "Base.MoneyBundle"

--[[ Global scale on every buy price.

     The catalogue was too generous: buying was cheap enough that a modest pile of
     looted cash bought most of what mattered, and selling at 90% meant loot converted
     to money almost losslessly. 1.75 on the way in and a much harder spread on the way
     out (see SellRatio) is the correction.

     Applied HERE, in one place, rather than baked into TC_PriceTable.lua, because this
     is the only spot that reaches all four pricing layers at once -- hand-set
     overrides, the generated table, modded items and the fallback formula. Baking it
     into the generated table would have needed a matching copy inside TC_ModPricing to
     keep modded items in step, which is exactly the kind of duplication that drifts.

     Note this means the numbers in TC_PriceTable.lua are BASE prices: what the game
     shows is that figure times this scale times the sandbox PriceMultiplier. ]]
TC.PRICE_SCALE = 1.75

-- Vanilla UnbundleMoney turns one bundle into exactly this many loose notes.
-- Read straight off media/scripts/generated/recipes/recipes_packing.txt; if the
-- devs ever change that recipe this constant has to follow it.
TC.NOTES_PER_BUNDLE = 100

-- Sandbox defaults, used whenever SandboxVars has no value for us. That happens
-- more often than you would think: an existing save made before the mod was added
-- keeps its old SandboxVars table until the settings are re-saved.
local DEFAULTS = {
    PriceMultiplier            = 1.0,
    SellRatio                  = 0.30,
    MaxQuantityPerPurchase     = 100,
    SellContainerContents      = true,
    MinConditionToSell         = 0.0,
    RequireCatalogueOnPerson   = true,
    CatalogueLootMultiplier    = 1.0,
    OrderSeconds               = 2.0,
    DebugLogging               = false,
    DeliveryHoursMultiplier    = 1.0,
    RushFeePercent             = 20,
}

function TC.opt(name)
    local vars = SandboxVars and SandboxVars.TheCatalogue
    if vars ~= nil and vars[name] ~= nil then
        return vars[name]
    end
    return DEFAULTS[name]
end

--[[ Categories the catalogue refuses to trade at all.

     These are not "worthless" items, they are items that should never appear in a
     shop list: corpses and severed body parts, the wound-modelling items the health
     system spawns, the invisible Hidden bucket, and the live-animal categories that
     exist to carry an animal's data rather than to be an object you own.

     Priced items you merely think are junk still belong in the catalogue -- that is
     what a low price is for. Only add here what would be absurd or exploitable to list.
]]
TC.EXCLUDED_CATEGORIES = {
    Hidden = true, Corpse = true, MaleBody = true, Ears = true, Eye = true,
    Tail = true, Wound = true, ZedDmg = true,
    Animal = true, Bear = true, Beaver = true, Badger = true, Bunny = true,
    Dog = true, Duck = true, Fox = true, Frog = true, Goblin = true,
    Hedgehog = true, Mole = true, Raccoon = true, Spider = true, Squirrel = true,
}

--[[ Individual items kept out of the catalogue.

     Money and MoneyBundle are the important ones: a currency that can be bought and
     sold at any spread other than exactly 1.0 is an arbitrage loop, and at exactly
     1.0 it is a pointless entry. BareHands is not an object at all -- it is the
     weapon the game equips when you are holding nothing.
]]
TC.EXCLUDED_ITEMS = {
    ["Base.Money"]       = true,
    ["Base.MoneyBundle"] = true,
    ["Base.BareHands"]   = true,

    -- Our oversized parcels are packaging, not merchandise. Listing them would put a
    -- 100-capacity container on the shelf for pocket change, which is a far better
    -- deal than anything else in the catalogue.
    ["Catalogue.Parcel_XXL"]  = true,
    ["Catalogue.Parcel_5XL"]  = true,
    ["Catalogue.Parcel_10XL"] = true,
}

--[[ Delivery packaging.

     A parcel that arrives with an order is a box, not goods. Left valued as merchandise
     it paid for itself: a $2 round turned up inside a parcel the catalogue would buy
     back for $4, so the cheapest thing on the shelf showed a profit the moment it
     landed and the loop had no bottom.

     Two ways to be packaging. The oversized parcels exist only as delivery crates, so
     they are packaging by type. A vanilla parcel is ordinary loot that a delivery merely
     borrowed, so it gets stamped on the way out instead -- a box found in a post office
     still sells for what it is worth, and only the one the catalogue handed over is
     worthless.

     Worthless is not the same as unsellable. A packaging parcel is still a carrier, so
     staging one sells everything inside it and the box goes with the sale; otherwise
     "sell this parcel" would quietly mean "unpack it first".
]]
TC.PACKAGING_TYPES = {
    ["Catalogue.Parcel_XXL"]  = true,
    ["Catalogue.Parcel_5XL"]  = true,
    ["Catalogue.Parcel_10XL"] = true,
}

function TC.markPackaging(item)
    if not item then return end
    local md = item:getModData()
    if md then md.TC_packaging = true end
end

function TC.isPackaging(item)
    if not item then return false end
    if TC.PACKAGING_TYPES[item:getFullType()] then return true end
    local md = item:getModData()
    return (md and md.TC_packaging) == true
end


--[[ Which build is actually running, printed into console.txt at load.

     Written after a round of testing was spent on a build that had already been replaced
     on disk: the game was launched four minutes before the files changed, and Project
     Zomboid reads models once at boot. Nothing in the log said which version was in
     memory, so three of us -- the log, the screenshots and me -- were describing
     different builds.

     A plain print rather than TC.log, because TC.log is gated behind the DebugLogging
     sandbox option and this line has to be there whether or not anyone turned it on.
     tools/check.sh verifies the string against mod.info, so it cannot drift. ]]
TC.VERSION = "0.10.2-alpha"
print("[The Catalogue] " .. TC.VERSION .. " loaded")
-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------

--[[ Two levels, and the split matters more than it looks.

     TC.warn is for things that went wrong and that a player might have to act on or
     report: an item that could not be supplied, money refunded because a delivery came
     up short, a mod misusing the API, a container graph deep enough to be a bug. These
     always print. Someone filing a bug report needs them.

     TC.log is diagnostics -- how long the index took, how many loot containers were
     touched. Useful while building the mod, noise in a stranger's console. Off unless
     DebugLogging is switched on in the sandbox.

     Before this existed everything printed unconditionally, which meant every player
     who installed the mod got timing output they had no use for. ]]
function TC.warn(fmt, ...)
    if select("#", ...) > 0 then
        print("[TheCatalogue] " .. string.format(fmt, ...))
    else
        print("[TheCatalogue] " .. tostring(fmt))
    end
end

function TC.log(fmt, ...)
    if not TC.opt("DebugLogging") then return end
    TC.warn(fmt, ...)
end

--[[ The container inside an item, or nil if it is not a container.

     ASK WHAT IT IS, NEVER pcall THE GETTER. getInventory() exists on
     InventoryContainer and on nothing else, so calling it on a can of beans throws.
     Wrapping that in pcall does catch it -- but the game still writes the failure to
     the log, so a single pass over an eleven-item inventory produced eleven logged
     errors and the mod looked broken while behaving correctly.

     One helper so this can never be got wrong in one place and right in another; there
     were six copies of the pcall version before this existed. ]]
function TC.contentsOf(item)
    if not item then return nil end
    if not instanceof(item, "InventoryContainer") then return nil end
    return item:getInventory()
end

--[[ Take an item out of the world for good.

     `container:Remove(item)` is enough for anything held in an inventory, and it was
     all the sale did. On the GROUND that removes the item from the floor container the
     inventory page is showing and leaves the IsoWorldInventoryObject standing on the
     square: the catalogue paid for the item, and the item was still lying there to be
     picked up and sold again. Free money, one drag at a time.

     The sequence below is vanilla's own, lifted from ISTransferAction's floor branch --
     drop the animal designation, tell the square (and any clients) the object is gone,
     take it out of the square's object list, then cut the item's link back to it. Doing
     only some of those leaves a ghost: an object with no item, or an item that still
     believes it is on the floor.
]]
function TC.removeItem(item)
    if not item then return false end

    local world = item:getWorldItem()
    if world then
        local square = world:getSquare()
        if square then
            if DesignationZoneAnimal and DesignationZoneAnimal.removeItemFromGround then
                DesignationZoneAnimal.removeItemFromGround(world)
            end
            square:transmitRemoveItemFromSquare(world)
            square:removeWorldObject(world)
        end
        item:setWorldItem(nil)
    end

    local container = item:getContainer()
    if container then container:Remove(item) end

    return true
end

-- ---------------------------------------------------------------------------
-- Wishlist
-- ---------------------------------------------------------------------------

--[[ Stored on the player's own modData, which is where vanilla keeps its crafting
     favourites and which persists per character across saves. Keyed by fullType, so it
     survives a reindex and does not care what order the catalogue was built in. ]]
local WISHLIST_KEY = "TheCatalogue_Wishlist"

function TC.wishlist(player)
    if not player then return {} end
    local md = player:getModData()
    if type(md[WISHLIST_KEY]) ~= "table" then md[WISHLIST_KEY] = {} end
    return md[WISHLIST_KEY]
end

function TC.isWished(player, fullType)
    return TC.wishlist(player)[fullType] == true
end

function TC.toggleWish(player, fullType)
    local list = TC.wishlist(player)
    if list[fullType] then
        list[fullType] = nil
        return false
    end
    list[fullType] = true
    return true
end

--[[ Every fullType the player is carrying, gathered in one walk of their inventory.

     Built once per list refresh and then read per row. Asking getItemCountRecurse for
     each of ten thousand catalogue rows would be ten thousand recursive inventory
     walks; walking the inventory once and asking a set is the same answer for a
     fraction of the work. ]]
function TC.ownedTypes(player, out, container, guard)
    out = out or {}
    guard = (guard or 0) + 1
    if guard > 16 then return out end

    container = container or (player and player:getInventory())
    if not container then return out end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        out[it:getFullType()] = (out[it:getFullType()] or 0) + 1
        local inv = TC.contentsOf(it)
        if inv then TC.ownedTypes(player, out, inv, guard) end
    end
    return out
end

--[[ Does the player still have a catalogue on them?

     Checked recursively, so one in a backpack counts. The window is opened from a
     specific catalogue item, but holding a reference to THAT one would close the
     window when a player consolidates two catalogues or moves one between bags, which
     is worse than useless. What matters is that some catalogue is on the person. ]]
function TC.hasCatalogue(player)
    if not player then return false end
    if not TC.opt("RequireCatalogueOnPerson") then return true end

    local ok, n = pcall(function()
        return player:getInventory():getItemCountRecurse(TC.ITEM_FULL)
    end)
    return ok and type(n) == "number" and n > 0
end
