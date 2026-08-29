#!/bin/sh
# Rebuild TC_PriceTable.lua from the vanilla price study.
#
#     sh tools/import_prices.sh
#
# WHAT CHANGED IN 0.11.1. Prices used to be GENERATED, by tools/gen_prices.ps1 reading
# the game's item scripts and applying the category rules in tools/rules.ps1. That
# formula could see category, weight, calories, MaxDamage, Capacity -- everything an item
# DECLARES -- and nothing about what an item is FOR. It could not know that a hunting
# rifle matters more than a fireplace poker of the same mass, which is why 186 hand
# overrides existed to argue with it.
#
# tools/reference/PZ_prices_B42.20.4.md prices all 5,092 vanilla ids one at a time, from
# 1993 US replacement cost and then survival utility in Knox County. It reasons about
# exactly what the formula could not. So the table is IMPORTED from it now rather than
# derived, and this script is what makes that reproducible from a clean clone.
#
# The study's figures are already in dollars -- 1 Cr is about one nominal 1993 dollar --
# so TC.PRICE_SCALE is 1.0 and what is written here is what the player is shown.
#
# Column 2 of each row is the id in backticks, column 6 is the value in Cr with a comma
# for the decimal point. Rows with fewer than six columns belong to the summary tables
# earlier in the document and are skipped by the shape of the pattern alone.

set -u
cd "$(dirname "$0")/.." || exit 1

SOURCE="tools/reference/PZ_prices_B42.20.4.md"
OUT="42/media/lua/shared/TheCatalogue/TC_PriceTable.lua"

[ -f "$SOURCE" ] || { echo "missing $SOURCE" >&2; exit 1; }

rows=$(mktemp) || exit 1
trap 'rm -f "$rows"' EXIT

sed -E -n 's/^\| *[^|]* *\| *`([^`]+)` *\| *[^|]* *\| *[^|]* *\| *[^|]* *\| *([0-9.,]+) *\|.*/\1\t\2/p' \
    "$SOURCE" \
    | awk -F'\t' '{ v=$2; gsub(/\./,"",v); gsub(/,/,".",v); printf "%s\t%s\n", $1, v }' \
    | sort -u > "$rows"

count=$(wc -l < "$rows" | tr -d ' ')
[ "$count" -gt 4000 ] || { echo "only $count rows parsed -- the document's shape changed" >&2; exit 1; }

{
cat <<'HEADER'
--[[ The Catalogue -- the price table.

     GENERATED FILE. Do not edit by hand: tools/import_prices.sh rewrites it wholesale
     from tools/reference/PZ_prices_B42.20.4.md. To change one price permanently, add it
     to TC_Overrides.lua, which wins over this table.

     IMPORTED, NOT DERIVED, since 0.11.1. It used to be computed from the item scripts by
     tools/gen_prices.ps1: category, weight, calories, MaxDamage, Capacity -- everything
     an item DECLARES. That formula could not know what an item is FOR, which is why a
     hunting rifle and a fireplace poker of the same mass came out alike and why 186 hand
     overrides existed to argue with it. The study prices every id one at a time, from
     1993 replacement cost and then survival utility in Knox County, so it reasons about
     precisely what the formula could not.

     Values are in dollars already -- the study's Cr is about one nominal 1993 dollar --
     so TC.PRICE_SCALE is 1.0 and these figures are what the player is shown, before the
     sandbox PriceMultiplier.

     Sorted by id. The old file grouped by display category, which needed the game
     installed to work out; a flat sort is reproducible anywhere and diffs cleanly.
]]

TheCatalogue = TheCatalogue or {}

TheCatalogue.PRICE_TABLE = {
HEADER

awk -F'\t' '{
    v = $2 + 0
    if (v == int(v)) printf "    [\"%s\"] = %d,\n", $1, v
    else             printf "    [\"%s\"] = %.2f,\n", $1, v
}' "$rows"

echo "}"
} > "$OUT"

echo "prices   $count ids imported into $OUT"
