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
--[[ A tooltip saying why an entry is greyed out.

     ISContextMenu draws option.toolTip when the option carries one, and a disabled entry
     with no explanation is worse than no entry at all -- the player is left guessing which
     of three requirements they are missing. ]]
local function tooltip(title, description)
    local tip = ISToolTip:new()
    tip:setName(title)
    tip.description = description
    return tip
end

local function onWire(worldobjects, playerNum, atm)
    local player = getSpecificPlayer(playerNum)
    if not player or not atm then return end

    local square = atm:getSquare()
    if square and luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_WireATMAction:new(player, atm))
    end
end

local function onForce(worldobjects, playerNum, atm)
    local player = getSpecificPlayer(playerNum)
    if not player or not atm then return end

    local square = atm:getSquare()
    if square and luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_ForceATMAction:new(player, atm))
    end
end

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
    local option = TC.addOption(context, getText("ContextMenu_TC_UseATM"),
                                worldobjects, onUse, playerNum, atm)

    --[[ A machine somebody has already forced open is a wrecked cabinet. It takes no
         cards and there is nothing left in it, so the only honest thing the menu can do is
         say so and offer nothing. ]]
    if TC.atmBroken(atm) then
        option.notAvailable = true
        option.toolTip = tooltip(getText("ContextMenu_TC_UseATM"),
                                 getText("IGUI_TC_ATMIsBroken"))
        return
    end

    --[[ The two ways past a PIN you do not have. Both go in a submenu: they are the
         uncommon answer, and a world menu in this game is twenty entries long before a mod
         touches it -- putting three top-level entries on every cash machine in the county
         would be the mod shouting. ]]
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(TC.addOption(context, getText("ContextMenu_TC_ATMTamper"),
                                    worldobjects, nil), sub)

    local wire = TC.addOption(sub, getText("ContextMenu_TC_WireATM"),
                              worldobjects, onWire, playerNum, atm)

    local level  = player:getPerkLevel(Perks.Electricity)
    local driver = TC.findScrewdriver(player)

    if TC.atmBypassed(atm) then
        wire.notAvailable = true
        wire.toolTip = tooltip(getText("ContextMenu_TC_WireATM"),
                               getText("IGUI_TC_ATMAlreadyWired"))
    elseif level < TC.ATM_ELEC_MIN or not driver then
        wire.notAvailable = true
        wire.toolTip = tooltip(getText("ContextMenu_TC_WireATM"),
                               getText("IGUI_TC_ATMWireNeeds", TC.ATM_ELEC_MIN))
    end

    local force = TC.addOption(sub, getText("ContextMenu_TC_ForceATM"),
                               worldobjects, onForce, playerNum, atm)

    if not TC.findPryBar(player) then
        force.notAvailable = true
        force.toolTip = tooltip(getText("ContextMenu_TC_ForceATM"),
                                getText("IGUI_TC_ATMForceNeeds"))
    else
        -- Said before the swing, not after: this destroys the machine for good, and the
        -- accounts you were going to use it for go with it.
        force.toolTip = tooltip(getText("ContextMenu_TC_ForceATM"),
                                getText("IGUI_TC_ATMForceWarn"))
    end
end

Events.OnFillWorldObjectContextMenu.Add(addOptions)
