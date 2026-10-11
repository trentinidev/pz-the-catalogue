--[[ The Catalogue -- how much of a thing the company can actually supply.

     THE PROBLEM THIS SOLVES. Stock was infinite and instant in quantity: a player with
     enough money could order a hundred generators, and the only thing standing between
     them and that was the money. Money is the resource the catalogue is best at giving
     you, so "enough money" is a stage of the game rather than a wall -- and once reached,
     every expensive thing in the mod became a formality.

     TIME IS THE RESOURCE PROJECT ZOMBOID ACTUALLY RATIONS. Weight, lead time and now
     availability are all ways of charging a purchase in something other than dollars. A
     weekly cap says "this company can get you one of those a week", which converts money
     into waiting -- and waiting is the thing a player cannot farm.

     CAPPED BY PRICE, NOT BY A HAND-WRITTEN LIST. The alternative is a table naming the
     items that deserve a limit, which would be wrong the moment another mod adds a
     generator and would need revisiting at every price change. The shelf price already
     encodes how precious something is -- the study spent 5,000 judgements working that
     out -- so the bands below read it instead of second-guessing it. An item nobody would
     describe as scarce is not capped at all, which is most of the catalogue.

     NOT A SIMULATION. There is no stock level that depletes and recovers, no supply
     chain, and no scarcity that varies by region: see ROADMAP.txt, where that is parked
     behind 1.0 on purpose. This is the cheap version that gets the gameplay effect
     without any of the bookkeeping -- a counter per id per week, and nothing else.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local STOCK_KEY = "TheCatalogue_Stock"

-- A game week. Vanilla has no "week" anywhere, so this is simply 7 x 24.
local HOURS_PER_WEEK = 7 * 24

--[[ How many of one id the company can supply in a week, or nil for "as many as you
     like".

     Read as shelf prices, which is what the player sees, so the thresholds mean the same
     thing whatever PriceMultiplier is set to. At the default multiplier of 5 the bands
     land on the catalogue roughly like this:

         1 per week      >= $5,000    bars, generators, ham radios, rifles --     15 ids
         3 per week      >= $1,000    handguns, shotguns, the costly middle --    86 ids
         10 per week     >= $250      tools, optics, the useful middle --        466 ids
         uncapped        under $250   ammunition, food, materials, nails --    4,331 ids

     So nothing a player buys by the handful is ever capped, and nothing that would settle
     a problem outright is ever bought by the handful. ]]
local BANDS = {
    { 5000, 1 },
    { 1000, 3 },
    { 250, 10 },
}

function TC.stockCap(fullType)
    if not fullType then return nil end

    local scale = TC.opt("StockLimitMultiplier")
    if type(scale) ~= "number" or scale <= 0 then return nil end   -- 0 means off

    local shelf = TC.getBuyPrice(fullType)
    if not shelf then return nil end

    for _, band in ipairs(BANDS) do
        if shelf >= band[1] then
            --[[ Rounded UP and floored at one, so a multiplier below 1 tightens the cap
                 without ever reaching zero. A cap of zero is not a scarcer shop, it is an
                 item silently removed from the catalogue, and an admin who wanted that
                 would say so with the exclusion list. ]]
            local n = math.ceil(band[2] * scale)
            if n < 1 then n = 1 end
            return n
        end
    end

    return nil
end

--[[ The player's counter table, reset when the week rolls over.

     ON THE PLAYER, because there is no save hook in this game beyond OnPlayerDeath and
     modData is the only thing that survives a reload -- the same reason the order list
     and the wishlist live there.

     PER CHARACTER rather than per world, which is the honest reading of a mail-order
     account: it is your name the company knows. It also means a cap cannot be dodged by
     switching characters mid-save and ordering again, because the new character starts
     with a counter of their own and the one they left keeps theirs.

     The week number is stored alongside the counts rather than the counts being dated
     individually. Rolling over therefore costs one comparison and one table drop, and a
     player who does not shop for a month does not accumulate a month of dead keys. ]]
local function bucket(player)
    if not player then return nil end

    local md = player:getModData()
    local week = math.floor(TC.worldHours() / HOURS_PER_WEEK)

    local b = md[STOCK_KEY]
    if type(b) ~= "table" or b.week ~= week then
        b = { week = week, used = {} }
        md[STOCK_KEY] = b
    end
    if type(b.used) ~= "table" then b.used = {} end

    return b
end

--[[ How many more of this the player may order this week.

     nil means uncapped, and callers have to test for nil rather than for a number --
     `TC.stockLeft(...) < qty` on an uncapped item would be comparing nil and would throw.
     Returns 0 when the week's allowance is spent. ]]
function TC.stockLeft(player, fullType)
    local cap = TC.stockCap(fullType)
    if not cap then return nil end

    local b = bucket(player)
    if not b then return cap end

    local used = b.used[fullType] or 0
    local left = cap - used
    if left < 0 then left = 0 end
    return left
end

--[[ Would this basket fit inside what is left? Reports the first line that does not.

     Checked as a whole rather than line by line, because a cart holding two generators
     has to be refused before any money moves -- a checkout that takes payment and then
     delivers one of them is the half-paid purchase this mod has spent several versions
     learning to avoid. ]]
function TC.stockCheck(player, lines)
    if not lines then return true end

    --[[ Summed per id FIRST. A cart is allowed to hold the same fullType on two lines --
         added twice, at different moments -- and checking each line against the remaining
         allowance separately would let two lines of one through a cap of one. ]]
    local want = {}
    for _, l in ipairs(lines) do
        local ft = l.fullType
        if ft then want[ft] = (want[ft] or 0) + (l.qty or 1) end
    end

    for _, l in ipairs(lines) do
        local ft = l.fullType
        if ft and want[ft] then
            local left = TC.stockLeft(player, ft)
            if left and want[ft] > left then
                return false, (l.name or ft), left, TC.stockCap(ft)
            end
            want[ft] = nil      -- reported once, not once per line
        end
    end

    return true
end

--[[ Record a basket against the week. Call it only once payment has succeeded. ]]
function TC.stockTake(player, lines)
    if not lines then return end

    local b = bucket(player)
    if not b then return end

    for _, l in ipairs(lines) do
        local ft = l.fullType
        if ft and TC.stockCap(ft) then
            b.used[ft] = (b.used[ft] or 0) + (l.qty or 1)
        end
    end
end

--[[ Give the allowance back.

     A cancelled order and a refused delivery are both refunded in money, and an allowance
     that was not given back with it would mean cancelling cost the player their week --
     a charge nothing in the UI mentions and nobody would guess.

     Clamped at zero rather than trusted, because a bucket that rolled over between the
     order and the cancellation has no record of it, and a negative count would hand out
     a free extra next week. ]]
function TC.stockRestore(player, lines)
    if not lines then return end

    local b = bucket(player)
    if not b then return end

    for _, l in ipairs(lines) do
        local ft = l.fullType
        if ft and b.used[ft] then
            local n = b.used[ft] - (l.qty or 1)
            if n <= 0 then n = nil end
            b.used[ft] = n
        end
    end
end
