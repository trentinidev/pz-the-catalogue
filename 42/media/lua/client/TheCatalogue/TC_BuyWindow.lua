--[[ The Catalogue -- the buy window.

     A table on the left, a detail panel on the right. One purchase at a time: the
     alternative, a quantity field on every row, puts thousands of editable widgets
     in a scroll box and makes a misclick expensive.

     The list is laid out as real columns -- icon, name, category, weight, price --
     with the numeric columns right-aligned and pinned to the right edge, so prices
     can be compared by running the eye down them.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)

local PAD        = 14
local ROW_HGT    = 34
local ICON       = 26
local DETAIL_W   = 340
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12

--[[ The bottom margin has to be larger than the top one to LOOK the same.

     At the top, content sits below the title bar, which is itself a visible band that
     reads as framing. At the bottom there is only the window border and the resize
     grip, so an identical PAD leaves the button and the row count looking pressed
     against the edge. Matching the top's total inset is what balances it.
]]
local BOTTOM_PAD = PAD * 2

-- ---------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------

TC_BuyList = ISScrollingListBox:derive("TC_BuyList")

--[[ ISScrollingListBox:prerender walks EVERY row every frame and calls doDrawItem on
     each -- the base class culls nothing. With the full catalogue loaded that would
     be five thousand icon and text draws per frame.

     So the first thing here is a visibility test that returns the next y without
     drawing. The loop still runs 5,000 times, but 5,000 comparisons per frame is
     cheap; it was the draw calls that hurt.
]]
function TC_BuyList:doDrawItem(y, item, alt)
    local scroll = self:getYScroll()
    if y + ROW_HGT + scroll < 0 or y + scroll > self.height then
        return y + ROW_HGT
    end

    local e = item.item
    local c = TC.columns(self.width, self.parentWindow and self.parentWindow.colW or nil)

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end

    -- Grid: a horizontal rail under each row and a vertical rule between each column,
    -- so a record reads across and a column reads down.
    self:drawRect(0, y + ROW_HGT - 1, self:getWidth(), 1, 0.25, 1, 1, 1)
    TC.drawColumnRules(self, c, 0, y, ROW_HGT - 1, 0.22)

    local icon = TC.entryIcon(e)
    if icon then
        self:drawTextureScaledAspect(icon, TC.UI.CELL_PAD, y + (ROW_HGT - ICON) / 2,
                                     ICON, ICON, 1, 1, 1, 1)
    end

    local textY = y + (ROW_HGT - FONT_HGT_MEDIUM) / 2
    self:drawText(TC.truncate(UIFont.Medium, e.name, c.nameW),
                  c.nameLeft, textY, 1, 1, 1, 1, UIFont.Medium)

    local smallY = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    if c.catW > 20 then
        self:drawText(TC.truncate(UIFont.Small, e.category, c.catW),
                      c.catLeft + TC.UI.CELL_PAD, smallY, 0.62, 0.62, 0.66, 1, UIFont.Small)
    end

    TC.drawRight(self, string.format("%.1f", e.weight or 0), c.midRight, smallY,
                 UIFont.Small, 0.62, 0.62, 0.66)

    TC.drawRight(self, "$" .. TC.entryPrice(e),
                 c.priceRight, textY, UIFont.Medium, 0.78, 0.96, 0.78)

    return y + ROW_HGT
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

TC_BuyWindow = ISCollapsableWindow:derive("TC_BuyWindow")
TC_BuyWindow.instances = TC_BuyWindow.instances or {}

function TC_BuyWindow:new(x, y, w, h, playerNum)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o.quantity = 1
    o.message = nil
    o.messageIsError = false
    o.colW = TC.defaultColumnWidths("buy")   -- per window, so drags do not leak across
    o.dragCol = nil
    o.sortKey = "name"                       -- name | cat | mid (weight) | price
    o.sortAsc = true
    o:setResizable(true)
    o.minimumWidth = 900
    o.minimumHeight = 640
    return o
end

function TC_BuyWindow:listGeometry()
    local top   = self:titleBarHeight() + PAD
    local listW = self.width - DETAIL_W - PAD * 3
    local listY = top + BUTTON_HGT + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - FONT_HGT_SMALL - PAD
    return top, listW, listY, listH
end

function TC_BuyWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local top, listW, listY, listH = self:listGeometry()

    self.search = ISTextEntryBox:new("", PAD, top, listW - 220, BUTTON_HGT)
    self.search:initialise()
    self.search:instantiate()
    self.search.onTextChange = function() self:refreshList() end
    self:addChild(self.search)

    self.categoryCombo = ISComboBox:new(PAD + listW - 210, top, 210, BUTTON_HGT,
                                        self, TC_BuyWindow.onCategoryChange)
    self.categoryCombo:initialise()
    self:addChild(self.categoryCombo)

    self.list = TC_BuyList:new(PAD, listY, listW, listH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    -- Without this the rows fall back to the DEFAULT column widths while the header
    -- uses the live ones, so dragging a divider moved only the header. The list needs
    -- a way back to the window that owns the widths.
    self.list.parentWindow = self
    self.list.onmousedown = TC_BuyWindow.onSelectItem
    self:addChild(self.list)

    local dx = self.width - DETAIL_W - PAD
    local by = self.height - BOTTOM_PAD - BUTTON_HGT

    self.minusBtn = ISButton:new(dx + PAD, by - BUTTON_HGT - PAD, 34, BUTTON_HGT, "-",
                                 self, TC_BuyWindow.onQuantityStep)
    self.minusBtn.internal = "MINUS"
    self.minusBtn:initialise(); self.minusBtn:instantiate()
    self:addChild(self.minusBtn)

    self.qtyEntry = ISTextEntryBox:new("1", dx + PAD + 40, by - BUTTON_HGT - PAD, 84, BUTTON_HGT)
    self.qtyEntry:initialise(); self.qtyEntry:instantiate()
    self.qtyEntry:setOnlyNumbers(true)
    self.qtyEntry.onTextChange = function() self:onQuantityTyped() end
    self:addChild(self.qtyEntry)

    self.plusBtn = ISButton:new(dx + PAD + 130, by - BUTTON_HGT - PAD, 34, BUTTON_HGT, "+",
                                self, TC_BuyWindow.onQuantityStep)
    self.plusBtn.internal = "PLUS"
    self.plusBtn:initialise(); self.plusBtn:instantiate()
    self:addChild(self.plusBtn)

    self.buyBtn = ISButton:new(dx + PAD, by, DETAIL_W - PAD * 2, BUTTON_HGT,
                               getText("IGUI_TC_Buy"), self, TC_BuyWindow.onBuy)
    self.buyBtn:initialise(); self.buyBtn:instantiate()
    self:addChild(self.buyBtn)

    self:populateCategories()
    self:refreshList()
end

--[[ Fill the filter dropdown with the item categories, then the source mods.

     self.categoryList runs in step with the combo's options and holds a FILTER SPEC
     per entry rather than a bare string, because the list now mixes two different
     questions: what a thing is (Food, Clothing) and where it came from (which mod).
     Keeping them in one dropdown was the deliberate choice -- one control, no extra
     width in a header bar that is already full.
]]
function TC_BuyWindow:populateCategories()
    TC.buildIndex()

    local seenCat, cats = {}, {}
    local seenMod, mods = {}, {}
    for _, e in ipairs(TC.entries) do
        if not seenCat[e.category] then
            seenCat[e.category] = true
            table.insert(cats, e.category)
        end
        local m = e.module or "Base"
        if m ~= "Base" and not seenMod[m] then
            seenMod[m] = true
            table.insert(mods, m)
        end
    end
    table.sort(cats)
    table.sort(mods)

    self.categoryList = { { kind = "all" } }
    self.categoryCombo:addOption(getText("IGUI_TC_AllCategories"))

    self.categoryCombo:addOption(getText("IGUI_TC_VanillaOnly"))
    table.insert(self.categoryList, { kind = "module", value = "Base" })

    for _, c in ipairs(cats) do
        self.categoryCombo:addOption(c)
        table.insert(self.categoryList, { kind = "category", value = c })
    end

    -- Source mods last, so the categories a player uses constantly stay near the top.
    for _, m in ipairs(mods) do
        self.categoryCombo:addOption(getText("IGUI_TC_ModPrefix", m))
        table.insert(self.categoryList, { kind = "module", value = m })
    end

    self.categoryCombo.selected = 1
end

function TC_BuyWindow:onCategoryChange()
    self:refreshList()
end

--[[ Rebuild the visible rows.

     Two things here exist purely for speed, because this runs on every keystroke in
     the search box over a ten-thousand-row catalogue.

     The ordering comes from TC.sortedEntries, which caches one array per sort and
     returns the index itself for the default name-ascending view. Filtering an
     already-ordered array preserves that order, so nothing is sorted here at all.

     The rows are then written straight into the list box's items table instead of
     going through addItem. addItem calls getScrollHeight and setScrollHeight on every
     single call, and both cross into Java through javaObject -- twenty thousand round
     trips to accumulate a total that is one multiplication.
]]
function TC_BuyWindow:refreshList()
    local ordered = TC.sortedEntries(self.sortKey, self.sortAsc)

    local needle = string.lower(self.search:getInternalText() or "")
    local spec = self.categoryList and self.categoryList[self.categoryCombo.selected]
                 or { kind = "all" }
    local filtering = (needle ~= "" or spec.kind ~= "all")

    local items, n = {}, 0
    for i = 1, #ordered do
        local e = ordered[i]
        local keep = true
        if filtering then
            if spec.kind == "category" then
                keep = (e.category == spec.value)
            elseif spec.kind == "module" then
                keep = ((e.module or "Base") == spec.value)
            end
            -- entry.lower holds "display name  fulltype" pre-lowercased at index time,
            -- so typing matches either what the player sees or what a modder would type.
            if keep and needle ~= "" then
                keep = string.find(e.lower, needle, 1, true) ~= nil
            end
        end
        if keep then
            n = n + 1
            items[n] = { text = e.name, item = e, itemindex = n, height = ROW_HGT }
        end
    end

    self.list.items = items
    self.list.count = n
    self.list:setScrollHeight(n * ROW_HGT)
    self.list:setYScroll(0)

    self.selectedEntry = nil
    self.list.selected = -1
end

--[[ Click a header to sort by it; click the active one again to reverse.

     Text columns open ascending (A-Z) and numeric columns open descending, because
     "show me the expensive things" is the question people actually arrive with when
     they click a price header.
]]
function TC_BuyWindow:sortBy(key)
    if self.sortKey == key then
        self.sortAsc = not self.sortAsc
    else
        self.sortKey = key
        self.sortAsc = (key == "name" or key == "cat")
    end
    self:refreshList()
end

--[[ ISScrollingListBox calls this as onmousedown(self.target, item.item), so the
     catalogue entry arrives directly -- no need to go back through the selected
     index, which is also briefly stale right after a clear(). ]]
function TC_BuyWindow:onSelectItem(entry)
    self.selectedEntry = entry
    self.message = nil
end

function TC_BuyWindow:maxQuantity()
    return math.max(1, math.floor(TC.opt("MaxQuantityPerPurchase")))
end

function TC_BuyWindow:setQuantity(q)
    q = math.max(1, math.min(self:maxQuantity(), math.floor(q or 1)))
    self.quantity = q
    if self.qtyEntry:getInternalText() ~= tostring(q) then
        self.qtyEntry:setText(tostring(q))
    end
end

--[[ Clamp what was typed, and write the clamped value back into the box.

     Only writing the variable let the field keep showing 999 while the purchase was
     silently capped at 100 -- the total underneath disagreed with the number the
     player was looking at. The box now always shows the quantity that will actually
     be bought. ]]
function TC_BuyWindow:onQuantityTyped()
    local text = self.qtyEntry:getInternalText()
    local n = tonumber(text)
    if not n then return end

    local clamped = math.max(1, math.min(self:maxQuantity(), math.floor(n)))
    self.quantity = clamped

    -- Rewrite only when the typing actually exceeded the bounds. Correcting the field
    -- on every keystroke would fight someone halfway through typing "10".
    if clamped ~= n and text ~= tostring(clamped) then
        self.qtyEntry:setText(tostring(clamped))
    end
end

function TC_BuyWindow:onQuantityStep(button)
    self:setQuantity(self.quantity + (button.internal == "PLUS" and 1 or -1))
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

function TC_BuyWindow:onBuy()
    local entry = self.selectedEntry
    if not entry then
        self:setMessage(getText("IGUI_TC_SelectAnItem"), true)
        return
    end

    local player = self.player
    if not player then return end

    local unit  = TC.getBuyPrice(entry.fullType) or 0
    local qty   = self.quantity
    local total = unit * qty

    -- Prove the item can actually be made BEFORE any money moves. A fullType can go
    -- stale between indexing and checkout -- a mod unloaded, an item retired by a
    -- patch -- and the old order of operations took the cash first, so a failed
    -- AddItem left the player charged and empty-handed.
    if not getScriptManager():FindItem(entry.fullType) then
        print("[TheCatalogue] refused purchase: unknown item " .. tostring(entry.fullType))
        self:setMessage(getText("IGUI_TC_ItemUnavailable"), true)
        return
    end

    if TC.getBalance(player) < total then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    if not TC.takeCash(player, total) then
        -- takeCash re-checks and leaves the inventory untouched on failure, so a race
        -- between the balance check and here cannot half-charge the player.
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    -- Count what is actually delivered and refund anything that was not. AddItem is
    -- not supposed to fail once FindItem has answered, but "not supposed to" is not a
    -- guarantee worth charging someone for.
    local inv = player:getInventory()
    local delivered = 0
    for _ = 1, qty do
        if inv:AddItem(entry.fullType) then delivered = delivered + 1 end
    end

    if delivered < qty then
        local refund = unit * (qty - delivered)
        TC.giveCash(player, refund)
        total = unit * delivered
        print(string.format("[TheCatalogue] delivered %d of %d %s -- refunded $%d",
                            delivered, qty, tostring(entry.fullType), refund))
        if delivered == 0 then
            self:setMessage(getText("IGUI_TC_ItemUnavailable"), true)
            return
        end
        qty = delivered
    end

    -- Deliver regardless of capacity, then say so. Being overloaded is a vanilla-legal
    -- state -- looting a hardware store does it too -- and silently refusing a purchase
    -- the player can afford is worse than letting them stagger home.
    local over = self:overCapacityBy(player)
    if over > 0 then
        self:setMessage(getText("IGUI_TC_BoughtOverweight", qty, entry.name, total,
                                string.format("%.1f", over)), false)
    else
        self:setMessage(getText("IGUI_TC_Bought", qty, entry.name, total), false)
    end
end

function TC_BuyWindow:overCapacityBy(player)
    local ok, over = pcall(function()
        local inv = player:getInventory()
        return inv:getCapacityWeight() - inv:getMaxWeight()
    end)
    if ok and type(over) == "number" and over > 0 then return over end
    return 0
end

function TC_BuyWindow:setMessage(text, isError)
    self.message = text
    self.messageIsError = isError and true or false
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

--[[ Column headers, drawn on the window rather than inside the list so they stay put
     while the rows scroll under them.

     Every label goes through truncate against its own column width. That is what fixes
     the pile-up in the old header: the labels were drawn at full length regardless of
     how much room the column had, so "Category", "Weight" and "Price" overprinted each
     other whenever the columns were narrower than the words. ]]
function TC_BuyWindow:drawListHeader(listX, headerY, listW)
    local c = TC.columns(listW, self.colW)

    self:drawRect(listX, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(listX, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)
    TC.drawColumnRules(self, c, listX, headerY, HEADER_HGT, 0.4)

    local ty = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local ay = headerY + (HEADER_HGT - 4) / 2      -- the arrow is 4px tall
    local F  = UIFont.Small
    local ARROW = 11                                -- glyph width plus its gap

    -- The active column is brighter, so which sort is in force is readable at a glance.
    local function shade(key)
        if self.sortKey == key then return 1, 1, 1 end
        return 0.72, 0.72, 0.76
    end

    -- Left-aligned headers: label first, arrow immediately after it.
    local function headLeft(key, tkey, x, avail)
        local room = (self.sortKey == key) and (avail - ARROW) or avail
        local text = TC.truncate(F, getText(tkey), room)
        local r, g, b = shade(key)
        self:drawText(text, x, ty, r, g, b, 1, F)
        if self.sortKey == key then
            local w = getTextManager():MeasureStringX(F, text)
            TC.drawSortArrow(self, x + w + 4, ay, self.sortAsc)
        end
    end

    -- Right-aligned headers: arrow sits to the LEFT of the label, so the label keeps
    -- its edge alignment with the numbers underneath it.
    local function headRight(key, tkey, right, avail)
        local room = (self.sortKey == key) and (avail - ARROW) or avail
        local text = TC.truncate(F, getText(tkey), room)
        local w = getTextManager():MeasureStringX(F, text)
        local x = listX + right - w - TC.UI.CELL_PAD
        local r, g, b = shade(key)
        self:drawText(text, x, ty, r, g, b, 1, F)
        if self.sortKey == key then
            TC.drawSortArrow(self, x - ARROW, ay, self.sortAsc)
        end
    end

    headLeft("name", "IGUI_TC_ColItem", listX + c.nameLeft, c.nameW)
    if c.catW > 20 then
        headLeft("cat", "IGUI_TC_ColCategory", listX + c.catLeft + TC.UI.CELL_PAD, c.catW)
    end
    headRight("mid", "IGUI_TC_ColWeight", c.midRight, c.midW)
    headRight("price", "IGUI_TC_ColPrice", c.priceRight, c.priceW)

    -- Highlight the divider under the cursor so the drag handle is discoverable.
    if self.hoverDivider then
        self:drawRect(listX + self.hoverDivider.x - 1, headerY, 3, HEADER_HGT, 0.8, 0.6, 0.7, 0.9)
    end
end

-- ---------------------------------------------------------------------------
-- Draggable column dividers
-- ---------------------------------------------------------------------------

--[[ The header strip is drawn by the window, not by the list box, so its mouse events
     arrive here. ISCollapsableWindow:onMouseDown sets self.moving unconditionally --
     it drags the window from anywhere, not just the title bar -- so a grab on a
     divider must NOT fall through to it, or the whole window would follow the cursor. ]]
function TC_BuyWindow:headerBand()
    local _, listW, listY = self:listGeometry()
    return PAD, listY - HEADER_HGT, listW, HEADER_HGT
end

function TC_BuyWindow:dividerAtPoint(x, y)
    local hx, hy, hw, hh = self:headerBand()
    if y < hy or y > hy + hh then return nil end
    return TC.dividerUnder(TC.columns(hw, self.colW), hx, x)
end

function TC_BuyWindow:onMouseMove(dx, dy)
    local x, y = self:getMouseX(), self:getMouseY()

    if self.dragCol then
        local hx, _, hw = self:headerBand()
        TC.resizeColumn(self.colW, self.dragCol.key, x - hx, hw)
        return true
    end

    self.hoverDivider = self:dividerAtPoint(x, y)
    return ISCollapsableWindow.onMouseMove(self, dx, dy)
end

function TC_BuyWindow:onMouseDown(x, y)
    local d = self:dividerAtPoint(x, y)
    if d then
        self.dragCol = d
        self:bringToTop()
        return true          -- consumed: the window must not start moving
    end

    -- A click anywhere else on the header sorts by that column. Checked after the
    -- divider so the few pixels of a drag handle are never stolen by the sort.
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

function TC_BuyWindow:onMouseUp(x, y)
    self.dragCol = nil
    return ISCollapsableWindow.onMouseUp(self, x, y)
end

function TC_BuyWindow:onMouseUpOutside(x, y)
    self.dragCol = nil
    return ISCollapsableWindow.onMouseUpOutside(self, x, y)
end

function TC_BuyWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local top, listW, listY, listH = self:listGeometry()
    self:drawListHeader(PAD, listY - HEADER_HGT, listW)

    -- Placeholder inside the empty search box. Without it the box reads as a blank
    -- field and players do not discover that they can type an item ID into it.
    if self.search and (self.search:getInternalText() or "") == "" then
        self:drawText(getText("IGUI_TC_SearchHint"), PAD + 10,
                      top + (BUTTON_HGT - FONT_HGT_SMALL) / 2,
                      0.45, 0.45, 0.5, 1, UIFont.Small)
    end

    local dx = self.width - DETAIL_W - PAD
    local dy = self:titleBarHeight() + PAD
    local dh = self.height - dy - PAD

    self:drawRect(dx, dy, DETAIL_W, dh, 0.45, 0, 0, 0)
    self:drawRectBorder(dx, dy, DETAIL_W, dh, 0.5, 0.4, 0.4, 0.4)

    local entry = self.selectedEntry
    local y = dy + PAD + 4
    local innerLeft  = dx + PAD
    local innerRight = dx + DETAIL_W - PAD

    if entry then
        if entry.icon then
            self:drawTextureScaledAspect(entry.icon, innerLeft, y, 64, 64, 1, 1, 1, 1)
        end

        local textLeft = innerLeft + 64 + PAD
        local nameW    = innerRight - textLeft
        self:drawText(TC.truncate(UIFont.Large, entry.name, nameW),
                      textLeft, y + 6, 1, 1, 1, 1, UIFont.Large)
        self:drawText(TC.truncate(UIFont.Small, entry.fullType, nameW),
                      textLeft, y + 10 + FONT_HGT_LARGE, 0.55, 0.55, 0.6, 1, UIFont.Small)

        y = y + 64 + PAD + 8

        self:drawRect(innerLeft, y, DETAIL_W - PAD * 2, 1, 0.35, 1, 1, 1)
        y = y + PAD

        local unit       = TC.getBuyPrice(entry.fullType) or 0
        local total      = unit * self.quantity
        local itemWeight = (entry.weight or 0) * self.quantity
        local balance    = TC.getBalance(self.player)
        local after      = balance - total

        -- The detail block flows downward while the cash block below it is pinned to
        -- the bottom of the panel. On a short window the two would meet, so lines stop
        -- rather than print over it. Losing the last line beats an unreadable overlap.
        local detailFloor = self.height - BOTTOM_PAD - BUTTON_HGT * 2 - PAD
                            - FONT_HGT_LARGE - PAD - 4 - FONT_HGT_SMALL

        local function line(label, value, font, r, g, b)
            font = font or UIFont.Medium
            local h = getTextManager():getFontHeight(font)
            if y + h > detailFloor then return end
            self:drawText(label, innerLeft, y, 0.68, 0.68, 0.72, 1, UIFont.Small)
            local vw = getTextManager():MeasureStringX(font, value)
            self:drawText(value, innerRight - vw, y - (h - FONT_HGT_SMALL) / 2,
                          r or 1, g or 1, b or 1, 1, font)
            y = y + math.max(h, FONT_HGT_SMALL) + 10
        end

        line(getText("IGUI_TC_UnitPrice"), "$" .. unit)

        -- What it fetches back. Buying and immediately reselling is a loss by design,
        -- and stating it up front is fairer than letting the player discover the
        -- spread only after they have committed.
        line(getText("IGUI_TC_SellsBackFor"),
             "$" .. math.floor(unit * TC.opt("SellRatio") + 0.5),
             UIFont.Small, 0.62, 0.62, 0.66)

        -- Counted recursively so a box of nails in a backpack still counts as owned.
        local owned = 0
        local okCount, n = pcall(function()
            return self.player:getInventory():getItemCountRecurse(entry.fullType)
        end)
        if okCount and type(n) == "number" then owned = n end
        line(getText("IGUI_TC_YouOwn"), tostring(owned), UIFont.Small, 0.62, 0.62, 0.66)

        y = y + 2
        self:drawRect(innerLeft, y, DETAIL_W - PAD * 2, 1, 0.35, 1, 1, 1)
        y = y + PAD

        line(getText("IGUI_TC_Quantity"),    tostring(self.quantity))
        line(getText("IGUI_TC_AddedWeight"), string.format("%.1f", itemWeight))

        y = y + 2
        self:drawRect(innerLeft, y, DETAIL_W - PAD * 2, 1, 0.35, 1, 1, 1)
        y = y + PAD

        line(getText("IGUI_TC_Total"), "$" .. total, UIFont.Large, 0.78, 0.98, 0.78)

        -- Red the moment the order costs more than the player is carrying, so the
        -- refusal is visible before the Buy button is ever pressed.
        if after < 0 then
            line(getText("IGUI_TC_CashAfter"), "$" .. after, UIFont.Medium, 1, 0.35, 0.35)
        else
            line(getText("IGUI_TC_CashAfter"), "$" .. after, UIFont.Medium, 0.72, 0.72, 0.76)
        end
    else
        -- Truncated against the panel width: at UIFont.Medium this string is wider
        -- than the detail panel, so it used to run off the right edge of the window.
        self:drawText(TC.truncate(UIFont.Small, getText("IGUI_TC_SelectAnItem"), DETAIL_W - PAD * 2),
                      innerLeft, y + 4, 0.55, 0.55, 0.6, 1, UIFont.Small)
    end

    -- Balance and message live in a fixed block above the controls, so they never
    -- move as the detail above them grows or shrinks.
    local blockY = self.height - BOTTOM_PAD - BUTTON_HGT * 2 - PAD - FONT_HGT_LARGE - PAD - 4

    self:drawText(getText("IGUI_TC_YourCash"), innerLeft, blockY + 4,
                  0.68, 0.68, 0.72, 1, UIFont.Small)
    local balance = TC.getBalance(self.player)
    local bText = "$" .. balance
    local bw = getTextManager():MeasureStringX(UIFont.Large, bText)
    self:drawText(bText, innerRight - bw, blockY, 0.85, 1, 0.85, 1, UIFont.Large)

    if self.message then
        local my = blockY + FONT_HGT_LARGE + 6
        local msg = TC.truncate(UIFont.Small, self.message, DETAIL_W - PAD * 2)
        if self.messageIsError then
            self:drawText(msg, innerLeft, my, 1, 0.3, 0.3, 1, UIFont.Small)
        else
            self:drawText(msg, innerLeft, my, 0.6, 1, 0.6, 1, UIFont.Small)
        end
    end

    -- Row count, so a filter that matches nothing reads as a filter and not a bug.
    local countText = (#self.list.items == 0)
        and getText("IGUI_TC_NoMatches")
        or  getText("IGUI_TC_ItemsListed", #self.list.items)
    self:drawText(countText, PAD, self.height - BOTTOM_PAD - FONT_HGT_SMALL,
                  0.6, 0.6, 0.64, 1, UIFont.Small)
end

function TC_BuyWindow:onResize()
    ISCollapsableWindow.onResize(self)

    local top, listW, listY, listH = self:listGeometry()

    self.search:setWidth(listW - 220)
    self.categoryCombo:setX(PAD + listW - 210)
    self.list:setWidth(listW)
    self.list:setHeight(listH)

    local dx = self.width - DETAIL_W - PAD
    local by = self.height - BOTTOM_PAD - BUTTON_HGT
    self.minusBtn:setX(dx + PAD);        self.minusBtn:setY(by - BUTTON_HGT - PAD)
    self.qtyEntry:setX(dx + PAD + 40);   self.qtyEntry:setY(by - BUTTON_HGT - PAD)
    self.plusBtn:setX(dx + PAD + 130);   self.plusBtn:setY(by - BUTTON_HGT - PAD)
    self.buyBtn:setX(dx + PAD);          self.buyBtn:setY(by)
    self.buyBtn:setWidth(DETAIL_W - PAD * 2)
end

function TC_BuyWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_BuyWindow.instances[self.playerNum] = nil
end

-- ---------------------------------------------------------------------------

function TC.openBuyWindow(playerNum, catalogueItem)
    local existing = TC_BuyWindow.instances[playerNum]
    if existing then
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local w = math.min(1240, getCore():getScreenWidth()  - 80)
    local h = math.min(760,  getCore():getScreenHeight() - 80)
    local x = (getCore():getScreenWidth()  - w) / 2
    local y = (getCore():getScreenHeight() - h) / 2

    local started = getTimestampMs()

    local win = TC_BuyWindow:new(x, y, w, h, playerNum)
    win:initialise()
    win:instantiate()
    win:setTitle(getText("IGUI_TC_BuyTitle"))
    win:addToUIManager()
    TC_BuyWindow.instances[playerNum] = win

    print(string.format("[TheCatalogue] buy window opened in %d ms (%d rows)",
                        getTimestampMs() - started, #win.list.items))
    return win
end
