--[[ The Catalogue -- what you bought and sold, and when.

     FEAT-13 in the roadmap is written on top of FEAT-08, persistent Orders with
     delivery states. Orders were deferred, so this is the part that stands on its own:
     a plain ledger of completed transactions. No order ids, no states to reconcile,
     nothing that has to survive a half-finished delivery -- an entry is only written
     once money and goods have already changed hands, so the ledger can never disagree
     with the world.

     Kept on the player's modData, the same place the wishlist lives, so it persists per
     character and needs no save hook -- which matters, because the game gives Lua no
     save hook to use. See TC_SellWindow.lua for the longer version of that story.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local HISTORY_KEY = "TheCatalogue_History"

--[[ How many entries to keep.

     modData is written into the save file, so an unbounded ledger grows it forever.
     Two hundred entries is far more than anyone scrolls back through and costs a few
     kilobytes. The oldest fall off the end. ]]
local MAX_ENTRIES = 200

function TC.history(player)
    if not player then return {} end
    local md = player:getModData()
    if type(md[HISTORY_KEY]) ~= "table" then md[HISTORY_KEY] = {} end
    return md[HISTORY_KEY]
end

--[[ A world timestamp, not a real one.

     The ledger belongs to the character, so it is dated by the game's calendar. Zero
     padding keeps the strings sortable and the column aligned. ]]
local function stamp()
    local gt = getGameTime()
    if not gt then return "?" end
    return string.format("%04d-%02d-%02d %02d:00",
                         gt:getYear(), gt:getMonth() + 1, gt:getDay() + 1, gt:getHour())
end

--[[ Record a completed transaction.

     `lines` is a list of { name, qty } -- what the player would recognise, not
     fullTypes, because this is a receipt and not a debug log. ]]
function TC.logTransaction(player, kind, lines, total)
    if not player then return end

    local hist = TC.history(player)

    table.insert(hist, 1, {
        kind  = kind,                 -- "buy" or "sell"
        total = math.floor((total or 0) + 0.5),
        when  = stamp(),
        lines = lines or {},
    })

    while #hist > MAX_ENTRIES do
        table.remove(hist)
    end
end

--[[ Collapse a list of items into { name, qty, fullType } lines, so a receipt reads
     "5 x Hammer" instead of five identical rows.

     The fullType is carried for the icon and nothing else -- the summary text is still
     built from the name, which is what the player recognises. Entries written before
     0.10.1 have no fullType and simply draw without an icon; the ledger keeps two
     hundred of them, so that is a real state and not a hypothetical one. ]]
function TC.summariseItems(items)
    local order, byName = {}, {}
    for _, it in ipairs(items) do
        local isString = type(it) == "string"
        local name = isString and it or it:getDisplayName()
        if not byName[name] then
            byName[name] = {
                name     = name,
                qty      = 0,
                fullType = (not isString) and it:getFullType() or nil,
            }
            table.insert(order, byName[name])
        end
        byName[name].qty = byName[name].qty + 1
    end
    return order
end
