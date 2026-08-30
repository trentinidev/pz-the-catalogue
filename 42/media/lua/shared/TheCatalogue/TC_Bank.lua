--[[ The Catalogue -- the accounts behind the cash machine.

     WHY A BANK AT ALL. The catalogue trades in physical notes, and TC_Money.lua opens
     with the reason: every dollar is its own InventoryItem, so carrying a fortune means
     carrying thousands of Java objects and tens of kilos. MoneyBundle takes the edge off
     it -- a hundred notes in one object at half the weight -- and it is still weight, and
     it is still lost with the bag it was in.

     An account is the other half of that answer. Money in it is a NUMBER, weighing
     nothing and occupying nothing, and the only way in or out is a machine bolted to a
     wall in a town somewhere.

     NOTHING IS CREATED HERE. Every dollar in an account was carried to a machine and put
     in. Deposit takes real items off the player through TC.takeCash and withdrawal hands
     real items back through TC.giveCash, so the total money in a save is exactly what it
     would have been -- the account only changes where it is being kept. There is no
     interest, no overdraft and no fee, because all three would mint or burn money that
     the rest of the mod believes it can count.

     THE CARD IS THE ACCOUNT.
     -----------------------
     This is the rule everything else here follows from, and it REPLACED the opposite
     rule. 0.1.0-beta kept one account per character and treated the card as a mere
     credential: lose it, enter the PIN, and the machine printed another. It was tested
     and it was wrong -- the machine let a player bank while the card sat in a crate on
     the other side of the map, which made the card set dressing.

     So: one account per CARD. The number lives on the plastic, and a card that is not on
     your person is an account you cannot reach, PIN or no PIN. Lose the card and the
     machine will open you a fresh account with a fresh card, and the old one keeps its
     number, its balance and its statement, waiting. Find the card again and the old
     account is simply there again. A character may hold as many as they have cards for,
     and the machine asks which one when there is more than one.

     THE COST OF THIS IS REAL AND IT IS THE POINT. A card that burns with the house it was
     in takes its balance out of reach for good. That is the risk the feature is now about:
     the money is safe from weight and from your own death-drop, and it is exactly as safe
     as one small item you have to keep track of.

     WHERE IT LIVES. On player:getModData(), next to the wishlist and the ledger, for the
     reason written at length in TC_SellWindow.lua: Lua is given no save hook in this game
     beyond OnPlayerDeath, so anything that must survive a quit has to ride on the
     character. The accounts are keyed by number, and the card carries the key.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local ACCOUNTS_KEY = "TheCatalogue_Accounts"

--[[ Where 0.1.0-beta kept its single account.

     One version's worth of saves can have one of these, and there is no reason to make
     anybody lose a balance over a design change. TC.accounts folds it into the new table
     the first time it is asked and clears the old key, so the migration happens once, on
     the first right-click of a cash machine, and never runs again. ]]
local LEGACY_KEY = "TheCatalogue_Account"

--[[ How many statement lines to keep per account.

     modData is written into the save file, so an unbounded statement grows it forever --
     the same reasoning, and the same fix, as the ledger's MAX_ENTRIES. Fifty is about two
     screens of scrolling and costs a couple of kilobytes; the oldest fall off the end. ]]
local MAX_ENTRIES = 50

-- Four digits, because that is what a cash machine asks for. The keypad in TC_ATMWindow
-- reads this rather than assuming it, so the two cannot disagree.
TC.PIN_LENGTH = 4

-- ---------------------------------------------------------------------------
-- The accounts
-- ---------------------------------------------------------------------------

--[[ Every account this character has ever opened, keyed by account number.

     Always a table, so a caller can walk it without checking first. This is also the one
     place the 0.1.0-beta save format is upgraded -- see LEGACY_KEY. ]]
function TC.accounts(player)
    if not player then return {} end

    local md = player:getModData()
    if type(md[ACCOUNTS_KEY]) ~= "table" then md[ACCOUNTS_KEY] = {} end

    local old = md[LEGACY_KEY]
    if type(old) == "table" and old.number then
        md[ACCOUNTS_KEY][old.number] = old
        md[LEGACY_KEY] = nil
        TC.log("migrated the 0.1.0-beta account %s", tostring(old.number))
    end

    return md[ACCOUNTS_KEY]
end

--[[ One account by its number, or nil.

     TWO PLACES ARE SEARCHED and the order is the meaningful part. An account this
     character opened lives on the character; an account that belonged to somebody in Knox
     County before all this lives in the world's own register (TC_WorldCards). Both are
     reached by number, because the number comes off a card and a card does not care whose
     it was -- which is exactly what lets one machine screen deal in either.

     A card belonging to another CHARACTER of yours still answers nil, because their
     accounts are on their save data and this one is not looking there. ]]
function TC.account(player, number)
    if not number then return nil end

    local mine = TC.accounts(player)[number]
    if mine then return mine end

    return TC.worldAccount(number)
end

--[[ Has this character ever opened one? Not the same question as "can they bank right
     now", which is answered by TC.cardsOnPlayer -- an account with its card in a crate
     across the map exists and is unreachable. The welcome screen needs both: one decides
     whether to offer a first account or a replacement, the other whether to offer
     anything at all. ]]
function TC.hasAnyAccount(player)
    for _ in pairs(TC.accounts(player)) do return true end
    return false
end

--[[ Dollars in the account. Zero for a number that names nothing, so a caller that only
     wants to print a figure does not have to check first. ]]
function TC.bankBalance(player, number)
    local acct = TC.account(player, number)
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

     Not cosmetic. It is the KEY: it ties one card to one account, it is what the machine
     reads off the plastic, and it is why a card belonging to somebody else's save does
     nothing here.

     THE LAST FOUR DIGITS ARE THE PART THAT HAS TO BE UNIQUE, because a transfer is
     addressed by tail alone -- four digits typed at a keypad, since sixteen would be an
     errand -- and an address two accounts can answer to is not an address.

     ONE REGISTER FOR THE WHOLE WORLD, and this used to be narrower than that. It rolled
     its own number and checked it against the character's other accounts, which was enough
     while the character's accounts were the only ones in existence. They are not:
     TC_WorldCards gives every card the world spawned an account of its own, and a tail
     those two could both answer to would be an address with two destinations. TC.reserveTail
     is the single place a tail is claimed now, and both openers come through it. ]]
local function newAccountNumber()
    return TC.reserveTail()
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
local function push(acct, kind, amount, balance, other)
    if type(acct.entries) ~= "table" then acct.entries = {} end

    table.insert(acct.entries, 1, {
        kind    = kind,
        amount  = math.floor((amount or 0) + 0.5),
        balance = math.floor((balance or 0) + 0.5),
        when    = TC.gameStamp(),
        -- The tail of the account at the other end, on a transfer. nil on everything else,
        -- which is what the statement reads to decide whether the line names anybody.
        other   = other,
    })

    while #acct.entries > MAX_ENTRIES do
        table.remove(acct.entries)
    end
end

--[[ Open a NEW account and print its card. Always new, never the one already there.

     This is the "lost card" path as much as it is the first-account path, and the two are
     deliberately the same function. A player standing at a machine with no card is not
     recovering anything -- the old account is not gone, it is merely out of reach, and
     handing them a second card to it would put the mod straight back into the model that
     made the card meaningless. What they get is a fresh account at zero.

     Returns nil if the PIN is not four digits, or in the vanishingly unlikely event that
     thirty-two rolls of the account number all collided. The keypad cannot produce a bad
     PIN; checking anyway is what keeps this safe to call from somewhere that is not the
     keypad. ]]
function TC.openAccount(player, pin)
    if not player then return nil end
    if not TC.isValidPin(pin) then return nil end

    local accounts = TC.accounts(player)
    local number   = newAccountNumber()
    if not number then
        TC.warn("could not find a free account number -- no account opened")
        return nil
    end

    --[[ A counter, because the DATE cannot order these and it looked as though it could.

         `opened` is TC.gameStamp, and the game clock it reads has a granularity of one
         hour. Two accounts opened in the same in-game hour carry the same stamp to the
         character, which is not a rare case at all -- losing a card and walking to the
         next machine is minutes of game time. Sorted by stamp, the tie fell through to the
         account NUMBER, which is random, so "oldest first" silently became "in whatever
         order the dice came up".

         Migrated 0.1.0-beta accounts have no seq and sort as 0, which is right: there was
         only ever one of them and it predates anything opened since. ]]
    local seq = 0
    for _, other in pairs(accounts) do
        seq = math.max(seq, other.seq or 0)
    end

    local acct = {
        number  = number,
        holder  = TC.accountHolder(player),
        pin     = pin,
        balance = 0,
        opened  = TC.gameStamp(),
        seq     = seq + 1,
        entries = {},
    }
    accounts[number] = acct

    push(acct, "open", 0, 0)

    --[[ No card, no account. If the plastic could not be created there is nothing to
         reach this balance with ever again, so the account is rolled back rather than
         left as an orphan the player can see in no window and spend from nowhere. ]]
    if not TC.issueCard(player, acct) then
        accounts[number] = nil
        return nil
    end

    return acct
end

function TC.checkPin(player, number, pin)
    local acct = TC.account(player, number)
    if not acct then return false end
    return acct.pin ~= nil and acct.pin == pin
end

--[[ Statement lines, newest first. Always a table, so the list box can be filled from it
     without a nil check on an account that has never moved. ]]
function TC.statement(player, number)
    local acct = TC.account(player, number)
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
function TC.bankDeposit(player, number, amount)
    local acct = TC.account(player, number)
    if not acct then return false, getText("IGUI_TC_BankNoAccount") end

    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return false, getText("IGUI_TC_BankBadAmount") end

    if TC.getBalance(player) < amount then
        return false, getText("IGUI_TC_BankNotEnoughCash")
    end
    if not TC.takeCash(player, amount) then
        return false, getText("IGUI_TC_BankNotEnoughCash")
    end

    acct.balance = TC.bankBalance(player, number) + amount
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
function TC.bankWithdraw(player, number, amount)
    local acct = TC.account(player, number)
    if not acct then return false, getText("IGUI_TC_BankNoAccount") end

    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return false, getText("IGUI_TC_BankBadAmount") end

    local have = TC.bankBalance(player, number)
    if have < amount then
        return false, getText("IGUI_TC_BankNotEnoughFunds")
    end

    acct.balance = have - amount
    push(acct, "withdraw", amount, acct.balance)
    TC.giveCash(player, amount)
    return true
end

--[[ The account whose number ends in these four digits, or nil.

     FOUR DIGITS IS THE WHOLE ADDRESS, because sixteen typed into a keypad is an errand and
     because the tail is what is printed on the card and shown on every screen. It can be
     unambiguous because newAccountNumber refuses to mint a number whose tail is already
     taken -- so the second return value, "more than one matched", is reachable only for
     accounts that predate that rule. It is reported rather than guessed at: silently
     picking one of two accounts to send money to is the worst possible answer. ]]
function TC.accountByTail(player, tail)
    if type(tail) ~= "string" then return nil, false end

    --[[ WHAT MAY BE ADDRESSED, and it is not "everything in the world".

         Your own accounts, whether or not you are carrying the card -- paying into one
         whose card you have lost is the point, and it does not break the access rule since
         the money still needs that card to come out again.

         Plus the accounts of any cards ON you, which is what lets a stranger's card be
         both a source and a destination once you are holding it.

         And nothing else. The world register knows every account in Knox County, and
         letting a transfer address one of them would turn this field into a probe: type
         four digits, see whether the machine recognises them, and learn a stranger's
         account number without ever finding their card. ]]
    local candidates = {}
    for number, acct in pairs(TC.accounts(player)) do
        candidates[number] = acct
    end
    for _, card in ipairs(TC.cardsOnPlayer(player)) do
        candidates[card.account.number] = card.account
    end

    local found, many = nil, false
    for number, acct in pairs(candidates) do
        if TC.cardTail(number) == tail then
            if found then many = true else found = acct end
        end
    end

    if many then return nil, true end
    return found, false
end

--[[ Move money from one account to another, addressed by the destination's last four.

     NO CARD IS NEEDED FOR THE DESTINATION, and that is deliberate rather than an oversight.
     Paying INTO an account you cannot open is exactly what knowing somebody's number lets
     you do in life, and it cannot be used to get around the access rule: the money lands
     somewhere that still needs its own card to be taken out again. The card requirement
     lives on the withdrawing end, where it belongs.

     So this is also the honest answer to "I found the old card, how do I merge it": insert
     the old card, send its balance to the new account's tail, and the old account is left
     empty rather than the old card being made to open the new account.

     Debit then credit, both in the same call and neither able to fail once the checks
     above them have passed -- there is no half-transferred state to unwind, which is the
     same reason the purchase path commits atomically.

     Returns true and the destination account, or false and a translated reason. ]]
function TC.bankTransfer(player, fromNumber, tail, amount)
    local from = TC.account(player, fromNumber)
    if not from then return false, getText("IGUI_TC_BankNoAccount") end

    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return false, getText("IGUI_TC_BankBadAmount") end

    if type(tail) ~= "string" or not string.match(tail, "^%d%d%d%d$") then
        return false, getText("IGUI_TC_BankBadTail")
    end

    local to, ambiguous = TC.accountByTail(player, tail)
    if ambiguous then return false, getText("IGUI_TC_BankTailAmbiguous", tail) end
    if not to        then return false, getText("IGUI_TC_BankNoSuchAccount", tail) end

    if to.number == from.number then
        return false, getText("IGUI_TC_BankSameAccount")
    end

    local have = TC.bankBalance(player, from.number)
    if have < amount then
        return false, getText("IGUI_TC_BankNotEnoughFunds")
    end

    from.balance = have - amount
    to.balance   = TC.bankBalance(player, to.number) + amount

    --[[ Two lines, one on each statement, each naming the OTHER end.

         A transfer read from one side only is a balance that changed for no stated reason,
         and the account it went to is the one thing the reader wants to know. `other` is
         the tail rather than the whole number because the tail is the address the player
         typed and the one they will recognise. ]]
    push(from, "sent",     amount, from.balance, TC.cardTail(to.number))
    push(to,   "received", amount, to.balance,   TC.cardTail(from.number))

    return true, to
end

-- ---------------------------------------------------------------------------
-- The cards
-- ---------------------------------------------------------------------------

--[[ Is this item plastic belonging to SOME account?

     Deliberately not "does it belong to THIS player". The sell window uses it to refuse a
     card, and refusing every bound card -- including one looted off a body -- is the right
     answer there: the catalogue has no way to tell whose it is, and the thing is worth a
     dollar as an object and an entire account as a key. ]]
function TC.isBankCard(item)
    if not item then return false end
    local md = item:getModData()
    return md ~= nil and md.TC_account ~= nil
end

--[[ Insertion sort, because the lists this runs on have two or three entries in them.

     table.sort is Kahlua's quicksort, which 0.12.1-alpha caught blowing the VM stack --
     but that took five thousand entries sharing a key, and the reason to avoid it here is
     smaller and duller: a hand-written insertion sort over a handful of cards is a few
     lines, needs no reasoning about pivots, and cannot surprise anybody later. ]]
local function sortCards(cards)
    for i = 2, #cards do
        local held = cards[i]
        local j = i - 1
        while j >= 1 and cards[j].sortKey > held.sortKey do
            cards[j + 1] = cards[j]
            j = j - 1
        end
        cards[j + 1] = held
    end
end

--[[ Every card ON THE PLAYER that opens an account of theirs, oldest account first.

     THIS IS THE ACCESS RULE, and it is the whole of it. The machine asks this and nothing
     else: a card in a crate, a card on a corpse, a card belonging to a character in
     another save -- none of them appear here, so none of them reach an account.

     getAllTypeRecurse, and both spellings of the type, for the reason TC_Money.lua gives:
     a card lives in a wallet and a wallet lives in a bag, and the game's own Lua is
     inconsistent about whether these lookups want "Base.CreditCard" or "CreditCard".
     Trying both and taking whichever answers is cheaper than being certain.

     Sorted by the counter each account is stamped with when it is opened, so the machine
     offers them in the order they came into the player's life and the list does not
     reshuffle itself every time a bag is repacked. The counter and not the DATE: the game
     clock ticks in hours, and two accounts opened in one hour would fall through to a tie
     broken by a random number. See TC.openAccount.

     Zero-padded into the sort key rather than compared as a number, so one comparison
     orders both halves at once and account 10 does not sort before account 2. ]]
function TC.cardsOnPlayer(player)
    local out = {}
    if not player then return out end

    local seen = {}

    for _, item in ipairs(TC.cardItemsOn(player)) do
        local md   = item:getModData()
        local num  = md and md.TC_account

        -- Through TC.account, not the character's own table, so a card taken off a corpse
        -- resolves against the world register and reaches the machine like any other. It
        -- will be asked for a PIN nobody told the player, which is the feature.
        local acct = num and TC.account(player, num)

        -- Two cards to one account should not exist, and a debug spawn or a duplicated
        -- save can produce one anyway. The first is kept so the machine never offers the
        -- same account twice in the list it asks the player to choose from.
        if acct and not seen[num] then
            seen[num] = true

            -- Bring a card printed by an older version up to the current name. Costs a
            -- string compare per card per scan; see TC.nameCard.
            TC.nameCard(item, acct)

            table.insert(out, {
                item    = item,
                account = acct,
                sortKey = string.format("%08d", acct.seq or 0) .. num,
            })
        end
    end

    sortCards(out)
    return out
end

--[[ Is this exact account still reachable -- that is, is its card still on the player?

     Asked while the window is open, because a session that began with the card in hand
     has to end if the card stops being in hand. Answering it by number rather than by
     holding on to the item is deliberate: an item reference survives the item being moved
     into a bag, consolidated, or dropped, and would keep saying yes. ]]
function TC.holdsCardFor(player, number)
    if not number then return false end
    for _, card in ipairs(TC.cardsOnPlayer(player)) do
        if card.account.number == number then return true end
    end
    return false
end

--[[ Print the card for an account and bind it.

     VANILLA'S OWN ITEM, not one of ours. Base.CreditCard already exists, already has an
     icon and a world model, and already carries base:fitswallet so it goes where a card
     should go. A Catalogue.CreditCard would have meant shipping art to draw the same
     rectangle of plastic, and it would have made every card the world spawns visibly
     not-a-card beside ours.

     What makes it OURS is the modData and the name. setCustomName is the flag that stops
     the game re-deriving the display name from the script -- the step that is easy to
     leave out and that makes the rename look like it silently failed -- and syncItemFields
     is what vanilla's own rename does afterwards so that open inventory panes redraw.

     The last four digits go on the name as well as the holder. With two cards in a bag,
     "Credit Card - Bob Smith" twice over is not a label, it is a coin toss. ]]
function TC.issueCard(player, acct)
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

    TC.nameCard(card, acct)

    push(acct, "card", 0, acct.balance or 0)
    return card
end

--[[ Write the account's name onto the plastic, and DO IT AGAIN whenever the card is seen.

     Not only at issue, which is where it used to happen and where it was not enough. Cards
     printed by 0.1.0-beta read "Credit Card - Bob Smith" with no digits on them, because
     the tail was not part of the name yet; they went on working -- the account is matched
     by modData, never by the label -- but two of them in a bag were indistinguishable, and
     the one thing a card has to do outside the machine is tell you which card it is.
     Renaming them the first time the machine looks at them is a migration, and it belongs
     next to the modData one at the top of this file.

     THE COMPARISON IS NOT AN OPTIMISATION, it is the whole safety of doing this on a scan
     that runs several times a second while the chooser is open. setName, setCustomName and
     syncItemFields on every card on every pass would be real work for no change; the string
     compare in front of them means the ordinary case costs nothing and the rename happens
     exactly once per card, ever. ]]
function TC.nameCard(card, acct)
    if not card or not acct then return false end

    local want = getText("IGUI_TC_CardName", acct.holder or "?", TC.cardTail(acct.number))
    if card:getName() == want then return false end

    card:setName(want)
    -- The flag that stops the game re-deriving the display name from the item script --
    -- the step that is easy to leave out and that makes a rename look like it silently
    -- failed. syncItemFields is what vanilla's own rename does afterwards, so that an
    -- inventory pane which is already open redraws.
    card:setCustomName(true)
    card:syncItemFields()
    return true
end

--[[ The last four digits, which is how a card is told from another card everywhere but on
     the account screen itself. Falls back to the whole string rather than to nothing if it
     is ever handed something that is not a sixteen-digit number. ]]
function TC.cardTail(number)
    if type(number) ~= "string" then return "????" end
    if #number < 4 then return number end
    return string.sub(number, #number - 3)
end
