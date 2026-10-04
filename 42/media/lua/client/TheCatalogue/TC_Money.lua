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

     WHERE THE MONEY IS ALLOWED TO BE. Since 0.14.0 the catalogue will spend out of any
     container the character can reach, not only out of their own pockets -- the crate in
     the safehouse, the till behind the counter, the car boot. See TC.cashSources below
     for which containers those are and why the question is answered by the game rather
     than by a radius of our own choosing.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

-- ---------------------------------------------------------------------------
-- Where the money may come from
-- ---------------------------------------------------------------------------

--[[ The inventories the catalogue is allowed to spend out of, nearest first.

     WHY THIS EXISTS. Keeping a safehouse's cash in a crate used to cost four actions per
     purchase: open the crate, drag the money out, buy, drag it back. The money was
     already within arm's reach and the catalogue refused to see it, which is busywork
     rather than difficulty.

     THE REACH RULE IS THE GAME'S, NOT OURS. The obvious implementation is a radius --
     every square within two tiles, every container on it -- and it is wrong in all the
     ways a radius is wrong: it reaches through walls, through locked doors, up and down
     stairs, and it disagrees with what the player can see in their own loot window.

     The right answer is already computed by the engine every frame. The loot page's
     `backpacks` list IS the set of containers this character can reach right now; it is
     what the inventory UI draws buttons for, and vanilla's own crafting reads exactly
     this list to decide which containers it may consume materials from
     (ISInventoryPaneContextMenu.getContainers). So the rule becomes: if the game would
     let you craft with it, the catalogue will pay with it. Nothing to tune, nothing to
     drift, and no case where the window shows money the player cannot see.

     NOT vanilla's helper directly, for two reasons. It reads
     `getPlayerInventory(n).inventoryPane.inventoryPage.backpacks` with no nil guard, and
     every one of those is nil before the UI is built -- the order paths in this mod run
     from a timed action and a delivery an hour later, and neither is worth a crash. And
     it returns the player's main inventory AND every equipped bag as separate entries,
     which is the double-count trap below.

     Returns the player's own inventory alone when the sandbox option is off, which is
     exactly the behaviour every version before this one had.
]]

--[[ Does some other inventory in `set` already contain this one?

     THE DOUBLE-COUNT TRAP, and it is the whole reason this function exists. Every lookup
     below is getAllTypeRecurse, which descends into nested containers -- so the player's
     main inventory already reports the money in their backpack. The reach list names the
     main inventory and the backpack separately, so summing both counts that money twice:
     the window shows a balance the player does not have, and takeCash then tries to
     remove the same banknote twice and leaves the purchase half-paid.

     Walking UP from a container to whatever holds it is cheap -- a bag in a bag in a bag
     is three links -- and it makes the kept set provably disjoint, which is what lets
     the counting path stay allocation-free. ]]
local function isNested(inv, set)
    local item = inv:getContainingItem()
    local guard = 0

    while item and guard < 16 do
        guard = guard + 1
        local holder = item:getContainer()
        if not holder then return false end
        if set[holder] then return true end
        item = holder:getContainingItem()
    end

    return false
end

-- The backpack buttons of one inventory page, or nothing at all if the UI is not up.
local function addPageContainers(page, out)
    if not page then return end

    local pane = page.inventoryPane
    local ipage = pane and pane.inventoryPage
    local list = ipage and ipage.backpacks
    if type(list) ~= "table" then return end

    for _, button in ipairs(list) do
        local inv = button and button.inventory
        if inv then out[#out + 1] = inv end
    end
end

function TC.cashSources(player)
    if not player then return {} end

    local own = player:getInventory()
    if not own then return {} end

    -- The player's own pockets are always first, so they are always spent first. A
    -- purchase a player could already afford on their own behaves exactly as it did
    -- before this feature existed.
    local sources = { own }
    if not TC.opt("SpendFromContainers") then return sources end

    local playerNum = player:getPlayerNum()
    if type(playerNum) ~= "number" or playerNum < 0 then return sources end

    --[[ Both globals exist in every client context this mod runs in, and both are checked
         anyway: calling a nil is a hard Kahlua error rather than a nil result, and a
         purchase is not worth a crash over a UI that has not been built yet. ]]
    if not (getPlayerInventory and getPlayerLoot) then return sources end

    local candidates = {}
    addPageContainers(getPlayerInventory(playerNum), candidates)
    addPageContainers(getPlayerLoot(playerNum), candidates)

    -- Identity set, built before anything is filtered: nesting has to be judged against
    -- the whole candidate list, not against the part of it already walked.
    local seen = { [own] = true }
    local present = { [own] = true }
    for _, inv in ipairs(candidates) do present[inv] = true end

    for _, inv in ipairs(candidates) do
        if not seen[inv] and not isNested(inv, present) then
            --[[ A crate the character cannot open is not money they have. Vanilla's own
                 helper makes this same check and only for IsoThumpable, which is the
                 player-built class that carries a lock; a vanilla counter has no such
                 notion and needs no test. ]]
            local parent = inv:getParent()
            local locked = instanceof(parent, "IsoThumpable")
                           and parent:isLockedToCharacter(player)

            if not locked then
                seen[inv] = true
                sources[#sources + 1] = inv
            end
        end
    end

    return sources
end

--[[ The Java list of one money type held in one inventory, or nil.

     getAllTypeRecurse walks nested containers, which is the whole point -- money lives in
     wallets, wallets live in bags. It is also the reason TC.cashSources has to hand this
     function a set of inventories none of which contains another.

     Called with both the full type and the bare type because the two spellings appear in
     the game's own Lua and the cheap way to be certain is to try both and take whichever
     answers.

     Split out of collect so that the counting path can stop here, with no array built. ]]
local function listOf(inv, fullType, shortType)
    if not inv then return nil end

    local list = inv:getAllTypeRecurse(fullType)
    if (not list or list:size() == 0) then
        list = inv:getAllTypeRecurse(shortType)
    end
    return list
end

local function collect(inv, fullType, shortType)
    local out = {}
    local list = listOf(inv, fullType, shortType)
    if not list then return out end

    for i = 0, list:size() - 1 do
        out[i + 1] = list:get(i)
    end
    return out
end

--[[ Every note and every bundle held in the given inventories.

     The two arrays are in source order, so the caller can rely on the front of each
     being the nearest money. No de-duplication is needed: TC.cashSources has already
     guaranteed the sources do not contain one another. ]]
local function cashFrom(sources)
    local notes, bundles = {}, {}

    for _, inv in ipairs(sources) do
        local n = collect(inv, TC.MONEY, "Money")
        for i = 1, #n do notes[#notes + 1] = n[i] end

        local b = collect(inv, TC.MONEY_BUNDLE, "MoneyBundle")
        for i = 1, #b do bundles[#bundles + 1] = b[i] end
    end

    return notes, bundles
end

--[[ There is deliberately no TC.getCash wrapper over this.

     There was one, taking a player and collecting from every source, and takeCash was its
     only caller -- until takeCash had to offer the pockets alone before the containers
     and started calling cashFrom directly with the list it wanted. A one-line function
     with no callers is worse than no function: the next reader assumes something uses it
     and preserves its behaviour. ]]

--[[ Total dollars the player can spend.

     COUNTED, NOT COLLECTED, and the difference is the whole reason this does not just
     take `#notes` off cashFrom.

     Every dollar is its own InventoryItem, so a player with $4,000 in loose notes has
     four thousand of them. cashFrom builds a Lua array holding all four thousand -- which
     is exactly right when you are about to SPEND them and have to pick which objects go,
     and pure waste when the only question is how many there are. The buy window asks
     that question once a frame and the cash machine once, so at sixty frames a second
     it was building a quarter of a million table slots per second to print one number.

     The Java list already knows its own length. Reading :size() off it costs one call
     and allocates nothing. ]]
local function countOf(inv, fullType, shortType)
    local list = listOf(inv, fullType, shortType)
    return (list and list:size()) or 0
end

--[[ What one inventory is worth, notes plus bundles. ]]
local function balanceOf(inv)
    return countOf(inv, TC.MONEY, "Money")
         + countOf(inv, TC.MONEY_BUNDLE, "MoneyBundle") * TC.NOTES_PER_BUNDLE
end

function TC.getBalance(player)
    if not player then return 0 end

    local total = 0
    for _, inv in ipairs(TC.cashSources(player)) do
        total = total + balanceOf(inv)
    end
    return total
end

--[[ The same figure split in two: what is in the character's own pockets, and what is
     merely within reach of them.

     The buy window prints the total and has to be able to say which kind of money it is
     looking at, because "you have $40,000" reads very differently when $39,000 of it is
     in a crate behind you. Returning both from one walk rather than letting the window
     subtract two separate calls, which would walk the containers twice. ]]
function TC.cashSplit(player)
    if not player then return 0, 0 end

    local own, nearby = 0, 0
    for i, inv in ipairs(TC.cashSources(player)) do
        if i == 1 then own = balanceOf(inv)
        else           nearby = nearby + balanceOf(inv) end
    end
    return own, nearby
end

local function removeItem(item)
    local c = item:getContainer()
    if c then c:Remove(item) end
end

--[[ Put `amount` into the player's hands as objects, and say nothing about it.

     Declared before takeCash because takeCash makes change through it. The register
     sound belongs to the TRANSACTION, and a purchase that breaks a hundred is still
     one transaction -- routing the change through here rather than through giveCash is
     what stops it ringing twice for one purchase.

     `into` is where the objects land, defaulting to the player. takeCash passes the
     container it broke a bundle out of, so change from a crate goes back into the crate
     rather than into the pockets of a player who deliberately keeps their money out of
     them. ]]
local function addCash(player, amount, into)
    local inv = into or player:getInventory()
    local PER = TC.NOTES_PER_BUNDLE

    local bundles = math.floor(amount / PER)
    local notes   = amount - bundles * PER

    for _ = 1, bundles do inv:AddItem(TC.MONEY_BUNDLE) end
    for _ = 1, notes   do inv:AddItem(TC.MONEY)        end
end

--[[ Take exactly `amount` dollars, breaking a bundle and returning change when the
     notes do not divide evenly.

     Returns true on success. Returns false and touches nothing when the money is not
     there -- the caller must be able to trust that a false leaves every inventory
     exactly as it found it, because the buy path checks affordability and commits
     in the same breath.

     POCKETS FIRST, AND THAT IS A TWO-STEP, NOT AN ORDERING. Since 0.14.0 a reachable
     crate can pay for a purchase, and the obvious implementation is to hand the whole
     pool to the rule below and let source order do the rest. It is not enough, and a test
     caught why: the rule prefers spending loose notes over breaking a bundle, so a player
     carrying two bundles who wanted a $150 item had the crate's ten loose notes taken to
     save breaking one of their own. Arithmetically correct, and still wrong -- it reached
     into a container for money the character already had on them.

     So the pool is tried in two passes. What the character is carrying is offered alone
     first, and the containers join only if that cannot cover the price. A purchase they
     could afford unaided therefore takes exactly the objects it always took, which is a
     promise worth being able to make rather than merely hoping for.
]]
function TC.takeCash(player, amount)
    amount = math.floor(amount + 0.5)
    if amount <= 0 then return true end

    local PER = TC.NOTES_PER_BUNDLE
    local sources = TC.cashSources(player)

    local notes, bundles = cashFrom({ sources[1] })
    if (#notes + #bundles * PER) < amount and #sources > 1 then
        notes, bundles = cashFrom(sources)
    end

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

    -- Read BEFORE the removal, because a removed item has no container to ask. The
    -- bundle that gets broken is the last one taken, so its home is where the change
    -- belongs; nil falls back to the player, which is what a floor container gives.
    local changeTo = nil
    if change > 0 and bundles[useBundles] then
        changeTo = bundles[useBundles]:getContainer()
    end

    for i = 1, useBundles do removeItem(bundles[i]) end
    for i = 1, useNotes   do removeItem(notes[i])   end

    if change > 0 then
        addCash(player, change, changeTo)
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
