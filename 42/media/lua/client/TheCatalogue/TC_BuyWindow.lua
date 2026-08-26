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
    local c = TC.columns(self.width, { categoryColumn = true })

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end

    -- Faint separator under each row. With five columns the eye needs a horizontal
    -- rail to stay on one record.
    self:drawRect(0, y + ROW_HGT - 1, self:getWidth(), 1, 0.25, 1, 1, 1)

    if e.icon then
        self:drawTextureScaledAspect(e.icon, TC.UI.CELL_PAD, y + (ROW_HGT - ICON) / 2,
                                     ICON, ICON, 1, 1, 1, 1)
    end

    local textY = y + (ROW_HGT - FONT_HGT_MEDIUM) / 2
    self:drawText(TC.truncate(UIFont.Medium, e.name, c.nameW),
                  c.nameLeft, textY, 1, 1, 1, 1, UIFont.Medium)

    local smallY = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    if c.catW > 20 then
        self:drawText(TC.truncate(UIFont.Small, e.category, c.catW),
                      c.catLeft, smallY, 0.62, 0.62, 0.66, 1, UIFont.Small)
    end

    TC.drawRight(self, string.format("%.1f", e.weight or 0), c.midRight, smallY,
                 UIFont.Small, 0.62, 0.62, 0.66)

    TC.drawRight(self, "$" .. tostring(TC.getBuyPrice(e.fullType) or 0),
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
    o:setResizable(true)
    o.minimumWidth = 900
    o.minimumHeight = 640
    return o
end

function TC_BuyWindow:listGeometry()
    local top   = self:titleBarHeight() + PAD
    local listW = self.width - DETAIL_W - PAD * 3
    local listY = top + BUTTON_HGT + PAD + HEADER_HGT
    local listH = self.height - listY - PAD - FONT_HGT_SMALL - PAD
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
    self.list.onmousedown = TC_BuyWindow.onSelectItem
    self:addChild(self.list)

    local dx = self.width - DETAIL_W - PAD
    local by = self.height - PAD - BUTTON_HGT

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

function TC_BuyWindow:populateCategories()
    TC.buildIndex()

    local seen, names = {}, {}
    for _, e in ipairs(TC.entries) do
        if not seen[e.category] then
            seen[e.category] = true
            table.insert(names, e.category)
        end
    end
    table.sort(names)

    self.categoryList = { "" }  -- empty string is the "all categories" sentinel
    self.categoryCombo:addOption(getText("IGUI_TC_AllCategories"))
    for _, n in ipairs(names) do
        self.categoryCombo:addOption(n)
        table.insert(self.categoryList, n)
    end
    self.categoryCombo.selected = 1
end

function TC_BuyWindow:onCategoryChange()
    self:refreshList()
end

function TC_BuyWindow:refreshList()
    TC.buildIndex()

    local needle = string.lower(self.search:getInternalText() or "")
    local cat = self.categoryList and self.categoryList[self.categoryCombo.selected] or ""

    self.list:clear()
    for _, e in ipairs(TC.entries) do
        local catOk = (cat == "" or e.category == cat)
        -- entry.lower holds "display name  fulltype" pre-lowercased at index time,
        -- so typing matches either what the player sees or what a modder would type.
        local textOk = (needle == "" or string.find(e.lower, needle, 1, true) ~= nil)
        if catOk and textOk then
            self.list:addItem(e.name, e)
        end
    end

    self.selectedEntry = nil
    self.list.selected = -1
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

function TC_BuyWindow:onQuantityTyped()
    local n = tonumber(self.qtyEntry:getInternalText())
    if n then self.quantity = math.max(1, math.min(self:maxQuantity(), math.floor(n))) end
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

    local inv = player:getInventory()
    for _ = 1, qty do
        inv:AddItem(entry.fullType)
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

--[[ Column headers, drawn on the window rather than inside the list so they stay
     put while the rows scroll under them. ]]
function TC_BuyWindow:drawListHeader(listX, headerY, listW)
    local c = TC.columns(listW, { categoryColumn = true })

    self:drawRect(listX, headerY, listW, HEADER_HGT, 0.6, 0.13, 0.13, 0.15)
    self:drawRectBorder(listX, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local ty = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local function head(text, x)
        self:drawText(text, listX + x, ty, 0.72, 0.72, 0.76, 1, UIFont.Small)
    end

    head(getText("IGUI_TC_ColItem"), c.nameLeft)
    if c.catW > 20 then head(getText("IGUI_TC_ColCategory"), c.catLeft) end

    local function headRight(text, right)
        local w = getTextManager():MeasureStringX(UIFont.Small, text)
        self:drawText(text, listX + right - w - TC.UI.CELL_PAD, ty, 0.72, 0.72, 0.76, 1, UIFont.Small)
    end
    headRight(getText("IGUI_TC_ColWeight"), c.midRight)
    headRight(getText("IGUI_TC_ColPrice"), c.priceRight)
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

        local function line(label, value, font, r, g, b)
            font = font or UIFont.Medium
            local h = getTextManager():getFontHeight(font)
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
        self:drawText(getText("IGUI_TC_SelectAnItem"), innerLeft, y + 4,
                      0.55, 0.55, 0.6, 1, UIFont.Medium)
    end

    -- Balance and message live in a fixed block above the controls, so they never
    -- move as the detail above them grows or shrinks.
    local blockY = self.height - PAD - BUTTON_HGT * 2 - PAD - FONT_HGT_LARGE - PAD - 4

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
    self:drawText(countText, PAD, self.height - PAD - FONT_HGT_SMALL,
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
    local by = self.height - PAD - BUTTON_HGT
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

    local win = TC_BuyWindow:new(x, y, w, h, playerNum)
    win:initialise()
    win:instantiate()
    win:setTitle(getText("IGUI_TC_BuyTitle"))
    win:addToUIManager()
    TC_BuyWindow.instances[playerNum] = win
    return win
end
