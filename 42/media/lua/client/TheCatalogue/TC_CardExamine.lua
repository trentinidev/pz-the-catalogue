--[[ The Catalogue -- looking closely at a card, and reading what somebody wrote down.

     Two context options on two items, and one timed action behind them, because both are
     the same act: holding a small thing up to the light and finding out what is on it.

     EXAMINING A CARD tells you one of two things, decided when the card was named and not
     when you look:

       the back    the owner wrote the number on it. You have the PIN.
       the pencil  the owner wrote it on and rubbed it out, and the pressure is still in
                   the plastic. You have the four DIGITS with no order -- at most 24
                   arrangements, and fewer when one repeats.

     It takes real time and it wants light, because it is close work on a small object.
     Illiterate characters cannot do it: there are numbers written on the thing.

     BURGLAR IS NOT A DICE ROLL HERE. It could have been -- a chance to fail, re-rollable
     by clicking again -- and that would only have taught the player to click again. The
     trait shortens the job instead, and its real weight is elsewhere: two extra guesses a
     day at the machine, in TC_CardSecrets.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

require "TimedActions/ISBaseTimedAction"

-- Sixty ticks a second, the same unit TC_OrderAction counts in. Twelve seconds of turning
-- a card over, halved for somebody who has done this before.
local EXAMINE_TICKS         = 12 * 60
local EXAMINE_TICKS_BURGLAR = 6 * 60
local READ_TICKS            = 3 * 60

TC_ExamineCardAction = ISBaseTimedAction:derive("TC_ExamineCardAction")

--[[ Still worth doing? The item has to still be on the player -- this is close work with
     the thing in your hands, not a memory of it -- and it has to still have an account.  ]]
function TC_ExamineCardAction:isValid()
    return self.item ~= nil
       and self.item:getContainer() ~= nil
       and TC.account(self.character, self.number) ~= nil
end

function TC_ExamineCardAction:start()
    self:setActionAnim(CharacterActionAnims.Read)
    self.character:reportEvent("EventRead")
end

function TC_ExamineCardAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

--[[ What twelve seconds with a card in your hands actually gets you.

     THE `else` USED TO REVEAL THE DIGITS, and that was the bug the player saw as "every
     card tells me the PIN". Two things were wrong with it. A card whose secret is a note
     in a drawer has nothing written on it at all, and fell into that branch anyway; and a
     card named by 0.4.0-beta, before secrets existed, has no `secret` field and fell in
     too. So examining always paid.

     Each outcome is now named explicitly and anything else finds nothing. A missing
     `secret` is rolled once, here, so cards from an older save join the same distribution
     as everything else rather than being permanently generous. ]]
function TC_ExamineCardAction:perform()
    local acct = TC.account(self.character, self.number)

    if acct then
        if acct.secret == nil then acct.secret = TC.rollCardSecret() end

        if acct.secret == "back" then
            TC.revealPin(acct)
            HaloTextHelper.addGoodText(self.character,
                getText("IGUI_TC_ExaminedBack", acct.pin))

        elseif acct.secret == "worn" then
            TC.revealDigits(acct)
            HaloTextHelper.addGoodText(self.character,
                getText("IGUI_TC_ExaminedWorn", TC.pinDigits(acct)))

        else
            -- Nothing on it, or what there is to find is not on the card. Said plainly, so
            -- the twelve seconds read as answered rather than as broken.
            HaloTextHelper.addBadText(self.character, getText("IGUI_TC_ExaminedNothing"))
        end

        --[[ Marked either way, which is what stops this being a button to press twice.
             The card has been looked at; looking again at the same piece of plastic does
             not make writing appear on it. ]]
        local known = TC.cardKnown(acct)
        if known then known.examined = true end
    end

    ISBaseTimedAction.perform(self)
end

function TC_ExamineCardAction:new(character, item, number)
    local o = ISBaseTimedAction.new(self, character)
    o.item   = item
    o.number = number
    o.stopOnWalk = true
    o.stopOnRun  = true

    o.maxTime = EXAMINE_TICKS
    if character:hasTrait(CharacterTrait.BURGLAR) then
        o.maxTime = EXAMINE_TICKS_BURGLAR
    end
    return o
end

-- ---------------------------------------------------------------------------

TC_ReadNoteAction = ISBaseTimedAction:derive("TC_ReadNoteAction")

function TC_ReadNoteAction:isValid()
    return self.item ~= nil and self.item:getContainer() ~= nil
end

function TC_ReadNoteAction:start()
    self:setActionAnim(CharacterActionAnims.Read)
    self.character:reportEvent("EventRead")
end

function TC_ReadNoteAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function TC_ReadNoteAction:perform()
    local acct = TC.noteAccount(self.character, self.item)

    if acct then
        TC.revealPin(acct)
        HaloTextHelper.addGoodText(self.character,
            getText("IGUI_TC_NoteRead", TC.cardTail(acct.number), acct.pin))
    else
        -- The note names an account this character cannot reach: another save's card, or
        -- one whose register entry is gone. Saying so beats a silent nothing.
        HaloTextHelper.addBadText(self.character, getText("IGUI_TC_NoteUnknown"))
    end

    ISBaseTimedAction.perform(self)
end

function TC_ReadNoteAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime = READ_TICKS
    return o
end

-- ---------------------------------------------------------------------------
-- The card reader
-- ---------------------------------------------------------------------------

--[[ Running a card through a home-made strip reader.

     THE ONLY ROUTE THAT DOES NOT DEPEND ON THE CARD. Examining tells you what that
     particular card happens to carry -- the number on the back if you are lucky, four
     unordered digits if you are not -- and a note is there or it is not. This works the
     same on every card in the county, which is what the skill and the materials are
     buying.

     It costs a point of condition per read, ten reads to a reader. That ceiling is why
     this is not simply better than everything else: one craft cannot answer every card
     you will ever find, and the reader coming apart in your hands is the feature working
     rather than a fault.

     Electricity decides the time and nothing else. A chance to fail would be re-rollable
     by clicking again, which teaches clicking again; and having built the thing, being
     told "it did not work, try once more" is a worse experience than waiting longer. ]]
local SKIM_SECONDS     = 40
local SKIM_ELEC_MIN    = 3

TC_SkimCardAction = ISBaseTimedAction:derive("TC_SkimCardAction")

function TC_SkimCardAction:isValid()
    return self.item ~= nil
       and self.item:getContainer() ~= nil
       and self.reader ~= nil
       and self.reader:getContainer() ~= nil
       and TC.account(self.character, self.number) ~= nil
end

function TC_SkimCardAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_SkimCardAction:update()
    self.character:setMetabolicTarget(Metabolics.LightDomestic)
end

function TC_SkimCardAction:perform()
    local acct = TC.account(self.character, self.number)

    if acct then
        TC.revealPin(acct)
        HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_Skimmed", acct.pin))
        self.character:getXp():AddXP(Perks.Electricity, 5)
    end

    --[[ A point of condition, and the reader is gone at zero.

         Removed rather than left at condition 0, because an item the game still shows in
         the bag but that this file will not use again is a puzzle for the player. It goes,
         and the halo says why. ]]
    local left = self.reader:getCondition() - 1
    if left <= 0 then
        TC.removeItem(self.reader)
        HaloTextHelper.addBadText(self.character, getText("IGUI_TC_SkimmerDead"))
    else
        self.reader:setCondition(left)
    end

    ISBaseTimedAction.perform(self)
end

function TC_SkimCardAction:new(character, item, number, reader)
    local o = ISBaseTimedAction.new(self, character)
    o.item   = item
    o.number = number
    o.reader = reader
    o.stopOnWalk = true
    o.stopOnRun  = true

    -- Level 3 is the floor and takes the full time; level 10 does it in about half.
    local level = character:getPerkLevel(Perks.Electricity)
    local scale = 1 - math.min(0.5, (level - SKIM_ELEC_MIN) * 0.07)
    o.maxTime = math.floor(SKIM_SECONDS * 60 * scale)
    return o
end

--[[ A working reader in the player's bag, or nil.

     Condition is checked here rather than only at use, so a reader on its last legs still
     offers the option and a dead one does not appear at all. ]]
function TC.findSkimmer(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local list = inv:getAllTypeRecurse("Catalogue.CardSkimmer")
    if not list then return nil end

    for i = 0, list:size() - 1 do
        local item = list:get(i)
        if item:getCondition() > 0 then return item end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- The menu
-- ---------------------------------------------------------------------------

--[[ Reading needs light and needs literacy, and the game has an opinion about both.

     tooDarkToRead is the same check vanilla puts in front of a book, and hasTrait
     ILLITERATE is the same one it puts in front of the text. A card is smaller print than
     a book, so if anything this is the more obvious place for them. ]]
local function canRead(player)
    if player:hasTrait(CharacterTrait.ILLITERATE) then
        return false, getText("IGUI_TC_CannotReadIlliterate")
    end
    if player:tooDarkToRead() then
        return false, getText("IGUI_TC_CannotReadDark")
    end
    return true
end

local function onExamine(playerNum, item, number)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    ISTimedActionQueue.add(TC_ExamineCardAction:new(player, item, number))
end

local function onSkim(playerNum, item, number, reader)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    ISTimedActionQueue.add(TC_SkimCardAction:new(player, item, number, reader))
end

local function onReadNote(playerNum, item)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    ISTimedActionQueue.add(TC_ReadNoteAction:new(player, item))
end

--[[ Every real item in a right-clicked selection, stacks flattened.

     The same unwrapping TC_ContextMenu.lua documents: the first entry of a grouped stack
     is a dummy duplicate of the second, exactly as ISInventoryPane.getActualItems says. ]]
local function realItems(items)
    local out = {}
    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            table.insert(out, v)
        elseif v.items then
            for i = 2, #v.items do table.insert(out, v.items[i]) end
        end
    end
    return out
end

local function addOptions(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    if not TC.opt("BankingEnabled") then return end

    local ok, why = canRead(player)

    for _, item in ipairs(realItems(items)) do
        --[[ A card worth examining: one that has an account, and that has not already
             given up everything it has. A card whose PIN you know has nothing left to
             say, and the option disappearing is how the player is told that. ]]
        if TC.isCardItem(item) then
            local md   = item:getModData()
            local acct = md and md.TC_account and TC.account(player, md.TC_account)

            if acct and not TC.knowsPin(acct) then
                --[[ Once looked at, never again -- whatever the looking found.

                     This used to also require that the digits were known, which meant a
                     card with nothing on it offered Examine forever and could be clicked
                     until the player gave up on it. Examining is about the card, and a
                     card does not change. ]]
                local known = TC.cardKnown(acct)
                local done  = known and known.examined

                if not done then
                    local option = TC.addOption(context, getText("ContextMenu_TC_ExamineCard"),
                                                playerNum, onExamine, item, acct.number)
                    if not ok then
                        option.notAvailable = true
                        local tip = ISToolTip:new()
                        tip:setName(getText("ContextMenu_TC_ExamineCard"))
                        tip.description = why
                        option.toolTip = tip
                    end
                end

                --[[ And the reader, offered only when one is actually in the bag.

                     Unlike examining, this is worth doing on a card that has ALREADY been
                     examined -- knowing the four digits is not knowing the number, and the
                     reader is what turns twenty-four arrangements into one. So it is
                     outside the `done` check above and inside the same "PIN still
                     unknown" one. ]]
                local reader = TC.findSkimmer(player)
                if reader then
                    local skim = TC.addOption(context, getText("ContextMenu_TC_SkimCard"),
                                              playerNum, onSkim, item, acct.number, reader)
                    local tip = ISToolTip:new()
                    tip:setName(getText("ContextMenu_TC_SkimCard"))
                    tip.description = getText("IGUI_TC_SkimmerUses", reader:getCondition())
                    skim.toolTip = tip
                end
            end

        elseif TC.noteAccount(player, item) then
            local option = TC.addOption(context, getText("ContextMenu_TC_ReadNote"),
                                        playerNum, onReadNote, item)
            if not ok then
                option.notAvailable = true
                local tip = ISToolTip:new()
                tip:setName(getText("ContextMenu_TC_ReadNote"))
                tip.description = why
                option.toolTip = tip
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(addOptions)
