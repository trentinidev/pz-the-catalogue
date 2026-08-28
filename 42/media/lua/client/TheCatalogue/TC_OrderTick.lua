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

--[[ Whether this session has already raised the arrival window once.

     A delivery can arrive and then be saved and quit on, and on the next load nothing
     "arrives" -- it is already there. Without this, goods waiting at the door would go
     unmentioned until the player happened to right-click the catalogue. Set on the
     first mention of the session either way, so closing the window is respected and
     the reminder never becomes nagging. ]]
local announced = false

local function tick()
    local player = getSpecificPlayer(0)
    if not player or player:isDead() then return end
    if TC.pendingCount(player) == 0 then return end

    local arrived, refunded = TC.deliverDueOrders(player)

    -- Something was already waiting when this session started.
    if arrived == 0 and not announced and TC.arrivedCount(player) > 0 then
        announced = true
        TC.openArrivalWindow(0)
    end

    --[[ Nothing is spawned here any more. The van has turned up; the window says what
         is on it and the player presses Receive when they are ready for it.

         The popup is justified now in a way it would not have been before: it is not
         reporting something that already happened, it is asking for a decision. The
         halo text stays as well, because the window can be closed or missed and the
         goods keep waiting either way. ]]
    if arrived > 0 then
        announced = true
        HaloTextHelper.addText(player, getText("IGUI_TC_DeliveryArrived", arrived))
        TC.openArrivalWindow(0)
    end
    if refunded > 0 then
        HaloTextHelper.addBadText(player, getText("IGUI_TC_DeliveryFailed", refunded))
    end
end

Events.EveryTenMinutes.Add(tick)
