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
    42/media/lua/shared/TheCatalogue/   pricing, orders, config, UI helpers
    42/media/lua/client/TheCatalogue/   the four windows, money, context menu
    42/media/lua/shared/Translate/EN/   JSON, not the old .txt
    tools/                           generators + check.sh
    art/                             icon sources, so renders are reproducible

## Read this before opening files

`TC_PriceTable.lua` is **179 KB of generated data** -- roughly a quarter of a context
window. Never read it whole. `grep` it for the fullType you care about. It is rewritten
wholesale by `tools/gen_prices.ps1` from the rules in `tools/rules.ps1`; to change one
price permanently use `TC_Overrides.lua`, which wins over the table.

`CHANGELOG.md` (34 KB) is append-only history: read the top, not the file.

## Before every commit

    sh tools/check.sh

Nine checks: LuaJIT syntax, JSON balance and duplicate keys, translation keys in both
directions, `TC.*` helpers called vs defined, duplicate methods, icon/texture and mesh
existence, a changelog entry for `modversion`, and `TC.VERSION` matching `mod.info`.
`.githooks/pre-commit` runs it (`git config core.hooksPath .githooks`).

A version bump therefore touches three places: `42/mod.info`, `TC.VERSION` in
`TC_Config.lua`, and a `CHANGELOG.md` entry. Ask the user for the number and name.

## Engine facts that have already cost time

- PZ runs **Kahlua, a Lua 5.1 VM**. No `goto`, no `//`, no bitwise operators -- a Lua 5.4
  parser accepts all three and the game rejects them at load. Hence LuaJIT in check.sh.
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
- Every window is resizable: **measure text, never hardcode pixel offsets.** Three
  separate overflow bugs came from fixed offsets. `TC.buttonRow` and the `columnStops()`
  helpers exist for this. Remember `TC.UI.SCROLL_GUTTER` when a column is right-aligned.

## Parked until after 1.0

PT-BR translation, multiplayer/server authority, stock and scarcity, Workshop packaging
(`workshop.txt`, `preview.png`), used/clearance goods, dynamic economy, catalogue inserts.
The user is making the oversized parcel models by hand; the three tiers currently share
vanilla's `Base.Parcel_ExtraLarge` mesh and differ only by icon.
