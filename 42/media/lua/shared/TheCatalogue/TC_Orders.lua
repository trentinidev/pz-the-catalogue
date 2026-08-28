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

     The first cut had a five-hour base and a sub-linear weight term, which meant a
     single pistol round took six hours to arrive -- the same six hours as a chest of
     tools, because the base swamped everything else. The lead time carried no
     information: it was a flat tax on shopping rather than a reason to think about
     what you were shopping for.

     So the base is nearly nothing and BULK is what costs time. The weight term is
     SUPER-linear, which is the one counter-intuitive choice here and the one that
     makes the curve read correctly: doubling the size of a load more than doubles the
     job, because it stops being something a van drops off on its round and starts
     being a delivery of its own. One round is a padded envelope; a hundred rounds is a
     box; a crate of medical supplies is a morning's work.

     Value is deliberately a WEAK term. It is there so that something small and
     precious is handled a little more carefully than something small and cheap, not so
     that money buys delay -- an expensive light thing should still turn up quickly.
     The per-unit term does the same job for count, and covers items the game gives no
     weight at all, where quantity would otherwise be free.

     Roughly, at the default multiplier:

         1 pistol round            ~20 minutes
         100 pistol rounds         ~2.5 hours
         a bandage                 ~20 minutes
         a crate of medical stock  ~4-5 hours
         a generator               days

     Clamped at both ends: a floor so nothing is instant (that is what Rush is for and
     what the player pays a premium for), and a ceiling so a bulk order still arrives.
     Returns FRACTIONAL hours -- rounding here would collapse every quick delivery to
     the same value, and the display rounds anyway.
]]
function TC.orderEta(lines)
    local weight, value, count = 0, 0, 0
    for _, l in ipairs(lines) do
        local qty = l.qty or 1
        weight = weight + (l.weight or 0) * qty
        value  = value  + (l.unit or 0) * qty
        count  = count  + qty
    end

    local hours = 0.25
                  + (weight ^ 1.3) * 1.5    -- bulk, and it compounds
                  + (value  ^ 0.5) * 0.03   -- a little more care for a little more worth
                  + (count  ^ 0.5) * 0.04   -- handling, even for weightless goods

    hours = hours * (TC.opt("DeliveryHoursMultiplier") or 1.0)

    if hours < 0.25 then hours = 0.25 end
    if hours > 96 then hours = 96 end
    return hours
end

--[[ How a wait is put into words.

     Two forms, because the two places that show one have very different room. The
     phrase goes in a sentence ("arriving within the hour"); the short form goes in the
     ledger's When column beside timestamps.

     Neither is ever exact. A delivery is somebody else's schedule, and "in about three
     hours" is both what a real one would tell you and what stops the player watching a
     clock instead of playing.
]]
function TC.etaPhrase(hours)
    if hours < 1 then return getText("IGUI_TC_EtaSoon") end
    return getText("IGUI_TC_EtaHours", math.floor(hours + 0.5))
end

function TC.etaShort(hours)
    if hours < 1 then return getText("IGUI_TC_LedgerSoon") end
    return getText("IGUI_TC_LedgerEta", math.floor(hours + 0.5))
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

--[[ Mark everything whose time is up as ARRIVED, and refund anything undeliverable.

     Arriving and receiving are two steps, not one. Goods used to appear at the
     player's feet the moment the clock ran out, which meant a delivery could land
     while they were fighting, swimming, or halfway up a rope, and the first they knew
     of it was a parcel left somewhere they were no longer standing. Now the van turns
     up and waits: the order is flagged, the player is told, and the goods are put down
     only when they say so.

     An arrived order STAYS in the list until it is collected, which is what makes it
     safe. The list lives on modData and survives a save, so a delivery that lands two
     minutes before someone quits is still there when they come back. Nothing is spawned
     until TC.collectOrders, and nothing is removed until it has been.

     Returns the number that arrived on this pass and the number refunded.

     Refunds are always in full. The player did not choose for a delivery to fail, and
     charging them a cancellation fee for the mod's own inability to spawn an item
     would be punishing them for our problem.
]]
function TC.deliverDueOrders(player)
    if not player then return 0, 0 end

    local orders = TC.orders(player)
    if #orders == 0 then return 0, 0 end

    local now = worldHours()
    local arrived, refunded = 0, 0
    local kept = {}

    for _, order in ipairs(orders) do
        if order.arrived then
            -- Already waiting to be collected. Nothing to do until the player says so.
            table.insert(kept, order)

        elseif (order.due or 0) > now then
            table.insert(kept, order)

        else
            -- Prove every line can still be made before the player is told anything,
            -- so a delivery is all or nothing rather than half a parcel and a refund.
            -- Checked here rather than at collection because a refund the player has
            -- to click a button to receive is a worse experience than one that simply
            -- appears with an explanation.
            local ok = true
            for _, l in ipairs(order.lines or {}) do
                if not getScriptManager():FindItem(l.fullType) then
                    ok = false
                end
            end

            if ok then
                order.arrived = true
                arrived = arrived + 1
                table.insert(kept, order)
                TC.log("order %s arrived, awaiting collection", tostring(order.id))
            else
                TC.giveCash(player, order.paid or 0)
                TC.warn("order %s could not be delivered, refunded $%d",
                        tostring(order.id), order.paid or 0)
                refunded = refunded + 1
            end
        end
    end

    local md = player:getModData()
    md[ORDERS_KEY] = kept

    return arrived, refunded
end

--[[ The orders standing at the door, in the order they arrived. ]]
function TC.arrivedOrders(player)
    local out = {}
    for _, order in ipairs(TC.orders(player)) do
        if order.arrived then table.insert(out, order) end
    end
    return out
end

function TC.arrivedCount(player)
    return #TC.arrivedOrders(player)
end

--[[ Take delivery: pack everything waiting and set it down at the player's feet.

     Returns the number of orders collected and the number of parcels put down, or
     nil when there is nowhere to put them. An order is removed only after its goods
     have actually been spawned, so a failure here loses nothing -- the delivery is
     still waiting on the next attempt.
]]
function TC.collectOrders(player)
    if not player or not player:getSquare() then return nil end

    local orders = TC.orders(player)
    local kept, collected, parcels = {}, 0, 0

    for _, order in ipairs(orders) do
        if not order.arrived then
            table.insert(kept, order)
        else
            local boxes, loose = TC.packAndDrop(player, order.lines)
            TC.logTransaction(player, "buy", order.lines, order.paid or 0)
            TC.log("collected order %s as %d parcel(s), %d loose",
                   tostring(order.id), boxes, loose)
            collected = collected + 1
            parcels = parcels + boxes + loose
        end
    end

    player:getModData()[ORDERS_KEY] = kept
    return collected, parcels
end
