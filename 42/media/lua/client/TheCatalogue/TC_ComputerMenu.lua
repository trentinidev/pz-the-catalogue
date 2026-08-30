--[[ The Catalogue -- the right-click entries on a desktop computer.

     The third menu hook, and the third kind of thing this mod attaches to: an item, a cash
     machine, and now a computer.

     THE DISC IS INSTALLED INTO THE MACHINE, NOT CARRIED. It goes in once, it is consumed,
     and from then on that computer runs the catalogue for ANYBODY who sits at it -- billed
     to whatever card THEY are carrying. The disc knows nothing about any account.

     This replaced the opposite arrangement, where the disc was stamped with the account of
     the person who burned it and had to be in their bag to work. That made the disc a
     second credit card: a personal token, tied to one balance, useless to anybody else.
     Software is not a credit card. Installing it makes the computer the thing that matters
     -- a place in the world you set up once and come back to, the same shape a wired ATM
     has -- and it is the only version of this that means anything with more than one
     player.

     A DESKTOP IS IDENTIFIED BY ITS TILE PROPERTIES, which is the opposite of the ATMs and
     is not an inconsistency: the four vanilla ATMs carry no CustomName and no GroupName, so
     a literal list of sprite names was the only handle there was. Desktops carry both.
     Matching properties survives a renumbered tileset and picks up appliances_com_01_76 and
     _77, whose CustomName is the literal string "CustomName" -- a typo in vanilla's own
     tile data that a list of the four documented sprites would have missed.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local DISC_ITEM = "Catalogue.OnlineCatalogue"

--[[ Is this object a desktop computer?

     ASK WHAT IT HAS, NEVER TRY AND CATCH. The first version called `props:Val(...)` inside
     a pcall, on the assumption that wrapping it made a wrong guess safe. It did not, twice
     over: `Val` is not a method on PropertyContainer -- it is `has` and `get`, which is
     what vanilla's own Lua uses -- so every right-click on a tile with properties threw,
     and the pcall CAUGHT the error while the engine still wrote it to the log. Fourteen
     stack traces from a menu that silently added nothing.

     That is the lesson already written down in CLAUDE.md about pcall-ing a getter, arrived
     at again from a new direction. Asking `has` before `get` is both correct and cheaper
     than an exception. ]]
local function isComputer(obj)
    local props = obj:getProperties()
    if not props then return false end

    if props:has("CustomName") and props:get("CustomName") == "Computer" then
        return true
    end

    return props:has("GroupName") and props:get("GroupName") == "Desktop"
end

local function findComputer(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if isComputer(obj) then return obj end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- What is installed on which machine
-- ---------------------------------------------------------------------------

--[[ Keyed by square, and stored in the world register beside the stranger's accounts and
     the wired ATMs.

     A tile IS its coordinates; an IsoObject reference does not survive the chunk being
     unloaded and streamed back in, which for a computer in a house the player has left is
     the normal case rather than the exception. ]]
local function computerKey(pc)
    local square = pc and pc:getSquare()
    if not square then return nil end
    return string.format("%d,%d,%d", square:getX(), square:getY(), square:getZ())
end

local function installs()
    local world = TC.worldBank()
    if type(world.pcs) ~= "table" then world.pcs = {} end
    return world.pcs
end

function TC.catalogueInstalled(pc)
    local key = computerKey(pc)
    if not key then return false end
    return installs()[key] == true
end

function TC.installCatalogue(pc)
    local key = computerKey(pc)
    if not key then return false end

    installs()[key] = true
    return true
end

-- ---------------------------------------------------------------------------
-- The disc, as an item and nothing more
-- ---------------------------------------------------------------------------

--[[ Every burned disc on the player, of either spelling.

     The same reason TC.cardItemsOn exists: getAllTypeRecurse answers on the short name in
     some builds and the module-prefixed one in others, and this mod has guessed wrong
     about that twice. Asking for both is the end of it. ]]
function TC.discItemsOn(player)
    local out = {}
    if not player then return out end

    local inv = player:getInventory()
    if not inv then return out end

    local seen = {}
    for _, t in ipairs({ "OnlineCatalogue", DISC_ITEM }) do
        local list = inv:getAllTypeRecurse(t)
        if list then
            for i = 0, list:size() - 1 do
                local item = list:get(i)
                if item and not seen[item] then
                    seen[item] = true
                    table.insert(out, item)
                end
            end
        end
    end

    return out
end

-- ---------------------------------------------------------------------------
-- The menu
-- ---------------------------------------------------------------------------

local function tooltip(title, description)
    local tip = ISToolTip:new()
    tip:setName(title)
    tip.description = description
    return tip
end

local function onInstall(worldobjects, playerNum, pc)
    local player = getSpecificPlayer(playerNum)
    if not player or not pc then return end

    local square = pc:getSquare()
    if square and luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_InstallCatalogueAction:new(player, pc))
    end
end

--[[ `account` is chosen in the MENU rather than by the window, because the choice is
     between cards the player is carrying and the menu is already listing them. The ATM
     needs a whole screen for this; here a submenu says the same thing in one click less. ]]
local function onOpen(worldobjects, playerNum, pc, account)
    local player = getSpecificPlayer(playerNum)
    if not player or not pc then return end

    local square = pc:getSquare()
    if square and luautils.walkAdj(player, square, true) then
        ISTimedActionQueue.add(TC_UseComputerAction:new(player, pc, account))
    end
end

--[[ How the player will pay, offered as one entry or as a list of them.

     ONE CARD IS NOT A QUESTION. Asking "which card?" of somebody holding one is a question
     with one answer and a click to give it, so the single case is a plain entry and the
     submenu only appears when there is a real choice -- the same rule the cash machine's
     chooser follows.

     NO CARD MEANS NO ENTRY THAT WORKS. The catalogue on a screen bills an account, and a
     player with no card on them has no account within reach. Greyed out and told why beats
     opening a catalogue that cannot buy anything. ]]
local function addPaymentEntries(context, playerNum, player, pc)
    local cards = TC.cardsOnPlayer(player)

    if #cards == 0 then
        local option = TC.addOption(context, getText("ContextMenu_TC_OnlineCatalogue"),
                                    nil, nil)
        option.notAvailable = true
        option.toolTip = tooltip(getText("ContextMenu_TC_OnlineCatalogue"),
                                 getText("IGUI_TC_OnlineNeedsCard"))
        return
    end

    if #cards == 1 then
        TC.addOption(context, getText("ContextMenu_TC_OnlineCatalogue"),
                     nil, onOpen, playerNum, pc, cards[1].account.number)
        return
    end

    local parent = TC.addOption(context, getText("ContextMenu_TC_OnlineCatalogue"), nil, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)

    for _, card in ipairs(cards) do
        local acct = card.account
        TC.addOption(sub, getText("IGUI_TC_OnlineBillTo", TC.cardTail(acct.number)),
                     nil, onOpen, playerNum, pc, acct.number)
    end
end

local function addOptions(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local player = getSpecificPlayer(playerNum)
    if not player then return false end
    if player:getVehicle() then return false end

    local pc = findComputer(worldobjects)
    if not pc then return false end

    local installed = TC.catalogueInstalled(pc)
    local discs     = TC.discItemsOn(player)

    --[[ Nothing to say about a computer with no catalogue on it and no disc in the
         player's bag. Every desktop in Knox County would otherwise carry a line about a
         feature the player cannot use yet, on a menu that is already twenty entries long. ]]
    if not installed and #discs == 0 then return false end

    if test then return ISWorldObjectContextMenu.setTest() end

    if not installed then
        TC.addOption(context, getText("ContextMenu_TC_InstallCatalogue"),
                     worldobjects, onInstall, playerNum, pc)
        return
    end

    addPaymentEntries(context, playerNum, player, pc)
end

Events.OnFillWorldObjectContextMenu.Add(addOptions)
