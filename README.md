# The Catalogue

A buy/sell mod for **Project Zomboid Build 42** (42.20+).

> **Alpha — 0.8.4.** Not released, and the version number says so deliberately. It works
> and it is played, but parts of it have never been exercised.
> **Single-player only.** All transaction logic runs client-side, so on a dedicated
> server it is trivially cheatable; server authority is deliberately deferred until
> after 1.0 rather than half-done before it. 1.0.0 is reserved for the first build that
> has been played end to end.
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

**Ordering** — add lines to a cart and settle the whole thing in one transaction, or
order a single line outright. Placing an order takes a couple of interruptible seconds,
so you cannot kit yourself out mid-horde.

**Delivery** — paying and receiving are separate. An order is booked and the money
leaves immediately; when the lead time is up a window opens to say what has turned up,
and the parcels are set down at your feet only when you press **Receive**. Closing that
window is not refusing the delivery — it waits, through a save and a reload, until you
collect it from the catalogue's right-click menu.

How long an order takes is mostly about **bulk**, and bulk compounds: one pistol round
is about twenty minutes, a hundred of them about two and a half hours, a crate of
medical supplies most of a morning, a generator several days. Value counts for a little
and sheer item count for a little, so something small and precious is handled slightly
more carefully than something small and cheap. **Rush** delivery skips the wait for a
surcharge and hands the goods straight across the counter. Pending orders and completed
ones share one ledger, opened from the catalogue's right-click menu.

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
| `DeliveryHoursMultiplier` | 1.0 | Scales how long orders take. |
| `RushFeePercent` | 20 | Surcharge for skipping the wait. |
| `OrderSeconds` | 2.0 | Length of the interruptible action when ordering. |
| `CatalogueLootMultiplier` | 1.0 | How common the catalogue is in world loot. |
| `DebugLogging` | false | Timing and loot-table detail in the console. |

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


### A delivery waits to be received

Goods used to appear at your feet the moment the clock ran out — which could be mid-
fight, mid-swim, or halfway up a rope. The parcel went down at that spot and the only
notice was a line of halo text, by which point you were usually somewhere else.

So the van waits. Arrival flags the order and opens a window listing what is on it;
nothing is spawned until you press Receive. The order stays in the pending list on
`modData` the whole time, which is what makes it safe — it survives a save, a crash and
a quit, and the goods cannot be lost by not being ready for them. This is the same
reasoning as the sell window: **spawn late, remove late, and keep the authoritative
record in the one place the game will persist for you.**

### Delivery packaging is worth nothing

Every order arrives in a parcel, and a parcel is an item the catalogue would otherwise
buy back. That closed a loop: a $2 round shipped in a box worth $4, so the cheapest
thing on the shelf turned a profit the moment it landed, and there was no bottom to it.

Boxes the catalogue hands over are stamped as packaging on the way out and pay nothing.
A parcel you found in a post office is ordinary loot and still sells for what it is
worth, because the mark is on the instance, not on the type. Worthless is not the same
as unsellable — a stamped parcel is still a carrier, so selling one sells everything
inside it and the box goes along with the sale.

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

## Art

`art/` holds the source renders, so the generated assets can be rebuilt from a clean
clone rather than from whatever happens to be in someone's Downloads folder.

```sh
powershell -ExecutionPolicy Bypass -File tools\gen_art.ps1          # the catalogue
powershell -ExecutionPolicy Bypass -File tools\gen_parcel_art.ps1   # the three parcels
powershell -ExecutionPolicy Bypass -File tools\gen_uv_guide.ps1      # the UV guide
blender --background --factory-startup --python tools/blender_parcels.py   # the meshes
```

`art/models/` holds the parcel meshes as editable `.blend` files, built headless by
Blender from `tools/blender_parcels.py`, which also writes the FBX the game loads. See
[its README](art/models/README.md) for the scale (one unit is one metre, Y up, measured
off vanilla's remaining ASCII models), the UV grid, and how to edit them. Owning the
mesh is what gives the crate its corner frame, the pallet load its pallet, and the
texture a layout we chose rather than one locked inside a binary FBX.

## Checks

`tools/check.sh` runs everything that can be verified without launching the game: Lua
syntax, the translation JSON, translation keys in both directions, `TC.*` helpers called
against helpers defined, methods defined twice in one file, and whether the version in
`mod.info` has a changelog entry.

```sh
sh tools/check.sh
```

Syntax is parsed by **LuaJIT 2.1**, not Lua 5.4: the game runs Kahlua, a Lua 5.1 VM, and
a 5.4 parser would accept `goto`, integer division and bitwise operators that Kahlua
rejects at load time. Install with `winget install DEVCOM.LuaJIT`. Without it the script
still runs and says plainly that syntax went unchecked.

It runs before every commit through `.githooks/pre-commit`. Git will not run a hook that
was merely cloned, so on a new machine enable it once:

```sh
git config core.hooksPath .githooks
```

**What it does not catch.** Anything that is valid Lua and wrong anyway. The bug that
took down the ledger in 0.6.4 — a cached function whose two exits returned different
numbers of values — parses perfectly and always will. Static checks buy the cheap half;
the rest is still playing the thing.

## Requirements

Build 42.20 or later. B42 moved mod translations from the legacy `.txt` format to JSON
around 42.15; this mod ships JSON and will show raw keys on older builds.

## Credits

Art and design by **trentini**. The catalogue item reuses vanilla's `Catalogue_Open`
and `Catalogue` world models.
