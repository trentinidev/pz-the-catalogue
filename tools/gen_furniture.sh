#!/bin/sh
# Rebuild TC_FurnitureTable.lua from the game's own tile definitions.
#
#     sh tools/gen_furniture.sh [path to newtiledefinitions.tiles.txt]
#
# WHY THIS EXISTS. Only 340 pieces of furniture are items the game ships in
# media/scripts/generated/items/moveable.txt, and those the catalogue has always been
# able to sell. Everything else in the world -- sofas, beds, bookcases, counters,
# fridges -- is a TILE. Picking one up produces a Base.Moveable carrying the sprite
# name, and every one of them shares that single fullType, which is why a china
# cabinet and a road cone were both worth exactly five dollars.
#
# The engine's InventoryItemFactory understands the fullType "Moveables.<sprite>": it
# builds a Base.Moveable and calls ReadFromWorldSprite. So a sprite name is enough to
# BOTH price a piece and hand one over, and a catalogue of furniture is a catalogue of
# sprite names.
#
# WHY OFFLINE. The alternative is sweeping IsoSpriteManager at load. That is thousands
# of sprites and a property read each, on the first open of the buy window, for data
# that only changes when the game does. This is the same trade the price table makes.
#
# SOURCE. media/newtiledefinitions.tiles.txt in the game install -- the text twin of
# the .tiles binary the game actually loads. It is 6.8 MB and is NOT vendored here: it
# belongs to the build. Pass its path if your install is not the Steam default.
#
# WHAT IS KEPT. A tile is a catalogue entry when it has IsMoveAble, has a CustomName,
# and has no CustomItem -- that last one because a CustomItem sprite is already one of
# the 340 items in the index, and listing it twice would put the same chair on the
# shelf at two different prices.
#
# WHAT IS DROPPED, and why each:
#   MoveType = Window        A window in a wall. instanceItem refuses one that has no
#                            SmashedTileOffset, and a catalogue that sells windows is
#                            a building-materials catalogue, which this is not.
#   IsGridExtensionTile      The second and third tiles of a multi-tile piece. The
#                            anchor carries the whole thing; its neighbours are not
#                            separate merchandise.
#   duplicate faces          A chair exists as four sprites, one per direction. They
#                            share a name, a material and a weight, so the first is
#                            kept and the rest fold into it -- the moveable cursor
#                            rotates it back at placement time.
#
# THE NAME. GroupName is the adjective and CustomName is the noun: "Wooden" + "Chair",
# "Premium Technologies" + "Ham Radio". Joined the way ISMoveableSpriteProps joins
# them, so the catalogue calls a thing what the game calls it.
#
# THE CATEGORY. Matched from the noun by the ordered rules below, because the price is
# fixed per category (TC_Furniture.lua holds the money). Ordered and not keyed: "Bar
# Stool" has to reach Seating before "Bar" reaches Counter. Every noun that falls
# through to Misc is reported, and that report is the thing to read after an update.

set -u
cd "$(dirname "$0")/.." || exit 1

SOURCE="${1:-/s/SteamLibrary/steamapps/common/ProjectZomboid/media/newtiledefinitions.tiles.txt}"
OUT="42/media/lua/shared/TheCatalogue/TC_FurnitureTable.lua"

[ -f "$SOURCE" ] || {
    echo "missing $SOURCE" >&2
    echo "pass the path to the game's media/newtiledefinitions.tiles.txt" >&2
    exit 1
}

perl tools/gen_furniture.pl "$SOURCE" "$OUT"
