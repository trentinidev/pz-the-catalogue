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

-- The spinner block: [-] [entry] [+]. Fixed, so the wishlist button beside it can
-- take whatever is left rather than being squeezed to a width that clips its label.
local SPINNER_W  = 164
local DETAIL_W   = 386
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

    -- A wishlisted row is tinted rather than given a star glyph, for the same reason
    -- the sort arrows are drawn from rects: the bitmap fonts have no guaranteed
    -- coverage for a star, and a missing glyph draws nothing at all.
    local win = self.parentWindow
    local wished = win and TC.isWished(win.player, e.fullType)
    local nr, ng, nb = 1, 1, 1
    if wished then nr, ng, nb = 1, 0.92, 0.6 end

    self:drawText(TC.truncate(UIFont.Medium, e.name, c.nameW),
                  c.nameLeft, textY, nr, ng, nb, 1, UIFont.Medium)

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
    o.cart = {}
    o:setResizable(true)
    o.minimumWidth = 900
    o.minimumHeight = 740
    return o
end

function TC_BuyWindow:listGeometry()
    local top   = self:titleBarHeight() + PAD
    local listW = self.width - DETAIL_W - PAD * 3
    local listY = top + BUTTON_HGT + PAD + HEADER_HGT
    local listH = self.height - listY - BOTTOM_PAD - FONT_HGT_SMALL - PAD
    return top, listW, listY, listH
end

--[[ What TC_Table needs from this window: where the header sits, how tall it is, and
     which heading belongs to which column slot. Everything else -- drawing, sorting,
     divider dragging, the status line -- comes from the mixin at the bottom of this
     file. ]]
--[[ Where the cash figure and the status line start.

     They sit ABOVE the three button rows, and the message needs room of its own under
     the figure -- it carries the delivery estimate, which is the one thing a player
     wants to read straight after ordering. Without counting that height in, the line
     was drawn underneath the top button row and simply never seen: "Ordered 1 x Apple
     - arriving in about 6 hours" rendered behind "Add to cart".

     A method rather than an expression repeated in two places, because it already went
     wrong once that way. ]]
function TC_BuyWindow:cashBlockY()
    return self.height - BOTTOM_PAD - BUTTON_HGT * 3 - PAD * 3
           - FONT_HGT_LARGE - FONT_HGT_SMALL - 8
end

function TC_BuyWindow:tableGeometry()
    local _, listW, listY = self:listGeometry()
    return PAD, listY - HEADER_HGT, listW
end

function TC_BuyWindow:tableHeaderHeight() return HEADER_HGT end

TC_BuyWindow.tableCols = {
    { key = "name",  textKey = "IGUI_TC_ColItem",     align = "left"  },
    { key = "cat",   textKey = "IGUI_TC_ColCategory", align = "left"  },
    { key = "mid",   textKey = "IGUI_TC_ColWeight",   align = "right" },
    { key = "price", textKey = "IGUI_TC_ColPrice",    align = "right" },
}

function TC_BuyWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local top, listW, listY, listH = self:listGeometry()

    self.search = ISTextEntryBox:new("", PAD, top, listW - 400, BUTTON_HGT)
    self.search:initialise()
    self.search:instantiate()
    self.search.onTextChange = function() self:refreshList() end
    self:addChild(self.search)

    -- Quick filter sits between the search and the category, because it answers a
    -- narrower question than either and is the one most likely to be toggled twice in
    -- a row -- "what can I actually afford" then straight back to everything.
    self.quickCombo = ISComboBox:new(PAD + listW - 390, top, 180, BUTTON_HGT,
                                     self, TC_BuyWindow.onCategoryChange)
    self.quickCombo:initialise()
    self.quickCombo:addOption(getText("IGUI_TC_QuickAll"))
    self.quickCombo:addOption(getText("IGUI_TC_QuickAffordable"))
    self.quickCombo:addOption(getText("IGUI_TC_QuickOwned"))
    self.quickCombo:addOption(getText("IGUI_TC_QuickNotOwned"))
    self.quickCombo:addOption(getText("IGUI_TC_QuickWishlist"))
    self.quickCombo.selected = 1
    self:addChild(self.quickCombo)

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

    self.wishBtn = ISButton:new(dx + PAD + SPINNER_W + PAD, by - BUTTON_HGT - PAD,
                                DETAIL_W - PAD * 3 - SPINNER_W, BUTTON_HGT,
                                getText("IGUI_TC_AddToWishlist"), self, TC_BuyWindow.onToggleWish)
    self.wishBtn:initialise(); self.wishBtn:instantiate()
    self:addChild(self.wishBtn)

    -- Middle row: the two ways to spend that are not "buy this one now".
    local half = (DETAIL_W - PAD * 2 - PAD) / 2
    local midY = by - (BUTTON_HGT + PAD) * 2

    self.cartAddBtn = ISButton:new(dx + PAD, midY, half, BUTTON_HGT,
                                   getText("IGUI_TC_AddToCart"), self, TC_BuyWindow.onAddToCart)
    self.cartAddBtn:initialise(); self.cartAddBtn:instantiate()
    self:addChild(self.cartAddBtn)

    self.cartBtn = ISButton:new(dx + PAD + half + PAD, midY, half, BUTTON_HGT,
                                getText("IGUI_TC_OpenCart"), self, TC_BuyWindow.onOpenCart)
    self.cartBtn:initialise(); self.cartBtn:instantiate()
    self:addChild(self.cartBtn)

    -- Two ways to buy, side by side, so the trade-off is visible at the moment of
    -- deciding rather than hidden behind a setting.
    local buyW = (DETAIL_W - PAD * 2 - PAD) * 0.58
    self.buyBtn = ISButton:new(dx + PAD, by, buyW, BUTTON_HGT,
                               getText("IGUI_TC_Buy"), self, TC_BuyWindow.onBuy)
    self.buyBtn:initialise(); self.buyBtn:instantiate()
    self:addChild(self.buyBtn)

    self.rushBtn = ISButton:new(dx + PAD + buyW + PAD, by,
                                DETAIL_W - PAD * 3 - buyW, BUTTON_HGT,
                                getText("IGUI_TC_Rush"), self, TC_BuyWindow.onRush)
    self.rushBtn:initialise(); self.rushBtn:instantiate()
    self:addChild(self.rushBtn)

    self:populateCategories()
    self:refreshList()
end

-- ---------------------------------------------------------------------------
-- Cart
-- ---------------------------------------------------------------------------

--[[ Add the current selection and quantity as a cart line.

     Lines are merged by fullType so adding five nails twice reads as ten nails on one
     line rather than as two lines to reconcile at checkout. Only the fullType, the
     display name and the weight are kept -- the PRICE is deliberately not stored, so
     the cart cannot lock in a stale rate if a sandbox multiplier changes underneath it.
]]
function TC_BuyWindow:onAddToCart()
    local entry = self.selectedEntry
    if not entry then
        self:setMessage(getText("IGUI_TC_SelectAnItem"), true)
        return
    end

    for _, line in ipairs(self.cart) do
        if line.fullType == entry.fullType then
            line.qty = line.qty + self.quantity
            self:setMessage(getText("IGUI_TC_AddedToCart", self.quantity, entry.name), false)
            self:syncCart()
            return
        end
    end

    table.insert(self.cart, {
        fullType = entry.fullType,
        name     = entry.name,
        weight   = entry.weight or 0,
        qty      = self.quantity,
    })
    self:setMessage(getText("IGUI_TC_AddedToCart", self.quantity, entry.name), false)
    self:syncCart()
end

function TC_BuyWindow:onOpenCart()
    TC.openCartWindow(self.playerNum, self)
end

-- Keep an open cart window in step with a line added from here.
function TC_BuyWindow:syncCart()
    local win = TC_CartWindow and TC_CartWindow.instances[self.playerNum]
    if win then win:refreshList() end
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
    local quick = self.quickCombo and self.quickCombo.selected or 1

    -- Both of these are gathered ONCE per refresh and then read per row. Asking the
    -- inventory or the balance per row would turn a filter into ten thousand
    -- recursive walks.
    local owned, balance
    if quick == 3 or quick == 4 then owned = TC.ownedTypes(self.player) end
    if quick == 2 then balance = TC.getBalance(self.player) end
    local wishes = (quick == 5) and TC.wishlist(self.player) or nil

    local filtering = (needle ~= "" or spec.kind ~= "all" or quick ~= 1)

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

            if keep then
                if     quick == 2 then keep = (TC.entryPrice(e) <= balance)
                elseif quick == 3 then keep = (owned[e.fullType] ~= nil)
                elseif quick == 4 then keep = (owned[e.fullType] == nil)
                elseif quick == 5 then keep = (wishes[e.fullType] == true)
                end
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

--[[ ISScrollingListBox calls this as onmousedown(self.target, item.item), so the
     catalogue entry arrives directly -- no need to go back through the selected
     index, which is also briefly stale right after a clear(). ]]
function TC_BuyWindow:onSelectItem(entry)
    --[[ A new selection starts at one.

         The quantity used to carry over, so typing 10 for one item and then clicking a
         different row left the field reading 10 against something you had only just
         looked at -- and Add to cart would take you at your word. Every item is its own
         decision; the number belongs to the thing that was on screen when it was typed.
         Only reset on an actual CHANGE of item, so clicking the same row twice does not
         throw away a quantity that was just entered. ]]
    if entry ~= self.selectedEntry then
        self:setQuantity(1)
    end

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

function TC_BuyWindow:onToggleWish()
    if not self.selectedEntry then return end
    TC.toggleWish(self.player, self.selectedEntry.fullType)

    -- Refresh only when the wishlist itself is what is being shown, otherwise
    -- un-starring an item would make it vanish from under the cursor.
    if self.quickCombo and self.quickCombo.selected == 5 then self:refreshList() end
end

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------

--[[ Pressing Buy no longer resolves on the spot.

     Ordering used to complete the instant the button went down, so a player could kit
     themselves out mid-horde without ever lowering their guard. When the sandbox gives
     the order a duration, this queues a short interruptible action and the real work
     happens in onOrderComplete.

     Everything that could REFUSE the order is checked here, before the action starts,
     so the player is told immediately rather than after standing still for three
     seconds. Nothing is charged until the action completes. ]]
--[[ ISButton calls onclick(target, BUTTON, ...), so a handler wired straight to a
     button receives the button as its first argument. Taking a "rush" flag there made
     every ordinary purchase a rush purchase -- goods arrived instantly and in hand
     instead of in a parcel, and the cart quietly added the surcharge and then refused
     the order for insufficient funds.

     The two button callbacks are now thin and the flag is passed explicitly. ]]
function TC_BuyWindow:onBuy()  self:startPurchase(false) end
function TC_BuyWindow:onRush() self:startPurchase(true)  end

function TC_BuyWindow:startPurchase(rush)
    local entry = self.selectedEntry
    if not entry then
        self:setMessage(getText("IGUI_TC_SelectAnItem"), true)
        return
    end
    if not self.player then return end

    local unit  = TC.getBuyPrice(entry.fullType) or 0
    local total = unit * self.quantity
    if rush then total = total + TC.rushSurcharge(total) end

    if not getScriptManager():FindItem(entry.fullType) then
        TC.warn("refused purchase: unknown item %s", tostring(entry.fullType))
        self:setMessage(getText("IGUI_TC_ItemUnavailable"), true)
        return
    end
    if TC.getBalance(self.player) < total then
        self:setMessage(getText("IGUI_TC_InsufficientFunds"), true)
        return
    end

    local seconds = TC.opt("OrderSeconds")
    if type(seconds) ~= "number" or seconds <= 0 then
        self:onOrderComplete({ entry = entry, qty = self.quantity, rush = rush })
        return
    end

    self:setMessage(getText("IGUI_TC_Ordering"), false)
    ISTimedActionQueue.add(TC_OrderAction:new(self.player, self,
                                              { entry = entry, qty = self.quantity, rush = rush }, seconds))
end

function TC_BuyWindow:onOrderCancelled()
    self:setMessage(getText("IGUI_TC_OrderCancelled"), true)
end

function TC_BuyWindow:onOrderComplete(payload)
    local entry = payload and payload.entry
    if not entry then return end

    local player = self.player
    if not player then return end

    local unit  = TC.getBuyPrice(entry.fullType) or 0
    local qty   = payload.qty or 1
    local total = unit * qty
    local rush  = payload.rush and true or false

    if rush then total = total + TC.rushSurcharge(total) end

    -- Re-checked rather than trusted from before the action: seconds passed, and the
    -- player may have spent or dropped money in the meantime.
    if not getScriptManager():FindItem(entry.fullType) then
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

    local lines = { {
        fullType = entry.fullType, name = entry.name,
        qty = qty, weight = entry.weight or 0, unit = unit,
    } }

    --[[ A normal order is booked and arrives later; only a rush order is handed over
         across the counter. The money is already gone either way, which is what makes
         the order safe to persist: the list holds a debt the catalogue owes, never a
         charge still to come. ]]
    if not rush then
        local order = TC.placeOrder(player, lines, total)
        self:setMessage(getText("IGUI_TC_OrderPlaced", qty, entry.name,
                                TC.etaPhrase(TC.hoursLeft(order))), false)
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
        TC.warn("delivered %d of %d %s -- refunded $%d",
                delivered, qty, tostring(entry.fullType), refund)
        if delivered == 0 then
            self:setMessage(getText("IGUI_TC_ItemUnavailable"), true)
            return
        end
        qty = delivered
    end

    TC.logTransaction(player, "buy", { { name = entry.name, qty = qty } }, total)

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

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Draggable column dividers
-- ---------------------------------------------------------------------------

-- Same slow tick as the sell window: dropping the catalogue shuts the shop, but it is
-- not worth asking the inventory about it sixty times a second.
local CATALOGUE_CHECK_MS = 1000

function TC_BuyWindow:prerender()
    ISCollapsableWindow.prerender(self)

    local now = getTimestampMs()
    if not self.lastCatalogueCheck or (now - self.lastCatalogueCheck) >= CATALOGUE_CHECK_MS then
        self.lastCatalogueCheck = now
        if not TC.hasCatalogue(self.player) then
            self:close()
            return
        end
    end

    local top, listW, listY, listH = self:listGeometry()
    self:drawTableHeader()

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

    -- The wishlist button only makes sense with something selected, and its label has
    -- to say which way it will go.
    if self.wishBtn then
        self.wishBtn:setEnable(entry ~= nil)
        if entry and TC.isWished(self.player, entry.fullType) then
            self.wishBtn:setTitle(getText("IGUI_TC_RemoveFromWishlist"))
        else
            self.wishBtn:setTitle(getText("IGUI_TC_AddToWishlist"))
        end
    end

    if entry then
        local icon = TC.entryIcon(entry)
        if icon then
            self:drawTextureScaledAspect(icon, innerLeft, y, 64, 64, 1, 1, 1, 1)
        end

        local textLeft = innerLeft + 64 + PAD
        local nameW    = innerRight - textLeft
        self:drawText(TC.truncate(UIFont.Large, entry.name, nameW),
                      textLeft, y + 6, 1, 1, 1, 1, UIFont.Large)
        self:drawText(TC.truncate(UIFont.Small, entry.fullType, nameW),
                      textLeft, y + 10 + FONT_HGT_LARGE, 0.55, 0.55, 0.6, 1, UIFont.Small)

        --[[ The rule goes under whichever is taller, the icon or the two lines of text
             beside it.

             It used to be pinned to the icon alone -- 64 plus padding -- on the
             assumption that the name and the fullType under it would always fit in
             that. At a larger UI scale they do not, and the fullType was drawn
             straight through the separator. Measured from both, so the header block
             owns whatever height it actually needs. ]]
        local iconBottom = y + 64
        local textBottom = y + 10 + FONT_HGT_LARGE + FONT_HGT_SMALL
        y = math.max(iconBottom, textBottom) + PAD + 8

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
        local detailFloor = self:cashBlockY() - 4

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
    local blockY = self:cashBlockY()

    self:drawText(getText("IGUI_TC_YourCash"), innerLeft, blockY + 4,
                  0.68, 0.68, 0.72, 1, UIFont.Small)
    local balance = TC.getBalance(self.player)
    local bText = "$" .. balance
    local bw = getTextManager():MeasureStringX(UIFont.Large, bText)
    self:drawText(bText, innerRight - bw, blockY, 0.85, 1, 0.85, 1, UIFont.Large)

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local my = blockY + FONT_HGT_LARGE + 6
        local msg = TC.truncate(UIFont.Small, msgText, DETAIL_W - PAD * 2)
        if msgErr then
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

    self.search:setWidth(listW - 400)
    self.quickCombo:setX(PAD + listW - 390)
    self.categoryCombo:setX(PAD + listW - 210)
    self.list:setWidth(listW)
    self.list:setHeight(listH)

    local dx = self.width - DETAIL_W - PAD
    local by = self.height - BOTTOM_PAD - BUTTON_HGT
    self.minusBtn:setX(dx + PAD);        self.minusBtn:setY(by - BUTTON_HGT - PAD)
    self.qtyEntry:setX(dx + PAD + 40);   self.qtyEntry:setY(by - BUTTON_HGT - PAD)
    self.plusBtn:setX(dx + PAD + 130);   self.plusBtn:setY(by - BUTTON_HGT - PAD)
    local buyW = (DETAIL_W - PAD * 2 - PAD) * 0.58
    self.buyBtn:setX(dx + PAD);  self.buyBtn:setY(by);  self.buyBtn:setWidth(buyW)
    self.rushBtn:setX(dx + PAD + buyW + PAD); self.rushBtn:setY(by)
    self.rushBtn:setWidth(DETAIL_W - PAD * 3 - buyW)
    self.wishBtn:setX(dx + PAD + SPINNER_W + PAD); self.wishBtn:setY(by - BUTTON_HGT - PAD)
    self.wishBtn:setWidth(DETAIL_W - PAD * 3 - SPINNER_W)
    local half = (DETAIL_W - PAD * 2 - PAD) / 2
    local midY = by - (BUTTON_HGT + PAD) * 2
    self.cartAddBtn:setX(dx + PAD);              self.cartAddBtn:setY(midY); self.cartAddBtn:setWidth(half)
    self.cartBtn:setX(dx + PAD + half + PAD);    self.cartBtn:setY(midY);    self.cartBtn:setWidth(half)
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

    TC.log("buy window opened in %d ms (%d rows)",
           getTimestampMs() - started, #win.list.items)
    return win
end
TC.applyTableBehaviour(TC_BuyWindow)
