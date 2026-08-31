--[[ The Catalogue -- the half-second after the furniture comes off the floor.

     WHY THIS IS A SECOND ACTION AND NOT ONE BIG ONE. Taking a piece of furniture out of
     a room is work the game already models properly: it checks the tool, it checks the
     carpentry level, it walks the character there, it plays the animation, it takes the
     right number of seconds, and it handles the two or three tiles a double bed occupies
     as one piece. Writing our own version of all that to save the player carrying a sofa
     would be re-implementing vanilla badly.

     So the menu queues VANILLA's pickup action, and this runs immediately after it. All
     it does is take the item that landed in the player's hands and pay for it.

     WHAT HAPPENS IF IT DOES NOT FIND THE ITEM. Nothing bad. The pickup already happened,
     so the player is holding the furniture and can walk it to the catalogue and sell it
     the ordinary way. That is the whole reason the pickup goes first and the sale second:
     a failure here costs the player a trip, not a sofa.
]]

require "TimedActions/ISBaseTimedAction"

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC_SellFurnitureAction = ISBaseTimedAction:derive("TC_SellFurnitureAction")

function TC_SellFurnitureAction:isValid()
    return true
end

function TC_SellFurnitureAction:waitToStart()
    return false
end

function TC_SellFurnitureAction:update()
end

function TC_SellFurnitureAction:start()
end

function TC_SellFurnitureAction:stop()
    ISBaseTimedAction.stop(self)
end

--[[ Instant. The work was the action before this one; this is the receipt. ]]
function TC_SellFurnitureAction:getDuration()
    return 1
end

--[[ The piece that just arrived, found by the sprite it carries.

     Searched by sprite rather than by "the newest Moveable", because a player who is
     already carrying three chairs would otherwise sell the wrong one. getAllTypeRecurse
     is asked for both spellings for the same reason TC.cardItemsOn does: the game's own
     Lua is not consistent about whether these lookups want the module prefix.

     The 340 pieces that ARE items answer here too -- a Base.Mov_BeachChair is a Moveable
     and knows its world sprite -- so one lookup covers both halves of the catalogue. ]]
local function findPickedUp(player, sprite)
    local inv = player:getInventory()
    if not inv then return nil end

    for _, typeName in ipairs({ "Moveable", "Base.Moveable" }) do
        local ok, list = pcall(function() return inv:getAllTypeRecurse(typeName) end)
        if ok and list then
            for i = 0, list:size() - 1 do
                local item = list:get(i)
                if TC.moveableSprite(item) == sprite then return item end
            end
        end
    end

    --[[ And the custom-item half, which getAllTypeRecurse("Moveable") does not reach
         because those carry their own type. Walking the inventory is the only lookup
         that sees every Moveable whatever its fullType. ]]
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if TC.moveableSprite(item) == sprite then return item end
    end

    return nil
end

function TC_SellFurnitureAction:perform()
    local item = findPickedUp(self.character, self.sprite)

    if item then
        local value = TC.getSellValue(item)
        if value then
            local total = math.max(0, math.floor(value + 0.5))

            -- Summarised BEFORE the item is removed, and through the same helper the
            -- sell window uses, because the ledger stores receipt LINES and not a
            -- sentence. Handing it the label string wrote an entry that crashed the
            -- ledger on its next open; see receiptLines in TC_History.lua.
            local receipt = TC.summariseItems({ item })

            -- The tile's own name if the menu gave us one. getDisplayName on a generic
            -- moveable answers "Moveable object", where the sprite props know it is a
            -- Blue Comfy Couch -- and a receipt is only worth keeping if it says what
            -- was sold. The fullType stays as summariseItems set it, so the row keeps
            -- its icon.
            if receipt[1] and self.label and self.label ~= "" then
                receipt[1].name = self.label
            end

            if TC.removeItem(item) then
                TC.playSound(self.character, "orderSign")
                -- Cash. There is no catalogue window open out here to have chosen an
                -- account, and putting money into one the player did not name would be
                -- deciding for them.
                TC.purseGive(self.character, nil, total)
                TC.logTransaction(self.character, "sell", receipt, total)
                HaloTextHelper.addGoodText(self.character,
                                           getText("IGUI_TC_SoldFurniture", total))
            end
        end
    end

    ISBaseTimedAction.perform(self)
end

function TC_SellFurnitureAction:new(character, sprite, label)
    local o = ISBaseTimedAction.new(self, character)
    o.character  = character
    o.sprite     = sprite
    o.label      = label
    o.stopOnWalk = false
    o.stopOnRun  = false
    o.maxTime    = 1
    return o
end
