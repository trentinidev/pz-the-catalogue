# The Catalogue

A buy/sell mod for **Project Zomboid Build 42** (42.20+).

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
fetches nothing. Selling pays 90% of catalogue price. The 10% spread is the house's.

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
| `SellRatio` | 0.9 | Fraction of value paid when selling. |
| `MaxQuantityPerPurchase` | 100 | Cap on the quantity field. |
| `SellContainerContents` | true | Selling a bag sells what is inside it. |
| `MinConditionToSell` | 0.0 | Refuse items below this condition. |

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
roughly **$5,000**. Prices are tuned to sit under that ceiling — beans $1, an axe $30,
a shotgun $250, a generator $600.

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

Two layers, in `media/lua/shared/TheCatalogue/`:

- **`TC_Overrides.lua`** — 171 hand-set prices covering firearms, ammunition, tools,
  medicine, electronics, radios and bags. These win outright.
- **`TC_Prices.lua`** — a formula for everything else, from the item's `DisplayCategory`
  and weight, on a sub-linear weight curve (`base × (0.55 + 0.45 × w^0.85)`).

Money, MoneyBundle and BareHands are excluded from the catalogue: a currency that can be
bought and sold at any spread other than exactly 1.0 is an arbitrage loop. Corpses,
body parts, wound items and live-animal categories are excluded too.

## Requirements

Build 42.20 or later. B42 moved mod translations from the legacy `.txt` format to JSON
around 42.15; this mod ships JSON and will show raw keys on older builds.

## Credits

Art and design by **trentini**. The catalogue item reuses vanilla's `Catalogue_Open`
and `Catalogue` world models.
