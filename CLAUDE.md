# The Catalogue -- notes for Claude

Buy/sell mod for Project Zomboid **Build 42.20+**. Repo `trentinidev/pz-the-catalogue`,
living in the game's own mods folder, so an edit here is what the next game launch loads.

## Testing loop

The game is **closed** while you edit and the user relaunches it to test. You never see
the result yourself -- the user reports back. On load the console prints
`[The Catalogue] <version> loaded`; when a report seems to contradict the code, ask for
that line first. It has already caught one round of feedback given on a stale build.

## Layout

    42/mod.info                      version, versionMin
    42/media/scripts/thecatalogue.txt   item + model definitions
    42/media/lua/shared/TheCatalogue/   pricing, orders, bank, config, UI helpers
    42/media/lua/client/TheCatalogue/   the five windows, money, two context menus
    42/media/lua/shared/Translate/EN/   JSON, not the old .txt
    tools/                           generators + check.sh
    art/                             icon sources, so renders are reproducible

## Read this before opening files

`TC_PriceTable.lua` is **180 KB of generated data** -- roughly a quarter of a context
window. Never read it whole. `grep` it for the fullType you care about. It is rewritten
wholesale by `sh tools/import_prices.sh` from `tools/reference/PZ_prices_B42.20.4.md`,
a **1.3 MB** study that is even less readable whole -- grep that too.

`CHANGELOG.md` (39 KB) is append-only history: read the top, not the file.

Prices are **imported, not computed**, since 0.11.1. `tools/gen_prices.ps1` is gone.
`tools/rules.ps1` survives only as the readable twin of `TC_ModPricing.lua`, which prices
items from OTHER mods at runtime -- the study will never cover those. Those two formula
layers are multiplied by `TC.MOD_PRICE_SCALE` (0.75) to sit on the study's footing;
`TC.PRICE_SCALE` is 1.0 and the table is in plain dollars.

The same script writes `TC_ExcludedItems.lua` from the 194 ids the study marks as not
merchandise. **Omitting a price does not keep an item off the shelf** -- the formula
fallback prices it anyway and `roundPrice` floors at $1, which is how a debug water
bucket gets listed for a dollar. Exclusion is decided per id; only five categories are
still refused wholesale (`Hidden`, `Corpse`, `MaleBody`, `Wound`, `ZedDmg`). A category
name is a guess about its contents -- `Bear`, `Dog`, `Duck`, `Ears` turned out to be
where vanilla files its **plush toys**, and excluding them withheld 27 real items.

`TC_Overrides.lua` is **empty on purpose**. The study holds relations, not just prices
(dirty at 35% of clean, sterilised at 150%, broken at most 25%, a pack worth what its
recipe yields), and an override opts an item out of every one of them. Read its header
before adding anything.

## Before every commit

    sh tools/check.sh

Ten checks: LuaJIT syntax, JSON balance and duplicate keys, translation keys in both
directions, `TC.*` helpers called vs defined, duplicate methods, icon/texture and mesh
existence, a changelog entry for `modversion`, `TC.VERSION` matching `mod.info`, and a
SCREAMING_CASE constant read from a file that never declared it -- how 0.10.0 shipped a
rail that crashed on open.
`.githooks/pre-commit` runs it (`git config core.hooksPath .githooks`).

A version bump therefore touches three places: `42/mod.info`, `TC.VERSION` in
`TC_Config.lua`, and a `CHANGELOG.md` entry. Ask the user for the number and name.

## Engine facts that have already cost time

- PZ runs **Kahlua, a Lua 5.1 VM**. No `goto`, no `//`, no bitwise operators -- a Lua 5.4
  parser accepts all three and the game rejects them at load. Hence LuaJIT in check.sh.
- **Every window declares its own `PAD`, `ROW_HGT`, `BUTTON_HGT`, `FONT_HGT_*` as file
  locals.** A shared file naming one gets a nil global instead, and `nil + 10` is a
  runtime crash that parses clean. Compute it locally, lazily. The `consts` check exists
  because this shipped once.
- **Translations are JSON since 42.15**, routed by key prefix: `IGUI_` -> `IG_UI.json`,
  `ContextMenu_` -> `ContextMenu.json`, item names -> `ItemName.json` under the bare
  fullType.
- `getText` turns `%1` into a format placeholder and **swallows a literal `%` right
  after it**. Put the symbol in the argument instead.
- `ISScrollingListBox` culls nothing and *paints* rows rather than building them, so a
  per-row button must be drawn and hit-tested by hand (see the ledger's cancel button).
- Ground items are `IsoWorldInventoryObject`; `container:Remove()` leaves the object in
  the world, which was an infinite-money duplication bug. Always use `TC.removeItem`.
- There is **no save/quit hook** in Lua beyond `OnPlayerDeath`. Anything that must
  survive a save lives on `player:getModData()`.
- **World-object menus are a different event from inventory menus.** `OnFillWorldObject-`
  `ContextMenu` fires TWICE -- once with `test = true` only to ask whether anything wants
  to add an option -- and the first pass must be answered with
  `ISWorldObjectContextMenu.setTest()`. Get it wrong and the whole menu is suppressed or
  built twice.
- **A tile is identified by its SPRITE NAME and nothing else.** The four vanilla ATMs
  carry no `CustomName` and no `GroupName`; the six sprites in the same tileset that DO
  look like an ATM set -- `Vault`, two wall and four standing -- are safe-deposit boxes.
  The way to settle it is to pull the tileset out of `media/texturepacks/Tiles1x.pack`
  and look at the pictures; the format is `PZPK`, a version int, a page count, then per
  page a name, a texture count, an int, that many `name + 8 ints` records, and a
  length-prefixed PNG.
- Every window is resizable: **measure text, never hardcode pixel offsets.** Three
  separate overflow bugs came from fixed offsets. `TC.buttonRow` and the `columnStops()`
  helpers exist for this. Remember `TC.UI.SCROLL_GUTTER` when a column is right-aligned.

## Parked until after 1.0

`ROADMAP.txt` holds the list and the reasoning -- keep it there, not here, so the two do
not drift. In short: multiplayer/server authority and Workshop packaging block 1.0;
stock and scarcity, used/clearance goods, dynamic economy, catalogue inserts, PT-BR and
the hand-made parcel models come after. Its closing section lists what has already
shipped, so nothing gets proposed twice.

One of those is a code fact worth having up front: the three delivery tiers share
vanilla's `Base.Parcel_ExtraLarge` mesh and differ only by icon, because the user is
still modelling the oversized parcels by hand.
