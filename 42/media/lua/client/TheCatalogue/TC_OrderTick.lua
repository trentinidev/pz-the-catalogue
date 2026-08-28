--[[ The Catalogue -- the clock that makes deliveries arrive.

     Orders are stored with a due time in world hours, but nothing checks that on its
     own. This is the only thing in the mod that runs without the player asking it to.

     EveryTenMinutes is game time, not real time, so it fires about once every ten
     seconds at normal speed and much faster while the player sleeps -- which is
     exactly right, because sleeping through the night is the most natural way to wait
     out a delivery. A ten-minute granularity on an order measured in hours is far
     finer than anyone will notice.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local function tick()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    if TC.pendingCount(player) == 0 then return end

    local delivered, refunded = TC.deliverDueOrders(player)

    -- Told through the halo text rather than a window: a delivery can land while the
    -- player is doing something else entirely, and a popup would be an interruption
    -- for something they already paid for and expected.
    if delivered > 0 then
        HaloTextHelper.addText(player, getText("IGUI_TC_DeliveryArrived", delivered))
    end
    if refunded > 0 then
        HaloTextHelper.addBadText(player, getText("IGUI_TC_DeliveryFailed", refunded))
    end
end

Events.EveryTenMinutes.Add(tick)
