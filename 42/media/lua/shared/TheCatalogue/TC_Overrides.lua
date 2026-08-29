--[[ The Catalogue -- hand-set prices.

     Nearly empty on purpose. Read the next four paragraphs before adding to it.

     This file used to hold 186 prices, and it held them for a good reason: the price
     table was computed by a formula that could see what an item DECLARES -- category,
     weight, calories, MaxDamage, Capacity -- and nothing about what an item is FOR. It
     put a hunting rifle and a fireplace poker of the same mass in the same place, so
     186 entries existed to argue with it, one item at a time.

     Since 0.11.1 the table is imported from tools/reference/PZ_prices_B42.20.4.md, which
     prices all 5,092 vanilla ids individually from 1993 replacement cost and then
     survival utility in Knox County. It reasons about exactly what the formula could
     not, which means the overrides were arguing a case that had already been won. They
     were retired wholesale rather than reconciled one by one: keeping a hand price that
     merely agrees with the table is how the two drift apart later.

     WHAT BELONGS HERE NOW. Only a price where this mod deliberately disagrees with the
     study, with the disagreement written down. Two, at the time of writing.

     Values are in dollars: TC.PRICE_SCALE is 1.0, so what is written here is what the
     player is shown, before the sandbox PriceMultiplier. Every id is checked against the
     game's own scripts by tools/verify_ids.sh -- a mistyped id is not a runtime error,
     it is silently ignored, which is worse.
]]

TheCatalogue = TheCatalogue or {}

TheCatalogue.PRICE_OVERRIDES = {

    --[[ A sterilised bandage costs more than a clean one.

         The study prices Base.Bandage and Base.AlcoholBandage identically, at $10. In
         game they are not the same object: the sterilised one is a clean bandage with
         disinfectant spent on it, and Disinfectant is itself worth $6 a bottle. Pricing
         the two alike would mean the alcohol went in for free, and would make the
         sterilised version the obvious buy at no cost -- which removes a decision the
         game otherwise poses. ]]
    ["Base.AlcoholBandage"] = 12,

    --[[ Same argument, same family. The study puts the sterilised bundle level with the
         clean one at $4; the sterilising is work and materials someone did. ]]
    ["Base.RippedSheetsSterilizedBundle"] = 5,
}
