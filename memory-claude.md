# Shared memory

Long-term memory for this mod, shared between the two machines. Claude's automatic
memory is per-machine and does not travel; this file is committed, so it does.

**For Claude, on either machine:**

- Read this file at the start of any session in this repo.
- Append to the log when a decision is made, a hypothesis is disproved, or a branch
  changes state. Do not append routine edits — the git history already has those.
- Newest entry at the bottom. Tag every entry with the date and the machine.
- Keep "Current state" accurate. It is the section that goes stale first and it is the
  one most worth trusting.
- Never delete a log entry. If something written here turns out to be wrong, add a new
  entry saying so and edit the old one to point at it.

Written in English to match the rest of the repo. Vitor writes in Portuguese; entries
quoting him may be in Portuguese.

---

## Current state

- **Version:** 1.2.2 (`42/mod.info`), targeting B42 42.20+.
- **Machines:** home PC has Project Zomboid installed and is the only place the mod can
  be run or the price table regenerated. Work PC has the repo only — no game, no
  `media/scripts/generated/items`, so `tools/gen_prices.ps1` cannot run there.
- **Repo location at home:** the clone **is** the installed mod —
  `C:\Users\vitor\Zomboid\mods\TheCatalogue` is the working tree itself. There is no
  junction or symlink; an earlier entry said there was, see 2026-08-27 (home PC).
- **Branch policy:** `main` only ever holds code that has actually run in the game.
  Work-PC changes land on a branch and are merged at home after testing.
- **Open branches:** none visible from the home PC. `changes-work-pc` was logged as
  created on the work PC but has never been pushed, so it does not exist here.
- **Standing instruction from Vitor:** never run `git push` or `git pull` without
  showing him what will move and getting a yes first. Applies on both machines.

---

## Log

### 2026-08-27 — work PC

Repo cloned on the work PC for the first time. Established that this machine can edit
but never verify: PZ loads Lua at startup and there is no game here, so anything written
on this machine is unverified until it runs at home.

Found a hard limit that was not obvious from the README: `tools/gen_prices.ps1` takes a
mandatory `$ItemsDir` pointing at an installed copy of the game. Changing
`tools/rules.ps1` on the work PC therefore leaves `TC_PriceTable.lua` stale, and the
commit looks complete when it is not. Regeneration is a home-PC task, always.

Added `CLAUDE.md` and this file so the reasoning stops dying with each machine's local
memory.

> Two statements in this entry and in `CLAUDE.md` turned out to be wrong when checked
> against the home PC. See **2026-08-27 — home PC** below.

### 2026-08-27 — home PC

Pulled the work-PC commit. Checked its claims against the machine; two were wrong.

**There is no junction.** `CLAUDE.md` said the home PC links its mods folder to the repo
with one. `dir /AL` on the mods folder reports no reparse point and
`git rev-parse --show-toplevel` answers `C:\Users\vitor\Zomboid\mods\TheCatalogue`. The
clone simply *is* the installed mod. The described effect was right — `git switch`
changes the installed mod directly — but the mechanism was invented, and someone acting
on it would go looking for a link that is not there. `CLAUDE.md` has been corrected.

**`changes-work-pc` does not exist here.** It is logged under Current state as created,
but it is on neither the local nor the remote refs. A branch with no commits and no push
does not travel, which is a limit worth knowing: this file can only usefully track
branch state for branches that have been pushed.

**Tested in game (Vitor), 1.2.1:** error spam gone; column headings fit; favourite
rescued from a sold container; wishlist persists across reload; dropping the catalogue
closes both windows; cart works; ledger survives reload; content tree works; bulk
staging works.

**Found and fixed as 1.2.2:**

- A wishlisted item inside a sold container was destroyed while a favourite in the same
  bag was rescued. The star now behaves exactly like a favourite in all three places
  that must agree — staged directly, rescued from a container, marked "kept" in the
  tree. **Decision, with a known cost:** the wishlist is strictly a shopping list, so
  protecting what you already own stretches its meaning, and spares of a starred item
  can no longer be bulk-sold without unstarring first. Chosen because a star reads as
  "I care about this". Revisit if it turns out to annoy in play.
- The cart checked out instantly while a single purchase waited out the order action,
  which made the cart the fast way to shop mid-fight. Both paths now use
  `TC_OrderAction`.
- Ledger columns were hardcoded pixel positions and collided at Vitor's UI scale.
  Measured now — and measured on first use, not at file load, because one width comes
  from a translated string and translations are not guaranteed loaded that early.

**Not a bug, recorded so it is not re-investigated:** a half-full bottle appearing to
sell for the same as a full one is the item being cheap, not fluids being ignored. Two
full bottles at $3 would pay $5; two part-full paid $2. Test fill ratio on a petrol can
or bleach.

**Still true:** `main` holds code that has not been played — FEAT-05 (the public API,
needs a consumer mod) and FEAT-18 (loot spawns, needs unexplored map) are unverified,
and 1.2.2 itself is untested. The branch policy in `CLAUDE.md` is aspirational until
those land.

**Next, agreed with Vitor:** FIX-12 (the timing and loot prints are always on and would
spam a released mod's console), then splitting `TC_BuyWindow.lua` and
`TC_SellWindow.lua`, which are ~960 lines each and where every UI regression so far has
come from.
