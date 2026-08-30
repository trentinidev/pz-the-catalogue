--[[ The Catalogue -- noticing a card that has not been named yet.

     TC_WorldCards can give a card an identity; this decides WHEN. Two hooks, because there
     are two ways a card reaches a player and only one of them is a container being filled.

     OnFillContainer fires as the game generates loot into a container -- a desk, a bin, a
     wallet inside a bag -- so a card is named at the moment it comes into existence, before
     anybody has seen it. That covers houses, shops and offices, which is most of them.

     It does NOT cover a zombie. Vanilla dresses zombies from outfit tables (Outfit_Gaudy
     carries four rolls of CreditCard), and that is not a container being filled; the card
     appears on a corpse the player is already looting. So the second hook is a throttled
     sweep of the player's own inventory, which catches a card whatever brought it -- a
     corpse, a trade, another mod, the debug menu -- and is the backstop that means the
     feature cannot have a hole in it that a player finds before I do.

     THE SWEEP IS THE EXPENSIVE ONE AND IT IS STILL CHEAP. getAllTypeRecurse for two item
     types, once every couple of seconds, against a window in this mod that redraws several
     thousand list rows a frame. The throttle is what keeps it off the per-tick path; the
     early return when the player has no cards at all is what makes the common case nothing.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ How often the player's own inventory is swept, in milliseconds.

     Two seconds, which is slower than a player can loot a corpse and read the name, and
     slow enough that the cost never shows up. The one visible consequence is that a card
     taken off a body can spend a moment called "Credit Card" before it becomes "Credit
     Card - Rose Miller (8471)"; that reads as the card being examined rather than as a
     bug. ]]
local SWEEP_MS = 2000

local lastSweep = 0

--[[ Loot being generated. The container is handed over already full. ]]
local function onFillContainer(roomName, containerType, container)
    if not container then return end

    --[[ Where this container is, which the "note elsewhere in the building" secret needs.
         The container hangs off a world object; that object knows its square. Both can be
         absent -- a vehicle's glovebox, most obviously -- and a card in one simply cannot
         queue a note, which is right. ]]
    local parent = container:getParent()
    local square = parent and parent:getSquare()

    local n = TC.blessContainer(container, nil, container, square)
    if n > 0 then
        TC.log("named %d card(s) in a %s", n, tostring(containerType))
    end

    -- And drop any note a card found in a nearby drawer was waiting for.
    if square then
        local notes = TC.placeHouseNotes(getSpecificPlayer(0), container, square)
        if notes > 0 then TC.log("left %d PIN note(s) in a %s", notes, tostring(containerType)) end
    end
end

--[[ The backstop. Runs per player per tick and does almost nothing on almost all of them.

     Both spellings of the type, the way TC_Money.lua and TC.cardsOnPlayer do it, because
     the game's own Lua is inconsistent about whether these lookups want the module prefix.
     The stolen variant is asked for separately rather than folded in, because
     getAllTypeRecurse takes one type at a time. ]]
local function sweep(player)
    if not player then return end

    local now = getTimestampMs()
    if (now - lastSweep) < SWEEP_MS then return end
    lastSweep = now

    -- The same lookup the machine uses, so a card the sweep names is a card the machine
    -- can see. These were two separate lists once, they disagreed about the stolen
    -- variant, and a stolen card ended up with an account that no ATM would offer.
    for _, item in ipairs(TC.cardItemsOn(player)) do
        TC.blessCard(item)
    end
end

Events.OnFillContainer.Add(onFillContainer)
Events.OnPlayerUpdate.Add(sweep)
