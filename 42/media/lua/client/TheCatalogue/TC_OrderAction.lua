--[[ The Catalogue -- the short action of actually placing an order.

     Buying used to resolve the instant the button was pressed, which meant a player
     could stand in a doorway mid-horde and kit themselves out without ever lowering
     their guard. This puts a few seconds of leafing-through-the-catalogue between the
     press and the goods, interruptible like any other action in the game.

     NOTHING IS CHARGED UNTIL THIS COMPLETES. The whole purchase runs in perform(), so
     an interrupted order costs nothing -- there is no half-state to unwind, which is
     the same reasoning behind the atomic checkout in the buy window.
]]

require "TimedActions/ISBaseTimedAction"

TC_OrderAction = ISBaseTimedAction:derive("TC_OrderAction")

function TC_OrderAction:isValid()
    -- The catalogue has to still be on the player and the window still open.
    return TheCatalogue.hasCatalogue(self.character) and self.window ~= nil
end

function TC_OrderAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function TC_OrderAction:start()
    self:setActionAnim("Loot")
    self.character:reportEvent("EventLootItem")
end

function TC_OrderAction:stop()
    ISBaseTimedAction.stop(self)
    if self.window and self.window.onOrderCancelled then
        self.window:onOrderCancelled()
    end
end

function TC_OrderAction:perform()
    -- Runs only on completion, so an interrupted order never touches money or items.
    if self.window and self.window.onOrderComplete then
        self.window:onOrderComplete(self.payload)
    end
    ISBaseTimedAction.perform(self)
end

function TC_OrderAction:new(character, window, payload, seconds)
    local o = ISBaseTimedAction.new(self, character)
    o.window = window
    o.payload = payload
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = (seconds or 3) * 60      -- ISBaseTimedAction counts in ticks, 60 a second
    return o
end
