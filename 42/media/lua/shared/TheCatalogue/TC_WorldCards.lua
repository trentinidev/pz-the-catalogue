--[[ The Catalogue -- the cards that belonged to somebody else.

     Knox County had banks before it had zombies, and the people in it had cards. This file
     gives every `CreditCard` the world spawns an owner, an account number and a balance,
     so that the one you pull out of a dead man's wallet is a real account with real money
     in it that you cannot get at, rather than a dollar's worth of junk plastic.

     NO NEW DISTRIBUTION. Vanilla already scatters CreditCard exactly where a credit card
     would be -- wallets, office desks, bedroom closets, bins, and the Outfit_Gaudy zombies
     wear -- and the Indie Stone put more thought into that list than a mod should try to
     improve on. What was missing was not cards in the world; it was cards MEANING anything.

     THE ACCOUNTS LIVE IN THE WORLD, NOT ON THE CHARACTER. A stranger's account is not
     yours and does not belong on your save data, so it goes in ModData.getOrCreate, which
     is the game's global, per-world, persists-across-quit table. Your own accounts stay
     where they were, on the character. TC.account looks in both, which is what lets one
     machine screen deal in either.

     THE FOUR DIGITS ARE UNIQUE ACROSS THE WHOLE WORLD, which is what makes them an address
     you can type at a machine -- and it is also the sharp constraint here, because there
     are only 9,999 of them. See TC.reserveTail for what that costs and why it never
     actually runs out in a real save.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

local WORLD_KEY = "TheCatalogue_World"

--[[ How much is in a stranger's account.

     WEIGHTED, NOT FLAT. A flat roll between $1 and $10,000 makes the average wallet worth
     five thousand dollars, every card the same size, and finding one boring by the third.
     Most people in 1993 Kentucky had a couple of hundred dollars in checking; a few had
     real money; almost nobody had ten thousand. So the roll picks a BAND first and then a
     figure inside it, which is what gives the tail its length: half of all cards are petty
     cash, and the one in twenty that is not is worth the walk to a machine.

     The bands are also why the top of the range is worth having at all. $10,000 is a
     hundred MoneyBundles and fifty kilos if you take it out in notes -- an amount the rest
     of the mod already has an opinion about. ]]
local BANDS = {
    { weight = 50, min = 1,    max = 200   },   -- pocket change, most cards
    { weight = 30, min = 200,  max = 1500  },   -- an ordinary current account
    { weight = 15, min = 1500, max = 5000  },   -- someone comfortable
    { weight = 5,  min = 5000, max = 10000 },   -- the one in twenty worth finding
}

local function rollBalance()
    local total = 0
    for _, band in ipairs(BANDS) do total = total + band.weight end

    local roll = ZombRand(total)
    for _, band in ipairs(BANDS) do
        if roll < band.weight then
            return band.min + ZombRand(band.max - band.min + 1)
        end
        roll = roll - band.weight
    end
    return 1
end

--[[ Fallback names, used only when the game's own survivor factory will not answer.

     Deliberately short and deliberately period-plausible. SurvivorFactory is the right
     source -- it is the same pool the game names its own characters from, so a looted card
     reads like it belonged to somebody who lived here -- but it is Java, it is called from
     a context the mod does not control, and a name is not worth throwing over. ]]
local FALLBACK_FORE = { "James", "Mary", "Robert", "Patricia", "John", "Jennifer",
                        "Michael", "Linda", "David", "Barbara", "Rose", "Frank" }
local FALLBACK_SUR  = { "Smith", "Johnson", "Williams", "Jones", "Brown", "Davis",
                        "Miller", "Wilson", "Moore", "Taylor" }

local function pick(list) return list[ZombRand(#list) + 1] end

--[[ A name for the person whose card this was.

     SurvivorFactory.CreateSurvivor is what the game itself uses to name a character, so
     the pool is the game's own and the result sits alongside vanilla naming rather than
     beside it. Wrapped in pcall and backed by the lists above, because this runs while
     loot is being generated and a card is not worth an error in that path. ]]
local function rollHolder()
    local ok, name = pcall(function()
        local desc = SurvivorFactory.CreateSurvivor()
        if not desc then return nil end

        local fore = desc:getForename() or ""
        local sur  = desc:getSurname() or ""
        if fore == "" and sur == "" then return nil end
        if sur == "" then return fore end
        if fore == "" then return sur end
        return fore .. " " .. sur
    end)

    if ok and type(name) == "string" and name ~= "" then return name end
    return pick(FALLBACK_FORE) .. " " .. pick(FALLBACK_SUR)
end

-- ---------------------------------------------------------------------------
-- The world's register
-- ---------------------------------------------------------------------------

--[[ The per-world table: every stranger's account, and every account tail spoken for.

     ModData.getOrCreate is the game's own global store -- one per save, written into it,
     alive across a quit. The same call returns the same table however many times it is
     made, so this is cheap to call from anywhere. ]]
function TC.worldBank()
    local md = ModData.getOrCreate(WORLD_KEY)
    if type(md.accounts) ~= "table" then md.accounts = {} end
    if type(md.tails)    ~= "table" then md.tails    = {} end
    return md
end

--[[ Claim a set of last-four digits that nothing in this world has used, and return the
     full sixteen-digit number built around it.

     ONE REGISTER FOR EVERY ACCOUNT IN THE SAVE, the player's own included. The tail is the
     address a transfer is typed at, and an address that two accounts can answer to is not
     an address -- so uniqueness cannot be per-character or per-source, it has to be per
     world, which is why this lives here and why TC.openAccount comes through it too.

     THERE ARE ONLY 9,999 OF THEM. That is a real ceiling and it is worth being honest
     about: a world that named a card the moment one spawned would burn through it, because
     vanilla scatters CreditCard across thousands of containers in a map this size. Naming
     is LAZY instead -- a card gets an identity the first time the mod actually looks at
     one, which means only the cards a player has picked up ever cost a number. A long save
     might use a few dozen.

     If the register ever does fill up, this returns nil and the card stays what it was: an
     unremarkable piece of plastic worth a dollar. Degrading into vanilla beats inventing a
     duplicate address. ]]
function TC.reserveTail()
    local world = TC.worldBank()

    for _ = 1, 64 do
        local groups = {}
        for i = 1, 4 do
            groups[i] = string.format("%04d", ZombRand(10000))
        end

        local number = table.concat(groups, " ")
        local tail   = TC.cardTail(number)

        if not world.tails[tail] then
            world.tails[tail] = true
            return number
        end
    end

    TC.warn("every four-digit account tail in this world is taken -- card left unnamed")
    return nil
end

--[[ A stranger's account by number, or nil. The other half of TC.account. ]]
function TC.worldAccount(number)
    if not number then return nil end
    return TC.worldBank().accounts[number]
end

-- ---------------------------------------------------------------------------
-- Naming a card the world spawned
-- ---------------------------------------------------------------------------

--[[ Is this item a credit card of any kind?

     Both vanilla spellings. CreditCard_Stolen is included on purpose -- a stolen card is
     the most thematically apt thing in this whole file to find in a wallet that is not
     yours, and mechanically it is the same object. ]]
function TC.isCardItem(item)
    if not item then return false end
    local t = item:getFullType()
    return t == TC.CARD_ITEM or t == "Base.CreditCard_Stolen"
end

--[[ Give an unclaimed card an owner, an account and a balance.

     Returns the account, or nil if the card already had one or could not be given a
     number. Idempotent by way of that first check, which matters because this is called
     from more than one place and cards get looked at repeatedly.

     THE PIN IS SET AND NOT WRITTEN DOWN ANYWHERE. That is the whole shape of the feature:
     the account is real, the money is real, and the four digits between you and it belonged
     to somebody who is not going to tell you. ]]
function TC.blessCard(item)
    if not TC.isCardItem(item) then return nil end
    if TC.isBankCard(item) then return nil end

    local number = TC.reserveTail()
    if not number then return nil end

    local acct = {
        number  = number,
        holder  = rollHolder(),
        pin     = string.format("%04d", ZombRand(10000)),
        balance = rollBalance(),
        opened  = TC.gameStamp(),
        seq     = 0,
        entries = {},
        -- Marks an account the player did not open. Nothing reads it to decide access --
        -- the card and the PIN do that -- but it is what tells a future feature, and a
        -- future reader of a save file, that this money was somebody else's.
        foreign = true,
    }

    TC.worldBank().accounts[number] = acct

    local md = item:getModData()
    md.TC_account = number
    md.TC_holder  = acct.holder

    TC.nameCard(item, acct)
    return acct
end

--[[ Walk a container and name every card in it, nested containers included.

     Wallets are the point of the recursion: vanilla's own distribution puts CreditCard
     inside a wallet and the wallet inside a bag, and a card that only got its identity
     when it was loose would be the one card the feature missed. The depth guard is the
     one TC.ownedTypes uses, and for the same reason. ]]
function TC.blessContainer(container, guard)
    guard = (guard or 0) + 1
    if guard > 8 or not container then return 0 end

    local n = 0
    local items = container:getItems()
    if not items then return 0 end

    for i = 0, items:size() - 1 do
        local item = items:get(i)

        if TC.isCardItem(item) then
            if TC.blessCard(item) then n = n + 1 end
        else
            local inner = TC.contentsOf(item)
            if inner then n = n + TC.blessContainer(inner, guard) end
        end
    end

    return n
end
