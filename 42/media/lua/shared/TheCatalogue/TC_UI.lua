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
