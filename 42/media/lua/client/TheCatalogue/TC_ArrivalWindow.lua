--[[ The Catalogue -- taking delivery.

     A delivery used to land the instant its clock ran out, wherever the player
     happened to be: mid-fight, mid-swim, halfway up a rope. The parcel went on the
     ground at that spot and the player found out from a line of halo text, by which
     time they were usually somewhere else.

     So the van waits. When an order arrives this window opens and says what is in it,
     and nothing is spawned until the player presses Receive. Until then the order sits
     in the pending list on modData, which means it survives a save, a crash and a quit
     -- the goods cannot be lost by not being ready for them.

     IT HAS NO CLOSE BUTTON. Every other window here is a tool the player opens and
     dismisses; this one is a question, and the answer is Receive. It can be collapsed
     out of the way with the arrow in its title bar -- that is what the arrow is for --
     but the only thing that makes it go away is taking the delivery. A window that can
     be dismissed without answering is a window that leaves goods in limbo with no
     obvious way back to them.

     It is also laid out on a centre line rather than flush left like the working
     windows. There is one question and one answer on it, so everything -- the
     headline, the table, the tally, the button -- is balanced about the middle, with
     equal margins on both sides.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12

-- The same row height and icon size as the catalogue, so a delivery reads as a page
-- from the same book rather than a different widget that happens to list items.
local ROW_HGT = TC.UI.ROW_HGT
local ICON    = TC.UI.ICON

-- Equal on both sides of the table, so the columns sit inside a symmetric frame. The
-- right-hand one has to clear the scrollbar, so the left one matches it rather than
-- using the smaller cell padding and leaving the table looking shifted.
local INSET = TC.UI.SCROLL_GUTTER

--[[ The quantity column, measured once. A fixed pixel width only holds at the font
     size it was written against; this is measured from the heading and from the widest
     number a delivery can plausibly show. Worked out on first use, not at load,
     because it reads a translated string. ]]
local qtyW
local function quantityWidth()
    if not qtyW then
        local tm = getTextManager()
        qtyW = math.max(tm:MeasureStringX(UIFont.Small, getText("IGUI_TC_Quantity")),
                        tm:MeasureStringX(UIFont.Small, "9999")) + TC.UI.CELL_PAD * 2
    end
    return qtyW
end

--[[ The two column bands, given the list's pixel width. One definition, used by the
     header and by every row, so a heading cannot drift away from the values under it. ]]
local function columns(listW)
    local qty = quantityWidth()
    local qtyLeft  = listW - INSET - qty
    local nameLeft = INSET + ICON + TC.UI.CELL_PAD
    return {
        iconLeft  = INSET,
        nameLeft  = nameLeft,
        nameW     = qtyLeft - nameLeft - TC.UI.CELL_PAD,
        qtyLeft   = qtyLeft,
        qtyW      = qty,
        ruleX     = math.floor(qtyLeft - TC.UI.CELL_PAD / 2),
    }
end

--[[ The item's own icon, resolved once per line and remembered.

     Same trick as TC.entryIcon: a failed lookup is stored as FALSE rather than left
     nil, so a modded item whose texture cannot be found is asked about once instead of
     once per frame for as long as the window is open. ]]
local function lineIcon(line)
    if line.icon == nil then
        local script = line.fullType and getScriptManager():FindItem(line.fullType)
        line.icon = (script and script:getNormalTexture()) or false
    end
    if line.icon == false then return nil end
    return line.icon
end

-- ---------------------------------------------------------------------------

TC_ArrivalList = ISScrollingListBox:derive("TC_ArrivalList")

function TC_ArrivalList:doDrawItem(y, item, alt)
    local line = item.item
    local w = self:getWidth()
    local c = columns(w)
    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2

    -- A rail under the row and a rule between the columns, the same grid the catalogue
    -- and the ledger use, so a record reads across and a column reads down.
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)
    self:drawRect(c.ruleX, y, 1, ROW_HGT - 1, 0.22, 1, 1, 1)

    local icon = lineIcon(line)
    if icon then
        self:drawTextureScaledAspect(icon, c.iconLeft, y + (ROW_HGT - ICON) / 2,
                                     ICON, ICON, 1, 1, 1, 1)
    end

    self:drawText(TC.truncate(UIFont.Small, line.name or "?", c.nameW),
                  c.nameLeft, ty, 0.92, 0.92, 0.95, 1, UIFont.Small)
    TC.drawCentred(self, tostring(line.qty or 1), c.qtyLeft, c.qtyW, ty,
                   UIFont.Small, 0.78, 0.96, 0.78)

    return y + ROW_HGT
end

-- ---------------------------------------------------------------------------

TC_ArrivalWindow = ISCollapsableWindow:derive("TC_ArrivalWindow")
TC_ArrivalWindow.instances = TC_ArrivalWindow.instances or {}

function TC_ArrivalWindow:new(x, y, w, h, playerNum)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o:setResizable(true)
    -- Both margins, the icon column, a readable stretch of name and the quantity: the
    -- window cannot be dragged narrower than the table it frames.
    o.minimumWidth = math.max(440, PAD * 2 + INSET * 2 + ICON + TC.UI.CELL_PAD
                                   + 200 + quantityWidth())
    o.minimumHeight = 320
    return o
end

--[[ The vertical stack, worked out in one place.

     Headline, table, tally, button, each with the same gap between them. Written as a
     single walk down the window so the blocks cannot drift apart the way two separate
     copies of the arithmetic would. ]]
function TC_ArrivalWindow:layout()
    local L = {}
    L.headlineY = self:titleBarHeight() + PAD
    L.headerY   = L.headlineY + FONT_HGT_MEDIUM + PAD
    L.listY     = L.headerY + HEADER_HGT
    L.buttonY   = self.height - BOTTOM_PAD - BUTTON_HGT
    L.footY     = L.buttonY - PAD - FONT_HGT_SMALL
    L.listH     = L.footY - PAD - L.listY
    L.listX     = PAD
    L.listW     = self.width - PAD * 2
    return L
end

--[[ Two buttons, sized by their own labels and centred as a pair.

     Receive and Deny are the same decision answered two ways, so they sit together on the
     centre line rather than at opposite ends of the window. Deny is the smaller of the
     two and is not styled to invite a click: taking the delivery is the ordinary answer,
     turning it away costs a quarter of what you paid. ]]
function TC_ArrivalWindow:buttonSlots()
    local tm = getTextManager()
    local receiveW = math.max(150, tm:MeasureStringX(UIFont.Medium, getText("IGUI_TC_Receive")) + TC.UI.BTN_PAD * 2)
    local denyW    = math.max(110, tm:MeasureStringX(UIFont.Medium, getText("IGUI_TC_Deny")) + TC.UI.BTN_PAD * 2)
    local gap = PAD
    local total = receiveW + gap + denyW

    if total > self.width - PAD * 2 then
        local scale = (self.width - PAD * 2 - gap) / (receiveW + denyW)
        receiveW = math.floor(receiveW * scale)
        denyW    = math.floor(denyW * scale)
        total    = receiveW + gap + denyW
    end

    local x = math.floor((self.width - total) / 2)
    return { x = x, w = math.floor(receiveW) },
           { x = x + math.floor(receiveW) + gap, w = math.floor(denyW) }
end

function TC_ArrivalWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    -- No way out but Receive. minTitleBarWidth already accounts for an invisible close
    -- button, so hiding it is enough -- the title simply centres over the space.
    if self.closeButton then self.closeButton:setVisible(false) end

    local L = self:layout()
    self.list = TC_ArrivalList:new(L.listX, L.listY, L.listW, L.listH)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self:addChild(self.list)

    local receive, deny = self:buttonSlots()

    self.receiveBtn = ISButton:new(receive.x, L.buttonY, receive.w, BUTTON_HGT,
                                   getText("IGUI_TC_Receive"), self, TC_ArrivalWindow.onReceive)
    self.receiveBtn:initialise(); self.receiveBtn:instantiate()
    self:addChild(self.receiveBtn)

    self.denyBtn = ISButton:new(deny.x, L.buttonY, deny.w, BUTTON_HGT,
                                getText("IGUI_TC_Deny"), self, TC_ArrivalWindow.onDeny)
    self.denyBtn:initialise(); self.denyBtn:instantiate()
    self.denyBtn.backgroundColor = { r = 0.34, g = 0.14, b = 0.14, a = 0.9 }
    -- The price of refusing, said before the click rather than after it.
    self.denyBtn:setTooltip(getText("IGUI_TC_DenyTooltip",
                                    math.floor(TC.DENY_REFUND * 100 + 0.5)))
    self:addChild(self.denyBtn)

    self:refreshList()
end

--[[ Everything waiting, merged into one list.

     Two orders that both contain nails are one line of nails here. The player is being
     asked "do you want this", not "which van did this come off", and splitting the
     answer by order would only make the list longer. ]]
function TC_ArrivalWindow:refreshList()
    self.list:clear()

    local merged, seen = {}, {}
    for _, o in ipairs(TC.arrivedOrders(self.player)) do
        for _, l in ipairs(o.lines or {}) do
            local key = l.fullType or l.name
            if seen[key] then
                seen[key].qty = seen[key].qty + (l.qty or 1)
            else
                seen[key] = { fullType = l.fullType, name = l.name,
                              qty = l.qty or 1, weight = l.weight or 0 }
                table.insert(merged, seen[key])
            end
        end
    end

    for _, line in ipairs(merged) do
        self.list:addItem(line.name, line)
    end
end

function TC_ArrivalWindow:totals()
    local count, weight = 0, 0
    for _, entry in ipairs(self.list.items) do
        local line = entry.item
        count  = count + (line.qty or 1)
        weight = weight + (line.weight or 0) * (line.qty or 1)
    end
    return count, weight
end

function TC_ArrivalWindow:onReceive()
    local collected, parcels = TC.collectOrders(self.player)

    -- nil means there was nowhere to put anything down -- mid-load, most likely. The
    -- delivery is untouched, so saying so and leaving the window open is the whole fix.
    if not collected then
        self:setMessage(getText("IGUI_TC_ReceiveNoRoom"), true)
        return
    end

    HaloTextHelper.addGoodText(self.player, getText("IGUI_TC_Received", parcels))
    self:close()
end


--[[ Turn the delivery away. Three quarters back, and the quarter is the point.

     No confirmation dialog. The refund is stated on the button's own tooltip and in the
     ledger afterwards, the loss is a quarter rather than everything, and a mod that stops
     to ask "are you sure" on every irreversible click teaches people to dismiss the
     question rather than read it.
]]
function TC_ArrivalWindow:onDeny()
    local denied, refund = TC.denyArrived(self.player)
    if denied == 0 then
        self:setMessage(getText("IGUI_TC_DenyNothing"), true)
        return
    end

    HaloTextHelper.addGoodText(self.player, getText("IGUI_TC_Denied", refund))
    self:close()
end
function TC_ArrivalWindow:prerender()
    ISCollapsableWindow.prerender(self)

    -- A second delivery can land while this window is open. Rebuilding when the count
    -- moves keeps the list honest without rebuilding it every frame.
    local waiting = TC.arrivedCount(self.player)
    if waiting ~= self.lastWaiting then
        self.lastWaiting = waiting
        self:refreshList()
    end

    -- Nothing left to collect: the player took delivery from somewhere else, or the
    -- save was loaded without it. Closing beats sitting there empty.
    if waiting == 0 then
        self:close()
        return
    end

    local L = self:layout()
    local F = UIFont.Small
    local c = columns(L.listW)

    TC.drawCentred(self, getText("IGUI_TC_ArrivalHeadline"), 0, self.width, L.headlineY,
                   UIFont.Medium, 0.85, 1, 0.85)

    self:drawRect(L.listX, L.headerY, L.listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(L.listX, L.headerY, L.listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = L.headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    self:drawRect(L.listX + c.ruleX, L.headerY, 1, HEADER_HGT, 0.4, 1, 1, 1)
    -- Over the NAMES, not over the icon column, so the heading marks the column it
    -- actually labels.
    self:drawText(getText("IGUI_TC_ColItem"), L.listX + c.nameLeft, hy,
                  0.72, 0.72, 0.76, 1, F)
    TC.drawCentred(self, getText("IGUI_TC_Quantity"), L.listX + c.qtyLeft, c.qtyW, hy,
                   F, 0.72, 0.72, 0.76)

    -- A rule under the table, the same width as the table, so the tally below reads as
    -- a summary of it rather than as another line of it.
    self:drawRect(L.listX, L.footY - PAD / 2, L.listW, 1, 0.3, 1, 1, 1)

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local r, g, b = 0.6, 1, 0.6
        if msgErr then r, g, b = 1, 0.3, 0.3 end
        TC.drawCentred(self, TC.truncate(F, msgText, L.listW), 0, self.width, L.footY,
                       F, r, g, b)
    else
        local count, weight = self:totals()
        TC.drawCentred(self,
                       getText("IGUI_TC_ArrivalSummary", count, string.format("%.1f", weight)),
                       0, self.width, L.footY, F, 0.62, 0.62, 0.66)
    end
end

function TC_ArrivalWindow:onResize()
    ISCollapsableWindow.onResize(self)

    local L = self:layout()
    self.list:setX(L.listX)
    self.list:setY(L.listY)
    self.list:setWidth(L.listW)
    self.list:setHeight(L.listH)

    local receive, deny = self:buttonSlots()
    self.receiveBtn:setX(receive.x); self.receiveBtn:setY(L.buttonY); self.receiveBtn:setWidth(receive.w)
    self.denyBtn:setX(deny.x);       self.denyBtn:setY(L.buttonY);    self.denyBtn:setWidth(deny.w)
end

function TC_ArrivalWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_ArrivalWindow.instances[self.playerNum] = nil
end

TC.applyMessageBehaviour(TC_ArrivalWindow)

--[[ Open it, or bring the existing one forward. Never opens empty: with nothing
     waiting there is nothing to say, and a window that opens to tell you so is worse
     than no window. ]]
function TC.openArrivalWindow(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player or TC.arrivedCount(player) == 0 then return nil end

    local existing = TC_ArrivalWindow.instances[playerNum]
    if existing then
        existing:refreshList()
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local w = math.min(520, getCore():getScreenWidth() - 80)
    local h = math.min(400, getCore():getScreenHeight() - 80)
    local win = TC_ArrivalWindow:new((getCore():getScreenWidth() - w) / 2,
                                     (getCore():getScreenHeight() - h) / 2,
                                     w, h, playerNum)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_ArrivalTitle"))
    win:addToUIManager()
    TC_ArrivalWindow.instances[playerNum] = win
    return win
end
