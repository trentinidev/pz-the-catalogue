--[[ The Catalogue -- hand-set prices.

     The formula in TC_Prices.lua covers all ~5,000 vanilla items, but a formula that
     reads only category and weight cannot know that a hunting rifle matters more than
     a fireplace poker of similar mass. This table is where judgement goes.

     Scale is early-90s Kentucky retail, the anchors being:
         canned beans  $1      an axe        $30
         a shotgun     $250    a generator   $600

     Anything absent falls through to the formula. Anything present wins outright,
     before the sandbox PriceMultiplier is applied.

     Every id here is checked against the game scripts by tools/verify_ids.sh -- a
     mistyped id is not a runtime error, it is silently ignored, which is worse.
]]

TheCatalogue = TheCatalogue or {}

TheCatalogue.PRICE_OVERRIDES = {

    -- ANCHORS -------------------------------------------------------------
    ["Base.TinnedBeans"]  = 1,
    ["Base.Axe"]          = 30,
    ["Base.Shotgun"]      = 250,
    ["Base.Generator"]    = 600,

    -- FIREARMS ------------------------------------------------------------
    -- Street prices for used civilian guns, with military hardware marked up
    -- hard because the catalogue is the only reliable way to get one.
    ["Base.Pistol"]                     = 300,
    ["Base.Pistol2"]                    = 340,
    ["Base.Pistol3"]                    = 260,
    ["Base.Revolver"]                   = 220,
    ["Base.Revolver_Long"]              = 280,
    ["Base.Revolver_Short"]             = 180,
    ["Base.ShotgunSawnoff"]             = 160,
    ["Base.DoubleBarrelShotgun"]        = 190,
    ["Base.DoubleBarrelShotgunSawnoff"] = 140,
    ["Base.HuntingRifle"]               = 420,
    ["Base.VarmintRifle"]               = 210,
    ["Base.AssaultRifle"]               = 750,
    ["Base.AssaultRifle2"]              = 520,
    ["Base.JS14_Rifle"]                 = 400,
    ["Base.JS3T_Shotgun"]               = 300,
    ["Base.L92_Carbine"]                = 480,
    ["Base.L94_Rifle"]                  = 560,
    ["Base.MSR7T_Rifle"]                = 620,
    ["Base.TrapperCarbine"]             = 350,

    -- MAGAZINES -----------------------------------------------------------
    ["Base.9mmClip"]   = 25,
    ["Base.44Clip"]    = 30,
    ["Base.45Clip"]    = 28,
    ["Base.556Clip"]   = 40,
    ["Base.M14Clip"]   = 45,
    ["Base.JS14_Clip"] = 40,

    -- AMMUNITION ----------------------------------------------------------
    -- Loose rounds priced per round, boxes and cartons at a bulk discount so
    -- buying in bulk is the sane play, as it is in real life.
    ["Base.Bullets9mm"]  = 1,   ["Base.Bullets9mmBox"]  = 22,  ["Base.Bullets9mmCarton"]  = 190,
    ["Base.Bullets38"]   = 1,   ["Base.Bullets38Box"]   = 24,  ["Base.Bullets38Carton"]   = 205,
    ["Base.Bullets44"]   = 2,   ["Base.Bullets44Box"]   = 38,  ["Base.Bullets44Carton"]   = 330,
    ["Base.Bullets45"]   = 1,   ["Base.Bullets45Box"]   = 28,  ["Base.Bullets45Carton"]   = 240,
    ["Base.Bullets357"]  = 2,   ["Base.Bullets357Box"]  = 34,  ["Base.Bullets357Carton"]  = 295,
    ["Base.ShotgunShells"] = 1, ["Base.ShotgunShellsBox"] = 20, ["Base.ShotgunShellsCarton"] = 170,
    ["Base.308Bullets"]  = 2,   ["Base.308Box"]         = 40,  ["Base.308Carton"]         = 350,
    ["Base.556Bullets"]  = 2,   ["Base.556Box"]         = 36,  ["Base.556Carton"]         = 310,
    ["Base.3030Bullets"] = 2,   ["Base.3030Box"]        = 42,  ["Base.3030Carton"]        = 365,

    -- BLADES --------------------------------------------------------------
    ["Base.Katana"]         = 160,
    ["Base.Sword"]          = 120,
    ["Base.ShortSword"]     = 85,
    ["Base.MacheteKnife"]   = 45,
    ["Base.HuntingKnife"]   = 24,
    ["Base.FightingKnife"]  = 32,
    ["Base.SwitchKnife"]    = 14,
    ["Base.KnifeButterfly"] = 16,
    ["Base.KnifePocket"]    = 8,
    ["Base.SmallKnife"]     = 5,
    ["Base.LargeKnife"]     = 12,
    ["Base.Multitool"]      = 30,
    ["Base.Handiknife"]     = 10,

    -- HAND TOOLS ----------------------------------------------------------
    ["Base.Hammer"]         = 12,
    ["Base.BallPeenHammer"] = 14,
    ["Base.ClubHammer"]     = 16,
    ["Base.Screwdriver"]    = 4,
    ["Base.Wrench"]         = 10,
    ["Base.PipeWrench"]     = 22,
    ["Base.Ratchet"]        = 18,
    ["Base.Pliers"]         = 9,
    ["Base.Saw"]            = 18,
    ["Base.GardenSaw"]      = 14,
    ["Base.SmallSaw"]       = 10,
    ["Base.Crowbar"]        = 16,
    ["Base.BoltCutters"]    = 40,
    ["Base.Sledgehammer"]   = 55,
    ["Base.Sledgehammer2"]  = 55,
    ["Base.WoodAxe"]        = 38,
    ["Base.HandAxe"]        = 20,
    ["Base.PickAxe"]        = 35,
    ["Base.SnowShovel"]     = 15,
    ["Base.File"]           = 6,
    ["Base.Whetstone"]      = 5,
    ["Base.MeasuringTape"]  = 7,
    ["Base.Needle"]         = 1,
    ["Base.Thimble"]        = 1,
    ["Base.Zipties"]        = 2,
    ["Base.BlowTorch"]      = 60,
    ["Base.WeldingMask"]    = 35,
    ["Base.Loupe"]          = 25,

    -- MEDICAL -------------------------------------------------------------
    ["Base.Bandage"]              = 1,
    ["Base.BandageBox"]           = 9,
    ["Base.Bandaid"]              = 1,
    ["Base.AdhesiveBandageBox"]   = 5,
    ["Base.Disinfectant"]         = 6,
    ["Base.AlcoholWipes"]         = 3,
    ["Base.CottonBalls"]          = 1,
    ["Base.CottonBallsBox"]       = 4,
    ["Base.Antibiotics"]          = 28,
    ["Base.AntibioticsBox"]       = 220,
    ["Base.Pills"]                = 6,
    ["Base.PillsVitamins"]        = 5,
    ["Base.PillsSleepingTablets"] = 9,
    ["Base.PillsAntiDep"]         = 12,
    ["Base.PillsBeta"]            = 12,
    ["Base.SutureNeedle"]         = 8,
    ["Base.SutureNeedleHolder"]   = 15,
    ["Base.Tweezers"]             = 4,
    ["Base.Splint"]               = 2,
    ["Base.Coldpack"]             = 3,
    ["Base.Stethoscope"]          = 30,
    ["Base.Gloves_Surgical"]      = 2,

    -- ELECTRONICS ---------------------------------------------------------
    ["Base.Generator_Yellow"] = 600,
    ["Base.Generator_Blue"]   = 600,
    ["Base.Generator_Old"]    = 380,
    ["Base.Battery"]          = 3,
    ["Base.BatteryBox"]       = 10,
    ["Base.LightBulb"]        = 2,
    ["Base.LightBulbBox"]     = 7,
    ["Base.ElectronicsScrap"] = 2,
    ["Base.ElectricWire"]     = 4,
    ["Base.Amplifier"]        = 35,
    ["Base.RadioReceiver"]    = 25,
    ["Base.RadioTransmitter"] = 45,
    ["Base.MotionSensor"]     = 55,
    ["Base.HomeAlarm"]        = 40,
    ["Base.Speaker"]          = 15,
    ["Base.CDplayer"]         = 60,
    ["Base.VideoGame"]        = 45,

    -- RADIO AND TV --------------------------------------------------------
    ["Base.RadioBlack"]    = 40,
    ["Base.RadioRed"]      = 40,
    ["Base.WalkieTalkie1"] = 45,
    ["Base.WalkieTalkie2"] = 60,
    ["Base.WalkieTalkie3"] = 80,
    ["Base.WalkieTalkie4"] = 110,
    ["Base.WalkieTalkie5"] = 150,
    ["Base.HamRadio1"]     = 180,
    ["Base.HamRadio2"]     = 260,
    ["Base.ManPackRadio"]  = 320,
    ["Base.TvBlack"]       = 200,
    ["Base.TvAntique"]     = 120,
    ["Base.TvWideScreen"]  = 450,

    -- LIGHT ---------------------------------------------------------------
    ["Base.HandTorch"]            = 12,
    ["Base.FlashLight_AngleHead"] = 20,
    ["Base.PenLight"]             = 6,
    ["Base.Torch"]                = 2,
    ["Base.Candle"]               = 1,
    ["Base.CandleBox"]            = 6,
    ["Base.Lantern_Hurricane"]    = 22,
    ["Base.Lantern_Propane"]      = 35,
    ["Base.Propane_Refill"]       = 18,

    -- BAGS ----------------------------------------------------------------
    ["Base.Bag_Schoolbag"]       = 25,
    ["Base.Bag_DuffelBag"]       = 35,
    ["Base.Bag_NormalHikingBag"] = 55,
    ["Base.Bag_BigHikingBag"]    = 90,
    ["Base.Bag_ALICEpack"]       = 130,
    ["Base.Bag_ALICEpack_Army"]  = 150,
    ["Base.Bag_SurvivorBag"]     = 110,
    ["Base.Bag_MedicalBag"]      = 70,
    ["Base.Bag_ToolBag"]         = 45,
    ["Base.Bag_Military"]        = 120,
    ["Base.Bag_Satchel"]         = 20,
    ["Base.Bag_FannyPackFront"]  = 12,
    ["Base.Toolbox_Mechanic"]    = 60,
}
