--[[ The Catalogue -- hand-set prices.

     Empty, and that is the finished state rather than a gap. Read this before adding to
     it.

     This file once held 186 prices, and it held them for a good reason: the price table
     was computed by a formula that could see what an item DECLARES -- category, weight,
     calories, MaxDamage, Capacity -- and nothing about what an item is FOR. It put a
     hunting rifle and a fireplace poker of the same mass in the same place, so 186
     entries existed to argue with it, one item at a time.

     The table is imported now, from a study that prices all 5,092 vanilla ids
     individually AND holds the relations between them: a dirty variant at 35% of the
     clean one, a sterilised one at 150%, a broken one at most 25%, an opened one at most
     80%, a pack worth what its recipe actually yields, a full container never worth less
     than the shell it returns. The overrides were arguing a case that had been won.

     THE LAST TWO WERE REMOVED FOR A SHARPER REASON THAN REDUNDANCY. They pinned
     Base.AlcoholBandage at $12 and Base.RippedSheetsSterilizedBundle at $5, back when
     the study priced a sterilised bandage level with a clean one and this mod disagreed.
     The study now sets sterilised at 150% of clean by rule -- $15 and $24. An override
     wins outright, so leaving them would have quietly held two items below the relation
     every other item in their family obeys. An override does not just state a price; it
     opts an item out of every rule the table enforces.

     WHAT BELONGS HERE. A price where this mod deliberately disagrees with the study,
     with the disagreement and its reason written down, and having checked that the item
     is not the endpoint of a relation. Values are in dollars: TC.PRICE_SCALE is 1.0.

     Every id is checked against the game's own scripts by tools/verify_ids.sh -- a
     mistyped id is not a runtime error, it is silently ignored, which is worse.
]]

TheCatalogue = TheCatalogue or {}

TheCatalogue.PRICE_OVERRIDES = {
}
