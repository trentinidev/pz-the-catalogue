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

    -- appliances_com_01_76 and _77 are desktops whose CustomName is the literal string
    -- "CustomName" -- a typo in vanilla's own tile data. GroupName is what catches them.
    return props:has("GroupName") and props:get("GroupName") == "Desktop"
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
    local discs = TC.discItemsOn(player)
    if #discs == 0 then return nil end

    for _, disc in ipairs(discs) do
        -- Stamps a blank one on the way past, which is what makes a disc burned before
        -- this version -- or burned while carrying no card -- start working.
        TC.stampDisc(player, disc)

        local md   = disc:getModData()
        local acct = md and md.TC_account and TC.account(player, md.TC_account)
        if acct then return disc, acct end
    end

    -- A disc exists but names nothing this character can reach: no card on them to stamp
    -- it with, or the account behind it has gone out of reach.
    return discs[1], nil
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

--[[ Stamp a burned disc with the account it bills, and put that on its name.

     LAZILY, THE WAY EVERY OTHER ITEM IN THIS MOD IS STAMPED. The first version hung this
     off `OnCreate` on the craftRecipe, which is how vanilla does it -- and vanilla's
     handlers are reached through `luaCallOnCreate`, whose Lua-side argument list is not
     something this mod can confirm without shipping a build to find out. The disc came out
     of the recipe named "Online Catalogue" with no account on it and no error to say why.

     Naming on first sight has no such problem. It is the same shape as TC.blessCard and
     TC.nameCard: the mod stamps what it finds, once, and the string compare in front of
     the rename means seeing it again costs nothing. It also fixes discs already burned by
     0.7.0-beta, which an OnCreate hook could never have reached.

     THE ACCOUNT IS THE OLDEST CARD ON THE PLAYER. A disc names one account for good, which
     is what makes burning a second one a real decision -- and TC.cardsOnPlayer already
     sorts oldest first, so "the account you have had longest" falls out without a screen
     asking. A disc burned with no card on the player stays blank and is stamped the next
     time the player is carrying one. ]]
function TC.stampDisc(player, disc)
    if not player or not disc then return false end

    local md = disc:getModData()
    if not md then return false end

    -- Already stamped with an account that still exists: leave the number alone and only
    -- make sure the name matches it.
    local acct = md.TC_account and TC.account(player, md.TC_account)

    if not acct then
        local cards = TC.cardsOnPlayer(player)
        if #cards == 0 then return false end

        acct = cards[1].account
        md.TC_account = acct.number
    end

    local want = getText("IGUI_TC_OnlineDiscName", TC.cardTail(acct.number))
    if disc:getName() == want then return false end

    disc:setName(want)
    disc:setCustomName(true)
    disc:syncItemFields()
    return true
end

--[[ Every burned disc on the player, of either spelling. The same reason TC.cardItemsOn
     exists: getAllTypeRecurse answers on the short name in some builds and the prefixed
     one in others, and this mod has guessed wrong about that twice now. ]]
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
