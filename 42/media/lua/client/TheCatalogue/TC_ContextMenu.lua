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

local function onBuy(playerNum, item)
    TC.openBuyWindow(playerNum, item)
end

local function onSell(playerNum, item)
    TC.openSellWindow(playerNum, item)
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
        -- Both entries sit at the top level rather than under a submenu. Two options
        -- is not enough to be worth an extra hover, and this is the item's purpose.
        --
        -- addOption returns the option table, and ISContextMenu draws option.iconTexture
        -- to the left of the label when one is set. Using the catalogue's own inventory
        -- texture ties the two entries to the item they came from, which matters on a
        -- right-click menu that may already be twenty entries long.
        local tex = catalogue:getTex()

        local buy = context:addOption(getText("ContextMenu_TC_Buy"), playerNum, onBuy, catalogue)
        if buy and tex then buy.iconTexture = tex end

        local sell = context:addOption(getText("ContextMenu_TC_Sell"), playerNum, onSell, catalogue)
        if sell and tex then sell.iconTexture = tex end
    end

    --[[ A keyboard-and-menu route into the sell box, offered only while the window
         is actually open. Drag and drop is the intended way in; this exists so that
         a controller, a joypad layout, or a drag that will not take still leaves the
         feature usable. ]]
    local sellWin = TC_SellWindow and TC_SellWindow.instances[playerNum]
    if sellWin then
        local real = allRealItems(items)

        if #real == 1 then
            context:addOption(getText("ContextMenu_TC_AddToSell"),
                              playerNum, onAddToSell, real)

        elseif #real > 1 then
            --[[ Dragging a stack always brings the whole stack, because that is what
                 the inventory pane puts in ISMouseDrag and nothing here can change it.
                 So the choice lives in this menu instead: one, or all of them. Without
                 it, selling a single ring out of a pile of nine means staging all nine
                 and then picking eight back out one at a time. ]]
            context:addOption(getText("ContextMenu_TC_AddOneToSell"),
                              playerNum, onAddToSell, { real[1] })
            context:addOption(getText("ContextMenu_TC_AddToSellMany", #real),
                              playerNum, onAddToSell, real)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(addOptions)
