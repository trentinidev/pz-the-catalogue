#!/usr/bin/perl
# The working half of tools/patch_save_sandbox.sh. Run it through that script, which
# holds the reasoning; this file holds the format.
use strict;
use warnings;

my ($dir, $apply) = @ARGV;
die "usage: patch_save_sandbox.pl <save dir> [--apply]\n" unless $dir;
$apply = defined($apply) && $apply eq '--apply';

my $file = "$dir/map_sand.bin";
die "no map_sand.bin in $dir\n" unless -f $file;

#[[ What this build's defaults say, against what an older build wrote.
#
#   Only same-length values. See the header of the shell script: a value that is not
#   the same number of bytes would mean moving everything after it, and nothing here
#   knows whether some other part of the file counts those bytes.
my @WANT = (
    [ 'PriceMultiplier', '1.0', '5.0' ],
    [ 'SellRatio',       '0.3', '0.1' ],
);

local $/;
open my $in, '<:raw', $file or die "$file: $!";
my $data = <$in>;
close $in;

my $size = length $data;
my ($changed, $already, $refused) = (0, 0, 0);

for my $w (@WANT) {
    my ($name, $old, $new) = @$w;
    my $key = "TheCatalogue.$name";

    my $at = index($data, $key);
    if ($at < 0) {
        printf "  %-20s not in this save -- it will take the new default on its own\n", $name;
        next;
    }

    # writeUTF: two bytes of length, then the bytes. The name is followed immediately
    # by the value, written the same way.
    my $vat = $at + length($key);
    my $len = unpack 'n', substr($data, $vat, 2);
    my $val = substr($data, $vat + 2, $len);

    if ($val eq $new) {
        printf "  %-20s already %s\n", $name, $new;
        $already++;
        next;
    }

    if ($val ne $old) {
        printf "  %-20s is %s, which is neither the old default (%s) nor the new one (%s) -- LEFT ALONE\n",
               $name, $val, $old, $new;
        $refused++;
        next;
    }

    if (length($new) != length($old)) {
        printf "  %-20s %s -> %s would change the length -- REFUSED\n", $name, $old, $new;
        $refused++;
        next;
    }

    substr($data, $vat + 2, $len) = $new;
    printf "  %-20s %s -> %s\n", $name, $old, $new;
    $changed++;
}

die "internal error: file length changed from $size to " . length($data) . ", refusing to write\n"
    unless length($data) == $size;

print "\n";

if (!$changed) {
    print "nothing to change ($already already current, $refused left alone)\n";
    exit 0;
}

if (!$apply) {
    print "$changed value(s) would change. Re-run with --apply to write them.\n";
    exit 0;
}

my $backup = "$file.before-tc-patch";
if (-e $backup) {
    my $n = 1;
    $n++ while -e "$backup.$n";
    $backup = "$backup.$n";
}

open my $b, '>:raw', $backup or die "$backup: $!";
print $b do { open my $o, '<:raw', $file or die $!; <$o> };
close $b;

open my $out, '>:raw', $file or die "$file: $!";
print $out $data;
close $out;

print "written. backup at $backup\n";
