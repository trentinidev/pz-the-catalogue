--[[ The Catalogue -- the right-click entry on a cash machine.

     A SECOND, SEPARATE MENU HOOK. TC_ContextMenu.lua fills the INVENTORY menu, which is
     the one that appears over an item you are carrying. This is the WORLD menu, the one
     that appears over a tile, and the two are different events with different arguments
     -- OnFillWorldObjectContextMenu hands over the objects on the square that was
     clicked. Keeping them in separate files is what stops the two sets of rules being
     read as one.

     ONE ENTRY, AND IT IS ALWAYS THE SAME ONE. Whether the player has an account, a card,
     both or neither is decided by the window when it opens, not out here: a right-click
     menu in this game is regularly twenty entries long before a mod adds anything, and
     branching this into "Open an account" / "Use cash machine" would put a mod's internal
     state on a menu the player is trying to read past. The same reasoning that reduced
     the catalogue's own three entries to one.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ The catalogue's own inventory icon, resolved once and remembered.

     Taken off the item SCRIPT rather than off an item instance, because there is no item
     here -- this menu is filled over a tile, and the player need not be carrying anything
     at all. getNormalTexture is what the arrival window uses for the same reason.

     A failed lookup is stored as FALSE rather than left nil, so it is asked once instead
     of once per right-click for the rest of the session. Same trick as TC.entryIcon. ]]
local icon
local function catalogueIcon()
    if icon == nil then
        local script = getScriptManager():FindItem(TC.ITEM_FULL)
        icon = (script and script:getNormalTexture()) or false
    end
    if icon == false then return nil end
    return icon
end

--[[ The first cash machine among the objects on a clicked square.

     Sprite name is the only handle there is -- see TC.ATM_SPRITES in TC_Config.lua for
     why the tile properties are no help, and for how the four vanilla sprites were
     identified. getSprite can be nil on some objects, so it is asked rather than assumed.
]]
local function findATM(worldobjects)
    for _, obj in ipairs(worldobjects) do
        local sprite = obj:getSprite()
        local name   = sprite and sprite:getName()
        if name and TC.isATMSprite(name) then return obj end
    end
    return nil
end

--[[ Walk there, then open. Never open from where the player is standing.

     luautils.walkAdj queues the walk and answers whether the square can be reached at
     all; false means there is no way to it -- through a window, across a fence -- and the
     right response is to do nothing rather than to open a window onto a machine the
     character cannot get to. keepActions is true so that the walk joins the queue instead
     of clearing whatever the player was already doing.

     TC_ATMAction is what turns "the walk was queued" into "the character has arrived". ]]
local function onUse(worldobjects, playerNum, atm)
    local player = getSpecificPlayer(playerNum)
    if not player or not atm then return end

    local square = atm:getSquare()
    if not square then return end

    if luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_ATMAction:new(player, atm))
    end
end

--[[ The two-phase test protocol every world-menu filler has to honour.

     ISWorldObjectContextMenu calls the event twice: once with test = true, purely to
     find out whether ANYTHING wants to add an option to this square, and again for real.
     Answering the first pass with setTest() is how a mod says yes; getting it wrong
     either suppresses the whole menu or builds it twice. Copied from vanilla's own
     ISFeedingTroughMenu, which is the clearest example of the pattern in the game's Lua.
]]
local function addOptions(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local player = getSpecificPlayer(playerNum)
    if not player then return false end

    -- Not from the driver's seat. Vanilla makes the same check on every world option.
    if player:getVehicle() then return false end

    local atm = findATM(worldobjects)
    if not atm then return false end

    if test then return ISWorldObjectContextMenu.setTest() end

    -- ISContextMenu draws option.iconTexture to the left of the label. The catalogue's
    -- own icon, the same one the inventory menu puts on Open Catalogue, so the two
    -- entries this mod adds anywhere in the game are recognisably the same mod's.
    local option = context:addOption(getText("ContextMenu_TC_UseATM"),
                                     worldobjects, onUse, playerNum, atm)

    local tex = catalogueIcon()
    if option and tex then option.iconTexture = tex end
end

Events.OnFillWorldObjectContextMenu.Add(addOptions)
