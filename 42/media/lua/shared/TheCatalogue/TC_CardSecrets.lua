--[[ The Catalogue -- getting into an account that was not yours.

     A stranger's card is a real account with real money and four digits in the way. This
     file is everything about those four digits: how they are chosen, what the world knows
     about them, and what the machine does to somebody guessing.

     THE PROBLEM IS 10,000 AND THE ANSWER IS NEVER "GUESS". Ten thousand combinations
     against three tries a day is not a puzzle, it is a wall, so every route below exists
     to cut the number down to something a person can actually work through:

         the note        a scrap of paper with the number on it, in the wallet or
                         somewhere else in the building. Gives the PIN outright.
         the back        the owner wrote it on the card. Gives the PIN outright.
         the impression  the owner wrote it on the card IN PENCIL and rubbed it out.
                         Gives the four DIGITS with no order -- at most 24 arrangements,
                         and fewer when a digit repeats.
         a lazy PIN      one card in five uses 1234 or 0000 or a birth year, because one
                         person in five does. Costs nothing to try and rewards knowing.

     WHY THE IMPRESSION IS THE DEFAULT and the notes are the lucky break: a card that gave
     nothing at all would be a card the player learns to ignore, and one that always gave
     the PIN would make the lock decorative. Twenty-four arrangements at three tries a day
     is about four days of walking back to a machine -- real work for a real amount of
     money, and the notes are what occasionally spare you it.

     TRIES AND THE LOCKOUT LIVE ON THE ACCOUNT, not on the window. A player who closes the
     machine and reopens it has not earned three more guesses, and one who walks to a
     different ATM in a different town has not either -- it is the same card and the same
     bank. That is only true if the counter rides with the account, which is why it does.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

--[[ How many wrong PINs before the card stops being accepted, and for how long.

     Three tries and 24 game hours are the DEFAULTS, and both are sandbox options now --
     three because that is what a real machine gave you, 24 because the unit a player
     thinks in is "come back tomorrow".

     BURGLAR is expressed as a BONUS rather than as its own number.
     Two absolutes drift apart the moment somebody edits one of them, and the point of the
     trait here is "two more than everybody else" -- which survives a player setting the
     allowance to 1 or to 20. It is the most literal example of getting into things that
     are not yours the game has, and two extra guesses a day is the difference between four
     days of work and two and a half. ]]
TC.PIN_TRIES_BURGLAR_BONUS = 2

--[[ The PINs people actually chose.

     One card in five, and the list is the real one: sequences, repeats, the corners of the
     keypad, and years somebody was born in. It costs a player nothing to try 1234 on every
     card they find, and the day it works it feels like they knew something rather than
     like the game gave them a present. ]]
local LAZY_CHANCE = 20      -- percent
local LAZY_PINS = {
    "1234", "0000", "1111", "4321", "1212", "2580", "1004", "2222",
    "1990", "1985", "1969", "1977", "1966", "1959", "7777", "9999",
}

--[[ What a given card gives up when you look at it closely.

     MOST CARDS GIVE NOTHING, and that is the correction that matters. The first cut had no
     "nothing" at all: every card in the county carried either the number or the digits, so
     examining was a button that always paid and the only question was how much. A search
     that always succeeds is not a search.

     Half give nothing now. One in twelve is written on, one in five carries the pencil
     impression, and about one in five has a note somewhere -- in the wallet or a drawer in
     the same building. So looking at a card is usually a waste of twelve seconds, which is
     what makes the times it is not worth something. ]]
local SECRETS = {
    { weight = 8,  kind = "back"    },   -- written on the card itself
    { weight = 12, kind = "note"    },   -- a scrap in the same container
    { weight = 10, kind = "house"   },   -- a scrap elsewhere in the building
    { weight = 20, kind = "worn"    },   -- a pencil impression: the digits, no order
    { weight = 50, kind = "nothing" },   -- a card, and nothing else
}

local function rollWeighted(list)
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.weight end

    local roll = ZombRand(total)
    for _, entry in ipairs(list) do
        if roll < entry.weight then return entry end
        roll = roll - entry.weight
    end
    return list[#list]
end

-- ---------------------------------------------------------------------------
-- Choosing the secret
-- ---------------------------------------------------------------------------

--[[ A PIN for somebody who is not the player. One in five is lazy; see LAZY_PINS. ]]
function TC.rollForeignPin()
    if ZombRand(100) < LAZY_CHANCE then
        return LAZY_PINS[ZombRand(#LAZY_PINS) + 1]
    end
    return string.format("%04d", ZombRand(10000))
end

function TC.rollCardSecret()
    return rollWeighted(SECRETS).kind
end

-- ---------------------------------------------------------------------------
-- What the player knows
-- ---------------------------------------------------------------------------

--[[ The knowledge block on an account, created on demand.

     Kept on the account rather than on the card item, because it is knowledge about the
     ACCOUNT: putting the card down in a crate and picking it up again should not make you
     forget what you read on it. ]]
function TC.cardKnown(acct)
    if not acct then return nil end
    if type(acct.known) ~= "table" then
        acct.known = { pin = false, digits = false, examined = false }
    end
    return acct.known
end

function TC.knowsPin(acct)
    local k = TC.cardKnown(acct)
    return k ~= nil and k.pin == true
end

function TC.knowsDigits(acct)
    local k = TC.cardKnown(acct)
    return k ~= nil and k.digits == true
end

function TC.revealPin(acct)
    local k = TC.cardKnown(acct)
    if not k then return false end
    if k.pin then return false end

    k.pin    = true
    k.digits = true          -- knowing the number obviously includes knowing the digits
    return true
end

function TC.revealDigits(acct)
    local k = TC.cardKnown(acct)
    if not k then return false end
    if k.digits then return false end

    k.digits = true
    return true
end

--[[ The four digits of the PIN, sorted, as a display string: "1 2 4 7".

     SORTED IS THE WHOLE POINT. An impression in plastic says which numbers were pressed,
     never in what order, so handing them back in their real order would give away the
     thing the player is supposed to work out. Sorting is what guarantees no accident of
     implementation leaks it -- there is no code path where these come out in PIN order,
     because they are never in PIN order after this function. ]]
function TC.pinDigits(acct)
    if not acct or type(acct.pin) ~= "string" then return "" end

    local digits = {}
    for i = 1, #acct.pin do
        table.insert(digits, string.sub(acct.pin, i, i))
    end
    table.sort(digits)

    return table.concat(digits, " ")
end

-- ---------------------------------------------------------------------------
-- Tries, and being shut out
-- ---------------------------------------------------------------------------

--[[ The world clock in hours, which is what a lockout is measured against.

     getWorldAgeHours counts from the start of the save and never goes backwards, so it
     survives sleeping, a save and a reload, and does not care what the calendar says.
     Zero when there is no game time yet, which makes an unset lockout read as expired. ]]
local function worldHours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours()
end

--[[ How many wrong tries this player gets before the card shuts. See PIN_TRIES_BURGLAR. ]]
function TC.pinTriesFor(player)
    local tries = TC.opt("PinTries") or 3
    if player and player:hasTrait(CharacterTrait.BURGLAR) then
        return tries + TC.PIN_TRIES_BURGLAR_BONUS
    end
    return tries
end

--[[ Hours until this card will accept a PIN again, or 0 if it will now. ]]
function TC.lockedHours(acct)
    if not acct or type(acct.lockedUntil) ~= "number" then return 0 end

    local left = acct.lockedUntil - worldHours()
    if left <= 0 then return 0 end
    return left
end

function TC.isCardLocked(acct)
    return TC.lockedHours(acct) > 0
end

--[[ Count a wrong PIN, and shut the card when the allowance runs out.

     Returns how many tries are left, and true when this was the one that locked it.

     THE COUNTER RESETS WHEN THE LOCK LIFTS, not when the window closes -- otherwise
     reopening the machine would refill the allowance and the lockout would be a formality.
     It is reset by the successful path and by the expiry check below, and nowhere else. ]]
function TC.wrongPin(acct, player)
    if not acct then return 0, false end

    acct.tries = (acct.tries or 0) + 1
    local allowance = TC.pinTriesFor(player)

    if acct.tries >= allowance then
        acct.lockedUntil = worldHours() + (TC.opt("PinLockoutHours") or 24)
        acct.tries = 0
        return 0, true
    end

    return allowance - acct.tries, false
end

function TC.clearPinTries(acct)
    if not acct then return end
    acct.tries = 0
    acct.lockedUntil = nil
end
