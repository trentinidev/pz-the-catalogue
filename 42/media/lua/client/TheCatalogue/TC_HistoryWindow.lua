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
    if stops then return stops.when, stops.kind, stops.what end

    local tm  = getTextManager()
    local F   = UIFont.Small
    local gap = 16

    local whenW = tm:MeasureStringX(F, "1993-07-20 00:00")
    local kindW = math.max(tm:MeasureStringX(F, getText("IGUI_TC_LedgerBought")),
                           tm:MeasureStringX(F, getText("IGUI_TC_LedgerSold")))

    stops = { when = 12 }
    stops.kind = stops.when + whenW + gap
    stops.what = stops.kind + kindW + gap
    return stops.when, stops.kind, stops.what
end

TC_HistoryList = ISScrollingListBox:derive("TC_HistoryList")

function TC_HistoryList:doDrawItem(y, item, alt)
    local e = item.item
    local w = self:getWidth()

    if self.selected == item.index then
        self:drawRect(0, y, w, ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.22, 1, 1, 1)

    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    local whenX, kindX, whatX = columnStops()

    -- Bought and sold are told apart by colour and by the sign on the figure, not by a
    -- word, so the column stays narrow and the direction reads at a glance.
    local isBuy = (e.kind == "buy")
    local r, g, b = 0.95, 0.72, 0.6            -- money going out
    local sign = "-"
    if not isBuy then r, g, b = 0.72, 0.95, 0.76; sign = "+" end

    self:drawText(e.when or "?", whenX, ty, 0.6, 0.6, 0.64, 1, UIFont.Small)

    local label = isBuy and getText("IGUI_TC_LedgerBought") or getText("IGUI_TC_LedgerSold")
    self:drawText(label, kindX, ty, 0.72, 0.72, 0.76, 1, UIFont.Small)

    -- The amount column is right-aligned, so the description stops short of it.
    self:drawText(TC.truncate(UIFont.Small, e.summary or "", w - whatX - 90),
                  whatX, ty, 0.86, 0.86, 0.9, 1, UIFont.Small)

    TC.drawRight(self, sign .. "$" .. (e.total or 0), w - 4, ty, UIFont.Small, r, g, b)

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
    o.minimumWidth = 620
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

    local listY, listH = self:listGeometry()
    local listW = self.width - PAD * 2
    local headerY = listY - HEADER_HGT

    self:drawRect(PAD, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(PAD, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local F = UIFont.Small
    local whenX, _, whatX = columnStops()
    self:drawText(getText("IGUI_TC_LedgerWhen"), PAD + whenX, hy, 0.72, 0.72, 0.76, 1, F)
    self:drawText(getText("IGUI_TC_LedgerWhat"), PAD + whatX, hy, 0.72, 0.72, 0.76, 1, F)

    local amt = getText("IGUI_TC_LedgerAmount")
    local aw = getTextManager():MeasureStringX(F, amt)
    self:drawText(amt, PAD + listW - aw - 4, hy, 0.72, 0.72, 0.76, 1, F)

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
