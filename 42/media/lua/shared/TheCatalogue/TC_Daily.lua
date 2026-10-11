--[[ The Catalogue -- what the company actually has on the shelf today.

     A mail-order company with one warehouse, no suppliers left and a county of looters
     does not have 6,017 lines in stock. It has what came in. So the catalogue carries a
     selection that changes every day: a hundred items, drawn at random, the same hundred
     for the whole day and a different hundred tomorrow.

     DERIVED, NOT STORED, and that is the whole design of this file. The obvious
     implementation writes today's list to the player's modData and rolls it over on a
     tick, which means a list that can be lost, a list that can be two lists if two
     windows disagree, and a rollover that has to happen even while nobody is looking.
     Instead the list is a pure function of the day number: the same arithmetic always
     produces the same hundred ids, so there is nothing to save, nothing to migrate, and
     no way for a reload to hand the player a different shelf than the one they were
     looking at a second ago.

     KAHLUA HAS NO BITWISE OPERATORS, which rules out every hash worth using. The engine's
     own ZombRand is no good either -- it is not seedable from Lua, so it cannot be made to
     agree with itself twice -- and math.randomseed would be worse than useless: it reseeds
     the ONE generator the whole game shares, so picking a shopping list would perturb
     zombie spawns and loot rolls. The generator below is Park and Miller's minimal
     standard, which needs only multiplication and modulo and keeps every intermediate
     value under 2^53 so a double holds it exactly.

     THE SELL SIDE IS NOT AFFECTED. The company buys what you bring it whether or not it
     happens to be selling one today -- a shop that refused to buy your axe because axes
     are Thursday's stock would be absurd, and it would make the sell window a lottery.
     Only the shelf rotates.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local HOURS_PER_DAY = 24

--[[ Park-Miller: x = 16807x mod (2^31 - 1).

     16807 x 2147483646 is about 3.6e13, comfortably inside the 9e15 a double represents
     exactly, which is the property that makes this one safe on an interpreter with no
     integers. The period is the full 2^31 - 2 and the stream is good enough for choosing
     a shopping list; it is not good enough for anything cryptographic and is not used for
     anything of the kind.

     Zero is the one fixed point -- 16807 x 0 is 0 forever -- so a seed of zero is moved
     off it rather than silently producing the same item 100 times. ]]
local M = 2147483647

local function seedFrom(day)
    --[[ 1103515245 is the Numerical Recipes multiplier, used here only to smear
         consecutive days apart before the stream starts. Without it day 1 and day 2 begin
         16807 apart and their first few draws overlap heavily, which shows up as "the
         catalogue barely changed overnight". ]]
    local s = (day * 1103515245 + 12345) % M
    if s <= 0 then s = s + M - 1 end
    return s
end

local function nextRand(s)
    return (16807 * s) % M
end

-- ---------------------------------------------------------------------------
-- Which day it is
-- ---------------------------------------------------------------------------

--[[ Days since the world was created.

     NOT getGameTime():getDay(), which is the day of the MONTH and goes back to 1 every
     thirty days -- a shelf that repeated monthly would be the same twelve catalogues for
     ever. World age is monotonic, survives a save, and is the same clock the order ledger
     and the weekly stock bucket read, so the three cannot disagree about when a day
     turned over. ]]
function TC.dayNumber()
    return math.floor(TC.worldHours() / HOURS_PER_DAY)
end

--[[ Game hours until the shelf changes, for the window to print.

     A player looking at something they cannot afford needs to know whether to come back
     with more money or to come back at all. ]]
function TC.restockHours()
    local h = TC.worldHours()
    return HOURS_PER_DAY - (h - math.floor(h / HOURS_PER_DAY) * HOURS_PER_DAY)
end

-- ---------------------------------------------------------------------------
-- Today's shelf
-- ---------------------------------------------------------------------------

--[[ How many lines the company carries, or nil for "all of them".

     Zero turns the whole feature off and restores every version before 0.16.0, which is
     also what happens if an admin sets it higher than the catalogue is long. ]]
local function dailyCount()
    local n = TC.opt("DailyItemCount")
    if type(n) ~= "number" or n <= 0 then return nil end
    return math.floor(n)
end

--[[ The set of fullTypes on sale today, or nil when everything is.

     PARTIAL FISHER-YATES, not "draw a random index until you have a hundred distinct
     ones". The retry loop looks simpler and is the wrong shape: it has no upper bound on
     iterations, and it degenerates badly exactly when an admin sets the count close to the
     length of the catalogue, which is the setting most likely to be tried. Shuffling the
     first N of an index array is O(N) with no retries and no worst case.

     Cached against the day AND the count, so changing the sandbox option mid-session
     takes effect on the next look rather than after a reload. ]]
function TC.dailyShelf()
    local count = dailyCount()
    if not count then return nil end

    TC.buildIndex()
    local entries = TC.entries
    if not entries or #entries == 0 then return nil end

    local total = #entries
    if count >= total then return nil end     -- carrying everything; no point filtering

    local day = TC.dayNumber()

    local cache = TC.dailyCache
    if cache and cache.day == day and cache.count == count and cache.total == total then
        return cache.set
    end

    -- 1..total, then shuffle only as far as we need to read.
    local order = {}
    for i = 1, total do order[i] = i end

    local s = seedFrom(day)
    local set = {}
    local list = {}

    for i = 1, count do
        s = nextRand(s)
        -- Uniform over the part of the array not yet drawn from.
        local j = i + (s % (total - i + 1))
        order[i], order[j] = order[j], order[i]

        local e = entries[order[i]]
        if e and e.fullType then
            set[e.fullType] = true
            list[#list + 1] = e.fullType
        end
    end

    TC.dailyCache = { day = day, count = count, total = total, set = set, list = list }
    TC.log("shelf for day %d: %d of %d lines", day, #list, total)
    return set
end

--[[ Is this id on sale right now?

     The ONE question every caller asks, and the only one they should: an entry that is not
     on today's shelf must not be orderable from the window, from the cart, or from the
     online catalogue, and all three go through here.

     True when the feature is off, so every call site reads naturally as "can I buy this"
     rather than having to know whether rotation is enabled. ]]
function TC.isAvailable(fullType)
    if not fullType then return false end
    local set = TC.dailyShelf()
    if not set then return true end
    return set[fullType] == true
end

--[[ How many lines are on the shelf today, for the window's header. nil when uncapped. ]]
function TC.shelfSize()
    local set = TC.dailyShelf()
    if not set then return nil end
    local cache = TC.dailyCache
    return cache and cache.list and #cache.list or 0
end

--[[ Every line of a basket that is not in stock, by name. Empty when the basket is fine.

     Reported as a list rather than as the first offender, because a cart assembled
     yesterday can have several lines that went out of stock overnight and telling the
     player about them one checkout at a time would be a cruel way to spend an evening. ]]
function TC.unavailableLines(lines)
    local out = {}
    if not lines then return out end

    local seen = {}
    for _, l in ipairs(lines) do
        local ft = l.fullType
        if ft and not seen[ft] and not TC.isAvailable(ft) then
            seen[ft] = true
            out[#out + 1] = l.name or ft
        end
    end
    return out
end
