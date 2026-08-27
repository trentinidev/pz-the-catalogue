--[[ The Catalogue -- what an item is MADE OF.

     The formula in TC_Prices.lua reads category and weight, and weight is the only
     magnitude it has. That makes it structurally blind to value density: a gold
     necklace weighs 0.1 and sits in the Accessory category, so it priced out at $4 --
     the same as a corkscrew, which is exactly right for the corkscrew and absurd for
     the necklace.

     The game already solves the identification problem for us. Vanilla tags precious
     items by material and by stone, because its own scrapping recipes need to know:
     base:tinygoldscrap, base:goldscrap, base:diamondjewellery, base:2rubyjewellery
     and so on. Those tags are a ready-made value signal.

     This table is GENERATED from those tags rather than read at runtime. ScriptItem
     exposes no getTags() we could rely on, and the tag set is fixed for a given build,
     so resolving it offline costs nothing at load and cannot fail on a missing method.
     Values are added ON TOP of the formula price, so a gold necklace set with a
     diamond is worth its gold plus its stone.

     Regenerate with tools/gen_materials.sh if the game's tags ever change.
]]

TheCatalogue = TheCatalogue or {}

--[[ Early-90s retail for the material itself, in dollars.

     Gold ran about $380/oz in 1993 and silver about $4.30, but jewellery never prices
     at melt value, so these lean on what the piece would have cost in a shop rather
     than on the metal ratio.
]]
TheCatalogue.MATERIAL_VALUES = {
    ["Base.BellyButton_DangleGold"] = 140,         -- tinygoldscrap
    ["Base.BellyButton_DangleGoldRuby"] = 400,     -- tinygoldscrap + rubyjewellery
    ["Base.BellyButton_DangleSilver"] = 30,        -- tinysilverscrap
    ["Base.BellyButton_DangleSilverDiamond"] = 530, -- tinysilverscrap + diamondjewellery
    ["Base.BellyButton_RingGold"] = 140,           -- tinygoldscrap
    ["Base.BellyButton_RingGoldDiamond"] = 640,    -- tinygoldscrap + diamondjewellery
    ["Base.BellyButton_RingGoldRuby"] = 400,       -- tinygoldscrap + rubyjewellery
    ["Base.BellyButton_RingSilver"] = 30,          -- tinysilverscrap
    ["Base.BellyButton_RingSilverAmethyst"] = 100, -- tinysilverscrap + amethystjewellery
    ["Base.BellyButton_RingSilverDiamond"] = 530,  -- tinysilverscrap + diamondjewellery
    ["Base.BellyButton_RingSilverRuby"] = 290,     -- tinysilverscrap + rubyjewellery
    ["Base.BellyButton_StudGold"] = 140,           -- tinygoldscrap
    ["Base.BellyButton_StudGoldDiamond"] = 640,    -- tinygoldscrap + diamondjewellery
    ["Base.BellyButton_StudSilver"] = 30,          -- tinysilverscrap
    ["Base.BellyButton_StudSilverDiamond"] = 530,  -- tinysilverscrap + diamondjewellery
    ["Base.Bracelet_BangleLeftGold"] = 140,        -- tinygoldscrap
    ["Base.Bracelet_BangleLeftSilver"] = 30,       -- tinysilverscrap
    ["Base.Bracelet_BangleRightGold"] = 140,       -- tinygoldscrap
    ["Base.Bracelet_BangleRightSilver"] = 30,      -- tinysilverscrap
    ["Base.Bracelet_ChainLeftGold"] = 140,         -- tinygoldscrap
    ["Base.Bracelet_ChainLeftSilver"] = 30,        -- tinysilverscrap
    ["Base.Bracelet_ChainRightGold"] = 140,        -- tinygoldscrap
    ["Base.Bracelet_ChainRightSilver"] = 30,       -- tinysilverscrap
    ["Base.ButterKnife_Gold"] = 220,               -- smallgoldscrap
    ["Base.ButterKnife_Silver"] = 50,              -- smallsilverscrap
    ["Base.Earring_Dangly_Diamond"] = 700,         -- 2diamondjewellery
    ["Base.Earring_Dangly_Emerald"] = 470,         -- 2emeraldjewellery
    ["Base.Earring_Dangly_Ruby"] = 440,            -- 2rubyjewellery
    ["Base.Earring_Dangly_Sapphire"] = 370,        -- 2sapphirejewellery
    ["Base.Earring_LoopLrg_Gold"] = 140,           -- tinygoldscrap
    ["Base.Earring_LoopLrg_Silver"] = 30,          -- tinysilverscrap
    ["Base.Earring_LoopMed_Gold"] = 140,           -- tinygoldscrap
    ["Base.Earring_LoopMed_Silver"] = 30,          -- tinysilverscrap
    ["Base.Earring_LoopSmall_Gold_Both"] = 140,    -- tinygoldscrap
    ["Base.Earring_LoopSmall_Gold_Top"] = 140,     -- tinygoldscrap
    ["Base.Earring_LoopSmall_Silver_Both"] = 30,   -- tinysilverscrap
    ["Base.Earring_LoopSmall_Silver_Top"] = 30,    -- tinysilverscrap
    ["Base.Earring_Stone_Emerald"] = 470,          -- 2emeraldjewellery
    ["Base.Earring_Stone_Ruby"] = 440,             -- 2rubyjewellery
    ["Base.Earring_Stone_Sapphire"] = 370,         -- 2sapphirejewellery
    ["Base.Earring_Stud_Gold"] = 140,              -- tinygoldscrap
    ["Base.Earring_Stud_Silver"] = 30,             -- tinysilverscrap
    ["Base.Fork_Gold"] = 220,                      -- smallgoldscrap
    ["Base.Fork_Silver"] = 50,                     -- smallsilverscrap
    ["Base.Goblet_Gold"] = 400,                    -- goldscrap
    ["Base.Goblet_Silver"] = 90,                   -- silverscrap
    ["Base.GoldCoin"] = 90,                        -- smallestgoldscrap
    ["Base.GoldCup"] = 400,                        -- goldscrap
    ["Base.Hat_HockeyMask_Gold"] = 400,            -- goldscrap
    ["Base.Hat_HockeyMask_Silver"] = 90,           -- silverscrap
    ["Base.KeyRing_Forged_Gold"] = 180,            -- smallergoldscrap
    ["Base.KeyRing_Forged_Silver"] = 40,           -- smallersilverscrap
    ["Base.Lantern_Hurricane_Gold"] = 400,         -- goldscrap
    ["Base.Lantern_Hurricane_Silver"] = 90,        -- silverscrap
    ["Base.NecklaceLong_Gold"] = 140,              -- tinygoldscrap
    ["Base.NecklaceLong_GoldDiamond"] = 640,       -- tinygoldscrap + diamondjewellery
    ["Base.NecklaceLong_Silver"] = 30,             -- tinysilverscrap
    ["Base.NecklaceLong_SilverDiamond"] = 430,     -- tinysilverscrap + diamondscrap
    ["Base.NecklaceLong_SilverEmerald"] = 310,     -- tinysilverscrap + emeraldjewellery
    ["Base.NecklaceLong_SilverSapphire"] = 250,    -- tinysilverscrap + sapphirejewellery
    ["Base.Necklace_Choker_Diamond"] = 500,        -- diamondjewellery
    ["Base.Necklace_Choker_Sapphire"] = 220,       -- sapphirejewellery
    ["Base.Necklace_Gold"] = 140,                  -- tinygoldscrap
    ["Base.Necklace_GoldDiamond"] = 640,           -- tinygoldscrap + diamondjewellery
    ["Base.Necklace_GoldRuby"] = 400,              -- tinygoldscrap + rubyjewellery
    ["Base.Necklace_Silver"] = 30,                 -- tinysilverscrap
    ["Base.Necklace_SilverCrucifix"] = 30,         -- tinysilverscrap
    ["Base.Necklace_SilverDiamond"] = 530,         -- tinysilverscrap + diamondjewellery
    ["Base.Necklace_SilverSapphire"] = 250,        -- sapphirejewellery + tinysilverscrap
    ["Base.NoseRing_Gold"] = 140,                  -- tinygoldscrap
    ["Base.NoseRing_Silver"] = 30,                 -- tinysilverscrap
    ["Base.NoseStud_Gold"] = 140,                  -- tinygoldscrap
    ["Base.NoseStud_Silver"] = 30,                 -- tinysilverscrap
    ["Base.Ring_Left_MiddleFinger_Gold"] = 140,    -- tinygoldscrap
    ["Base.Ring_Left_MiddleFinger_GoldDiamond"] = 640,   -- tinygoldscrap + diamondjewellery
    ["Base.Ring_Left_MiddleFinger_GoldRuby"] = 400, -- tinygoldscrap + rubyjewellery
    ["Base.Ring_Left_MiddleFinger_Silver"] = 30,   -- tinysilverscrap
    ["Base.Ring_Left_MiddleFinger_SilverDiamond"] = 430,     -- tinysilverscrap + diamondscrap
    ["Base.Ring_Left_RingFinger_Gold"] = 140,      -- tinygoldscrap
    ["Base.Ring_Left_RingFinger_GoldDiamond"] = 640, -- tinygoldscrap + diamondjewellery
    ["Base.Ring_Left_RingFinger_GoldRuby"] = 400,  -- tinygoldscrap + rubyjewellery
    ["Base.Ring_Left_RingFinger_Silver"] = 30,     -- tinysilverscrap
    ["Base.Ring_Left_RingFinger_SilverDiamond"] = 430,   -- tinysilverscrap + diamondscrap
    ["Base.Ring_Right_MiddleFinger_Gold"] = 140,   -- tinygoldscrap
    ["Base.Ring_Right_MiddleFinger_GoldDiamond"] = 640,    -- tinygoldscrap + diamondjewellery
    ["Base.Ring_Right_MiddleFinger_GoldRuby"] = 400, -- tinygoldscrap + rubyjewellery
    ["Base.Ring_Right_MiddleFinger_Silver"] = 30,  -- tinysilverscrap
    ["Base.Ring_Right_MiddleFinger_SilverDiamond"] = 430,      -- tinysilverscrap + diamondscrap
    ["Base.Ring_Right_RingFinger_Gold"] = 140,     -- tinygoldscrap
    ["Base.Ring_Right_RingFinger_GoldDiamond"] = 640,  -- tinygoldscrap + diamondjewellery
    ["Base.Ring_Right_RingFinger_GoldRuby"] = 400, -- tinygoldscrap + rubyjewellery
    ["Base.Ring_Right_RingFinger_Silver"] = 30,    -- tinysilverscrap
    ["Base.Ring_Right_RingFinger_SilverDiamond"] = 430,    -- tinysilverscrap + diamondscrap
    ["Base.SilverCoin"] = 18,                      -- smallestsilverscrap
    ["Base.SilverCup"] = 90,                       -- silverscrap
    ["Base.Spoon_Gold"] = 220,                     -- smallgoldscrap
    ["Base.Spoon_Silver"] = 50,                    -- smallsilverscrap

    --[[ Hand-added below this line.

         These pieces carry no material tag, because vanilla has no scrapping recipe
         that wants pearl, amber, bone or a watch movement. They are still obviously
         not junk, so they get a value here rather than falling back to the $4 the
         weight curve would give them. Watches are priced as watches, not as metal --
         paired left/right variants share a price since they are the same object. ]]

    -- Pearl and amber
    ["Base.Necklace_Pearl"]        = 190,
    ["Base.NecklaceLong_Amber"]    = 120,
    ["Base.Necklace_Choker_Amber"] = 95,
    ["Base.Earring_Pearl"]         = 80,
    ["Base.Earring_Dangly_Pearl"]  = 110,

    -- Plain pieces: still costume jewellery, but a cut above a corkscrew
    ["Base.Necklace_Crucifix"] = 25,
    ["Base.Necklace_YingYang"] = 18,
    ["Base.Necklace_Choker"]   = 15,

    -- Signet rings: gold-look, unmarked, so priced well under a tagged gold ring
    ["Base.Ring_Left_MiddleFinger_Signet"]  = 60,
    ["Base.Ring_Right_MiddleFinger_Signet"] = 60,
    ["Base.Ring_Left_RingFinger_Signet"]    = 60,
    ["Base.Ring_Right_RingFinger_Signet"]   = 60,

    -- Trophy pieces: worth something as curios, nothing as material
    ["Base.Necklace_BoarTusk"]       = 20,
    ["Base.Necklace_BoarTusk_Multi"] = 32,
    ["Base.Earring_BoarTusk"]        = 14,
    ["Base.Earring_BirdSkull"]       = 14,

    -- Wristwatches
    ["Base.WristWatch_Left_Expensive"]       = 260,
    ["Base.WristWatch_Right_Expensive"]      = 260,
    ["Base.WristWatch_Left_ClassicGold"]     = 150,
    ["Base.WristWatch_Right_ClassicGold"]    = 150,
    ["Base.WristWatch_Left_ClassicBlack"]    = 55,
    ["Base.WristWatch_Right_ClassicBlack"]   = 55,
    ["Base.WristWatch_Left_ClassicBrown"]    = 55,
    ["Base.WristWatch_Right_ClassicBrown"]   = 55,
    ["Base.WristWatch_Left_ClassicMilitary"] = 70,
    ["Base.WristWatch_Right_ClassicMilitary"]= 70,
    ["Base.WristWatch_Left_DigitalDress"]    = 45,
    ["Base.WristWatch_Right_DigitalDress"]   = 45,
    ["Base.WristWatch_Left_DigitalBlack"]    = 28,
    ["Base.WristWatch_Right_DigitalBlack"]   = 28,
    ["Base.WristWatch_Left_DigitalRed"]      = 28,
    ["Base.WristWatch_Right_DigitalRed"]     = 28,
}
