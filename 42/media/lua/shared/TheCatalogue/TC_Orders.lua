--[[ The Catalogue -- orders, lead times and delivery.

     Until now the catalogue was a vending machine: press buy, receive goods. That
     works, and it is also the reason the mod trivialises the game once you have an
     income -- there is never a reason to plan, because everything is always available
     immediately.

     An order separates paying from receiving. You commit the money now and the goods
     turn up hours later, wherever you happen to be standing, in a parcel dropped at
     your feet. That turns "I will buy it when I need it" into "I need to work out what
     I will need", which is the kind of planning the rest of the game already rewards.

     THE ONE STATE THAT HAS TO SURVIVE A SAVE. Everything else in this mod is either
     derived (the price index) or a live reference (the sell staging). An order is a
     promise made before a save and kept after one, so it lives on the player's modData
     -- the same place the wishlist and the ledger live, and the only persistence the
     game offers Lua without a save hook.

     Time is measured with getWorldAgeHours, which counts forward from world creation
     and never runs backwards. Wall-clock time would be wrong: an order placed at dusk
     should arrive after a night's sleep, not after the player has been away from their
     desk for eight hours.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local ORDERS_KEY = "TheCatalogue_Orders"

--[[ The parcels a delivery can arrive in, smallest first.

     The first five are vanilla. The last three are ours, and they exist because
     vanilla's largest box holds 20 while a single generator weighs 40 -- without them
     the heaviest goods in the catalogue could not be packed at all. See
     media/scripts/thecatalogue.txt. ]]
local PARCELS = {
    { type = "Base.Parcel_ExtraSmall", cap = 1 },
    { type = "Base.Parcel_Small",      cap = 2 },
    { type = "Base.Parcel_Medium",     cap = 5 },
    { type = "Base.Parcel_Large",      cap = 10 },
    { type = "Base.Parcel_ExtraLarge", cap = 20 },
    { type = "Catalogue.Parcel_XXL",   cap = 25 },
    { type = "Catalogue.Parcel_5XL",   cap = 50 },
    { type = "Catalogue.Parcel_10XL",  cap = 100 },
}

local LARGEST_CAP = PARCELS[#PARCELS].cap

-- ---------------------------------------------------------------------------
-- The store
-- ---------------------------------------------------------------------------

function TC.orders(player)
    if not player then return {} end
    local md = player:getModData()
    if type(md[ORDERS_KEY]) ~= "table" then md[ORDERS_KEY] = {} end
    return md[ORDERS_KEY]
end

local function worldHours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours()
end

-- ---------------------------------------------------------------------------
-- Lead time
-- ---------------------------------------------------------------------------

--[[ How long an order takes, in game hours.

     Weight dominates, because a lorry full of planks is a different job from an
     envelope of nails, and value contributes a little so that the rare and expensive
     things are also the ones worth planning around. Both are sub-linear: a hundred
     hammers should take longer than one, but not a hundred times longer.

     Clamped at both ends. The floor stops a single tin of beans arriving before the
     player has walked away from the catalogue, which would make the whole system feel
     pointless; the ceiling stops a bulk order effectively never arriving.
]]
function TC.orderEta(lines)
    local weight, value = 0, 0
    for _, l in ipairs(lines) do
        weight = weight + (l.weight or 0) * l.qty
        value  = value + (l.unit or 0) * l.qty
    end

    local hours = 5
                  + (weight ^ 0.7) * 1.6
                  + (value  ^ 0.5) * 0.35

    hours = hours * (TC.opt("DeliveryHoursMultiplier") or 1.0)

    if hours < 4 then hours = 4 end
    if hours > 96 then hours = 96 end
    return math.floor(hours + 0.5)
end

--[[ What paying to skip the wait costs, on top of the order. ]]
function TC.rushSurcharge(total)
    local pct = TC.opt("RushFeePercent") or 20
    return math.floor(total * pct / 100 + 0.5)
end

-- ---------------------------------------------------------------------------
-- Placing
-- ---------------------------------------------------------------------------

--[[ Record a paid order. The money has already left the player by the time this is
     called -- an order in the list is a debt the catalogue owes, never a pending
     charge, so a save mid-flight can never lose track of who is owed what. ]]
function TC.placeOrder(player, lines, paid)
    local orders = TC.orders(player)
    local now = worldHours()

    local order = {
        id      = string.format("%d-%d", math.floor(now), #orders + 1),
        lines   = lines,
        paid    = paid,
        placed  = now,
        due     = now + TC.orderEta(lines),
    }

    table.insert(orders, order)
    return order
end

function TC.pendingCount(player)
    return #TC.orders(player)
end

--[[ Hours left on an order, floored at zero. ]]
function TC.hoursLeft(order)
    local left = (order.due or 0) - worldHours()
    if left < 0 then return 0 end
    return left
end

-- ---------------------------------------------------------------------------
-- Packing
-- ---------------------------------------------------------------------------

local function smallestParcelFor(weight)
    for _, p in ipairs(PARCELS) do
        if p.cap >= weight then return p end
    end
    return PARCELS[#PARCELS]
end

--[[ Pack a delivery into as few parcels as it needs and drop them at the player's feet.

     Greedy, and deliberately so: the goods are already paid for, so there is nothing to
     win by packing optimally and a lot to lose by getting clever and dropping an item.
     Each parcel is sized to whatever is still waiting, then filled until the next item
     would not fit.

     An item heavier than the largest crate cannot be boxed at all and is set down
     beside the parcels. With the XXL sizes that only happens above 100 units, which no
     single vanilla item reaches -- but the branch exists because a modded item could,
     and a delivery that silently skipped it would be the worst kind of bug.
]]
function TC.packAndDrop(player, lines)
    local square = player:getSquare()
    if not square then return 0, 0 end

    -- Flatten to individual units: parcels hold items, not stacks.
    local units = {}
    for _, l in ipairs(lines) do
        for _ = 1, l.qty do
            table.insert(units, { fullType = l.fullType, weight = l.weight or 0 })
        end
    end

    -- Heaviest first, so a big awkward item picks the crate size instead of being left
    -- over at the end with nowhere to go.
    table.sort(units, function(a, b) return a.weight > b.weight end)

    local parcelCount, looseCount = 0, 0
    local i = 1

    while i <= #units do
        if units[i].weight > LARGEST_CAP then
            square:AddWorldInventoryItem(units[i].fullType, 0, 0, 0)
            looseCount = looseCount + 1
            i = i + 1
        else
            local remaining = 0
            for j = i, #units do
                if units[j].weight <= LARGEST_CAP then remaining = remaining + units[j].weight end
            end

            local spec   = smallestParcelFor(remaining)
            local parcel = instanceItem(spec.type)
            if not parcel then
                -- Cannot make the box: set the goods down rather than lose them.
                for j = i, #units do
                    square:AddWorldInventoryItem(units[j].fullType, 0, 0, 0)
                    looseCount = looseCount + 1
                end
                break
            end

            local inv, used = parcel:getInventory(), 0
            while i <= #units do
                local u = units[i]
                if u.weight > LARGEST_CAP then break end
                if used + u.weight > spec.cap then break end
                inv:AddItem(u.fullType)
                used = used + u.weight
                i = i + 1
            end

            -- Stamped as packaging so the catalogue will not buy its own box back. A
            -- vanilla parcel is otherwise ordinary loot, so the mark goes on this
            -- instance rather than on the type.
            TC.markPackaging(parcel)

            square:AddWorldInventoryItem(parcel, 0, 0, 0)
            parcelCount = parcelCount + 1
        end
    end

    return parcelCount, looseCount
end

-- ---------------------------------------------------------------------------
-- Delivery
-- ---------------------------------------------------------------------------

--[[ Deliver everything that is due, and refund anything that cannot be delivered.

     Called on a timer while the player is in the world. Returns the number delivered
     and the number refunded so the caller can tell them.

     Refunds are always in full. The player did not choose for a delivery to fail, and
     charging them a cancellation fee for the mod's own inability to spawn an item
     would be punishing them for our problem.
]]
function TC.deliverDueOrders(player)
    if not player then return 0, 0 end

    local orders = TC.orders(player)
    if #orders == 0 then return 0, 0 end

    local now = worldHours()
    local delivered, refunded = 0, 0
    local kept = {}

    for _, order in ipairs(orders) do
        if (order.due or 0) > now then
            table.insert(kept, order)
        else
            -- Prove every line can still be made before anything is spawned, so a
            -- delivery is all or nothing rather than half a parcel and a refund.
            local ok = true
            for _, l in ipairs(order.lines or {}) do
                if not getScriptManager():FindItem(l.fullType) then
                    ok = false
                end
            end

            if ok and player:getSquare() then
                local parcels, loose = TC.packAndDrop(player, order.lines)
                TC.logTransaction(player, "buy", order.lines, order.paid or 0)
                TC.log("delivered order %s as %d parcel(s), %d loose",
                       tostring(order.id), parcels, loose)
                delivered = delivered + 1
            elseif not ok then
                TC.giveCash(player, order.paid or 0)
                TC.warn("order %s could not be delivered, refunded $%d",
                        tostring(order.id), order.paid or 0)
                refunded = refunded + 1
            else
                -- No square yet: the player is mid-load. Try again on the next tick.
                table.insert(kept, order)
            end
        end
    end

    local md = player:getModData()
    md[ORDERS_KEY] = kept

    return delivered, refunded
end
