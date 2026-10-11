--[[ TC_Stock.lua, exercised outside the game.

     WHY THIS CAN EXIST AT ALL. Almost nothing in this mod can be tested without the game:
     it needs a world, an inventory and a Java API. TC_Stock is the exception -- it is
     arithmetic over a table on modData, and the only engine things it touches are
     TC.opt, TC.getBuyPrice and TC.worldHours, all three of which are three lines to fake.
     So this file loads the REAL TC_Stock.lua against a fake engine and pins its
     behaviour, rather than reimplementing it and testing the copy.

     WHAT IT IS FOR. Every assertion below is a bug that would otherwise be silent: a cap
     dodged by splitting a cart into two lines of one, an allowance not returned when an
     order is cancelled, a week that never rolls over, a multiplier of 0.4 quietly
     removing an item from the shop by capping it at zero. None of those crash, and none
     of them are visible without counting.

     Run from the repo root:  luajit tools/tests/stock.lua
     tools/check.sh runs it.
]]

-- Load TC_Stock.lua for real, against a fake engine.
local WORLD_HOURS = 0
local SHELF = {}
local OPTS = { StockLimitMultiplier = 1.0 }

TheCatalogue = {}
local TC = TheCatalogue
function TC.opt(n) return OPTS[n] end
function TC.getBuyPrice(ft) return SHELF[ft] end
function TC.worldHours() return WORLD_HOURS end

local PLAYER = { md = {}, getModData = function(self) return self.md end }
function getGameTime() return nil end

dofile("42/media/lua/shared/TheCatalogue/TC_Stock.lua")

local pass, fail = 0, 0
local function check(l, got, want)
  if got == want then pass = pass + 1
  else fail = fail + 1; print(("FAIL  %-52s got %s want %s"):format(l, tostring(got), tostring(want))) end
end

SHELF["gen"]    = 13500   -- band 1/week
SHELF["pistol"] = 4400    -- band 3/week  (>=1000)
SHELF["crow"]   = 225     -- uncapped (<250)
SHELF["saw"]    = 300     -- band 10/week
SHELF["rifle"]  = 12600   -- band 1/week

-- ===== caps =====
check("gen cap 1",        TC.stockCap("gen"), 1)
check("rifle cap 1",      TC.stockCap("rifle"), 1)
check("pistol cap 3",     TC.stockCap("pistol"), 3)
check("saw cap 10",       TC.stockCap("saw"), 10)
check("crowbar uncapped", TC.stockCap("crow"), nil)
check("unknown uncapped", TC.stockCap("nope"), nil)

-- ===== left / take =====
check("gen left 1",  TC.stockLeft(PLAYER, "gen"), 1)
TC.stockTake(PLAYER, { { fullType = "gen", qty = 1 } })
check("gen left 0 after one", TC.stockLeft(PLAYER, "gen"), 0)
check("crowbar still nil",    TC.stockLeft(PLAYER, "crow"), nil)

-- ===== check refuses over cap =====
local ok, name, left = TC.stockCheck(PLAYER, { { fullType = "gen", name = "Generator", qty = 1 } })
check("second gen refused", ok, false)
check("refusal names it",   name, "Generator")
check("refusal says 0 left", left, 0)
check("uncapped basket ok", TC.stockCheck(PLAYER, { { fullType = "crow", qty = 999 } }), true)

-- ===== the duplicate-line hole =====
local p2 = { md = {}, getModData = function(self) return self.md end }
local two = { { fullType = "gen", name = "Generator", qty = 1 },
              { fullType = "gen", name = "Generator", qty = 1 } }
check("two lines of one capped item refused", TC.stockCheck(p2, two), false)
local three = { { fullType = "pistol", name = "M9", qty = 2 },
                { fullType = "pistol", name = "M9", qty = 2 } }
check("2+2 pistols over a cap of 3 refused", TC.stockCheck(p2, three), false)
local fits = { { fullType = "pistol", name = "M9", qty = 1 },
               { fullType = "pistol", name = "M9", qty = 2 } }
check("1+2 pistols within a cap of 3 allowed", TC.stockCheck(p2, fits), true)

-- ===== restore =====
local p3 = { md = {}, getModData = function(self) return self.md end }
TC.stockTake(p3, { { fullType = "pistol", qty = 3 } })
check("3 pistols used", TC.stockLeft(p3, "pistol"), 0)
TC.stockRestore(p3, { { fullType = "pistol", qty = 2 } })
check("restore 2 -> 2 left", TC.stockLeft(p3, "pistol"), 2)
TC.stockRestore(p3, { { fullType = "pistol", qty = 99 } })
check("over-restore clamps, not negative", TC.stockLeft(p3, "pistol"), 3)

-- ===== week rollover =====
local p4 = { md = {}, getModData = function(self) return self.md end }
TC.stockTake(p4, { { fullType = "gen", qty = 1 } })
check("gen spent", TC.stockLeft(p4, "gen"), 0)
WORLD_HOURS = 167
check("same week still 0", TC.stockLeft(p4, "gen"), 0)
WORLD_HOURS = 168
check("next week resets", TC.stockLeft(p4, "gen"), 1)
WORLD_HOURS = 0

-- ===== multiplier =====
OPTS.StockLimitMultiplier = 0
check("0 disables all caps", TC.stockCap("gen"), nil)
check("0 -> left is nil",    TC.stockLeft(PLAYER, "gen"), nil)
OPTS.StockLimitMultiplier = 2.0
check("2x doubles the gen",  TC.stockCap("gen"), 2)
check("2x doubles pistols",  TC.stockCap("pistol"), 6)
OPTS.StockLimitMultiplier = 0.4
check("0.4x gen never below 1", TC.stockCap("gen"), 1)
check("0.4x pistol rounds up",  TC.stockCap("pistol"), 2)
OPTS.StockLimitMultiplier = 1.0

-- ===== nil safety =====
check("nil player -> cap still known", TC.stockLeft(nil, "gen"), 1)
check("nil lines check ok", TC.stockCheck(PLAYER, nil), true)

print(("\n%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
