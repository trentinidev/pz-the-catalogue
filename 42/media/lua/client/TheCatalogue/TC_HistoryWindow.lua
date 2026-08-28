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
local ROW_HGT    = 30
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
                           "IGUI_TC_LedgerPending" }) do
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
    if e.pending then label = getText("IGUI_TC_LedgerPending")
    elseif isBuy then label = getText("IGUI_TC_LedgerBought")
    else label = getText("IGUI_TC_LedgerSold") end
    self:drawText(label, c.kind, ty, 0.72, 0.72, 0.76, 1, UIFont.Small)

    -- What is the elastic column: it gives up whatever the fixed ones need, so the
    -- figure on the right is never the thing that gets cut.
    self:drawText(TC.truncate(UIFont.Small, e.summary or "", amountLeft - c.what - TC.UI.CELL_PAD),
                  c.what, ty, 0.86, 0.86, 0.9, 1, UIFont.Small)

    TC.drawRight(self, sign .. "$" .. (e.total or 0), rightEdge, ty, UIFont.Small, r, g, b)

    return y + ROW_HGT
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

    -- Wide enough for the three fixed columns plus a readable stretch of What, so the
    -- elastic column can never be squeezed out of existence by a drag.
    local c = columnStops()
    o.minimumWidth = math.max(620, PAD * 2 + c.what + 200 + c.amount + TC.UI.SCROLL_GUTTER)
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
    self.list = TC_HistoryList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self:addChild(self.list)

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
    for _, order in ipairs(TC.orders(self.player)) do
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
        self.list:addItem(e.when or "", e)
    end
end

function TC_HistoryWindow:prerender()
    ISCollapsableWindow.prerender(self)

    -- The countdown redraws itself every frame, but a delivered order has to LEAVE the
    -- list, and that only happens on a rebuild. Watching the pending count is enough:
    -- it is the only thing that changes the rows while the window sits open.
    local pending = TC.pendingCount(self.player)
    if pending ~= self.lastPending then
        self.lastPending = pending
        self:refreshList()
    end

    local listY, listH = self:listGeometry()
    local listW = self.width - PAD * 2
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
    self:drawText(getText("IGUI_TC_LedgerWhat"), PAD + c.what, hy, 0.72, 0.72, 0.76, 1, F)

    -- Through the same helper the rows use, so the heading sits over its own figures.
    TC.drawRight(self, getText("IGUI_TC_LedgerAmount"), PAD + rightEdge, hy, F, 0.72, 0.72, 0.76)

    if #self.list.items == 0 then
        local hint = getText("IGUI_TC_LedgerEmpty")
        local hw = getTextManager():MeasureStringX(UIFont.Medium, hint)
        self:drawText(hint, (self.width - hw) / 2, listY + listH / 2 - FONT_HGT_MEDIUM,
                      0.6, 0.6, 0.64, 1, UIFont.Medium)
    end

    self:drawText(getText("IGUI_TC_LedgerCount", #self.list.items),
                  PAD, self.height - BOTTOM_PAD - FONT_HGT_SMALL,
                  0.6, 0.6, 0.64, 1, UIFont.Small)
end

function TC_HistoryWindow:onResize()
    ISCollapsableWindow.onResize(self)
    local listY, listH = self:listGeometry()
    self.list:setWidth(self.width - PAD * 2)
    self.list:setHeight(listH)
end

function TC_HistoryWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_HistoryWindow.instances[self.playerNum] = nil
end

function TC.openHistoryWindow(playerNum)
    local existing = TC_HistoryWindow.instances[playerNum]
    if existing then
        existing:refreshList()
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local w = math.min(760, getCore():getScreenWidth() - 80)
    local h = math.min(480, getCore():getScreenHeight() - 80)
    local win = TC_HistoryWindow:new((getCore():getScreenWidth() - w) / 2,
                                     (getCore():getScreenHeight() - h) / 2,
                                     w, h, playerNum)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_LedgerTitle"))
    win:addToUIManager()
    TC_HistoryWindow.instances[playerNum] = win
    return win
end
