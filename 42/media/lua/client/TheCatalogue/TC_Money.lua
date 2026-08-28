--[[ The Catalogue -- physical cash.

     The catalogue trades in real objects, not a balance. That decision is the source
     of every awkward detail in this file, and it is worth stating why each exists.

     PZ HAS NO ITEM STACKING. Every dollar is its own InventoryItem. $10,000 in loose
     notes is ten thousand Java objects weighing 100 kg, and the inventory UI visibly
     struggles well before that. Base.MoneyBundle exists precisely to fix this: it is
     100 notes at 0.5 kg instead of 1.0 kg, and one object instead of a hundred.

     So: we always PAY OUT in bundles and settle the remainder in notes, and we always
     SPEND bundles first. Both rules exist to keep the object count down, not for
     flavour. Vanilla can only unbundle (the UnbundleMoney recipe), never re-bundle,
     so the catalogue is the only thing in the game that hands out bundles.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Collect the player's cash from their main inventory and every bag inside it.

     getAllTypeRecurse walks nested containers, which is the whole point -- money
     lives in wallets, wallets live in bags. It is called with both the full type and
     the bare type because the two spellings appear in the game's own Lua and the
     cheap way to be certain is to try both and take whichever answers.
]]
local function collect(inv, fullType, shortType)
    local out = {}
    if not inv then return out end

    local list = inv:getAllTypeRecurse(fullType)
    if (not list or list:size() == 0) then
        list = inv:getAllTypeRecurse(shortType)
    end
    if not list then return out end

    for i = 0, list:size() - 1 do
        table.insert(out, list:get(i))
    end
    return out
end

function TC.getCash(player)
    if not player then return {}, {} end
    local inv = player:getInventory()
    return collect(inv, TC.MONEY, "Money"),
           collect(inv, TC.MONEY_BUNDLE, "MoneyBundle")
end

--[[ Total dollars the player is carrying. ]]
function TC.getBalance(player)
    local notes, bundles = TC.getCash(player)
    return #notes + (#bundles * TC.NOTES_PER_BUNDLE)
end

local function removeItem(item)
    local c = item:getContainer()
    if c then c:Remove(item) end
end

--[[ Put `amount` into the player's hands as objects, and say nothing about it.

     Declared before takeCash because takeCash makes change through it. The register
     sound belongs to the TRANSACTION, and a purchase that breaks a hundred is still
     one transaction -- routing the change through here rather than through giveCash is
     what stops it ringing twice for one purchase. ]]
local function addCash(player, amount)
    local inv = player:getInventory()
    local PER = TC.NOTES_PER_BUNDLE

    local bundles = math.floor(amount / PER)
    local notes   = amount - bundles * PER

    for _ = 1, bundles do inv:AddItem(TC.MONEY_BUNDLE) end
    for _ = 1, notes   do inv:AddItem(TC.MONEY)        end
end

--[[ Take exactly `amount` dollars off the player, breaking a bundle and returning
     change when the notes do not divide evenly.

     Returns true on success. Returns false and touches nothing when the player is
     short -- the caller must be able to trust that a false leaves the inventory
     exactly as it found it, because the buy path checks affordability and commits
     in the same breath.
]]
function TC.takeCash(player, amount)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return true end

    local notes, bundles = TC.getCash(player)
    local PER = TC.NOTES_PER_BUNDLE

    if (#notes + #bundles * PER) < amount then return false end

    -- Spend bundles down to the last whole hundred first: fewer objects destroyed,
    -- and it keeps the player's loose notes for the small purchases where they help.
    local useBundles = math.min(#bundles, math.floor(amount / PER))
    local owed = amount - useBundles * PER

    local useNotes = math.min(#notes, owed)
    owed = owed - useNotes

    -- Still short by less than a hundred: break one more bundle and make change.
    local change = 0
    if owed > 0 then
        if #bundles > useBundles then
            useBundles = useBundles + 1
            change = PER - owed
            owed = 0
        else
            return false  -- unreachable given the check above, but cheap to be sure
        end
    end

    for i = 1, useBundles do removeItem(bundles[i]) end
    for i = 1, useNotes   do removeItem(notes[i])   end

    if change > 0 then
        addCash(player, change)
    end

    -- Money has changed hands: this is the instant the transaction is real, and the
    -- only place in the mod that has to know it happened.
    TC.playSound(player, "cash")
    return true
end

--[[ Hand the player `amount` dollars as objects, bundled as far as it goes.

     $2,350 arrives as 23 bundles and 50 notes: 73 objects and 12 kg, against
     2,350 objects and 23.5 kg if we paid in notes alone.
]]
function TC.giveCash(player, amount)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return end

    addCash(player, amount)
    TC.playSound(player, "cash")
end

--[[ Weight of a payout before it happens, so the buy panel can warn honestly.
     Bundles are 0.5 kg each and notes 0.01 kg, straight off the item scripts. ]]
function TC.cashWeight(amount)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return 0 end
    local bundles = math.floor(amount / TC.NOTES_PER_BUNDLE)
    local notes   = amount - bundles * TC.NOTES_PER_BUNDLE
    return bundles * 0.5 + notes * 0.01
end
