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

    self:drawText(TC.truncate(UIFont.Small, line.name, w - 260), 12, ty, 1, 1, 1, 1, UIFont.Small)
    TC.drawRight(self, tostring(line.qty),      w - 176, ty, UIFont.Small, 0.72, 0.72, 0.76)
    TC.drawRight(self, "$" .. unit,             w - 92,  ty, UIFont.Small, 0.62, 0.62, 0.66)
    TC.drawRight(self, "$" .. (unit * line.qty), w - 4,  ty, UIFont.Small, 0.78, 0.96, 0.78)

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
    o.minimumWidth = 560
    o.minimumHeight = 420
    return o
end

function TC_CartWindow:listGeometry()
    local listY = self:titleBarHeight() + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - BUTTON_HGT - PAD
                  - FONT_HGT_LARGE - FONT_HGT_SMALL - PAD
    return listY, listH
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

    local by = self.height - BOTTOM_PAD - BUTTON_HGT
    local third = (self.width - PAD * 4) / 3

    self.removeBtn = ISButton:new(PAD, by, third, BUTTON_HGT,
                                  getText("IGUI_TC_RemoveSelected"), self, TC_CartWindow.onRemove)
    self.removeBtn:initialise(); self.removeBtn:instantiate()
    self:addChild(self.removeBtn)

    self.clearBtn = ISButton:new(PAD * 2 + third, by, third, BUTTON_HGT,
                                 getText("IGUI_TC_ClearAll"), self, TC_CartWindow.onClear)
    self.clearBtn:initialise(); self.clearBtn:instantiate()
    self:addChild(self.clearBtn)

    self.checkoutBtn = ISButton:new(PAD * 3 + third * 2, by, third, BUTTON_HGT,
                                    getText("IGUI_TC_Checkout"), self, TC_CartWindow.onCheckout)
    self.checkoutBtn:initialise(); self.checkoutBtn:instantiate()
    self:addChild(self.checkoutBtn)

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

function TC_CartWindow:setMessage(text, isError)
    self.message = text
    self.messageIsError = isError and true or false
end

--[[ Everything that can REFUSE the order is checked here, before the action starts,
     so the player hears about it immediately rather than after standing still. The
     charge and the delivery happen in onOrderComplete.

     A cart order takes the same interruptible time as a single purchase. It used to
     complete instantly, which made the cart the fast way to shop mid-fight and turned
     the order action into a pointless tax on buying one thing at a time. ]]
function TC_CartWindow:onCheckout()
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

    if TC.getBalance(self.player) < select(1, self:totals()) then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    local seconds = TC.opt("OrderSeconds")
    if type(seconds) ~= "number" or seconds <= 0 then
        self:onOrderComplete()
        return
    end

    self:setMessage(getText("IGUI_TC_Ordering"), false)
    ISTimedActionQueue.add(TC_OrderAction:new(self.player, self, nil, seconds))
end

function TC_CartWindow:onOrderCancelled()
    self:setMessage(getText("IGUI_TC_OrderCancelled"), true)
end

function TC_CartWindow:onOrderComplete()
    local cart = self:cart()
    if #cart == 0 then return end

    -- Re-priced and re-checked after the action: seconds passed, and the player may
    -- have spent money or had the cart changed underneath them.
    local total = select(1, self:totals())

    if TC.getBalance(self.player) < total then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end
    if not TC.takeCash(self.player, total) then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
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
    local function hr(text, right)
        local w = getTextManager():MeasureStringX(F, text)
        self:drawText(text, PAD + listW - right - w, hy, 0.72, 0.72, 0.76, 1, F)
    end
    hr(getText("IGUI_TC_Quantity"), 176)
    hr(getText("IGUI_TC_UnitPrice"), 92)
    hr(getText("IGUI_TC_Total"), 4)

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

    if self.message then
        local msg = TC.truncate(UIFont.Small, self.message, listW)
        local my = footY + FONT_HGT_LARGE + 6
        if self.messageIsError then
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
    local third = (self.width - PAD * 4) / 3
    self.removeBtn:setX(PAD);                   self.removeBtn:setY(by);   self.removeBtn:setWidth(third)
    self.clearBtn:setX(PAD * 2 + third);        self.clearBtn:setY(by);    self.clearBtn:setWidth(third)
    self.checkoutBtn:setX(PAD * 3 + third * 2); self.checkoutBtn:setY(by); self.checkoutBtn:setWidth(third)
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
