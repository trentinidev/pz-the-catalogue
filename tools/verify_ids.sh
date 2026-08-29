#!/bin/sh
# Every id in TC_Overrides.lua, checked against the game's own item scripts.
#
#     sh tools/verify_ids.sh "<PZ install>/media/scripts/generated/items"
#
# WHY THIS EXISTS. A mistyped id in the overrides table is not a runtime error. The
# lookup simply misses, the item falls through to the formula, and the hand-set price is
# silently ignored -- so the failure looks exactly like "the formula priced it oddly".
# TC_Overrides.lua has claimed this script exists since it was written; it did not, and
# the 186 ids in it had never been checked against anything.
#
# NOT part of tools/check.sh, and it cannot be: it needs an installed copy of the game,
# which the GitHub runner does not have. Run it by hand after editing the overrides.

set -u
cd "$(dirname "$0")/.." || exit 1

SCRIPTS="${1:-}"
if [ -z "$SCRIPTS" ] || [ ! -d "$SCRIPTS" ]; then
    echo "usage: sh tools/verify_ids.sh \"<PZ install>/media/scripts/generated/items\"" >&2
    exit 2
fi

OVERRIDES="42/media/lua/shared/TheCatalogue/TC_Overrides.lua"

game=$(mktemp) || exit 1
ours=$(mktemp) || exit 1
trap 'rm -f "$game" "$ours"' EXIT

grep -rhoE "^[[:space:]]*item [A-Za-z0-9_]+" "$SCRIPTS" \
    | sed -E 's/^[[:space:]]*item //' | sort -u > "$game"

grep -oE '\["Base\.[A-Za-z0-9_]+"\]' "$OVERRIDES" \
    | sed -E 's/\["Base\.([^"]+)"\]/\1/' | sort -u > "$ours"

missing=$(comm -23 "$ours" "$game")

if [ -z "$missing" ]; then
    echo "ids       $(wc -l < "$ours" | tr -d ' ') override(s), every one of them a real vanilla item"
    exit 0
fi

echo "$missing" | while read -r id; do
    [ -n "$id" ] && echo "FAIL  Base.$id is in TC_Overrides.lua and not in the game scripts"
done
exit 1
