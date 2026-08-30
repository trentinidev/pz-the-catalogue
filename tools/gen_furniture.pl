#!/usr/bin/perl
# The reading half of tools/gen_furniture.sh. Run it through that script, which holds
# the reasoning; this file holds the rules.
use strict;
use warnings;

my ($src, $out) = @ARGV;
die "usage: gen_furniture.pl <tiles.txt> <out.lua>\n" unless $src && $out;

# Ordered. First match wins, so the specific rule comes before the general one:
# "Bar Stool" must reach Seating before "Bar" reaches Counter, and "Neon Sign" must
# reach Lighting before "Sign" reaches Signage.
my @RULES = (
    [ qr/(tiles?|floors?|carpets?|rugs?|squares)( [A-Z])?$/i                    => q{Flooring}    ],
    [ qr/\b(stool|barstool|chair|chairs|couch|bench|seat|pew|ottoman|seating|futon)\b/i   => 'Seating'     ],
    [ qr/\b(bed|beds|hay|mattress)\b/i                                          => 'Bed'         ],
    [ qr/\b(desk|workstation|workbench|cubicle)\b/i                             => 'Desk'        ],
    [ qr/\b(counter|bar)\b/i                                                    => 'Counter'     ],
    [ qr/\btable\b/i                                                            => 'Table'       ],
    [ qr/\b(shelves|shelf|cabinet|drawers|wardrobe|locker|crate|box|cartbox|chest|rack|stand|bin|dumpster|basket|pegboard|vault|trash|recycle|pallet)\b/i => 'Storage' ],
    # Split out of Appliance because the study prices a fridge at $175 and an oven at
    # $8, and one category cannot hold both without lying about one of them.
    [ qr/\b(fridge|freezer|refrigerator|blood bank)\b/i                          => 'Refrigeration' ],
    [ qr/\b(air conditioner|espresso|oven|microwave|dishwasher|washer|dryer|toaster|barbecue|stove|hood|churn|composter|incinerator)\b/i => 'Appliance' ],
    [ qr/\b(neon sign|lamp|lights|light|chandelier|candle)\b/i                   => 'Lighting'    ],
    # Same split, same reason: the study puts a desktop computer at $355 and a rotary
    # phone at pocket money.
    [ qr/\b(computer|terminal|monitors|hk533p)\b/i                               => 'Computer'   ],
    [ qr/\b(radio|phone|phones|amplifier|speaker|jukebox|microphone|projector|walkie|antenna|dish|register|microscope|scale|meter|jukebox|soda machine|popcorn machine|bowling machine)\b/i => 'Electronics' ],
    [ qr/\b(sink|toilet|shower|bath|standpipe|trough|bloodbag)\b/i               => 'Plumbing'    ],
    [ qr/\b(curtain|canopy|bunting|window|blinds)\b/i                            => 'Drapery'     ],
    [ qr/\b(ecstacy of gold|painting|paintings|picture|poster|certificate|drawing|banner|flag|mirror|statue|bust|dartboard|clock|whiteboard|noteboard|piano|skull|cross|gravestone|coffin|altar|trophy|flamingo|gnome|spiffo|mannequin|decoration|comb|deer)\b/i => 'Art' ],
    [ qr/\b(sign|notices|menu|map|display|target|signal|certificate)\b/i          => 'Signage'     ],
    [ qr/\b(plant|tree|fern|ficus|cactus|roses|flowers|bonsai|hedge|bush|flowerbed|plantbed|evergreen|venus fly trap|salt lick)\b/i => 'Plant' ],
    [ qr/\b(machine|press|grinder|grindstone|slab|loom|quern|wheel|blower|forge|burner|drum|barrel|tire|tires|truck|ladder|ladders|distaff|dispenser|turnstile|slide|castle|golf put|contraption|helper|industrial|x-press|grinder)\b/i => 'Industrial' ],
    [ qr/\b(merry go round|dog house|cone|barrier|pole|post|beam|block|board|pillar|wall|fence|trailer|hydrant|ladder)\b/i => 'Outdoor' ],
);

my (@rows, %seen, %bysprite, %fell);

open my $fh, '<', $src or die "$src: $!";
my ($sprite, $in, %p);
while (my $line = <$fh>) {
    if ($line =~ m{^\s*//\s*(\S+)\s*$}) { $sprite = $1; next }
    if ($line =~ /^\s*tile\s*$/)        { $in = 1; %p = (); next }

    if ($in && $line =~ /^\s*\}/) {
        $in = 0;
        next unless exists $p{IsMoveAble};

        my $noun = $p{CustomName} // '';
        next if $noun eq '';
        next if exists $p{CustomItem};
        next if exists $p{IsGridExtensionTile};
        next if ($p{MoveType} // '') eq 'Window';

        my $group  = $p{GroupName} // '';
        my $raw    = $p{PickUpWeight} // 50;
        my $weight = $raw / 10;

        my $key = join "\x1f", $group, $noun, $p{Material} // '', $raw;
        next if $seen{$key}++;

        # A closed curtain instances as its open twin. This is vanilla's own
        # correction in ISMoveableSpriteProps:instanceItem, applied here so the stored
        # sprite is the one the engine would have used anyway.
        my $spr = $sprite;
        if (($p{MoveType} // '') eq 'WindowObject' && exists $p{IsClosedState}) {
            $spr =~ s/^(.*)_(\d+)$/$1 . '_' . ($2 + 4)/e;
        }

        # A second dedupe, on the FINAL sprite. The correction just above rewrites a
        # closed curtain to its open twin, and that twin is usually a tile in its own
        # right -- so two rows can arrive at one sprite, and the catalogue would list
        # the same curtain twice at the same price.
        next if $bysprite{$spr}++;

        my $name = $group ne '' ? "$group $noun" : $noun;

        # The noun first, then the whole name. The noun is the thing, so it decides
        # where a piece belongs -- but the split between GroupName and CustomName is
        # not always where the grammar would put it. "Bar Tap" + "Antique" leaves the
        # noun as an adjective, and only the full name still says bar.
        my $cat = 'Misc';
        for my $subject ($noun, $name) {
            for my $r (@RULES) {
                if ($subject =~ $r->[0]) { $cat = $r->[1]; last }
            }
            last if $cat ne 'Misc';
        }
        $fell{$name}++ if $cat eq 'Misc';

        $name =~ s/\\/\\\\/g;
        $name =~ s/"/\\"/g;

        push @rows, [ $spr, $name, $cat, $weight ];
        next;
    }

    if ($in && $line =~ /^\s*(\w+)\s*=\s*(.*?)\s*$/) { $p{$1} = $2 }
}
close $fh;

@rows = sort { $a->[1] cmp $b->[1] || $a->[0] cmp $b->[0] } @rows;

open my $o, '>', $out or die "$out: $!";
print $o <<'HEAD';
--[[ The Catalogue -- furniture, generated. DO NOT EDIT.

     Rebuilt by `sh tools/gen_furniture.sh` from the game's own tile definitions. The
     header of that script says what is kept, what is dropped, and why each; read it
     there rather than trusting this file to stay in step with it.

     One row per piece of furniture the catalogue sells:
       s   the world sprite, which is also the fullType as "Moveables." .. s -- the
           engine's InventoryItemFactory reads that prefix and builds a placeable
           Moveable from it.
       n   the name the game gives it: GroupName then CustomName.
       c   the category its price comes from. The money is hand-set per category in
           TC_Furniture.lua, which is the file to edit when a sofa costs too much.
       w   weight, PickUpWeight/10, the same figure the game puts on the item.
]]

TheCatalogue = TheCatalogue or {}
local TC = TheCatalogue

TC.FURNITURE = {
HEAD
printf $o qq{    { s = "%s", n = "%s", c = "%s", w = %.1f },\n}, @$_ for @rows;
print $o "}\n";
close $o;

printf STDERR "furniture   %d pieces written to %s\n", scalar @rows, $out;
my %bycat;
$bycat{ $_->[2] }++ for @rows;
printf STDERR "  %-12s %4d\n", $_, $bycat{$_} for sort { $bycat{$b} <=> $bycat{$a} } keys %bycat;
if (%fell) {
    printf STDERR "\n%d noun(s) fell through to Misc:\n  %s\n",
        scalar keys %fell, join ", ", sort keys %fell;
}
