# The Catalogue — working notes for Claude

Read `README.md` first. It carries the design reasoning: why money is physical and
weight is the balance lever, why the sell window stages references instead of moving
items, and why both lists cull their own rows. Do not re-litigate those three.

Then read `memory-claude.md`.

## Memory

`memory-claude.md` is shared long-term memory, committed so it survives the trip between
machines — Claude's own memory is per-machine and does not travel. Read it at the start
of every session in this repo, and append to it when a decision is made, a hypothesis is
disproved, or a branch changes state. Not for routine edits; git already has those.

## Layout

- `42/media/lua/client/` — UI and anything that touches the player. `TC_BuyWindow.lua`
  and `TC_SellWindow.lua` are ~950 lines each and hold most of the complexity.
- `42/media/lua/shared/` — pricing, config, history, API. Loads on client and server,
  so nothing in here may touch the world.
- `42/media/lua/server/Items/` — loot distribution only.
- `tools/` — offline generators. Not shipped to players.
- `42/mod.info` — `modversion` is bumped by hand on release.

## Pricing has four layers, most specific first

1. `TC_Overrides.lua` — 171 hand-set prices. Win outright.
2. `TC_PriceTable.lua` — **generated, never edit by hand.** 4,916 vanilla items.
3. `TC_ModPricing.lua` — runtime pricing for modded items.
4. `TC_Prices.lua` — category-and-weight fallback of last resort.

`TC_ModPricing.lua` encodes the same judgements as `tools/rules.ps1`. **Change the two
together** or vanilla and modded items drift apart in price.

## Regenerating the price table

If pricing rules change in `tools/rules.ps1`, `TC_PriceTable.lua` must be regenerated:

```
pwsh tools/gen_prices.ps1 "<PZ install>\media\scripts\generated\items"
```

`$ItemsDir` is mandatory and points at an **installed copy of Project Zomboid**. This
only runs on a machine that has the game. On a machine without it, changing
`tools/rules.ps1` leaves the table stale — say so explicitly rather than committing a
rules change that looks complete and is not.

## Testing

There is no test suite and there cannot be one: Lua errors in a PZ mod surface only at
runtime, inside the game, and PZ loads Lua at startup — so every test round is a full
game restart. Anything not run in the game is unverified. Say that plainly instead of
implying a change is working.

## Two machines

This repo is edited from a home PC (has the game) and a work PC (does not).

`main` only ever holds code that has run in the game. Work-PC changes go on a branch,
are pushed, and are merged into `main` at home after they have actually been played.
The home PC links its mods folder at the repo with a junction, so `git switch` there
changes the installed mod directly — no copying, and a branch can be tested as it is.

Never run `git push` or `git pull` without showing Vitor what will move and getting a
yes first. This holds on both machines.

## Conventions

- `.gitattributes` normalises everything to LF. Do not fight it.
- Comments explain *why*, in full sentences, and are dense where the game forced the
  decision. Match that; do not add comments that restate the code.
- Commit subjects are lowercase prose describing the effect, not the file touched
  ("Make the buy window open fast again"). No conventional-commit prefixes.
- UI strings go through the JSON files in `42/media/lua/shared/Translate/EN/`, never
  inline in Lua.
