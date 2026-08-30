--[[ The Catalogue -- sitting down at the computer and putting the disc in.

     The same shape as TC_ATMAction and for the same reason: luautils.walkAdj queues a walk
     and does not say when it finishes, so the window has to open from a timed action or it
     opens while the character is still crossing the room.

     WHAT PERFORM DOES THAT THE ATM'S DOES NOT: it starts a session. TC.startOnline is what
     makes every catalogue window this player opens from now on spend a bank balance
     instead of the notes in their pockets, and it is set BEFORE the window opens so that
     the window's own title and figures are right on the first frame rather than one frame
     later.
]]

require "TimedActions/ISBaseTimedAction"

TC_UseComputerAction = ISBaseTimedAction:derive("TC_UseComputerAction")

function TC_UseComputerAction:isValid()
    return self.computer ~= nil and self.computer:getSquare() ~= nil
end

function TC_UseComputerAction:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_UseComputerAction:start()
end

function TC_UseComputerAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

--[[ The disc is re-read here rather than carried from the menu.

     Seconds have passed since the option was clicked, and in this game seconds are enough
     for the player to have dropped the disc, or for the card behind its account to have
     left the bag. Asking again is cheap and is the difference between a catalogue that
     cannot pay and one that never opened. ]]
function TC_UseComputerAction:perform()
    local TC = TheCatalogue
    local playerNum = self.character:getPlayerNum()

    local account = TC.discAccount(self.character)

    if not account then
        HaloTextHelper.addBadText(self.character, getText("IGUI_TC_OnlineNoAccount"))
        ISBaseTimedAction.perform(self)
        return
    end

    if TC.startOnline(playerNum, account, self.computer) then
        TC.openBuyWindow(playerNum)
    end

    ISBaseTimedAction.perform(self)
end

function TC_UseComputerAction:new(character, computer)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- Long enough to read as a machine booting, short enough not to be a toll. The ATM's
    -- card slot is 45 ticks; a 1993 desktop is slower than a card slot.
    o.maxTime = 90
    return o
end
