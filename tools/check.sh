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

# --- 6. Every icon and texture a script asks for actually exists ---------------
# A missing one is silent: the game renders nothing, or a placeholder, and the script
# that named it is never blamed.
missingArt=""
for i in $(grep -ohE "Icon = [A-Za-z0-9_]+" 42/media/scripts/*.txt | sed "s/Icon = //" | sort -u); do
    [ -f "42/media/textures/Item_$i.png" ] || missingArt="$missingArt$(printf '
    icon Item_%s.png' "$i")"
done
for t in $(grep -ohE "texture = [A-Za-z0-9_/]+" 42/media/scripts/*.txt | sed "s/texture = //" | sort -u); do
    [ -f "42/media/textures/$t.png" ] || missingArt="$missingArt$(printf '
    texture %s.png' "$t")"
done
[ -z "$missingArt" ] || bad "art referenced by a script but not present:$missingArt"
note "art       every Icon and texture a script names is on disk"

# --- 7. Every mesh a model block asks for --------------------------------------
# Ours must be in the repo. A vanilla one is checked against the game install when this
# machine has one, and reported as unverified when it does not -- better than pretending
# either way.
GAME_MODELS="S:/SteamLibrary/steamapps/common/ProjectZomboid/media/models_X"
missingMesh=""; vanillaUnchecked=0
for m in $(grep -ohE "mesh = [A-Za-z0-9_/]+" 42/media/scripts/*.txt | sed "s/mesh = //" | sort -u); do
    if [ -f "42/media/models_X/$m.fbx" ] || [ -f "42/media/models_X/$m.x" ]; then
        continue
    elif [ -d "$GAME_MODELS" ]; then
        [ -f "$GAME_MODELS/$m.fbx" ] || [ -f "$GAME_MODELS/$m.FBX" ] || [ -f "$GAME_MODELS/$m.x" ] \
            || missingMesh="$missingMesh$(printf '\n    %s' "$m")"
    else
        vanillaUnchecked=$((vanillaUnchecked + 1))
    fi
done
[ -z "$missingMesh" ] || bad "mesh referenced by a model block but not found:$missingMesh"
if [ "$vanillaUnchecked" -gt 0 ]; then
    note "mesh      ours present; $vanillaUnchecked vanilla mesh(es) unverified, no game install here"
else
    note "mesh      every mesh a model block names is present"
fi

# --- 8. The version has been written down -----------------------------------------
# Bumping mod.info and forgetting the changelog is the easiest thing here to get wrong,
# because nothing in the game ever notices.
v=$(grep -oE '^modversion=.*' 42/mod.info | cut -d= -f2 | tr -d '\r')
if grep -q "^## $v " CHANGELOG.md; then
    note "version   $v, with a changelog entry"
else
    bad "CHANGELOG.md has no entry for modversion $v"
fi

# The version string the mod prints into console.txt must match mod.info. That banner is
# how a log tells you which build was in memory, and a stale one would say the opposite of
# the truth -- worse than no banner at all.
lua_v=$(grep -oE 'TC\.VERSION = "[^"]+"' 42/media/lua/shared/TheCatalogue/TC_Config.lua | sed 's/.*"\(.*\)"/\1/')
if [ "$lua_v" = "$v" ]; then
    note "banner    TC.VERSION matches mod.info"
else
    bad "TC.VERSION is \"$lua_v\" but mod.info says \"$v\""
fi

# A CONSTANT read from a file that never declared it.
#
# Every window here opens with file locals in SCREAMING_CASE -- PAD, ROW_HGT,
# BUTTON_HGT, FONT_HGT_SMALL. They are locals, so a second file that names one gets a
# GLOBAL read instead, which is nil, and nil + 10 kills the window at runtime. That is
# how 0.10.0 shipped a rail that crashed the moment it was built: TC_UI.lua reached for
# a FONT_HGT_SMALL that only exists inside each window file.
#
# It is Lua that parses perfectly, so the syntax check above cannot see it. LuaJIT can:
# -bl dumps the bytecode, and every global read appears as a GGET naming the symbol. A
# global in SCREAMING_CASE is always this mistake -- the engine's own globals are
# camelCase (getTextManager) or PascalCase (ISButton), never all caps -- so the rule
# needs no allowlist to maintain.
if [ -n "${LUA:-}" ] && [ -x "$LUA" ] || command -v "${LUA:-luajit}" >/dev/null 2>&1; then
    consts=""
    for f in $(find "$LUA_DIR" -name "*.lua" | sort); do
        found=$("$LUA" -bl "$f" 2>/dev/null \
                | grep 'GGET' \
                | sed -E 's/.*; "([^"]+)".*/\1/' \
                | grep -E '^[A-Z][A-Z0-9_]*$' \
                | sort -u)
        for name in $found; do
            consts="$consts $(basename "$f"):$name"
        done
    done

    if [ -z "$consts" ]; then
        note "consts    no file reads a CONSTANT another file declared as a local"
    else
        for hit in $consts; do
            bad "undeclared constant read: $hit -- it is a file local somewhere else"
        done
    fi
fi

if [ $fail -eq 0 ]; then
    note ""
    note "all checks passed"
fi
exit $fail
