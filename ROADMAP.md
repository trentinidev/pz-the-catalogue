# Roadmap

What is deliberately not built yet, and why. Everything here was considered and parked
on purpose -- none of it is rejected. Landed work lives in [CHANGELOG.md](CHANGELOG.md);
this file is the other half of that story.

Current version: **0.9.2-alpha**. `1.0.0` is reserved for the first build that has been
played end to end and is safe on a dedicated server.

---

## Blocking 1.0

### 1. Multiplayer / server authority

Every transaction runs client-side today, so on a dedicated server the mod is trivially
cheatable. Deferred rather than half-done: prices, money deduction and order state all
have to move behind server commands together. Single-player is honest about this in the
README and the mod description.

### 2. Workshop packaging

`workshop.txt` and `preview.png`, plus making `trentinidev/pz-the-catalogue` public.
Mechanical work, but it is what turns the mod from a folder into a release.

---

## Content and economy

### 3. Limited stock and scarcity

Stock is infinite. Finite stock with restocking would give buying a real sense of
scarcity, but it needs stock levels that survive a save -- and PZ has no save hook, so
the state has to live on `player:getModData()` like the ledger does.

### 4. Used and clearance goods

Occasional discounted offers at a predefined condition, so the catalogue is not always
mint-condition stock. The condition-scaling code the sell window already uses would do
most of the work.

### 5. Dynamic economy

Prices and availability drifting with weeks survived: medicine and ammunition climb,
decoration falls. Cheap to fake with a multiplier over `TC_PriceTable`, expensive to
make feel deliberate rather than random.

### 6. Catalogue inserts

Flavour pages bound into the catalogue -- adverts, notices, a company voice. Pure
presentation, no mechanics.

---

## Presentation

### 7. PT-BR translation

English only for now. Cheap to revisit: the JSON translation format and the
key-prefix-decides-the-file rule are both written down in `CLAUDE.md`, which is what made
this expensive the first time.

### 8. Hand-made parcel models

The three delivery tiers share vanilla's `Base.Parcel_ExtraLarge` mesh and differ only by
icon. Vitor is modelling the oversized parcels by hand; the script definitions in
`42/media/scripts/thecatalogue.txt` are ready for them.

---

## Struck off -- already shipped

Kept here so nothing on the list gets proposed twice:

- Orders with delivery time, and physical delivery to a container
- Shipping cost and Economy / Standard / Express tiers
- Cancelling an order, and refusing it at the door
- The recipe that bundles 100 loose notes
- Affordable / owned / not-owned filters, and the per-character wishlist
- B42 fluid containers handled in the condition scaling
- Requiring the catalogue in hand while the window is open
- Mod-item integration: other mods' items priced by the same rules and filterable by
  source mod
