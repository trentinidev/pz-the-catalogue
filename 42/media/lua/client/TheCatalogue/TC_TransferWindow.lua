--[[ The Catalogue -- sending money from one account to another.

     A SEPARATE WINDOW, NOT A SIXTH SCREEN, and it is the cart's argument rather than the
     machine's. Deposit and Withdraw are screens because they replace the account screen
     for a moment and hand it straight back. A transfer is not like that: you are reading
     one balance while typing a figure to send off it, and a screen that covered the
     account would hide the number the decision is being made against -- which is exactly
     why TC_CartWindow is a window beside the catalogue instead of a fourth rail pane.

     So it docks to the machine the way the cart docks to the catalogue, and the Transfer
     button TOGGLES it: once it is sitting there, the button that opened it is the obvious
     way to get the space back.

     FOUR DIGITS IS THE ADDRESS. Sixteen typed into a field is an errand, and the tail is
     what is printed on the card and shown on every screen. It can be an address at all
     because TC_Bank refuses to mint an account whose last four are already taken -- see
     newAccountNumber.

     NO CARD IS NEEDED AT THE FAR END. Paying into an account you cannot open is what
     knowing somebody's number lets you do, and it cannot dodge the access rule: the money
     lands somewhere that still needs its own card to be taken out again.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

-- File locals, every one of them, for the reason tools/check.sh has a `consts` rule.
local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE  = getTextManager():getFontHeight(UIFont.Large)

local PAD        = 14
local BOTTOM_PAD = PAD * 2
local BUTTON_HGT = FONT_HGT_MEDIUM + 12
local LINE_GAP   = 10

-- The same steps the machine's own amount screen offers, so the two read as one feature.
local QUICK = { 1, 5, 10, 20, 50, 100 }

-- Two lines of room for the status message, held whether or not there is one, for the
-- reason TC_ATMWindow gives: a message that grows downwards grows into the button row.
local MSG_LINES   = 2
local MSG_LEADING = 3

local TAIL_DIGITS = 4

-- ---------------------------------------------------------------------------

TC_TransferWindow = ISCollapsableWindow:derive("TC_TransferWindow")
TC_TransferWindow.instances = TC_TransferWindow.instances or {}

local function quickLabels()
    local out = {}
    for i, n in ipairs(QUICK) do out[i] = "$" .. n end
    out[#QUICK + 1] = getText("IGUI_TC_BankAll")
    return out
end

function TC_TransferWindow:new(x, y, w, h, playerNum, accountNumber)
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self

    o.playerNum     = playerNum
    o.player        = getSpecificPlayer(playerNum)
    o.accountNumber = accountNumber
    o.amount        = 0

    o:setResizable(true)
    o.minimumWidth = math.max(
        TC.buttonRowWidth(quickLabels(), UIFont.Medium),
        TC.buttonRowWidth({ getText("IGUI_TC_BankSend"),
                            getText("IGUI_TC_BankCancel") }, UIFont.Medium)) + PAD * 2

    o.minimumHeight = FONT_HGT_MEDIUM + PAD                    -- title bar
                      + PAD + FONT_HGT_SMALL * 2 + LINE_GAP * 2 + FONT_HGT_LARGE + PAD
                      + PAD + BUTTON_HGT                       -- the destination field
                      + PAD + BUTTON_HGT                       -- the quick row
                      + PAD + BUTTON_HGT                       -- the typed amount
                      + PAD + FONT_HGT_SMALL * MSG_LINES + MSG_LEADING
                      + PAD + BUTTON_HGT + BOTTOM_PAD
    return o
end

--[[ The stack, walked down once. Same shape as the machine's own layout(): a panel at the
     top, rows of controls under it, a status block and a button row pinned to the bottom. ]]
function TC_TransferWindow:layout()
    local L = {}
    L.x       = PAD
    L.w       = self.width - PAD * 2
    L.panelY  = self:titleBarHeight() + PAD
    L.panelH  = PAD * 2 + FONT_HGT_SMALL * 2 + LINE_GAP * 2 + FONT_HGT_LARGE

    L.toY     = L.panelY + L.panelH + PAD
    L.quickY  = L.toY + BUTTON_HGT + PAD
    L.entryY  = L.quickY + BUTTON_HGT + PAD

    L.buttonY = self.height - BOTTOM_PAD - BUTTON_HGT
    L.msgH    = FONT_HGT_SMALL * MSG_LINES + MSG_LEADING * (MSG_LINES - 1)
    L.msgY    = L.buttonY - PAD - L.msgH
    return L
end

--[[ How wide the label in front of a field is: the wider of the two, so the two fields
     line up with each other rather than each sitting at its own indent. ]]
function TC_TransferWindow:labelWidth()
    local tm = getTextManager()
    return math.max(tm:MeasureStringX(UIFont.Small, getText("IGUI_TC_BankToAccount")),
                    tm:MeasureStringX(UIFont.Small, getText("IGUI_TC_BankCustom"))) + PAD
end

function TC_TransferWindow:mkButton(text, handler, internal)
    local b = ISButton:new(0, 0, 10, BUTTON_HGT, text, self, handler)
    b.internal = internal
    b:initialise(); b:instantiate()
    self:addChild(b)
    return b
end

function TC_TransferWindow:createChildren()
    ISCollapsableWindow.createChildren(self)

    local L = self:layout()

    --[[ Four digits and no more. setOnlyNumbers keeps letters out and the length cap keeps
         a fifth digit out, so the field can only ever hold something the address format
         accepts -- there is no "that is not a valid account number" to report because the
         field cannot be made to say one. ]]
    self.toEntry = ISTextEntryBox:new("", PAD, L.toY, 90, BUTTON_HGT)
    self.toEntry:initialise(); self.toEntry:instantiate()
    self.toEntry:setOnlyNumbers(true)
    self.toEntry:setMaxTextLength(TAIL_DIGITS)
    self:addChild(self.toEntry)

    self.quickBtns = {}
    for i, n in ipairs(QUICK) do
        self.quickBtns[i] = self:mkButton("$" .. n, TC_TransferWindow.onQuick, tostring(n))
    end
    self.quickBtns[#QUICK + 1] = self:mkButton(getText("IGUI_TC_BankAll"),
                                               TC_TransferWindow.onQuick, "ALL")

    self.amountEntry = ISTextEntryBox:new("0", PAD, L.entryY, 120, BUTTON_HGT)
    self.amountEntry:initialise(); self.amountEntry:instantiate()
    self.amountEntry:setOnlyNumbers(true)
    self.amountEntry:setMaxTextLength(7)
    self.amountEntry.onTextChange = function() self:onAmountTyped() end
    self:addChild(self.amountEntry)

    self.sendBtn   = self:mkButton(getText("IGUI_TC_BankSend"),   TC_TransferWindow.onSend)
    self.cancelBtn = self:mkButton(getText("IGUI_TC_BankCancel"), TC_TransferWindow.onCancel)

    self:layoutWidgets()
end

function TC_TransferWindow:layoutWidgets()
    if not self.quickBtns then return end

    local L  = self:layout()
    local lw = self:labelWidth()

    self.toEntry:setX(L.x + lw)
    self.toEntry:setY(L.toY)
    self.toEntry:setWidth(math.max(60, math.min(110, L.w - lw)))

    local slots = TC.buttonRow(L.x, L.w, quickLabels(), UIFont.Medium)
    for i, b in ipairs(self.quickBtns) do
        b:setX(slots[i].x); b:setY(L.quickY)
        b:setWidth(slots[i].w); b:setHeight(BUTTON_HGT)
        b:setTitle(slots[i].text)
    end

    self.amountEntry:setX(L.x + lw)
    self.amountEntry:setY(L.entryY)
    self.amountEntry:setWidth(math.max(80, math.min(160, L.w - lw)))

    local btm = TC.buttonRow(L.x, L.w, { getText("IGUI_TC_BankSend"),
                                         getText("IGUI_TC_BankCancel") }, UIFont.Medium)
    for i, b in ipairs({ self.sendBtn, self.cancelBtn }) do
        b:setX(btm[i].x); b:setY(L.buttonY)
        b:setWidth(btm[i].w); b:setHeight(BUTTON_HGT)
        b:setTitle(btm[i].text)
    end
end

-- ---------------------------------------------------------------------------
-- What is in the fields
-- ---------------------------------------------------------------------------

--[[ The destination as typed: the four digits, or nil while it is still being typed.

     Nil rather than an error for a short entry. Somebody halfway through typing "8415" is
     not making a mistake, and a panel that turns red on the way to being right is a panel
     that teaches people to ignore it. ]]
function TC_TransferWindow:tail()
    local text = self.toEntry:getInternalText() or ""
    if #text ~= TAIL_DIGITS then return nil end
    return text
end

function TC_TransferWindow:available()
    return TC.bankBalance(self.player, self.accountNumber)
end

function TC_TransferWindow:setAmount(n)
    self.amount = math.max(0, math.floor(n or 0))
    self.amountEntry:setText(tostring(self.amount))
end

function TC_TransferWindow:onQuick(button)
    local code = button and button.internal
    if not code then return end

    if code == "ALL" then
        self:setAmount(self:available())
        return
    end
    self:setAmount(tonumber(code) or 0)
end

-- Not clamped as it is typed, for the reason the machine's amount screen gives: an account
-- holding $5 has to be able to accept the "5" in "50". The panel goes red and Send refuses.
function TC_TransferWindow:onAmountTyped()
    self.amount = math.max(0, math.floor(tonumber(self.amountEntry:getInternalText()) or 0))
end

function TC_TransferWindow:onCancel()
    self:close()
end

function TC_TransferWindow:onSend()
    local tail = self:tail()
    if not tail then
        self:setMessage(getText("IGUI_TC_BankBadTail"), true)
        return
    end

    local ok, result = TC.bankTransfer(self.player, self.accountNumber, tail, self.amount)
    if not ok then
        self:setMessage(result or getText("IGUI_TC_BankBadAmount"), true)
        return
    end

    TC.playSound(self.player, "cash")

    local sent = self.amount
    self:setAmount(0)

    --[[ The machine behind this window is showing the balance that just changed, so it has
         to be told. Reaching for the window rather than calling a shared refresh because
         there is exactly one of it and it may have been closed underneath us. ]]
    local atm = TC_ATMWindow and TC_ATMWindow.instances[self.playerNum]
    if atm then
        atm:refreshStatement()
        atm:setMessage(getText("IGUI_TC_BankSent", sent, TC.cardTail(result.number)), false)
    end

    self:setMessage(getText("IGUI_TC_BankSent", sent, TC.cardTail(result.number)), false)
end

-- ---------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------

function TC_TransferWindow:statLine(left, right, y, label, value, font, r, g, b)
    font = font or UIFont.Small
    local h  = getTextManager():getFontHeight(font)
    local vw = getTextManager():MeasureStringX(font, value)

    self:drawText(label, left, y + math.floor((h - FONT_HGT_SMALL) / 2),
                  0.68, 0.68, 0.72, 1, UIFont.Small)
    self:drawText(value, right - vw, y, r or 0.92, g or 0.92, b or 0.95, 1, font)

    return y + math.max(h, FONT_HGT_SMALL) + LINE_GAP
end

--[[ What the destination field currently resolves to, as a line of text and a colour.

     THIS IS THE POINT OF THE SCREEN. Four digits is a short address and a mistyped one is
     a real transfer to the wrong place, so the machine says what it has understood before
     the button is pressed rather than after: which account, or that no account ends in
     those digits, or that it is your own. ]]
function TC_TransferWindow:destinationLine()
    local tail = self:tail()
    if not tail then
        return getText("IGUI_TC_BankTailHint"), 0.55, 0.55, 0.6
    end

    local to, ambiguous = TC.accountByTail(self.player, tail)
    if ambiguous then return getText("IGUI_TC_BankTailAmbiguous", tail), 1, 0.35, 0.35 end
    if not to     then return getText("IGUI_TC_BankNoSuchAccount", tail), 1, 0.35, 0.35 end

    if to.number == self.accountNumber then
        return getText("IGUI_TC_BankSameAccount"), 1, 0.35, 0.35
    end

    return to.number, 0.66, 0.94, 0.66
end

--[[ Everything Send needs to be true, asked in one place so the button and the click agree.
     TC.bankTransfer checks all of it again -- it has to, it is the thing that moves money
     -- and this is what stops the player finding out by being refused. ]]
function TC_TransferWindow:canSend()
    if self.amount <= 0 or self.amount > self:available() then return false end

    local tail = self:tail()
    if not tail then return false end

    local to, ambiguous = TC.accountByTail(self.player, tail)
    if ambiguous or not to or to.number == self.accountNumber then return false end
    return true
end

function TC_TransferWindow:prerender()
    ISCollapsableWindow.prerender(self)

    --[[ This window belongs to a session at a machine, not to the character. When the
         machine closes -- walked away, card put down, Done pressed -- there is nothing
         left for it to be about. ]]
    local atm = TC_ATMWindow and TC_ATMWindow.instances[self.playerNum]
    if not atm or atm.accountNumber ~= self.accountNumber then
        self:close()
        return
    end

    local L     = self:layout()
    local left  = L.x + PAD
    local right = L.x + L.w - PAD
    local avail = self:available()

    self:drawRect(L.x, L.panelY, L.w, L.panelH, 0.45, 0, 0, 0)
    self:drawRectBorder(L.x, L.panelY, L.w, L.panelH, 0.5, 0.4, 0.4, 0.4)

    local y = L.panelY + PAD
    y = self:statLine(left, right, y, getText("IGUI_TC_BankFromAccount"),
                      TC.truncate(UIFont.Small, self.accountNumber or "?", L.w / 2),
                      UIFont.Small, 0.72, 0.72, 0.76)

    local over = self.amount > avail
    if over then
        y = self:statLine(left, right, y, getText("IGUI_TC_BankAmount"),
                          "$" .. self.amount, UIFont.Large, 1, 0.35, 0.35)
    else
        y = self:statLine(left, right, y, getText("IGUI_TC_BankAmount"),
                          "$" .. self.amount, UIFont.Large, 0.78, 0.98, 0.78)
    end

    self:statLine(left, right, y, getText("IGUI_TC_BankBalanceAfter"),
                  "$" .. (avail - self.amount), UIFont.Small, 0.72, 0.72, 0.76)

    -- The two field labels, each in front of its own box.
    local lw = self:labelWidth()
    self:drawText(getText("IGUI_TC_BankToAccount"), L.x,
                  L.toY + (BUTTON_HGT - FONT_HGT_SMALL) / 2, 0.68, 0.68, 0.72, 1, UIFont.Small)
    self:drawText(getText("IGUI_TC_BankCustom"), L.x,
                  L.entryY + (BUTTON_HGT - FONT_HGT_SMALL) / 2, 0.68, 0.68, 0.72, 1, UIFont.Small)

    -- What those four digits resolve to, beside the field they were typed into.
    local text, r, g, b = self:destinationLine()
    local textX = L.x + lw + self.toEntry:getWidth() + PAD
    self:drawText(TC.truncate(UIFont.Small, text, L.x + L.w - textX),
                  textX, L.toY + (BUTTON_HGT - FONT_HGT_SMALL) / 2, r, g, b, 1, UIFont.Small)

    for _, btn in ipairs(self.quickBtns) do
        if btn.internal == "ALL" then
            btn:setEnable(avail > 0)
        else
            btn:setEnable((tonumber(btn.internal) or 0) <= avail)
        end
    end
    self.sendBtn:setEnable(self:canSend())

    local msgText, msgErr = self:activeMessage()
    if msgText then
        local mr, mg, mb = 0.6, 1, 0.6
        if msgErr then mr, mg, mb = 1, 0.3, 0.3 end

        local lines = TC.wrapText(UIFont.Small, msgText, L.w)
        local shown = math.min(#lines, MSG_LINES)
        if #lines > MSG_LINES then
            lines[shown] = TC.truncate(UIFont.Small, lines[shown] .. "...", L.w)
        end

        local my = L.msgY + L.msgH - shown * FONT_HGT_SMALL - (shown - 1) * MSG_LEADING
        for i = 1, shown do
            TC.drawCentred(self, lines[i], L.x, L.w, my, UIFont.Small, mr, mg, mb)
            my = my + FONT_HGT_SMALL + MSG_LEADING
        end
    end
end

function TC_TransferWindow:onResize()
    ISCollapsableWindow.onResize(self)
    self:layoutWidgets()
end

function TC_TransferWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    TC_TransferWindow.instances[self.playerNum] = nil
end

TC.applyMessageBehaviour(TC_TransferWindow)

--[[ Beside the machine, not on top of it -- the cart's docking rule and its reasoning.

     The whole point of this being its own window is that the balance being spent from is
     still visible while the figure is typed. Opening it centred would put it over the
     account screen and give that up. To the right of the machine, or to the left when
     there is no room on the right. ]]
local function dockPosition(playerNum, w, h)
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local GAP = 8

    local frame = TC_ATMWindow and TC_ATMWindow.instances[playerNum]
    if not frame then return (sw - w) / 2, (sh - h) / 2 end

    local x = frame.x + frame.width + GAP
    if x + w > sw then x = frame.x - w - GAP end
    x = math.max(0, math.min(x, sw - w))

    return x, math.max(0, math.min(frame.y, sh - h))
end

function TC.openTransferWindow(playerNum, accountNumber)
    if not accountNumber then return nil end

    local existing = TC_TransferWindow.instances[playerNum]
    if existing then
        existing.accountNumber = accountNumber
        existing:setVisible(true)
        existing:bringToTop()
        return existing
    end

    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()
    local w = math.min(520, sw - 80)
    local h = math.min(440, sh - 80)
    local x, y = dockPosition(playerNum, w, h)

    local win = TC_TransferWindow:new(x, y, w, h, playerNum, accountNumber)
    win:initialise(); win:instantiate()
    win:setTitle(getText("IGUI_TC_TransferTitle"))
    win:addToUIManager()
    TC_TransferWindow.instances[playerNum] = win
    return win
end

--[[ Open it if it is shut, shut it if it is open. A toggle rather than an open, for the
     same reason the cart's rail entry is one: once the window is docked beside the machine,
     the button that opened it is the only obvious way to get the space back. ]]
function TC.toggleTransferWindow(playerNum, accountNumber)
    local existing = TC_TransferWindow.instances[playerNum]
    if existing then
        existing:close()
        return nil
    end
    return TC.openTransferWindow(playerNum, accountNumber)
end
