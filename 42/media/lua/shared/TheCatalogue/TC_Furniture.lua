--[[ The Catalogue -- furniture.

     WHAT WAS WRONG. Only 340 pieces of furniture are items the game ships. Everything
     else in the world is a TILE, and picking one up produces a Base.Moveable that
     carries the sprite name on the instance. Every one of them therefore shares one
     fullType, so the price table could say exactly one thing about all of them -- and
     it said five dollars, for a china cabinet and for a road cone alike.

     WHAT MAKES THE FIX POSSIBLE. The engine's InventoryItemFactory understands the
     fullType "Moveables.<sprite>": it builds a Base.Moveable and reads the world
     sprite into it. A sprite name is therefore a complete address for a piece of
     furniture -- enough to price it, list it, and hand one over. TC_FurnitureTable.lua
     holds 1,119 of them, generated from the game's own tile definitions.

     WHY THE PRICE IS PER CATEGORY. Every other price in this mod comes from the study,
     which priced items one at a time; the study never saw these, because they are not
     items. Rather than invent 1,119 numbers, each piece carries a category and the
     category carries the money. That means a shop counter costs the same as a kitchen
     counter, which is the price of the approach and was chosen deliberately.

     THE FIGURES BELOW ARE ANCHORED, NOT GUESSED. Where the study has an opinion about
     a piece of furniture the game does ship as an item, that opinion sets the
     category: it prices a chair at $20, a table at $31, a lamp at $7, an oven at $8, a
     fridge at $175 and a desktop computer at $355. Categories the study says nothing
     about are placed between those anchors. Refrigeration and Computer are split out
     of their obvious parents for exactly this reason -- one number cannot hold both a
     $175 fridge and an $8 oven without lying about one of them.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Dollars, on the same footing as TC_PriceTable: plain money, before PRICE_SCALE and
     the sandbox multiplier. Edit these rather than the generated table -- the table is
     rewritten wholesale by tools/gen_furniture.sh and anything typed into it is lost. ]]
TC.FURNITURE_PRICES = {
    Refrigeration =  175,   -- study: fridge 175, industrial fridge 330
    Computer      =  250,   -- study: desktop computer 355, terminals below it
    Industrial    =   90,   -- forges, presses, looms: heavy, and worth the haul
    Electronics   =   60,   -- radios, phones, registers, projectors
    Bed           =   45,
    Desk          =   40,
    Appliance     =   40,   -- study: oven 8, but washers and dishwashers pull it up
    Table         =   31,   -- study
    Art           =   25,   -- paintings, statues, mirrors
    Seating       =   20,   -- study: chair 20
    Counter       =   15,   -- study: counter 5, which reads as a floor rather than a price
    Storage       =   15,   -- study: shelves and drawers 5, cabinets 22
    Plumbing      =   12,
    Outdoor       =   12,
    Plant         =   10,
    Misc          =   10,
    Signage       =    8,
    Drapery       =    8,
    Lighting      =    7,   -- study
    Flooring      =    6,   -- a rug or a run of tiles
}

--[[ The prefix the engine reads. A local rather than a TC constant because it is an
     engine fact this file speaks about, not a setting anybody should reach for. ]]
local MOVEABLE_MODULE = "Moveables."

--[[ Sprite -> row, built on first use.

     Built lazily for the same reason the price index is: 1,119 rows is nothing to walk
     once and a waste to walk at load, when a session may never open the buy window. ]]
local bySprite

local function index()
    if bySprite then return bySprite end

    bySprite = {}
    for i = 1, #(TC.FURNITURE or {}) do
        local row = TC.FURNITURE[i]
        bySprite[row.s] = row
    end

    return bySprite
end

--[[ The catalogue row for a world sprite, or nil if it is not merchandise. ]]
function TC.furnitureRow(sprite)
    if not sprite then return nil end
    return index()[sprite]
end

--[[ The fullType the catalogue lists a piece of furniture under. ]]
function TC.furnitureType(sprite)
    if not sprite then return nil end
    return MOVEABLE_MODULE .. sprite
end

--[[ The sprite behind a furniture fullType, or nil for an ordinary item. ]]
function TC.furnitureSprite(fullType)
    if not fullType then return nil end
    return string.match(fullType, "^Moveables%.(.+)$")
end

--[[ Base price in dollars for a world sprite, before any scale. ]]
function TC.furnitureBase(sprite)
    local row = TC.furnitureRow(sprite)
    if not row then return nil end
    return TC.FURNITURE_PRICES[row.c] or TC.FURNITURE_PRICES.Misc
end

--[[ The world sprite a Moveable is carrying, or nil for anything else.

     instanceof first, because getWorldSprite lives on Moveable and asking any other
     item for it is a hard Kahlua error rather than a nil -- the same trap that cost a
     release when getUsedDelta went away. ]]
function TC.moveableSprite(item)
    if not item then return nil end
    if not instanceof(item, "Moveable") then return nil end

    local sprite = item:getWorldSprite()
    if sprite == nil or sprite == "" then return nil end
    return sprite
end

--[[ What one piece standing in the world is worth, buying and selling.

     Three sources in order, and the order is the point. A sprite that names a CustomItem
     IS one of the 340 pieces the game ships as items, so it keeps the study's price and
     the catalogue quotes the same number for the chair on the shelf and the chair in the
     room. Then the generated table. Then the Misc rate, for a tile from a mod this build
     has never seen.

     Scaled here rather than by the caller: TC.getBuyPrice already folds in PRICE_SCALE
     and the sandbox multiplier, so the fallback has to as well or an admin who doubles
     prices would find unknown furniture alone unchanged.
]]
function TC.furnitureUnit(sprite, customItem)
    local unit = customItem and TC.getBuyPrice(customItem)
    unit = unit or (sprite and TC.getBuyPrice(TC.furnitureType(sprite)))
    if unit then return unit end

    local misc = TC.FURNITURE_PRICES.Misc * TC.PRICE_SCALE * TC.opt("PriceMultiplier")
    return math.max(1, math.floor(misc + 0.5))
end

--[[ What the catalogue pays for it, spread and dollar floor included. Shown on the menu
     BEFORE the player commits, because a sale you agree to sight unseen is not a sale. ]]
function TC.furnitureSell(sprite, customItem)
    return TC.sellBackPrice(TC.furnitureUnit(sprite, customItem))
end

--[[ Build one item, furniture included.

     Everything the mod spawns goes through here rather than through instanceItem,
     because a furniture fullType is not a script item and instanceItem alone would
     hand back nil. The Moveable is built the way ISMoveableSpriteProps builds one: an
     empty Base.Moveable, then ReadFromWorldSprite.

     THE ANCHOR MATTERS. A double bed or a long counter is one sprite GRID, and only
     the tile at 0,0 in that grid is the whole piece; reading a neighbour into an item
     would place half a bed. ISMoveablesAction does this same correction before it
     places anything, and doing it here means the item is right from the moment it is
     made rather than only when it is set down.
]]
function TC.createItem(fullType)
    if not fullType then return nil end

    local sprite = TC.furnitureSprite(fullType)
    if not sprite then
        local ok, item = pcall(function() return instanceItem(fullType) end)
        return ok and item or nil
    end

    local worldSprite = getSprite(sprite)
    if worldSprite then
        local grid = worldSprite:getSpriteGrid()
        if grid then
            local anchor = grid:getSprite(0, 0)
            if anchor then sprite = anchor:getName() end
        end
    end

    local item = instanceItem("Base.Moveable")
    if not item then return nil end
    if not item:ReadFromWorldSprite(sprite) then return nil end

    -- The weight the game itself puts on the item, from PickUpWeight. Without this a
    -- wardrobe would weigh whatever Base.Moveable declares, which is half a kilo.
    local row = TC.furnitureRow(sprite)
    if row and row.w then item:setActualWeight(row.w) end

    return item
end
