#!perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
use strict;
use Fcntl ':seek';
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 42 };
use PerlIO::subfile;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my @caps = ("AA\n", 'PAHOEHOE');
my @lower = ("one\n", "two\n", "three\n", "four\n", "five");
my @num = ("007\n", "655360\n");

my @whole;
my @sub;
my $sub_start;
my $sub_end;
my $i = 0;
my $j = 0;

open TEST, ">test" or die "Can't open file: $!";
binmode TEST;
foreach (@caps) {
  $whole[$i++] = tell TEST;
  print TEST $_;
}
$sub_start = tell TEST;
foreach (@lower) {
  $sub[$j++] = $whole[$i++] = tell TEST;
  print TEST $_;
}
$sub_end = tell TEST;
foreach (@num) {
  $whole[$i++] = tell TEST;
  print TEST $_;
}
$_ -= $sub_start foreach (@sub);
close TEST or die "Can't close file: $!";

# Right. Let's play

open TEST, "<test" or die "Can't open file: $!";
binmode TEST;
ok(seek TEST, $sub_start, SEEK_SET);
ok (tell (TEST), $sub_start);
ok (binmode (TEST, ":subfile"), 1, sub {"binmode failed with $!"});
ok (tell (TEST), 0, "We shoud be at offset zero of the subfile");
ok (scalar <TEST>, $lower[0]);
ok (seek (TEST, 0, SEEK_SET), 1, "Failed to seek to the start of the subfile");
ok (tell (TEST), 0, "We shoud be at offset zero of the subfile again");
ok (scalar <TEST>, $lower[0]);
ok (seek (TEST, length($lower[1]), SEEK_CUR), 1, "Failed to seek forwards");
ok (scalar <TEST>, $lower[2]);
my $first_three = "$lower[0]$lower[1]$lower[2]";
ok (seek (TEST, -length($first_three), SEEK_CUR), 1,
    "Failed to seek backwards to the start");
my $buffer;
ok (read TEST, $buffer, length ($first_three));
ok ($buffer, $first_three);
ok (seek (TEST, -1-length($first_three), SEEK_CUR), '',
    sub {"Should have failed to seek backwards to before the start, \$!=$!"});
ok (scalar <TEST>, $lower[3]);
close TEST or die "Can't close file: $!";

my $caps_length = length (join '', @caps);
open TEST, "<:subfile(start=$caps_length)", "test" or die "Can't open file: $!";
# Hmm. I want tobinmode TEST; as part of the open.
ok (tell (TEST), 0, "We shoud start at offset zero of the subfile");
ok (scalar <TEST>, $lower[0]);
close TEST or die "Can't close file: $!";

my $lower_length = length (join '', @lower);
my $layerspec
  = sprintf "<:subfile(start=%d,end=+%d)", $caps_length, $lower_length;
open TEST, $layerspec, "test" or die "Can't open file with $layerspec: $!";
# Hmm. I want tobinmode TEST; as part of the open.
ok (tell (TEST), 0, "We shoud start at offset zero of the subfile");
ok (scalar <TEST>, $lower[0]);
my $line;
while (<TEST>) {
  $line = $_;
}
ok ($line, $lower[-1], "Hmm. That should have been the last line");
ok (eof TEST, 1, "Should be end of file");
ok (seek (TEST, 0, SEEK_SET), 1, "Failed to seek to the start of the subfile");
ok (scalar <TEST>, $lower[0]);
ok (seek (TEST, -length $lower[-1], SEEK_END), 1,
    "Should be at last line of subfile");
ok (scalar <TEST>, $lower[-1]);
ok (eof TEST, 1, "Should be end of file again");
close TEST or die "Can't close file: $!";

# Should be able to do these as hex (or octal)
$layerspec =
  sprintf "<:subfile(start=%d,end=+0x%X)", $caps_length, $lower_length;
open TEST, $layerspec, "test" or die "Can't open file with $layerspec: $!";
ok (seek (TEST, -length $lower[-1], SEEK_END), 1,
    "Should be at last line of subfile");
ok (scalar <TEST>, $lower[-1]);
ok (eof TEST, 1, "Should be end of file again again");
# There was an old man called Michael Finnegan...
close TEST or die "Can't close file: $!";

open TEST, "test" or die "Can't open file: $!";
while ($lower[2] ne <TEST>) {
  die if eof TEST; # We should not get to end of file.
}
$layerspec = sprintf ":subfile(start=-%d)", length $first_three;
ok (binmode (TEST, $layerspec), 1, sub {"binmode '$layerspec' failed with $!"});
ok (seek (TEST, 0, SEEK_SET), 1, "Binmode should take us to the start of the subfile");
while (<TEST>) {
  $line = $_;
}
ok ($line, $num[-1], "Hmm. That should have been the last line of numbers");
# Right. We should be able to nest these.
$layerspec = sprintf ":subfile(start=0,end=%d)", $lower_length;
ok (binmode (TEST, $layerspec), 1, sub {"binmode '$layerspec' failed with $!"});
{
  local $/;
  ok (<TEST>, join ('', @lower), "Slurp failed");
}
ok (seek (TEST, length $lower[0], SEEK_SET), 1, "Failed to seek to the second line of the subfile");
ok (scalar <TEST>, $lower[1]);
ok (seek (TEST, -length($first_three), SEEK_CUR), '',
    sub {"Should have failed to seek backwards to before the start, \$!=$!"});
ok (scalar <TEST>, $lower[2]);
# Right. this is within the outer subfile, but should still be beyond the
# inner subfile. Not sure that seek-beyond-end not failing is unix specific.
ok (seek (TEST, length$num[0], SEEK_END), 1,
    sub {"Failed to seek beyond the end of the subfile, \$!=$!"});
ok (eof TEST, 1, "Beyond the end should indicate EOF");
ok (scalar <TEST>, undef, "should read undef as we are at eof");
close TEST or die "Can't close file: $!";

while (-f "test") {
  unlink "test" or die "Can't unlink: $!";
}
__END__

# And now, it should all work on a pipe, as long as we don't seek.
# perl -pe0 might be an alternative to cat on some platforms
# (platforms which I don't have access to to test on)

# :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-(
#
# different perlio layers inconsistent when it comes to tell() on pipes
#
# :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-( :-(

open (PIPE, "cat test|") or die "Can't open pipe: $!";
ok ((read PIPE, $buffer, $caps_length), $caps_length, "Should have skipped the capitals");
$layerspec = sprintf ":subfile(end=%d)", $lower_length;
ok (binmode (PIPE, $layerspec), 1, sub {"binmode '$layerspec' failed with $!"});
ok (scalar <PIPE>, $lower[0]);
{
  local $/;
  ok (<PIPE>, join ('', @lower[1..$#lower]), "Slurp failed");
}
close PIPE or die "Can't close pipe: $!";
