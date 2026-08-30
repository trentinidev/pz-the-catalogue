--[[ The Catalogue -- selling the sofa without carrying it.

     A THIRD WORLD MENU, AND THE REASON IT IS SEPARATE. TC_ATMContextMenu answers a cash
     machine and TC_ComputerMenu answers a desk; this answers furniture, which is nearly
     every other tile in the game. Three sets of rules in three files, because the one
     thing they share is the event.

     WHY IT EXISTS AT ALL. Furniture can already be sold: pick it up and it is an item
     like any other. But a wardrobe weighs more than the largest delivery crate holds,
     and a house has a dozen pieces in it, so "sell your furniture" as a trip each is not
     a feature anybody would use twice. The entry here is the same sale, with the walk
     taken out of it.

     WHAT IT DOES NOT SKIP. The tool, the carpentry level and the seconds. It queues
     VANILLA's pickup action -- so a piece that needs a screwdriver still needs one, a
     piece above your level is still refused, and a double bed still comes up as one
     piece -- and only then takes the item and pays for it. The money is the shortcut;
     the work is not.
]]

require "Moveables/ISMoveableSpriteProps"
require "Moveables/ISMoveablesAction"

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Every distinct piece of furniture among the objects on a clicked square.

     Distinct by SPRITE, not by object: a wall lamp and the wall it hangs on are two
     objects, and a multi-tile counter reports itself once per tile. Offering the same
     sale three times over would be a menu bug and a double-sell waiting to happen.

     fromObject is asked rather than new(sprite) because only the object knows which of
     its sprites is the moveable one; the props it hands back carry the object with them,
     which is what canPickUpMoveable needs. ]]
local function moveablesOn(worldobjects)
    local found, seen = {}, {}

    for _, obj in ipairs(worldobjects) do
        local ok, props = pcall(function() return ISMoveableSpriteProps.fromObject(obj) end)

        if ok and props and props.isMoveable and props.spriteName and not seen[props.spriteName] then
            seen[props.spriteName] = true

            local square = obj:getSquare()
            if square then
                table.insert(found, { props = props, object = obj, square = square })
            end
        end
    end

    return found
end

--[[ Take it out of the room, then pay for it.

     walkToAndEquip is vanilla's own gate: it walks the character over and puts the right
     tool in their hands, and answers false when the piece cannot be taken at all. Only
     then does anything get queued, so a refusal leaves the room exactly as it was.

     The direction and the re-found object are copied from ISDisassembleMenu, which is
     the clearest example in the game's Lua of driving ISMoveablesAction from a context
     menu rather than from the moveable cursor. The nil in the last position is that
     cursor: pickup does not need one. ]]
local function onSell(worldobjects, playerNum, entry)
    local player = getSpecificPlayer(playerNum)
    if not player or not entry then return end

    local props, square = entry.props, entry.square
    if not square:getObjects():contains(entry.object) then return end

    if not props:walkToAndEquip(player, square, "pickup") then return end

    local direction = props:getFaceDirectionFromSpriteName(props.spriteName)
    local object    = props:findOnSquare(square, props.spriteName)

    -- The walk above takes time, and a zombie can put the wall through in it. Without
    -- this the action would be built around a nil object and ISMoveablesAction would
    -- read the sprite off nothing.
    if not object then return end

    ISTimedActionQueue.add(ISMoveablesAction:new(player, square, "pickup",
                                                 props.spriteName, object, direction,
                                                 nil, nil))
    ISTimedActionQueue.add(TC_SellFurnitureAction:new(player, props.spriteName,
                                                      props.name))
end

--[[ The two-phase test protocol every world-menu filler has to honour.

     Same shape as the cash machine's: the event fires once with test = true only to ask
     whether anything wants a place on this menu, and setTest() is how a mod says yes.
     Get it wrong and the whole menu is either suppressed or built twice. ]]
local function addOptions(playerNum, context, worldobjects, test)
    if test and ISWorldObjectContextMenu.Test then return true end

    local player = getSpecificPlayer(playerNum)
    if not player then return false end

    -- Not from the driver's seat. Vanilla makes the same check on every world option.
    if player:getVehicle() then return false end

    --[[ THE CATALOGUE HAS TO BE ON YOU, and this gate is doing more work than it looks.

         The obvious reading is thematic: you sell THROUGH the catalogue, so you need it
         to hand, exactly as the order window already requires.

         The real reason is the footprint. Ordinary house floors are moveables -- 129 of
         the pieces in the table are flooring -- so without this, every right-click on
         every square in Knox County grows a line from this mod, forever, whether or not
         the player has ever crafted a catalogue. A mod that changes what a right-click
         looks like everywhere is a mod other people uninstall.

         It is the same sandbox switch that governs the window, so a player who has
         turned the catalogue into a menu rather than an object gets the entries back
         everywhere, which is what they asked for. ]]
    if not TC.hasCatalogue(player) then return false end

    local found = moveablesOn(worldobjects)
    if #found == 0 then return false end

    if test then return ISWorldObjectContextMenu.setTest() end

    --[[ One entry per piece, priced on the label.

         The price is on the menu because this sale has no window to confirm it in. Every
         other way of selling something in this mod shows the money before the item is
         gone; a right-click that quietly turned a wardrobe into an unstated number of
         dollars would be the one exception, and it is the one that matters most. ]]
    local function addOne(menu, entry)
        local price = TC.furnitureSell(entry.props.spriteName, entry.props.customItem)
        local label = getText("ContextMenu_TC_SellFurniture", entry.props.name or "", price)

        local option = TC.addOption(menu, label, worldobjects, onSell, playerNum, entry)

        --[[ Greyed out rather than hidden when the piece cannot be taken.

             Hiding it would leave the player believing the catalogue does not buy
             wardrobes, when the truth is that this one is bolted down and they are
             missing the screwdriver. canPickUpMoveable is vanilla's own answer to that
             question, so the entry is grey in exactly the cases vanilla's own pickup
             would refuse. ]]
        local ok, allowed = pcall(function()
            return entry.props:canPickUpMoveable(player, entry.square, entry.object)
        end)

        if option and not (ok and allowed) then
            option.notAvailable = true
            local tip = ISToolTip:new()
            tip:setName(entry.props.name or "")
            tip.description = getText("IGUI_TC_CannotPickUp")
            option.toolTip = tip
        end
    end

    --[[ A submenu the moment there is more than one piece, and not before.

         A square in this game is rarely one thing. A rug, the table standing on it, the
         lamp on the wall behind and the poster beside the lamp are four moveables, and
         four more lines on a menu that vanilla has already filled is how a mod becomes
         the reason somebody cannot find "Open window". One line for one piece stays
         direct, because a submenu wrapping a single entry is just a second click. ]]
    if #found == 1 then
        addOne(context, found[1])
    else
        local option = TC.addOption(context, getText("ContextMenu_TC_SellFurnitureMany"),
                                    worldobjects, nil)
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(option, sub)

        for _, entry in ipairs(found) do addOne(sub, entry) end
    end

    return true
end

Events.OnFillWorldObjectContextMenu.Add(addOptions)
