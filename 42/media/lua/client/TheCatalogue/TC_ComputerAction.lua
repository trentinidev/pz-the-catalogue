--[[ The Catalogue -- installing the disc, and sitting down at the machine.

     Both are the same shape as TC_ATMAction and for the same reason: luautils.walkAdj
     queues a walk and does not say when it finishes, so anything that should happen at the
     computer has to happen in a timed action or it happens while the character is still
     crossing the room.
]]

require "TimedActions/ISBaseTimedAction"

-- ---------------------------------------------------------------------------

TC_InstallCatalogueAction = ISBaseTimedAction:derive("TC_InstallCatalogueAction")

function TC_InstallCatalogueAction:isValid()
    local TC = TheCatalogue
    return self.computer ~= nil
       and self.computer:getSquare() ~= nil
       and not TC.catalogueInstalled(self.computer)
       and #TC.discItemsOn(self.character) > 0
end

function TC_InstallCatalogueAction:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_InstallCatalogueAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_InstallCatalogueAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

--[[ THE DISC IS CONSUMED and the machine keeps the catalogue for good.

     Both halves are the point. Spending the disc is what makes finding a blank one matter
     and what stops one disc lighting up every computer in the county; the install being
     permanent is what turns a machine into a PLACE -- somewhere you set up once, come back
     to, and can tell somebody else about.

     The disc is looked up again here rather than carried from the menu, because seconds
     have passed and in this game seconds are enough to have dropped it. ]]
function TC_InstallCatalogueAction:perform()
    local TC = TheCatalogue

    local discs = TC.discItemsOn(self.character)
    if #discs > 0 and TC.installCatalogue(self.computer) then
        TC.removeItem(discs[1])
        HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_OnlineInstalled"))
    end

    ISBaseTimedAction.perform(self)
end

function TC_InstallCatalogueAction:new(character, computer)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- Long enough to read as a 1993 machine reading a disc, which is a while.
    o.maxTime = 240
    return o
end

-- ---------------------------------------------------------------------------

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

--[[ The card is re-checked here rather than trusted from the menu.

     Seconds have passed since the option was clicked, and that is long enough for the card
     to have left the player's bag. TC.holdsCardFor is the same question the cash machine
     asks continuously, and asking it once more here is the difference between a catalogue
     that cannot pay and one that never opened.

     TC.startOnline is set BEFORE the window opens so that the title and the figures are
     right on the first frame rather than one frame later. ]]
function TC_UseComputerAction:perform()
    local TC = TheCatalogue
    local playerNum = self.character:getPlayerNum()

    if not TC.holdsCardFor(self.character, self.account) then
        HaloTextHelper.addBadText(self.character, getText("IGUI_TC_OnlineNeedsCard"))
        ISBaseTimedAction.perform(self)
        return
    end

    if TC.startOnline(playerNum, self.account, self.computer) then
        TC.openBuyWindow(playerNum)
    end

    ISBaseTimedAction.perform(self)
end

function TC_UseComputerAction:new(character, computer, account)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.account  = account
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- The ATM's card slot is 45 ticks; a 1993 desktop is slower than a card slot.
    o.maxTime = 90
    return o
end
