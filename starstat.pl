#!/usr/bin/perl
# starstat.pl
# Read in the data from any stars file to validate it.
# Rick Steeves th@corwyn.net
# 120129, 180318
# Version 1.2
# Adding Encryption Salt

#     Copyright (C) 2012 Rick Steeves
# 
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.

@dt_verbose = ('Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File');
@dt = ("XY", "Log", "Host", "Turn", "Hist", "Race", "Max");
@fDone = ('Turn Saved','Turn Saved/Submitted');
@fMulti = ('Single Turn', 'Multiple Turns');
@fGameOver = ('Game In Progress', 'Game Over'); 
@fShareware = ('Registered','Shareware'); 
@fInUse = ('Host instance not using file','Host instance using file'); # No idea what this value is.
%Version = ("1.2a" => "1.1a", "2.65" => "2.0a", "2.81j" => "2.6i", "2.83" => "2.6jrc4");

my $filename = $ARGV[0];
print "File is $filename\n";
if ($filename eq '') { print "Please enter the file to examine. Example c:\\games\\meat.m6. "; die; }
##########################
open(StarFile, "$filename");
binmode(StarFile);
read(StarFile, $FileValues, 22);
close(StarFile);

# This is all specific to the file header block

#$unpack = "A2A4h8SSSS";
$unpack = "SA4LSSsS";
#$Header-S, $Magic=A4, $lidGame-h8, $ver-S, $turn-S $iPlayer-S, $dts-S)
# S/s - Unsigned/signed Short     (exactly 16-bits, 2 bytes) 
# h/H -  hex string, low/high nybble first. 1 byte?
# A - ASCII string, blank padded. 1 byte
# L - unsigned long, 32 bits, 4 bytes

@FileValues = unpack($unpack,$FileValues);
($Header, $Magic, $lidGame, $ver, $turn, $iPlayer, $dts) = @FileValues;
#print join(',', @FileValues) . "\n";
#print "Header\t$Header\t" .  dec2bin($Header) . "\n"; #Header

#Each block have 2 bytes header followed by data of variable length. 
#Header contains block type and block length. First header byte is a low 8 bits 
#of the block size. Low 2 bits of the second byte is a high 2 bits of the block 
#size and high 6 bits of the second byte is a block type. 
#Each block in file can have up to 1024 bytes of data.
#So, here is a header block bitwise: XXXXXXXX YYYYYYZZ
#(XXXXXXXX is a first byte, YYYYYYZZ is a second byte)

$binHeader = dec2bin($Header);
#$blocktype = (substr($binHeader, 8,6));
$blocktype = (substr($binHeader, 0,6));
$blocktype = bin2dec($blocktype);
print "Blocktype = $blocktype\n";
#$blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
$blocksize = (substr($binHeader, 7,2)) . (substr($binHeader, 8,8));
$blocksize = bin2dec($blocksize);
print "Blocksize = $blocksize\n";

print "Magic = $Magic\n"; #
print "lidGame = $lidGame\n"; 

# Game Version
$ver = dec2bin($ver);
$verInc = substr($ver,11,5);
$verMinor = substr($ver,4,7);
$verMajor = substr($ver,0,4);
$verMajor = bin2dec($verMajor);
$verMinor = bin2dec($verMinor);
$verInc = bin2dec($verInc);
$ver = $verMajor . "." . $verMinor . "." . $verInc;
$verClean = $verMajor . "." . $verMinor;
print qq|Version = $ver  >> $Version{$verClean}\n|;

# Turn
$turn=$turn + 2400;
print "Turn = $turn\n"; #

# Player Number
$iPlayer = &dec2bin($iPlayer);
$Player = substr($iPlayer,11,5);
$Player = bin2dec($Player);
$Player=$Player +1; # Correcting for 0-15
print "Player = $Player\n";
 
# Encryption Seed
$Seed =  substr($iPlayer,0,11);
$Seed = bin2dec($Seed);
print "Seed = $Seed\n"; 

# dts
# Convert DTS to binary so we can pull the values back out
print "\n";
$dts = dec2bin($dts);
print "\ndts=$dts\n";

# File Type
$dt = substr($dts, 8,15);
$dt = bin2dec($dt);
print $dt . ":\t" . @dt_verbose[$dt] . "\n";

# These are 1 character, so there's no need to convert them back to decimal
# Turn state (.x file only)
$fDone = substr($dts, 7,1);
#print "fDone\t$fDone\n";
print $fDone . ":\t" . @fDone[$fDone] . "\n";

# Host instance is using this file (dtHost, dtTurn).
$fInUse = substr($dts, 6, 1);
print $fInUse . ":\t" . @fInUse[$fInUse] . "\n";

# Are multiple turns included (.m only)
$fMulti = substr($dts, 5,1);
print $fMulti . ":\t" . @fMulti[$fMulti] . "\n";

# Is the Game Over
$fGameOver = substr($dts, 4,1);  # Probably 4
print $fGameOver . ":\t" . @fGameOver[$fGameOver] . "\n";

# Shareware
$fShareware = substr($dts, 3, 1);
print $fShareware . ":\t" . @fShareware[$fShareware] . "\n";

#############
sub dec2bin {
	# This doesn't match stuff online because I changed from 32- to 16-bit
	my $str = unpack("B16", pack("n", shift));
	return $str;
}
sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}
