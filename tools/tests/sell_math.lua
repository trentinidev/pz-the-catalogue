--[[ The sell arithmetic, pinned.

     This one does NOT load the real file: the spread lives inside rawValue, which needs
     an InventoryItem, a container graph and four vanilla classes to reach. What it does
     instead is restate the three lines of arithmetic exactly as TC_Prices.lua performs
     them -- node value, dollar floor, one multiply at the end -- and assert the
     invariants those three lines are supposed to guarantee.

     That is a copy, and a copy can drift from the original. It is still worth having,
     because the invariants are the part that is easy to break and hard to notice: the
     0.15.0 category rates divided the floor by the rate as well as by the spread, which
     floored the 0.5 categories at $2 and the 2.5 categories at 40 cents. The code looked
     right, the game looked fine, and the number was wrong. This file caught it.

     IF YOU CHANGE THE SPREAD MATH IN TC_Prices.lua, change it here too, and expect the
     assertions rather than the model to tell you whether you were right.

     Run from the repo root:  luajit tools/tests/sell_math.lua
     tools/check.sh runs it.
]]

-- The sell arithmetic exactly as TC_Prices does it, to pin the invariants.
local MIN_SELL = 1
local function nodeValue(unit, cond, rate, spread)
  local value = unit * cond * rate
  if spread > 0 then
    local floorRaw = MIN_SELL / spread
    if value < floorRaw then value = floorRaw end
  end
  return value
end
local function payout(nodes, spread)        -- spread applied ONCE to the total
  local sum = 0
  for _, n in ipairs(nodes) do sum = sum + nodeValue(n[1], n[2], n[3], spread) end
  return math.max(0, math.floor(sum * spread + 0.5))
end

local pass, fail = 0, 0
local function check(l, got, want)
  if got == want then pass = pass + 1
  else fail = fail + 1; print(("FAIL  %-54s got %s want %s"):format(l, tostring(got), tostring(want))) end
end

local S = 0.10   -- default SellRatio

-- ===== the floor is exactly $1 at EVERY rate =====
for _, r in ipairs({0.5, 1.0, 1.5, 2.5}) do
  check(("rate %.1f: a $5 shelf item pays the $1 floor"):format(r),
        payout({ {5, 1, r} }, S), 1)
end

-- ===== rates actually differentiate above the floor =====
check("rifle shelf 3780 at 2.5x pays 945", payout({ {3780, 1, 2.5} }, S), 945)
check("same item at 1.0x pays 378",        payout({ {3780, 1, 1.0} }, S), 378)
check("ornament shelf 600 at 0.5x pays 30",payout({ {600, 1, 0.5} }, S), 30)
check("same ornament at 1.0x pays 60",     payout({ {600, 1, 1.0} }, S), 60)

-- ===== condition still scales =====
check("half-condition axe 355 at 2.5x",    payout({ {355, 0.5, 2.5} }, S), 44)

-- ===== a mixed bag: each node keeps its own rate =====
check("rifle + ornament in one bag",
      payout({ {3780, 1, 2.5}, {600, 1, 0.5} }, S), 975)

-- ===== forty junk items in a bag still pay forty dollars =====
local bag = {}
for i = 1, 40 do bag[i] = {5, 1, 0.5} end
check("40 floor items in a bag pay $40, not $1", payout(bag, S), 40)

-- ===== SellRatio 0 means nothing, and does not divide by zero =====
check("SellRatio 0 pays 0", payout({ {3780, 1, 2.5} }, 0), 0)

-- ===== doubling SellRatio doubles everything (rates stay relative) =====
check("0.20 ratio doubles the rifle", payout({ {3780, 1, 2.5} }, 0.20), 1890)

-- ===== the round-trip is still a loss at every rate =====
for _, r in ipairs({0.5, 1.0, 1.5, 2.5}) do
  local shelf = 3780
  local back = payout({ {shelf, 1, r} }, S)
  check(("rate %.1f: buying then reselling loses money"):format(r), back < shelf, true)
end

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
