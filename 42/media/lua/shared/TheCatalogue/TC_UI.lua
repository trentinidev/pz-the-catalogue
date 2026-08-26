--[[ The Catalogue -- shared drawing helpers for the two windows. ]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Shared layout constants. Both windows use these so the buy and sell lists line
     up with each other; changing a value here changes both, which is the point. ]]
TC.UI = {
    PAD          = 14,   -- outer margin and gap between blocks
    ROW_HGT      = 34,   -- list row: tall enough for a 26px icon plus breathing room
    ICON         = 26,
    CELL_PAD     = 12,   -- gap between a column edge and its text
    SCROLL_GUTTER= 18,   -- reserved for the scrollbar so text never runs under it
    COL_PRICE_W  = 88,
    COL_WEIGHT_W = 70,
    COL_COND_W   = 92,
    COL_CAT_W    = 150,
    DETAIL_W     = 340,
}

--[[ Cut text down to fit a pixel width, with an ellipsis when it had to be cut.

     Item names in this game run long ("Camouflage Hunting Vest with Orange Trim"),
     and the base list box does not clip per-column -- it stencils only the outer
     panel, so an overlong name would happily draw straight through the category and
     price columns. Truncating up front is what keeps the table looking like a table.
]]
function TC.truncate(font, text, maxW)
    if not text then return "" end
    local tm = getTextManager()
    if tm:MeasureStringX(font, text) <= maxW then return text end

    local ellipsis = "..."
    local avail = maxW - tm:MeasureStringX(font, ellipsis)
    if avail <= 0 then return ellipsis end

    -- Linear walk from the end. Names are short enough that a binary search would
    -- be optimising a loop that runs a few dozen times on a handful of visible rows.
    local out = text
    while #out > 1 and tm:MeasureStringX(font, out) > avail do
        out = string.sub(out, 1, #out - 1)
    end
    return out .. ellipsis
end

--[[ Column geometry for a list of the given pixel width.

     Computed from the RIGHT edge inwards: the price is the number the player is
     actually shopping on, so it gets a fixed column pinned to the right, and the
     name column absorbs whatever width is left over when the window is resized.
]]
function TC.columns(listWidth, opts)
    local U = TC.UI
    opts = opts or {}

    local rightEdge   = listWidth - U.SCROLL_GUTTER
    local priceRight  = rightEdge
    local priceLeft   = priceRight - U.COL_PRICE_W

    local midW        = opts.conditionColumn and U.COL_COND_W or U.COL_WEIGHT_W
    local midRight    = priceLeft
    local midLeft     = midRight - midW

    local catLeft, catRight
    if opts.categoryColumn then
        catRight = midLeft
        catLeft  = catRight - U.COL_CAT_W
    else
        catRight = midLeft
        catLeft  = midLeft
    end

    local nameLeft = U.ICON + U.CELL_PAD * 2
    local nameW    = catLeft - nameLeft - U.CELL_PAD

    return {
        nameLeft = nameLeft, nameW = math.max(40, nameW),
        catLeft = catLeft, catRight = catRight, catW = math.max(0, catRight - catLeft - U.CELL_PAD),
        midLeft = midLeft, midRight = midRight,
        priceLeft = priceLeft, priceRight = priceRight,
    }
end

--[[ Draw a right-aligned string ending at `right`, held off the edge by CELL_PAD.
     Right-aligning numbers is what lets the eye compare prices down a column, and
     the padding is what stops them touching the scrollbar. ]]
function TC.drawRight(panel, text, right, y, font, r, g, b, a)
    local w = getTextManager():MeasureStringX(font, text)
    panel:drawText(text, right - w - TC.UI.CELL_PAD, y, r, g, b, a or 1, font)
end
