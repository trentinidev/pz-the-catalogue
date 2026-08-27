--[[ The Catalogue -- where a Shop Catalogue turns up in the world.

     Crafting one from a notebook is a good fallback, but it says nothing about there
     having BEEN a mail-order company in Knox County. Finding one in a post office
     sorting rack, on an office desk, or in the magazine rack of somebody's living room
     is what makes the company feel like it existed before the outbreak.

     Weights below are relative to everything else already in each container, so they
     are read as "roughly this rare compared to its neighbours". They are deliberately
     low: the catalogue should be a find, not litter. The sandbox multiplier scales all
     of them together, and setting it to 0 removes the item from loot entirely and
     leaves crafting as the only route.
]]

require 'Items/ProceduralDistributions'

local CATALOGUE = "Catalogue.Catalogue"

local function rate()
    local vars = SandboxVars and SandboxVars.TheCatalogue
    local m = vars and vars.CatalogueLootMultiplier
    if type(m) ~= "number" then m = 1.0 end
    return m
end

--[[ Where it makes sense to find one, and how common it is there.

     A post office is the obvious home -- that is where the catalogues were mailed
     from. Offices and desks are next: somebody ordered stationery from one. Living
     rooms and magazine racks are the domestic case, a catalogue left on the coffee
     table. Bookstores and libraries stock them thinly because they are not really
     books, and a general-purpose crate of magazines gets the lowest weight of all. ]]
local PLACES = {
    { "PostOfficeMagazines",   4.0 },
    { "MagazineRackBrochure",  3.0 },
    { "DeskGeneric",           1.5 },
    { "OfficeDesk",            1.5 },
    { "MagazineRackMixed",     2.0 },
    { "MagazineRackFancy",     1.5 },
    { "LivingRoomShelf",       1.0 },
    { "LivingRoomShelfNoTapes",1.0 },
    { "CafeShelfBooks",        0.8 },
    { "LibraryMagazines",      0.8 },
    { "CrateMagazines",        0.6 },
    { "ClosetShelfGeneric",    0.5 },
}

local multiplier = rate()

if multiplier > 0 then
    local added, missing = 0, 0

    for _, place in ipairs(PLACES) do
        local name, weight = place[1], place[2]
        local list = ProceduralDistributions.list[name]

        -- A container name can disappear between builds, and a mod can replace the
        -- whole table. Skipping quietly beats erroring out of the file and losing
        -- every remaining entry.
        if list and list.items then
            -- The items array is flat pairs: fullType, weight, fullType, weight...
            table.insert(list.items, CATALOGUE)
            table.insert(list.items, weight * multiplier)
            added = added + 1
        else
            missing = missing + 1
        end
    end

    print(string.format("[TheCatalogue] catalogue added to %d loot containers (%d unknown, x%.2f)",
                        added, missing, multiplier))
else
    print("[TheCatalogue] catalogue loot spawning disabled by sandbox option")
end
