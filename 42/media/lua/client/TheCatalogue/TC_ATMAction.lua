--[[ The Catalogue -- walking up to the machine and putting the card in.

     WHY THERE IS AN ACTION HERE AT ALL. luautils.walkAdj queues a walk and returns; it
     does not tell you when the character arrives. Opening the window straight after
     queueing it would put the ATM screen on the player's monitor while the character was
     still crossing the room -- and worse, would let them do their banking and close it
     again without ever reaching the wall. The window has to open when the walk FINISHES,
     and a timed action is the only thing in this game that knows when that is.

     Modelled on ISPlantInfoAction, which is vanilla's own answer to the same shape of
     problem: walk to a thing, turn to it, open a window about it. waitToStart holds the
     action until the turn is done, and perform is the only place a window appears.

     NO ACTION ANIMATION. CharacterActionAnims has twenty-odd entries and not one of them
     is a person standing at a machine pressing buttons -- the nearest, Loot, is the
     crouched rummage the character does over a corpse. Standing still, facing the ATM, is
     both the honest picture and the one vanilla settles for in the same situation.

     NOTHING IS COMMITTED HERE. The action only opens a window; every dollar that moves,
     moves later, from a button on it. So there is no half-state to unwind and an
     interruption costs nothing -- the same reasoning that makes TC_OrderAction safe to
     cancel, arrived at from the opposite direction.
]]

require "TimedActions/ISBaseTimedAction"

TC_ATMAction = ISBaseTimedAction:derive("TC_ATMAction")

--[[ Still worth doing?

     The square is re-read rather than remembered, because an ATM is a MOVEABLE object in
     this game -- crowbar, level 2 -- and the one thing that must not happen is a window
     opening onto a machine somebody has just picked up and walked off with. ]]
function TC_ATMAction:isValid()
    return self.atm ~= nil and self.atm:getSquare() ~= nil
end

function TC_ATMAction:waitToStart()
    self.character:faceThisObject(self.atm)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_ATMAction:start()
end

function TC_ATMAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function TC_ATMAction:perform()
    TheCatalogue.openATMWindow(self.character:getPlayerNum(), self.atm)
    ISBaseTimedAction.perform(self)
end

function TC_ATMAction:new(character, atm)
    local o = ISBaseTimedAction.new(self, character)
    o.atm = atm
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- ISBaseTimedAction counts in ticks at sixty a second, the same as TC_OrderAction.
    -- Long enough to read as putting a card in a slot, short enough not to be a toll.
    o.maxTime = 45
    return o
end
