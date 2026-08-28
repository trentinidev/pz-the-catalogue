#!/bin/sh
# The Catalogue -- everything that can be checked without launching the game.
#
#     sh tools/check.sh
#
# Also run automatically before every commit; see .githooks/pre-commit.
#
# WHY THIS EXISTS. Up to 0.6.5 the only verification was grep: keys used against keys
# defined, TC.* called against TC.* defined. Those catch a lot, and they caught real
# bugs -- but they cannot catch a syntax error, and a released version shipped a ledger
# that threw the moment it was opened. This closes the cheap half of that gap. The
# expensive half, behaviour, is still on testing in game.
#
# LuaJIT rather than Lua 5.4: Project Zomboid runs Kahlua, a Lua 5.1 VM, and LuaJIT 2.1
# is the closest widely available parser to 5.1. A 5.4 parser would cheerfully accept
# goto, integer division and bitwise operators that Kahlua rejects at load time.

set -u
cd "$(dirname "$0")/.." || exit 1

# In PATH if the shell has been restarted since the install; at the MSI's own location
# if not, which is where winget's DEVCOM.LuaJIT puts it.
if command -v luajit >/dev/null 2>&1; then
    LUA="$(command -v luajit)"
else
    LUA="$LOCALAPPDATA/Programs/LuaJIT/bin/luajit.exe"
fi

LUA_DIR="42/media/lua"
TRANSLATE="$LUA_DIR/shared/Translate/EN"
fail=0

note() { printf '%s\n' "$*"; }
bad()  { printf 'FAIL  %s\n' "$*"; fail=1; }

# --- 1. Lua syntax ---------------------------------------------------------------
if [ ! -x "$LUA" ]; then
    bad "luajit not found -- syntax UNCHECKED. winget install DEVCOM.LuaJIT"
else
    n=0
    for f in $(find "$LUA_DIR" -name '*.lua' | sort); do
        n=$((n + 1))
        if ! msg=$("$LUA" -e "local f, e = loadfile([[$f]]); if not f then io.stderr:write(e) os.exit(1) end" 2>&1); then
            bad "syntax: $msg"
        fi
    done
    note "syntax    $n Lua file(s) parsed clean"
fi

# --- 2. Translation JSON ----------------------------------------------------------
j=0
for f in "$TRANSLATE"/*.json; do
    [ -e "$f" ] || continue
    j=$((j + 1))
    out=$("$LUA" tools/json_check.lua "$f" 2>&1) || bad "json: $out"
done
note "json      $j translation file(s) balanced, no duplicate keys"

# --- 3. Translation keys ----------------------------------------------------------
# Both directions. A key used with no definition renders as its own raw name in game,
# which is how the whole JSON migration went unnoticed; a key defined and never used is
# usually the leftover of a rename and the next person to grep for it wastes their time.
used=$(grep -rhoE '"[A-Za-z]+_TC_[A-Za-z0-9_]+"' --include=*.lua "$LUA_DIR" | tr -d '"' | sort -u)
defined=$(grep -rhoE '^[[:space:]]*"[A-Za-z]+_TC_[A-Za-z0-9_]+"' "$TRANSLATE"/*.json | tr -d ' "' | sort -u)

missing=$(printf '%s\n' "$used"    | grep -vxF "$defined" || true)
orphan=$( printf '%s\n' "$defined" | grep -vxF "$used"    || true)
[ -z "$missing" ] || bad "translation key(s) used with no definition:$(printf '\n    %s' $missing)"
[ -z "$orphan" ]  || bad "translation key(s) defined but never used:$(printf '\n    %s' $orphan)"
note "keys      $(printf '%s\n' "$used" | wc -l | tr -d ' ') used, all defined and all reachable"

# --- 4. TC.* helpers --------------------------------------------------------------
calls=$(grep -rhoE '\bTC\.[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(' --include=*.lua "$LUA_DIR" \
        | sed 's/[( 	]*$//' | sort -u)
defs=$(grep -rhoE '^function TC\.[a-zA-Z_][a-zA-Z0-9_]*' --include=*.lua "$LUA_DIR" \
       | sed 's/^function //' | sort -u)
undefined=$(printf '%s\n' "$calls" | grep -vxF "$defs" || true)
[ -z "$undefined" ] || bad "TC helper(s) called but never defined:$(printf '\n    %s' $undefined)"
note "helpers   $(printf '%s\n' "$calls" | wc -l | tr -d ' ') TC.* call site(s), all defined"

# --- 5. A method defined twice in one file ----------------------------------------
# The second definition silently wins, so this is always a mistake, never a warning.
dupes=""
for f in $(find "$LUA_DIR" -name '*.lua'); do
    d=$(grep -oE '^function [A-Za-z_][A-Za-z0-9_]*[:.][a-zA-Z0-9_]+' "$f" | sort | uniq -d)
    [ -z "$d" ] || dupes="$dupes$(printf '\n    %s: %s' "$f" "$d")"
done
[ -z "$dupes" ] || bad "method defined more than once:$dupes"
note "dupes     no method defined twice"

# --- 6. The version has been written down -----------------------------------------
# Bumping mod.info and forgetting the changelog is the easiest thing here to get wrong,
# because nothing in the game ever notices.
v=$(grep -oE '^modversion=.*' 42/mod.info | cut -d= -f2 | tr -d '\r')
if grep -q "^## $v " CHANGELOG.md; then
    note "version   $v, with a changelog entry"
else
    bad "CHANGELOG.md has no entry for modversion $v"
fi

if [ $fail -eq 0 ]; then
    note ""
    note "all checks passed"
fi
exit $fail
