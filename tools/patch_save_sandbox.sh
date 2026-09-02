#!/bin/sh
# Bring a save that is already in progress onto this build's sandbox defaults.
#
#     sh tools/patch_save_sandbox.sh [save dir]          # say what would change
#     sh tools/patch_save_sandbox.sh [save dir] --apply  # change it
#
# With no directory it takes the most recently written save under Zomboid/Saves/Sandbox.
#
# WHY THIS IS NEEDED AT ALL. Changing a `default =` in sandbox-options.txt, or a value
# in TC_Config's DEFAULTS table, only reaches a save that does not already have an
# answer. A save WRITES every option it knows about at creation, so one made while this
# mod was installed already holds PriceMultiplier and SellRatio, and it keeps holding
# them for good. TC.opt reads the save first, on purpose -- a player's setting must beat
# our default -- so a new default is invisible to every existing game. 0.13.0-beta
# changed both numbers and none of it reached the save being played at the time.
#
# WHY NOT DO IT IN LUA. A mod that quietly rewrites sandbox values is a mod that
# overrules the player, and it cannot tell "never touched this" from "chose exactly the
# old number". Doing it here means it happens once, visibly, to a named save, with a
# backup, and only when somebody asks for it.
#
# THE FORMAT. map_sand.bin is a flat run of Java writeUTF pairs: two bytes of length
# then the bytes, name followed by value, and the value is a STRING even when the option
# is a double -- "1.0", "0.3", "true", "20".
#
# SAME LENGTH ONLY, and that is the whole safety argument. "1.0" -> "5.0" and
# "0.3" -> "0.1" are three bytes for three bytes, so not one byte after them moves and
# nothing else in the file can be describing an offset that just went stale. A value
# that would change length is refused rather than guessed at. The script also refuses a
# value that is neither the old default nor the new one, because that is a setting
# somebody chose and it is not ours to overwrite.
#
# CLOSE THE GAME FIRST. Project Zomboid holds the save open and rewrites map_sand.bin
# when it exits, so a patch applied underneath a running game is thrown away at best.
# The script checks and refuses.

set -u
cd "$(dirname "$0")/.." || exit 1

SAVES="$HOME/Zomboid/Saves/Sandbox"
DIR="${1:-}"
APPLY=""

# Either argument may be the flag, so a bare `--apply` still finds the newest save.
for a in "${1:-}" "${2:-}"; do
    [ "$a" = "--apply" ] && APPLY="--apply"
done
[ "$DIR" = "--apply" ] && DIR=""

if [ -z "$DIR" ]; then
    DIR=$(ls -1dt "$SAVES"/*/ 2>/dev/null | head -1)
    [ -n "$DIR" ] || { echo "no save found under $SAVES" >&2; exit 1; }
    DIR=${DIR%/}
fi

[ -f "$DIR/map_sand.bin" ] || { echo "no map_sand.bin in $DIR" >&2; exit 1; }

if tasklist 2>/dev/null | grep -qi "ProjectZomboid"; then
    echo "Project Zomboid is running. Quit to the desktop first -- it rewrites" >&2
    echo "map_sand.bin on exit and would throw this away." >&2
    exit 1
fi

echo "save: $DIR"
echo
perl tools/patch_save_sandbox.pl "$DIR" $APPLY
