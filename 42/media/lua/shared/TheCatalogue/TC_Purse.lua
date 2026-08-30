--[[ The Catalogue -- where the money for a transaction comes from and goes to.

     There are two now. The catalogue in your hands is paid in notes out of your pockets;
     the catalogue on a screen is paid out of a bank account, and never touches a note. Six
     files used to call TC.getBalance and TC.takeCash directly, which was fine while there
     was only one answer to "what is the money".

     THE ACCOUNT NUMBER IS THE WHOLE INTERFACE. Every function here takes one, and nil
     means cash. That is deliberately the SAME shape as everything else in the bank -- an
     account is addressed by its number, and nil is the absence of one -- so nothing had to
     learn a new vocabulary. A caller that knows nothing about the online catalogue passes
     nil and gets exactly the behaviour it had before.

     WHY NOT AN OBJECT WITH METHODS. Because it would have to be constructed somewhere and
     then carried, and the things that need it are a timed action, a delivery that arrives
     an hour later, and a refund for an order the player has since forgotten about. A
     number survives being written to modData and read back; a table with functions in it
     does not. TC_Orders stores the account on the order for exactly that reason.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ What is available to spend, from cash or from an account.

     An account number that names nothing answers 0 rather than falling back to cash. A
     silent fallback is how an online order would quietly empty a player's pockets after
     their card left their bag mid-session, and 0 makes the window say "insufficient
     funds", which is both true and recoverable. ]]
function TC.purseBalance(player, account)
    if not account then return TC.getBalance(player) end
    return TC.bankBalance(player, account)
end

--[[ Take `amount`. True on success; false and NOTHING TOUCHED on failure.

     Both halves keep that promise and both were already written to. TC.takeCash walks the
     inventory, breaks a bundle and makes change, and leaves everything alone when the
     player is short; TC.bankWithdraw checks the balance before it debits. The purchase
     path checks affordability and commits in the same breath and has to be able to trust
     this. ]]
function TC.purseTake(player, account, amount)
    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return true end

    if not account then return TC.takeCash(player, amount) end

    local acct = TC.account(player, account)
    if not acct then return false end

    local have = TC.bankBalance(player, account)
    if have < amount then return false end

    acct.balance = have - amount
    TC.pushEntry(acct, "spent", amount, acct.balance)
    return true
end

--[[ Give `amount` back -- a payout, a refund, a cancelled order.

     A refund to an account that has since gone out of reach falls back to CASH, and that
     is the one place a fallback is right. The alternative is money that vanishes because
     the player lost a card between ordering and cancelling, and a mod that eats a refund
     is worse than one that hands it over in notes. ]]
function TC.purseGive(player, account, amount)
    amount = math.floor((amount or 0) + 0.5)
    if amount <= 0 then return end

    if account then
        local acct = TC.account(player, account)
        if acct then
            acct.balance = TC.bankBalance(player, account) + amount
            TC.pushEntry(acct, "refund", amount, acct.balance)
            return
        end
        TC.warn("account %s is gone -- refunding $%d in cash", tostring(account), amount)
    end

    TC.giveCash(player, amount)
end

--[[ What to call the figure on screen: your pockets, or the account it is coming out of.
     The buy window prints this beside the number, and it is the only thing that tells a
     player at a glance which catalogue they are looking at. ]]
function TC.purseLabel(account)
    if account then return getText("IGUI_TC_BankBalance") end
    return getText("IGUI_TC_YourCash")
end
