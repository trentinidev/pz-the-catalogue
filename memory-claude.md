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

- **Version:** 1.2.1 (`42/mod.info`), targeting B42 42.20+.
- **Machines:** home PC has Project Zomboid installed and is the only place the mod can
  be run or the price table regenerated. Work PC has the repo only — no game, no
  `media/scripts/generated/items`, so `tools/gen_prices.ps1` cannot run there.
- **Branch policy:** `main` only ever holds code that has actually run in the game.
  Work-PC changes land on a branch and are merged at home after testing.
- **Open branches:** `changes-work-pc` — created 2026-08-27, no commits yet.
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
