# Changelog

All notable changes to The Catalogue.

The mod has never been released, so the version numbers below are **pre-1.0 by
design**. Everything to date is development toward a first public build: the numbering
was reset from an over-optimistic 1.x to reflect that. 1.0.0 is reserved for the first
version that has been played end to end. It does not promise a dedicated server —
server authority is deferred past 1.0, as the 0.7.4-alpha entry below records.

Dates are the day the work was done, not a release date — nothing here has shipped.

---

## 0.10.2-beta — 2026-08-30

### Changed
- **The book on the ground is our own mesh now.** `42/media/models_X/ShopCatalogue.fbx`,
  modelled by Vitor, replacing the re-skin of vanilla's `WorldItems/Catalogue`. Its UVs were
  built against `ShopCatalogueWorld.png` — the FBX references that file by name — so the
  texture and `tools/gen_art.ps1` are unchanged.

- **`scale = 0.125` is MEASURED, not inherited.** This mod has been burned by FBX scale
  before: the oversized parcels shipped custom meshes that rendered at the wrong size, four
  readings of how PZ scales an FBX were tried against the actual box on the actual tile, and
  the meshes were pulled rather than left half-working.

  So both files were measured rather than assumed:

  | mesh | X | Y | Z |
  |---|---|---|---|
  | vanilla `WorldItems/Catalogue` | 14.7409 | 21.4300 | 0.7975 |
  | ours `ShopCatalogue` | 14.7200 | 21.4200 | 0.8400 |

  The same book to within a fifth of a millimetre, so the scale vanilla is known to work at
  is the scale this needs. **Settled without launching the game.**

### Added
- **`tools/fbx_bbox.ps1`** — the measuring tool that answered it, kept because the question
  will come back with the parcel models. The scale in a model block cannot be checked by
  reading it: a mesh twice too big and a scale half too small look exactly like a correct
  pair until the thing is on a tile in front of you. Measure the new mesh, measure a vanilla
  one whose scale is known good, compare.

  It finds the `Vertices` node by name and decodes that one array rather than walking the
  FBX tree — a full parser is a lot of PowerShell to answer one question, and the first
  attempt at one hung.

### Watch for this in game
**The axis order differs.** Vanilla is X wide, Y tall, Z thick; ours is X wide, Z tall,
Y thick — a Z-up export against a Y-up mesh. If the book stands on its edge on the floor,
that is why, and the fix is a re-export with the up axis matched: `rotate` appears only
inside `attachment` blocks in vanilla's own scripts, never on a model, so there is nothing
in the script that can turn it.

`StaticModel` — the open book the character holds while ordering — is still vanilla's. It
is a different mesh with a two-page spread, and the cover art has no spread to put on it.

---

## 0.10.1-beta — 2026-08-30

### Changed
- **New catalogue icon**, drawn by Vitor: the blue-spined book with the printed cover.

  It changes **twelve places at once** and only one file had to move. The item in the
  inventory reads it directly, and every context-menu entry this mod adds — *Open
  Catalogue*, *Collect delivery*, the three sell entries, *Use ATM*, the machine submenu
  and its two entries, *Examine the card*, *Read the note*, *Run it through the reader*,
  *Online Catalogue*, *Internet Banking* and the three installs — goes through
  `TC.catalogueIcon`, which reads the texture off the item script. One PNG, eleven menus.

  Swapped at the **source**, in `art/catalogue_icon.png`, and rebuilt with
  `tools/gen_art.ps1` rather than by dropping a 32×32 into `media/textures`. The script
  trims the transparent margin, squares the result so the book is not stretched by the
  icon slot, and steps 1254 → 256 → 96 → 32 rather than reducing in one jump — a 39×
  bicubic reduction throws away most of the detail it should be averaging.

### Note
**The book on the ground still wears the old cover.** The world texture is built from a
different source — `art/catalogue_faces.png`, a flat sheet of panels, because it re-skins
vanilla's `WorldItems/Catalogue` mesh and its layout is fixed by that mesh's UVs. The new
render is the book in perspective, which is right for an icon and cannot be unwrapped back
into flat panels. The two covers are close in style rather than identical; send a new faces
sheet and `gen_art.ps1` rebuilds that half too.

`42/icon.png` is untouched — that is the mod's banner logo, not the item.

---

## 0.10.0-beta — 2026-08-29

### Added
- **The note gear, and deposits at a computer.** Strip the cassette, stacker and feed
  mechanism out of a **wrecked** cash machine at **Electrical 6**, fit it to a computer that
  already runs Internet Banking, and that machine takes notes in.

  **Software is copied; hardware is taken.** A banking disc can be burned as many times as
  there are blank CDs, because copying costs the original nothing. This is a steel assembly
  bolted inside one particular ATM: **one per machine in the county, forever**, and once it
  is fitted to a desk it is gone from everywhere else. It is the most expensive single
  decision in the mod.

  Both jobs can be done on the same wreck, which is right — the cabinet is open and
  everything in it is reachable, and stripping it properly is what somebody who came
  prepared would do.

- **Deposit comes back; withdrawal never does.** A cassette is a box that swallows notes and
  counts them, not one that hands them back, so taking money out still means walking to a
  real machine. That asymmetry is the feature rather than a limitation: cash goes in
  wherever you built for it, and only a bank gives it back.

### Changed
- **Cloning a machine's software is Electrical 3, down from 5.** Vitor's call, and the
  reasoning holds better than mine did: 5 was justified as "copying a bank should be the
  most advanced thing here", and then the note gear arrived above it at 6, which is where
  that argument belongs. Three jobs of one system all sitting on the same rung is what a
  floor *is* — the ladder is **3 for software, 6 for the hardware that handles cash**.

### Details
- **The machine is marked as stripped only once the part is really in the player's hands.**
  Marking first and adding second would lose the assembly for good on the one failure that
  matters — an inventory that would not take it — and there is no second ATM that can give
  this particular one back.
- **A computer now tracks three installs**, independently: shop, bank, note gear. The
  cassette entry only appears once banking is there, because a note path wired to a machine
  with no bank on it has nothing to deposit into.
- **The cassette is not sold by the catalogue**, alongside the reader and the three discs.

### Note
The sprite is Vitor's; source kept in `art/cassette_icon.png`.

---

## 0.9.0-beta — 2026-08-29

### Added
- **Internet Banking.** The bank, on a desktop, reached with your own cards. It is the
  last of the three things a computer can run and by far the most expensive to get to.

- **Cloning a machine's software — at a WRECKED cash machine.** Vitor's rule, and it is
  better than either option I offered: the cabinet has to have been **forced open** first,
  which takes that ATM out of the world permanently, for this player and for every account
  anybody was going to reach through it. Only then is the board inside reachable.

  So an internet banking disc costs **one cash machine**, and Knox County has a finite
  number of them. It also gives a forced ATM a second life — until now a wrecked machine
  was a dead end with a tooltip on it, and it is now the only place in the game this disc
  can be made.

  **Electricity 5**, a step above the 3 that wires a reader or builds a card reader, plus a
  screwdriver and a blank CD. Pulling a bank's software off its own board should be the
  most advanced thing this mod asks for.

- **Installing it consumes the disc AND the card reader.** A computer cannot read a
  magnetic strip on its own, and the reader is the only thing in the game that can. Wired
  into the case it stops being ten reads in a bag and becomes a machine that reads cards
  **forever** — which is exactly the trade, because that is the last that reader will ever
  be used for anywhere else.

- **No deposit and no withdrawal, ever.** A desktop has no cash drawer, and making notes
  appear in an inventory from a computer would break the rule the whole mod rests on: no
  dollar is ever created. Balance, statement and **transfers** — moving numbers is what a
  computer can actually do. The two buttons are hidden rather than greyed out, because
  there is no circumstance in a remote session where they would come back.

- **The PIN is asked for exactly as the machine asks**, three tries and a 24-hour lockout
  included. A stranger's card is as much of a puzzle at a desk as it is in the street, and
  a computer that skipped the PIN because a reader was wired into it would have made all
  nine ways into a stranger's account pointless overnight.

### Details
- **A computer tracks its two installs separately.** Shop and bank are independent: a
  machine can have either, both or neither, and the menu says which is missing rather than
  lumping them into one "set up" flag.

- **The flag 0.8.0-beta wrote is migrated on read.** That version stored a bare `true`
  against the square, because the catalogue was the only installable thing. Read as a table
  it would be neither installed nor installable, and a player would find their machine had
  quietly forgotten — so a bare `true` is folded into `{ catalogue = true }` the first time
  it is looked at.

- **The banking disc is not sold by the catalogue**, alongside the reader and the other two
  discs. Ordering the thing that costs a destroyed ATM would be the whole price deleted.

---

## 0.8.0-beta — 2026-08-29

**The disc is software, not a credit card.** 0.7.0-beta stamped each burned disc with the
account of whoever made it and required that person to be carrying it. That made the disc a
second credit card: a personal token, tied to one balance, useless to anybody else — and it
is the one version of this feature that means nothing with more than one player.

### Changed
- **The disc is INSTALLED into a computer and consumed.** *Install the Online Catalogue* on
  any desktop, and from then on **that machine runs it for anybody who sits at it**, billed
  to whatever card *they* are carrying. The disc knows nothing about any account and never
  did need to.

  Both halves of that are the point. Spending the disc is what keeps finding a blank one
  worth something and stops one disc lighting up every computer in the county; the install
  being permanent is what turns a machine into a **place** — somewhere you set up once,
  come back to, and can tell somebody else about. The same shape a wired ATM has.

- **The card is chosen at the menu.** One card is not a question, so it stays a plain
  entry; carrying two or more opens a submenu — *Bill account 8471* — because the menu is
  already listing them and a submenu says it in one click less than the cash machine's
  whole chooser screen. No card at all greys the entry out and says why: the online
  catalogue bills an account and never touches cash.

- **The recipe no longer wants a credit card.** It wanted one because the disc used to be
  stamped with an account. Asking for a card to make a copy of a catalogue would now be
  asking for something the result carries no trace of. A blank disc and the catalogue,
  which stays.

- **`TC.stampDisc` is gone**, along with the lazy stamping pass that repaired discs. There
  is nothing on a disc to repair.

### Note
A disc burned by 0.7.0-beta works exactly as a new one does — its leftover account stamp is
never read. **Discs already in a save are not lost.**

---

## 0.7.1-beta — 2026-08-29

### Fixed
- **Right-clicking anything with tile properties threw, and the computer menu never
  appeared.** `props:Val(...)` is not a method on `PropertyContainer` — it is `has` and
  `get`, which is what vanilla's own Lua uses everywhere.

  The call was wrapped in a `pcall`, on the assumption that wrapping made a wrong guess
  safe. **It did not, twice over**: the pcall caught the error while the engine still wrote
  it to the log, so fourteen stack traces came out of a menu that silently added nothing.
  That is precisely the lesson already written down in `CLAUDE.md` about pcall-ing a
  getter, and I walked into it from a new direction. Asking `has` before `get` is both
  correct and cheaper than an exception.

- **The burned disc had no account on it.** The stamp hung off `OnCreate` on the
  craftRecipe — how vanilla does it, through `luaCallOnCreate`, whose Lua-side argument
  list this mod cannot confirm without shipping a build to find out. The disc came out
  named *Online Catalogue* with no account and no error to say why.

  It is stamped **lazily** now, the same way every other item this mod writes an identity
  onto: on the inventory sweep, and again when the menu looks for a disc. A string compare
  in front of the rename means seeing it again costs nothing — and unlike an `OnCreate`
  hook, this also repairs the discs 0.7.0-beta already burned.

  A disc burned while carrying no card stays blank and is stamped the next time the player
  is carrying one, rather than being ruined.

- **`TC.discItemsOn` asks for both spellings of the type**, like `TC.cardItemsOn`. This mod
  has now guessed wrong about whether `getAllTypeRecurse` wants the module prefix twice;
  asking for both is the end of that.

### Changed
- **The real disc sprite is in.** Vitor's 32×32 iridescent CD replaces the generated
  placeholder for both `Item_BlankCD.png` and `Item_OnlineCatalogue.png`; the source is
  kept in `art/blankcd_icon.png`.

---

## 0.7.0-beta — 2026-08-29

### Added
- **The catalogue's icon is on every entry this mod adds to a context menu.** Two of the
  eleven carried it and nine did not, which is worse than none of them carrying it — it
  read as two unrelated features. A right-click menu in this game is twenty entries long
  before a mod touches it, and the picture beside a line is the only way a player with
  three mods installed can tell which line came from which.

  `TC.addOption` is one call instead of "addOption, then remember the icon", because
  remembering it is exactly what did not happen nine times. The icon comes off the item
  *script* rather than an item instance, since most of these menus are filled when the
  player is holding no catalogue at all.

- **The Online Catalogue.** Find a **Blank CD** — office desks, electronics shops, school
  desks — and burn it with the catalogue in hand and your own credit card: 120 seconds, no
  skill. The disc is stamped with the account and named *Online Catalogue (account 8471)*.

  Right-click a **desktop computer** while carrying it and the catalogue opens on the
  screen. Same buy, sell, cart and ledger, retitled *Online Catalogue*, **spending the bank
  balance and never touching a note.** The figure in the corner reads *Account balance*
  instead of *Your cash*.

- **`TC_Purse` — one interface, two kinds of money.** Every window that called
  `TC.getBalance` and `TC.takeCash` directly now goes through `purseBalance`/`purseTake`/
  `purseGive`, and **an account number is the whole interface**: nil means cash, which is
  the same shape the rest of the bank already uses and is why the paper catalogue needed no
  changes beyond threading an argument through.

  Not an object with methods, because the things that need it are a timed action, a
  delivery that lands an hour later, and a refund for an order the player has forgotten
  about. A number survives being written to modData; a table with functions in it does not.

- **Orders remember what paid for them.** A refund days later — cancelled, refused at the
  door, undeliverable — goes back where the money came from. `denyArrived` refunds **inside
  its loop**, per order, because it turns away everything at the door at once and those
  orders need not have been paid the same way: one bought at a kitchen table, the next at a
  computer. A single payment of the total has only one place to send it.

### Details that took the most thought
- **A desktop is matched on tile PROPERTIES, not a list of sprite names** — the opposite of
  the ATMs, and not an inconsistency: the ATMs carry no `CustomName` and no `GroupName`, so
  a literal list was the only handle. Desktops carry both. Matching properties survives a
  renumbered tileset *and* picks up `appliances_com_01_76` and `_77`, whose `CustomName` is
  the literal string `"CustomName"` — a typo in vanilla's own tile data that a hand-written
  list of the four documented sprites would have missed.

- **The session ends when the last catalogue window closes, not the first.** Clicking Sell
  on the rail closes the buy window and opens the sell window at the same rectangle — a
  pane swap that happens to be a close. Ending there would drop the player onto their
  pocket money mid-trip. Getting it wrong the other way is worse: a session outliving its
  windows would leave the next *paper* catalogue quietly spending a bank balance.

- **Neither disc is sold by the catalogue**, alongside the card reader. A blank disc is the
  one scarce thing between a player and this feature, and a shop that sells discs is that
  scarcity deleted. Ordering an online catalogue *from* the catalogue is a snake eating
  itself.

- **Blank discs are not scaled by `CatalogueLootMultiplier`.** That option exists so a
  player can turn off finding catalogues and be left with crafting one; the disc has no
  crafting route, so the same switch would silently remove the whole feature.

- **Every translation key is written out in full.** The first draft built the online titles
  by gluing a prefix to a suffix, which `check.sh` cannot see through — and that check is
  the only automatic guard this mod has over its text. It then caught the half-key inside
  the comment explaining the decision.

### Note
The disc icon is a **placeholder** — a plain generated disc — until Vitor's sprite arrives.
`Item_BlankCD.png` and `Item_OnlineCatalogue.png` are the two files to replace.

---

## 0.6.2-beta — 2026-08-29

### Fixed
- **The PIN boxes were drawn underneath the keypad.** The keys were anchored to the bottom
  of the body and the prompt and boxes flowed down from the top — two independent pieces of
  arithmetic about one screen, which is the exact mistake the arrival window's `layout()`
  exists to prevent, and it went in anyway. Once the card-knowledge line was added the two
  met in the middle and the row of boxes ended up behind the digits.

  Everything on that screen is measured back from the keys now, in one `pinGeometry`
  function that both the layout pass and the drawing pass ask. Slack from a taller window
  collects at the **top**, where nothing is competing for it.

- **"Pressed into the plastic: 1 3 3 7 - the order is yours to find" ran off both edges.**
  `drawCentred` will happily centre a string wider than the box it is centred in, which
  puts equal amounts of it outside each border. It goes through `TC.wrapText` like every
  other run of prose in the mod, and the sentence lost its second half — after the first
  time, "the order is yours to find" is telling the player something they know.

- **The window's minimum height did not count the card-knowledge line**, so at the smallest
  size there was exactly enough room for the prompt and the boxes and the hint landed on
  the headline. Two lines are reserved for it whether or not there is anything to say.

Checked by replaying the layout arithmetic at three UI scales and four window heights,
including the minimum: 192 assertions that nothing on the PIN screen overlaps anything
else.

---

## 0.6.1-beta — 2026-08-29

### Fixed
- **Right-clicking a cash machine threw a Java exception every time.**
  `getFirstTagRecurse` is a Java method that takes an `ItemTag` enum, and it was being
  handed the string `"Screwdriver"` — Kahlua will not coerce one into the other, so it
  threw `expected argument of type ItemTag, got String` and aborted the menu builder
  half-way through. `ItemTag.SCREWDRIVER` is the constant, and the lookup is wrapped so
  that a missing enum on some future build costs an option rather than the menu.

  `findPryBar` had the same class of mistake one line below and no exception to announce
  it: it asked for `Base.Crowbar`, and `getFirstTypeRecurse` answers on the bare name. A
  bag with a crowbar in it silently did not have one.

- **A stolen card never appeared in the machine's card list.** There were three separate
  places asking the inventory for credit cards and they disagreed about which spellings to
  try — the sweep that names cards looked for `CreditCard_Stolen`, and the lookup the
  machine uses did not. So a stolen card was given an account, given a name, given an
  *Examine* option, and was then invisible to every ATM in the county.

  All three now go through `TC.cardItemsOn`, which asks for both types in both spellings
  and de-duplicates. The mod has been guessing whether `getAllTypeRecurse` wants the module
  prefix since `TC_Money.lua`; asking for all four costs a walk of an inventory with two
  cards in it.

- **Examining a card always paid, and most of them should give nothing.** Half the weight
  now goes to a card with nothing written on it anywhere. Measured over 6,000 rolls:
  **7.7% hand over the PIN, 19.9% show the pencil impression, 72.4% find nothing.**

  Two things had made it always pay. The `else` branch revealed the digits, so a card whose
  secret was a note in a drawer — which has nothing on the card at all — fell into it; and
  so did a card named by 0.4.0-beta, before secrets existed, whose `secret` field is nil.
  Each outcome is named explicitly now and anything else finds nothing, and a card from an
  older save is rolled once on first examination so it joins the same distribution instead
  of being permanently generous.

- **The Examine option stayed on a card that had nothing to give.** It required that the
  digits had become known before it would disappear, so a card with nothing on it could be
  examined until the player gave up. Examining is about the card, and a card does not
  change: once looked at, the option is gone whatever the looking found.

---

## 0.6.0-beta — 2026-08-29

### Added
- **The card reader**, and with it the tenth and last route into somebody else's account.

  Two electronics scrap, a battery, a length of wire and a screwdriver, at **Electricity
  3** — the same floor the mod puts on wiring an ATM's reader, and for the same reason.
  Run a card through it and it hands back the four digits, without the machine, without
  the wait, and without the three-tries-a-day.

  **It is the only route that does not depend on the card.** Examining tells you whatever
  that particular card happens to carry — the number on the back if you are lucky, four
  unordered digits if you are not — and a note is either in the wallet or it is not. The
  reader works the same on every card in the county, and that is what the skill is buying.

  **Condition is the ceiling that stops it being simply better than everything else.** Ten
  reads to a reader, one point per card, and it comes apart at zero — removed rather than
  left at condition 0, because an item the game still shows but the mod will not use again
  is a puzzle. It is offered on a card that has *already* been examined, because knowing
  four digits is not knowing the number: the reader is what turns twenty-four arrangements
  into one.

  Electricity sets the time and nothing else. A chance to fail is re-rollable by clicking
  again, which teaches clicking again — and having built the thing, "it did not work, try
  once more" is a worse experience than waiting longer.

  Icon drawn by Vitor; the source is in `art/skimmer_icon.png` so the 32×32 can be redone.

### Changed
- **The catalogue will not sell you a card reader.** The most important line in
  `EXCLUDED_ITEMS` and the only one there to protect a mechanic rather than because the
  item is a box. The reader is gated behind a skill and a handful of scrap on purpose; a
  mail-order company that posts you one for a few hundred dollars is that gate deleted —
  no skill, no materials, just money, which is the thing a player has plenty of by the
  time any of this matters.

---

## 0.5.0-beta — 2026-08-29

**Getting into an account that was not yours.** 0.4.0-beta put real accounts on the cards
the world spawns and left them locked with no key. This is the key — nine of them.

Ten thousand combinations against three tries a day is not a puzzle, it is a wall, so
every route below exists to cut that number down to something a person can work through.

### Finding the number
- **The note in the wallet** (15% of cards). A scrap of paper in the same container. It is
  vanilla's own `SheetPaper2`, renamed *Scrap of Paper (card 8471)* so nobody throws it out
  of a full inventory — but the number is not in the name. Reading it is its own act.
- **Written on the back** (10%). *Examine the card* and there it is.
- **Left in a drawer somewhere else in the building** (15%). Loot is generated one
  container at a time, so the note is queued against the square the card was found on and
  dropped into the next container filled within a dozen tiles. **The queue is allowed to
  fail**: loot the wallet, never open another drawer in that house, and you never find it,
  which is what a real house would do.
- **Lazy PINs** (one card in five). `1234`, `0000`, `2580`, a birth year. Costs nothing to
  try on every card you find, and the day it works it feels like you knew something.

### Working it out
- **The pencil impression** — the default, on the 60% of cards with nothing else. The owner
  wrote the number on the plastic and rubbed it out, and the pressure is still there.
  *Examine the card* gives you the four **digits with no order**: at most 24 arrangements,
  fewer when one repeats. `TC.pinDigits` sorts them, so there is no code path where they
  can come out in PIN order by accident.
- The machine repeats what you know at the keypad. Learning "1 2 4 7" three days and two
  towns ago is no use if only the halo text ever said it.

### The cost of guessing
- **Three wrong PINs and the card is refused for 24 game hours.** The counter and the
  lockout live **on the account**, not on the window — closing the machine and reopening
  it used to hand out three fresh guesses, and walking to an ATM in the next town another
  three. It is the same card and the same bank.
- The card is never retained. A mod that destroys the way into an account over three typos
  is a mod nobody keeps installed.
- **Burglar gets five tries** instead of three, and examines a card in half the time. Not a
  dice roll: a chance to fail that is re-rollable by clicking again only teaches the player
  to click again.

### Going round the PIN entirely
- **Wire the card reader** — a screwdriver and Electrical 3. The machine stops asking and
  takes any card for six hours. **Per-machine and it expires**, both load-bearing: what it
  buys is a *place*. For the next six hours there is an ATM in Rosewood that will take
  anything, and everything in your bag you cannot open is suddenly worth carrying there.
  Pays Electricity XP, because a system that demands a skill and never feeds it punishes
  using it.
- **Force the cashbox** — a crowbar or a sledgehammer. Physical money, no cards involved.
  Slow, and it makes noise *every second* rather than once at the end, so you hear it
  building and get to decide whether to keep going. The machine is wrecked afterwards, for
  good and for every account you were going to use it for. Once per machine, ever: the haul
  is what an ATM had in it, not a balance, or this would be a money printer on a cooldown.

Reading anything needs light and literacy, the same checks vanilla puts in front of a book.

### Measured
Over 4,000 rolls: 21.2% lazy PINs. Secrets land at 12.7% back / 15.2% note / 11.7% house /
60.4% impression.

---

## 0.4.0-beta — 2026-08-29

### Added
- **Every credit card in Knox County belongs to somebody.** The cards vanilla already
  scatters — wallets, office desks, bedroom closets, bins, and the `Outfit_Gaudy` zombies
  wear — now carry an owner's name, an account number and a balance. The one you pull out
  of a dead man's wallet reads *Credit Card - Rose Miller (8471)* and is a real account
  with real money in it that you cannot get at.

  **No new distribution.** Vanilla's list of where a credit card would plausibly be is
  better than one a mod would write, and it was never the missing part. What was missing
  was cards *meaning* anything.

- **Balances are rolled in weighted bands, not flat.** A flat $1–$10,000 makes the average
  wallet worth five thousand dollars and every card the same size. Half of all cards are
  petty cash, a third are an ordinary current account, and one in twenty is worth the walk
  to a machine. Measured over 20,000 rolls: mean $1,141, and 4.6% above $5,000.

- **Strangers' accounts live in the world, not on the character.** `ModData.getOrCreate`
  is the game's per-save global store, which is where an account that is not yours belongs.
  `TC.account` searches the character first and the world second, which is what lets one
  machine screen deal in either.

- **Naming is lazy, and that is what makes four digits work at all.** There are only 9,999
  possible tails and vanilla scatters credit cards across thousands of containers, so a
  world that named a card the moment one spawned would exhaust the space. A card gets its
  identity the first time the mod actually looks at one — as loot is generated into a
  container it can see, or on a throttled sweep of the player's own inventory, which is the
  backstop that catches a card off a corpse, a trade, or a debug spawn. Only cards a player
  has picked up ever cost a number; a long save might use a few dozen.

- **One tail register for the whole world.** The character's own accounts come through it
  too. A tail two accounts can answer to is not an address, and the transfer field is
  addressed by tail alone.

### Changed
- **A transfer can be addressed to your own accounts and to any card on you — and nothing
  else.** The world register knows every account in the county; letting a transfer name one
  would turn the destination field into a probe, where four digits and a look at the
  machine's reaction leak a stranger's account number without ever finding their card.

### Not done yet
A stranger's card asks for a PIN that nobody wrote down, so as of this version it is a
locked box with no key. The mechanic for getting into one is the next decision and it is
Vitor's to make.

---

## 0.3.0-beta — 2026-08-29

### Added
- **Send money from one account to another, addressed by four digits.** A **Transfer**
  button on the account screen opens a window beside the machine: the account you are
  sending from and its balance, a field for the destination's last four, the same quick
  amounts the deposit screen offers, and Send.

  **A window and not a sixth screen**, and that is the cart's argument rather than the
  machine's. Deposit and Withdraw replace the account screen for a moment and hand it
  straight back; a transfer is read *against* the balance it is coming out of while the
  figure is typed, so a screen that covered the account would hide the number the decision
  is being made against. It docks beside the machine and the button toggles it — once it
  is sitting there, the button that opened it is the obvious way to get the space back.

  **Four digits is the whole address** because sixteen typed into a field is an errand, and
  the tail is what is printed on the card and shown on every screen.

- **The machine says what it understood before you press Send.** A mistyped tail is a real
  transfer to the wrong place, so the field reports the account it resolves to, or that no
  account ends in those digits, or that it is the one you are sending from. Send is
  disabled until all of it is true, and `TC.bankTransfer` re-checks every condition anyway
  — it is the thing that moves money.

- **No card is needed at the far end**, deliberately. Paying into an account you cannot
  open is what knowing somebody's number lets you do, and it cannot dodge the access rule:
  the money lands somewhere that still needs its own card to be taken out again. This is
  also the honest answer to *"I found the old card, how do I merge it"* — insert the old
  card and send its balance across.

- **Both statements name the other end.** *Sent to 8415*, *Received from 8000*. A transfer
  read from one side without it is a balance that changed for no stated reason, and where
  it went is the one thing the reader wants to know.

### Changed
- **Account numbers now have unique last four digits**, refused at the point the number is
  minted. Four digits can only *be* an address if two of the character's accounts cannot
  share them, and settling it in `newAccountNumber` means no screen downstream ever has to
  ask "which 8000 did you mean".

### Fixed
- **Cards printed before 0.2.0-beta kept their old name** — `Credit Card - Bob Smith`,
  with no digits on it. They went on working, since an account is matched by modData and
  never by the label, but two of them in a bag were indistinguishable and telling you which
  card it is is the one job a card has outside the machine. They are renamed the first time
  the machine looks at them, which makes it a migration and puts it beside the modData one.

  The rename sits behind a string compare, which is not an optimisation but the whole
  safety of doing this on a scan that runs several times a second while the chooser is
  open: the ordinary case costs nothing and each card is renamed exactly once, ever.

---

## 0.2.1-beta — 2026-08-29

### Fixed
- **The card chooser opened empty.** Two cards in the player's pockets, the screen
  correctly decided to ask which one, and then drew an empty table.

  The line that fills it was there and was never reached. `screen` is written in TWO
  places — directly in `:new`, because the window has to know what it is before
  `createChildren` runs, and through `setScreen` everywhere after — and only `setScreen`
  repopulated. So a window that ARRIVED at the chooser by clicking would have been fine,
  and one that OPENED on it never was. Fixed by giving the population its own function
  and calling it from both, rather than by adding the missing line to one of them: the
  bug was the second path, not the absent call.

### Added
- **Double-clicking a card inserts it.** It is what a list you pick one thing out of is
  expected to do, and it is the first thing anybody tries. The button stays — it is the
  discoverable half, and the half a controller can reach.
- **The chooser follows the pockets it is a picture of.** The inventory stays editable
  while the machine is open, so picking cards up or putting them down while the list is on
  screen rebuilds it. Only when the count actually moves, so the ordinary frame costs a
  comparison; the same trick the delivery window uses to notice a second van arriving.
- **A word in the empty chooser.** It should be unreachable — the screen only opens with
  two cards in hand — but the player can empty it from underneath, and a black panel with
  nothing written in it is the worst thing a screen can be.

---

## 0.2.0-beta — 2026-08-29

**The card is the account.** This replaces the rule 0.1.0-beta shipped with, and it is a
save-format change with a migration behind it.

### The rule that was wrong
0.1.0-beta kept ONE account per character and treated the card as a credential: enter the
PIN and the machine printed you another. Played, it did the thing it should not have — it
let a player bank while the card sat in a crate on the other side of the map. The card was
set dressing, and an account you can reach from anywhere with a number you memorised is
not an account, it is a second inventory that weighs nothing.

### The rule now
- **One account per CARD.** The number lives on the plastic. A card that is not on your
  person — hand, pockets, a bag, a wallet inside a bag; `getAllTypeRecurse` walks all of
  it — is an account you cannot reach, PIN or no PIN.
- **No card at the machine, and it offers you a NEW account**, at zero, with its own card
  and its own PIN. The old one is not recovered and not lost: it keeps its number, its
  balance and its statement, and opens again the day the card turns up. Opening a first
  account and replacing a lost one are deliberately the same button, because they do the
  same thing.
- **More than one card on you, and the machine asks which.** A new `choose` screen lists
  them by account number and the date each was opened. **It shows no balances** — it is
  drawn before a PIN has been entered, and a machine that shows you what is in an account
  before establishing you may look is a display case.
- **The card leaving mid-session ends the session.** Checked on the same timer that
  notices you walking away, because a rule enforced only at the moment the window opened
  would be a rule about opening windows. The inventory is fully usable underneath this
  window; putting the card down in front of the ATM is an ordinary thing to do.
- **The PIN proves you may use the card you are holding.** It proves nothing about a card
  you are not, so nothing is reissued at the keypad any more.

**What this costs, and it is the point.** A card that burns with the house it was in takes
its balance out of reach for good. The money is now safe from weight and from your own
death-drop, and exactly as safe as one small item you have to keep track of.

### Fixed
- **Cards sorted by date could not actually be sorted by date.** `opened` is the game
  clock and the game clock ticks in HOURS, so two accounts opened in the same in-game hour
  carry the same stamp — and losing a card and walking to the next machine is minutes of
  game time. The tie fell through to the account number, which is random, so "oldest
  first" was silently "in whatever order the dice came up". Each account is stamped with a
  counter when it is opened and the chooser sorts on that.

### Migration
The single 0.1.0-beta account is folded into the new table on the first right-click of a
cash machine, keeping its number, balance, PIN and statement, and the old modData key is
cleared so it runs once and never again. It sorts ahead of anything opened since, which is
right — there was only ever one of it.

### Also
- A card's name carries the last four digits: *Credit Card - Bob Smith (9025)*. With two
  cards in a bag, the same name twice over is not a label, it is a coin toss.
- An account whose card could not be created is rolled back rather than left as an orphan
  the player can see in no window and spend from nowhere.

---

## 0.1.1-beta — 2026-08-29

The first play of the cash machine. Everything below is a layout fault or a wording one:
the banking itself behaved, and no money went missing.

### Fixed
- **Prose is WRAPPED now, not truncated.** The welcome screen read "The Catalogue banks
  for you at any cash machine in the cou..." at the size the window actually opens at,
  because everything in this mod went through `TC.truncate` — and truncation is for a
  table cell, where the column is the promise and a name that will not fit has to give
  way to the ones beside it. A sentence is not a table cell.

  `TC.wrapText` is the counterpart, in `TC_UI.lua` beside the function it corrects:
  greedy, one word at a time, falling back to truncation only for a single word too long
  for the column. There is no hyphenation, and a mod that invented one would be guessing
  at every language it gets translated into.

  Because prose wraps, it no longer sets the window's minimum width either. It used to,
  and it bought nothing: the window could not be dragged narrower than the longest line
  of welcome text, and that line came out truncated anyway. Half of it is kept, so four
  sentences wrap to about eight lines rather than to one word each.

- **The status line has two lines of room, reserved whether or not there is a message.**
  "Card not found — a replacement has been printed" does not fit on one line at a larger
  UI scale, and a message allowed to grow downwards grows into the button row. Reserved
  rather than measured per message, so the body above does not jump half a line taller
  every time a message ages out; anchored to the BOTTOM of that block, so a one-line
  message still sits exactly where a one-line message always sat. Past two lines it is
  cut from the END — losing the tail of a sentence still leaves it readable, dropping
  the first line leaves the reader looking at the middle of something.

- **"Account opened" no longer recites the account number.** It made the longest message
  in the mod out of a figure that is on the very next screen, in a row labelled *Account*.

### Changed
- **The right-click entry is *Use ATM*, with the catalogue's own icon beside it** — the
  same one the inventory menu puts on *Open Catalogue*, so the two entries this mod adds
  anywhere in the game are recognisably the same mod's. The icon is read off the item
  SCRIPT rather than off an item instance, because there is no item involved here: the
  menu is filled over a tile, and the player need not be carrying anything at all.

---

## 0.1.0-beta — 2026-08-29

The version number goes DOWN, on purpose and for the second time. 1.x was reset to
0.x when it became clear nothing had shipped; 0.13.0-alpha resets to 0.1.0-beta now
because the alpha line is finished and beta starts its own count. ROADMAP.txt names
the condition for beta -- work that is about how far the mod REACHES rather than what
it does -- and a bank that sends the player out to a machine in a town is that.
Nothing has been released, so no install anywhere sees this as a downgrade.

### Added
- **Cash machines, credit cards and a bank account.** Right-click a vanilla ATM and the
  menu carries *Use cash machine*. The character walks to it, and a four-screen window
  opens on it: open an account, enter a PIN, look at the balance and the statement, pay
  money in or take it out.

- **The account is on the character and the card is only the key.** The balance lives on
  `player:getModData()` beside the wishlist and the ledger, because Lua still has no save
  hook in this game. The card is a `Base.CreditCard` with the account number written into
  its modData and the holder's name written on its face -- *Credit Card - Bob Smith*,
  taken from the survivor descriptor rather than from a Steam login.

  It would have been easier to keep the money ON the card, and it would have been wrong.
  An item worth ten thousand dollars is an item lost with the bag it was in, which is the
  exact problem an account is supposed to solve. Lose the card and the machine prints
  another once the PIN is entered.

- **No money is created or destroyed.** A deposit takes real notes and bundles off the
  player through `TC.takeCash` and a withdrawal hands real ones back through
  `TC.giveCash`, so the total cash in a save is what it always was -- the account only
  changes where it is kept. No interest, no overdraft, no fee: all three would mint or
  burn money the rest of the mod believes it can count.

  The ordering of the two halves is not symmetric and cannot be. A deposit takes the cash
  FIRST, because `takeCash` is the half that can fail and promises to touch nothing when
  it does; crediting first would mint money on exactly that failure. A withdrawal debits
  first, because `giveCash` cannot fail.

- **Quick amounts and a typed one.** $1 / $5 / $10 / $20 / $50 / $100 / All, with a field
  for anything else. A quick amount larger than the account or the wallet is disabled
  rather than left to fail on Confirm; a TYPED one is not clamped as it is typed -- an
  account holding $5 has to be able to accept the "5" in "50" -- so the panel turns the
  figure red and Confirm is what refuses. A withdrawal states its weight before it
  happens: $10,000 is a hundred bundles and fifty kilos.

- **The statement.** The last fifty movements on the account, in the same table style as
  the ledger: when, what, how much, and the balance afterwards. Money in is green, money
  out is red, and the two lines that move nothing -- opening the account, printing a card
  -- show a dash rather than $0, because a zero in a money column invites adding it up.

- **The catalogue will not buy a bound card.** A `CreditCard` is worth about a dollar as
  an object and an entire account as a key, and the sell window was happy to take that
  spread. Refused for any account and not only the player's own: the catalogue has no way
  to tell whose card it is holding, and refusing a looted one costs a dollar while
  accepting your own costs everything.

### The ATM sprites, and how they were found
The four vanilla cash machines are `location_business_bank_01_64` through `_67` -- 64 and
65 the free-standing green one, 66 and 67 the wall-mounted one. They carry no `CustomName`
and no `GroupName`, so there is nothing to match on but the sprite name.

The obvious candidates in the same tileset are a trap and were tried first. Sprites 40 to
45 are named **Vault**, in a `Wall` group of two and a `Standing` group of four -- exactly
the shape an ATM set would have, with the wall-mounted variant having two facings and the
free-standing one four. They are banks of safe-deposit boxes. This was settled by pulling
the tileset out of `Tiles1x.pack` and looking at the pictures, which is also the only
reason the right answer is in this file rather than a plausible wrong one.

`TC.isATMSprite` also accepts a sprite another mod would plausibly call an ATM -- `atm_01_3`,
`mall_atm_2` -- with the delimiter required so that a longer word containing those three
letters is not swept up.

### Changed
- `TC.gameStamp` is public and lives in `TC_History.lua` under a name about the clock
  rather than about the ledger. The bank statement dates its lines with the same call;
  two copies of it would be two calendars in one save file that could come to disagree.
- Two sound intents, `atmOpen` and `atmClose`, both vanilla shop-counter clips. There is
  deliberately no keypad beep: every short beep in the game belongs to something
  announcing itself -- an alarm clock, a house alarm, a reversing van -- and none of them
  is a clip that survives being fired twelve times while somebody types a PIN.

### Notes
- The PIN is asked for on every visit rather than once at opening, which is the only
  reading under which it is a PIN at all. Three wrong tries end the session and the player
  walks back to the machine. **The card is not retained** -- a mod that destroys the way
  into your own savings over three typos is a mod that gets uninstalled.
- Walking away closes the window. The account is money that is deliberately somewhere you
  are not, and being able to bank from across the street would give that away.
- Single-player, like the rest of the mod. Every balance is worked out on the player's own
  machine, so on a dedicated server it is exactly as tamperable as the prices already are.
  Server authority remains one job, after 1.0.

---

## 0.13.0-alpha — 2026-08-29

### Changed
- **Writing a catalogue now needs something to write with.** The recipe takes a bound
  notebook and a pen; the paper is consumed and the pen is not.
- **Three papers are accepted instead of one**: `Journal`, `Notebook`, `Notepad`. Vanilla's
  own marker for a blank writing surface is `PageToWrite`, and five items carry it -- the
  three above at 20, 10 and 5 pages, and `SheetPaper2` and `IndexCard` at one page each.
  Only the bound three qualify: a catalogue is a document with a body to it, and letting a
  single index card become one would make the recipe free. `Doodle` looks like paper and
  is not -- no `PageToWrite`, because it is a finished picture.
- **The pen is `tags[base:write]`, not a list of ids.** Vanilla applies that tag to
  fourteen items: every pen and colour, the Spiffo and fancy ones, pencils, markers and
  crayons. It already excludes the two things that read as pens and are not -- `PenLight`
  is a torch and `PencilCase` a container -- and a tag picks up whatever a future patch or
  another mod marks, which a hand-written list never would.

  No vanilla recipe consumes `base:write` at all. The tag is applied and unused; this is
  the first thing to ask for it.
- **`mode:keep`, and no `MayDegradeLight`.** The pen is a requirement to have, not a
  consumable. A `Pen` has `ConditionMax = 2`, so real wear would break it inside a couple
  of catalogues and turn a nice detail into an errand.

---

## 0.12.1-alpha — 2026-08-29

### Fixed
- **Clicking a column header crashed the buy window** with `Stack overflow`, three hundred
  and fifty frames deep inside Kahlua's `quicksort_comp`. The mod's comparator was fine;
  the sort under it was not, and this data is its worst case on two counts at once:

  - **Enormous runs of an identical key.** 899 vanilla items are priced $1, 465 at $2, 321
    at $5. Sorting by price is sorting one long plateau.
  - **The array is already sorted by the tie-break.** `TC.entries` is built in name order
    and every comparator falls through to the name, so inside that plateau the comparator
    says "already in order" for every pair -- the textbook pivot-degenerate input, where
    recursion depth becomes the LENGTH of the run instead of its logarithm. 899 frames of
    quicksort on top of the outer levels is more stack than the VM has.

  Sorting is done by a **bottom-up merge sort** in `TC_Prices.lua` now: no recursion at
  all, O(n log n) on every input rather than on lucky ones, and stable, so the name order
  the entries arrive in survives as the tie-break for free. Measured on the exact shape
  that crashed -- 5,179 entries, 899 sharing a price, pre-sorted by name -- it sorts in
  about a millisecond, and re-sorting an already-sorted array and sorting descending are
  both fine.

  This got worse as the prices got better. The old generated table spread its values
  thinly enough that no plateau was long enough to overflow; the imported study rounds a
  great many genuinely cheap things to the same dollar, which is correct and which is what
  made the latent bug reachable.
- The comparators are strict **total** orders now -- category, weight and price all fall
  through name to `fullType`, as the name comparator already did. Two different items can
  share a display name, so without that last step a pair could compare equal in both
  directions.

### Internal
- The index build's own sort moved to the same merge sort. It was never the one that
  overflowed -- `getAllItems()` order is not pathological -- but there is no reason to
  keep a second, riskier sort in the file.

---

## 0.12.0-alpha — 2026-08-29

### Added
- **A pack is now worth what is in it.** A box of six BBQ sauces costs six times a BBQ
  sauce; a box of 24 costs 24 times. The bulk factor in 0.11.3 got the ORDER of these
  right and could never get the ANSWER right, because only the recipe knows the count.

  Two things the game will tell us, and neither needs the recipe API:

  - **the count** — an item that unpacks declares `DoubleClickRecipe`, and the convention
    across packing mods is to name the recipe after its yield: `UnpackFoodBox6`,
    `UnpackBox12`, `OCP_UnpackCarton12`. The trailing number is the count.
  - **the content** — strip `Box`/`Carton`/`Crate`/`Case`/`Pack` off the id and look for a
    sibling. `OCP.BBQSauceBox` → `Base.BBQSauce`, `OCP.Seasoning_BasilBox` →
    `Base.Seasoning_Basil`.

  Measured against a 306-box packing mod: **294 of its 296 packs resolve**, and the two
  that do not keep the price the ordinary rules gave them. There is no per-mod table and
  no mod-specific code — the rule is the study's own rule for vanilla packs, and it holds
  for any mod that names an unpack recipe after its yield.
- **A carton holds boxes, not units.** These mods ship both a `RadioTransmitterBox` of
  twelve and a `RadioTransmitterCarton` of twelve boxes. Matching the bare stem for both
  would have priced the carton at twelve transmitters instead of a hundred and forty-four
  — twelvefold short. Outer packs look for the inner pack first, so a carton of twelve
  boxes of twelve comes out at 144 units.

### Internal
- Packs are resolved in a second pass after the index loop, not inline: the sibling a box
  holds may come later in `getAllItems()` than the box does, and a carton has to wait for
  its boxes. Up to three passes, stopping as soon as one changes nothing, so a
  vanilla-only game pays for one pass over an empty list.
- An outer pack will not read an inner pack's price until that one is settled. In the
  first pass it is still whatever the ordinary rules guessed, and reading it then would
  fix the carton at twelve times a guess and mark it done. That is the whole reason the
  passes exist.
- `TC.priceUnknownItem` returns the pack spec alongside the price, from the instance it
  already built. Building a second one would have doubled the cost that makes the first
  open of the buy window take a moment with many item mods installed.

---

## 0.11.3-alpha — 2026-08-29

### Fixed
- **Every modded food listed at $1, whatever its size.** A 10 kg box of dried beans, a
  4 kg box of carrots and a 1 kg sachet of dried basil all came out at a dollar, which
  made a whole mod's worth of "Box of ..." items free money against anything they could
  be resold or eaten as.

  `ruleFood` in `TC_ModPricing.lua` took a `weight` argument and never read it. Calories
  gave the price of one PORTION and nothing gave the number of portions in the package,
  so every food priced as a single serving; the $1 floor underneath then collapsed the
  whole class onto the same number and hid it.

  Food now carries a **bulk factor**. It is the one place weight is the answer rather
  than a nudge: for a rifle against a poker mass tells you nothing, but ten kilos of
  dried beans is ten kilos of dried beans. Calibrated against vanilla rather than taste
  -- over the 705 food items the study prices with a weight, the median runs $1 up to
  0.3 kg, $2 from 0.7 to 1.5 kg, $4 from 1.5 to 3 kg and $15 from 3 to 5 kg, so a case is
  worth about fifteen times a single. The screenshot's boxes now run $2 to $11 by weight
  instead of $1 across the board.

  Mirrored in `tools/rules.ps1`, which is the readable twin of that file.

### Known
- The same class of bug may sit in `ruleLiterature` and `ruleContainer`, which also take
  a `weight` they never read. For those two it is probably right -- a book is priced by
  the skill it teaches and a bag by its capacity, and neither gets more valuable for
  being heavy. Left alone deliberately rather than by omission.

---

## 0.11.2-alpha — 2026-08-29

The study was revised; this imports the revision. It is a better document than the one
0.11.1 read, and it caught two things this mod had wrong.

### Fixed
- **Twenty-seven real items were being withheld from the catalogue.** `TC_EXCLUDED_CATEGORIES`
  dropped `Ears`, `Eye`, `Tail` and thirteen animal names -- `Bear`, `Beaver`, `Dog`,
  `Duck`, `Fox`, `Squirrel` and the rest -- on the reading that they were "live-animal
  categories that exist to carry an animal's data rather than to be an object you own".
  They are not. They are where vanilla files its **plush toys and costume pieces**.
  Spiffo, Spiffo Big, Freddy Fox, Pancho Dog, Moley Mole, Jacques Beaver, a rubber duck, a
  rubber spider, bunny-ear hats, a rabbit's-foot keyring, a dog leash and a pet water dish
  are all buyable now. Five categories are still refused wholesale, all genuinely engine
  states: `Hidden`, `Corpse`, `MaleBody`, `Wound`, `ZedDmg`.
- **194 ids that are not merchandise are refused outright**, through the generated
  `TC_ExcludedItems.lua`: debug and test fixtures, corpses, the wound and bandage overlays
  the health system paints on a body, hair and beard stubble. Leaving them merely unpriced
  would not have worked -- the formula fallback prices whatever the table skips and
  `roundPrice` floors at $1, so `Base.BucketWaterDebug` would have gone on the shelf for a
  dollar.
- **Every item over $999 was being skipped by the importer**, falling through to the
  formula. The study writes prices Brazilian style, so `2.700` is two thousand seven
  hundred and the integer test rejected it. Generators, gold and silver bars, ham radios,
  the antibiotics box. Caught by the row count not adding up: 4,887 + 194 is not 5,092.

### Changed
- **Prices now hold relations, not just values.** A dirty variant is 35% of the clean one,
  a sterilised one 150%, a broken one at most 25%, an opened one at most 80%; a pack is
  worth what its vanilla recipe actually yields, and a full container never less than the
  shell it returns. So a bandage is $10, a dirty one $4, a sterilised one $15 -- and
  `RippedSheets` and `RippedSheetsDirty` are $2 and $1, where 0.11.1 could only show $1
  for both.
- **`TC_Overrides.lua` is empty**, and that is the finished state. Its last two entries
  pinned `AlcoholBandage` at $12 and `RippedSheetsSterilizedBundle` at $5, from when the
  study priced sterilised level with clean and this mod disagreed. The study sets that
  relation by rule now. An override wins outright, so leaving them would have quietly held
  two items below the relation every other item in their family obeys -- an override does
  not just state a price, it opts an item out of every rule the table enforces.
- The importer reads columns **by name**, not by position, and skips any table whose
  header lacks one it needs. The document holds several summary tables that also have an
  `Item ID` and a `Status`; under the old positional read, one of them fed whole lines
  into the price field.

### Known
- 4,898 items are listed, against 5,092 vanilla ids. The buy window's own count is higher
  again when item mods are loaded: that figure is the runtime index, not the vanilla one.

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
