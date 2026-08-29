--[[ The Catalogue -- the cart, which now outlives any one window.

     It used to live on the buy window instance, and while the buy window was the only
     way in that was honest: close the window and the cart went with it, the way an
     abandoned basket does.

     The rail broke that reading. Switching to the ledger and back closes the buy
     window and opens a new one at the same place, so a cart owned by the window would
     be emptied by the act of glancing at something else -- which is not a decision the
     player made.

     So it is keyed by player here instead. It lasts as long as the session and is
     emptied when the order it describes is placed, or when the player clears it.

     Every caller mutates the table in place (table.insert, table.remove), so the
     reference this hands back has to be stable for the life of the cart. Rebuilding it
     per call would silently drop lines.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local carts = {}

function TC.cart(playerNum)
    carts[playerNum] = carts[playerNum] or {}
    return carts[playerNum]
end

--[[ The number of ITEMS on order, not the number of lines. The rail shows this, and
     "3" against a cart holding three of one thing and "3" against a cart holding one
     each of three things are the same answer to the question the player is asking. ]]
function TC.cartCount(playerNum)
    local n = 0
    for _, line in ipairs(TC.cart(playerNum)) do
        n = n + (line.qty or 0)
    end
    return n
end
