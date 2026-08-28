--[[ The Catalogue -- the cart.

     Buying one line at a time works, but stocking up means a dozen separate
     transactions and a dozen separate withdrawals of cash. A cart collects the lines
     first and settles once, which is both less tedious and closer to what placing an
     order from a catalogue actually was.

     The cart holds fullTypes and quantities, never item instances -- nothing exists yet
     to hold. Prices are re-read at checkout rather than remembered from when the line
     was added, so a sandbox multiplier changed mid-session cannot be locked in at the
     old rate.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
local ROW_HGT    = 30
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12

-- ---------------------------------------------------------------------------

--[[ Where the three numeric columns end, counted back from the right edge.

     These were fixed offsets -- 176, 92, 4 -- which held at one font size and no other.
     At a larger UI scale "Unit price" is wide enough to start before "Quantity" has
     finished, and the header read "QuantiUnit price" with the two words stacked on each
     other.

     Measured off the widest thing each column can hold instead: its own heading, or a
     number long enough to cover any realistic cart, whichever is bigger. Worked out on
     first use rather than at load, because the headings are translated strings and
     translations are not guaranteed to be loaded while this file is being read. ]]
local cartStops
local function columnStops()
    if cartStops then return cartStops end

    local tm = getTextManager()
    local F  = UIFont.Small

    local function width(key, sample)
        return math.max(tm:MeasureStringX(F, getText(key)),
                        tm:MeasureStringX(F, sample)) + TC.UI.CELL_PAD * 2
    end

    local totalW = width("IGUI_TC_Total",     "$999999")
    local unitW  = width("IGUI_TC_UnitPrice", "$99999")
    local qtyW   = width("IGUI_TC_Quantity",  "999")

    -- Counted back from the scrollbar, not from the border: at 4px the last digit of
    -- the total drew underneath the scroll track and no resize could rescue it.
    local edge = TC.UI.SCROLL_GUTTER

    cartStops = {
        total = edge,
        unit  = edge + totalW,
        qty   = edge + totalW + unitW,
        name  = edge + totalW + unitW + qtyW,   -- what the name column has to give up
    }
    return cartStops
end

TC_CartList = ISScrollingListBox:derive("TC_CartList")

function TC_CartList:doDrawItem(y, item, alt)
    local line = item.item
    local w = self:getWidth()

    if self.selected == item.index then
        self:drawRect(0, y, w, ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)

    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    local unit = TC.getBuyPrice(line.fullType) or 0
    local c = columnStops()

    self:drawText(TC.truncate(UIFont.Small, line.name, w - c.name - 12),
                  12, ty, 1, 1, 1, 1, UIFont.Small)
    TC.drawRight(self, tostring(line.qty),       w - c.qty,   ty, UIFont.Small, 0.72, 0.72, 0.76)
    TC.drawRight(self, "$" .. unit,              w - c.unit,  ty, UIFont.Small, 0.62, 0.62, 0.66)
    TC.drawRight(self, "$" .. (unit * line.qty), w - c.total, ty, UIFont.Small, 0.78, 0.96, 0.78)

    return y + ROW_HGT
end

-- ---------------------------------------------------------------------------

TC_CartWindow = ISCollapsableWindow:derive("TC_CartWindow")
TC_CartWindow.instances = TC_CartWindow.instances or {}

function TC_CartWindow:new(x, y, w, h, playerNum, buyWindow)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o.buyWindow = buyWindow
    o.message = nil
    o.messageIsError = false
    o:setResizable(true)
    -- Never narrower than the button row, so a resize cannot clip a label.
    o.minimumWidth = math.max(560, PAD * 2 + TC.buttonRowWidth(
        { getText("IGUI_TC_RemoveSelected"), getText("IGUI_TC_ClearAll"),
          getText("IGUI_TC_Checkout"), getText("IGUI_TC_Rush") }, UIFont.Medium))
    o.minimumHeight = 420
    return o
end

function TC_CartWindow:listGeometry()
    local listY = self:titleBarHeight() + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - BUTTON_HGT - PAD
                  - FONT_HGT_LARGE - FONT_HGT_SMALL - PAD
    return listY, listH
end

--[[ The bottom row, worked out once and used by both creation and resize.

     Two copies of a layout expression is how the two drift apart, and this one is
     re-run on every resize. ]]
function TC_CartWindow:buttonSlots()
    return TC.buttonRow(PAD, self.width - PAD * 2,
                        { getText("IGUI_TC_RemoveSelected"),
                          getText("IGUI_TC_ClearAll"),
                          getText("IGUI_TC_Checkout"),
                          getText("IGUI_TC_Rush") },
                        UIFont.Medium)
end

function TC_CartWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local listY, listH = self:listGeometry()

    self.list = TC_CartList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self:addChild(self.list)

    -- Sized from their own labels rather than from the window, so "Place order" cannot
    -- run out through its border when the cart is narrow and "Rush" cannot become a
    -- banner when it is wide. See TC.buttonRow.
    local slots = self:buttonSlots()
    local by = self.height - BOTTOM_PAD - BUTTON_HGT

    local handlers = { TC_CartWindow.onRemove, TC_CartWindow.onClear,
                       TC_CartWindow.onCheckout, TC_CartWindow.onRush }
    local buttons = {}
    for i, slot in ipairs(slots) do
        local b = ISButton:new(slot.x, by, slot.w, BUTTON_HGT, slot.text, self, handlers[i])
        b:initialise(); b:instantiate()
        self:addChild(b)
        buttons[i] = b
    end

    self.removeBtn, self.clearBtn, self.checkoutBtn, self.rushBtn =
        buttons[1], buttons[2], buttons[3], buttons[4]

    self:refreshList()
end

function TC_CartWindow:cart()
    return self.buyWindow and self.buyWindow.cart or {}
end

function TC_CartWindow:refreshList()
    self.list:clear()
    for _, line in ipairs(self:cart()) do
        self.list:addItem(line.name, line)
    end
end

function TC_CartWindow:totals()
    local total, weight, count = 0, 0, 0
    for _, line in ipairs(self:cart()) do
        local unit = TC.getBuyPrice(line.fullType) or 0
        total  = total + unit * line.qty
        weight = weight + (line.weight or 0) * line.qty
        count  = count + line.qty
    end
    return total, weight, count
end

function TC_CartWindow:onRemove()
    local sel = self.list.items[self.list.selected]
    if not sel then return end
    local cart = self:cart()
    for i, line in ipairs(cart) do
        if line == sel.item then table.remove(cart, i); break end
    end
    self:refreshList()
    self.message = nil
end

function TC_CartWindow:onClear()
    local cart = self:cart()
    for i = #cart, 1, -1 do table.remove(cart, i) end
    self:refreshList()
    self.message = nil
end

--[[ Everything that can REFUSE the order is checked here, before the action starts,
     so the player hears about it immediately rather than after standing still. The
     charge and the delivery happen in onOrderComplete.

     A cart order takes the same interruptible time as a single purchase. It used to
     complete instantly, which made the cart the fast way to shop mid-fight and turned
     the order action into a pointless tax on buying one thing at a time. ]]
-- Same reason as TC_BuyWindow: the button arrives as the first argument, so the flag
-- cannot ride in that slot.
function TC_CartWindow:onCheckout() self:startCheckout(false) end
function TC_CartWindow:onRush()     self:startCheckout(true)  end

function TC_CartWindow:startCheckout(rush)
    local cart = self:cart()
    if #cart == 0 then
        self:setMessage(getText("IGUI_TC_CartEmpty"), true)
        return
    end

    for _, line in ipairs(cart) do
        if not getScriptManager():FindItem(line.fullType) then
            TC.warn("cart refused: unknown item %s", tostring(line.fullType))
            self:setMessage(getText("IGUI_TC_ItemUnavailable"), true)
            return
        end
    end

    local due = select(1, self:totals())
    if rush then due = due + TC.rushSurcharge(due) end
    if TC.getBalance(self.player) < due then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    local seconds = TC.opt("OrderSeconds")
    if type(seconds) ~= "number" or seconds <= 0 then
        self:onOrderComplete({ rush = rush })
        return
    end

    self:setMessage(getText("IGUI_TC_Ordering"), false)
    ISTimedActionQueue.add(TC_OrderAction:new(self.player, self, { rush = rush }, seconds))
end

function TC_CartWindow:onOrderCancelled()
    self:setMessage(getText("IGUI_TC_OrderCancelled"), true)
end

function TC_CartWindow:onOrderComplete(payload)
    local cart = self:cart()
    if #cart == 0 then return end

    local rush = payload and payload.rush and true or false

    -- Re-priced and re-checked after the action: seconds passed, and the player may
    -- have spent money or had the cart changed underneath them.
    local total = select(1, self:totals())
    if rush then total = total + TC.rushSurcharge(total) end

    if TC.getBalance(self.player) < total then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end
    if not TC.takeCash(self.player, total) then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    -- A normal cart is booked for delivery; only a rush cart is handed over now.
    if not rush then
        local lines, count = {}, 0
        for _, line in ipairs(cart) do
            table.insert(lines, {
                fullType = line.fullType, name = line.name, qty = line.qty,
                weight = line.weight or 0, unit = TC.getBuyPrice(line.fullType) or 0,
            })
            count = count + line.qty
        end

        local order = TC.placeOrder(self.player, lines, total)
        self:onClear()
        self:setMessage(getText("IGUI_TC_CartOrdered", count,
                                TC.etaPhrase(TC.hoursLeft(order))), false)
        return
    end

    local inv = self.player:getInventory()
    local lines, delivered, owed = {}, 0, 0

    for _, line in ipairs(cart) do
        local unit, got = TC.getBuyPrice(line.fullType) or 0, 0
        for _ = 1, line.qty do
            if inv:AddItem(line.fullType) then got = got + 1 end
        end
        delivered = delivered + got
        owed = owed + unit * (line.qty - got)
        if got > 0 then table.insert(lines, { name = line.name, qty = got }) end
    end

    if owed > 0 then
        TC.giveCash(self.player, owed)
        TC.warn("cart short by $%d, refunded", owed)
    end

    if delivered > 0 then
        TC.logTransaction(self.player, "buy", lines, total - owed)
    end

    self:onClear()
    self:setMessage(getText("IGUI_TC_CheckedOut", delivered, total - owed), false)
end

function TC_CartWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local listY, listH = self:listGeometry()
    local listW = self.width - PAD * 2
    local headerY = listY - HEADER_HGT

    self:drawRect(PAD, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(PAD, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local F = UIFont.Small
    self:drawText(getText("IGUI_TC_ColItem"), PAD + 12, hy, 0.72, 0.72, 0.76, 1, F)

    -- Drawn through the same right-aligning helper the rows use, so a heading sits
    -- exactly over its own numbers instead of twelve pixels to the side of them.
    local c = columnStops()
    for _, col in ipairs({ { "IGUI_TC_Quantity",  c.qty },
                           { "IGUI_TC_UnitPrice", c.unit },
                           { "IGUI_TC_Total",     c.total } }) do
        TC.drawRight(self, getText(col[1]), PAD + listW - col[2], hy, F, 0.72, 0.72, 0.76)
    end

    if #self:cart() == 0 then
        local hint = getText("IGUI_TC_CartEmpty")
        local hw = getTextManager():MeasureStringX(UIFont.Medium, hint)
        self:drawText(hint, (self.width - hw) / 2, listY + listH / 2 - FONT_HGT_MEDIUM,
                      0.6, 0.6, 0.64, 1, UIFont.Medium)
    end

    local total, weight, count = self:totals()
    local footY = listY + listH + PAD
    self:drawRect(PAD, footY - 6, listW, 1, 0.3, 1, 1, 1)

    self:drawText(getText("IGUI_TC_CartSummary", count, string.format("%.1f", weight)),
                  PAD, footY + 6, 0.62, 0.62, 0.66, 1, UIFont.Small)

    local tText = "$" .. total
    local tw = getTextManager():MeasureStringX(UIFont.Large, tText)
    local label = getText("IGUI_TC_Total")
    local lw = getTextManager():MeasureStringX(UIFont.Small, label)
    self:drawText(tText, self.width - PAD - tw, footY, 0.85, 1, 0.85, 1, UIFont.Large)
    self:drawText(label, self.width - PAD - tw - lw - PAD,
                  footY + (FONT_HGT_LARGE - FONT_HGT_SMALL) / 2, 0.68, 0.68, 0.72, 1, UIFont.Small)

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local msg = TC.truncate(UIFont.Small, msgText, listW)
        local my = footY + FONT_HGT_LARGE + 6
        if msgErr then
            self:drawText(msg, PAD, my, 1, 0.3, 0.3, 1, UIFont.Small)
        else
            self:drawText(msg, PAD, my, 0.6, 1, 0.6, 1, UIFont.Small)
        end
    end
end

function TC_CartWindow:onResize()
    ISCollapsableWindow.onResize(self)
    local listY, listH = self:listGeometry()
    self.list:setWidth(self.width - PAD * 2)
    self.list:setHeight(listH)

    local by = self.height - BOTTOM_PAD - BUTTON_HGT
    local slots = self:buttonSlots()
    for i, b in ipairs({ self.removeBtn, self.clearBtn, self.checkoutBtn, self.rushBtn }) do
        b:setX(slots[i].x)
        b:setY(by)
        b:setWidth(slots[i].w)
        -- The title is re-set as well as the width: below a certain size the labels are
        -- truncated to fit, and growing the window has to give the words back.
        b:setTitle(slots[i].text)
    end
end

function TC_CartWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_CartWindow.instances[self.playerNum] = nil
end

function TC.openCartWindow(playerNum, buyWindow)
    local existing = TC_CartWindow.instances[playerNum]
    if existing then
        existing:refreshList()
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local w = math.min(680, getCore():getScreenWidth() - 80)
    local h = math.min(520, getCore():getScreenHeight() - 80)
    local win = TC_CartWindow:new((getCore():getScreenWidth() - w) / 2,
                                  (getCore():getScreenHeight() - h) / 2,
                                  w, h, playerNum, buyWindow)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_CartTitle"))
    win:addToUIManager()
    TC_CartWindow.instances[playerNum] = win
    return win
end
TC.applyMessageBehaviour(TC_CartWindow)
