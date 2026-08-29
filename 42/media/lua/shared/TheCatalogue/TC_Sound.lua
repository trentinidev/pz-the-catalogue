--[[ The Catalogue -- what trading sounds like.

     Two different things happen when you buy something here, a few seconds apart, and
     they should not sound the same.

     FIRST THE PAPERWORK. Placing an order is filling in a form: the catalogue opens,
     you leaf through it, you write the line down. That is what the timed action is
     modelling, so it gets the literature sounds -- open, a page flip partway through,
     a pen at the end. Cancel it and the book shuts.

     THEN THE MONEY. Cash changing hands is one instant, not a few seconds, and it is
     the moment the transaction is real. It gets the register.

     Every name below is a vanilla sound script, so nothing ships with the mod and
     nothing can go missing on a build that has them: OpenMagazine, PageFlipMagazine
     and CloseBook are Character/Survival/Literature, MapAddNote is the pen the map
     screen uses to write a label, and the register is the one on shop counters.

     playSound rather than PlayWorldSound: these belong to the character, so they should
     follow them and be positioned on them, which is what ISReadABook and ISWriteSomething
     do with the same clips.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC.SOUNDS = {
    orderOpen   = "OpenMagazine",        -- the catalogue comes out
    orderFlip   = "PageFlipMagazine",    -- leafing to the right page
    orderSign   = "MapAddNote",          -- the pen: the order is written down
    orderCancel = "CloseBook",           -- interrupted, the book shuts
    cash        = "CashRegisterTransferItem",

    --[[ The cash machine, opening and closing. Both are vanilla shop-counter clips, and
         they are the register's drawer rather than anything electronic, which is as close
         as this game gets to the noise an ATM makes.

         THERE IS DELIBERATELY NO KEYPAD BEEP. Every short beep in the game belongs to
         something that is announcing itself -- an alarm clock, a house alarm, a stove
         timer, a reversing van -- and none of them is a clip that can be fired twelve
         times while somebody types a PIN. A named sound that does not exist is not an
         error either: playSound simply plays nothing, so a wrong guess here would be
         silent rather than wrong, and silent is what it already is. ]]
    atmOpen     = "CashRegisterOpen",
    atmClose    = "CashRegisterClose",
}

--[[ Play one of the above, by intent rather than by clip name.

     Wrapped for two reasons. Call sites say what is happening ("the order was signed")
     instead of naming a clip, so changing the clip is one edit here; and a nil player
     or an unknown name is shrugged off rather than thrown, because no sale should ever
     fail over a sound.
]]
function TC.playSound(player, intent)
    if not player then return end
    local name = TC.SOUNDS[intent]
    if not name then
        TC.warn("no sound registered for intent %s", tostring(intent))
        return
    end
    player:playSound(name)
end
