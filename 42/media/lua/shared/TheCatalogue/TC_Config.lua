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

-- Vanilla UnbundleMoney turns one bundle into exactly this many loose notes.
-- Read straight off media/scripts/generated/recipes/recipes_packing.txt; if the
-- devs ever change that recipe this constant has to follow it.
TC.NOTES_PER_BUNDLE = 100

-- Sandbox defaults, used whenever SandboxVars has no value for us. That happens
-- more often than you would think: an existing save made before the mod was added
-- keeps its old SandboxVars table until the settings are re-saved.
local DEFAULTS = {
    PriceMultiplier            = 1.0,
    SellRatio                  = 0.9,
    MaxQuantityPerPurchase     = 100,
    SellContainerContents      = true,
    MinConditionToSell         = 0.0,
    RequireCatalogueOnPerson   = true,
    CatalogueLootMultiplier    = 1.0,
    OrderSeconds               = 2.0,
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
}

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
