#!/usr/bin/perl -w
#
# ripdvd.pl - rips audio from DVDs into mp3 format 
# Copyright (C) 2004 Russ Burdick, grub@extrapolation.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

use strict;
use diagnostics;
use POSIX qw(tmpnam);

my $trackbase = $ARGV[0] || "track";

my %dvd;
$dvd{artist} = "";
$dvd{title} = "";
$dvd{tno} = 0; # number of titles on dvd
# $dvd{tno##} = 0; # chapter counts for each title
$dvd{year} = "";
@{$dvd{track}} = (); # array of title names
# @{$dvd{track##}} = (); # array of chapter names for each title
#$dvd{torip}->{title,chapter} = (); # hash of "title,chapter" items to rip

my $fixname;
sub fixname {
   my $name = shift;
   my $name2 = $name;

   $name2 =~ s/://g;
   $name2 =~ s/: +/-/g;
   $name2 =~ s/\//-/g;
   $name2 =~ s/\) //g;
   $name2 =~ s/ \(/-/g;
   $name2 =~ s/\(//g;
   $name2 =~ s/12"/12\.inch/g;
   $name2 =~ s/["',!\?\)]+//g;
   $name2 =~ s/&+/and/g;
   $name2 =~ s/\++/and/g;
   $name2 =~ s/ - /-/g;
   $name2 =~ tr/A-Z /a-z./;
   $name2 =~ s/\.\.+/\./g;
   $name2 =~ s/-\./\-/g;
   $name2 =~ s/\.\-/\-/g;
#   $name2 =~ s/\\n//g;

   return($name2);
}


my $user_input = "y";
while ( ( $user_input ne "n" ) && ( $user_input ne "N" ) ) {
   disc_cycle();
   print "\n";
   print "Try another disc? ([y]/n) ";
   $user_input = <STDIN>;
   chomp ($user_input);
}
print "Thanks for trying this software.\n";
exit;

my $disc_cycle;
sub disc_cycle {
   my $user_input;

   print "\n";
   print "---Insert DVD into drive and press enter to begin---\n";
   print "\n";
   $user_input = <STDIN>;  # FIXME: find cleaner way to get a key
   $user_input = 2;
   print "getting CD info...\n";

   probe_dvd();

   ask_to_add();

}

my $ask_to_add;
sub ask_to_add {
   my $user_input = "z";

   while (lc($user_input) ne "y") {
      print_dvd(\%dvd);
      print "ok to rip? ([y]/n/e/r) ";

      $user_input = <STDIN>;
      chomp($user_input);
      if (lc($user_input) eq 'n') {
         warn "Aborting per user request...\n";
         return;
      } elsif (lc($user_input) eq 'e') {
         edit_dvd_info(\%dvd);
      } elsif (lc($user_input) eq 'r') {
         read_dvd_info(\%dvd);
      } else {
         $user_input = "y";
         rip_tag(\%dvd);
      }
   }
}

my $probe_dvd;
sub probe_dvd {

   my $out = "";
   my $outfile = "";
   my $cmd = "";

   # first get the number of titles on the DVD
   $outfile = tmpnam();
   $cmd = "mplayer dvd://1 -waveheader -vc null -vo null -aofile foo.wav -ao pcm -chapter 0-0 -af resample=44100,volume=0 > $outfile 2> /dev/null";
   system($cmd);

   open STATUS, "$outfile" or die "cant open \"$outfile\": $!";
   while (<STATUS>) {
      $out = $_;
      if ($_ =~ m/^There are (\d+) titles on this DVD/) {
         $dvd{tno} = $1;
      }
   }
   close STATUS;
   unlink $outfile or die "error unlinking \"$outfile\": $!";

   # now find the number of chapters in each title
   for (my $i = 1; $i <= $dvd{tno}; $i++) {
      $outfile = tmpnam();
      $cmd = "mplayer dvd://$i -waveheader -vc null -vo null -aofile foo.wav -ao pcm -chapter 0-0 -af resample=44100,volume=0 > $outfile 2> /dev/null";
      system($cmd);

      open STATUS, "$outfile" or die "cant open \"$outfile\": $!";
      while (<STATUS>) {
         $out = $_;
         if ($_ =~ m/^There are (\d+) chapters in this DVD title/) {
            my $ref = "tno$i";
            $dvd{$ref} = $1;

            my $ref2 = "track$i";
            for (my $j = 1; $j <= $dvd{$ref}; $j++) {
               push @{$dvd{$ref2}}, "title $i chapter $j";
            }
         }
      }
      close STATUS;
      unlink $outfile or die "error unlinking \"$outfile\": $!";
   }
}

my $print_dvd;
sub print_dvd {
   my $dvd = shift;

   for (my $i = 1; $i <= $dvd->{tno}; $i++) {
      my $ref = "tno$i";
      print qq(there are $dvd->{$ref} chapters in title $i\n);
   }

}

my $read_dvd_info;
sub read_dvd_info {
   my $dvd = shift;
   my $user_input = "z";
   my $out;
   my $tnum;
   my $num;
   my $tmp;

   while (lc($user_input) ne "") {

      # get filename
      print "\nload filename: ";
      $user_input = <STDIN>;
      chomp($user_input);

      if ($user_input ne "") {
         open STATUS, "$user_input" or die "cant open \"$user_input\": $!";
         while (<STATUS>) {
            $out = $_;
            chomp($out);

            if ($out =~ m/^artist (.*?)$/) {
               $dvd->{artist} = $1;
            } elsif ($out =~ m/^title (.*?)$/) {
               $dvd->{title} = $1;
            } elsif ($out =~ m/^year (.*?)$/) {
               $dvd->{year} = $1;
            } elsif ($out =~ m/^(\d+) (\d+) (.*?)$/) {
               $tnum = $1; # title#
               $num = $2;  # chapter#
               $tmp = $3;  # chapter name
               my $ref = "$tnum,$num";
               my $ref2 = "track$tnum";

               @{$dvd->{$ref2}}[$num-1] = $tmp;
               $dvd->{torip}->{$ref}++;
            } else {
               # ignore
            }
         }
         close STATUS;

         $user_input = "";
         print "\n";
      }
   }
}

my $edit_dvd_info;
sub edit_dvd_info {
   my $dvd = shift;
   my %backup_dvd;
   my @backup_tracks;
   my $user_input = "z";
   my $curtitle = 1;
   my $tmp = "";
   my $foo = "";

   %backup_dvd = %{$dvd};
   @backup_tracks = @{$dvd->{track}};
   while ((lc($user_input) ne "s") && (lc($user_input) ne "x")) {
      print "\n    [a] Artist  : $dvd->{artist}\n";
      print "    [t] Title   : $dvd->{title}\n";
      print "    [y] Year    : $dvd->{year}\n";
      print "\n    [c] Current Title: $curtitle\n";
      print "\nrip ch# title\n";

      my $num = 0;
      my $ref = "track$curtitle";
      my $ref2 = "tno$curtitle";
      foreach my $track (@{$dvd->{$ref}}) {
         $num++;
         $foo = "$curtitle,$num";
         if ($dvd->{torip}->{$foo}) {
            print "[y] ";
         } else {
            print "[n] ";
         }
         print "[$num] $track\n";
      }
      print "\n[g] toggle all\n";
      print "[f] read from file\n";
      print "[s] save\n";
      print "[x] abort and exit\n";
      print "choice? ([s]/c/a/t/y/#/x/r#/g/f) ";

      $user_input = <STDIN>;
      chomp($user_input);
      if (lc($user_input) eq "a") {
         print "Artist: ";
         $dvd->{artist} = <STDIN>;
         chomp($dvd->{artist});
      } elsif (lc($user_input) eq "t") {
         print "Title: ";
         $dvd->{title} = <STDIN>;
         chomp($dvd->{title});
      } elsif (lc($user_input) eq "c") {
         print "Change to which title? (1-$dvd->{tno}): ";
         $tmp = <STDIN>;
         chomp($tmp);
         if (($tmp > 0) && ($tmp <= $dvd->{tno})) {
            $curtitle = $tmp;
         }
      } elsif (lc($user_input) eq "y") {
         print "Year: ";
         $dvd->{year} = <STDIN>;
         chomp($dvd->{year});
      } elsif (lc($user_input) eq "") {
         $user_input = "s";
      } elsif (lc($user_input) eq "f") {
         read_dvd_info($dvd);
      } elsif (lc($user_input) eq "g") {
         toggle_all($dvd);
      } elsif (lc($user_input) eq "x") {
         %{$dvd} = %backup_dvd;
         $dvd->{$ref} = \@backup_tracks;
      } elsif (($user_input =~ m/^r(\d+)$/) && ($1 <= $dvd->{$ref2})) {
         $foo = "$curtitle,$1";
         if ($dvd->{torip}->{$foo}) {
            $dvd->{torip}->{$foo} = undef;
         } else {
            $dvd->{torip}->{$foo}++;
         }
      } elsif (($user_input =~ m/^\d+$/) && ($user_input <= $dvd->{$ref2})) {
         print "$user_input: ";
         ${$dvd->{$ref}}[$user_input-1] = <STDIN>;
         chomp(${$dvd->{$ref}}[$user_input-1]);
      }
   }
}

my $toggle_all;
sub toggle_all {
   my $dvd = shift;

   for (my $tnum = 1; $tnum <= $dvd->{tno}; $tnum++) {
      my $ref = "tno$tnum";
      for (my $num = 1; $num <= $dvd->{$ref}; $num++) {
         my $tmp = "$tnum,$num";
         if ($dvd->{torip}->{$tmp}) {
            $dvd->{torip}->{$tmp} = undef;
         } else {
            $dvd->{torip}->{$tmp}++;
         }
      }
   }
}

my $rip_tag;
sub rip_tag {

   my $dvd = shift;
   my $outfile = "";
   my $cmd = "";

   if (keys %{$dvd->{torip}}) {
      my $cmd2 = qq(id3ren -quiet -tag -tagonly);
      $cmd2 .= qq( -artist="$dvd->{artist}" -album="$dvd->{title}");
      if ($dvd->{year} eq "") {
         $cmd2 .= qq( -noyear);
      } else {
         $cmd2 .= qq( -year="$dvd->{year}");
      }
      $cmd2 .= qq( -nogenre -comment="dvd rip by grub");

      my $arname = fixname($dvd->{artist});
      my $alname = fixname($dvd->{title});
      system("mkdir $arname");
      system("mkdir $arname/$alname");

      my $num;
      my $tnum;
      foreach my $pair (keys %{$dvd->{torip}}) {
         $pair =~ m/^(\d+),(\d+)$/;
         my $curtitle = $1;
         my $i = $2;
         my $ref = "tno$curtitle";

         if ($i < 10) {
            $num = "0$i";
         } else {
            $num = $i;
         }
         if ($curtitle < 10) {
            $tnum = "0$curtitle";
         } else {
            $tnum = $curtitle;
         }

         my $t = "track$curtitle";
         my $track = @{$dvd->{$t}}[$i-1];
         my $cmd3 = $cmd2;
         if ((!$track) || ($track eq "")) {
            $cmd3 .= qq( -track="$num" -song="");
         } else {
            $cmd3 .= qq( -track="$num" -song="$track");
         }

         my $fname = fixname(qq($dvd->{artist}-$dvd->{title}-$tnum-$num-$track.mp3));

         $cmd3 .= " $fname";

         $outfile = "$trackbase-title$tnum-chapter$num";
#         $cmd = "mplayer -dvd $curtitle -vc dummy -vo null -hardframedrop -chapter $i-$i -ao pcm -really-quiet -nojoystick -nolirc -aid 128 -af resample=44100,volume=0 -waveheader -aofile '$fname.wav'";
         $cmd = "mplayer -dvd $curtitle -vc dummy -vo null -hardframedrop -chapter $i-$i -ao pcm -nojoystick -nolirc -aid 128 -af volume=0 -waveheader -aofile '$fname.wav'";
         system($cmd);

         # encode mp3
         $cmd = "lame -h -b 192 '$fname.wav' '$fname'";
         system($cmd);

         # tag new mp3, move into subdir, delete .wav
         system($cmd3);
         system("mv '$fname' $arname/$alname");
         system("rm -f '$fname.wav'");
      }

   }
   print "\n";
}

