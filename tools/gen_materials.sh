#!/usr/bin/env bash
# Regenerate the material-value table in
#   42/media/lua/shared/TheCatalogue/TC_Materials.lua
# from the precious-material tags in the game's own item scripts.
#
# Vanilla tags jewellery by metal and by stone because its scrapping recipes need to
# (base:tinygoldscrap, base:diamondjewellery, base:2rubyjewellery, ...). Those tags are
# the value signal the price formula lacks, since the formula can only see weight.
#
# Resolved offline rather than at runtime: ScriptItem exposes no getTags() worth relying
# on, and the tag set is fixed for a given build.
#
# Usage:  tools/gen_materials.sh "/path/to/ProjectZomboid/media/scripts/generated/items"
#
# NOTE: the hand-written block at the bottom of TC_Materials.lua (pearl, amber, watches,
# signet rings, trophy pieces -- everything vanilla does not tag) is NOT regenerated.
# Preserve it by hand, or this script will drop it.
set -euo pipefail
G="${1:?path to media/scripts/generated/items}"
awk '
/^[[:space:]]*item [A-Za-z0-9_]+$/ { name=$2; tags="" }
/Tags = / { tags=$0 }
/^[[:space:]]*}/ {
  if (name != "" && tags ~ /goldscrap|silverscrap|jewellery|diamondscrap/) {
    gsub(/^[[:space:]]*Tags = /,"",tags); gsub(/,$/,"",tags); print name "\t" tags
  }
  name=""; tags=""
}' "$G"/*.txt | sort -u
