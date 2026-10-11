--[[ TC_Daily.lua, exercised outside the game.

     This one loads the REAL file. The daily shelf is a pure function of the day number
     over TC.entries, and the only engine things it touches are TC.opt, TC.worldHours,
     TC.buildIndex and TC.log -- four fakes, all trivial.

     WHAT IT IS FOR. Every property below is one a player would notice and nobody could
     debug from a screenshot:

       - the shelf must not change when you reload, or the thing you were about to buy
         vanishes on a load;
       - it must be the same all day and different tomorrow, which is the feature;
       - it must hold exactly N DISTINCT ids -- a draw-until-distinct loop would silently
         deliver 94 items and a duplicate, and a partial Fisher-Yates gets this right only
         if the swap range is right;
       - consecutive days must not overlap heavily, which is the bug a weak seed gives:
         the stream for day 2 starting 16807 away from day 1 reads as "the catalogue
         barely changed overnight";
       - and at a count of zero or one above the catalogue length it must fall back to
         carrying everything rather than to an empty shop.

     Run from the repo root:  luajit tools/tests/daily.lua
     tools/check.sh runs it.
]]

local WORLD_HOURS = 0
local OPTS = { DailyItemCount = 100 }

TheCatalogue = {}
local TC = TheCatalogue
function TC.opt(n) return OPTS[n] end
function TC.worldHours() return WORLD_HOURS end
function TC.log() end
function TC.buildIndex() end

-- A stand-in index of 6,017 entries, the size of the real one.
local TOTAL = 6017
TC.entries = {}
for i = 1, TOTAL do TC.entries[i] = { fullType = "Base.Item" .. i } end

dofile("42/media/lua/shared/TheCatalogue/TC_Daily.lua")

local pass, fail = 0, 0
local function check(l, got, want)
  if got == want then pass = pass + 1
  else fail = fail + 1; print(("FAIL  %-56s got %s want %s"):format(l, tostring(got), tostring(want))) end
end
local function size(set) local n = 0 for _ in pairs(set) do n = n + 1 end return n end
local function atHour(h) WORLD_HOURS = h; TC.dailyCache = nil; return TC.dailyShelf() end

-- ===== the day number =====
WORLD_HOURS = 0;     check("hour 0 is day 0",      TC.dayNumber(), 0)
WORLD_HOURS = 23.9;  check("hour 23.9 is day 0",   TC.dayNumber(), 0)
WORLD_HOURS = 24;    check("hour 24 is day 1",     TC.dayNumber(), 1)
WORLD_HOURS = 999;   check("hour 999 is day 41",   TC.dayNumber(), 41)

-- ===== restock countdown =====
WORLD_HOURS = 0;    check("midnight: 24h to restock", TC.restockHours(), 24)
WORLD_HOURS = 18;   check("18:00: 6h to restock",     TC.restockHours(), 6)
WORLD_HOURS = 47.5; check("23:30 on day 1: 0.5h",     TC.restockHours(), 0.5)

-- ===== exactly N distinct =====
local d5 = atHour(5 * 24)
check("day 5 carries exactly 100 ids", size(d5), 100)

-- ===== same all day =====
local morning = atHour(5 * 24 + 1)
local evening = atHour(5 * 24 + 23)
local same = true
for ft in pairs(morning) do if not evening[ft] then same = false end end
check("same shelf at 01:00 and 23:00", same, true)
check("same size too", size(morning), size(evening))

-- ===== stable across a "reload": cache dropped, same answer =====
local before = {}
for ft in pairs(atHour(9 * 24 + 3)) do before[ft] = true end
TC.dailyCache = nil
local after = atHour(9 * 24 + 20)
local stable = (size(before) == size(after))
for ft in pairs(before) do if not after[ft] then stable = false end end
check("a reload mid-day gives the identical shelf", stable, true)

-- ===== different tomorrow, and not by a little =====
local function overlap(a, b)
  local n = 0
  for ft in pairs(a) do if b[ft] then n = n + 1 end end
  return n
end
local worst = 0
for day = 0, 40 do
  local a, b = {}, nil
  for ft in pairs(atHour(day * 24)) do a[ft] = true end
  b = atHour((day + 1) * 24)
  local o = overlap(a, b)
  if o > worst then worst = o end
end
-- 100 of 6,017 twice over: the expected overlap is 100*100/6017 = 1.7 items.
check("consecutive days overlap by at most 8 of 100", worst <= 8, true)

-- ===== no day produces a degenerate shelf =====
local minSize, maxSize = 1e9, 0
for day = 0, 200 do
  local n = size(atHour(day * 24))
  if n < minSize then minSize = n end
  if n > maxSize then maxSize = n end
end
check("every one of 200 days carries exactly 100", minSize == 100 and maxSize == 100, true)

-- ===== isAvailable agrees with the set =====
WORLD_HOURS = 7 * 24; TC.dailyCache = nil
local shelf = TC.dailyShelf()
local onIt, offIt
for i = 1, TOTAL do
  local ft = "Base.Item" .. i
  if shelf[ft] then onIt = onIt or ft else offIt = offIt or ft end
end
check("isAvailable true for a stocked id",    TC.isAvailable(onIt), true)
check("isAvailable false for an unstocked id", TC.isAvailable(offIt), false)
check("isAvailable false for nil",             TC.isAvailable(nil), false)
check("shelfSize reports 100",                 TC.shelfSize(), 100)

-- ===== the off switch and the overflow =====
OPTS.DailyItemCount = 0; TC.dailyCache = nil
check("0 carries everything (nil shelf)", TC.dailyShelf(), nil)
check("0 makes everything available",     TC.isAvailable("Base.Item1"), true)
check("0 reports no shelf size",          TC.shelfSize(), nil)

OPTS.DailyItemCount = TOTAL; TC.dailyCache = nil
check("count == catalogue length carries everything", TC.dailyShelf(), nil)
OPTS.DailyItemCount = TOTAL + 500; TC.dailyCache = nil
check("count above the length carries everything",    TC.dailyShelf(), nil)

OPTS.DailyItemCount = 1; TC.dailyCache = nil
check("a count of 1 is honoured", size(TC.dailyShelf()), 1)

-- ===== changing the option mid-session takes effect without a reload =====
OPTS.DailyItemCount = 100; TC.dailyCache = nil
local a = size(TC.dailyShelf())
OPTS.DailyItemCount = 250
local b = size(TC.dailyShelf())
check("raising the count re-draws without clearing the cache by hand", a == 100 and b == 250, true)
OPTS.DailyItemCount = 100

-- ===== unavailableLines =====
WORLD_HOURS = 7 * 24; TC.dailyCache = nil
TC.dailyShelf()
local gone = TC.unavailableLines({ { fullType = onIt, name = "Stocked" },
                                   { fullType = offIt, name = "Missing" },
                                   { fullType = offIt, name = "Missing" } })
check("unavailableLines reports only the missing", #gone, 1)
check("and names it",                              gone[1], "Missing")
check("empty basket is fine",                      #TC.unavailableLines({}), 0)
check("nil basket is fine",                        #TC.unavailableLines(nil), 0)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
