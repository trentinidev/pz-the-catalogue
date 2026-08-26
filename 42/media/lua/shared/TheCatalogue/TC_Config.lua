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
    PriceMultiplier         = 1.0,
    SellRatio               = 0.9,
    MaxQuantityPerPurchase  = 100,
    SellContainerContents   = true,
    MinConditionToSell      = 0.0,
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
