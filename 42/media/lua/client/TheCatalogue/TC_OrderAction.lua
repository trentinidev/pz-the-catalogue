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

--[[ A page flip partway through, once.

     The action was silent between its two ends, which made two seconds feel like a
     freeze rather than like doing something. A single flip near the middle is enough
     to say the pages are turning; a loop would be noise on an action this short.

     Guarded by a flag rather than by a time window, because update runs every tick and
     a window would fire it several times in a row. ]]
function TC_OrderAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)

    if not self.flipped and self:getJobDelta() > 0.45 then
        self.flipped = true
        TheCatalogue.playSound(self.character, "orderFlip")
    end
end

--[[ Reading, not looting.

     It was the Loot animation -- a crouched rummage through a container -- which is
     what the character does to a corpse, not to a mail-order catalogue. Read is the
     same animation vanilla uses for a book or for writing a note, which is exactly
     what placing an order is. ]]
function TC_OrderAction:start()
    self:setActionAnim(CharacterActionAnims.Read)
    self.character:reportEvent("EventRead")
    TheCatalogue.playSound(self.character, "orderOpen")
end

function TC_OrderAction:stop()
    ISBaseTimedAction.stop(self)
    TheCatalogue.playSound(self.character, "orderCancel")
    if self.window and self.window.onOrderCancelled then
        self.window:onOrderCancelled()
    end
end

function TC_OrderAction:perform()
    -- The pen goes down before the window is told, so the sound lands with the action
    -- finishing rather than after whatever the callback decides to do.
    TheCatalogue.playSound(self.character, "orderSign")

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
