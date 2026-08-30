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

--[[ The bank card is VANILLA's card. See TC.issueCard in TC_Bank.lua for why the mod
     ships no plastic of its own: Base.CreditCard already has the icon, the world model
     and base:fitswallet, and a card of ours would only look like a worse copy of it
     sitting next to one on the floor of a bank. Ours is the same item with modData and a
     name on it. ]]
TC.CARD_ITEM = "Base.CreditCard"

--[[ Global scale on every buy price. 1.0 since 0.11.1, and it stays here for the
     sandbox multiplier to compose with rather than because it still corrects anything.

     It was 1.75 while TC_PriceTable held BASE prices that a formula had worked out and
     that were, as a body, too generous. The table is imported from the vanilla price
     study now (tools/import_prices.sh) and the study's figures are already in dollars,
     so there is nothing left to scale: what is written in the table is what the player
     is shown. ]]
TC.PRICE_SCALE = 1.0

--[[ ...except for the two layers that are still a formula.

     Items from other mods have never been in the study and never will be. They are
     priced by TC_ModPricing, which encodes the old judgements at the old base scale, so
     dropping PRICE_SCALE to 1.0 would leave every modded item cheap against a vanilla
     table that did not move with it.

     0.75 is measured, not chosen: across the 4,905 ids both sets price, the study's
     median figure is 0.43x what this mod used to SHOW, and it used to show base x 1.75.
     0.43 x 1.75 is 0.75, so this is the factor that puts a formula price on the study's
     footing. It corrects the level, not the shape -- the formula still cannot tell a
     rifle from a poker, which is the whole reason vanilla stopped using it. ]]
TC.MOD_PRICE_SCALE = 0.75

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

    -- The banking half. See sandbox-options.txt for what each one turns off.
    BankingEnabled             = true,
    ForeignCards               = true,
    ForeignBalanceMultiplier   = 1.0,
    PinTries                   = 3,
    PinLockoutHours            = 24,
}

function TC.opt(name)
    local vars = SandboxVars and SandboxVars.TheCatalogue
    if vars ~= nil and vars[name] ~= nil then
        return vars[name]
    end
    return DEFAULTS[name]
end

--[[ Categories the catalogue refuses to trade at all.

     Five, and deliberately only five: states the engine paints on a body or hides from
     the player. Everything else is decided per id by the study, through
     TC_ExcludedItems.lua.

     THIS LIST USED TO BE FOUR TIMES LONGER, and it was wrong. It also held Ears, Eye,
     Tail and thirteen animal names -- Bear, Beaver, Dog, Duck, Fox, Squirrel and the
     rest -- on the reading that those were "live-animal categories that exist to carry
     an animal's data rather than to be an object you own". They are not. They are the
     categories vanilla files its PLUSH TOYS and costume pieces under. Twenty-seven real,
     physical, sellable objects were being withheld from the catalogue on the strength of
     a category name: Spiffo and Spiffo Big, Freddy Fox, Pancho Dog, Moley Mole, Jacques
     Beaver, a rubber duck, a rubber spider, bunny-ear hats, a rabbit's-foot keyring, a
     dog leash and a pet water dish.

     The lesson is the general one: a category name is a guess about what is inside it.
     Per-id status is not. Add to this list only for a category whose members are engine
     internals to a one, and check the members before believing the name.
]]
TC.EXCLUDED_CATEGORIES = {
    Hidden = true, Corpse = true, MaleBody = true, Wound = true, ZedDmg = true,
}

--[[ Individual items kept out of the catalogue.

     This is the HAND-WRITTEN half. The other 194 -- vanilla's debug fixtures, corpses,
     wound and bandage overlays, hair stubble -- are generated into TC_ExcludedItems.lua
     from the study and merged into this same table at load. That file loads after this
     one (shared lua loads alphabetically, and Config sorts before ExcludedItems), which
     matters because this line ASSIGNS the table rather than adding to it.

     Money and MoneyBundle are the important ones here and are in the study's list too;
     kept written out because the reason is ours: a currency that can be bought and sold
     at any spread other than exactly 1.0 is an arbitrage loop, and at exactly 1.0 it is
     a pointless entry. BareHands is not an object at all -- it is the weapon the game
     equips when you are holding nothing.
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

    --[[ The card reader is NOT for sale, and this is the most important line in the table.

         Nothing else here is excluded to protect a mechanic; the parcels are excluded
         because they are boxes. The reader is gated behind Electricity 3 and a handful of
         scrap ON PURPOSE -- it is the one route into a stranger's account that works the
         same on every card, and the skill is what pays for it. A mail-order company that
         would post you one for a few hundred dollars is that gate deleted: no skill, no
         materials, just money, which is the thing the player already has plenty of by the
         time this matters.

         It stays out of the SELL side too, which is what excluding it does, and that is
         right as well -- a reader bought back at a fraction of nothing is not a trade
         anybody needs. ]]
    ["Catalogue.CardSkimmer"] = true,

    --[[ The disc and what is burned onto it, for the same reason as the reader.

         A blank disc is found, not bought: it is the one scarce thing standing between a
         player and an online catalogue, and a shop that sells discs is that scarcity
         deleted. The burned disc is worse still -- ordering an online catalogue FROM the
         catalogue is a snake eating itself, and it would skip the account requirement that
         is the whole point of the feature. ]]
    ["Catalogue.BlankCD"]         = true,
    ["Catalogue.OnlineCatalogue"] = true,
    ["Catalogue.BankingCD"]       = true,
    ["Catalogue.DepositCassette"] = true,
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


--[[ The cash machines.

     Vanilla has exactly four ATM sprites and they are all in location_business_bank_01:
     64 and 65 are the free-standing green machine seen from its two drawn angles, 66 and
     67 the wall-mounted one. They carry NO CustomName and no GroupName -- the bank
     tileset labels its counters and its safe-deposit walls and leaves these two anonymous
     -- so there is nothing to match on but the sprite name itself.

     WORKED OUT BY LOOKING. The tile properties are no help and the obvious candidates in
     the same tileset are a trap: 40 to 45 are named "Vault", in a Wall group of two and a
     Standing group of four, which is the exact shape an ATM set would have. They are
     banks of safe-deposit boxes. The four below were confirmed by pulling the tileset out
     of Tiles1x.pack and looking at the pictures, and the two with "ATM" printed on the
     front are 64 and 65.

     A sprite name is the only handle the engine offers here, so it is a literal list, and
     a literal list goes stale if the tileset is ever renumbered. That is the trade, and
     it is a cheap one to fix -- but it is why TC.isATMSprite also takes a guess at what
     ANOTHER mod would call its machine. A tile called atm_01_3 or mall_atm_2 is almost
     certainly one, and matching it costs nothing; the delimiter is required so that a
     sprite with "atm" buried in a longer word is not swept up with them. ]]
TC.ATM_SPRITES = {
    ["location_business_bank_01_64"] = true,   -- free-standing, one facing
    ["location_business_bank_01_65"] = true,   -- free-standing, the other
    ["location_business_bank_01_66"] = true,   -- wall-mounted, one facing
    ["location_business_bank_01_67"] = true,   -- wall-mounted, the other
}

function TC.isATMSprite(name)
    if type(name) ~= "string" or name == "" then return false end
    if TC.ATM_SPRITES[name] then return true end

    local lower = string.lower(name)
    if string.find(lower, "^atm[_%d]") then return true end
    if string.find(lower, "_atm[_%d]") then return true end
    if string.find(lower, "cashmachine", 1, true) then return true end
    return false
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
TC.VERSION = "0.11.2-beta"
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
