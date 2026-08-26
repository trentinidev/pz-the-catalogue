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
     in the buy window does not move the sell window's columns. ]]
function TC.defaultColumnWidths(kind)
    if kind == "sell" then
        return { cat = 0, mid = 108, price = 96 }
    end
    return { cat = 150, mid = 78, price = 96 }
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
