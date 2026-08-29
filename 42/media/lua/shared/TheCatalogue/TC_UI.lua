--[[ The Catalogue -- shared table layout for the two windows.

     Both lists are real tables: fixed-width columns pinned to the right edge, an
     elastic name column that absorbs whatever is left, vertical rules between them,
     and dividers the player can drag to re-balance the widths.

     ISScrollingListBox does ship an addColumn() that draws headers and vertical rules,
     but it left-aligns every header at `size + 10` and has no resize logic at all, so
     the numeric columns here could not be right-aligned under it. The geometry below
     replaces it rather than fighting it.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC.UI = {
    PAD           = 14,   -- outer margin and gap between blocks
    ROW_HGT       = 34,   -- list row: fits a 26px icon with breathing room
    ICON          = 26,
    CELL_PAD      = 12,   -- gap between a column edge and its text
    SCROLL_GUTTER = 18,   -- reserved for the scrollbar so text never runs under it
    DETAIL_W      = 340,
    GRAB          = 5,    -- how close to a divider the cursor must be to grab it
    MIN_COL       = 46,   -- narrowest a draggable column may become
    MIN_NAME      = 120,  -- the name column never collapses below this
}

--[[ Default widths for the resizable columns. Copied per window instance so a drag
     in the buy window does not move the sell window's columns.

     MEASURED, not guessed. The old fixed numbers assumed a font size, and on a larger
     UI scale the header truncated to "Wei..." before the player had touched anything.
     Each column now starts at least as wide as its own heading plus both cell
     paddings and the space a sort arrow needs, so the table opens legible at any
     scale and the fixed numbers are only floors. ]]
function TC.defaultColumnWidths(kind)
    local tm = getTextManager()
    local reserve = TC.UI.CELL_PAD * 2 + 14      -- both paddings, plus the sort arrow

    local function need(key, floor)
        local w = tm:MeasureStringX(UIFont.Small, getText(key)) + reserve
        return math.max(floor, math.ceil(w))
    end

    if kind == "sell" then
        return {
            cat   = 0,
            mid   = need("IGUI_TC_ColCondition", 108),
            price = need("IGUI_TC_ColValue", 96),
        }
    end
    return {
        cat   = need("IGUI_TC_ColCategory", 150),
        mid   = need("IGUI_TC_ColWeight", 78),
        price = need("IGUI_TC_ColPrice", 96),
    }
end

--[[ Status lines that clear themselves.

     A confirmation is worth reading once. Left on screen it stops being feedback and
     becomes furniture: "Added 5 x Apple to the cart" sitting there ten minutes later
     tells the player nothing except that something happened at some point.

     Expiry is measured in real seconds, not game time. This is a message to the person
     at the keyboard, and it should be gone by the time they have looked away and back
     -- not eight in-game hours later, and not instantly during a sleep. ]]
TC.MESSAGE_SECONDS = 6

function TC.applyMessageBehaviour(cls)
    function cls:setMessage(text, isError)
        self.message = text
        self.messageIsError = isError and true or false
        self.messageAt = getTimestampMs()
    end

    --[[ The message if it is still fresh, nil once it has aged out. Clears the stored
         text on the way so nothing keeps re-checking a dead string. ]]
    function cls:activeMessage()
        if not self.message then return nil end
        if getTimestampMs() - (self.messageAt or 0) > TC.MESSAGE_SECONDS * 1000 then
            self.message = nil
            return nil
        end
        return self.message, self.messageIsError
    end
end

--[[ Cut text to fit a pixel width, with an ellipsis when it had to be cut.

     Item names in this game run long ("Camouflage Hunting Vest with Orange Trim"), and
     the list box stencils only its outer panel -- it does not clip per column -- so an
     overlong name would draw straight through the category and price. Truncating up
     front is what keeps the table looking like a table. Header labels go through it
     too, which is what stopped them piling on top of each other.
]]
function TC.truncate(font, text, maxW)
    if not text then return "" end
    local tm = getTextManager()
    if maxW <= 0 then return "" end
    if tm:MeasureStringX(font, text) <= maxW then return text end

    local ellipsis = "..."
    local avail = maxW - tm:MeasureStringX(font, ellipsis)
    if avail <= 0 then return "" end

    local out = text
    while #out > 1 and tm:MeasureStringX(font, out) > avail do
        out = string.sub(out, 1, #out - 1)
    end
    return out .. ellipsis
end

--[[ Column geometry for a list of the given pixel width.

     Computed from the RIGHT edge inwards. The price is the number the player is
     shopping on, so it gets a fixed column pinned right; the name column absorbs the
     remainder when the window is resized.

     `widths` is the per-window table from defaultColumnWidths, mutated by dragging.
     A cat width of 0 means the window has no category column (the sell list).
]]
function TC.columns(listWidth, widths)
    local U = TC.UI
    local w = widths or TC.defaultColumnWidths("buy")

    local rightEdge  = listWidth - U.SCROLL_GUTTER
    local priceLeft  = rightEdge - w.price
    local midLeft    = priceLeft - w.mid
    local catLeft    = (w.cat > 0) and (midLeft - w.cat) or midLeft

    local nameLeft = U.ICON + U.CELL_PAD * 2

    return {
        nameLeft   = nameLeft,
        nameRight  = catLeft,
        nameW      = math.max(20, catLeft - nameLeft - U.CELL_PAD),

        catLeft    = catLeft,
        catRight   = midLeft,
        catW       = math.max(0, midLeft - catLeft - U.CELL_PAD * 2),

        midLeft    = midLeft,
        midRight   = priceLeft,
        midW       = math.max(0, priceLeft - midLeft - U.CELL_PAD),

        priceLeft  = priceLeft,
        priceRight = rightEdge,
        priceW     = math.max(0, rightEdge - priceLeft - U.CELL_PAD),

        rightEdge  = rightEdge,
        hasCat     = w.cat > 0,
    }
end

--[[ The x of every draggable divider, paired with the width key it controls.
     Dragging a divider resizes the column to its RIGHT, which is the only direction
     that stays stable in a right-anchored layout. ]]
function TC.dividers(c)
    local out = {}
    if c.hasCat then table.insert(out, { x = c.catLeft, key = "cat", right = c.catRight }) end
    table.insert(out, { x = c.midLeft,   key = "mid",   right = c.midRight })
    table.insert(out, { x = c.priceLeft, key = "price", right = c.rightEdge })
    return out
end

--[[ Which divider is under the cursor, if any. `x` is relative to the window and
     `listX` is where the list starts, because the header is drawn on the window
     rather than inside the list box. ]]
function TC.dividerUnder(c, listX, x)
    for _, d in ipairs(TC.dividers(c)) do
        if math.abs(x - (listX + d.x)) <= TC.UI.GRAB then return d end
    end
    return nil
end

--[[ Which column the cursor is over, as one of "name" / "cat" / "mid" / "price".
     Used for click-to-sort on the header. Returns nil past the right edge, where the
     scrollbar gutter lives. ]]
function TC.columnAtPoint(c, listX, x)
    local rel = x - listX
    if rel < 0 or rel > c.rightEdge then return nil end
    if rel >= c.priceLeft then return "price" end
    if rel >= c.midLeft   then return "mid" end
    if c.hasCat and rel >= c.catLeft then return "cat" end
    return "name"
end

--[[ A sort arrow, built from stacked rectangles rather than a glyph.

     The obvious choice is a triangle character, but the game's bitmap fonts have no
     guaranteed coverage for those code points and a missing glyph renders as nothing
     at all -- an invisible sort indicator is worse than none. Four rects always draw.
]]
function TC.drawSortArrow(panel, x, y, ascending)
    local rows = { 7, 5, 3, 1 }
    for i, w in ipairs(rows) do
        local step = ascending and (i - 1) or (#rows - i)
        panel:drawRect(x + (7 - w) / 2, y + step, w, 1, 0.9, 0.85, 0.85, 0.9)
    end
end

--[[ Draw a right-aligned string ending at `right`, held off the edge by CELL_PAD.
     Right-aligning numbers is what lets the eye compare prices down a column, and the
     padding is what stops them touching the divider. ]]
function TC.drawRight(panel, text, right, y, font, r, g, b, a)
    local w = getTextManager():MeasureStringX(font, text)
    panel:drawText(text, right - w - TC.UI.CELL_PAD, y, r, g, b, a or 1, font)
end

--[[ The vertical rules, drawn both in the header strip and down each row so a column
     reads as a column all the way down. ]]
function TC.drawColumnRules(panel, c, x0, y, height, alpha)
    for _, d in ipairs(TC.dividers(c)) do
        panel:drawRect(x0 + d.x, y, 1, height, alpha or 0.28, 1, 1, 1)
    end
end

--[[ Apply a drag. Returns true when a width actually changed, so the caller can skip
     redundant work. Clamps both the dragged column and the elastic name column, which
     is what stops a drag from squeezing the names to nothing. ]]
function TC.resizeColumn(widths, key, newLeftX, listWidth)
    local U = TC.UI
    local c = TC.columns(listWidth, widths)

    local right
    if     key == "price" then right = c.rightEdge
    elseif key == "mid"   then right = c.midRight
    else                       right = c.catRight end

    local proposed = math.floor(right - newLeftX)
    if proposed < U.MIN_COL then proposed = U.MIN_COL end

    local old = widths[key]
    if proposed == old then return false end

    widths[key] = proposed

    -- Reject the change if it would starve the name column.
    local after = TC.columns(listWidth, widths)
    if after.nameW < U.MIN_NAME then
        widths[key] = old
        return false
    end
    return true
end

--[[ A row of buttons that neither overflows nor balloons.

     The cart laid its four buttons out as fractions of the window width, which is wrong
     at both ends of the resize. Narrow, a third of the width is less than the words
     "Remove selected" and the label ran out through the border. Wide, the same third
     became a button the size of a paragraph with one word floating in the middle of it.

     A button should be the size of what it says. So the widths come from the labels,
     and any space left over goes into the GAPS between them -- the row still spans the
     full width and still looks deliberate, but the buttons stay button-sized. When
     there is not enough room even for the labels, every button gives up the same
     FRACTION of its own width, which squeezes the long label hardest and stops the
     short one collapsing to nothing, and the titles are truncated to what is left so a
     label can never draw outside its own button.

     Returns one { x, w, text } per label, laid out left to right from x0.
]]
TC.UI.BTN_PAD     = 28   -- breathing room either side of a button label
TC.UI.BTN_MIN_GAP = 10   -- buttons never touch

function TC.buttonRow(x0, availW, labels, font)
    local tm   = getTextManager()
    local n    = #labels
    local gaps = math.max(0, n - 1)

    local widths, sum = {}, 0
    for i, text in ipairs(labels) do
        widths[i] = tm:MeasureStringX(font, text) + TC.UI.BTN_PAD
        sum = sum + widths[i]
    end

    local forGaps = availW - sum
    if forGaps < gaps * TC.UI.BTN_MIN_GAP then
        local room  = math.max(0, availW - gaps * TC.UI.BTN_MIN_GAP)
        local scale = (sum > 0) and (room / sum) or 0
        sum = 0
        for i = 1, n do
            widths[i] = math.max(24, math.floor(widths[i] * scale))
            sum = sum + widths[i]
        end
        forGaps = availW - sum
    end

    local gap = (gaps > 0) and (forGaps / gaps) or 0

    local out, x = {}, x0
    for i = 1, n do
        out[i] = {
            x    = math.floor(x),
            w    = math.floor(widths[i]),
            text = TC.truncate(font, labels[i], widths[i] - 8),
        }
        x = x + widths[i] + gap
    end
    return out
end

--[[ The narrowest a row of buttons can be drawn without truncating anything.

     Windows use it as their minimum width, so a row can never be dragged smaller than
     the words in it. Cheaper than discovering the same number by clipping a label. ]]
function TC.buttonRowWidth(labels, font)
    local tm = getTextManager()
    local total = 0
    for _, text in ipairs(labels) do
        total = total + tm:MeasureStringX(font, text) + TC.UI.BTN_PAD
    end
    return total + math.max(0, #labels - 1) * TC.UI.BTN_MIN_GAP
end

--[[ Draw a string centred inside a column of the given left edge and width.

     The two alignments already here -- left at a fixed x, right against an edge -- are
     what a dense table wants, where the eye compares figures down a column. A short
     value in a narrow column is the other case: centred under a centred heading, it
     reads as one balanced block rather than a number pushed against a rule. ]]
function TC.drawCentred(panel, text, left, width, y, font, r, g, b, a)
    local w = getTextManager():MeasureStringX(font, text)
    panel:drawText(text, left + math.floor((width - w) / 2), y, r, g, b, a or 1, font)
end


--[[ =====================================================================
     THE RAIL -- the pane switcher down the right edge of every window.
     =====================================================================

     There is one catalogue window, and Buy, Sell and Ledger are three faces of it.
     What actually happens is that clicking a rail entry closes the window you are on
     and opens the next one AT THE SAME RECTANGLE. Nothing moves and nothing resizes,
     so the frame under the cursor is where it was and it reads as a pane swap. The
     alternative -- one host window owning three ISPanels -- is the same picture for a
     rewrite of every layout offset in three files, and those offsets have already
     produced three overflow bugs between them.

     Two entries do NOT switch, and both for the same reason: they are wanted ALONGSIDE
     a pane rather than instead of one.

       Cart      because it is the running total for the list you are still adding to,
                 and a tab would hide the thing being counted. It toggles a second
                 window beside this one.
       Delivery  because it can arrive while no catalogue window is open at all, and
                 because turning it away is a decision that deserves its own window.
]]

--[[ The rail button height, read on FIRST USE rather than at file scope.

     The window files each open with `local FONT_HGT_SMALL = getTextManager():...` and
     the rail was written as if it could reach one of those. It cannot: they are file
     locals, and this file is shared and loads before any of them. `nil + 10` is valid
     Lua and a crash at runtime, which is exactly the class of bug tools/check.sh says
     it cannot catch.

     Computed lazily and cached, so nothing here depends on the text manager being
     ready at the moment this file is read. ]]
local railBtnH
local function railButtonHeight()
    if not railBtnH then
        railBtnH = getTextManager():getFontHeight(UIFont.Small) + 10
    end
    return railBtnH
end

TC.UI.RAIL_PAD = 8      -- inset between the rail and the window edge
TC.UI.RAIL_GAP = 5      -- between one rail button and the next

--[[ The switchable panes, in the order they are drawn.

     `open` is the NAME of the opener rather than the function itself, because this
     file is shared and loads long before the client windows that define them. Looking
     it up on TC at click time is what lets the rail live down here with the rest of
     the layout instead of in one of the windows it switches between. ]]
TC.RAIL_PANES = {
    { id = "buy",    label = "IGUI_TC_RailBuy",    open = "openBuyWindow"     },
    { id = "sell",   label = "IGUI_TC_RailSell",   open = "openSellWindow"    },
    { id = "ledger", label = "IGUI_TC_RailLedger", open = "openHistoryWindow" },
}

local function railEntries()
    local out = {}
    for _, p in ipairs(TC.RAIL_PANES) do
        table.insert(out, { id = p.id, text = getText(p.label) })
    end
    table.insert(out, { id = "cart",     text = getText("IGUI_TC_RailCart")     })
    table.insert(out, { id = "delivery", text = getText("IGUI_TC_RailDelivery") })
    return out
end

--[[ Measured, never assumed. Every label plus room for the widest count it can carry,
     so a rail entry never truncates and the three windows agree on what the rail costs
     them in width. ]]
function TC.railWidth()
    local tm = getTextManager()
    local w  = 0
    for _, entry in ipairs(railEntries()) do
        w = math.max(w, tm:MeasureStringX(UIFont.Small, entry.text .. "  99"))
    end
    return w + TC.UI.BTN_PAD + TC.UI.RAIL_PAD * 2
end

--[[ How wide the window's own content may be. Every horizontal layout expression in a
     railed window goes through this instead of reading self.width directly. ]]
function TC.innerW(win)
    return win.width - (win.railW or 0)
end

local function railCount(playerNum, id)
    if id == "cart" then
        return TC.cartCount(playerNum)
    end
    local player = getSpecificPlayer(playerNum)
    if not player then return 0 end
    if id == "ledger"   then return TC.pendingCount(player) or 0 end
    if id == "delivery" then return TC.arrivedCount(player) or 0 end
    return 0
end

--[[ ISButton hands the BUTTON to onclick as the first argument after the target, so
     which pane was clicked rides on the button rather than in a bound argument. Same
     trap the cart window's rush flag fell into. ]]
function TC.onRailClick(win, button)
    local id = button and button.internal
    if not id or id == win.railId then return end

    if id == "cart" then
        TC.toggleCartWindow(win.playerNum)
        return
    end

    if id == "delivery" then
        TC.openArrivalWindow(win.playerNum)
        return
    end

    for _, p in ipairs(TC.RAIL_PANES) do
        if p.id == id then
            local playerNum = win.playerNum
            TC.saveFrame(win)
            win:close()
            TC[p.open](playerNum)
            return
        end
    end
end

--[[ Build the rail as real children of `win`. `activeId` is the pane the window IS; it
     is drawn disabled, because a button that reopens the window you are looking at is
     a button that appears to do nothing. ]]
function TC.buildRail(win, activeId)
    win.railId   = activeId
    win.railW    = TC.railWidth()
    win.railBtns = {}

    local hgt = railButtonHeight()

    for _, entry in ipairs(railEntries()) do
        local b = ISButton:new(0, 0, 10, hgt, entry.text, win, TC.onRailClick)
        b.internal = entry.id
        b:initialise()
        b:instantiate()
        b.baseText = entry.text
        if entry.id == activeId then b:setEnable(false) end
        win:addChild(b)
        win.railBtns[entry.id] = b
    end

    TC.layoutRail(win)
end

--[[ Position every rail button. Called from createChildren and again from onResize, so
     the rail follows a drag the way the list does.

     Delivery is pinned to the BOTTOM rather than flowing with the rest. It is the only
     entry that is usually absent, and an entry that appears and disappears in the
     middle of a column shoves everything under it down half a button. Pinned, it
     arrives in space of its own and nothing else moves. ]]
function TC.layoutRail(win)
    if not win.railBtns then return end

    local x   = win.width - win.railW + TC.UI.RAIL_PAD
    local w   = win.railW - TC.UI.RAIL_PAD * 2
    local hgt = railButtonHeight()
    local y   = win:titleBarHeight() + TC.UI.PAD

    for _, p in ipairs(TC.RAIL_PANES) do
        local b = win.railBtns[p.id]
        b:setX(x); b:setY(y); b:setWidth(w); b:setHeight(hgt)
        y = y + hgt + TC.UI.RAIL_GAP
    end

    -- A gap above the cart: it is the one entry here that opens something beside the
    -- window rather than inside it, and the space says so without a label.
    local cart = win.railBtns.cart
    cart:setX(x); cart:setY(y + TC.UI.RAIL_GAP)
    cart:setWidth(w); cart:setHeight(hgt)

    local del = win.railBtns.delivery
    del:setX(x); del:setY(win.height - TC.UI.PAD - hgt)
    del:setWidth(w); del:setHeight(hgt)
end

--[[ Put the live numbers on the rail: what is in the cart, what is still on order, and
     whether anything is at the door. This is the part that earns the rail its width --
     you stop having to open the ledger to find out whether you have anything coming.

     Cheap enough to run every prerender: three integers and a string compare, against
     a list that redraws several thousand rows in the same frame. ]]
function TC.refreshRail(win)
    if not win.railBtns then return end

    for id, b in pairs(win.railBtns) do
        local n    = railCount(win.playerNum, id)
        local want = (n > 0) and (b.baseText .. "  " .. tostring(n)) or b.baseText
        if b:getTitle() ~= want then b:setTitle(want) end
    end

    win.railBtns.delivery:setVisible(railCount(win.playerNum, "delivery") > 0)
end


--[[ =====================================================================
     WHERE THE WINDOW WAS
     =====================================================================

     The rail's whole trick is that the next pane opens exactly where the last one
     stood. That has to outlast the click: a player who sized the catalogue to suit
     their screen and then quit expects to find it that size, so the rectangle rides on
     modData the way the pending orders do.

     One frame per player, not one per pane -- there is only one window, and it has
     three faces. ]]
function TC.saveFrame(win)
    local player = getSpecificPlayer(win.playerNum)
    if not player then return end
    player:getModData().TC_frame = {
        x = win.x, y = win.y, w = win.width, h = win.height,
    }
end

--[[ Where a pane should open: the remembered frame when there is one, else centred at
     the size asked for.

     Clamped at both ends. A frame saved on a wider monitor, or saved by a roomier pane
     than the one now opening, must not put a window's controls off the screen or
     squeeze a pane below the width its own button row needs. ]]
function TC.frameRect(playerNum, defW, defH, minW, minH)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()

    local w = math.min(defW, sw - 80)
    local h = math.min(defH, sh - 80)
    local x, y = (sw - w) / 2, (sh - h) / 2

    local player = getSpecificPlayer(playerNum)
    local saved  = player and player:getModData().TC_frame

    if type(saved) == "table" and type(saved.w) == "number" and type(saved.h) == "number" then
        w = math.max(minW or 0, math.min(saved.w, sw))
        h = math.max(minH or 0, math.min(saved.h, sh))
        x = math.max(0, math.min(saved.x or x, sw - w))
        y = math.max(0, math.min(saved.y or y, sh - h))
    end

    return x, y, w, h
end
