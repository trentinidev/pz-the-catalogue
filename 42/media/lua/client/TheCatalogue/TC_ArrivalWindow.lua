--[[ The Catalogue -- taking delivery.

     A delivery used to land the instant its clock ran out, wherever the player
     happened to be: mid-fight, mid-swim, halfway up a rope. The parcel went on the
     ground at that spot and the player found out from a line of halo text, by which
     time they were usually somewhere else.

     So the van waits. When an order arrives this window opens and says what is in it,
     and nothing is spawned until the player presses Receive. Until then the order sits
     in the pending list on modData, which means it survives a save, a crash and a quit
     -- the goods cannot be lost by not being ready for them.

     Closing this window is not refusing the delivery. Everything waiting stays waiting;
     the ledger shows it as ready to collect and the catalogue's right-click menu grows
     a Collect entry until it has been taken.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
local ROW_HGT    = 28
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12

--[[ One measured stop, for the same reason as everywhere else here: a fixed pixel
     offset only holds at the font size it was written against. Cached on first use
     rather than at load, because it is measured from a translated string. ]]
local qtyW
local function quantityWidth()
    if not qtyW then
        local tm = getTextManager()
        qtyW = math.max(tm:MeasureStringX(UIFont.Small, getText("IGUI_TC_Quantity")),
                        tm:MeasureStringX(UIFont.Small, "999")) + TC.UI.CELL_PAD * 2
    end
    return qtyW
end

-- ---------------------------------------------------------------------------

TC_ArrivalList = ISScrollingListBox:derive("TC_ArrivalList")

function TC_ArrivalList:doDrawItem(y, item, alt)
    local line = item.item
    local w = self:getWidth()

    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)

    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    local rightEdge = w - TC.UI.SCROLL_GUTTER
    local qtyLeft   = rightEdge - quantityWidth()

    self:drawRect(qtyLeft, y, 1, ROW_HGT - 1, 0.22, 1, 1, 1)

    self:drawText(TC.truncate(UIFont.Small, line.name or "?", qtyLeft - 12 - TC.UI.CELL_PAD),
                  12, ty, 0.92, 0.92, 0.95, 1, UIFont.Small)
    TC.drawRight(self, tostring(line.qty or 1), rightEdge, ty, UIFont.Small, 0.78, 0.96, 0.78)

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
    o.minimumWidth = math.max(420, PAD * 2 + 200 + quantityWidth() + TC.UI.SCROLL_GUTTER)
    o.minimumHeight = 300
    return o
end

function TC_ArrivalWindow:listGeometry()
    local listY = self:titleBarHeight() + PAD + FONT_HGT_MEDIUM + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - BUTTON_HGT - PAD - FONT_HGT_SMALL - PAD
    return listY, listH
end

function TC_ArrivalWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local listY, listH = self:listGeometry()
    self.list = TC_ArrivalList:new(PAD, listY, self.width - PAD * 2, listH)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self:addChild(self.list)

    local slots = self:buttonSlots()
    local by = self.height - BOTTOM_PAD - BUTTON_HGT

    self.receiveBtn = ISButton:new(slots[1].x, by, slots[1].w, BUTTON_HGT,
                                   slots[1].text, self, TC_ArrivalWindow.onReceive)
    self.receiveBtn:initialise(); self.receiveBtn:instantiate()
    self:addChild(self.receiveBtn)

    self:refreshList()
end

--[[ One button, laid out the same way as every other row in the mod so it is sized by
     its own label rather than by the window. ]]
function TC_ArrivalWindow:buttonSlots()
    return TC.buttonRow(PAD, self.width - PAD * 2,
                        { getText("IGUI_TC_Receive") }, UIFont.Medium)
end

--[[ Everything waiting, merged into one list.

     Two orders that both contain nails are one line of nails here. The player is being
     asked "do you want this", not "which van did this come off", and splitting the
     answer by order would only make the list longer. ]]
function TC_ArrivalWindow:refreshList()
    self.list:clear()

    local merged, order = {}, {}
    for _, o in ipairs(TC.arrivedOrders(self.player)) do
        for _, l in ipairs(o.lines or {}) do
            local key = l.fullType or l.name
            if merged[key] then
                merged[key].qty = merged[key].qty + (l.qty or 1)
            else
                merged[key] = { name = l.name, qty = l.qty or 1, weight = l.weight or 0 }
                table.insert(order, key)
            end
        end
    end

    for _, key in ipairs(order) do
        self.list:addItem(merged[key].name, merged[key])
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

    local listY, listH = self:listGeometry()
    local listW = self.width - PAD * 2
    local F = UIFont.Small

    local titleY = self:titleBarHeight() + PAD
    self:drawText(getText("IGUI_TC_ArrivalHeadline"), PAD, titleY,
                  0.85, 1, 0.85, 1, UIFont.Medium)

    local headerY = listY - HEADER_HGT
    self:drawRect(PAD, headerY, listW, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(PAD, headerY, listW, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local rightEdge = listW - TC.UI.SCROLL_GUTTER
    self:drawRect(PAD + rightEdge - quantityWidth(), headerY, 1, HEADER_HGT, 0.4, 1, 1, 1)
    self:drawText(getText("IGUI_TC_ColItem"), PAD + 12, hy, 0.72, 0.72, 0.76, 1, F)
    TC.drawRight(self, getText("IGUI_TC_Quantity"), PAD + rightEdge, hy, F, 0.72, 0.72, 0.76)

    local count, weight = self:totals()
    local footY = listY + listH + PAD

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local r, g, b = 0.6, 1, 0.6
        if msgErr then r, g, b = 1, 0.3, 0.3 end
        self:drawText(TC.truncate(F, msgText, listW), PAD, footY, r, g, b, 1, F)
    else
        self:drawText(getText("IGUI_TC_ArrivalSummary", count, string.format("%.1f", weight)),
                      PAD, footY, 0.62, 0.62, 0.66, 1, F)
    end
end

function TC_ArrivalWindow:onResize()
    ISCollapsableWindow.onResize(self)

    local listY, listH = self:listGeometry()
    self.list:setWidth(self.width - PAD * 2)
    self.list:setHeight(listH)

    local slots = self:buttonSlots()
    self.receiveBtn:setX(slots[1].x)
    self.receiveBtn:setY(self.height - BOTTOM_PAD - BUTTON_HGT)
    self.receiveBtn:setWidth(slots[1].w)
    self.receiveBtn:setTitle(slots[1].text)
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
