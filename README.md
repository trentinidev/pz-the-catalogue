# The Catalogue

A buy/sell mod for **Project Zomboid Build 42** (42.20+).

> **Alpha — 0.5.0.** Not released, and the version number says so deliberately. It works
> and it is played, but multiplayer is unsafe (all transaction logic runs client-side)
> and parts of it have never been exercised. 1.0.0 is reserved for the first build that
> has been played end to end and is safe on a dedicated server.
> See [CHANGELOG.md](CHANGELOG.md) for what has landed.

Craft a **Shop Catalogue** from a Notebook, right-click it, and trade with the world's
last mail-order company. Every vanilla item has a price. You pay in real banknotes and
you get paid in real banknotes.

---

## What it does

**Buy** — a searchable, filterable table of all 5,092 vanilla items with prices on an
early-90s scale. Pick an item, pick a quantity (1–100), and the cost is deducted from
the `Base.Money` and `Base.MoneyBundle` actually sitting in your inventory.

**Sell** — drop items into the sell window and it prices them, scaled by condition: a
40%-durability axe fetches 40%, a half-empty bleach bottle fetches half, rotten food
fetches nothing. Selling pays 30% of catalogue price -- the catalogue buys low and sells
high, as a company with no competition would.

**Bundling cash** — a `Bundle Money` recipe turns 100 loose notes into one
`MoneyBundle`, the exact mirror of vanilla's `UnbundleMoney`. Vanilla can only take a
bundle apart, which is an odd gap in a game that spawns thousands of notes: each one is
a separate object at 0.01 weight, so a few thousand dollars is a few thousand objects
and tens of kilos.

**Finding things** — search by name or item ID, filter by category or by source mod, and
narrow further with a quick filter: what you can afford, what you already own, what you
do not, or your wishlist. Star anything from the detail panel; the wishlist is stored per
character and survives reloads. Click any column header to sort by it, click again to
reverse, and drag the dividers to re-balance the widths.

**Ordering** — add lines to a cart and settle the whole thing in one transaction, or buy
a single line outright. Placing an order takes a couple of interruptible seconds by
default, so you cannot kit yourself out mid-horde; set `OrderSeconds` to 0 for the
instant behaviour. Every completed purchase and sale is written to a ledger you can open
from the catalogue's right-click menu.

**Selling in bulk** — stage everything eligible from your inventory or from an open
container in one click. Nothing leaves your possession until you confirm. Expand any
staged bag to see its contents line by line, each marked as sold or kept, using the same
test the sale itself applies.

**Finding a catalogue** — one spawns rarely in post office sorting racks, office desks,
magazine racks and living rooms, so the mail-order company existed before you started
writing your own. `CatalogueLootMultiplier` tunes how common, and 0 turns it off.

## For other mod authors

`TC_API.lua` exposes `registerPrice`, `excludeItem`, `registerCategoryBase` and
`registerValueHandler`, so another mod can price its own items without editing anything
in here. Precedence is documented at the top of that file; a registered price beats
everything The Catalogue works out for itself.

## Installing

Copy the `42/` folder into a folder named `TheCatalogue` inside your mods directory:

```
%USERPROFILE%\Zomboid\mods\TheCatalogue\42\
```

Then enable **The Catalogue** in the Mods menu.

## Sandbox options

Custom sandbox options in B42 are drawn by the **server settings** screen
(Host → Manage settings), not the singleplayer sandbox screen. For a solo save, edit
`<save>_SandboxVars.lua` directly.

| Option | Default | What it does |
|---|---|---|
| `PriceMultiplier` | 1.0 | Scales every buy price. Sell prices follow. |
| `SellRatio` | 0.30 | Fraction of value paid when selling. |
| `MaxQuantityPerPurchase` | 100 | Cap on the quantity field. |
| `SellContainerContents` | true | Selling a bag sells what is inside it. |
| `MinConditionToSell` | 0.0 | Refuse items below this condition. |
| `RequireCatalogueOnPerson` | true | Close both windows if you no longer carry a catalogue. |

---

## Design notes

Three decisions in here are not obvious, and all three were forced by how the game
actually works rather than by preference.

### Money is physical, so weight is the real balance lever

`Base.Money` weighs 0.01 and `Base.MoneyBundle` weighs 0.5, and the vanilla
`UnbundleMoney` recipe fixes the rate at **1 bundle = 100 notes**. Project Zomboid does
not stack items — every banknote is a separate `InventoryItem` — so $10,000 in loose
notes is ten thousand Java objects weighing 100 kg, and the inventory UI struggles long
before that.

The mod therefore always pays out in bundles and settles the remainder in notes, and
always spends bundles first. $2,350 arrives as 23 bundles and 50 notes: 73 objects and
12 kg, against 2,350 objects and 23.5 kg.

The practical consequence is a hard ceiling: with a decent backpack you can carry
roughly **$5,000**, which is what the price scale is built around: beans $2, a hammer
$21, an axe $53, a shotgun $438, a generator $1,050.

Note that vanilla can only *un*bundle, never re-bundle. The catalogue is the only thing
in the game that hands out `MoneyBundle`.

### The sell window stages items instead of holding them

The obvious implementation is a real `ItemContainer` with a huge capacity that the
player fills and then sells. `ItemContainer.new()` does work from Lua — the game builds
its own floor container that way — but a container created in Lua and attached to no
`IsoObject` **is never saved**, and the game exposes no `OnSave` or `OnQuit` event to
Lua to empty it on the way out. Vanilla has exactly one save-lifecycle hook,
`OnPlayerDeath`. Anyone who alt-F4'd with a full sell box would lose everything in it,
silently.

So nothing moves. The window holds references to items still sitting in their original
containers and only removes them when the sale is confirmed. Closing, dying, crashing
or quitting all cost nothing. The tradeoff is that staged loot still weighs on you
until it sells.

### The lists cull their own rows

`ISScrollingListBox:prerender` walks every row every frame and calls `doDrawItem` on
each — the base class culls nothing. With the full catalogue that would be 5,000 icon
and text draws per frame. Both lists test visibility first and return the next `y`
without drawing. The loop still runs 5,000 times, but comparisons are cheap; it was the
draw calls that hurt.

## Prices

Three layers, most specific first, in `media/lua/shared/TheCatalogue/`:

- **`TC_Overrides.lua`** — 171 hand-set prices covering firearms, ammunition, tools,
  medicine, electronics, radios and bags. These win outright.
- **`TC_PriceTable.lua`** — generated, covering all 4,916 tradeable vanilla items. Built
  offline by `tools/gen_prices.ps1`, which reads everything the item scripts declare:
  calories and macronutrients on food, `MaxDamage` and `ConditionMax` on weapons,
  `BodyLocation` and the three defence ratings on clothing, `Capacity` and
  `WeightReduction` on bags, `SkillTrained` on books, and the precious-material tags on
  jewellery. Rules live in `tools/rules.ps1`.
- **`TC_ModPricing.lua`** — items from other mods, which the offline generator never saw.
  The rich properties it needs (`BodyLocation`, `Calories`, `Capacity`, `ConditionMax`,
  the defence ratings) live on `InventoryItem`, not on the `ScriptItem` the index walks,
  so one instance of each unknown item is built at index time to read them. It encodes
  the same judgements as `tools/rules.ps1` and the two should be changed together.

Changing `tools/rules.ps1` means `TC_PriceTable.lua` has to be regenerated, or the two
disagree and the change looks done when it is not:

```
pwsh tools/gen_prices.ps1 "<PZ install>\media\scripts\generated\items"
```

The path is mandatory and points at an installed copy of the game, so this only runs on
a machine that has Project Zomboid.
- **`TC_Prices.lua`** — the original category-and-weight formula, now a last resort for
  an item that refuses to instantiate at all.

> **A note on load time.** With a lot of item mods installed, the first time you open the
> Buy window in a session takes a few seconds while every modded item is priced. It is
> instant on every open after that. This is the deliberate cost of pricing modded items
> properly instead of guessing from their weight. Vanilla-only games never pay it, since
> every vanilla price is precomputed.

Modded items can be filtered by source: the category dropdown lists **Vanilla items only**
and then each installed mod under `Mod: <name>`, below the ordinary item categories.

Prices are set by **what a thing is**, with weight as a minor modifier — except for
building materials, where weight is the honest signal, since a kilo of nails really is
worth twice what half a kilo is. Weight alone was the original mistake: it priced a gold
necklace and a corkscrew at $4 apiece.

Sanity check on the result: median item $9, 90th percentile $56, dearest item the
assault rifle at $750. Food runs a median of $2, clothing $26, skill books $46.

Money, MoneyBundle and BareHands are excluded from the catalogue: a currency that can be
bought and sold at any spread other than exactly 1.0 is an arbitrage loop. Corpses,
body parts, wound items and live-animal categories are excluded too.

## Requirements

Build 42.20 or later. B42 moved mod translations from the legacy `.txt` format to JSON
around 42.15; this mod ships JSON and will show raw keys on older builds.

## Credits

Art and design by **trentini**. The catalogue item reuses vanilla's `Catalogue_Open`
and `Catalogue` world models.
