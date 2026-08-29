--[[ The Catalogue -- the account behind the cash machine.

     WHY A BANK AT ALL. The catalogue trades in physical notes, and TC_Money.lua opens
     with the reason: every dollar is its own InventoryItem, so carrying a fortune means
     carrying thousands of Java objects and tens of kilos. MoneyBundle takes the edge off
     it -- a hundred notes in one object at half the weight -- and it is still weight, and
     it is still lost with the bag it was in.

     An account is the other half of that answer. Money in it is a NUMBER, weighing
     nothing and occupying nothing, and the only way in or out is a machine bolted to a
     wall in a town somewhere. That is the trade: the cash on your hip is spendable
     anywhere and vulnerable to everything, and the cash in the account is safe and
     several miles away.

     NOTHING IS CREATED HERE. Every dollar in an account was carried to a machine and put
     in. Deposit takes real items off the player through TC.takeCash and withdrawal hands
     real items back through TC.giveCash, so the total money in a save is exactly what it
     would have been -- the account only changes where it is being kept. There is no
     interest, no overdraft and no fee, because all three would mint or burn money that
     the rest of the mod believes it can count.

     WHERE IT LIVES. On player:getModData(), next to the wishlist and the ledger, for the
     reason written at length in TC_SellWindow.lua: Lua is given no save hook in this game
     beyond OnPlayerDeath, so anything that must survive a quit has to ride on the
     character. One account per character, which is also the only reading that makes sense
     of a card with a name printed on it.

     THE CARD IS NOT THE MONEY. It would have been easier to keep the balance on the card
     item and let the money travel with it, and it would have been wrong: an item worth
     ten thousand dollars is an item worth killing a player for and losing to a bag left
     in a burning house, which is the exact problem the account was meant to solve. The
     card is a CREDENTIAL. Lose it and the machine prints another one once you have
     entered the PIN; the balance never moved.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local ACCOUNT_KEY = "TheCatalogue_Account"

--[[ How many statement lines to keep.

     modData is written into the save file, so an unbounded statement grows it forever --
     the same reasoning, and the same fix, as the ledger's MAX_ENTRIES. Fifty is about two
     screens of scrolling and costs a couple of kilobytes; the oldest fall off the end. ]]
local MAX_ENTRIES = 50

-- Four digits, because that is what a cash machine asks for. The keypad in TC_ATMWindow
-- reads this rather than assuming it, so the two cannot disagree.
TC.PIN_LENGTH = 4

-- ---------------------------------------------------------------------------
-- The account
-- ---------------------------------------------------------------------------

--[[ The account, or nil when this character has never opened one.

     NIL AND NOT AN EMPTY TABLE. Every caller has to tell "no account" from "an account
     with nothing in it" -- the first offers to open one, the second offers to deposit --
     and a helper that quietly created the account on being asked about it would make the
     first state unreachable. TC.openAccount is the only thing here that writes. ]]
function TC.account(player)
    if not player then return nil end
    local md = player:getModData()
    if type(md[ACCOUNT_KEY]) ~= "table" then return nil end
    return md[ACCOUNT_KEY]
end

function TC.hasAccount(player)
    return TC.account(player) ~= nil
end

--[[ Dollars in the account. Zero when there is no account, so a caller that only wants
     to print a figure does not have to check first. ]]
function TC.bankBalance(player)
    local acct = TC.account(player)
    if not acct then return 0 end
    return math.floor((acct.balance or 0) + 0.5)
end

--[[ The name that goes on the card: the CHARACTER's, never the player's.

     getDescriptor is the survivor sheet the character was rolled from, so this is the
     forename and surname chosen at the start of the save. player:getUsername() is the
     multiplayer login and would print a Steam handle on a 1993 credit card.

     Falls back rather than failing. A character with no surname is ordinary, and a
     descriptor that answers nothing at all is not worth refusing an account over. ]]
function TC.accountHolder(player)
    if not player then return getText("IGUI_TC_BankHolderUnknown") end

    local ok, name = pcall(function()
        local desc = player:getDescriptor()
        if not desc then return nil end

        local fore = desc:getForename() or ""
        local sur  = desc:getSurname() or ""

        local both = fore
        if sur ~= "" then
            if both ~= "" then both = both .. " " .. sur else both = sur end
        end
        if both == "" then return nil end
        return both
    end)

    if ok and type(name) == "string" and name ~= "" then return name end
    return getText("IGUI_TC_BankHolderUnknown")
end

--[[ A sixteen-digit number in the four groups a card is printed in.

     Cosmetic in every respect but one: it is also the KEY that ties a card item to an
     account, so two characters in the same save cannot pick up each other's plastic and
     have it work. Sixteen random digits collide often enough to worry about only in a
     save with some millions of characters in it.

     ZombRand rather than math.random: it is the game's own generator, and it is the one
     that behaves identically on both sides of the client/server split. ]]
local function newAccountNumber()
    local groups = {}
    for i = 1, 4 do
        groups[i] = string.format("%04d", ZombRand(10000))
    end
    return table.concat(groups, " ")
end

--[[ Four characters, all of them digits.

     string.rep rather than a written-out "^%d%d%d%d$", so that changing TC.PIN_LENGTH
     changes the check with it instead of leaving a validator that quietly disagrees with
     the keypad. ]]
function TC.isValidPin(pin)
    if type(pin) ~= "string" then return false end
    if #pin ~= TC.PIN_LENGTH then return false end
    return string.match(pin, "^" .. string.rep("%d", TC.PIN_LENGTH) .. "$") ~= nil
end

--[[ Write one statement line, newest first.

     TC.gameStamp is the ledger's world clock, over in TC_History.lua, because the ledger
     needed it first. Shared Lua loads alphabetically so that file is read AFTER this one,
     which does not matter: nothing here runs until a player is standing at a machine. ]]
local function push(acct, kind, amount, balance)
    if type(acct.entries) ~= "table" then acct.entries = {} end

    table.insert(acct.entries, 1, {
        kind    = kind,
        amount  = math.floor((amount or 0) + 0.5),
        balance = math.floor((balance or 0) + 0.5),
        when    = TC.gameStamp(),
    })

    while #acct.entries > MAX_ENTRIES do
        table.remove(acct.entries)
    end
end

--[[ Open the account and print the first card.

     Returns the account, or nil when the PIN is not four digits. The keypad cannot
     produce anything else; checking anyway is what keeps this safe to call from
     somewhere that is not the keypad.

     It refuses to open a SECOND one. One account per character is the whole model, and a
     call that asked twice would otherwise write a fresh zero balance over the old one --
     which is the shape this bug would have taken. Asking twice hands back what is
     already there. ]]
function TC.openAccount(player, pin)
    if not player then return nil end
    if not TC.isValidPin(pin) then return nil end

    local existing = TC.account(player)
    if existing then return existing end

    local acct = {
        number  = newAccountNumber(),
        holder  = TC.accountHolder(player),
        pin     = pin,
        balance = 0,
        opened  = TC.gameStamp(),
        entries = {},
    }
    player:getModData()[ACCOUNT_KEY] = acct

    push(acct, "open", 0, 0)
    TC.issueCard(player)
    return acct
end

function TC.checkPin(player, pin)
    local acct = TC.account(player)
    if not acct then return false end
    return acct.pin ~= nil and acct.pin == pin
end

--[[ Statement lines, newest first. Always a table, so the list box can be filled from it
     without a nil check on a character who has never banked. ]]
function TC.statement(player)
    local acct = TC.account(player)
    if not acct or type(acct.entries) ~= "table" then return {} end
    return acct.entries
end

-- ---------------------------------------------------------------------------
-- Moving money
-- ---------------------------------------------------------------------------

--[[ Notes and bundles in, a number out.

     THE ORDER MATTERS AND IT IS NOT THE OBVIOUS ONE. The cash is taken FIRST and the
     balance credited only once that has succeeded, because TC.takeCash is the half that
     can fail -- it walks the inventory, breaks a bundle and makes change, and it promises
     to touch nothing at all when the player turns out to be short. Crediting first and
     taking second would mint money on exactly that failure.

     Returns true, or false and a translated reason the caller can put on screen. ]]
function TC.bankDeposit(player, amount)
    local acct = TC.account(player)
    if not acct then return false, getText("IGUI_TC_BankNoAccount") end

    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return false, getText("IGUI_TC_BankBadAmount") end

    if TC.getBalance(player) < amount then
        return false, getText("IGUI_TC_BankNotEnoughCash")
    end
    if not TC.takeCash(player, amount) then
        return false, getText("IGUI_TC_BankNotEnoughCash")
    end

    acct.balance = TC.bankBalance(player) + amount
    push(acct, "deposit", amount, acct.balance)
    return true
end

--[[ A number in, notes and bundles out.

     The mirror of the above, and the ordering is mirrored with it: the balance is DEBITED
     first here, because TC.giveCash cannot fail -- it adds items to an inventory that is
     allowed to be over capacity, exactly as a purchase does. Handing the cash over and
     then discovering the account was short is the failure this ordering removes.

     NO WEIGHT CHECK. The catalogue already lets a player buy themselves immobile and says
     so rather than refusing, and a machine that would not give you your own money back
     because it was heavy would be a worse rule than the one the rest of the mod plays by.
     TC.cashWeight is what the withdraw screen states up front instead. ]]
function TC.bankWithdraw(player, amount)
    local acct = TC.account(player)
    if not acct then return false, getText("IGUI_TC_BankNoAccount") end

    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return false, getText("IGUI_TC_BankBadAmount") end

    local have = TC.bankBalance(player)
    if have < amount then
        return false, getText("IGUI_TC_BankNotEnoughFunds")
    end

    acct.balance = have - amount
    push(acct, "withdraw", amount, acct.balance)
    TC.giveCash(player, amount)
    return true
end

-- ---------------------------------------------------------------------------
-- The card
-- ---------------------------------------------------------------------------

--[[ Is this item plastic belonging to SOME account?

     Deliberately not "does it belong to THIS player". The sell window uses it to refuse a
     card, and refusing every bound card -- including one looted off a body -- is the right
     answer there: the catalogue has no way to know whose it is, and the thing is worth a
     dollar as an object and an account as a key. ]]
function TC.isBankCard(item)
    if not item then return false end
    local md = item:getModData()
    return md ~= nil and md.TC_account ~= nil
end

--[[ This character's own card, wherever it is on them.

     getAllTypeRecurse, and both spellings of the type, for the reason TC_Money.lua gives:
     a card lives in a wallet and a wallet lives in a bag, and the game's own Lua is
     inconsistent about whether these lookups want "Base.CreditCard" or "CreditCard".
     Trying both and taking whichever answers is cheaper than being certain. ]]
function TC.findCard(player)
    local acct = TC.account(player)
    if not player or not acct then return nil end

    local inv = player:getInventory()
    if not inv then return nil end

    local list = inv:getAllTypeRecurse(TC.CARD_ITEM)
    if (not list or list:size() == 0) then
        list = inv:getAllTypeRecurse("CreditCard")
    end
    if not list then return nil end

    for i = 0, list:size() - 1 do
        local item = list:get(i)
        local md = item:getModData()
        if md and md.TC_account == acct.number then return item end
    end
    return nil
end

--[[ Print a card and bind it to the account.

     VANILLA'S OWN ITEM, not one of ours. Base.CreditCard already exists, already has an
     icon and a world model, and already carries base:fitswallet so it goes where a card
     should go. A Catalogue.CreditCard would have meant shipping art to draw the same
     rectangle of plastic, and it would have made every card the world spawns visibly
     not-a-card beside ours.

     What makes it OURS is the modData and the name. setCustomName is the flag that stops
     the game re-deriving the display name from the script -- the step that is easy to
     leave out and that makes the rename look like it silently failed -- and syncItemFields
     is what vanilla's own rename does afterwards so that open inventory panes redraw. ]]
function TC.issueCard(player)
    local acct = TC.account(player)
    if not player or not acct then return nil end

    local inv = player:getInventory()
    if not inv then return nil end

    local card = inv:AddItem(TC.CARD_ITEM)
    if not card then
        TC.warn("could not create %s -- no card issued", tostring(TC.CARD_ITEM))
        return nil
    end

    local md = card:getModData()
    md.TC_account = acct.number
    md.TC_holder  = acct.holder

    card:setName(getText("IGUI_TC_CardName", acct.holder))
    card:setCustomName(true)
    card:syncItemFields()

    push(acct, "card", 0, acct.balance or 0)
    return card
end
