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

--[[ Turn whatever `lines` happens to be into the list of receipt lines it must be.

     A LEDGER ENTRY IS FOREVER, WHICH IS WHY THIS EXISTS TWICE. 0.12.0 handed this a
     plain string from the furniture sale, and nothing complained: the entry was written,
     the sale went through, the money arrived. The ledger then threw `Expected a table`
     out of ipairs the next time it was opened -- and kept throwing, because the bad
     entry was in the save by then and a fresh install would not have cured it.

     So the repair runs on the way IN, where no future caller can write a bad entry, and
     on the way OUT, where a save that already holds one is healed the first time it is
     read. A string is kept as the line's name rather than dropped: it is what the player
     bought, and losing it to tidiness would be a second bug on top of the first. ]]
local function receiptLines(lines)
    if type(lines) == "table" then return lines end
    if type(lines) == "string" and lines ~= "" then
        return { { name = lines, qty = 1 } }
    end
    return {}
end

function TC.history(player)
    if not player then return {} end
    local md = player:getModData()
    if type(md[HISTORY_KEY]) ~= "table" then md[HISTORY_KEY] = {} end

    -- Healed in place, so the save is corrected once rather than reformatted on every
    -- draw. The loop is over at most MAX_ENTRIES and does nothing at all in the
    -- ordinary case.
    for _, e in ipairs(md[HISTORY_KEY]) do
        if type(e) == "table" and type(e.lines) ~= "table" then
            e.lines = receiptLines(e.lines)
        end
    end

    return md[HISTORY_KEY]
end

--[[ A world timestamp, not a real one.

     The ledger belongs to the character, so it is dated by the game's calendar. Zero
     padding keeps the strings sortable and the column aligned.

     Public, and named for the clock rather than for the ledger, because the bank
     statement in TC_Bank.lua dates its lines the same way. Two copies of this would be
     two calendars in one save file that could disagree about what a month is. ]]
function TC.gameStamp()
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
        when  = TC.gameStamp(),
        lines = receiptLines(lines),
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
