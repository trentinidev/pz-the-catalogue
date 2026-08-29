--[[ The Catalogue -- the ledger of what you bought and sold.

     One row per completed transaction, newest first, with the lines of that
     transaction underneath it. Read-only by design: this is a receipt book, not a
     control surface, and nothing here can change the world.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
-- 34, not 30, so a 26px inventory icon has the same breathing room it gets in the buy
-- list. The icon size is the fixed thing here; the row follows it.
local ROW_HGT    = 34
local ICON       = TC.UI.ICON
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12

--[[ Column positions, measured rather than assumed.

     These were hardcoded at 12 / 150 / 238, which held only at the font size I happened
     to have. At a larger UI scale the timestamp ran straight through the Bought/Sold
     label and that through the description: "1993-07-20 1B0o0ught1 x Apple".

     Measured off the widest real content each column can hold -- a full timestamp, and
     the longer of the two direction words -- so the columns cannot collide at any scale.

     Worked out on FIRST USE, not at file load. One of the widths is measured from a
     translated string, and translations are not guaranteed to be loaded at the moment
     this file is read; measuring then would size the column against a raw key. Cached
     after the first call, because the font does not change mid-session. ]]
local stops
local function columnStops()
    if stops then return stops end

    local tm  = getTextManager()
    local F   = UIFont.Small
    local gap = 16

    local whenW = tm:MeasureStringX(F, "1993-07-20 00:00")
    -- All three words the column can hold. Measuring only two of them is how a column
    -- ends up a few pixels short of the one case nobody checked.
    local kindW = 0
    for _, key in ipairs({ "IGUI_TC_LedgerBought", "IGUI_TC_LedgerSold",
                           "IGUI_TC_LedgerPending", "IGUI_TC_LedgerCanceled",
                           "IGUI_TC_LedgerDenied" }) do
        kindW = math.max(kindW, tm:MeasureStringX(F, getText(key)))
    end

    --[[ The amount column is measured too, and counted back from the right.

         It was a bare 4px offset, which put the figure under the scrollbar: "-$2" drew
         as "-$" with the last character behind the scroll track, and no amount of
         resizing helped because the gutter moves with the edge. Widened to hold the
         largest figure the ledger can show, and pushed clear of the gutter. ]]
    local amountW = tm:MeasureStringX(F, "-$999999") + TC.UI.CELL_PAD * 2

    stops = { when = 12 }
    stops.kind   = stops.when + whenW + gap
    stops.what   = stops.kind + kindW + gap
    stops.amount = amountW
    return stops
end


--[[ Where the cancel button sits on a row: a small square tucked inside the left edge
     of the Amount column, vertically centred.

     One function, used by both the drawing and the hit test, because a button you can see
     in one place and click in another is worse than no button. ]]
local function cancelRect(listW, rowY)
    local size = math.min(ROW_HGT - 10, 14)
    local c = columnStops()
    local x = listW - TC.UI.SCROLL_GUTTER - c.amount + 2
    return x, rowY + math.floor((ROW_HGT - size) / 2), size
end

TC_HistoryList = ISScrollingListBox:derive("TC_HistoryList")

function TC_HistoryList:doDrawItem(y, item, alt)
    local e = item.item
    local w = self:getWidth()

    if self.selected == item.index then
        self:drawRect(0, y, w, ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end

    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    local c = columnStops()

    -- Everything to the right of the list is the scrollbar's, so the amount stops
    -- short of it rather than under it.
    local rightEdge  = w - TC.UI.SCROLL_GUTTER
    local amountLeft = rightEdge - c.amount

    -- Same grid as the catalogue: a rail under each row and a rule between each
    -- column, so a record reads across and a column reads down.
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)
    for _, x in ipairs({ c.kind - 8, c.what - 8, amountLeft }) do
        self:drawRect(x, y, 1, ROW_HGT - 1, 0.22, 1, 1, 1)
    end

    -- Bought and sold are told apart by colour and by the sign on the figure, not by a
    -- word, so the column stays narrow and the direction reads at a glance. A pending
    -- order is amber: paid for, not yet in hand.
    local isBuy = (e.kind == "buy") or e.pending
    local r, g, b = 0.95, 0.72, 0.6            -- money going out
    local sign = "-"
    if e.pending then
        r, g, b = 0.95, 0.82, 0.45
    elseif not isBuy then
        r, g, b = 0.72, 0.95, 0.76
        sign = "+"
    end

    -- A pending row shows a live countdown; a completed one shows when it happened.
    local when = e.when or "?"
    if e.pending and e.order then
        when = e.order.arrived and getText("IGUI_TC_LedgerReady")
                                or TC.etaShort(TC.hoursLeft(e.order))
    end
    self:drawText(when, c.when, ty, 0.6, 0.6, 0.64, 1, UIFont.Small)

    local label
    if e.kind == "cancel"   then label = getText("IGUI_TC_LedgerCanceled")
    elseif e.kind == "deny" then label = getText("IGUI_TC_LedgerDenied")
    elseif e.pending        then label = getText("IGUI_TC_LedgerPending")
    elseif isBuy            then label = getText("IGUI_TC_LedgerBought")
    else                         label = getText("IGUI_TC_LedgerSold") end
    self:drawText(label, c.kind, ty, 0.72, 0.72, 0.76, 1, UIFont.Small)

    --[[ The cancel button, on rows that can still be called off.

         Only while the order is in transit. Once it is at the door the ledger says "ready
         to collect" and this disappears, because turning it away then is Deny's job and
         costs a quarter -- offering a free X next to a delivery that has already arrived
         would be offering the wrong price for the wrong thing.

         Drawn rather than made an ISButton: the rows of an ISScrollingListBox are painted,
         not built, so a real button would have to be created, moved and destroyed as rows
         scroll. A rect and a hit test in onMouseDown is the whole of it. ]]
    if e.pending and e.order and not e.order.arrived then
        local bx, by, size = cancelRect(w, y)
        local hot = self.cancelHover == item.index
        self:drawRect(bx, by, size, size, hot and 0.95 or 0.7, 0.62, 0.2, 0.2)
        self:drawRectBorder(bx, by, size, size, 0.8, 0.85, 0.5, 0.5)
        -- An X from two rects rather than a glyph, for the same reason as the sort
        -- arrows: the bitmap fonts have no guaranteed coverage and a missing glyph draws
        -- nothing at all, which would leave a blank red square.
        for i = 0, size - 7 do
            self:drawRect(bx + 3 + i, by + 3 + i, 1, 1, 1, 1, 1, 1)
            self:drawRect(bx + size - 4 - i, by + 3 + i, 1, 1, 1, 1, 1, 1)
        end
    end

    --[[ The icon of what the row is about, at the head of the What column.

         A transaction can hold several lines, and this shows the FIRST one's icon: the
         summary beside it already reads "1 x ID Card, 1 x Belt, 1 x Jeans, ...", so the
         picture is a marker for the row rather than a claim about all of it.

         Rows written before 0.10.1 have no fullType on their lines and draw without an
         icon. The ledger keeps two hundred entries, so old rows and new ones share the
         list for a long time -- hence the text indents by the icon whether or not one
         is actually there, so the column does not zigzag down the page. ]]
    local icon = TC.iconFor(e.icon)
    if icon then
        self:drawTextureScaledAspect(icon, c.what, y + (ROW_HGT - ICON) / 2,
                                     ICON, ICON, 1, 1, 1, 1)
    end

    -- What is the elastic column: it gives up whatever the fixed ones need, so the
    -- figure on the right is never the thing that gets cut.
    local textX = c.what + ICON + TC.UI.CELL_PAD
    self:drawText(TC.truncate(UIFont.Small, e.summary or "", amountLeft - textX - TC.UI.CELL_PAD),
                  textX, ty, 0.86, 0.86, 0.9, 1, UIFont.Small)

    TC.drawRight(self, sign .. "$" .. (e.total or 0), rightEdge, ty, UIFont.Small, r, g, b)

    return y + ROW_HGT
end


--[[ A click on the cancel square calls the order off; anything else selects the row.

     The row is worked out from the click's y rather than from self.selected, because
     selection happens in the base class AFTER this returns -- reading it here would
     cancel whichever order was highlighted a moment ago, which is the worst possible
     off-by-one to ship. ]]
function TC_HistoryList:onMouseDown(x, y)
    local index = math.floor((y - self:getYScroll()) / ROW_HGT) + 1
    local entry = self.items[index]
    local e = entry and entry.item

    if e and e.pending and e.order and not e.order.arrived then
        local bx, by, size = cancelRect(self:getWidth(), (index - 1) * ROW_HGT)
        local ry = y - self:getYScroll()
        if x >= bx and x <= bx + size and ry >= by and ry <= by + size then
            local refund = TC.cancelOrder(self.parentWindow.player, e.order)
            if refund then
                self.parentWindow:setMessage(getText("IGUI_TC_OrderCancelled2", refund), false)
                self.parentWindow:refreshList()
            end
            return true
        end
    end

    return ISScrollingListBox.onMouseDown(self, x, y)
end

--[[ Light the square under the cursor, so it reads as something you can press. ]]
function TC_HistoryList:onMouseMove(dx, dy)
    local y = self:getMouseY()
    local index = math.floor((y - self:getYScroll()) / ROW_HGT) + 1
    local entry = self.items[index]
    local e = entry and entry.item
    self.cancelHover = nil

    if e and e.pending and e.order and not e.order.arrived then
        local bx, by, size = cancelRect(self:getWidth(), (index - 1) * ROW_HGT)
        local x, ry = self:getMouseX(), y - self:getYScroll()
        if x >= bx and x <= bx + size and ry >= by and ry <= by + size then
            self.cancelHover = index
        end
    end
    return ISScrollingListBox.onMouseMove(self, dx, dy)
end

function TC_HistoryList:onMouseMoveOutside(dx, dy)
    self.cancelHover = nil
    return ISScrollingListBox.onMouseMoveOutside(self, dx, dy)
end
-- ---------------------------------------------------------------------------

TC_HistoryWindow = ISCollapsableWindow:derive("TC_HistoryWindow")
TC_HistoryWindow.instances = TC_HistoryWindow.instances or {}

function TC_HistoryWindow:new(x, y, w, h, playerNum)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o:setResizable(true)
    o.railW = TC.railWidth()   -- before createChildren asks listGeometry, see TC_BuyWindow

    -- Wide enough for the three fixed columns plus a readable stretch of What, so the
    -- elastic column can never be squeezed out of existence by a drag.
    local c = columnStops()
    o.minimumWidth = TC.railWidth()
                   + math.max(620, PAD * 2 + c.what + ICON + TC.UI.CELL_PAD + 200
                                       + c.amount + TC.UI.SCROLL_GUTTER)
    o.minimumHeight = 380
    return o
end

function TC_HistoryWindow:listGeometry()
    local listY = self:titleBarHeight() + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - FONT_HGT_SMALL - PAD
    return listY, listH
end

function TC_HistoryWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local listY, listH = self:listGeometry()
    self.list = TC_HistoryList:new(PAD, listY, TC.innerW(self) - PAD * 2, listH)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self.list.parentWindow = self
    self:addChild(self.list)

    TC.buildRail(self, "ledger")

    self:refreshList()
end

function TC_HistoryWindow:refreshList()
    self.list:clear()

    --[[ Orders still in flight go at the top, above the completed history.

         They belong here rather than in a window of their own: "what did I buy" and
         "what have I got coming" are the same question asked at different times, and
         splitting them would mean checking two places to answer it. They are marked
         pending and carry an ETA instead of a timestamp, so they cannot be mistaken
         for something that already happened. ]]
    --[[ Soonest first, with anything already waiting at the very top.

         They used to come out in the order they were placed, which put the order
         FURTHEST from arriving at the head of the ledger and one that was ready to
         collect below it -- so an old order sitting eight hours out read like the one
         just placed. A queue should be ordered by when it will be dealt with. ]]
    local pending = {}
    for _, order in ipairs(TC.orders(self.player)) do table.insert(pending, order) end
    table.sort(pending, function(a, b)
        if (a.arrived and true) ~= (b.arrived and true) then return a.arrived and true or false end
        return TC.hoursLeft(a) < TC.hoursLeft(b)
    end)

    for _, order in ipairs(pending) do
        local parts = {}
        for _, line in ipairs(order.lines or {}) do
            table.insert(parts, (line.qty or 1) .. " x " .. (line.name or "?"))
        end
        -- The ORDER is kept, not a formatted time. The countdown is rendered per frame
        -- from it, so an open ledger ticks down from ~8h to ~7h as the hours pass
        -- rather than freezing at whatever it said when the window opened.
        self.list:addItem("", {
            pending = true,
            order   = order,
            total   = order.paid or 0,
            summary = table.concat(parts, ", "),
            icon    = order.lines and order.lines[1] and order.lines[1].fullType,
        })
    end

    for _, e in ipairs(TC.history(self.player)) do
        -- The lines are flattened into one readable string here rather than at write
        -- time, so an old entry saved by an earlier version still renders.
        local parts = {}
        for _, line in ipairs(e.lines or {}) do
            table.insert(parts, (line.qty or 1) .. " x " .. (line.name or "?"))
        end
        e.summary = table.concat(parts, ", ")
        e.icon = e.lines and e.lines[1] and e.lines[1].fullType
        self.list:addItem(e.when or "", e)
    end
end

function TC_HistoryWindow:prerender()
    ISCollapsableWindow.prerender(self)

    TC.refreshRail(self)

    -- The countdown redraws itself every frame, but a delivered order has to LEAVE the
    -- list, and that only happens on a rebuild. Watching the pending count is enough:
    -- it is the only thing that changes the rows while the window sits open.
    local pending = TC.pendingCount(self.player)
    if pending ~= self.lastPending then
        self.lastPending = pending
        self:refreshList()
    end

    local listY, listH = self:listGeometry()
    local listW = TC.innerW(self) - PAD * 2
    local headerY = listY - HEADER_HGT

    self:drawRect(PAD, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(PAD, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local F = UIFont.Small
    local c = columnStops()
    local rightEdge  = listW - TC.UI.SCROLL_GUTTER
    local amountLeft = rightEdge - c.amount

    for _, x in ipairs({ c.kind - 8, c.what - 8, amountLeft }) do
        self:drawRect(PAD + x, headerY, 1, HEADER_HGT, 0.4, 1, 1, 1)
    end
    self:drawText(getText("IGUI_TC_LedgerWhen"), PAD + c.when, hy, 0.72, 0.72, 0.76, 1, F)
    self:drawText(getText("IGUI_TC_LedgerKind"), PAD + c.kind, hy, 0.72, 0.72, 0.76, 1, F)
    -- Over the TEXT, not over the icon, the same way the buy list heads its Item column.
    self:drawText(getText("IGUI_TC_LedgerWhat"), PAD + c.what + ICON + TC.UI.CELL_PAD,
                  hy, 0.72, 0.72, 0.76, 1, F)

    -- Through the same helper the rows use, so the heading sits over its own figures.
    TC.drawRight(self, getText("IGUI_TC_LedgerAmount"), PAD + rightEdge, hy, F, 0.72, 0.72, 0.76)

    if #self.list.items == 0 then
        local hint = getText("IGUI_TC_LedgerEmpty")
        local hw = getTextManager():MeasureStringX(UIFont.Medium, hint)
        self:drawText(hint, (TC.innerW(self) - hw) / 2, listY + listH / 2 - FONT_HGT_MEDIUM,
                      0.6, 0.6, 0.64, 1, UIFont.Medium)
    end

    local footY = self.height - BOTTOM_PAD - FONT_HGT_SMALL
    self:drawText(getText("IGUI_TC_LedgerCount", #self.list.items),
                  PAD, footY, 0.6, 0.6, 0.64, 1, UIFont.Small)

    -- A refund is worth confirming in words: the money lands silently in the inventory
    -- and the row simply vanishes, which on its own looks like the click did nothing.
    local msgText, msgErr = self:activeMessage()
    if msgText then
        local r, g, b = 0.6, 1, 0.6
        if msgErr then r, g, b = 1, 0.3, 0.3 end
        TC.drawRight(self, TC.truncate(UIFont.Small, msgText, listW * 0.7),
                     PAD + listW, footY, UIFont.Small, r, g, b)
    end
end

function TC_HistoryWindow:onResize()
    ISCollapsableWindow.onResize(self)
    local listY, listH = self:listGeometry()
    TC.layoutRail(self)
    self.list:setWidth(TC.innerW(self) - PAD * 2)
    self.list:setHeight(listH)
end

function TC_HistoryWindow:close()
    TC.saveFrame(self)
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_HistoryWindow.instances[self.playerNum] = nil
end


-- Status lines that clear themselves, shared with every other window here.
TC.applyMessageBehaviour(TC_HistoryWindow)
function TC.openHistoryWindow(playerNum)
    local existing = TC_HistoryWindow.instances[playerNum]
    if existing then
        existing:refreshList()
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local x, y, w, h = TC.frameRect(playerNum, 760, 480, TC.railWidth() + 620, 380)
    local win = TC_HistoryWindow:new(x, y, w, h, playerNum)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_LedgerTitle"))
    win:addToUIManager()
    TC_HistoryWindow.instances[playerNum] = win
    return win
end
