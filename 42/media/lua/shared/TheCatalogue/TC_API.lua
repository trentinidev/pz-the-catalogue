--[[ The Catalogue -- the public API other mods use to price their own items.

     A formula can guess what a modded item is worth from its category, its weight and
     the properties it declares. It can never know that a particular item is meant to be
     the rarest thing in its mod. Only the mod's author knows that, and before this file
     the only way to say so was to edit TC_Overrides.lua inside The Catalogue -- which
     does not survive an update and does not scale past one mod.

     USAGE. Everything here is safe to call at any time, including before The Catalogue
     has built its index; registrations are held and applied when the index is built.
     From another mod, in media/lua/shared or server:

         if TheCatalogue then
             TheCatalogue.registerPrice("MyMod.GoldIdol", 4000)
             TheCatalogue.excludeItem("MyMod.QuestToken")
             TheCatalogue.registerCategoryBase("Relic", 250)
             TheCatalogue.registerValueHandler("MyMod", function(scriptItem, fullType)
                 if fullType:find("^MyMod%.Ingot") then return 180 end
                 return nil     -- nil means "not mine, carry on"
             end)
         end

     PRECEDENCE, highest first. Each layer only sees what the layer above did not answer:

         1. registerPrice          another mod naming its own item's price
         2. TC_Overrides.lua       hand-set vanilla prices that carry balance weight
         3. TC_PriceTable.lua      generated from the vanilla item scripts
         4. registerValueHandler   a mod's own rule, in registration order
         5. TC_ModPricing.lua      our rules, applied to a live instance
         6. the category formula   last resort

     registerPrice sits above our own tables on purpose: an author naming a price for
     their own item is better information than anything we can infer, and it is the
     whole point of the API. registerValueHandler sits BELOW the generated table so a
     broad handler cannot accidentally reprice all of vanilla.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC.REGISTERED_PRICES   = TC.REGISTERED_PRICES or {}
TC.REGISTERED_BASES    = TC.REGISTERED_BASES or {}
TC.REGISTERED_HANDLERS = TC.REGISTERED_HANDLERS or {}

local function warn(msg)
    TC.warn("API: %s", msg)
end

--[[ Fix the price of one item. Wins over everything The Catalogue works out itself. ]]
function TC.registerPrice(fullType, price)
    if type(fullType) ~= "string" or type(price) ~= "number" or price < 0 then
        warn("registerPrice ignored: expected (string fullType, number price >= 0)")
        return false
    end
    TC.REGISTERED_PRICES[fullType] = math.floor(price + 0.5)
    return true
end

--[[ Keep an item out of the catalogue entirely -- quest tokens, currency, anything
     that would be nonsense to trade. Excluded items are also refused for sale, and
     the sale is careful never to destroy them inside a container. ]]
function TC.excludeItem(fullType)
    if type(fullType) ~= "string" then
        warn("excludeItem ignored: expected a fullType string")
        return false
    end
    TC.EXCLUDED_ITEMS[fullType] = true
    return true
end

--[[ Set the base price for a DisplayCategory the formula has never heard of. Only
     reached by the last-resort formula, so it is a safety net rather than a lever. ]]
function TC.registerCategoryBase(category, price)
    if type(category) ~= "string" or type(price) ~= "number" or price < 0 then
        warn("registerCategoryBase ignored: expected (string category, number price >= 0)")
        return false
    end
    TC.REGISTERED_BASES[category] = price
    return true
end

--[[ Register a rule.

     `handler(scriptItem, fullType)` returns a number to claim the item, or nil to pass.
     `name` identifies the handler in logs and lets a mod replace its own registration
     instead of stacking duplicates on a reload.

     Handlers run in registration order and the first number wins. A handler that
     throws is caught, reported once and skipped -- a broken third-party rule must not
     take the whole index down with it. ]]
function TC.registerValueHandler(name, handler)
    if type(name) ~= "string" or type(handler) ~= "function" then
        warn("registerValueHandler ignored: expected (string name, function handler)")
        return false
    end

    for _, h in ipairs(TC.REGISTERED_HANDLERS) do
        if h.name == name then
            h.fn = handler
            h.broken = false
            return true
        end
    end

    table.insert(TC.REGISTERED_HANDLERS, { name = name, fn = handler, broken = false })
    return true
end

--[[ Ask the registered handlers, in order. Used by buildIndex; not usually called
     directly. ]]
function TC.runValueHandlers(scriptItem, fullType)
    for _, h in ipairs(TC.REGISTERED_HANDLERS) do
        if not h.broken then
            local ok, result = pcall(h.fn, scriptItem, fullType)
            if not ok then
                h.broken = true
                warn("handler '" .. h.name .. "' threw and was disabled: " .. tostring(result))
            elseif type(result) == "number" and result >= 0 then
                return math.floor(result + 0.5)
            end
        end
    end
    return nil
end

--[[ Drop the cached index so the next lookup rebuilds it.

     A mod that registers prices after the catalogue has already been opened would
     otherwise not see its own registrations until the next session. ]]
function TC.invalidateIndex()
    TC.entries = nil
    TC.priceByType = nil
    TC.sortCache = nil
end
