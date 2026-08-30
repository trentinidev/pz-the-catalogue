--[[ The Catalogue -- the session at a computer.

     The online catalogue is not a sixth window. It is the SAME buy, sell, cart and ledger
     the paper catalogue opens, running against a bank account instead of the notes in your
     pockets, with a different title on the frame. Building a parallel set of windows would
     have meant maintaining two of everything so that one of them could subtract from a
     different number.

     WHY THE STATE LIVES HERE AND NOT ON A WINDOW. The rail closes one window and opens
     another at the same rectangle (TC_UI.lua), the cart is a separate window that outlives
     all of them, and a delivery arrives an hour later with no window open at all. A flag
     carried on the buy window would be lost the first time somebody clicked "Sell". One
     table, keyed by player, that every one of them asks.

     IT IS A SESSION AND NOT A SETTING. It begins when the player uses the disc at a
     computer and ends when they close the catalogue or walk away from the machine. Nothing
     about it is written to modData: a save reloaded is a player standing in a room, not a
     player halfway through a shopping trip.

     THE ORDERS IT PLACES DO OUTLIVE IT, which is the one thing that has to be persisted --
     see TC_Orders. An order remembers the account it was paid from so that a refund three
     days later goes back where the money came from, and that lives on the order, not here.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ playerNum -> { account = "1234 ...", computer = IsoObject }

     The computer is kept so the windows can tell whether the player is still sitting at
     it. It is an object reference rather than a square, because unlike an ATM a desktop
     computer is not something the player is going to walk to a second one of mid-session. ]]
local sessions = {}

--[[ Begin. Returns false when the account cannot be reached, which is the caller's cue to
     say so rather than to open a catalogue that cannot buy anything. ]]
function TC.startOnline(playerNum, account, computer)
    local player = getSpecificPlayer(playerNum)
    if not player or not account then return false end
    if not TC.account(player, account) then return false end

    sessions[playerNum] = { account = account, computer = computer }
    return true
end

function TC.endOnline(playerNum)
    sessions[playerNum] = nil
end

--[[ End the session only once the last catalogue window has gone.

     THE RAIL IS WHY THIS IS NOT JUST `endOnline` IN A close(). Clicking Sell closes the
     buy window and opens the sell window at the same rectangle (TC_UI.lua) -- a pane swap
     that happens to be a close. Ending the session there would drop the player back onto
     their pocket money midway through a shopping trip, and they would find out from the
     figure changing under them.

     So every railed window calls this on the way out and it asks whether any of the others
     are still up. Called from close(), which runs BEFORE the instance is cleared, so the
     window doing the asking excludes itself by name.

     Getting it wrong in the other direction is worse than the rail glitch: a session that
     outlived its windows would leave the next PAPER catalogue quietly spending a bank
     balance, which is the worst way this feature could fail -- silently, and with the
     player's money. ]]
function TC.endOnlineIfLast(playerNum, closing)
    -- A pane swap closes this window and opens the next one immediately AFTER, so at this
    -- instant there is genuinely nothing else up and the count would say the session is
    -- over. The rail sets this flag on the window it is about to close; see TC.onRailClick.
    if closing and closing.switchingPane then return false end

    for _, cls in ipairs({ TC_BuyWindow, TC_SellWindow, TC_HistoryWindow }) do
        local win = cls and cls.instances and cls.instances[playerNum]
        if win and win ~= closing then return false end
    end

    TC.endOnline(playerNum)
    return true
end

--[[ The account this player's catalogue is spending from, or nil for notes in a pocket.

     THE ONE FUNCTION EVERYTHING ELSE ASKS. Every window that used to call TC.getBalance
     now calls TC.purseBalance with this, and passing nil is exactly the old behaviour --
     which is why the paper catalogue needed no changes beyond threading the argument
     through. ]]
function TC.onlineAccount(playerNum)
    local s = sessions[playerNum]
    return s and s.account or nil
end

function TC.isOnline(playerNum)
    return sessions[playerNum] ~= nil
end

--[[ Is the player still at the computer they started at?

     False ends the session and closes the windows, the same rule the cash machine plays
     by and for the same reason: this is a PLACE. A catalogue you can carry is the paper
     one, and it is still in your bag.

     A flat box in tiles rather than a true distance, and the z check is what stops
     somebody shopping from the floor above. Answers true when there is no computer on
     record, which is a session started some way this file does not know about. ]]
TC.ONLINE_RANGE_TILES = 2.5

function TC.stillAtComputer(playerNum)
    local s = sessions[playerNum]
    if not s then return false end
    if not s.computer then return true end

    local player = getSpecificPlayer(playerNum)
    if not player then return false end

    local square = s.computer:getSquare()
    if not square then return false end
    if math.floor(player:getZ()) ~= square:getZ() then return false end

    local r = TC.ONLINE_RANGE_TILES
    return math.abs(player:getX() - (square:getX() + 0.5)) <= r
       and math.abs(player:getY() - (square:getY() + 0.5)) <= r
end

--[[ May this player's catalogue window stay open?

     TWO DIFFERENT QUESTIONS WEARING ONE NAME. On paper it is "is the catalogue still in
     your bag" -- the rule since 0.7, and the reason the buy window checks it on a timer.
     Online there is no catalogue in the bag; the thing you are reading is on a screen
     across the room, so the question becomes "are you still at that screen".

     Answering both here is what let TC_BuyWindow and TC_SellWindow keep a single guard,
     rather than each growing a branch that could be updated in one and forgotten in the
     other. ]]
function TC.catalogueStillOpen(player)
    if not player then return false end

    if TC.isOnline(player:getPlayerNum()) then
        return TC.stillAtComputer(player:getPlayerNum())
    end
    return TC.hasCatalogue(player)
end

--[[ The title on the frame, which is the only thing that tells the player at a glance
     which catalogue they are in. One table so four windows cannot disagree about the
     wording.

     EVERY KEY IS WRITTEN OUT IN FULL, and the first draft did not do that -- it glued a
     prefix onto a suffix at runtime, which is shorter and which tools/check.sh cannot see
     through. That check exists because a translation key with no definition renders in
     game as its own raw name, and it is what caught the whole JSON migration; a key
     assembled at runtime is a key it has to take on trust. Concatenation buys two lines
     and gives up the only automatic guard this mod has over its text.

     (It caught the concatenation itself, too: the half-key in the first draft of THIS
     comment was reported as used and undefined, from inside a comment. Better noisy than
     asleep.) ]]
local TITLES = {
    buy    = { paper = "IGUI_TC_BuyTitle",    online = "IGUI_TC_OnlineBuyTitle"    },
    sell   = { paper = "IGUI_TC_SellTitle",   online = "IGUI_TC_OnlineSellTitle"   },
    cart   = { paper = "IGUI_TC_CartTitle",   online = "IGUI_TC_OnlineCartTitle"   },
    ledger = { paper = "IGUI_TC_LedgerTitle", online = "IGUI_TC_OnlineLedgerTitle" },
}

function TC.windowTitle(playerNum, which)
    local pair = TITLES[which]
    if not pair then return "" end

    if TC.isOnline(playerNum) then return getText(pair.online) end
    return getText(pair.paper)
end
