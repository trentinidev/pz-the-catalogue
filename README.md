# The Catalogue

A buy/sell mod for **Project Zomboid Build 42** (42.20+).

[![checks](https://github.com/trentinidev/pz-the-catalogue/actions/workflows/checks.yml/badge.svg)](https://github.com/trentinidev/pz-the-catalogue/actions/workflows/checks.yml)

> **Alpha — 0.13.0, single-player.** Not released, and the version number says so
> deliberately: it works and it is played, but parts of it have never been exercised.
> [What to expect](#what-to-expect) sets out the limits before you install.
> See [CHANGELOG.md](CHANGELOG.md) for what has landed, and [ROADMAP.txt](ROADMAP.txt)
> for what is deliberately still missing.

Craft **The Catalogue** from a notebook and any pen, right-click it, pick **Open
Catalogue**, and trade with the world's last mail-order company. Every vanilla item has
a price. You pay in real banknotes and you get paid in real banknotes.

---

## Contents

- [What it is for](#what-it-is-for) — the problem, and why the answer is a catalogue
- [What it does](#what-it-does) — the features, one paragraph each, [furniture](#furniture) included
- [What to expect](#what-to-expect) — the honest limits, before you install
- [Installing](#installing) and [Sandbox options](#sandbox-options)
- [Design notes](#design-notes) — why the awkward parts are shaped the way they are
- [Prices](#prices) — where any given number comes from
- [For other mod authors](#for-other-mod-authors), [Checks](#checks),
  [Requirements](#requirements)

---

## What it is for

Knox County is full of money. It is in every till, every wallet and every safe, and by
the end of the first week it is the one kind of loot nobody stoops for, because there is
nothing to spend it on. Meanwhile the opposite problem is filling your safehouse: eleven
spare hammers, four hundred nails and a wardrobe of clothes you will never wear. **The
Catalogue exists to connect those two facts** — to give money somewhere to go and
hoarded loot somewhere to come from.

The obvious version of that idea is a shopkeeper, and the obvious version is the one the
game cannot support. Project Zomboid has no merchants: no NPC to haggle with, no
shopfront to travel to, and writing either means building a social system out of nothing.
A **mail-order catalogue** needs none of that. You order from wherever you happen to be
standing, and the company never has to exist on screen.

That framing is also what keeps it from breaking the game, because a catalogue can charge
you in the currencies a magic shop menu would not:

- **Cash is physical and heavy.** Banknotes are real items with real weight, so there is
  a hard ceiling on what you can carry to spend — around $5,000 with a good backpack.
  You cannot simply buy your way out of the apocalypse.
- **Goods take time.** An order books, the money leaves immediately, and the van arrives
  when the bulk of what you ordered says it arrives — twenty minutes for a pistol round,
  several days for a generator. You cannot re-equip in the middle of a horde.
- **The company buys low and sells high.** Selling pays 10% of catalogue price, so
  clearing out a safehouse is a way to convert junk into cash, never a way to farm it.

**What it is deliberately not:** a trader mod with NPCs, an economy simulation, or an
item spawner with a price tag on it. Prices are fixed, stock is infinite, and there is no
bartering. See [What to expect](#what-to-expect).

---

## What it does

**One window, four faces** -- right-clicking the catalogue offers a single **Open
Catalogue**, which lands on Buy. A rail down the right edge switches the same frame to
Sell or the Ledger without it moving or resizing, and carries the numbers with it: how
many items are in the cart, how many orders are still in flight, and a **Delivery** entry
that appears only when something is at the door. The cart opens beside the window rather
than inside it, so you can watch the total while you keep adding to it; the rail entry
toggles it shut again.

**Buy** — a searchable, filterable table of 4,898 vanilla items on an early-90s scale.
Pick an item, pick a quantity (1–100), and the cost is deducted from the `Base.Money` and
`Base.MoneyBundle` actually sitting in your inventory. The other 194 ids vanilla ships
are not merchandise — debug fixtures, corpses, the wound and bandage overlays the health
system paints on a body — and are refused outright rather than listed at a token price.

**Sell** — drop items into the sell window and it prices them, scaled by condition: a
40%-durability axe fetches 40%, a half-empty bleach bottle fetches half, rotten food
fetches nothing. Selling pays 10% of catalogue price -- the catalogue buys low and sells
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
collect it from the rail's Delivery entry, or the catalogue's right-click menu.

How long an order takes is mostly about **bulk**, and bulk compounds: one pistol round
is about twenty minutes, a hundred of them about two and a half hours, a crate of
medical supplies most of a morning, a generator several days. Value counts for a little
and sheer item count for a little, so something small and precious is handled slightly
more carefully than something small and cheap. **Rush** delivery skips the wait for a
surcharge and hands the goods straight across the counter. Pending orders and completed
ones share one ledger, opened from the rail.

**Changing your mind** — a pending order can be cancelled from the ledger, with the small
red **✕** on its row, for a **full refund**. Once it has arrived that ✕ is gone and the
choice is at the door instead: the delivery window's **Deny** turns it away for **75%**
back, rounded down -- so a $2 order gives back $1 and refusing always costs something. The quarter is the difference between calling something off before it was made up
and sending back something that was assembled and carried to you — and it is what stops
"order everything, refuse what I no longer want" from being a free warehouse. Rush needs no
rule of its own: it never becomes an order, so there is nothing to cancel and nothing to
turn away.

**Selling in bulk** — stage everything eligible from your inventory or from an open
container in one click. Nothing leaves your possession until you confirm. Expand any
staged bag to see its contents line by line, each marked as sold or kept, using the same
test the sale itself applies.

**Writing one** — a `Journal`, `Notebook` or `Notepad`, plus anything you can write
with: any pen or colour, a pencil, a marker, even crayons. The paper is consumed and the
pen is not. Vanilla marks writing implements with a `base:write` tag and blank pages with
`PageToWrite`, so the recipe asks for those rather than naming items — which means a pen
added by another mod works too, and a one-page index card does not become a whole
catalogue.

**Finding a catalogue** — one spawns rarely in post office sorting racks, office desks,
magazine racks and living rooms, so the mail-order company existed before you started
writing your own. `CatalogueLootMultiplier` tunes how common, and 0 turns it off.

**Banking** — right-click any vanilla cash machine, the green free-standing one or the
one set into a wall, and the menu carries **Use ATM**. Your character walks over and the
machine opens: no account yet and it offers to start one, printing a
`Credit Card - Your Name (9025)` and asking you to choose a four-digit PIN. After that it
is a balance, a statement of the last fifty movements, and two buttons — pay money in,
take money out, in $1 / $5 / $10 / $20 / $50 / $100 / All or any figure you type.

Nothing is created: a deposit takes real notes and bundles off you, a withdrawal hands
real ones back, and there is no interest, no overdraft and no fee. What it buys you is
**weight**. Ten thousand dollars in the bank weighs nothing and cannot burn with the house
it was in; the same money in your pockets is a hundred bundles and fifty kilos, and the
withdrawal screen tells you so before you press Confirm.

**The card *is* the account.** The number lives on the plastic, so a card that is not on
you — hand, pockets, a bag, a wallet inside a bag all count — is an account you cannot
reach, PIN or no PIN. Put the card down mid-session and the machine ends the session.

Turn up without one and it will open you a **new** account, at zero, with a card and a PIN
of its own. The old one is not recovered and not lost: it keeps its number, its balance
and its statement, and opens again the day the card turns up. Carry both and the machine
asks which one you mean. Three wrong PINs end the session and you walk back; the machine
does not keep your card. And the catalogue will not buy a card that is tied to an account,
whosever it is.

**Somebody else's card** — every `CreditCard` the world spawns belongs to a person. Pull
one out of a dead man's wallet and it reads *Credit Card - Rose Miller (8471)*: a real
account, with a real balance, and four digits in the way. Balances are weighted rather than
flat — half are petty cash, about one in twenty is worth the walk to a machine.

Ten thousand combinations against three tries a day is a wall, not a puzzle, so there are
nine ways to cut it down. **Examine the card** and roughly one in twelve has the number
written on the back, one in five carries a pencil impression that gives you the four digits
with **no order** — at most 24 arrangements — and most give nothing at all. About one card
in five has a **note** with the PIN on it, in the same wallet or in a drawer elsewhere in
the building. One in five uses a **lazy PIN**: `1234`, `0000`, a birth year. **Burglar**
gets two extra tries a day and examines in half the time.

**The card reader** — two electronics scrap, a battery, wire and a screwdriver at
**Electrical 3**. Run a card through it and it hands back the number, no machine and no
waiting. It is the only route that works the same on every card, and it is capped at ten
reads before it comes apart.

**The machine itself** — with a screwdriver and Electrical 3 you can **wire an ATM's card
reader** so it stops asking for a PIN, for six hours, on that machine only. With a crowbar
you can **force the cashbox**: physical money, no cards involved, very loud, and the
machine is wrecked for good.

**The Online Catalogue** — find a **Blank CD**, burn it with the catalogue in hand, and
install it into a desktop computer. That machine then runs the catalogue for **anybody who
sits at it**, billed to whatever card *they* are carrying, **spending a bank balance and
never touching a note**. The disc is consumed; the install is permanent.

**Internet Banking** — clone a **wrecked** cash machine's software onto a blank disc at
Electrical 3, and install it into a computer along with a card reader. Both are consumed,
and that machine reads cards forever: balance, statement and transfers, with the same PIN
and the same lockout the ATM asks for. **No deposit and no withdrawal** — a desktop has no
cash drawer.

...unless you strip the **note gear** out of a wrecked ATM at **Electrical 6** and fit it.
One per machine in the county, and then that computer takes notes **in**. Taking them out
still means walking to a real machine.

### Furniture

**1,119 pieces of furniture**, from rugs and posters to sofas, beds, wardrobes, shop
counters and industrial fridges. Bought like anything else and delivered as a **placeable
moveable** -- the same item you would get by prising it off a floor yourself.

Only **340** pieces of furniture are items the game ships. Everything else in Knox County
is a **tile**: pick one up and you get a `Base.Moveable` with the sprite written into it,
which is why every sofa, fridge and road cone in this mod used to be worth exactly five
dollars and why the shelf carried one meaningless entry called *Moveable*. The catalogue
now reads the game's own tile definitions, so a sprite name is a piece of furniture with a
name, a weight and a price.

**Selling yours works two ways.** Carry it in like any other item, or **right-click the
piece where it stands** and take the price off the menu. The world entry only appears
while you are carrying the catalogue -- ordinary house floors are moveables too, and a
mod that grows a line on every right-click in the county is a mod people uninstall. The second route skips the
carrying and nothing else: it queues the game's own pickup, so a piece that needs a
screwdriver still needs one, a piece above your carpentry is still refused, and a double
bed still comes up as one piece. A piece you cannot take is greyed out with the reason,
because "the catalogue does not buy wardrobes" and "this one is bolted down" are different
facts.

A wardrobe weighs more than the largest crate holds, so heavy furniture arrives standing
beside the parcels rather than inside one.


---

## What to expect

The limits worth knowing before you install. None of these are oversights; each one is a
decision, and [ROADMAP.txt](ROADMAP.txt) says what is planned about it.

**Single-player.** Every price, payment and order is worked out on your own machine.
On a dedicated server that makes the mod trivially cheatable, so it is documented as
single-player and the mod description says so too. Moving the logic behind server
commands is one job that has to be done all at once, and it is deliberately deferred
past 1.0 rather than half-done before it.

**Stock is infinite.** The catalogue never runs out and never restocks. If you can carry
the cash, you can buy the item — the brake on buying is money, weight and delivery time,
not scarcity. Finite stock needs levels that survive a save, which is real work rather
than a missing checkbox.

**Prices never move.** They do not drift with the weeks you have survived, they do not
respond to what you buy, and there is no haggling. A hammer costs $105 in week one and
$105 in year two.

**Everything arrives mint.** There are no used, damaged or clearance goods; the
condition system runs on the selling side only.

**Delivery costs time, not freight.** Lead time is worked out from bulk. There is no
shipping fee by weight and no named delivery tiers — the only paid option is **Rush**,
which skips the wait entirely for a surcharge.

**The first Buy window of a session can take a few seconds** if you run a lot of item
mods, while every modded item is priced properly instead of guessed at. Every open after
that is instant, and vanilla-only games never pay it at all.

**A lost card is a lost balance.** The card is the only way to its account, by design —
without that rule the account is a second inventory that weighs nothing and can be reached
from anywhere. Burn the card with the house it was in and the money is out of reach for
good. Accounts also ride on the character's own save data, so they die with them.

**It is a beta.** The catalogue, the bank, the cards, the computer, the note gear and the
furniture have all been played through, and each round of it turned up faults that are
fixed. It has now also been run **beside other mods**, which turned up two crashes — both
of them ours, and both the same mistake: a method B42 had quietly renamed. Those are
fixed too.

What is still owed before 1.0.0: no single character has run the whole chain end to end,
and "beside other mods" is not the same as a large, adversarial mod list. 1.0.0 is
reserved for the first build that has had both.

---

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
| `PriceMultiplier` | 5.0 | Scales every buy price. Sell prices follow. |
| `SellRatio` | 0.10 | Fraction of value paid when selling. |
| `MaxQuantityPerPurchase` | 100 | Cap on the quantity field. |
| `SellContainerContents` | true | Selling a bag sells what is inside it. |
| `MinConditionToSell` | 0.0 | Refuse items below this condition. |
| `RequireCatalogueOnPerson` | true | Close both windows if you no longer carry a catalogue. |
| `DeliveryHoursMultiplier` | 1.0 | Scales how long orders take. |
| `RushFeePercent` | 20 | Surcharge for skipping the wait. |
| `OrderSeconds` | 2.0 | Length of the interruptible action when ordering. |
| `CatalogueLootMultiplier` | 1.0 | How common the catalogue is in world loot. |
| `DebugLogging` | false | Timing and loot-table detail in the console. |
| `BankingEnabled` | true | Accounts, cards, cash machines and the computer. Off returns the mod to buying with the notes in your pocket, and no credit card in the world is touched. |
| `ForeignCards` | true | Cards the world spawns belong to somebody. Off leaves your own account working and stops the mod naming or stamping cards it finds. |
| `ForeignBalanceMultiplier` | 1.0 | Scales what is in a found card. 0 makes every one empty. |
| `PinTries` | 3 | Wrong PINs before a card is refused. Burglar always gets two more. |
| `PinLockoutHours` | 24 | How long it stays refused. 0 removes the lockout. |

`BankingEnabled` and `ForeignCards` are two switches because they answer two different
objections. The first is *"I do not want a banking economy"*; the second is *"I do not want
this mod touching `CreditCard`"*, which is the one that matters if another mod cares about
that item.

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

The practical consequence is a ceiling on what you can carry to spend — roughly
**$5,000** with a decent backpack. Up to 0.11.1 the price scale was built around that
number. It is not any more: prices come from the study now, and the study was written
about 1993 Kentucky rather than about how much cash fits in a rucksack. Since 0.13.0
`PriceMultiplier` defaults to **5** on top of the table, so the shelf price is five
times the study figure: a generator is $13,500 and a gold bar $194,500.

Eleven items now cost more than one trip can carry in cash -- the four generators, both
ham radios, a box of antibiotics, the assault rifle and the precious-metal bars.

**In cash.** Buying through the [Online Catalogue](#what-it-does) spends a bank balance
instead of your pockets, and a balance has no weight and no ceiling. So those eleven are
out of reach on foot and in reach from a desk, which puts the dearest things in the game
behind a computer, a disc and a card rather than behind a sandbox setting. Lower
`PriceMultiplier` if you would rather they stayed reachable either way.

That is the intended reading rather than a problem to correct. The ceiling is a fact
about carrying money, not a budget the catalogue has to fit inside, and the dearest
things on the shelf being out of reach of a single trip is what makes them worth
planning for.

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

### The lists sort themselves, too

Kahlua's `table.sort` is a recursive quicksort, and this data is its worst case twice
over. 899 vanilla items sit at the table minimum and 465 one step above — sorting by price is one long
plateau. And the array handed to it is already sorted by the tie-break, because the index
is built in name order and every comparator falls through to the name, so inside that
plateau the comparator says "already in order" for every pair. Recursion depth becomes the
*length* of the run rather than its logarithm, and clicking a column header overflowed the
stack.

`TC_Prices.lua` sorts with a bottom-up merge sort instead: no recursion at all, O(n log n)
on every input rather than on lucky ones, and stable, so the name order the entries arrive
in survives as the tie-break for free. It got worse as the prices got better — the old
generated table spread its values thinly enough that no plateau was long enough to
overflow.

## Prices

Three layers, most specific first, in `media/lua/shared/TheCatalogue/`:

- **`TC_Overrides.lua`** — hand-set, and now only where this mod deliberately disagrees
  with the table below. **Empty**, and that is the finished state — see the file for why
  an override is a heavier thing than it looks now that the table holds relations.
- **`TC_PriceTable.lua`** — the 4,898 tradable vanilla items, **imported** from
  [`tools/reference/PZ_prices_B42.20.4.md`](tools/reference/PZ_prices_B42.20.4.md), a
  study that prices every id one at a time from 1993 US replacement cost and then
  survival utility in Knox County. Rebuild it with `sh tools/import_prices.sh`; it needs
  nothing but the checked-in document, so it runs on a clean clone.
- **`TC_ExcludedItems.lua`** — generated by the same script, from the 194 ids the study
  marks as not merchandise. Leaving them merely unpriced would not work: the formula
  fallback would price them anyway and the floor is $1, which is how a debug water
  bucket ends up on the shelf for a dollar. They are refused before any pricing layer
  is asked.
- **Packs** — a box is priced at what it holds: the count comes from the trailing number
  of the item's `DoubleClickRecipe` (`UnpackFoodBox6`), the content from stripping
  `Box`/`Carton`/`Crate`/`Case`/`Pack` off the id and finding the sibling. A carton looks
  for the inner box before the bare item, so a carton of twelve boxes of twelve is 144
  units. Resolved in a pass after the index, because a box's content may be indexed
  after the box and a carton has to wait for its boxes.
- **`TC_FurnitureTable.lua`** — the 1,119 pieces of furniture, generated by
  `sh tools/gen_furniture.sh` from the game's own tile definitions. A sofa is not an
  item, so the study never saw one; each piece carries a category and
  **`TC_Furniture.lua`** carries twenty prices, anchored on the study wherever it does
  price a piece of furniture the game ships as an item. That file is the one to edit.
- **`TC_ModPricing.lua`** — items from other mods, which the study will never cover. The
  rich properties it needs (`BodyLocation`, `Calories`, `Capacity`, `ConditionMax`, the
  defence ratings) live on `InventoryItem`, not on the `ScriptItem` the index walks, so
  one instance of each unknown item is built at index time to read them. It encodes the
  same judgements as `tools/rules.ps1` and the two should be changed together.
- **`TC_Prices.lua`** — the original category-and-weight formula, now a last resort for
  an item that refuses to instantiate at all.

The last two are still formulas, so they are multiplied by `TC.MOD_PRICE_SCALE` (0.75)
to land on the study's footing. That factor is measured rather than chosen: across the
4,905 ids both sets price, the study's median figure is 0.43× what this mod used to
show, and it used to show base × 1.75.

**Why imported rather than computed.** The table used to be generated from the item
scripts, and the generator could read everything an item *declares* — category, weight,
calories, `MaxDamage`, `Capacity` — and nothing about what an item is *for*. It put a
hunting rifle and a fireplace poker of the same mass in the same place, which is why 186
hand overrides existed to argue with it. The study reasons about exactly what the formula
could not, so the overrides were arguing a case that had already been won.

> **A note on load time.** With a lot of item mods installed, the first time you open the
> Buy window in a session takes a few seconds while every modded item is priced. It is
> instant on every open after that. This is the deliberate cost of pricing modded items
> properly instead of guessing from their weight. Vanilla-only games never pay it, since
> every vanilla price is precomputed.

Modded items can be filtered by source: the category dropdown lists **Vanilla items only**
and then each installed mod under `Mod: <name>`, below the ordinary item categories.

Prices are set by **what a thing is**, and since 0.11.1 by what it is *for*: the study
starts from a 1993 US replacement cost and then asks what the object is worth to someone
thirty to ninety days into the Knox Event. Food, water, medicine, ammunition, fuel and
tools go up; heavy furniture, mains-dependent electronics and luxury go down. Weight
alone was the original mistake — it priced a gold necklace and a corkscrew at $4 apiece.

Sanity check on the result, over 4,898 items -- these are the TABLE's figures, before
`PriceMultiplier`, which now defaults to 5 and is what the shelf actually shows: median $9, 75th percentile $24, 90th $61,
99th $265. An apple is $1, canned beans $3, a hammer $35, an axe $71, a shotgun $760, an
assault rifle $1,890, a generator $2,700 — and the dearest thing in the game is a gold
bar at $38,900.

That last figure is the shape of the change. The old generated table topped out at
$1,313 and had a median of $16; the catalogue is now **cheaper in the body and far
steeper at the top**. Ordinary loot is ordinary, and the handful of things that are
genuinely worth something are priced like it.

**Furniture is the one exception, and deliberately.** The study priced 5,092 *items*; a
sofa is not an item, so it was never in it. Rather than invent 1,119 numbers, every piece
carries a category and `TC_Furniture.lua` carries twenty prices you can read in one
screen. Those twenty are anchored on the study wherever it does have an opinion about a
piece of furniture the game happens to ship as an item: chair $20, table $31, lamp $7,
fridge $175, desktop computer $355. It means a shop counter costs what a kitchen counter
costs, which is the price of the approach.


Money, MoneyBundle and BareHands are excluded from the catalogue: a currency that can be
bought and sold at any spread other than exactly 1.0 is an arbitrage loop. The study
names another 194 ids that are not objects at all -- debug and test fixtures, corpses,
the wound and bandage overlays the health system paints on a body, hair stubble.

Exclusion is now decided **per id**, not per category. It used to also drop the `Ears`,
`Eye`, `Tail` and thirteen animal categories, on the reading that those held live-animal
data rather than objects. They do not: they are where vanilla files its plush toys and
costume pieces, and twenty-seven real sellable things were being withheld because of it
-- Spiffo, Freddy Fox, a rubber duck, bunny-ear hats, a dog leash, a pet water dish. Only
five categories are still refused wholesale, all of them engine states: `Hidden`,
`Corpse`, `MaleBody`, `Wound`, `ZedDmg`.

## Art

`art/` holds the source renders, so the generated assets can be rebuilt from a clean
clone rather than from whatever happens to be in someone's Downloads folder.

```sh
powershell -ExecutionPolicy Bypass -File tools\gen_art.ps1          # the catalogue
powershell -ExecutionPolicy Bypass -File tools\gen_parcel_art.ps1   # the three parcels
```

**No custom meshes.** Three were built for the parcel tiers -- a framed crate, a tarped
load on a pallet -- and every one rendered at the wrong size in game. Four readings of how
Project Zomboid scales an FBX were tried and measured; none survived contact with the box
on the tile. The parcels wear vanilla's extra-large model and are told apart by their
icons.

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

Because that opt-in is exactly as reliable as somebody remembering it, the same script
also runs on GitHub through [`.github/workflows/checks.yml`](.github/workflows/checks.yml),
on every push to `main` and every pull request. The hook is still the real gate — it
refuses the commit before it exists — and the workflow is the backstop for the clone
where the hook was never enabled. It needs nothing but a POSIX shell and LuaJIT, so the
workflow is an `apt-get install luajit` and the same `sh tools/check.sh` you run locally.

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
