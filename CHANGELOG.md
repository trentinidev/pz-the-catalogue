# Changelog

All notable changes to The Catalogue.

The mod has never been released, so the version numbers below are **pre-1.0 by
design**. Everything to date is development toward a first public build: the numbering
was reset from an over-optimistic 1.x to reflect that. 1.0.0 is reserved for the first
version that has been played end to end. It does not promise a dedicated server —
server authority is deferred past 1.0, as the 0.7.4-alpha entry below records.

Dates are the day the work was done, not a release date — nothing here has shipped.

---

## 0.11.1-alpha — 2026-08-29

The price table is no longer computed. It is imported.

### Changed
- **All 5,092 vanilla prices come from a study, not a formula.**
  `tools/reference/PZ_prices_B42.20.4.md` prices every id one at a time, from 1993 US
  replacement cost and then what the object is worth thirty to ninety days into the Knox
  Event. `sh tools/import_prices.sh` builds `TC_PriceTable.lua` from it, and needs
  nothing but the checked-in document, so it runs on a clean clone.

  The generated table could read everything an item DECLARES -- category, weight,
  calories, `MaxDamage`, `Capacity` -- and nothing about what an item is FOR. It put a
  hunting rifle and a fireplace poker of the same mass in the same place. That is what
  186 hand overrides existed to argue with.
- **The catalogue is cheaper in the body and far steeper at the top.** Median falls from
  $16 to $9, the 90th percentile from $98 to $50, the 99th from $705 to $245 -- while the
  dearest item goes from $1,313 to a gold bar at $38,900. An apple is $0.75, beans $2.50,
  a hammer $35, an axe $71, a shotgun $760, a generator $2,700. Ordinary loot is ordinary
  now, and the few things genuinely worth something are priced like it.
- **`TC_Overrides.lua` is nearly empty.** The 186 hand prices were retired wholesale
  rather than reconciled one at a time: keeping a hand price that merely agrees with the
  table is how the two drift apart later. Two remain, each where this mod deliberately
  disagrees with the study, with the disagreement written down -- a sterilised bandage
  and a sterilised bundle cost more than a clean one, because the disinfectant that went
  into them is itself worth something.
- **`TC.PRICE_SCALE` is 1.0.** The study's figures are already in dollars, so the table
  is what the player is shown.
- **`TC.MOD_PRICE_SCALE` (0.75) is new**, and applies only to the two layers that are
  still a formula: items from other mods, which the study will never cover. Measured, not
  chosen -- across the 4,905 ids both sets price, the study's median is 0.43x what this
  mod used to show, and it used to show base x 1.75.
- **The $5,000 carry ceiling is no longer the design anchor.** Prices used to be built
  around how much cash fits in a rucksack; they are built around 1993 Kentucky now. A
  generator is over half a full load and a gold bar cannot be bought in one trip at all.
  That is the intended reading rather than a problem to correct.
- `mod.info` still said "Craft a Shop Catalogue". Renamed with the rest of it.

### Removed
- `tools/gen_prices.ps1`. It rewrote `TC_PriceTable.lua` wholesale, so leaving it in the
  tree meant one careless run would silently destroy the import. `tools/rules.ps1`
  survives as the readable twin of `TC_ModPricing.lua`, which still prices modded items.

---

## 0.11.0-alpha — 2026-08-29

### Fixed
- **A dirty bandage cost five times a clean one.** $11 against $2, with a sterilised one
  also $11. Nothing in the generator knows the three are related, so they were priced
  independently: the clean bandage carried a hand override of `1` from an earlier scale,
  and its two siblings fell through to the formula at `6`. The whole family is set
  together now -- $7 dirty, $10 clean, $12 sterilised.
- The same treatment for the three other families that come in a dirty and a clean form:
  ripped sheets, denim strips and leather strips, singles and bundles. Dirty was priced
  identically to clean in all six pairs.
- **A bundle cost less than one of the things in it.** `RippedSheetsBundle` was $4 and a
  single `RippedSheets` $5. Bundles now run three to four times the single, per the
  reference table.

### Changed
- The sixteen prices above come from the ratios in a 42.20.4 vanilla price study
  (`PZ_tabela_precos_vanilla_B42.20.4.md`): dirty runs 60-65% of clean, a bundle three to
  four times a single. They are written as `reference / 1.75` so that `TC.PRICE_SCALE`
  cancels out and the shown price IS the reference's own figure.
- One deliberate departure from it: the reference prices a sterilised bandage the same as
  a clean one. Here it costs more, because it is a clean bandage with disinfectant spent
  on it.

### Internal
- `tools/verify_ids.sh` now exists. TC_Overrides.lua has claimed since it was written
  that "every id here is checked against the game scripts by tools/verify_ids.sh" -- the
  script did not exist, and the 186 ids had never been checked against anything. A
  mistyped id is not a runtime error: the lookup misses, the item falls through to the
  formula, and the hand-set price is silently ignored, which looks exactly like the
  formula pricing it oddly. All 186 check out. It cannot join tools/check.sh because it
  needs an installed copy of the game, which the CI runner does not have.

### Known
- `RippedSheets` and `RippedSheetsDirty` both show **$1**. The reference puts them at
  $1.25 and $0.75 and `roundPrice` floors at $1, so there is no room between them. The
  distinction survives on the bundles, which is where it is worth having. A strip of
  dirty cloth being worth about a dollar is the right answer even when it is not a
  distinguishable one.

---

## 0.10.3-alpha — 2026-08-29

### Changed
- **The rail is centred in the gap it actually occupies.** Every one of these windows
  ends its content block at `innerW - PAD` -- the buy window's detail panel, and the
  full-width list in the sell window and the ledger -- so the empty strip the rail lives
  in is `railW + PAD` across, not `railW`. Insetting from the rail's own edge therefore
  left 28px of air to the left of a button and 14 to the right, and the column read as
  pushed against the frame. Splitting the real gap puts an equal 21 either side; the
  buttons move 7px left.
- **Buy, Sell and Cart are back at the top of the rail.** 0.10.2 centred them in the
  rail's free height, which left them floating in the middle of the frame. At the top,
  Buy sits level with the search box beside it and the column reads as having a start.
  The Ledger keeps the bottom, on the centre line of the button row next to it.

---

## 0.10.2-alpha — 2026-08-29

### Changed
- **The rail sits off the frame edge.** Its inset is now `TC.UI.PAD`, the same margin
  every other block in these windows keeps from the border, rather than a smaller number
  of its own -- at 8 the buttons read as tighter to the frame than the list opposite
  them.
- **Buy, Sell and Cart are centred in the rail** instead of stacked under the title bar,
  which left the column looking top-heavy against a list that fills the whole height.
  The space is measured to the RESERVED top of the bottom block rather than to what is
  currently visible, so a delivery arriving cannot re-centre the group above it.
- **The Ledger lines up with the bottom button row.** It hung off the window's bottom
  EDGE, and since a rail button is shorter than a Rush or a Place order, sharing a margin
  left it sitting low -- reading as something that had slid down the edge rather than as
  the last entry of a column. It now shares that row's centre line, which holds at any
  font size.

---

## 0.10.1-alpha — 2026-08-29

0.10.0 crashed on open and never really ran; this is the first working build of the
rail. The fix is recorded under 0.10.0 where it was made, but the number is bumped so
that two different builds are not both called 0.10.0 -- the log line is how a report
gets matched to a build, and it has already misled once.

### Added
- **Item icons in the cart and the ledger**, at the same 26px the buy list uses. Both
  rows grew from 30 to 34 to give the icon the same breathing room it has there: the
  icon size is the fixed thing and the row follows it.
- Ledger lines now carry the `fullType` alongside the name they already stored. The
  summary is still built from the name -- it is a receipt, and the name is what the
  player recognises -- but an icon needs the type. Entries written before this version
  have no `fullType` and draw without an icon; the ledger keeps two hundred entries, so
  old and new rows share the list for a while yet. The text indents past the icon either
  way, so the column does not zigzag.
- A ledger row shows the FIRST line's icon. A transaction can hold several, and the
  summary beside it already says so ("1 x ID Card, 1 x Belt, ..."), so the picture marks
  the row rather than claiming to describe all of it.

### Changed
- **The rail is regrouped.** Cart moves up into the third slot, where the Ledger was, and
  the Ledger moves to the bottom of the rail. The top three are what you go to the
  catalogue to do -- browse, sell, and look at what you have staged; the bottom two
  report on what already happened -- what is on order and what has turned up. Both
  bottom entries are anchored to the bottom edge rather than flowing from the top, which
  is what keeps the Ledger still when a Delivery entry appears above it.
- Both column headings now sit over the text rather than over the icon, matching how the
  buy list heads its Item column. The ledger's minimum width grew by the icon, so the
  summary is not squeezed to pay for it.

---

## 0.10.0-alpha — 2026-08-29

### Changed
- **The item is called The Catalogue.** It was the Shop Catalogue, which was one word
  longer than it needed to be and did not match the mod's own name. The display strings
  changed; the ids did not. `Catalogue.Catalogue`, the `MakeShopCatalogue` recipe and the
  `ShopCatalogue` icon keep their names on purpose -- renaming the item id would delete
  every catalogue in every existing save, and renaming the recipe id would make anyone
  who had learned it forget.
- **One right-click entry instead of three.** Buy, Sell and Ledger were three entries
  because that is how the windows are built, not because anyone thinks in threes, and a
  PZ context menu is regularly twenty entries long before a mod adds to it. There is now
  a single **Open Catalogue**, which lands on Buy. Collect stays, and stays conditional:
  it appears only while a delivery is actually waiting.
- **Buy, Sell and the Ledger are one window with a rail.** A vertical strip of entries
  down the right edge switches between them. What happens underneath is that the current
  window closes and the next opens at the same rectangle, so nothing moves, nothing
  resizes, and it reads as a pane swap -- the alternative, one host window owning three
  panels, is the same picture for a rewrite of every layout offset in three files, and
  those offsets have already caused three overflow bugs between them.
- **The rail carries the numbers.** How many items are in the cart, how many orders are
  still in flight, and a Delivery entry that is only there when something is at the door.
  Checking whether anything is coming no longer means opening the ledger to find out.
- **The window remembers where it was.** Size and position ride on `modData`, so the rail
  can promise "same frame" across a switch and the catalogue opens where you left it
  after a reload. Clamped on the way back in, so a frame saved on a wider screen cannot
  open with its controls off the edge.
- **The cart opens beside the catalogue, and toggles.** It is the one panel you want
  visible *while* using another -- a tab would hide the list you are adding from -- so it
  docks to the right of the frame, or to the left when there is no room, and the rail
  entry closes it again.
- **"Open cart" is gone from the detail panel.** The rail carries the cart now, with the
  count on it; the button beside it was a second door to the same room. Add to cart takes
  the full width it leaves behind.

### Fixed
- **The rail crashed the buy window the moment it opened.** `TC_UI.lua` reached for
  `FONT_HGT_SMALL`, which every window file declares as its own file LOCAL -- so from
  the shared file it was a global read, nil, and `nil + 10` took the window down with
  `__add not defined for operands`. Read from the text manager on first use and cached
  instead.
- **`mod.info` no longer promises 90% on sales.** It pays 30, and has since 0.5.0 cut the
  ratio; the description had been thirteen versions out of date, wrong by a factor of
  three, and wrong in the direction that made the mod look like an exploit. It now names
  the default and says the sandbox can change it.

### Internal
- A tenth check: a CONSTANT read from a file that never declared it. LuaJIT `-bl` dumps
  the bytecode, every global read shows up as a `GGET` naming the symbol, and a global
  in SCREAMING_CASE is always this mistake -- the engine names are camelCase or
  PascalCase, never all caps, so the rule needs no allowlist. It catches the crash
  above, which parsed perfectly and shipped.
- The cart moved off the buy window instance to a table keyed by player (`TC_Cart.lua`).
  It had to: a rail click closes the buy window, and a cart owned by that window would
  have been emptied by the act of glancing at the ledger.
- `TC.innerW` replaces direct reads of `self.width` in every railed window's layout, so
  the rail's width comes out of the content once rather than at seventeen call sites.
- `railW` is set in each constructor rather than in `TC.buildRail`, because
  `createChildren` asks `listGeometry` for its widths before the rail exists.

---

## 0.9.2-alpha — 2026-08-28

### Fixed
- **Refusing a cheap delivery was free.** The 75% refund rounded to the nearest dollar, and
  75% of $2 is $1.50, which rounds back up to the whole $2 — every order under $3 could be
  turned away at no cost. It rounds **down** now: $2 gives back $1, $5 gives back $3, and
  the quarter is really taken at every price.
- **The Deny tooltip read "75$s%".** PZ's `getText` turns `%1` into a format placeholder,
  so the literal `%` written straight after it in the string was swallowed into that
  placeholder. The sign is part of the argument now rather than of the translated string,
  which sidesteps the escape entirely.

---


## 0.9.1-alpha — 2026-08-28

### Added
- **Cancel a pending order from the ledger.** A small red ✕ on the row of anything still in
  transit calls it off and refunds **100%**. It is drawn rather than made a real button —
  the rows of a scrolling list are painted, not built, so a button would have to be
  created, moved and destroyed as rows scroll — and the hit test shares one rectangle
  function with the drawing, because a button you can see in one place and click in another
  is worse than no button.
- **Deny a delivery at the door.** The arrival window gained a **Deny** beside Receive:
  the goods vanish and **75%** comes back. The quarter is the difference between calling
  something off before it was made up and sending back something that was assembled and
  carried to you, and it is what stops "order everything, refuse what I no longer want"
  from being a free warehouse. The rate is on the button's tooltip, before the click
  rather than after it.
- Once an order has arrived the ledger's ✕ disappears, because turning it away then costs
  a quarter — offering a free cancel next to a delivery already at the door would be the
  wrong price for the wrong thing.
- Both show in the ledger afterwards as **Canceled** and **Refused**, in green with the
  refund, so a receipt book that only ever showed money leaving now shows it coming back.

Rush needed no special case: a rush purchase never becomes an order, so there is nothing
sitting in the list to cancel and nothing to turn away at the door.

---


## 0.9.0-alpha — 2026-08-28

### Removed
- **The custom parcel meshes.** Three were built — a framed crate, a tarped load on a
  pallet — and every one rendered at the wrong size in game. Four readings of how Project
  Zomboid scales an FBX were tried and measured, and none survived contact with the box on
  the tile. They are gone rather than left half-working, along with their world textures,
  the Blender build script and the UV tooling.
- The parcels wear **vanilla's extra-large model** on the ground. Capacity, weight, sound
  and icon are still per tier; only the thing on the ground is shared, and it is a parcel,
  which is what it should look like. The tiers are told apart by their inventory icons,
  which is where the difference was always going to be read.

---


## 0.8.5-alpha — 2026-08-28

### Added
- **The mod prints its version into `console.txt` at load.** A round of size testing was
  spent on a build that had already been replaced on disk — the game was launched four
  minutes before the mesh files changed, and Project Zomboid reads models once at boot.
  Nothing in the log said which version was in memory, so the log, the screenshots and I
  were each describing a different build. `tools/check.sh` verifies the string against
  `mod.info`, because a stale banner would be worse than none.

---


## 0.8.4-alpha — 2026-08-28

### Fixed
- **The unit conversion is baked into the vertices**, which is what the parcels needed all
  along. Vanilla's FBX carries two numbers — 17.664 in its vertex data and 0.4487 after the
  file's inch-to-metre conversion — and everything turned on which one the game reads.
  Building against the raw 17.664 shipped parcels that filled the screen, which rules that
  reading out: the game applies vanilla's conversion, and ignored ours because ours lived
  in unit metadata rather than in the node transform.
  The meshes now ship with their vertices already at the final numbers and a node scale of
  1.0, so there is no unit information left for anything to interpret differently.
  Measured: 1.45×, 2.05× and 2.75× the extra large.

---


## 0.8.3-alpha — 2026-08-28

### Changed
- **The tier sizes step by bulk rather than by width.** "Each one double the last" taken
  literally gave 1.2×, 2.4× and 4.8× the vanilla extra large — right for capacity, absurd
  on screen, because doubling a linear dimension is eight times the volume and the biggest
  tier swallowed its tile. The step is now about ×1.4 linear, which is what twice the box
  looks like with two of them side by side: **1.45×, 2.00× and 2.75×** the extra large.
  The smallest is also lifted clear of vanilla's extra large rather than beating it by a
  hair.
- The three multipliers are a `TIER` table at the top of `tools/blender_parcels.py` and are
  the only numbers to touch.

---


## 0.8.2-alpha — 2026-08-28

### Fixed
- **The parcel FBX files now carry vanilla's unit convention**, which is what the sizes
  were still missing. Getting the numbers right was only half of it: ours declared metres
  while vanilla declares inches, a factor of 39.4 that shows up under one reading of the
  file and not the other — exactly how one tier ends up tiny and another enormous.
  The export configuration was found empirically, by writing a known cube several ways and
  re-importing each; only one comes back as vanilla does, raw 17.664 with an object scale
  of 0.0254. With the convention matched, the tiers measure 1.20×, 2.46× and 4.80× the
  extra large under *both* readings of the file rather than only one.

---


## 0.8.1-alpha — 2026-08-28

### Fixed
- **The parcels were the wrong size, because the reference was in the wrong space.** The
  game reads an FBX's raw vertex data and applies only the `scale` from the model block —
  it does not apply the file's unit metadata. Vanilla's extra large holds 17.664 units of
  vertex data and declares inches, so Blender reports 0.449 and the game sees 17.664.
  Building against Blender's number shipped parcels eight times too small.
  Sizes are now multiples of vanilla's own raw figure, at vanilla's own `scale = 0.2`:
  the 25 is 1.20× the extra large, the 50 is 2.05× the 25, the 100 is 1.95× the 50 and
  covers about a tile.

### Changed
- **The polygon budget is vanilla's now.** Every vanilla parcel is 20 triangles — a plain
  box with a painted texture doing all the work. These were 324, 1188 and 1836, which is
  not a nicer version of the game's art but a different game's art sitting next to it.
  They are 12, 60 and 60, with geometry only where it changes the silhouette: the crate's
  corner posts, the pallet under the tarp.
- **The tape, strapping, rails, plank seams and shipping label are painted into the
  texture**, which is where vanilla puts them. The previous textures were flat material
  with nothing drawn on, which was the other half of why they did not sit next to the
  game's own boxes.

---


## 0.8.0-alpha — 2026-08-28

### Added
- **The parcels have meshes of their own**, built in Blender and shipped as FBX. The crate
  has a real corner-post frame with rails; the pallet load has a real pallet, blocks and
  deck boards, under a tarp that tapers the way fabric over a stack does. Silhouette is
  shape, and no texture was ever going to fake it at the angle the game draws items from.
- **`tools/blender_parcels.py`** builds all three headless — `blender --background
  --factory-startup --python` — and writes both the editable `.blend` and the FBX the game
  loads. Editing is now opening a file, not reconstructing one.
- Every box gets a two-segment edge bevel. Under the game's flat lighting a sharp cube
  reads as a placeholder; the bevel is most of what makes it read as an object.

### Changed
- **The world textures are painted into our own UV grid.** That grid was the whole point
  of owning the mesh: vanilla's layout lives inside a binary FBX, so until now the
  textures had to be re-materialised copies of its atlas. A pixel in the FRONT cell now
  comes out on the front.
- `scale = 1.0`, because the meshes are modelled life-size. Vanilla's remaining ASCII `.x`
  models settle the question — a canteen is 0.122 tall at scale 1.0 — and both our FBX and
  vanilla's carry `UpAxis = 1`.
- The hand-written OBJ generator is retired; `.blend` is a better source in every way now
  that the whole pipeline runs headless. The UV guide survives as
  `tools/gen_uv_guide.ps1`, drawing from the cell table the Blender script writes rather
  than from a second copy of the numbers.
- `tools/check.sh` also verifies that **every mesh a model block names exists** — ours in
  the repo, vanilla's against the game install when there is one, and reported as
  unverified when there is not.

---


## 0.7.9-alpha — 2026-08-28

### Added
- **Base meshes for the three parcel tiers**, in `art/models/`, generated by
  `tools/gen_base_models.ps1` and ready to open in Blender: a taped carton, a strapped
  crate with corner posts, and a tarped load on a modelled half-pallet. Built from
  axis-aligned boxes only, so every part separates cleanly and there is no curve to fight
  when you start detailing.
- **The scale question is settled.** Vanilla still ships a handful of ASCII `.x` models,
  and at `scale = 1.0` they measure like the real objects they are — a canteen 12 cm tall,
  a corkscrew 10 cm long. One unit is one metre and Y is up, so the meshes are built at
  real freight sizes instead of at a number someone would have to discover by trial.
- **A UV layout that is written down**, with `uv_layout.png` to paint against. The whole
  reason the world textures are re-materialised copies of vanilla's atlas is that
  vanilla's layout is locked inside a binary FBX; these meshes are unwrapped to a grid we
  chose, so face art can finally go on the faces it was drawn for.

---


## 0.7.8-alpha — 2026-08-28

### Changed
- **All three parcel tiers now carry their own art**, icons and world textures both. The
  new renders arrived with alpha, so the icons are the art itself rather than a crop off
  a comparison sheet, and each world texture takes its material — cardboard, planks,
  olive canvas — from that tier's own faces instead of from a vanilla stand-in.
- **The material patch is found, not hand-picked.** Hardcoded coordinates are magic
  numbers that silently start pointing at a shipping label the next time the art is
  re-rendered; the script searches for the flattest fully-opaque window instead, which is
  what picks bare planks over a corner bracket. Sampled from the face sheets rather than
  the isometric render, because the iso view is busy everywhere and the best it could
  offer still carried half a FRAGILE stamp.

### Added
- **`art/`** holds the source renders, so both generators are reproducible from a clean
  clone rather than from whatever happens to be in someone's Downloads folder.
- `tools/check.sh` now verifies that **every `Icon` and `texture` a script names exists on
  disk**. A missing one is silent in game — nothing renders, and the script that named it
  is never blamed.

---


## 0.7.7-alpha — 2026-08-27

### Changed
- **The three oversized parcels are now three different objects.** They were one cardboard
  box drawn three times, which left capacity — a number in a tooltip — as the only thing
  telling them apart. The step up in size is now a step up in packaging: a taped carton at
  25, a strapped wooden crate at 50, a tarped pallet load at 100. Legible at a glance, and
  what a real freight company would do anyway.
- Renamed from `Parcel - XXL / 5XL / 10XL` to **`Parcel - 25 / 50 / 100`**, matching the
  art and saying the useful thing outright.
- The crate's world model re-materialises vanilla's parcel atlas rather than painting the
  art onto it: plank texture underneath, vanilla's per-face shading kept, and vanilla's
  tape turned into the dark strapping — which lands correctly on the mesh precisely
  because it *is* vanilla's tape. The 100 uses vanilla's olive-drab military parcel,
  already the colour the art wants.
- **`tools/gen_parcel_art.ps1`** builds all of it from the art sheet.

### Not changed
- The world models keep vanilla's box shape, so the crate has no corner brackets and the
  pallet load has no pallet. Those are silhouettes, and a silhouette needs a mesh. The
  inventory icons have all of it, which is where the difference is actually read.

---


## 0.7.6-alpha — 2026-08-27

### Changed
- **New art for the catalogue: a 1993 Cumberland Mail Order edition.** The inventory icon
  is rebuilt from the new render, and the book on the ground wears its own cover instead
  of being a Keio Furniture catalogue.
- The world model re-skins vanilla's closed-catalogue mesh rather than shipping a new
  one — nothing about this item needs a shape the game does not already have. Its texture
  layout is therefore fixed by that mesh's UVs: cover in columns 0-56, fore-edge in 57-63,
  measured off vanilla's own 64×64.
- **`tools/gen_art.ps1`** builds both assets from the source renders, so the art can be
  re-rendered and the assets rebuilt without anyone having to remember which rectangle of
  the sheet is the cover or how far it gets squashed.

### Not changed
- The open book the character holds while ordering is still vanilla's. It is a different
  mesh with a different texture layout, showing a two-page spread, and the new art has no
  spread to put on it.

---


## 0.7.5-alpha — 2026-08-27

### Added
- **Buying and selling have sounds, in two stages.** Placing an order is paperwork and
  sounds like it — the catalogue opens, a page turns partway through, a pen goes down
  when the order is written. Cash changing hands is a separate instant and gets the shop
  register. The register lives in `takeCash`/`giveCash`, the one place in the mod that
  knows money moved, so it covers buying, the cart, rush, selling and refunds without a
  single call site having to remember. All clips are vanilla sound scripts; nothing ships
  with the mod.
- Selling has no timed action to hang the paperwork on, so the pen sounds at the moment
  the sale completes and a sale sounds like the purchase it mirrors.

### Changed
- **Placing an order plays the reading animation, not the looting one.** It was a
  crouched rummage through a container, which is what your character does to a corpse —
  not to a mail-order catalogue. `Read` is what vanilla uses for a book or for writing a
  note, which is exactly what placing an order is.

---


## 0.7.4-alpha — 2026-08-27

### Added
- **`tools/check.sh`**, run before every commit by `.githooks/pre-commit`. Lua syntax
  through LuaJIT 2.1 (a 5.1 parser, matching the game's Kahlua VM — a 5.4 parser would
  accept `goto` and bitwise operators that Kahlua rejects at load), the translation JSON,
  translation keys in both directions, `TC.*` helpers, methods defined twice in one file,
  and whether `mod.info`'s version has a changelog entry. Everything up to 0.6.5 was
  verified by grep alone, which is why a ledger that threw the instant it opened got
  released. It does not catch code that is valid and wrong anyway — that is still on
  testing.

### Changed
- **The mod is documented as single-player only.** Server authority is deferred until
  after 1.0 rather than half-done before it, so 1.0.0 no longer promises it.

---


## 0.7.3-alpha — 2026-08-27

### Fixed
- **The item ID was drawn through the separator in the buy window's detail panel.** The
  rule was pinned to the bottom of the 64px icon, on the assumption that the name and
  the fullType beside it would always fit in that height — at a larger UI scale they do
  not. The rule now sits below whichever of the two is actually taller.

### Changed
- **The delivery window lists items with their icons**, on the same row height and grid
  as the catalogue: a rail under each row and a rule between the columns. A delivery
  should read as a page from the same book, not as a different widget that happens to
  list items.

---


## 0.7.2-alpha — 2026-08-27

### Changed
- **The delivery window has no close button.** Every other window here is a tool you
  open and dismiss; this one is a question, and the answer is Receive. It still
  collapses out of the way from the arrow in its title bar. A window that can be
  dismissed without answering leaves goods in limbo with no obvious way back to them.
- **The delivery window is laid out on a centre line.** Headline, tally and button are
  centred, the table sits in a symmetric frame with equal margins on both sides, and the
  quantity column is centred under a centred heading instead of pushed against a rule.
- **The ledger lists pending orders soonest-first**, with anything ready to collect at
  the very top. They came out in the order they were placed, which put the order
  *furthest* from arriving at the head of the list and one that was ready to collect
  below it — so an old order eight hours out read like the one just placed.
- **The quantity resets to 1 when you select a different item.** It used to carry over,
  so typing 10 for one item and then clicking another row left the field reading 10
  against something you had only just looked at — and Add to cart would take you at your
  word. Clicking the same row twice still keeps what you typed.

---


## 0.7.1-alpha — 2026-08-27

### Changed
- **Waits under an hour count down in minutes** — `in ~20min`, `in ~10min` — instead of
  collapsing to a single `under 1h`. With lead times rebalanced, a twenty-minute delivery
  and a fifty-minute one are different plans, and the ledger already redraws every frame,
  so the countdown is there for free. Rounded to the nearest five minutes, because a
  delivery is somebody else's schedule and an exact figure would invite watching a clock
  instead of playing; below five minutes it says `any minute` rather than a number worth
  nothing. The order confirmation now reads "arriving in about 20 minutes" for the same
  reason.

---


## 0.7.0-alpha — 2026-08-27

### Added
- **A delivery now waits to be received.** When an order arrives, a window opens listing
  what is on the van, and the parcels are set down at your feet only when you press
  Receive. Goods used to appear the instant the clock ran out — which could be mid-fight,
  mid-swim, or halfway up a rope — and the parcel went down at that spot whether you were
  ready for it or not. Closing the window is not refusing the delivery: the order stays
  in the pending list, survives a save and a reload, and the catalogue's right-click menu
  grows a **Collect delivery** entry for as long as something is waiting. The ledger shows
  a waiting order as `ready to collect`.

### Changed
- **Lead times rebalanced around bulk.** The old formula had a five-hour base, so a single
  pistol round took the same six hours as a chest of tools and the number carried no
  information. The base is now almost nothing and weight is *super-linear* — doubling a
  load more than doubles the job, because it stops being something a van drops off on its
  round. Roughly: one round twenty minutes, a hundred rounds two and a half hours, a
  bandage twenty minutes, a crate of medical stock four to five hours, a generator several
  days. Value and item count contribute a little, so something small and precious is
  handled slightly more carefully than something small and cheap.
- Waits under an hour are said in words (`within the hour`, `under 1h`) rather than
  rounded to `~0h`.

---


## 0.6.5-alpha — 2026-08-27

### Fixed
- **The ledger threw on open.** Its column function has two exits -- one that computes
  the widths and one that returns the cached copy -- and the Amount column added in
  0.6.4 was only added to the first. Every call after the first handed back one value
  short, so the arithmetic downstream ran against a nil: the window rendered empty the
  first time and refused to open after that. It returns the table itself now, so a
  fourth column cannot be added to one exit and forgotten at the other.

---


## 0.6.4-alpha — 2026-08-27

### Fixed
- **The ledger's Amount column was drawn underneath the scrollbar**, so `-$2` rendered
  as `-$` with the digit behind the scroll track, and resizing never helped because the
  gutter moves with the edge. The column is measured against the largest figure the
  ledger can show and counted back from the scrollbar; `What` is the elastic column and
  gives up the room, so the figure is never the thing that gets cut. The cart's Total
  column had the same 4-pixel offset and the same latent bug.
- The ledger cannot be dragged narrower than its own columns any more.

---


## 0.6.3-alpha — 2026-08-27

### Fixed
- **Selling an item off the ground did not remove it — free money, one drag at a time.**
  `container:Remove` takes an item out of the floor container the inventory page is
  showing and leaves the world object standing on the square, so the catalogue paid for
  the item and the item was still lying there to be sold again. Removal now follows
  vanilla's own floor sequence and takes the world object with it.
- **Delivery parcels paid for themselves.** A $2 round arrived inside a box the
  catalogue would buy back for $4, so the cheapest thing on the shelf showed a profit
  the moment it landed. Boxes the catalogue hands over are now stamped as packaging and
  are worth nothing; a parcel found while looting is untouched. A stamped parcel is
  still a carrier, so selling one still sells everything inside it.

### Changed
- **Buttons are sized from their labels, not from the window.** The cart and sell rows
  divided the width into thirds and halves, which clipped `Place order` on a narrow
  window and blew `Rush` up into a banner on a wide one. Widths now come from the text
  and the leftover space goes into the gaps; a window cannot be dragged narrower than
  its own button row.
- **The cart header stopped writing `Quantity` and `Unit price` on top of each other.**
  Its columns were fixed pixel offsets that held at one font size; they are measured
  now, like every other table in the mod.

---


## 0.6.2-alpha — 2026-08-27

### Changed
- **The ledger is a real table now**, with the same column rules and row rails as the
  catalogue, and a `Type` heading over the column that was previously unlabelled.
- **"Order history" is now "Ledger"** in the right-click menu, matching what the window
  has called itself all along.

### Fixed
- **The ledger's delivery estimate was frozen at whatever it said when the window
  opened.** The row now keeps the order rather than a formatted string and renders the
  countdown each frame, so an open ledger walks down from `~8h` to `~7h` to `~6h` as the
  hours pass. A delivery that lands while the window is open drops out of the pending
  block on its own.
- **Confirmation messages stayed on screen forever.** "Added 5 x Apple to the cart" is
  worth reading once; left up it becomes furniture that says only that something
  happened at some point. Messages now clear themselves after six real seconds --
  measured in real time, not game time, because they are addressed to the person at the
  keyboard and should not survive a night's sleep.
- **`Place order` overflowed its button in the cart.** The bottom row divided the width
  into thirds and then squeezed two buttons into the last one. `Rush` is now measured
  from its own label and the other three split what remains evenly.

---


## 0.6.1-alpha — 2026-08-27

### Fixed
- **Every purchase was a rush purchase.** ISButton calls its handler as
  `onclick(target, BUTTON, ...)`, so a handler wired straight to a button gets the
  button as its first argument -- and the rush flag was sitting in that slot. Goods
  arrived instantly and in hand instead of in a parcel hours later, and the cart added
  the 20% surcharge and then refused the order for insufficient funds on money the
  player plainly had. One cause, four symptoms.
- **Excluded categories were bypassed by three of the four pricing layers.** The check
  lived inside the fallback formula, which runs last, so anything the generated table
  or the modded-item pricer answered first went straight past it -- which is how
  "Animal Corpse" ended up on the shelf. It is now one gate in the indexer, before any
  pricing is attempted.
- The cash figure and the status line were drawn underneath the button rows and never
  seen, so the delivery estimate and the "added to cart" confirmation both vanished on
  sight. Their position is now one method instead of the same expression written twice,
  which is how it went wrong.

---

## 0.6.0-alpha — 2026-08-27

Orders. The catalogue stops being a vending machine.

### Added
- **Deliveries take time.** Paying and receiving are now separate. An order is booked,
  the money leaves immediately, and the goods turn up hours later in a parcel dropped
  at your feet, wherever you happen to be. Lead time grows with the weight and value of
  the order -- a tin of beans is a few hours, a generator most of a day.
- **Rush delivery** for a surcharge, default 20%, keeps the old across-the-counter
  behaviour as a paid choice rather than a setting. Both the buy panel and the cart
  offer it beside the ordinary order button.
- **Oversized parcels** at 25, 50 and 100 capacity. Vanilla tops out at 20 and a single
  generator weighs 40, so the largest box the game ships could not hold one item the
  catalogue sells. Same art and sounds as vanilla's largest parcel.
- **Pending orders in the ledger**, above the completed history, marked as ordered and
  carrying an ETA rather than a timestamp.
- `DeliveryHoursMultiplier` and `RushFeePercent` sandbox options.

### Notes
- An order is the only state in this mod that has to survive a save, so it lives on the
  player's modData beside the wishlist and the ledger. Time is measured with
  getWorldAgeHours, not wall clock: an order placed at dusk should arrive after a
  night's sleep, not after the player has been away from their desk.
- A delivery that cannot be made -- an item retired by a patch, a mod unloaded -- is
  refunded in full. The player did not choose for it to fail.

---

## 0.5.0-alpha — 2026-08-27

Ordering, record-keeping, and the maintenance work that had been accumulating.

### Balance
- **Buy prices scaled 1.75x and the sell ratio cut from 0.9 to 0.30.** The catalogue
  was too generous in both directions at once: buying was cheap and selling converted
  loot to cash almost losslessly, so a modest pile of found money bought most of what
  mattered. Together these drop the purchasing power of looted goods by about 5.8x --
  an axe used to cost 1.1 axes sold, and now costs 3.3. Both are sandbox-tunable.

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
