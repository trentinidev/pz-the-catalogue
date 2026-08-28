--[[ The Catalogue -- shared table behaviour for the buy and sell windows.

     Both windows present a sortable, resizable table with a fixed header, and both had
     their own copy of it: the header drawing, the divider hit-testing, the drag to
     resize, the sort toggle and the mouse plumbing that keeps a grab on a divider from
     dragging the whole window. About a hundred and twenty duplicated lines each, which
     is where a fix applied to one and forgotten in the other comes from.

     Applied with TC.applyTableBehaviour(SomeWindowClass). The window supplies four
     things and gets the rest:

         self:tableGeometry()      -> listX, headerY, listW
         self:tableHeaderHeight()  -> pixels
         self.tableCols            -> the column spec, see below
         self:refreshList()        -> called after a sort changes

     and keeps self.colW, self.sortKey and self.sortAsc as its own state, so two open
     windows never share a column drag or a sort.

     The column spec names which geometry slot each heading belongs to:

         { { key = "name",  textKey = "IGUI_TC_ColItem",     align = "left"  },
           { key = "cat",   textKey = "IGUI_TC_ColCategory", align = "left"  },
           { key = "mid",   textKey = "IGUI_TC_ColWeight",   align = "right" },
           { key = "price", textKey = "IGUI_TC_ColPrice",    align = "right" } }
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local ARROW = 11        -- the sort arrow plus the gap it needs

function TC.applyTableBehaviour(cls)

    -- -----------------------------------------------------------------------
    -- Header
    -- -----------------------------------------------------------------------

    --[[ Every label is truncated against its own column. Without that, headings are
         drawn at full length regardless of the room they have and print over each
         other the moment a column is narrower than its word. ]]
    function cls:drawTableHeader()
        local listX, headerY, listW = self:tableGeometry()
        local hgt = self:tableHeaderHeight()
        local c   = TC.columns(listW, self.colW)
        local F   = UIFont.Small
        local fh  = getTextManager():getFontHeight(F)

        self:drawRect(listX, headerY, listW, hgt, 0.75, 0.13, 0.13, 0.15)
        self:drawRectBorder(listX, headerY, listW, hgt, 0.5, 0.4, 0.4, 0.4)
        TC.drawColumnRules(self, c, listX, headerY, hgt, 0.4)

        local ty = headerY + (hgt - fh) / 2
        local ay = headerY + (hgt - 4) / 2

        for _, col in ipairs(self.tableCols) do
            local active = (self.sortKey == col.key)
            local r, g, b = 0.72, 0.72, 0.76
            if active then r, g, b = 1, 1, 1 end

            local avail, x
            if col.key == "name" then
                avail, x = c.nameW, listX + c.nameLeft
            elseif col.key == "cat" then
                avail, x = c.catW, listX + c.catLeft + TC.UI.CELL_PAD
            elseif col.key == "mid" then
                avail = c.midW
            else
                avail = c.priceW
            end

            if avail > 0 then
                local room = active and (avail - ARROW) or avail
                local text = TC.truncate(F, getText(col.textKey), room)
                local tw = getTextManager():MeasureStringX(F, text)

                if col.align == "right" then
                    local right = (col.key == "mid") and c.midRight or c.priceRight
                    x = listX + right - tw - TC.UI.CELL_PAD
                end

                self:drawText(text, x, ty, r, g, b, 1, F)

                if active then
                    -- Left-aligned headings put the arrow after the word; right-aligned
                    -- ones put it before, so the label keeps its edge alignment with
                    -- the numbers underneath it.
                    if col.align == "right" then
                        TC.drawSortArrow(self, x - ARROW, ay, self.sortAsc)
                    else
                        TC.drawSortArrow(self, x + tw + 4, ay, self.sortAsc)
                    end
                end
            end
        end

        -- The divider under the cursor lights up, so the drag handle is discoverable.
        if self.hoverDivider then
            self:drawRect(listX + self.hoverDivider.x - 1, headerY, 3, hgt, 0.8, 0.6, 0.7, 0.9)
        end
    end

    -- -----------------------------------------------------------------------
    -- Sorting
    -- -----------------------------------------------------------------------

    --[[ Click a heading to sort by it, click the active one again to reverse.
         Text opens ascending; numbers open descending, because someone clicking a
         price heading is usually asking to see the expensive things. ]]
    function cls:sortBy(key)
        if self.sortKey == key then
            self.sortAsc = not self.sortAsc
        else
            self.sortKey = key
            self.sortAsc = (key == "name" or key == "cat")
        end
        self:refreshList()
    end

    -- -----------------------------------------------------------------------
    -- Mouse
    -- -----------------------------------------------------------------------

    function cls:headerBand()
        local listX, headerY, listW = self:tableGeometry()
        return listX, headerY, listW, self:tableHeaderHeight()
    end

    function cls:dividerAtPoint(x, y)
        local hx, hy, hw, hh = self:headerBand()
        if y < hy or y > hy + hh then return nil end
        return TC.dividerUnder(TC.columns(hw, self.colW), hx, x)
    end

    function cls:onMouseMove(dx, dy)
        local x, y = self:getMouseX(), self:getMouseY()

        if self.dragCol then
            local hx, _, hw = self:headerBand()
            TC.resizeColumn(self.colW, self.dragCol.key, x - hx, hw)
            return true
        end

        self.hoverDivider = self:dividerAtPoint(x, y)
        return ISCollapsableWindow.onMouseMove(self, dx, dy)
    end

    --[[ ISCollapsableWindow:onMouseDown sets self.moving unconditionally -- it drags
         the window from anywhere on it, not just the title bar -- so a grab on a
         divider must NOT fall through to it, or the whole window follows the cursor.
         The divider is checked before the sort so the few pixels of a drag handle are
         never stolen by a sort. ]]
    function cls:onMouseDown(x, y)
        local d = self:dividerAtPoint(x, y)
        if d then
            self.dragCol = d
            self:bringToTop()
            return true
        end

        local hx, hy, hw, hh = self:headerBand()
        if y >= hy and y <= hy + hh and x >= hx and x <= hx + hw then
            local col = TC.columnAtPoint(TC.columns(hw, self.colW), hx, x)
            if col then
                self:sortBy(col)
                self:bringToTop()
                return true
            end
        end

        return ISCollapsableWindow.onMouseDown(self, x, y)
    end

    function cls:onMouseUp(x, y)
        self.dragCol = nil
        return ISCollapsableWindow.onMouseUp(self, x, y)
    end

    function cls:onMouseUpOutside(x, y)
        self.dragCol = nil
        return ISCollapsableWindow.onMouseUpOutside(self, x, y)
    end

    -- Status lines, with the self-clearing behaviour shared by every window here.
    TC.applyMessageBehaviour(cls)
end
