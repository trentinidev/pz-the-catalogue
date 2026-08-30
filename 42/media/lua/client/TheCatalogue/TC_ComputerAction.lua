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

-- ---------------------------------------------------------------------------

TC_InstallBankingAction = ISBaseTimedAction:derive("TC_InstallBankingAction")

function TC_InstallBankingAction:isValid()
    local TC = TheCatalogue
    return self.computer ~= nil
       and self.computer:getSquare() ~= nil
       and not TC.bankingInstalled(self.computer)
       and TC.findBankingDisc(self.character) ~= nil
       and TC.findSkimmer(self.character) ~= nil
end

function TC_InstallBankingAction:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_InstallBankingAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_InstallBankingAction:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

--[[ BOTH PARTS ARE CONSUMED and the machine reads cards forever afterwards.

     The disc is the bank's software; the card reader is the only thing in the game that
     can pull a number off a magnetic strip. Wired into the case it stops being ten reads
     in a bag and becomes a permanent fixture -- which is exactly the trade, because that
     is the last this reader will ever be used for anywhere else.

     Both are looked up again rather than carried from the menu: minutes have passed. ]]
function TC_InstallBankingAction:perform()
    local TC = TheCatalogue

    local disc   = TC.findBankingDisc(self.character)
    local reader = TC.findSkimmer(self.character)

    if disc and reader and TC.installBanking(self.computer) then
        TC.removeItem(disc)
        TC.removeItem(reader)
        HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_BankingInstalled"))
        self.character:getXp():AddXP(Perks.Electricity, 20)
    end

    ISBaseTimedAction.perform(self)
end

function TC_InstallBankingAction:new(character, computer)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- Longer than installing the shop: a reader has to be opened up and wired in.
    o.maxTime = 360
    return o
end

-- ---------------------------------------------------------------------------

TC_UseBankingAction = ISBaseTimedAction:derive("TC_UseBankingAction")

function TC_UseBankingAction:isValid()
    return self.computer ~= nil and self.computer:getSquare() ~= nil
end

function TC_UseBankingAction:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_UseBankingAction:start()
end

function TC_UseBankingAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

--[[ The bank window, in remote mode.

     Same window, same PIN, same three-tries-and-a-lockout: a card belonging to somebody
     else is exactly as much of a puzzle at a desk as it is at a machine in the street. The
     alternative -- a computer that skips the PIN because a reader is wired into it -- would
     have made every one of the nine ways into a stranger's account pointless overnight.

     The card is re-checked because minutes have passed since the menu was drawn. ]]
function TC_UseBankingAction:perform()
    local TC = TheCatalogue
    local playerNum = self.character:getPlayerNum()

    if not TC.holdsCardFor(self.character, self.account) then
        HaloTextHelper.addBadText(self.character, getText("IGUI_TC_OnlineNeedsCard"))
        ISBaseTimedAction.perform(self)
        return
    end

    TC.openATMWindow(playerNum, self.computer, self.account)
    ISBaseTimedAction.perform(self)
end

function TC_UseBankingAction:new(character, computer, account)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.account  = account
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime = 90
    return o
end

-- ---------------------------------------------------------------------------

TC_InstallCassetteAction = ISBaseTimedAction:derive("TC_InstallCassetteAction")

function TC_InstallCassetteAction:isValid()
    local TC = TheCatalogue
    return self.computer ~= nil
       and self.computer:getSquare() ~= nil
       and TC.bankingInstalled(self.computer)
       and not TC.cassetteInstalled(self.computer)
       and TC.findCassette(self.character) ~= nil
end

function TC_InstallCassetteAction:waitToStart()
    self.character:faceThisObject(self.computer)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_InstallCassetteAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_InstallCassetteAction:update()
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
end

--[[ Bolting a bank's note path onto a desk.

     The assembly is consumed, and there is only one of it per ATM in the county -- so this
     is the most expensive single decision in the mod: a machine forced open, a part
     salvaged at Electricity 6, and then given up for good to one particular computer.

     What it buys is the one thing internet banking could not do: notes going INTO an
     account somewhere other than a cash machine. Taking them out still needs a real
     machine, and that asymmetry is deliberate -- a cassette is a box that swallows notes
     and counts them, not one that hands them back. ]]
function TC_InstallCassetteAction:perform()
    local TC = TheCatalogue

    local part = TC.findCassette(self.character)
    if part and TC.installCassette(self.computer) then
        TC.removeItem(part)
        HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_CassetteInstalled"))
        self.character:getXp():AddXP(Perks.Electricity, 30)
    end

    ISBaseTimedAction.perform(self)
end

function TC_InstallCassetteAction:new(character, computer)
    local o = ISBaseTimedAction.new(self, character)
    o.computer = computer
    o.stopOnWalk = true
    o.stopOnRun  = true
    -- The longest install in the mod: this is a steel assembly being fitted, not a disc.
    o.maxTime = 480
    return o
end
