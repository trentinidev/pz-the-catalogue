# Changelog

All notable changes to The Catalogue.

The mod has never been released, so the version numbers below are **pre-1.0 by
design**. Everything to date is development toward a first public build: the numbering
was reset from an over-optimistic 1.x to reflect that. 1.0.0 is reserved for the first
version that has been played end to end and is safe on a dedicated server.

Dates are the day the work was done, not a release date — nothing here has shipped.

---

## 0.5.0-alpha — 2026-08-27

Ordering, record-keeping, and the maintenance work that had been accumulating.

### Added
- **Cart.** Collect lines and settle them in one transaction instead of a dozen
  separate withdrawals. Prices are re-read at checkout rather than remembered, so a
  cart left open across a settings change cannot lock in the old rate.
- **Ledger.** Every completed purchase and sale is recorded per character and survives
  a reload. Opened from the catalogue's right-click menu.
- **Order action.** Placing an order takes a couple of interruptible seconds, so you
  cannot kit yourself out in the middle of a horde. Nothing is charged until it
  completes. Set `OrderSeconds` to 0 for the old instant behaviour.
- **Bulk selling.** Stage everything eligible from your inventory or an open container
  in one click, with favourites, equipped gear, currency and the catalogue itself
  skipped exactly as they would be by hand. Nothing leaves your possession until you
  confirm.
- **Content tree.** Expand a staged bag to see its contents line by line, each marked
  sold or kept by the same test the sale itself applies.
- **Catalogue in world loot.** Spawns in post office sorting racks, office desks,
  magazine racks and living rooms, so the mail-order company existed before you started
  writing your own. `CatalogueLootMultiplier` tunes it; 0 turns it off.
- **Public API** (`TC_API.lua`) so other mods can price their own items —
  `registerPrice`, `excludeItem`, `registerCategoryBase`, `registerValueHandler`.
- **Diagnostic logging** as a sandbox option, off by default.

### Changed
- Wishlisted items are now protected from sale exactly like favourites, in all three
  places that have to agree: refused when staged, rescued from a sold container, and
  marked as kept in the content tree.
- Cart checkout takes the same interruptible time as a single purchase. It used to
  complete instantly, which made the cart the fast way to shop mid-fight.
- The buy and sell windows now share their table behaviour instead of each carrying its
  own copy — about 120 duplicated lines each, which is where a fix applied to one and
  forgotten in the other comes from.
- Timing and loot-table output no longer prints unless diagnostics are switched on.
  Real problems — refused purchases, refunds, API misuse — still always print.
- `Bundle Money` recipe renamed to `Money Bundle`, matching the item it produces.

### Fixed
- An error was logged for every non-container item in the inventory. `getInventory()`
  exists only on containers, and six places called it inside `pcall` — which catches
  the throw, but the game logs it anyway, so one pass over eleven items produced eleven
  errors and the mod looked broken while behaving correctly.
- Ledger columns were fixed pixel positions and collided at larger UI scales.
- Table headings truncated to "Wei..." before a divider had been touched, for the same
  reason. Column widths are measured from their own headings now.
- The wishlist button and the detail-panel hint were both too long for the space they
  had.

---

## 0.4.0-alpha — 2026-08-26

Quality of life, and the physical-money gaps.

### Added
- **`Money Bundle` recipe** — 100 loose notes into one bundle, the exact mirror of
  vanilla's `UnbundleMoney`. Vanilla can only take a bundle apart, which is an odd gap
  in a game that spawns thousands of notes, each its own object.
- **Quick filters** — what you can afford, what you already own, what you do not, and
  your wishlist, combinable with search and category.
- **Wishlist**, stored per character and surviving reloads.
- **`RequireCatalogueOnPerson`** — both windows close if you no longer carry a
  catalogue. Sandbox-optional for an arcade-style game.

### Fixed
- B42 fluids are their own system and are not drainables, so a half-empty water bottle,
  petrol can or bleach bottle sold for the price of a full one.

---

## 0.3.0-alpha — 2026-08-26

Integrity. Nothing here changes the experience; it stops the mod losing things.

### Fixed
- **Selling a container destroyed what it would not pay for.** A backpack with $500 in
  it paid nothing for the notes and deleted them. Currency, favourites and unlisted
  items are now moved back to your inventory before the container is removed.
- **Valuation stopped at three levels of nesting**, so contents below that were removed
  with the container and never priced. Replaced with a visited set, which cannot lose
  anything to a limit and still stops a genuine cycle.
- **Per-line prices were rounded and then summed.** Ten $1 items at a 0.9 sell ratio
  are worth $9.00, but each line rounded to $1 and the total came to $10 — the player
  was overpaid and the configured spread vanished on exactly the bulk junk sales where
  it matters.
- **Staged items could be sold from across the map.** A dropped item keeps a valid
  container indefinitely; reachability is now what the game itself means by it.
- **Cash was taken before the item existed.** The item is proved first, deliveries are
  counted, and anything undelivered is refunded.
- Quantity box showed 999 while the purchase was capped at 100.
- `versionMin` raised to 42.20.0. The mod cannot work below 42.15 regardless: JSON
  translations do not exist before then.
- Staging from an open container was broken by the reachability check and is fixed;
  a single item can be taken off a stack from the right-click menu.

---

## 0.2.0-alpha — 2026-08-26

Prices, which were the mod's weakest part.

### Changed
- **Every vanilla item repriced from what it is, not what it weighs.** Weight was the
  only magnitude the runtime formula could see, which is why a gold necklace and a
  corkscrew both came out at $4. All 4,916 tradeable vanilla items are now priced
  offline from everything the item scripts declare — calories on food, condition on
  weapons, body location and defence on clothing, capacity on bags, skill on books.
- **Jewellery priced by material**, read from the game's own precious-material tags.
  A gold necklace went from $4 to $143; set with a diamond, $644.
- **Modded items** get the same judgements rather than the blind formula, and can be
  filtered by source mod.

### Fixed
- The sell window recomputed every staged item's value on every frame, which made a
  large sale unusable.
- The buy window took seconds to open: it resolved a texture for all eleven thousand
  items in the game to draw about twenty rows.

---

## 0.1.0-alpha — 2026-08-26

First playable version.

### Added
- **Shop Catalogue** item, crafted from a Notebook.
- **Buy window** — a searchable, sortable table of every tradeable item with prices on
  an early-90s scale, with resizable columns and a detail panel.
- **Sell window** — drag items in, priced by condition, paying 90% of value.
- **Physical money.** Purchases deduct real `Money` and `MoneyBundle`; sales pay out in
  bundles with loose notes for the remainder.
- Five sandbox options, and the mod's artwork.

### Fixed
- Every UI string rendered as its raw key: B42 moved mod translations to JSON around
  42.15, and `IGUI_` keys live in `IG_UI.json`, not `UI.json`.
