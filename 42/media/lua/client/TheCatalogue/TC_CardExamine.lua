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

--[[ What was learned, said once and in the halo text rather than in a window.

     A window would be a whole UI for one sentence, and this is a sentence: the number, or
     the four digits it is made of. It also goes into the account, which is what the
     machine reads later -- the halo is the telling, the account is the remembering. ]]
function TC_ExamineCardAction:perform()
    local acct = TC.account(self.character, self.number)

    if acct then
        if acct.secret == "back" then
            TC.revealPin(acct)
            HaloTextHelper.addGoodText(self.character,
                getText("IGUI_TC_ExaminedBack", acct.pin))
        else
            TC.revealDigits(acct)
            HaloTextHelper.addGoodText(self.character,
                getText("IGUI_TC_ExaminedWorn", TC.pinDigits(acct)))
        end

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

    local ok, why = canRead(player)

    for _, item in ipairs(realItems(items)) do
        --[[ A card worth examining: one that has an account, and that has not already
             given up everything it has. A card whose PIN you know has nothing left to
             say, and the option disappearing is how the player is told that. ]]
        if TC.isCardItem(item) then
            local md   = item:getModData()
            local acct = md and md.TC_account and TC.account(player, md.TC_account)

            if acct and not TC.knowsPin(acct) then
                local known = TC.cardKnown(acct)
                local done  = known and known.examined and TC.knowsDigits(acct)

                if not done then
                    local option = context:addOption(getText("ContextMenu_TC_ExamineCard"),
                                                     playerNum, onExamine, item, acct.number)
                    if not ok then
                        option.notAvailable = true
                        local tip = ISToolTip:new()
                        tip:setName(getText("ContextMenu_TC_ExamineCard"))
                        tip.description = why
                        option.toolTip = tip
                    end
                end
            end

        elseif TC.noteAccount(player, item) then
            local option = context:addOption(getText("ContextMenu_TC_ReadNote"),
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
