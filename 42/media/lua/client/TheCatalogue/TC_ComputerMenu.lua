--[[ The Catalogue -- the right-click entry on a desktop computer.

     The third menu hook, and the third kind of thing this mod attaches to: an item, a cash
     machine, and now a computer.

     A DESKTOP IS IDENTIFIED BY ITS PROPERTIES, NOT BY A LIST OF SPRITE NAMES. This is the
     opposite of TC.isATMSprite, and the difference is not inconsistency -- it is that the
     tiles differ. The four vanilla ATMs carry no CustomName and no GroupName, so a literal
     list of sprite names was the only handle there was. The desktops carry both:
     `CustomName = Computer` and `GroupName = Desktop` on appliances_com_01_72 through _75.

     Matching on the properties is better wherever the properties exist. It survives the
     tileset being renumbered, and it picks up _76 and _77 -- which are desktops whose
     CustomName is the literal string "CustomName", a typo in vanilla's own tile data that
     a hand-written list of the four documented sprites would have missed.

     WHAT THE OPTION NEEDS. The disc, and an account it can still reach. The catalogue
     itself is NOT wanted here: the whole point of burning a disc was to stop carrying the
     book. Being at the computer is what replaces it, and TC.catalogueStillOpen enforces
     that for as long as the window is open.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local DISC_ITEM = "Catalogue.OnlineCatalogue"

--[[ Is this object a desktop computer?

     Properties are read through a pcall because getProperties is a Java call on an object
     that need not have a sprite at all, and a right-click menu is the last place that
     should be allowed to throw -- as this mod found out with ItemTag. ]]
local function isComputer(obj)
    local ok, yes = pcall(function()
        local sprite = obj:getSprite()
        if not sprite then return false end

        local props = sprite:getProperties()
        if not props then return false end

        if props:Val("CustomName") == "Computer" then return true end
        return props:Val("GroupName") == "Desktop"
    end)

    return ok and yes == true
end

local function findComputer(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if isComputer(obj) then return obj end
    end
    return nil
end

--[[ The disc on the player, and the account it was burned against.

     Returns the item and the account, or nil and a reason. The account is looked up
     through TC.account rather than trusted off the disc, because a disc is a piece of
     plastic with a number written on it and the account it names may since have gone --
     another character's save, or a card lost with the balance behind it. ]]
local function findDisc(player)
    local inv = player:getInventory()
    if not inv then return nil end

    local list = inv:getAllTypeRecurse("OnlineCatalogue")
    if (not list or list:size() == 0) then
        list = inv:getAllTypeRecurse(DISC_ITEM)
    end
    if not list or list:size() == 0 then return nil end

    for i = 0, list:size() - 1 do
        local disc = list:get(i)
        local md   = disc:getModData()
        local acct = md and md.TC_account and TC.account(player, md.TC_account)
        if acct then return disc, acct end
    end

    -- A disc exists but names nothing this character can reach.
    return list:get(0), nil
end

--[[ The account a usable disc on this player names, or nil.

     Public because the timed action re-asks it a second and a half after the menu did --
     see TC_ComputerAction. One function, two callers, no chance of the menu and the action
     disagreeing about whether a session may start. ]]
function TC.discAccount(player)
    if not player then return nil end
    local _, acct = findDisc(player)
    return acct and acct.number or nil
end

local function onOpen(worldobjects, playerNum, computer)
    local player = getSpecificPlayer(playerNum)
    if not player or not computer then return end

    local square = computer:getSquare()
    if square and luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_UseComputerAction:new(player, computer))
    end
end

local function addOptions(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    if player:getVehicle() then return false end

    local computer = findComputer(worldobjects)
    if not computer then return false end

    -- No disc, no entry. Every computer in Knox County would otherwise carry a line about
    -- a mod the player has no way to use yet, on a menu that is already long.
    local disc, acct = findDisc(player)
    if not disc then return false end

    if test then return ISWorldObjectContextMenu.setTest() end

    local option = TC.addOption(context, getText("ContextMenu_TC_OnlineCatalogue"),
                                worldobjects, onOpen, playerNum, computer)

    if not acct then
        option.notAvailable = true
        local tip = ISToolTip:new()
        tip:setName(getText("ContextMenu_TC_OnlineCatalogue"))
        tip.description = getText("IGUI_TC_OnlineNoAccount")
        option.toolTip = tip
    end
end

Events.OnFillWorldObjectContextMenu.Add(addOptions)

--[[ The disc has to be stamped with an account when it is burned, and a craftRecipe cannot
     do that on its own. This is the same trick TC.issueCard plays on a credit card: the
     item is vanilla-shaped, and the modData is what makes it ours.

     THE ACCOUNT IS CHOSEN AT BURN TIME, not at use time, and it is the oldest card on the
     player. A disc names one account for good, which is what makes burning a second disc a
     real decision rather than a formality -- and TC.cardsOnPlayer already sorts oldest
     first, so "the account you have had longest" is what falls out without a screen asking.

     Called from an OnCreate hook on the recipe rather than from Lua at the crafting UI,
     because the recipe is what knows an item was just made. ]]
function TC.stampDisc(items, result, player)
    if not result or not player then return end

    local cards = TC.cardsOnPlayer(player)
    if #cards == 0 then
        TC.warn("burned a disc with no card on the player -- it will name no account")
        return
    end

    local acct = cards[1].account
    local md = result:getModData()
    md.TC_account = acct.number

    result:setName(getText("IGUI_TC_OnlineDiscName", TC.cardTail(acct.number)))
    result:setCustomName(true)
    result:syncItemFields()
end
