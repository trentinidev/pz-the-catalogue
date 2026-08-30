--[[ The Catalogue -- doing something to the machine instead of to the card.

     Two more ways into money, and neither of them involves knowing a PIN. They are the
     other half of the answer to "I found a card and I cannot get in", and they are
     deliberately about the MACHINE rather than the plastic, so that a player who has
     invested in a skill or is willing to make a lot of noise has a route that examining
     cards will never give them.

     WIRE THE READER (Electricity, a screwdriver)
     -------------------------------------------
     Open the housing and put a wire across the card reader, so it stops asking. The
     machine then takes ANY card without a PIN -- for a while, and only that machine.

     It is per-ATM and it expires, and both of those are load-bearing. A permanent bypass
     would be a switch the player flips once and never thinks about again; one that
     followed the player would make the machine irrelevant. What this actually buys is a
     PLACE: for the next few hours there is an ATM in Rosewood that will take anything you
     put in it, and everything in your bag that you cannot open is suddenly worth carrying
     there. That is a reason to remember a location, which is the scarcest thing a mod can
     give this game.

     Electricity decides how long it takes and whether it works at all. Level 3 is the
     floor -- below that you are looking at a circuit board you do not understand.

     FORCE THE CASHBOX (a crowbar or a sledgehammer)
     -----------------------------------------------
     No cards, no accounts, no PINs: physical money out of a physical box. It is loud, it
     takes a long time, and the machine is finished afterwards -- for everyone, including
     the accounts you were going to use it for.

     THE HAUL IS NOT AN ACCOUNT BALANCE. It is what a cash machine had in it, which is
     nothing to do with whose card you are carrying, and it can only be done once per
     machine ever. Otherwise this is a money printer with a two-minute cooldown.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

require "TimedActions/ISBaseTimedAction"

--[[ Wiring the reader.

     ELEC_MIN is where the game's own electrical gates sit for anything non-trivial, and
     the time falls away as the skill climbs: level 3 is two minutes of fiddling, level 10
     is under a minute. BYPASS_HOURS is how long the machine stays open afterwards. ]]
-- Read by the context menu to grey the entry out, so the requirement is stated in one
-- place and cannot drift between the menu and the action.
TC.ATM_ELEC_MIN = 3
local ELEC_MIN  = TC.ATM_ELEC_MIN
local WIRE_SECONDS  = 150
local BYPASS_HOURS  = 6

--[[ Forcing the box. Slow and loud on purpose: this is a person hitting a steel cabinet
     in an empty street. The radius is roughly what a gunshot does not reach and a window
     breaking does. ]]
local FORCE_SECONDS = 100
local FORCE_NOISE   = 30

--[[ What is actually in a machine, in weighted bands, the same shape TC_WorldCards rolls a
     balance in and for the same reason: a flat range makes every ATM identical and the
     average one absurd. Most have been emptied by somebody already. ]]
local HAUL = {
    { weight = 35, min = 0,    max = 0    },   -- already done over, or empty
    { weight = 35, min = 20,   max = 300  },
    { weight = 22, min = 300,  max = 1200 },
    { weight = 8,  min = 1200, max = 3000 },
}

local function rollHaul()
    local total = 0
    for _, band in ipairs(HAUL) do total = total + band.weight end

    local roll = ZombRand(total)
    for _, band in ipairs(HAUL) do
        if roll < band.weight then
            if band.max == 0 then return 0 end
            return band.min + ZombRand(band.max - band.min + 1)
        end
        roll = roll - band.weight
    end
    return 0
end

-- ---------------------------------------------------------------------------
-- What has been done to which machine
-- ---------------------------------------------------------------------------

--[[ Machines are identified by their square, because a tile IS its coordinates and an
     IsoObject reference does not survive the chunk being unloaded and streamed back in.
     Stored in the world register beside the stranger's accounts, so it persists. ]]
local function atmKey(atm)
    local square = atm and atm:getSquare()
    if not square then return nil end
    return string.format("%d,%d,%d", square:getX(), square:getY(), square:getZ())
end

local function machines()
    local world = TC.worldBank()
    if type(world.atms) ~= "table" then world.atms = {} end
    return world.atms
end

local function worldHours()
    local gt = getGameTime()
    if not gt then return 0 end
    return gt:getWorldAgeHours()
end

local function record(atm)
    local key = atmKey(atm)
    if not key then return nil end

    local all = machines()
    if type(all[key]) ~= "table" then all[key] = {} end
    return all[key]
end

--[[ Is this machine currently wired to skip the PIN? Read by the ATM window. ]]
function TC.atmBypassed(atm)
    local rec = record(atm)
    if not rec or type(rec.bypassUntil) ~= "number" then return false end
    return rec.bypassUntil > worldHours()
end

--[[ Has this machine already been forced open? A broken ATM is broken for good. ]]
function TC.atmBroken(atm)
    local rec = record(atm)
    return rec ~= nil and rec.broken == true
end

-- ---------------------------------------------------------------------------
-- Wiring the reader
-- ---------------------------------------------------------------------------

TC_WireATMAction = ISBaseTimedAction:derive("TC_WireATMAction")

function TC_WireATMAction:isValid()
    return self.atm ~= nil and self.atm:getSquare() ~= nil and not TC.atmBroken(self.atm)
end

function TC_WireATMAction:waitToStart()
    self.character:faceThisObject(self.atm)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_WireATMAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_WireATMAction:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function TC_WireATMAction:perform()
    local rec = record(self.atm)
    if rec then
        rec.bypassUntil = worldHours() + BYPASS_HOURS
        HaloTextHelper.addGoodText(self.character,
            getText("IGUI_TC_ATMWired", BYPASS_HOURS))

        --[[ Electricity XP, because this IS electrical work and a system that asks for a
             skill and never feeds it is a system that punishes using it. The figure is
             modest: it is one job, not a workbench. ]]
        self.character:getXp():AddXP(Perks.Electricity, 15)
    end

    ISBaseTimedAction.perform(self)
end

function TC_WireATMAction:new(character, atm)
    local o = ISBaseTimedAction.new(self, character)
    o.atm = atm
    o.stopOnWalk = true
    o.stopOnRun  = true

    -- Faster the more you know. Level 3 is the floor and takes the full time; level 10
    -- takes about a third of it.
    local level = character:getPerkLevel(Perks.Electricity)
    local scale = 1 - math.min(0.65, (level - ELEC_MIN) * 0.09)
    o.maxTime = math.floor(WIRE_SECONDS * 60 * scale)
    return o
end

-- ---------------------------------------------------------------------------
-- Forcing the cashbox
-- ---------------------------------------------------------------------------

TC_ForceATMAction = ISBaseTimedAction:derive("TC_ForceATMAction")

function TC_ForceATMAction:isValid()
    return self.atm ~= nil and self.atm:getSquare() ~= nil and not TC.atmBroken(self.atm)
end

function TC_ForceATMAction:waitToStart()
    self.character:faceThisObject(self.atm)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_ForceATMAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

--[[ Noise, made repeatedly rather than once at the end.

     A single sound when the box finally opens would mean the horde arrives after the
     player has the money, which is a story with no decision in it. Made every second or
     so, the player gets to hear it building and choose whether to keep going. ]]
function TC_ForceATMAction:update()
    self.character:setMetabolicTarget(Metabolics.HeavyWork)

    if (self:getJobDelta() * FORCE_SECONDS) - (self.lastNoise or -1) >= 1 then
        self.lastNoise = self:getJobDelta() * FORCE_SECONDS
        local square = self.atm:getSquare()
        if square then
            addSound(self.character, square:getX(), square:getY(), square:getZ(),
                     FORCE_NOISE, FORCE_NOISE)
        end
    end
end

function TC_ForceATMAction:perform()
    local rec = record(self.atm)

    if rec and not rec.broken then
        rec.broken = true

        local haul = rollHaul()
        if haul > 0 then
            TC.giveCash(self.character, haul)
            HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_ATMForced", haul))
        else
            HaloTextHelper.addBadText(self.character, getText("IGUI_TC_ATMForcedEmpty"))
        end
    end

    ISBaseTimedAction.perform(self)
end

function TC_ForceATMAction:new(character, atm)
    local o = ISBaseTimedAction.new(self, character)
    o.atm = atm
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime = FORCE_SECONDS * 60
    return o
end

-- ---------------------------------------------------------------------------
-- Requirements, asked once so the menu and the action agree
-- ---------------------------------------------------------------------------

--[[ Something to open a housing with.

     ItemTag.SCREWDRIVER, NOT THE STRING "Screwdriver". getFirstTagRecurse is a Java method
     that takes an ItemTag enum, and Kahlua will not coerce a string into one -- it throws
     `expected argument of type ItemTag, got String`, which is precisely what it did every
     time somebody right-clicked a cash machine. The tag is still the right thing to ask
     for: it picks up a screwdriver another mod adds without this file knowing about it.

     The type lookup stays as a fallback for anything that is a screwdriver without
     carrying the tag, and the whole thing is wrapped because a nil ItemTag constant on
     some future build should cost the menu an option, not the menu. ]]
function TC.findScrewdriver(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local ok, item = pcall(function()
        return inv:getFirstTagRecurse(ItemTag.SCREWDRIVER)
    end)
    if ok and item then return item end

    return inv:getFirstTypeRecurse("Screwdriver")
end

--[[ Something to hit a steel cabinet with. A crowbar is the obvious one; a sledgehammer
     is faster in fiction and the same here, because the action's length is about the
     cabinet rather than about the tool. ]]
function TC.findPryBar(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    -- Bare types, not module-prefixed. getFirstTypeRecurse answers on the short name, and
    -- the prefixed form is what quietly returned nothing here for a bag with a crowbar in
    -- it -- the same trap findScrewdriver was in one line above.
    for _, t in ipairs({ "Crowbar", "Sledgehammer", "SledgeHammer" }) do
        local item = inv:getFirstTypeRecurse(t)
        if item then return item end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Cloning the machine's software
-- ---------------------------------------------------------------------------

--[[ Copying a cash machine's operating system onto a blank disc.

     THE MACHINE HAS TO BE WRECKED FIRST, and that is the price rather than an obstacle.
     Forcing the cashbox takes an ATM out of the world permanently -- for this player and
     for anybody else, and for every account they were going to reach through it -- and
     only once the cabinet is open is the board inside reachable at all. So an internet
     banking disc costs one cash machine, and Knox County has a finite number of them.

     It also gives a forced machine a second life. Until now a wrecked ATM was a dead end
     with a tooltip on it; it is now the only place in the game this disc can be made.

     ELECTRICITY 5, a step above the 3 that wires a reader or builds a card reader. Pulling
     the software out of a bank's own board should be the most advanced thing this mod asks
     for, and the skill is what separates a player who invested from one who found the
     parts.
]]
TC.CLONE_ELEC_MIN = 5

local CLONE_SECONDS = 210

TC_CloneATMAction = ISBaseTimedAction:derive("TC_CloneATMAction")

function TC_CloneATMAction:isValid()
    return self.atm ~= nil
       and self.atm:getSquare() ~= nil
       and TC.atmBroken(self.atm)
       and TC.findBlankDisc(self.character) ~= nil
end

function TC_CloneATMAction:waitToStart()
    self.character:faceThisObject(self.atm)
    return self.character:isTurning() or self.character:shouldBeTurning()
end

function TC_CloneATMAction:start()
    self:setActionAnim(CharacterActionAnims.Craft)
end

function TC_CloneATMAction:update()
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

--[[ The blank disc is looked up again rather than carried from the menu: three and a half
     minutes have passed, and that is long enough to have put it down. ]]
function TC_CloneATMAction:perform()
    local blank = TC.findBlankDisc(self.character)

    if blank then
        TC.removeItem(blank)

        local disc = self.character:getInventory():AddItem("Catalogue.BankingCD")
        if disc then
            HaloTextHelper.addGoodText(self.character, getText("IGUI_TC_ATMCloned"))
            self.character:getXp():AddXP(Perks.Electricity, 25)
        else
            TC.warn("could not create Catalogue.BankingCD -- the disc was lost")
        end
    end

    ISBaseTimedAction.perform(self)
end

function TC_CloneATMAction:new(character, atm)
    local o = ISBaseTimedAction.new(self, character)
    o.atm = atm
    o.stopOnWalk = true
    o.stopOnRun  = true

    -- Faster the more you know, from the floor of 5 upwards.
    local level = character:getPerkLevel(Perks.Electricity)
    local scale = 1 - math.min(0.5, (level - TC.CLONE_ELEC_MIN) * 0.1)
    o.maxTime = math.floor(CLONE_SECONDS * 60 * scale)
    return o
end

--[[ A blank disc on the player, of either spelling.

     Both, because this mod has guessed wrong twice about whether getAllTypeRecurse wants
     the module prefix. See TC.cardItemsOn. ]]
function TC.findBlankDisc(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    for _, t in ipairs({ "BlankCD", "Catalogue.BlankCD" }) do
        local item = inv:getFirstTypeRecurse(t)
        if item then return item end
    end
    return nil
end
