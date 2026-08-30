--[[ The Catalogue -- the right-click entries on the catalogue item. ]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ The context menu hands us a mixed list: real InventoryItems for single items,
     and a plain table with an .items array for a stack the inventory pane has
     grouped together. Unwrap to the first real item either way. ]]
local function firstCatalogue(items)
    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            if v:getFullType() == TC.ITEM_FULL then return v end
        elseif v.items then
            for _, it in ipairs(v.items) do
                if it:getFullType() == TC.ITEM_FULL then return it end
            end
        end
    end
    return nil
end

--[[ One entry, and it lands on Buy.

     There used to be three -- Buy, Sell, Ledger -- and they were three because that is
     how the windows are built, not because the player thinks in threes. A right-click
     menu in this game is regularly twenty entries long before a mod adds anything, and
     three of them competing for the same glance is worse than one that always works.

     Buy is the landing pane because it is the one you want nine times out of ten, and
     because the rail down its right edge reaches the other three in a click. ]]
local function onOpen(playerNum, item)
    TC.openBuyWindow(playerNum, item)
end

local function onCollect(playerNum, item)
    TC.openArrivalWindow(playerNum)
end

--[[ Every real item in the right-clicked selection, stacks flattened. ]]
local function allRealItems(items)
    local out = {}
    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            table.insert(out, v)
        elseif v.items then
            -- The first entry of a grouped stack is a dummy duplicate of the second,
            -- exactly as ISInventoryPane.getActualItems documents. Skip it.
            for i = 2, #v.items do table.insert(out, v.items[i]) end
        end
    end
    return out
end

local function onAddToSell(playerNum, items)
    local win = TC_SellWindow and TC_SellWindow.instances[playerNum]
    if win then win:stageItems(items) end
end

local function addOptions(playerNum, context, items)
    local catalogue = firstCatalogue(items)

    if catalogue then
        -- Through TC.addOption, which hangs the catalogue's icon off every entry. It used
        -- to read the texture off THIS item -- correct here, and unavailable in the five
        -- other menus this mod fills, where there is no catalogue in the player's hands to
        -- read it from. One helper, one picture, eleven entries.
        TC.addOption(context, getText("ContextMenu_TC_Open"), playerNum, onOpen, catalogue)

        --[[ Only while something is actually standing at the door. Closing the arrival
             window is not refusing the delivery, so there has to be a way back to it --
             but an entry that is always there and usually does nothing is clutter on a
             menu that is already long. ]]
        local waiting = TC.arrivedCount(getSpecificPlayer(playerNum))
        if waiting > 0 then
            TC.addOption(context, getText("ContextMenu_TC_Collect", waiting),
                         playerNum, onCollect, catalogue)
        end
    end

    --[[ A keyboard-and-menu route into the sell box, offered only while the window
         is actually open. Drag and drop is the intended way in; this exists so that
         a controller, a joypad layout, or a drag that will not take still leaves the
         feature usable. ]]
    local sellWin = TC_SellWindow and TC_SellWindow.instances[playerNum]
    if sellWin then
        local real = allRealItems(items)

        if #real == 1 then
            TC.addOption(context, getText("ContextMenu_TC_AddToSell"),
                         playerNum, onAddToSell, real)

        elseif #real > 1 then
            --[[ Dragging a stack always brings the whole stack, because that is what
                 the inventory pane puts in ISMouseDrag and nothing here can change it.
                 So the choice lives in this menu instead: one, or all of them. Without
                 it, selling a single ring out of a pile of nine means staging all nine
                 and then picking eight back out one at a time. ]]
            TC.addOption(context, getText("ContextMenu_TC_AddOneToSell"),
                         playerNum, onAddToSell, { real[1] })
            TC.addOption(context, getText("ContextMenu_TC_AddToSellMany", #real),
                         playerNum, onAddToSell, real)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(addOptions)
