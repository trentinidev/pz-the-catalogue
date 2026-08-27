--[[ The Catalogue -- the sell window.

     WHY ITEMS DO NOT ACTUALLY MOVE. The original design was a real ItemContainer with
     an enormous capacity, which the player fills and then sells. ItemContainer.new()
     works fine from Lua -- the game builds the floor container that way -- but a
     container created in Lua and attached to no IsoObject IS NEVER SAVED, and the
     game exposes no OnSave or OnQuit event to Lua to empty it on the way out. Vanilla
     has exactly one save-lifecycle hook, OnPlayerDeath. Anyone who alt-F4s or quits
     to the menu with a full sell box would lose every item in it, silently.

     So nothing moves. Items are STAGED: the window holds references to items that are
     still sitting in whatever container they came from, shows what each is worth, and
     only removes them at the moment the sale is confirmed. Closing the window, dying,
     crashing or quitting all cost nothing, because there is nothing to give back.

     The one thing this gives up is weight relief -- staged loot still weighs on the
     player until it sells. Everything else about the described behaviour is intact,
     including unlimited capacity: you can stage as much as you can reach.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)

local PAD        = 14
local ROW_HGT    = 34
local ICON       = 26
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12
local FOOTER_HGT = FONT_HGT_LARGE + FONT_HGT_SMALL + PAD * 2

-- Same reasoning as the buy window: the top edge is framed by the visible title bar,
-- the bottom edge is not, so an identical PAD reads as cramped down there.
local BOTTOM_PAD = PAD * 2

-- ---------------------------------------------------------------------------
-- The staged list
-- ---------------------------------------------------------------------------

TC_SellList = ISScrollingListBox:derive("TC_SellList")

-- Same culling reason as the buy list: the base class draws every row every frame.
function TC_SellList:doDrawItem(y, item, alt)
    local scroll = self:getYScroll()
    if y + ROW_HGT + scroll < 0 or y + scroll > self.height then
        return y + ROW_HGT
    end

    -- item.item is a ROW record built by rebuildRows, not the InventoryItem itself.
    -- Name, condition and value were computed there; drawing only reads them back.
    local row = item.item
    local it  = row.item
    local c   = TC.columns(self.width, self.parentWindow and self.parentWindow.colW or nil)

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end
    self:drawRect(0, y + ROW_HGT - 1, self:getWidth(), 1, 0.25, 1, 1, 1)
    TC.drawColumnRules(self, c, 0, y, ROW_HGT - 1, 0.22)

    if row.tex == nil then row.tex = it:getTex() or false end
    if row.tex then
        self:drawTextureScaledAspect(row.tex, TC.UI.CELL_PAD, y + (ROW_HGT - ICON) / 2,
                                     ICON, ICON, 1, 1, 1, 1)
    end

    local textY  = y + (ROW_HGT - FONT_HGT_MEDIUM) / 2
    local smallY = y + (ROW_HGT - FONT_HGT_SMALL) / 2

    self:drawText(TC.truncate(UIFont.Medium, row.name, c.nameW),
                  c.nameLeft, textY, 1, 1, 1, 1, UIFont.Medium)

    -- Condition, but only when the item actually models wear. Printing "100%" beside
    -- a nail is noise; the absence of a figure is itself the information.
    if row.ratio < 0.999 then
        local pct = string.format("%d%%", math.floor(row.ratio * 100 + 0.5))
        -- Colour carries the warning: green is fine, amber is worn, red is nearly spent.
        local r, g, b = 0.55, 0.9, 0.55
        if row.ratio < 0.3 then r, g, b = 0.95, 0.45, 0.4
        elseif row.ratio < 0.7 then r, g, b = 0.95, 0.82, 0.45 end
        TC.drawRight(self, pct, c.midRight, smallY, UIFont.Small, r, g, b)
    end

    if row.value then
        TC.drawRight(self, "$" .. row.value, c.priceRight, textY, UIFont.Medium, 0.78, 0.96, 0.78)
    else
        TC.drawRight(self, getText("IGUI_TC_NoValue"), c.priceRight, smallY,
                     UIFont.Small, 0.7, 0.45, 0.45)
    end

    return y + ROW_HGT
end

--[[ The drop target. ISMouseDrag.dragging holds whatever the inventory pane picked
     up; getActualItems flattens grouped stacks into real InventoryItems, and skips
     the dummy duplicate that leads each group. ]]
function TC_SellList:onMouseUp(x, y)
    if ISMouseDrag.dragging ~= nil and ISMouseDrag.draggingFocus ~= self then
        local dropped = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
        if dropped and #dropped > 0 then
            self.parentWindow:stageItems(dropped)
            ISMouseDrag.dragging = nil
            return
        end
    end
    ISScrollingListBox.onMouseUp(self, x, y)
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

TC_SellWindow = ISCollapsableWindow:derive("TC_SellWindow")
TC_SellWindow.instances = TC_SellWindow.instances or {}

function TC_SellWindow:new(x, y, w, h, playerNum)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o.staged = {}
    o.message = nil
    o.messageIsError = false
    o.colW = TC.defaultColumnWidths("sell")   -- per window, so drags do not leak across
    o.dragCol = nil
    o.sortKey = "name"                       -- name | mid (condition) | price (value)
    o.sortAsc = true
    o:setResizable(true)
    o.minimumWidth = 640
    o.minimumHeight = 460
    return o
end

function TC_SellWindow:listGeometry()
    local listY = self:titleBarHeight() + PAD + HEADER_HGT
    local listH = self.height - listY - FOOTER_HGT - BUTTON_HGT - PAD - BOTTOM_PAD
    return listY, listH
end

function TC_SellWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local listY, listH = self:listGeometry()

    self.list = TC_SellList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.parentWindow = self
    self.list.target = self
    self:addChild(self.list)

    local by    = self.height - BOTTOM_PAD - BUTTON_HGT
    local third = (self.width - PAD * 4) / 3

    self.removeBtn = ISButton:new(PAD, by, third, BUTTON_HGT,
                                  getText("IGUI_TC_RemoveSelected"), self, TC_SellWindow.onRemoveSelected)
    self.removeBtn:initialise(); self.removeBtn:instantiate()
    self:addChild(self.removeBtn)

    self.clearBtn = ISButton:new(PAD * 2 + third, by, third, BUTTON_HGT,
                                 getText("IGUI_TC_ClearAll"), self, TC_SellWindow.onClearAll)
    self.clearBtn:initialise(); self.clearBtn:instantiate()
    self:addChild(self.clearBtn)

    self.sellBtn = ISButton:new(PAD * 3 + third * 2, by, third, BUTTON_HGT,
                                getText("IGUI_TC_Sell"), self, TC_SellWindow.onSell)
    self.sellBtn:initialise(); self.sellBtn:instantiate()
    self:addChild(self.sellBtn)
end

-- ---------------------------------------------------------------------------
-- Staging
-- ---------------------------------------------------------------------------

local function isStaged(self, item)
    for _, it in ipairs(self.staged) do
        if it == item then return true end
    end
    return false
end

--[[ Is this item sitting inside something already staged?

     It matters because selling a bag sells its contents with it (see
     TC.getSellValue). If both the bag and a book inside it were staged, the book
     would be counted twice and then removed twice. Walking up the container chain
     catches that before it can happen.
]]
local function isInsideStaged(self, item)
    local ok, container = pcall(function() return item:getContainer() end)
    local guard = 0
    while ok and container and guard < 8 do
        local okp, parent = pcall(function() return container:getContainingItem() end)
        if not okp or not parent then return false end
        if isStaged(self, parent) then return true end
        ok, container = pcall(function() return parent:getContainer() end)
        guard = guard + 1
    end
    return false
end

--[[ Is the player holding or wearing this right now?

     Lifted from ISUnequipAction, which is the game's own answer to the same question:
     an item is in use if it is in either hand or in the worn-items list. There is no
     single isEquipped on IsoPlayer that covers all three.
]]
local function isInUse(player, item)
    if not player then return false end
    if player:getPrimaryHandItem() == item then return true end
    if player:getSecondaryHandItem() == item then return true end
    local ok, worn = pcall(function() return player:getWornItems() end)
    if ok and worn and worn:contains(item) then return true end
    return false
end

--[[ Reasons an item is refused, in the order a player would expect to hear them. ]]
function TC_SellWindow:canStage(item)
    if item:getFullType() == TC.ITEM_FULL then
        return false, getText("IGUI_TC_RefuseCatalogue")
    end

    local okFav, fav = pcall(function() return item:isFavorite() end)
    if okFav and fav then
        return false, getText("IGUI_TC_RefuseFavorite")
    end

    if isInUse(self.player, item) then
        return false, getText("IGUI_TC_RefuseEquipped")
    end

    local value, reason = TC.getSellPriceRounded(item)
    if not value then
        if reason == "condition" then return false, getText("IGUI_TC_RefuseCondition") end
        return false, getText("IGUI_TC_RefuseNotListed")
    end

    if not TC.opt("SellContainerContents") then
        local okInv, inv = pcall(function() return item:getInventory() end)
        if okInv and inv and inv:getItems():size() > 0 then
            return false, getText("IGUI_TC_RefuseNotEmpty")
        end
    end

    return true
end

function TC_SellWindow:stageItems(items)
    local added, refused, lastReason = 0, 0, nil

    for _, item in ipairs(items) do
        if isStaged(self, item) or isInsideStaged(self, item) then
            -- Already accounted for; not an error worth reporting.
        else
            local ok, reason = self:canStage(item)
            if ok then
                table.insert(self.staged, item)
                added = added + 1
            else
                refused = refused + 1
                lastReason = reason
            end
        end
    end

    self:refreshList()

    -- If the prune threw anything out during that refresh, its warning is the more
    -- important message and must not be overwritten by a success line.
    if self.prunedLast then return end

    if added > 0 and refused == 0 then
        self:setMessage(getText("IGUI_TC_Staged", added), false)
    elseif added > 0 then
        self:setMessage(getText("IGUI_TC_StagedSomeRefused", added, refused), false)
    elseif lastReason then
        self:setMessage(lastReason, true)
    end
end

--[[ Drop anything that has left the world behind our back -- eaten, dropped on the
     floor, moved into a container we can no longer see. Called before every render
     path that reads self.staged, so a stale reference never reaches the sale. ]]
--[[ Every container the player can reach right now.

     The two inventory pages -- their own inventory, and the loot side -- each keep a
     `backpacks` list of the containers currently on offer, which is precisely the
     game's own answer to "what can this player touch from where they are standing". A
     briefcase inside a vehicle boot is in that list the moment both are open, which is
     the case that matters here.

     Rebuilt per check rather than cached: the player opens and closes containers
     constantly, and the list is a handful of entries. ]]
local function collectBackpacks(page, set)
    if not page then return end
    if page.inventory then set[page.inventory] = true end

    -- Vanilla reaches this list two different ways -- page.backpacks directly, and
    -- page.inventoryPane.inventoryPage.backpacks, which loops back to the same page.
    -- Both are read here rather than betting on which one is the intended path.
    local lists = { page.backpacks }
    if page.inventoryPane and page.inventoryPane.inventoryPage then
        table.insert(lists, page.inventoryPane.inventoryPage.backpacks)
    end

    for _, list in ipairs(lists) do
        if list then
            for _, cb in ipairs(list) do
                if cb.inventory then set[cb.inventory] = true end
            end
        end
    end
end

local function reachableInventories(playerNum)
    local set = {}
    collectBackpacks(getPlayerInventory(playerNum), set)
    collectBackpacks(getPlayerLoot(playerNum), set)
    return set
end

--[[ Is this item somewhere the player could actually hand it over?

     Having a container is not enough on its own: a dropped item, or one left in a
     crate three rooms away, keeps a perfectly valid container indefinitely, and the
     sale would go through from across the map.

     But requiring the player's OWN inventory was too strict and broke selling out of
     any open container -- items staged from a boot or a crate were added and then
     pruned on the same frame, which read as the drag doing nothing at all. Anything in
     a container the player currently has open counts, at any nesting depth. ]]
local function isReachable(player, playerNum, item)
    local ok, container = pcall(function() return item:getContainer() end)
    if not ok or not container then return false end

    if container == player:getInventory() then return true end

    local reachable = reachableInventories(playerNum)
    if reachable[container] then return true end

    local okOut, outer = pcall(function() return container:getOutermostContainer() end)
    return okOut and outer ~= nil and reachable[outer] == true
end

function TC_SellWindow:pruneStaged()
    local kept = {}
    for _, item in ipairs(self.staged) do
        if isReachable(self.player, self.playerNum, item) then
            table.insert(kept, item)
        end
    end
    if #kept ~= #self.staged then
        local dropped = #self.staged - #kept
        self.staged = kept
        self:setMessage(getText("IGUI_TC_DroppedUnreachable", dropped), true)
        return true
    end
    return false
end

--[[ Comparator for the active sort.

     Sorts a COPY, never self.staged itself: the staged array is the record of what
     will be sold and in what order it will be removed, and reordering it to suit the
     display would quietly reorder the sale.
]]
function TC_SellWindow:sortedStaged()
    local out = {}
    for _, item in ipairs(self.staged) do table.insert(out, item) end

    local asc, key = self.sortAsc, self.sortKey

    table.sort(out, function(a, b)
        local an, bn = a:getDisplayName(), b:getDisplayName()

        if key == "mid" then
            local ac, bc = TC.conditionRatio(a), TC.conditionRatio(b)
            if ac ~= bc then
                if asc then return ac < bc end
                return ac > bc
            end
            return an < bn
        end

        if key == "price" then
            local av = TC.getSellPriceRounded(a) or 0
            local bv = TC.getSellPriceRounded(b) or 0
            if av ~= bv then
                if asc then return av < bv end
                return av > bv
            end
            return an < bn
        end

        if an ~= bn then
            if asc then return an < bn end
            return an > bn
        end
        return a:getFullType() < b:getFullType()
    end)

    return out
end

--[[ Rebuild the row cache.

     THIS IS THE WHOLE POINT. Valuing an item is not cheap: getSellValue walks into
     container contents, and conditionRatio has to ask the item what it is. Before this
     existed, prerender called total() -- which valued EVERY staged item from scratch --
     and then doDrawItem valued each visible row again, all sixty times a second. Stage
     two hundred items and that is twelve thousand recursive valuations per second.

     Now each row's name, condition and value are computed once and kept. Drawing and
     the payout total just read the numbers back.
]]
function TC_SellWindow:rebuildRows()
    -- Recorded so stageItems can tell whether the staging it just did survived. It is
    -- how "Added 9 item(s)" ended up printed in green over an empty list: the prune
    -- ran first, dropped all nine, and the success message was written afterwards.
    self.prunedLast = self:pruneStaged()

    local rows = {}
    local sorted = self:sortedStaged()
    for i, item in ipairs(sorted) do
        rows[i] = {
            item  = item,
            name  = item:getDisplayName(),
            ratio = TC.conditionRatio(item),
            value = TC.getSellPriceRounded(item),   -- per-line, for display only
        }
    end

    self.rows = rows

    -- The footer total is the one the player is actually paid, so it comes from the
    -- same precise-sum-then-round path the sale uses. Adding up the rounded per-line
    -- figures above would disagree with the payout by a dollar or two on big sales.
    self.totalValue = TC.sumSellValues(sorted)

    local items = {}
    for i = 1, #rows do
        items[i] = { text = rows[i].name, item = rows[i], itemindex = i, height = ROW_HGT }
    end
    self.list.items = items
    self.list.count = #items
    self.list:setScrollHeight(#items * ROW_HGT)

    self.lastRevalidate = getTimestampMs()
end

function TC_SellWindow:refreshList()
    self:rebuildRows()
end

function TC_SellWindow:total()
    return self.totalValue or 0
end

--[[ Click a header to sort by it; click the active one again to reverse. Text opens
     ascending, numbers open descending. ]]
function TC_SellWindow:sortBy(key)
    if self.sortKey == key then
        self.sortAsc = not self.sortAsc
    else
        self.sortKey = key
        self.sortAsc = (key == "name")
    end
    self:refreshList()
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

function TC_SellWindow:onRemoveSelected()
    local sel = self.list.items[self.list.selected]
    if not sel then return end

    -- sel.item is a row record; the InventoryItem it stands for is row.item.
    local target = sel.item.item
    for i, item in ipairs(self.staged) do
        if item == target then
            table.remove(self.staged, i)
            break
        end
    end
    self:refreshList()
    self.message = nil
end

function TC_SellWindow:onClearAll()
    self.staged = {}
    self:refreshList()
    self.message = nil
end

function TC_SellWindow:onSell()
    self:pruneStaged()

    if #self.staged == 0 then
        self:setMessage(getText("IGUI_TC_NothingStaged"), true)
        return
    end

    -- Settle on exactly the items that are going, and price the whole basket at full
    -- precision before rounding once. Rounding line by line and adding those up hands
    -- the player more than the goods are worth and erases the sell spread on cheap
    -- items -- ten $1 items at 0.9 should pay $9, not $10.
    local going = {}
    for _, item in ipairs(self.staged) do
        if TC.getSellValue(item) and item:getContainer() then
            table.insert(going, item)
        end
    end

    if #going == 0 then
        self:setMessage(getText("IGUI_TC_NothingStaged"), true)
        return
    end

    local total = TC.sumSellValues(going)

    -- Rescue anything inside a sold container that the sale will not pay for, BEFORE
    -- the container is removed. Otherwise selling a backpack deletes the money,
    -- favourites and unlisted items sitting in it and pays nothing for them.
    local rescued = {}
    for _, item in ipairs(going) do
        TC.rescueProtected(item, self.player, rescued)
    end

    local sold = 0
    for _, item in ipairs(going) do
        local container = item:getContainer()
        if container then
            container:Remove(item)
            sold = sold + 1
        end
    end

    self.staged = {}
    self:refreshList()

    TC.giveCash(self.player, total)

    if #rescued > 0 then
        self:setMessage(getText("IGUI_TC_SoldAndKept", sold, total, #rescued), false)
    else
        self:setMessage(getText("IGUI_TC_Sold", sold, total), false)
    end
end

function TC_SellWindow:setMessage(text, isError)
    self.message = text
    self.messageIsError = isError and true or false
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

--[[ Header labels are truncated against their own column width -- that is what stops
     "Condition" and "Value" printing on top of each other when the columns are
     narrower than the words. ]]
function TC_SellWindow:drawListHeader(headerY, listW)
    local c = TC.columns(listW, self.colW)
    local F = UIFont.Small

    self:drawRect(PAD, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(PAD, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)
    TC.drawColumnRules(self, c, PAD, headerY, HEADER_HGT, 0.4)

    local ty = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local ay = headerY + (HEADER_HGT - 4) / 2
    local ARROW = 11

    local function shade(key)
        if self.sortKey == key then return 1, 1, 1 end
        return 0.72, 0.72, 0.76
    end

    local nameRoom = (self.sortKey == "name") and (c.nameW - ARROW) or c.nameW
    local nameText = TC.truncate(F, getText("IGUI_TC_ColItem"), nameRoom)
    local nr, ng, nb = shade("name")
    self:drawText(nameText, PAD + c.nameLeft, ty, nr, ng, nb, 1, F)
    if self.sortKey == "name" then
        local w = getTextManager():MeasureStringX(F, nameText)
        TC.drawSortArrow(self, PAD + c.nameLeft + w + 4, ay, self.sortAsc)
    end

    -- The arrow goes to the LEFT of a right-aligned label, so the label keeps its edge
    -- alignment with the numbers in the column below it.
    local function headRight(key, tkey, right, avail)
        local room = (self.sortKey == key) and (avail - ARROW) or avail
        local text = TC.truncate(F, getText(tkey), room)
        local w = getTextManager():MeasureStringX(F, text)
        local x = PAD + right - w - TC.UI.CELL_PAD
        local r, g, b = shade(key)
        self:drawText(text, x, ty, r, g, b, 1, F)
        if self.sortKey == key then
            TC.drawSortArrow(self, x - ARROW, ay, self.sortAsc)
        end
    end
    headRight("mid", "IGUI_TC_ColCondition", c.midRight, c.midW)
    headRight("price", "IGUI_TC_ColValue", c.priceRight, c.priceW)

    if self.hoverDivider then
        self:drawRect(PAD + self.hoverDivider.x - 1, headerY, 3, HEADER_HGT, 0.8, 0.6, 0.7, 0.9)
    end
end

-- ---------------------------------------------------------------------------
-- Draggable column dividers
-- ---------------------------------------------------------------------------

-- Same reasoning as the buy window: a grab on a divider must not fall through to
-- ISCollapsableWindow:onMouseDown, which starts dragging the whole window.
function TC_SellWindow:headerBand()
    local listY = self:listGeometry()
    return PAD, listY - HEADER_HGT, self.width - PAD * 2, HEADER_HGT
end

function TC_SellWindow:dividerAtPoint(x, y)
    local hx, hy, hw, hh = self:headerBand()
    if y < hy or y > hy + hh then return nil end
    return TC.dividerUnder(TC.columns(hw, self.colW), hx, x)
end

function TC_SellWindow:onMouseMove(dx, dy)
    local x, y = self:getMouseX(), self:getMouseY()

    if self.dragCol then
        local hx, _, hw = self:headerBand()
        TC.resizeColumn(self.colW, self.dragCol.key, x - hx, hw)
        return true
    end

    self.hoverDivider = self:dividerAtPoint(x, y)
    return ISCollapsableWindow.onMouseMove(self, dx, dy)
end

function TC_SellWindow:onMouseDown(x, y)
    local d = self:dividerAtPoint(x, y)
    if d then
        self.dragCol = d
        self:bringToTop()
        return true
    end

    -- Header click sorts. Checked after the divider so the drag handle is never stolen.
    local hx, hy, hw, hh = self:headerBand()
    if y >= hy and y <= hy + hh and x >= hx and x <= hx + hw then
        local col = TC.columnAtPoint(TC.columns(hw, self.colW), hx, x)
        if col then
            self:sortBy(col)
            self:bringToTop()
            return true
        end
    end

    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function TC_SellWindow:onMouseUp(x, y)
    self.dragCol = nil
    return ISCollapsableWindow.onMouseUp(self, x, y)
end

function TC_SellWindow:onMouseUpOutside(x, y)
    self.dragCol = nil
    return ISCollapsableWindow.onMouseUpOutside(self, x, y)
end

--[[ How often the cached values are rebuilt while the window just sits there.

     Something has to catch food rotting, an item eaten out of the staged set, or a bag
     emptied behind our back. Doing it every frame was the original sin; once a second
     is far below what any of those changes can outrun, and costs a sixtieth as much. ]]
local REVALIDATE_MS = 1000

function TC_SellWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local now = getTimestampMs()
    if not self.lastRevalidate or (now - self.lastRevalidate) >= REVALIDATE_MS then
        self:rebuildRows()
    end

    local listY, listH = self:listGeometry()
    local listW = self.width - PAD * 2
    self:drawListHeader(listY - HEADER_HGT, listW)

    if #self.staged == 0 then
        -- The empty state has to say what to do: a blank box with a Sell button under
        -- it explains nothing.
        local hint = getText("IGUI_TC_DragHint")
        local hw = getTextManager():MeasureStringX(UIFont.Medium, hint)
        self:drawText(hint, (self.width - hw) / 2, listY + listH / 2 - FONT_HGT_MEDIUM,
                      0.6, 0.6, 0.64, 1, UIFont.Medium)

        local sub = getText("IGUI_TC_DragHintSub")
        local sw = getTextManager():MeasureStringX(UIFont.Small, sub)
        self:drawText(sub, (self.width - sw) / 2, listY + listH / 2 + 6,
                      0.45, 0.45, 0.5, 1, UIFont.Small)
    end

    -- Footer: staged count on the left, payout on the right, spread note beneath.
    local footY = listY + listH + PAD

    self:drawRect(PAD, footY - 6, listW, 1, 0.3, 1, 1, 1)

    self:drawText(getText("IGUI_TC_StagedCount", #self.staged), PAD, footY + 6,
                  0.62, 0.62, 0.66, 1, UIFont.Small)

    local label = getText("IGUI_TC_TotalPayout")
    local total = self:total()
    local tText = "$" .. total
    local tw = getTextManager():MeasureStringX(UIFont.Large, tText)
    local lw = getTextManager():MeasureStringX(UIFont.Small, label)

    self:drawText(tText, self.width - PAD - tw, footY, 0.85, 1, 0.85, 1, UIFont.Large)
    self:drawText(label, self.width - PAD - tw - lw - PAD, footY + (FONT_HGT_LARGE - FONT_HGT_SMALL) / 2,
                  0.68, 0.68, 0.72, 1, UIFont.Small)

    -- Spell out the spread rather than leaving the player to work out why the total
    -- falls short of the sticker prices.
    local msgY = footY + FONT_HGT_LARGE + 6
    if self.message then
        local msg = TC.truncate(UIFont.Small, self.message, listW)
        if self.messageIsError then
            self:drawText(msg, PAD, msgY, 1, 0.3, 0.3, 1, UIFont.Small)
        else
            self:drawText(msg, PAD, msgY, 0.6, 1, 0.6, 1, UIFont.Small)
        end
    else
        local ratio = TC.opt("SellRatio")
        if ratio < 1 then
            local note = getText("IGUI_TC_SellRatioNote",
                                 string.format("%d", math.floor((1 - ratio) * 100 + 0.5)))
            self:drawText(note, PAD, msgY, 0.5, 0.5, 0.55, 1, UIFont.Small)
        end
    end
end

function TC_SellWindow:onResize()
    ISCollapsableWindow.onResize(self)

    local listY, listH = self:listGeometry()
    self.list:setWidth(self.width - PAD * 2)
    self.list:setHeight(listH)

    local by    = self.height - BOTTOM_PAD - BUTTON_HGT
    local third = (self.width - PAD * 4) / 3
    self.removeBtn:setX(PAD);               self.removeBtn:setY(by); self.removeBtn:setWidth(third)
    self.clearBtn:setX(PAD * 2 + third);    self.clearBtn:setY(by);  self.clearBtn:setWidth(third)
    self.sellBtn:setX(PAD * 3 + third * 2); self.sellBtn:setY(by);   self.sellBtn:setWidth(third)
end

function TC_SellWindow:close()
    -- Nothing to hand back: staged items never left their containers.
    self.staged = {}
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_SellWindow.instances[self.playerNum] = nil
end

-- ---------------------------------------------------------------------------

function TC.openSellWindow(playerNum, catalogueItem)
    local existing = TC_SellWindow.instances[playerNum]
    if existing then
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local w = math.min(820, getCore():getScreenWidth()  - 80)
    local h = math.min(620, getCore():getScreenHeight() - 80)
    local x = (getCore():getScreenWidth()  - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2

    local win = TC_SellWindow:new(x, y, w, h, playerNum)
    win:initialise()
    win:instantiate()
    win:setTitle(getText("IGUI_TC_SellTitle"))
    win:addToUIManager()
    TC_SellWindow.instances[playerNum] = win
    return win
end

--[[ Death empties the box. The items are still wherever they were -- on the corpse,
     usually -- but the window must not keep pointing at them. ]]
Events.OnPlayerDeath.Add(function(player)
    local num = player and player:getPlayerNum()
    local win = num and TC_SellWindow.instances[num]
    if win then win:close() end
    local buy = num and TC_BuyWindow and TC_BuyWindow.instances[num]
    if buy then buy:close() end
end)
