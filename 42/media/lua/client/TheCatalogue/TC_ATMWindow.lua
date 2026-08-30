--[[ The Catalogue -- the cash machine.

     ONE WINDOW, FIVE SCREENS, because that is what the machine in the wall is. A real
     ATM does not open five windows; it swaps what is on the one screen it has, and every
     step is answered before the next one appears. So this is a single ISCollapsableWindow
     with a `screen` field, all of its widgets built once in createChildren and shown or
     hidden by applyScreen.

         welcome   no card on the player: what an account is, or -- if they have accounts
                   and no card to any of them -- what has become of the old one, and the
                   button that opens a new one either way
         choose    more than one card on the player: which of them are we talking about
         pin       the keypad -- entering a PIN, choosing one, confirming a new one
         account   the balance, the statement, and the two things you can do
         amount    how much, in quick steps or typed, for a deposit or a withdrawal

     THE CARD IS THE ACCOUNT, and everything on this screen follows from it. openingScreen
     asks TC.cardsOnPlayer and nothing else: no card on the person means no account is
     reachable, whatever the save data says and whatever PIN can be typed. 0.1.0-beta got
     this wrong -- it kept one account per character, treated the card as a credential, and
     happily let a player bank while the card sat in a crate on the other side of the map.
     TC_Bank.lua's header has the full version of the rule and what it costs.

     WHY NOT ON THE RAIL. Buy, Sell and Ledger are three faces of one catalogue and the
     rail down their right edge is what makes that true (see TC_UI.lua). The cash machine
     is not a fourth face of it: it is a PLACE. You have to walk to it, it is bolted to a
     wall in a town, and the whole point of the feature is that the money in it is
     somewhere you are not. A rail entry would say the opposite -- that the account is
     another page of a book in your bag -- and it would need a rail on a window that is
     opened by right-clicking a tile rather than by holding a catalogue.

     THE PIN IS ASKED FOR EVERY VISIT. It would have been friendlier to ask once and
     remember, and it would have made the PIN a formality typed at account opening and
     never again. Three wrong tries ends the session and the player walks back; the card
     is not eaten, because a mod that permanently destroys the way into your own savings
     over a typo is a mod that gets uninstalled. The PIN proves you may use the card you
     are holding -- it proves nothing about a card you are not.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ Every one of these is a FILE LOCAL and has to be, which is the whole reason
     tools/check.sh grew its `consts` rule: a shared file that names one of them gets a
     nil global instead, and `nil + 10` is a crash that parses perfectly. See TC_UI.lua,
     where the rail computes its own heights lazily for exactly this reason. ]]
local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local HEADER_HGT = FONT_HGT_SMALL + 12
local ROW_HGT    = TC.UI.ROW_HGT
local LINE_GAP   = 10
local KEY_GAP    = 8

-- Equal margins inside the statement table, the arrival window's trick: the right-hand
-- one has to clear the scrollbar, so the left one matches it rather than leaving the
-- columns looking shifted inside their own frame.
local INSET = TC.UI.SCROLL_GUTTER

--[[ The quick amounts, and the order they are offered in.

     Doubling steps rather than round tens, because the question a player is answering is
     "roughly how much", and 1 / 5 / 10 / 20 / 50 / 100 is how the notes in a wallet are
     actually grouped. A hundred is the last one because that is a MoneyBundle -- past it,
     "all" is nearly always what is meant, and the typed field is there for the rest. ]]
local QUICK = { 1, 5, 10, 20, 50, 100 }

-- The five screens, named once so a typo is a nil rather than a silently dead branch.
local WELCOME = "welcome"
local CHOOSE  = "choose"
local PIN     = "pin"
local ACCOUNT = "account"
local AMOUNT  = "amount"


--[[ How much room the status line gets, in lines and in the gap between them.

     Two, because that is what the longest thing the machine says needs at the width the
     window opens at, and because a THIRD line would start eating the screen above it for a
     message that clears itself after six seconds. Anything longer than two lines is a
     message that should have been written shorter. ]]
local MSG_LINES   = 2
local MSG_LEADING = 3

--[[ How often the window re-checks that the player is still standing at the machine, and
     how far they may drift before it closes.

     Measured in milliseconds and tiles. Every frame would be wasteful for a question
     whose answer changes at walking pace, and the buy window already checks whether the
     catalogue is still in the bag on the same kind of timer. ]]
local RANGE_CHECK_MS = 400
local RANGE_TILES    = 2.5

-- ---------------------------------------------------------------------------
-- The statement table
-- ---------------------------------------------------------------------------

--[[ Column widths, measured once on first use rather than written as pixel numbers.

     Every fixed offset in this mod has eventually collided with a larger UI scale -- the
     cart's header stacked "QuantiUnit price" on itself, the buy window's detail panel drew
     a fullType through its own separator -- so a column here is as wide as the WIDER of
     its own heading and the widest value it can hold, and never narrower.

     Worked out on first use and not at load, because these are translated strings and
     nothing guarantees the translations are ready while this file is being read. ]]
local stmtW
local function statementWidths()
    if stmtW then return stmtW end

    local tm = getTextManager()
    local F  = UIFont.Small

    local function width(key, sample)
        return math.max(tm:MeasureStringX(F, getText(key)),
                        tm:MeasureStringX(F, sample)) + TC.UI.CELL_PAD * 2
    end

    stmtW = {
        when    = width("IGUI_TC_LedgerWhen",    "1993-07-09 13:00"),
        amount  = width("IGUI_TC_LedgerAmount",  "-$999999"),
        balance = width("IGUI_TC_BankColBalance", "$9999999"),
    }
    return stmtW
end

--[[ The four bands, given the list's pixel width. One definition used by the header and
     by every row, so a heading cannot drift off the values under it.

     Counted from the RIGHT edge inwards for the two money columns, the same shape as
     TC.columns: the figures are what the eye runs down, so they get fixed widths pinned
     right, and the elastic middle column absorbs a resize. ]]
local function statementColumns(listW)
    local W = statementWidths()

    local rightEdge = listW - INSET
    local balLeft   = rightEdge - W.balance
    local amtLeft   = balLeft - W.amount
    local whenLeft  = INSET
    local whatLeft  = whenLeft + W.when

    return {
        whenLeft = whenLeft,
        whenW    = W.when - TC.UI.CELL_PAD,

        whatLeft = whatLeft,
        whatW    = math.max(20, amtLeft - whatLeft - TC.UI.CELL_PAD),

        amtLeft   = amtLeft,
        amtRight  = balLeft,
        balLeft   = balLeft,
        balRight  = rightEdge,

        rules = { whatLeft - math.floor(TC.UI.CELL_PAD / 2), amtLeft, balLeft },
    }
end

--[[ What a statement line is called, and what colour it reads in.

     Money in is green and money out is red, which is the only colour convention this mod
     already uses (the buy window turns "Cash after" red the moment an order costs more
     than the player is carrying). The two lines that move no money -- opening the account
     and printing a card -- are grey and show a dash rather than $0, because a zero in a
     money column invites the reader to add it up. ]]
local KINDS = {
    open     = { key = "IGUI_TC_BankKindOpen",     sign = nil, r = 0.62, g = 0.62, b = 0.66 },
    card     = { key = "IGUI_TC_BankKindCard",     sign = nil, r = 0.62, g = 0.62, b = 0.66 },
    deposit  = { key = "IGUI_TC_BankKindDeposit",  sign = "+", r = 0.66, g = 0.94, b = 0.66 },
    withdraw = { key = "IGUI_TC_BankKindWithdraw", sign = "-", r = 0.96, g = 0.66, b = 0.62 },

    --[[ The two halves of a transfer, and they NAME THE OTHER END.

         `other` says the line's label takes the far account's last four as an argument:
         "Sent to 8415", not "Sent". A transfer read from one side without it is a balance
         that changed for no stated reason, and where it went is the one thing the reader
         of a statement wants to know. ]]
    sent     = { key = "IGUI_TC_BankKindSent",     sign = "-", r = 0.96, g = 0.66, b = 0.62, other = true },
    received = { key = "IGUI_TC_BankKindReceived", sign = "+", r = 0.66, g = 0.94, b = 0.66, other = true },
}

TC_StatementList = ISScrollingListBox:derive("TC_StatementList")

function TC_StatementList:doDrawItem(y, item, alt)
    local line = item.item
    local w = self:getWidth()
    local c = statementColumns(w)
    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2
    local F = UIFont.Small

    -- The same grid as the catalogue and the ledger: a rail under each row and a rule
    -- between each column, so a record reads across and a column reads down.
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)
    for _, x in ipairs(c.rules) do
        self:drawRect(x, y, 1, ROW_HGT - 1, 0.22, 1, 1, 1)
    end

    local kind = KINDS[line.kind] or KINDS.open

    self:drawText(TC.truncate(F, line.when or "?", c.whenW),
                  c.whenLeft, ty, 0.62, 0.62, 0.66, 1, F)
    -- A transfer line names the account at the other end; everything else is a bare label.
    local what = getText(kind.key)
    if kind.other then what = getText(kind.key, line.other or "?") end

    self:drawText(TC.truncate(F, what, c.whatW),
                  c.whatLeft, ty, 0.92, 0.92, 0.95, 1, F)

    local amountText = getText("IGUI_TC_BankNoMovement")
    if kind.sign then amountText = kind.sign .. "$" .. tostring(line.amount or 0) end
    TC.drawRight(self, amountText, c.amtRight, ty, F, kind.r, kind.g, kind.b)

    TC.drawRight(self, "$" .. tostring(line.balance or 0), c.balRight, ty,
                 F, 0.82, 0.82, 0.86)

    return y + ROW_HGT
end

-- ---------------------------------------------------------------------------
-- The card chooser
-- ---------------------------------------------------------------------------

--[[ The cards on the player, one to a row, for the screen that asks which one.

     NO BALANCES ON THIS LIST. It is drawn before a PIN has been entered, and a machine
     that shows you what is in an account before it has established you may look is not a
     machine, it is a display case. The number and the date it was opened are enough to
     tell one card from another, which is the only question this screen asks. ]]
TC_CardList = ISScrollingListBox:derive("TC_CardList")

--[[ Where the rule between the two columns sits.

     The date is a fixed-width string, so the column it lives in is measured off it -- and
     off its own heading, which may be wider in some language -- and the account numbers
     take everything left over. One definition, used by the row and by the header strip the
     window draws above the list, so a heading cannot drift off the values under it. ]]
local function cardRule(listW)
    local tm = getTextManager()
    local w  = math.max(tm:MeasureStringX(UIFont.Small, "1993-07-09 13:00"),
                        tm:MeasureStringX(UIFont.Small, getText("IGUI_TC_BankColOpened")))
    return listW - INSET - w - TC.UI.CELL_PAD
end

function TC_CardList:doDrawItem(y, item, alt)
    local card = item.item
    local w    = self:getWidth()
    local F    = UIFont.Small

    if self.selected == item.index then
        self:drawRect(0, y, w, ROW_HGT - 1, 0.55, 0.24, 0.34, 0.45)
    end
    self:drawRect(0, y + ROW_HGT - 1, w, 1, 0.25, 1, 1, 1)

    local ruleX = cardRule(w)
    self:drawRect(ruleX, y, 1, ROW_HGT - 1, 0.22, 1, 1, 1)

    local ty = y + (ROW_HGT - FONT_HGT_SMALL) / 2

    self:drawText(TC.truncate(F, card.account.number or "?", ruleX - INSET - TC.UI.CELL_PAD),
                  INSET, ty, 0.92, 0.92, 0.95, 1, F)
    TC.drawRight(self, tostring(card.account.opened or "?"), w - INSET, ty,
                 F, 0.62, 0.62, 0.66)

    return y + ROW_HGT
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

TC_ATMWindow = ISCollapsableWindow:derive("TC_ATMWindow")
TC_ATMWindow.instances = TC_ATMWindow.instances or {}

--[[ The keypad's key size, measured off its widest label.

     Clear and Enter are words and the digits are single characters, so the words decide
     the size and every key is square-ish and identical -- an ATM keypad with one wide key
     in it does not read as a keypad. Lazily, and cached, because it reads translations. ]]
local keySize
local function keyWidth()
    if not keySize then
        local tm = getTextManager()
        keySize = math.max(52,
                           tm:MeasureStringX(UIFont.Medium, getText("IGUI_TC_PinKeyClear")),
                           tm:MeasureStringX(UIFont.Medium, getText("IGUI_TC_PinKeyEnter")))
                  + TC.UI.BTN_PAD
    end
    return keySize
end

local function keypadWidth()
    return keyWidth() * 3 + KEY_GAP * 2
end

--[[ The welcome screen's body text, and there are two of them.

     PITCH is the first-account version: what an account is, for somebody who has never
     had one. LOST is what the same screen says to somebody who HAS accounts and is
     standing there without the card to any of them -- a different situation that wants
     different words, because the thing they most need told is that the old balance has
     not gone anywhere. ]]
local PITCH = { "IGUI_TC_ATMPitch1", "IGUI_TC_ATMPitch2",
                "IGUI_TC_ATMPitch3", "IGUI_TC_ATMPitch4" }

local LOST  = { "IGUI_TC_ATMLost1", "IGUI_TC_ATMLost2", "IGUI_TC_ATMLost3" }

--[[ The narrowest this window may be dragged: whatever the widest thing on any of the
     five screens actually needs.

     Every screen is measured, not just the one that happens to be open, because a resize
     made on the account screen has to survive switching to the keypad. Four button rows,
     the keypad grid and the longest line of welcome text, and the largest of them wins. ]]
local function minimumWidth()
    local quick = {}
    for i, n in ipairs(QUICK) do quick[i] = "$" .. n end
    table.insert(quick, getText("IGUI_TC_BankAll"))

    --[[ Prose no longer sets the minimum width, because prose WRAPS now.

         It used to: the window could not be dragged narrower than the longest line of
         welcome text, and that line still came out truncated at the size the window opens
         at, so the constraint bought nothing. What is kept is half of it -- enough that
         four sentences wrap to about eight lines rather than to one word each, which is
         where a narrow column stops being readable. ]]
    local tm = getTextManager()
    local pitch = 0
    for _, key in ipairs(PITCH) do
        pitch = math.max(pitch, tm:MeasureStringX(UIFont.Small, getText(key)))
    end

    local widest = math.max(
        keypadWidth(),
        pitch / 2,
        TC.buttonRowWidth({ getText("IGUI_TC_BankDeposit"),
                            getText("IGUI_TC_BankWithdraw"),
                            getText("IGUI_TC_BankTransfer"),
                            getText("IGUI_TC_BankDone") }, UIFont.Medium),
        TC.buttonRowWidth(quick, UIFont.Medium),
        TC.buttonRowWidth({ getText("IGUI_TC_BankConfirm"),
                            getText("IGUI_TC_BankBack") }, UIFont.Medium),
        TC.buttonRowWidth({ getText("IGUI_TC_BankOpenAccount"),
                            getText("IGUI_TC_BankCancel") }, UIFont.Medium),
        -- The welcome screen's other face: its button says "Lost card - open a new one",
        -- which is the longest label the mod has.
        TC.buttonRowWidth({ getText("IGUI_TC_BankLostCard"),
                            getText("IGUI_TC_BankCancel") }, UIFont.Medium),
        TC.buttonRowWidth({ getText("IGUI_TC_BankInsertCard"),
                            getText("IGUI_TC_BankCancel") }, UIFont.Medium)
    )

    return math.ceil(widest) + PAD * 2
end

--[[ And the shortest it may be dragged, which is whatever the KEYPAD screen needs -- the
     tallest of the five, and the only one with nothing elastic on it to give up.

     Counted as the real stack: headline, prompt, the row of PIN boxes, four rows of keys,
     the status line, and the button row at the bottom. The title bar cannot be asked
     about from here -- titleBarHeight is a method on a window that does not exist yet at
     the moment :new needs this number -- so it is allowed for at the same font height the
     bar is drawn from. ]]
local function minimumHeight()
    local titleBar = FONT_HGT_MEDIUM + PAD

    return titleBar
           + PAD + FONT_HGT_LARGE                       -- headline
           --[[ Two lines for what is known about the card, held whether or not there is
                anything to say. Without them in the count, a window dragged to its minimum
                had exactly enough room for the prompt and the boxes, and the card-knowledge
                line went in on top of the headline. ]]
           + PAD + FONT_HGT_SMALL * 2 + MSG_LEADING     -- "pressed into the plastic: ..."
           + PAD + FONT_HGT_SMALL                       -- keypad prompt
           + PAD + FONT_HGT_MEDIUM + 12                 -- the PIN boxes
           + PAD + BUTTON_HGT * 4 + KEY_GAP * 3         -- the keys
           + PAD + FONT_HGT_SMALL * MSG_LINES
                 + MSG_LEADING * (MSG_LINES - 1)        -- the status block
           + PAD + BUTTON_HGT + BOTTOM_PAD              -- the button row
end

function TC_ATMWindow:new(x, y, w, h, playerNum, atm)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.playerNum = playerNum
    o.player    = getSpecificPlayer(playerNum)
    o.atm       = atm

    o.pinMode    = "enter"          -- enter | new | confirm
    o.pinBuffer  = ""
    o.pinFirst   = ""
    o.amountMode = "deposit"
    o.amount     = 0

    --[[ WHICH ACCOUNT THIS SESSION IS ABOUT, set the moment a card is chosen and nil until
         then. Everything downstream -- the balance, the statement, the deposit, the
         withdrawal -- is addressed by this number rather than by "the player's account",
         because a player may hold several cards and the machine has to be talking about
         exactly one of them. ]]
    o.accountNumber = nil

    o.screen = o:openingScreen()

    o:setResizable(true)
    o.minimumWidth  = minimumWidth()
    o.minimumHeight = minimumHeight()
    return o
end

--[[ Which screen the machine wakes up on, decided by WHAT IS IN THE PLAYER'S POCKETS.

     This is the access rule and it is deliberately the first thing that happens. No card
     on the person means no account is reachable, whatever the character's save data says
     and whatever PIN they can type -- 0.1.0-beta got this wrong, let a player bank with
     the card in a crate across the map, and made the card set dressing.

         no cards    the welcome screen, which offers to open one. It says different words
                     depending on whether this is a first account or a lost card, but the
                     button does the same thing either way: a NEW account, at zero.
         one card    straight to its PIN. Asking "which card?" of somebody holding one is
                     a question with one answer and a click to give it.
         several     the chooser, because the machine cannot know which one they meant. ]]
function TC_ATMWindow:openingScreen()
    local cards = TC.cardsOnPlayer(self.player)

    if #cards == 0 then return WELCOME end

    if #cards == 1 then
        self.accountNumber = cards[1].account.number
        return self:afterCard()
    end

    return CHOOSE
end

--[[ Where a card goes once it has been inserted: the keypad, or straight past it.

     A machine whose reader has been wired (TC_ATMTamper) has stopped asking, so it would
     be a lie to draw a PIN screen and then accept anything. Skipping it is also the only
     way the player SEES that the wiring worked.

     The tries counter is cleared on the way through. Getting in is getting in, however you
     did it, and leaving a card two wrong guesses from a lockout after you have opened it
     would be a state nobody could explain. ]]
function TC_ATMWindow:afterCard()
    if TC.atmBypassed(self.atm) then
        TC.clearPinTries(TC.account(self.player, self.accountNumber))
        return ACCOUNT
    end
    return PIN
end

--[[ The vertical stack every screen shares, walked down in one place.

     Headline at the top, a row of buttons pinned to the bottom, a status line above them,
     and whatever is left over in the middle is the body. Written as one walk so the
     blocks cannot drift apart the way two copies of the arithmetic would -- the mistake
     the arrival window's layout() exists to prevent. ]]
function TC_ATMWindow:layout()
    local L = {}
    L.x         = PAD
    L.w         = self.width - PAD * 2
    L.headlineY = self:titleBarHeight() + PAD
    L.bodyY     = L.headlineY + FONT_HGT_LARGE + PAD
    L.buttonY   = self.height - BOTTOM_PAD - BUTTON_HGT

    --[[ TWO lines of room for the status message, reserved whether or not there is one.

         "Card not found - a replacement has been printed" does not fit on one line at the
         size this window opens at, and a message that is allowed to grow downwards grows
         into the button row. Reserved rather than measured per message, so the body above
         does not jump half a line taller every time a message ages out. ]]
    L.msgH  = FONT_HGT_SMALL * MSG_LINES + MSG_LEADING * (MSG_LINES - 1)
    L.msgY  = L.buttonY - PAD - L.msgH
    L.bodyH = math.max(0, L.msgY - PAD - L.bodyY)
    return L
end

--[[ The keypad screen, laid out in ONE place from the bottom up.

     THE KEYS AND THE BOXES USED TO BE WORKED OUT SEPARATELY, and they collided. The keypad
     was anchored to the bottom of the body; the prompt and the row of PIN boxes flowed
     down from the top. On a short window -- or once a line was added saying what is known
     about the card -- the two met in the middle and the boxes were drawn underneath the
     digits. Two independent pieces of arithmetic about one screen is the same mistake the
     arrival window's layout() exists to prevent, and it went in anyway.

     So everything is measured back from the keys. The keypad sits at the bottom of the
     body, the boxes a padding above it, the prompt above those, and the "what you know"
     line above that when there is one. Whatever slack a taller window has ends up as empty
     space at the TOP, which is where nothing is competing for it.

     `knownLines` is how many lines of card knowledge are being shown, which the caller
     knows and this does not. ]]
function TC_ATMWindow:pinGeometry(knownLines)
    local L = self:layout()
    knownLines = knownLines or 0

    local G = {}
    G.L      = L
    G.boxH   = FONT_HGT_MEDIUM + 12
    G.boxW   = math.floor(G.boxH * 0.85)
    G.keysH  = BUTTON_HGT * 4 + KEY_GAP * 3

    G.keyY   = L.bodyY + L.bodyH - G.keysH
    G.boxY   = G.keyY - PAD - G.boxH
    G.promptY = G.boxY - PAD - FONT_HGT_SMALL
    G.knownY  = G.promptY - MSG_LEADING
                          - knownLines * FONT_HGT_SMALL
                          - math.max(0, knownLines - 1) * MSG_LEADING

    return G
end

--[[ How tall the account screen's summary panel is: two label rows, a rule, the balance
     in Large, and the cash-on-hand row under it. Measured off the fonts rather than
     guessed, so the panel grows with the UI scale instead of clipping. ]]
local function summaryHeight()
    return PAD * 2 + FONT_HGT_SMALL * 3 + FONT_HGT_LARGE + LINE_GAP * 4
end

--[[ Where the quick-amount row, the typed field and the panel sit on the amount screen.
     One function, called by both the layout pass and prerender, for the same reason. ]]
function TC_ATMWindow:amountGeometry()
    local L = self:layout()
    local panelH = PAD * 2 + FONT_HGT_SMALL * 2 + LINE_GAP * 2 + FONT_HGT_LARGE

    return {
        panelY  = L.bodyY,
        panelH  = panelH,
        quickY  = L.bodyY + panelH + PAD * 2,
        entryY  = L.bodyY + panelH + PAD * 2 + BUTTON_HGT + PAD * 2,
        L       = L,
    }
end

-- ---------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------

function TC_ATMWindow:mkButton(text, handler, internal)
    local b = ISButton:new(0, 0, 10, BUTTON_HGT, text, self, handler)
    b.internal = internal
    b:initialise(); b:instantiate()
    self:addChild(b)
    return b
end

function TC_ATMWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    -- welcome
    self.openBtn   = self:mkButton(getText("IGUI_TC_BankOpenAccount"), TC_ATMWindow.onOpenAccount)
    self.leaveBtn  = self:mkButton(getText("IGUI_TC_BankCancel"),      TC_ATMWindow.onDone)

    --[[ The keypad, built as twelve real buttons in reading order.

         Digits carry their own character as `internal` and the two words carry a name, so
         onKeypad reads one field rather than switching on a label that a translation would
         change underneath it. ]]
    self.keys = {}
    local labels = { "1", "2", "3", "4", "5", "6", "7", "8", "9",
                     getText("IGUI_TC_PinKeyClear"), "0", getText("IGUI_TC_PinKeyEnter") }
    local codes  = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "CLEAR", "0", "ENTER" }

    for i = 1, 12 do
        self.keys[i] = self:mkButton(labels[i], TC_ATMWindow.onKeypad, codes[i])
    end
    self.pinCancelBtn = self:mkButton(getText("IGUI_TC_BankCancel"), TC_ATMWindow.onDone)

    -- choose
    self.cardList = TC_CardList:new(PAD, 0, self.width - PAD * 2, 10)
    self.cardList:initialise(); self.cardList:instantiate()
    self.cardList.itemheight = ROW_HGT
    self.cardList.drawBorder = true
    self.cardList.target = self
    --[[ Double-clicking a row inserts it, because that is what a list of things you pick
         one of is expected to do and it is the first thing anybody tries. The button stays:
         it is the discoverable half, and it is the half a controller can reach.

         ISScrollingListBox sets `selected` on the mouse-down that precedes the double
         click, so by the time this fires onInsertCard already has the right row and the
         handler needs no argument of its own. ]]
    self.cardList.onmousedblclick = TC_ATMWindow.onCardDoubleClick
    self:addChild(self.cardList)

    self.insertBtn      = self:mkButton(getText("IGUI_TC_BankInsertCard"), TC_ATMWindow.onInsertCard)
    self.chooseCancelBtn = self:mkButton(getText("IGUI_TC_BankCancel"),    TC_ATMWindow.onDone)

    -- account
    self.list = TC_StatementList:new(PAD, 0, self.width - PAD * 2, 10)
    self.list:initialise(); self.list:instantiate()
    self.list.itemheight = ROW_HGT
    self.list.drawBorder = true
    self.list.target = self
    self:addChild(self.list)

    self.depositBtn  = self:mkButton(getText("IGUI_TC_BankDeposit"),  TC_ATMWindow.onDeposit)
    self.withdrawBtn = self:mkButton(getText("IGUI_TC_BankWithdraw"), TC_ATMWindow.onWithdraw)
    self.transferBtn = self:mkButton(getText("IGUI_TC_BankTransfer"), TC_ATMWindow.onTransfer)
    self.doneBtn     = self:mkButton(getText("IGUI_TC_BankDone"),     TC_ATMWindow.onDone)

    -- amount
    self.quickBtns = {}
    for i, n in ipairs(QUICK) do
        self.quickBtns[i] = self:mkButton("$" .. n, TC_ATMWindow.onQuick, tostring(n))
    end
    self.quickBtns[#QUICK + 1] = self:mkButton(getText("IGUI_TC_BankAll"),
                                               TC_ATMWindow.onQuick, "ALL")

    self.customEntry = ISTextEntryBox:new("0", PAD, 0, 120, BUTTON_HGT)
    self.customEntry:initialise(); self.customEntry:instantiate()
    self.customEntry:setOnlyNumbers(true)
    -- Seven digits is $9,999,999, which is more money than a save will ever hold and
    -- still short enough that the figure cannot outgrow the panel it is drawn in.
    self.customEntry:setMaxTextLength(7)
    self.customEntry.onTextChange = function() self:onAmountTyped() end
    self:addChild(self.customEntry)

    self.confirmBtn = self:mkButton(getText("IGUI_TC_BankConfirm"), TC_ATMWindow.onConfirmAmount)
    self.backBtn    = self:mkButton(getText("IGUI_TC_BankBack"),    TC_ATMWindow.onBack)

    self:refreshForScreen()
    self:applyScreen()
end

-- ---------------------------------------------------------------------------
-- Screens
-- ---------------------------------------------------------------------------

--[[ Fill whatever the screen we are on reads from.

     CALLED FROM BOTH PLACES A SCREEN CAN BE SET, and that is the whole reason it exists as
     a function rather than as two lines inside setScreen. `screen` is written directly in
     :new -- the window has to know what it is before createChildren runs -- and goes
     through setScreen everywhere after. Only setScreen used to repopulate, so a window
     that ARRIVED at the chooser by clicking was fine and one that OPENED on it drew an
     empty table with two cards in the player's pockets. ]]
function TC_ATMWindow:refreshForScreen()
    if self.screen == ACCOUNT then self:refreshStatement() end
    if self.screen == CHOOSE  then self:refreshCards() end
end

function TC_ATMWindow:setScreen(screen)
    self.screen = screen
    self:refreshForScreen()
    self:applyScreen()
end

--[[ Show what belongs to the current screen and hide everything else, then place it.

     Every widget exists for the whole life of the window, which is what makes this a
     visibility switch rather than a teardown: the alternative -- destroying and rebuilding
     children on every step -- is how a UI ends up holding a reference to a button that is
     no longer in the tree. ]]
function TC_ATMWindow:applyScreen()
    local s = self.screen

    self.openBtn:setVisible(s == WELCOME)
    self.leaveBtn:setVisible(s == WELCOME)

    for _, b in ipairs(self.keys) do b:setVisible(s == PIN) end
    self.pinCancelBtn:setVisible(s == PIN)

    self.cardList:setVisible(s == CHOOSE)
    self.insertBtn:setVisible(s == CHOOSE)
    self.chooseCancelBtn:setVisible(s == CHOOSE)

    self.list:setVisible(s == ACCOUNT)
    self.depositBtn:setVisible(s == ACCOUNT)
    self.withdrawBtn:setVisible(s == ACCOUNT)
    self.transferBtn:setVisible(s == ACCOUNT)
    self.doneBtn:setVisible(s == ACCOUNT)

    for _, b in ipairs(self.quickBtns) do b:setVisible(s == AMOUNT) end
    self.customEntry:setVisible(s == AMOUNT)
    self.confirmBtn:setVisible(s == AMOUNT)
    self.backBtn:setVisible(s == AMOUNT)

    self:layoutWidgets()
end

--[[ Place everything for the screen that is showing. Called from applyScreen and again
     from onResize, so a drag moves the keypad the same way it moves the list. ]]
function TC_ATMWindow:layoutWidgets()
    -- onResize can fire before createChildren has run -- setting a width on a window is
    -- enough to trigger it -- and every branch below reaches for a child that would not
    -- exist yet. The rail guards itself the same way in TC.layoutRail.
    if not self.keys then return end

    local L = self:layout()
    local s = self.screen

    if s == WELCOME then
        local slots = TC.buttonRow(L.x, L.w, { self:openLabel(),
                                               getText("IGUI_TC_BankCancel") }, UIFont.Medium)
        self:place(self.openBtn,  slots[1], L.buttonY)
        self:place(self.leaveBtn, slots[2], L.buttonY)

    elseif s == CHOOSE then
        -- Below its own header strip, which the window draws rather than the list -- the
        -- same arrangement the statement, the ledger and the catalogue all use.
        local listY = L.bodyY + HEADER_HGT
        self.cardList:setX(L.x)
        self.cardList:setY(listY)
        self.cardList:setWidth(L.w)
        self.cardList:setHeight(math.max(ROW_HGT, L.bodyY + L.bodyH - listY))

        local slots = TC.buttonRow(L.x, L.w, { getText("IGUI_TC_BankInsertCard"),
                                               getText("IGUI_TC_BankCancel") }, UIFont.Medium)
        self:place(self.insertBtn,       slots[1], L.buttonY)
        self:place(self.chooseCancelBtn, slots[2], L.buttonY)

    elseif s == PIN then
        local kw  = keyWidth()
        local kx0 = L.x + math.floor((L.w - keypadWidth()) / 2)
        -- Through pinGeometry, the same function drawPin measures the boxes against, so
        -- the keys and the boxes cannot end up on top of each other again.
        local ky0 = self:pinGeometry(0).keyY

        for i, b in ipairs(self.keys) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            b:setX(kx0 + col * (kw + KEY_GAP))
            b:setY(ky0 + row * (BUTTON_HGT + KEY_GAP))
            b:setWidth(kw)
            b:setHeight(BUTTON_HGT)
        end

        --[[ One button, centred rather than run through TC.buttonRow.

             buttonRow lays a row out from x0 and puts the slack into the GAPS between
             buttons; with a single label there are no gaps, so it would sit hard against
             the left border with the rest of the row empty beside it. Sized by the same
             rule buttonRow uses -- the label plus BTN_PAD -- and then centred. ]]
        local label = getText("IGUI_TC_BankCancel")
        local bw    = getTextManager():MeasureStringX(UIFont.Medium, label) + TC.UI.BTN_PAD
        self:place(self.pinCancelBtn,
                   { x = L.x + math.floor((L.w - bw) / 2), w = bw, text = label },
                   L.buttonY)

    elseif s == ACCOUNT then
        local listY = L.bodyY + summaryHeight() + PAD * 2 + HEADER_HGT
        self.list:setX(L.x)
        self.list:setY(listY)
        self.list:setWidth(L.w)
        self.list:setHeight(math.max(ROW_HGT, L.bodyY + L.bodyH - listY))

        local slots = TC.buttonRow(L.x, L.w, { getText("IGUI_TC_BankDeposit"),
                                               getText("IGUI_TC_BankWithdraw"),
                                               getText("IGUI_TC_BankTransfer"),
                                               getText("IGUI_TC_BankDone") }, UIFont.Medium)
        self:place(self.depositBtn,  slots[1], L.buttonY)
        self:place(self.withdrawBtn, slots[2], L.buttonY)
        self:place(self.transferBtn, slots[3], L.buttonY)
        self:place(self.doneBtn,     slots[4], L.buttonY)

    elseif s == AMOUNT then
        local G = self:amountGeometry()

        local labels = {}
        for i, n in ipairs(QUICK) do labels[i] = "$" .. n end
        labels[#QUICK + 1] = getText("IGUI_TC_BankAll")

        local slots = TC.buttonRow(L.x, L.w, labels, UIFont.Medium)
        for i, b in ipairs(self.quickBtns) do
            self:place(b, slots[i], G.quickY)
        end

        -- The typed field sits under the row it is an alternative to, indented past its
        -- own label so the two read as one line rather than as a stray box.
        local labelW = getTextManager():MeasureStringX(UIFont.Small,
                                                       getText("IGUI_TC_BankCustom")) + PAD
        self.customEntry:setX(L.x + labelW)
        self.customEntry:setY(G.entryY)
        self.customEntry:setWidth(math.max(80, math.min(160, L.w - labelW)))

        local btm = TC.buttonRow(L.x, L.w, { getText("IGUI_TC_BankConfirm"),
                                             getText("IGUI_TC_BankBack") }, UIFont.Medium)
        self:place(self.confirmBtn, btm[1], L.buttonY)
        self:place(self.backBtn,    btm[2], L.buttonY)
    end
end

--[[ Put a button in the slot TC.buttonRow worked out for it.

     The title is re-set along with the width: below a certain window size buttonRow
     truncates the labels to fit, and growing the window has to give the words back. The
     cart window learned this the hard way and does the same thing in its onResize. ]]
function TC_ATMWindow:place(button, slot, y)
    button:setX(slot.x)
    button:setY(y)
    button:setWidth(slot.w)
    button:setHeight(BUTTON_HGT)
    button:setTitle(slot.text)
end

function TC_ATMWindow:refreshStatement()
    self.list:clear()
    for _, entry in ipairs(TC.statement(self.player, self.accountNumber)) do
        self.list:addItem(entry.when or "", entry)
    end
end

--[[ Fill the chooser from what is actually in the player's pockets right now.

     Re-read rather than remembered from when the window opened, because this is the same
     question the access rule asks and there is no reason for two answers to it to exist.
     The selection is left on the first row so that Insert card always has something to
     act on. ]]
function TC_ATMWindow:refreshCards()
    self.cardList:clear()
    for _, card in ipairs(TC.cardsOnPlayer(self.player)) do
        self.cardList:addItem(card.account.number or "", card)
    end

    -- Kept in step with the list so the prerender's cheap "has it changed" test has
    -- something true to compare against, whoever rebuilt it.
    self.lastCardCount = #self.cardList.items

    -- The first row is selected rather than nothing, so Insert card always has something
    -- to act on and the screen never answers a click with "choose a card first" while a
    -- card is plainly sitting there.
    self.cardList.selected = 1
end

--[[ What the welcome screen's big button says, which depends on why the player is looking
     at it. Opening a first account and replacing a lost card do exactly the same thing --
     a new account at zero -- and the label is the only place the difference is visible, so
     it has to be right. ]]
function TC_ATMWindow:openLabel()
    if TC.hasAnyAccount(self.player) then return getText("IGUI_TC_BankLostCard") end
    return getText("IGUI_TC_BankOpenAccount")
end

function TC_ATMWindow:onCardDoubleClick()
    self:onInsertCard()
end

function TC_ATMWindow:onInsertCard()
    local sel = self.cardList.items[self.cardList.selected]
    if not sel then
        self:setMessage(getText("IGUI_TC_BankSelectCard"), true)
        return
    end

    --[[ Re-asked, because the list was built when the screen opened and the inventory is
         fully usable underneath this window. A card put down between the chooser being
         drawn and the button being pressed must not reach a keypad -- the session would
         only be killed on the next range tick anyway, and being refused here says why. ]]
    local number = sel.item.account.number
    if not TC.holdsCardFor(self.player, number) then
        self:setScreen(CHOOSE)
        self:setMessage(getText("IGUI_TC_BankCardGone"), true)
        return
    end

    self.accountNumber = number
    self.pinMode   = "enter"
    self.pinBuffer = ""
    self:setScreen(self:afterCard())
end

-- ---------------------------------------------------------------------------
-- The keypad
-- ---------------------------------------------------------------------------

function TC_ATMWindow:onKeypad(button)
    local code = button and button.internal
    if not code then return end

    if code == "CLEAR" then
        self.pinBuffer = ""
        return
    end

    if code == "ENTER" then
        self:submitPin()
        return
    end

    -- Silently ignored once four digits are in rather than beeping about it: the keypad
    -- submits on Enter, so an over-full buffer is a state the player can see and fix by
    -- pressing Clear.
    if #self.pinBuffer < TC.PIN_LENGTH then
        self.pinBuffer = self.pinBuffer .. code
    end
end

--[[ What Enter means depends on which question was asked.

     Three modes, and they are deliberately one screen rather than three: the keypad, the
     four boxes and the prompt are identical in all of them, and only the sentence above
     them and what happens on Enter change. ]]
function TC_ATMWindow:submitPin()
    if not TC.isValidPin(self.pinBuffer) then
        self:setMessage(getText("IGUI_TC_PinTooShort", TC.PIN_LENGTH), true)
        return
    end

    if self.pinMode == "new" then
        self.pinFirst  = self.pinBuffer
        self.pinBuffer = ""
        self.pinMode   = "confirm"
        self:setMessage(nil, false)
        return
    end

    if self.pinMode == "confirm" then
        if self.pinBuffer ~= self.pinFirst then
            -- Back to the start of the pair, not to the confirmation: the player does not
            -- know which of the two they mistyped, so asking them to confirm a PIN they
            -- may not have meant would be the wrong half to keep.
            self.pinBuffer = ""
            self.pinFirst  = ""
            self.pinMode   = "new"
            self:setMessage(getText("IGUI_TC_PinMismatch"), true)
            return
        end

        local acct = TC.openAccount(self.player, self.pinBuffer)
        self.pinBuffer = ""
        self.pinFirst  = ""

        if not acct then
            self:setMessage(getText("IGUI_TC_BankOpenFailed"), true)
            return
        end

        -- The session is now about the account that was just opened. Without this the
        -- next screen would be addressed at nil and show an empty account that exists.
        self.accountNumber = acct.number

        TC.playSound(self.player, "cash")
        self:setScreen(ACCOUNT)
        self:setMessage(getText("IGUI_TC_BankOpened"), false)
        return
    end

    -- "enter": the ordinary case, unlocking the account whose card was inserted.
    local acct = TC.account(self.player, self.accountNumber)

    --[[ A card that has already been shut out does not get to be guessed at.

         Checked before the PIN is compared, so a locked card cannot be brute-forced by
         somebody who is willing to click through the refusal -- and so that a player who
         locked it and then FOUND the note still has to wait, which is the lockout meaning
         anything. ]]
    if TC.isCardLocked(acct) then
        self.pinBuffer = ""
        self:setMessage(getText("IGUI_TC_PinCardLocked",
                                math.ceil(TC.lockedHours(acct))), true)
        return
    end

    if not TC.checkPin(self.player, self.accountNumber, self.pinBuffer) then
        self.pinBuffer = ""

        --[[ THE COUNTER IS ON THE ACCOUNT, NOT ON THIS WINDOW.

             It used to be `self.pinTries`, which meant closing the machine and reopening
             it handed the player a fresh three, and walking to an ATM in the next town
             handed them another. It is the same card and the same bank. TC.wrongPin also
             knows about the Burglar trait, which is worth two extra guesses a day. ]]
        local left, locked = TC.wrongPin(acct, self.player)

        if locked then
            -- The card is NOT retained. A mod that destroys the way into an account over
            -- three typos is a mod nobody keeps installed; it goes quiet until tomorrow.
            HaloTextHelper.addBadText(self.player,
                getText("IGUI_TC_PinLockedOut", TC.PIN_LOCKOUT_HOURS))
            self:close()
            return
        end

        self:setMessage(getText("IGUI_TC_PinWrong", left), true)
        return
    end

    self.pinBuffer = ""
    TC.clearPinTries(acct)

    --[[ NO CARD IS PRINTED HERE, and the absence is the design.

         0.1.0-beta reissued one at this point, on the reasoning that the PIN identified
         the holder and the plastic was a replaceable convenience. That is exactly what
         made the card meaningless. The PIN now proves you may use the card you are
         holding; it proves nothing about a card you are not. ]]
    self:setScreen(ACCOUNT)
end

-- ---------------------------------------------------------------------------
-- Buttons
-- ---------------------------------------------------------------------------

function TC_ATMWindow:onOpenAccount()
    self.pinMode   = "new"
    self.pinBuffer = ""
    self.pinFirst  = ""
    self:setScreen(PIN)
end

function TC_ATMWindow:onDeposit()  self:startAmount("deposit")  end
function TC_ATMWindow:onWithdraw() self:startAmount("withdraw") end

--[[ Sending money is the one thing here that does NOT take over the screen.

     Deposit and Withdraw replace the account screen for a moment and hand it straight
     back. A transfer is read against the balance it is coming out of while the figure is
     typed, so covering that balance would hide the number the decision is being made
     against -- the cart's argument, in TC_CartWindow's header, arrived at again. It docks
     beside the machine instead, and this button toggles it: once it is sitting there, the
     button that opened it is the obvious way to get the space back. ]]
function TC_ATMWindow:onTransfer()
    TC.toggleTransferWindow(self.playerNum, self.accountNumber)
end

--[[ Open the amount screen with nothing filled in.

     Zero rather than a remembered figure, and rather than the maximum. A screen that
     opens with a number already in it is a screen where Confirm can move money the player
     did not choose, and this one has exactly one irreversible button on it. ]]
function TC_ATMWindow:startAmount(mode)
    self.amountMode = mode
    self.amount     = 0
    self.customEntry:setText("0")
    self:setScreen(AMOUNT)
end

function TC_ATMWindow:onBack()
    self:setScreen(ACCOUNT)
end

--[[ How much this screen may move: cash in the player's pockets going in, money in the
     account coming out. Everything on the amount screen is measured against it. ]]
function TC_ATMWindow:available()
    if self.amountMode == "deposit" then
        return TC.getBalance(self.player)
    end
    return TC.bankBalance(self.player, self.accountNumber)
end

function TC_ATMWindow:setAmount(n)
    self.amount = math.max(0, math.floor(n or 0))
    self.customEntry:setText(tostring(self.amount))
end

function TC_ATMWindow:onQuick(button)
    local code = button and button.internal
    if not code then return end

    if code == "ALL" then
        self:setAmount(self:available())
        return
    end
    self:setAmount(tonumber(code) or 0)
end

--[[ Typed figures are NOT clamped as they are typed.

     Clamping on every keystroke means a player whose account holds $5 cannot type "50" --
     the 5 is accepted, the 0 is clamped away, and the field fights them. The figure is
     taken as typed, the panel turns the resulting balance red, and Confirm is the thing
     that refuses. Same treatment the buy window gives an unaffordable order. ]]
function TC_ATMWindow:onAmountTyped()
    self.amount = math.max(0, math.floor(tonumber(self.customEntry:getInternalText()) or 0))
end

function TC_ATMWindow:onConfirmAmount()
    local amount = self.amount

    if amount <= 0 then
        self:setMessage(getText("IGUI_TC_BankBadAmount"), true)
        return
    end

    local ok, why
    if self.amountMode == "deposit" then
        ok, why = TC.bankDeposit(self.player, self.accountNumber, amount)
    else
        ok, why = TC.bankWithdraw(self.player, self.accountNumber, amount)
    end

    if not ok then
        self:setMessage(why or getText("IGUI_TC_BankBadAmount"), true)
        return
    end

    self:setScreen(ACCOUNT)
    if self.amountMode == "deposit" then
        self:setMessage(getText("IGUI_TC_BankDeposited", amount), false)
    else
        self:setMessage(getText("IGUI_TC_BankWithdrew", amount), false)
    end
end

function TC_ATMWindow:onDone()
    self:close()
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

--[[ A label on the left and a value on the right of the same line, which is the shape
     every figure in this mod is presented in. Returns the y the next line starts at, so a
     block of them is written as a walk rather than as a column of hand-added offsets. ]]
function TC_ATMWindow:statLine(left, right, y, label, value, font, r, g, b)
    font = font or UIFont.Small
    local h  = getTextManager():getFontHeight(font)
    local vw = getTextManager():MeasureStringX(font, value)

    self:drawText(label, left, y + math.floor((h - FONT_HGT_SMALL) / 2),
                  0.68, 0.68, 0.72, 1, UIFont.Small)
    self:drawText(value, right - vw, y, r or 0.92, g or 0.92, b or 0.95, 1, font)

    return y + math.max(h, FONT_HGT_SMALL) + LINE_GAP
end

function TC_ATMWindow:headline()
    --[[ The welcome screen has two faces and they are NOT the same news.

         Somebody who has never banked is being offered something. Somebody with accounts
         and no card is being told that the way into them is not on them -- which is the
         single most important thing the machine can say at that moment, and saying "Open
         a Catalogue account" instead would read as if the old balance had been forgotten
         about. ]]
    if self.screen == WELCOME then
        if TC.hasAnyAccount(self.player) then return getText("IGUI_TC_ATMLostTitle") end
        return getText("IGUI_TC_ATMWelcome")
    end

    if self.screen == CHOOSE then return getText("IGUI_TC_ATMChoose") end

    if self.screen == PIN then
        if self.pinMode == "new"     then return getText("IGUI_TC_PinChoose") end
        if self.pinMode == "confirm" then return getText("IGUI_TC_PinConfirm") end
        return getText("IGUI_TC_PinEnter")
    end

    if self.screen == AMOUNT then
        if self.amountMode == "deposit" then return getText("IGUI_TC_BankDeposit") end
        return getText("IGUI_TC_BankWithdraw")
    end

    local acct = TC.account(self.player, self.accountNumber)
    return getText("IGUI_TC_BankGreeting", (acct and acct.holder) or "")
end

function TC_ATMWindow:prerender()
    ISCollapsableWindow.prerender(self)

    --[[ Two things end a session, both checked on the same timer rather than every frame:
         walking away from the machine, and the card leaving the player.

         The second is not paranoia about a case that cannot happen. A session lasts as
         long as the player wants it to, the inventory is fully usable underneath it, and
         dropping the card into the crate beside the ATM mid-transaction is a perfectly
         ordinary thing to do. The access rule is that the card is on you -- and a rule
         that were only enforced at the moment the window opened would be a rule about
         opening windows. ]]
    local now = getTimestampMs()
    if not self.lastRangeCheck or (now - self.lastRangeCheck) >= RANGE_CHECK_MS then
        self.lastRangeCheck = now

        if not self:stillAtMachine() then
            self:close()
            return
        end

        -- Only once a card has actually been inserted. Before that there is no account to
        -- lose hold of, and the welcome screen exists precisely for the player with none.
        if self.accountNumber and not TC.holdsCardFor(self.player, self.accountNumber) then
            HaloTextHelper.addBadText(self.player, getText("IGUI_TC_BankCardGone"))
            self:close()
            return
        end

        -- The chooser is a picture of the player's pockets, and the pockets stay editable
        -- while it is open. Rebuilt only when the COUNT moves, so the ordinary case is a
        -- comparison rather than a rebuild -- the same trick the arrival window uses to
        -- notice a second delivery landing while it is on screen.
        if self.screen == CHOOSE then
            local n = #TC.cardsOnPlayer(self.player)
            if n ~= self.lastCardCount then
                self.lastCardCount = n
                self:refreshCards()
            end
        end
    end

    local L = self:layout()

    TC.drawCentred(self, TC.truncate(UIFont.Large, self:headline(), L.w),
                   L.x, L.w, L.headlineY, UIFont.Large, 0.85, 1, 0.85)

    if     self.screen == WELCOME then self:drawWelcome(L)
    elseif self.screen == CHOOSE  then self:drawChoose(L)
    elseif self.screen == PIN     then self:drawPin(L)
    elseif self.screen == ACCOUNT then self:drawAccount(L)
    elseif self.screen == AMOUNT  then self:drawAmount(L)
    end

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local r, g, b = 0.6, 1, 0.6
        if msgErr then r, g, b = 1, 0.3, 0.3 end

        --[[ Wrapped, then bottom-anchored inside the block reserved for it.

             Bottom-anchored so that a one-line message sits just above the buttons where a
             one-line message always sat, and a two-line one grows UPWARD into the space
             that was already being held for it. Anchored to the top instead, every short
             message would float a line clear of the buttons and read as unrelated to
             them. ]]
        local lines = TC.wrapText(UIFont.Small, msgText, L.w)
        local shown = math.min(#lines, MSG_LINES)

        -- Past the reserved lines the message is cut from the END, not the start: losing
        -- the tail of a sentence still leaves it readable, and dropping the first line
        -- leaves the reader looking at the middle of something.
        if #lines > MSG_LINES then
            lines[shown] = TC.truncate(UIFont.Small, lines[shown] .. "...", L.w)
        end

        local y = L.msgY + L.msgH - shown * FONT_HGT_SMALL - (shown - 1) * MSG_LEADING

        for i = 1, shown do
            TC.drawCentred(self, lines[i], L.x, L.w, y, UIFont.Small, r, g, b)
            y = y + FONT_HGT_SMALL + MSG_LEADING
        end
    end
end

--[[ The four lines of sales patter, WRAPPED and not truncated.

     They were truncated, and at the size the window actually opens at the first two came
     out as "...at any cash machine in the cou..." and "...cannot be dropped or lo...".
     Truncation is for a table cell, where the column is the promise; a sentence that is
     being read has to be laid out instead. See TC.wrapText.

     Each sentence keeps its own paragraph gap and its wrapped continuations are set at a
     tighter leading, so four sentences over seven lines still read as four sentences. ]]
function TC_ATMWindow:drawWelcome(L)
    self:drawRect(L.x, L.bodyY, L.w, L.bodyH, 0.45, 0, 0, 0)
    self:drawRectBorder(L.x, L.bodyY, L.w, L.bodyH, 0.5, 0.4, 0.4, 0.4)

    local textW = L.w - PAD * 4

    -- Which of the two things this screen is here to say. See :headline.
    local body = TC.hasAnyAccount(self.player) and LOST or PITCH

    -- Laid out once into a flat list of { text, gapAfter }, so the height of the block is
    -- known before a single line is drawn and the whole thing can be centred in the panel.
    local rows, blockH = {}, 0
    for p, key in ipairs(body) do
        local lines = TC.wrapText(UIFont.Small, getText(key), textW)
        for i, line in ipairs(lines) do
            local last = (i == #lines)
            local gap  = 0
            if not last then gap = MSG_LEADING
            elseif p < #body then gap = LINE_GAP end

            table.insert(rows, { text = line, gap = gap })
            blockH = blockH + FONT_HGT_SMALL + gap
        end
    end

    -- Centred in the panel, but never above its top edge: on a window dragged to its
    -- minimum the block can be taller than the frame, and starting inside it and running
    -- out of the bottom loses the last line rather than the first two.
    local y = L.bodyY + math.max(PAD, math.floor((L.bodyH - blockH) / 2))
    local floorY = L.bodyY + L.bodyH - PAD

    for _, row in ipairs(rows) do
        if y + FONT_HGT_SMALL > floorY then return end
        TC.drawCentred(self, row.text, L.x, L.w, y, UIFont.Small, 0.78, 0.78, 0.82)
        y = y + FONT_HGT_SMALL + row.gap
    end
end

--[[ The chooser's header strip, drawn on the window rather than inside the list box --
     the arrangement every other table in this mod uses, because ISScrollingListBox has no
     header of its own worth fighting. ]]
function TC_ATMWindow:drawChoose(L)
    local F     = UIFont.Small
    local ruleX = cardRule(L.w)

    self:drawRect(L.x, L.bodyY, L.w, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(L.x, L.bodyY, L.w, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)
    self:drawRect(L.x + ruleX, L.bodyY, 1, HEADER_HGT, 0.4, 1, 1, 1)

    local hy = L.bodyY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    self:drawText(getText("IGUI_TC_BankAccountNo"), L.x + INSET, hy, 0.72, 0.72, 0.76, 1, F)
    TC.drawRight(self, getText("IGUI_TC_BankColOpened"), L.x + L.w - INSET, hy,
                 F, 0.72, 0.72, 0.76)

    -- An empty chooser should be unreachable -- it is only opened with two cards in hand --
    -- but the player can empty it from underneath by putting the cards down, and a black
    -- panel with no words in it is the worst thing a screen can be.
    if #self.cardList.items == 0 then
        TC.drawCentred(self, TC.truncate(F, getText("IGUI_TC_ATMLost1"), L.w - PAD * 2),
                       L.x, L.w, self.cardList:getY() + PAD, F, 0.55, 0.55, 0.6)
    end
end

--[[ The four PIN boxes.

     A filled box is drawn as a small SQUARE and not as a bullet character, for the reason
     TC.drawSortArrow gives about its triangles: the game's bitmap fonts have no guaranteed
     coverage for those code points, and a missing glyph renders as nothing at all -- which
     here would mean a PIN field that never appears to accept anything. Rectangles always
     draw. ]]
--[[ What is known about the card in the machine, as wrapped lines and a colour.

     The examine action says it once in halo text and then it is gone, and the player who
     learned "1 3 3 7" three days and two towns ago will not remember it. So the machine
     repeats it at the moment it is useful, which is the only moment it matters.

     WRAPPED, because it did not fit. "Pressed into the plastic: 1 3 3 7 - the order is
     yours to find" ran off both edges of the window at the size it opens at -- drawCentred
     will happily centre a string wider than the box it is centred in, which puts equal
     amounts of it outside each border. Every other run of prose in this mod goes through
     TC.wrapText and this one was written before that existed.

     Nothing at all while a PIN is being CHOSEN: there is no secret to know about an
     account that does not exist yet. ]]
function TC_ATMWindow:knownLines(width)
    if self.pinMode ~= "enter" then return nil end

    local acct = TC.account(self.player, self.accountNumber)
    if not acct then return nil end

    if TC.knowsPin(acct) then
        return TC.wrapText(UIFont.Small, getText("IGUI_TC_PinKnown", acct.pin), width),
               0.66, 0.94, 0.66
    end

    if TC.knowsDigits(acct) then
        return TC.wrapText(UIFont.Small,
                           getText("IGUI_TC_PinDigitsKnown", TC.pinDigits(acct)), width),
               0.94, 0.88, 0.62
    end

    return nil
end

function TC_ATMWindow:drawPin(L)
    local textW = L.w - PAD * 2

    local lines, kr, kg, kb = self:knownLines(textW)
    local G = self:pinGeometry(lines and #lines or 0)

    if lines then
        local y = G.knownY
        for _, line in ipairs(lines) do
            TC.drawCentred(self, line, L.x, L.w, y, UIFont.Small, kr, kg, kb)
            y = y + FONT_HGT_SMALL + MSG_LEADING
        end
    end

    TC.drawCentred(self, TC.truncate(UIFont.Small, getText("IGUI_TC_PinPrompt"), textW),
                   L.x, L.w, G.promptY, UIFont.Small, 0.68, 0.68, 0.72)

    --[[ The four boxes, sitting a full padding above the keys because pinGeometry put
         them there. A filled box is a small SQUARE and not a bullet character, for the
         reason TC.drawSortArrow gives about its triangles: the bitmap fonts have no
         guaranteed coverage for those code points, and a missing glyph renders as nothing
         at all -- which here would be a PIN field that never appears to accept anything. ]]
    local total = G.boxW * TC.PIN_LENGTH + KEY_GAP * (TC.PIN_LENGTH - 1)
    local x = L.x + math.floor((L.w - total) / 2)

    for i = 1, TC.PIN_LENGTH do
        local bx = x + (i - 1) * (G.boxW + KEY_GAP)
        self:drawRect(bx, G.boxY, G.boxW, G.boxH, 0.5, 0, 0, 0)
        self:drawRectBorder(bx, G.boxY, G.boxW, G.boxH, 0.6, 0.45, 0.45, 0.45)

        if i <= #self.pinBuffer then
            local dot = 8
            self:drawRect(bx + (G.boxW - dot) / 2, G.boxY + (G.boxH - dot) / 2, dot, dot,
                          0.95, 0.85, 1, 0.85)
        end
    end
end

function TC_ATMWindow:drawAccount(L)
    local acct = TC.account(self.player, self.accountNumber)
    if not acct then return end

    local panelH = summaryHeight()
    self:drawRect(L.x, L.bodyY, L.w, panelH, 0.45, 0, 0, 0)
    self:drawRectBorder(L.x, L.bodyY, L.w, panelH, 0.5, 0.4, 0.4, 0.4)

    local left  = L.x + PAD
    local right = L.x + L.w - PAD
    local y     = L.bodyY + PAD

    y = self:statLine(left, right, y, getText("IGUI_TC_BankAccountNo"),
                      acct.number or "?", UIFont.Small, 0.72, 0.72, 0.76)
    y = self:statLine(left, right, y, getText("IGUI_TC_BankHolder"),
                      TC.truncate(UIFont.Small, acct.holder or "?", L.w / 2),
                      UIFont.Small, 0.72, 0.72, 0.76)

    self:drawRect(left, y, L.w - PAD * 2, 1, 0.35, 1, 1, 1)
    y = y + LINE_GAP

    y = self:statLine(left, right, y, getText("IGUI_TC_BankBalance"),
                      "$" .. TC.bankBalance(self.player, self.accountNumber), UIFont.Large, 0.78, 0.98, 0.78)
    self:statLine(left, right, y, getText("IGUI_TC_BankOnHand"),
                  "$" .. TC.getBalance(self.player), UIFont.Small, 0.72, 0.72, 0.76)

    -- The statement's own header strip, drawn on the window rather than inside the list
    -- box, exactly as the other three tables in this mod do it.
    local headerY = L.bodyY + panelH + PAD * 2
    local c = statementColumns(L.w)

    self:drawRect(L.x, headerY, L.w, HEADER_HGT, 0.75, 0.13, 0.13, 0.15)
    self:drawRectBorder(L.x, headerY, L.w, HEADER_HGT, 0.5, 0.4, 0.4, 0.4)

    local hy = headerY + (HEADER_HGT - FONT_HGT_SMALL) / 2
    local F  = UIFont.Small
    for _, x in ipairs(c.rules) do
        self:drawRect(L.x + x, headerY, 1, HEADER_HGT, 0.4, 1, 1, 1)
    end

    self:drawText(getText("IGUI_TC_LedgerWhen"), L.x + c.whenLeft, hy, 0.72, 0.72, 0.76, 1, F)
    self:drawText(getText("IGUI_TC_LedgerWhat"), L.x + c.whatLeft, hy, 0.72, 0.72, 0.76, 1, F)
    TC.drawRight(self, getText("IGUI_TC_LedgerAmount"),   L.x + c.amtRight, hy, F, 0.72, 0.72, 0.76)
    TC.drawRight(self, getText("IGUI_TC_BankColBalance"), L.x + c.balRight, hy, F, 0.72, 0.72, 0.76)

    if #self.list.items == 0 then
        TC.drawCentred(self, getText("IGUI_TC_BankNoActivity"), L.x, L.w,
                       self.list:getY() + PAD, UIFont.Small, 0.55, 0.55, 0.6)
    end
end

function TC_ATMWindow:drawAmount(L)
    local G     = self:amountGeometry()
    local avail = self:available()

    self:drawRect(L.x, G.panelY, L.w, G.panelH, 0.45, 0, 0, 0)
    self:drawRectBorder(L.x, G.panelY, L.w, G.panelH, 0.5, 0.4, 0.4, 0.4)

    local left  = L.x + PAD
    local right = L.x + L.w - PAD
    local y     = G.panelY + PAD

    local availKey = (self.amountMode == "deposit") and "IGUI_TC_BankOnHand"
                                                    or "IGUI_TC_BankBalance"
    y = self:statLine(left, right, y, getText(availKey), "$" .. avail,
                      UIFont.Small, 0.72, 0.72, 0.76)

    -- Red the moment the figure is more than the screen can move, so the refusal is
    -- visible before Confirm is ever pressed rather than after it.
    local over = self.amount > avail
    if over then
        y = self:statLine(left, right, y, getText("IGUI_TC_BankAmount"),
                          "$" .. self.amount, UIFont.Large, 1, 0.35, 0.35)
    else
        y = self:statLine(left, right, y, getText("IGUI_TC_BankAmount"),
                          "$" .. self.amount, UIFont.Large, 0.78, 0.98, 0.78)
    end

    --[[ What a withdrawal will cost you to carry, stated before you take it.

         TC.cashWeight is the same arithmetic the buy window uses to warn about a heavy
         purchase: bundles at half a kilo, loose notes at a hundredth. $10,000 is a
         hundred bundles and fifty kilos, and that is worth knowing at the machine rather
         than at the door. ]]
    if self.amountMode == "withdraw" then
        self:statLine(left, right, y, getText("IGUI_TC_BankToCarry"),
                      string.format("%.1f", TC.cashWeight(self.amount)),
                      UIFont.Small, 0.72, 0.72, 0.76)
    else
        self:statLine(left, right, y, getText("IGUI_TC_BankBalanceAfter"),
                      "$" .. (TC.bankBalance(self.player, self.accountNumber) + self.amount),
                      UIFont.Small, 0.72, 0.72, 0.76)
    end

    self:drawText(getText("IGUI_TC_BankCustom"), L.x,
                  G.entryY + (BUTTON_HGT - FONT_HGT_SMALL) / 2,
                  0.68, 0.68, 0.72, 1, UIFont.Small)

    -- A quick amount you cannot afford is disabled rather than left to fail on Confirm.
    -- "All" is the one that means "whatever there is", so it only goes out at zero.
    for i, b in ipairs(self.quickBtns) do
        if b.internal == "ALL" then
            b:setEnable(avail > 0)
        else
            b:setEnable((tonumber(b.internal) or 0) <= avail)
        end
    end
    self.confirmBtn:setEnable(self.amount > 0 and not over)
end

-- ---------------------------------------------------------------------------
-- Life cycle
-- ---------------------------------------------------------------------------

--[[ Is the player still in front of the machine?

     A flat box in tiles rather than a true distance, because the squares either side of a
     wall-mounted ATM are as much "at the machine" as the one in front of it, and because
     a couple of comparisons beat a square root on a check that runs several times a
     second. The z test is what stops a player operating the ATM from the floor above. ]]
function TC_ATMWindow:stillAtMachine()
    if not self.player then return false end
    if not self.atm then return true end

    local square = self.atm:getSquare()
    if not square then return false end
    if math.floor(self.player:getZ()) ~= square:getZ() then return false end

    return math.abs(self.player:getX() - (square:getX() + 0.5)) <= RANGE_TILES
       and math.abs(self.player:getY() - (square:getY() + 0.5)) <= RANGE_TILES
end

function TC_ATMWindow:onResize()
    ISCollapsableWindow.onResize(self)
    self:layoutWidgets()
end

function TC_ATMWindow:close()
    -- The buffer is wiped before the window goes, so nothing of the PIN survives in a
    -- table that something else might still be holding a reference to.
    self.pinBuffer = ""
    self.pinFirst  = ""

    --[[ The transfer window belongs to this session, not to the character, so it goes when
         the machine does. Its own prerender would notice and close it a frame later
         anyway; doing it here means the two disappear together rather than in sequence. ]]
    local transfer = TC_TransferWindow and TC_TransferWindow.instances[self.playerNum]
    if transfer then transfer:close() end

    TC.playSound(self.player, "atmClose")
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_ATMWindow.instances[self.playerNum] = nil
end

TC.applyMessageBehaviour(TC_ATMWindow)

--[[ Open the machine, or bring the one already open forward.

     Centred rather than remembered. TC.frameRect is where the catalogue's three panes
     keep their shared rectangle, and this window is deliberately not part of that set: it
     is a different size, it has no rail, and it belongs to a place rather than to the
     book. Sharing the frame would drag the catalogue's size onto it and back again. ]]
function TC.openATMWindow(playerNum, atm)
    local player = getSpecificPlayer(playerNum)
    if not player then return nil end

    local existing = TC_ATMWindow.instances[playerNum]
    if existing then
        existing.atm = atm or existing.atm
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.min(620, sw - 80)
    local h = math.min(640, sh - 80)

    local win = TC_ATMWindow:new((sw - w) / 2, (sh - h) / 2, w, h, playerNum, atm)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_ATMTitle"))
    win:addToUIManager()
    TC_ATMWindow.instances[playerNum] = win

    TC.playSound(player, "atmOpen")
    return win
end
