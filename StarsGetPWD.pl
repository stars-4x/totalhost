#!/usr/bin/perl
# Read in the data from a .m or .r file to strip off the password. 
# Rick Steeves th@corwyn.net
# 180325
#     Copyright (C) 2018 Rick Steeves
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

#use StarsGetPWD;

# Initial seeds for our Random Number Generator
# 279 is not prime
my @primes = ( 
                3, 5, 7, 11, 13, 17, 19, 23, 
                29, 31, 37, 41, 43, 47, 53, 59,
                61, 67, 71, 73, 79, 83, 89, 97,
                101, 103, 107, 109, 113, 127, 131, 137,
                139, 149, 151, 157, 163, 167, 173, 179,
                181, 191, 193, 197, 199, 211, 223, 227,
                229, 233, 239, 241, 251, 257, 263, 279,
                271, 277, 281, 283, 293, 307, 311, 313 
        );
my $seedA;    # All of the examples modify a global variable. 
my $seedB;    # even if it's a terrible practice.
my $filename = $ARGV[0];
print "File is $filename\n";
if ($filename eq '') { print "Please enter the file to examine. Example c:\\games\\meat.m6. "; die; }
##########################
##########################
open(StarFile, "$filename");
binmode(StarFile);
# Read in the Stars! file byte by byte
while (read(StarFile, $FileValues, 1)) {
  push @fileBytes, $FileValues;     		#List<Block> v1 = new Decryptor().readFile(f.getAbsolutePath());
}
close(StarFile);

##################
# Parse the file
$offset = 0;
$numbytes = scalar @fileBytes;
print "Byte Count = $numbytes\n"; 

# Loop through the entire file, separating out the blocks
foreach $byte (@fileBytes) {
 ($typeId, $size, $data) = &parseBlock(\@fileBytes, $offset);
  print "typeID=$typeId size=$size offset=$offset\n";
#  $block = substr(@fileBytes,$offset,$size);
  # We start with 8, because it's always first. 
  if  ($typeId == 8) {   # Gather the seed info
     ( $binSeed, $fShareware, $Player, $turn, $lidGame) = &getFileHeaderBlock(\@fileBytes, $offset, $size);
      # We always have this data before getting to block 6, because block 8 is first
      &initDecryption ($binSeed, $fShareware, $Player, $turn, $lidGame);
  }
  if ($typeId == 6) {  # Found the Player Block
      &decryptBlock(\@fileBytes, $offset, $size)
#      &getPlayerBlock(\@fileBytes, $offset, $size);
#      &resetpassword (\@fileBytes, $offset, $size, $binSeed, $fShareware, $Player, $turn, $lidGame);
#      die;
  }
  # Skip through the file finding each block by the offsets
  $offset = $offset + $size + 2;
#  print "New Offset: $offset\n\n";
#  if ($offset >  $numbytes) {print "Offset: $offset\n"; die;} # For some reason this goes past the end of the array 
  if ($offset >=  $numbytes) {last; } 
}
###########################
###########################

sub getFileHeaderBlock {
print "\n**getFileHeaderBlock\n";
#$Header-S, $Magic=A4, $lidGame-h8, $ver-S, $turn-S $iPlayer-S, $dts-S)
# S/s - Unsigned/signed Short     (exactly 16-bits, 2 bytes) 
# h/H -  hex string, low/high nybble first. 1 byte?
# A - ASCII string, blank padded. 1 byte
# L - unsigned long, 32 bits, 4 bytes
  my @dt_verbose = ('Universe Definition (.xy) File', 'Player Log (.x) File', 'Host (.h) File', 'Player Turn (.m) File', 'Player History (.h) File', 'Race Definition (.r) File', 'Unknown (??) File');
  my @dt = ("XY", "Log", "Host", "Turn", "Hist", "Race", "Max");
  my @fDone = ('Turn Saved','Turn Saved/Submitted');
  my @fMulti = ('Single Turn', 'Multiple Turns');
  my @fGameOver = ('Game In Progress', 'Game Over'); 
  my @fShareware = ('Registered','Shareware'); 
  my @fInUse = ('Host instance not using file','Host instance using file'); # No idea what this value is.
  my %Version = ("1.2a" => "1.1a", "2.65" => "2.0a", "2.81j" => "2.6i", "2.83" => "2.6jrc4");

# This is always the first block, so it starts at 0. 
  my ($fileBytes, $offset, $size) = @_;
  my @fileBytes = @{ $fileBytes }; 
  # Unpack the data
  # 2 bytes
  $bytes = @fileBytes[0] . @fileBytes[1];
  $Header = unpack ("S", $bytes);
  # 4 bytes
  $bytes = @fileBytes[2] . @fileBytes[3] . @fileBytes[4] . @fileBytes[5];
  $Magic = unpack ("A4", $bytes);
  # 4 bytes
  $bytes =  @fileBytes[6] . @fileBytes[7] . @fileBytes[8] . @fileBytes[9];
  $lidGame = unpack ("L",  $bytes);
  # 2 bytes
  $bytes = @fileBytes[10] . @fileBytes[11];
  $ver = unpack ("S", $bytes);
  # 2 bytes
  $bytes = @fileBytes[12] . @fileBytes[13];
  $turn = unpack ("S", $bytes);
  # 2 bytes
  $bytes = @fileBytes[14] . @fileBytes[15];
  $iPlayer = unpack ("s", $bytes);
  # 2 bytes
  $bytes = @fileBytes[16] . @fileBytes[17];
  $dts = unpack ("S", $bytes);
  # Convert the data to its usable form
  $binHeader = dec2bin($Header);
  $blocktype = (substr($binHeader, 0,6));
  $blocktype = bin2dec($blocktype);
  print "Blocktype=$blocktype\n";
  
  $blocksize = (substr($binHeader, 7,2)) . (substr($binHeader, 8,8));
  $blocksize = bin2dec($blocksize);
  print "Blocksize=$blocksize\n";

  print "Magic=$Magic\n"; #
  print "lidGame=$lidGame\n"; 

  # Game Version
  $ver = dec2bin($ver);
  #print "ver:$ver\n";
  $verInc = substr($ver,11,5);
  $verMinor = substr($ver,4,7);
  $verMajor = substr($ver,0,4);
  $verMajor = bin2dec($verMajor);
  $verMinor = bin2dec($verMinor);
  $verInc = bin2dec($verInc);
  $ver = $verMajor . "." . $verMinor . "." . $verInc;
  $verClean = $verMajor . "." . $verMinor;
  print qq|Version\t$ver  >> $Version{$verClean}\n|;
  # Turn
  $displayturn=$turn + 2400;
  print "Turn=$turn\n"; #
  # Player Number
  $iPlayer = &dec2bin($iPlayer);
  $Player = substr($iPlayer,11,5);
  $Player = bin2dec($Player);
  $PlayerDisplay=$Player +1; # Correcting for 0-15
  print "Player=$Player (displayed as $PlayerDisplay)\n";
  # Encryption Seed
  $binSeed =  substr($iPlayer,0,11);
  $Seed = bin2dec($binSeed);
  print "Seed=$Seed\t$binSeed\n"; 
  print "\n";
  # dts - Convert DTS to binary so we can pull the values back out
  $dts = dec2bin($dts);
  print "dts=$dts\n";
  #Break DTS into its binary components
  $dt = substr($dts, 8,15);
  $dt = bin2dec($dt);
  # File Type
  print $dt . ":\t" . @dt_verbose[$dt] . "\n";
  # These are 1 character, so there's no need to convert them back to decimal
  # Turn state (.x file only)
  $fDone = substr($dts, 7,1);
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
  print $fShareware . ":\t" . @fShareware[$fShareware] . "\n\n";
  return $binSeed, $fShareware, $Player, $turn, $lidGame;
}

#####
##### This is wrong. The block is inherently encrypted, so looking
# at it when it's encrypted doesn't do me any good. 
# sub getPlayerBlock  {
#   my $fileBytes;
#   my $offset;
#   my $size;
#   ($fileBytes, $offset, $size) = @_;
#   my @fileBytes = @{ $fileBytes }; 
#   # Display the password bytes
#   print "**PLAYER PASSWORD\n";
#   $bytecount = 12;
#   $begin =  $offset + 2 + $bytecount;
#   $end =    $offset + 2 + $bytecount + 4;
#   for (my $i = $begin; $i < $end; $i++){
#     print "$bytecount FileBytes: $fileBytes[$i]\n";
#     $bytecount++;
#   }
#   print "**END PLAYER PASSWORD\n";
# }


sub initDecryption {
  print "\n**initDecryption\n";
  # Init decryption
  # Need the values from the FileHeaderBlock to seed the encryption
  my ($binSeed, $fShareware, $Player, $turn, $lidGame) = @_;
  #print "FileBytes:$fileBytes, Offset:$offset, Size:$size, binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame\n";
  print "binSeed:$binSeed,Shareware:$fShareware,Player:$Player,Turn:$turn,GameID:$lidGame\n";
  # Convert fileBytes back to an array. 
  # my @fileBytes = @{ $fileBytes }; 
  # Use two prime numbers as random seeds.
	# First one comes from the lower 5 bits of the salt
  $salt = bin2dec($binSeed);
  print "salt: $salt\n";
 	$index1 = $salt & 0x1F;
	# Second index comes from the next higher 5 bits
	$index2 = ($salt >> 5) & 0x1F;
  print "Index1: $index1   Index2: $index2\n";
  #Adjust our indexes if the highest bit (bit 11) is set
	#If set, change index1 to use the upper half of our primes table
	if(($salt >> 10) == 1) { $index1 += 32; 
	#else index2 uses the upper half of the primes table
	} else { $index2 += 32; }
  print "Adjusted Index1: $index1   Index2: $index2\n";
  
  #Determine the number of initialization rounds from 4 other data points
	#0 or 1 if shareware (I think this is correct, but may not be - so far
	#I have not encountered a shareware flag
	$part1 = $fShareware;
  #Lower 2 bits of player number, plus 1
	$part2 = ($Player & 0x3) + 1;
	#Lower 2 bits of turn number, plus 1
	$part3 = ($turn & 0x3) + 1;
	#Lower 2 bits of gameId, plus 1
	$part4 = ($lidGame & 0x3) + 1;
  #Now put them all together, this could conceivably generate up to 65 
	# rounds  (4 * 4 * 4) + 1
  print "(4:$part4 * 3:$part3 * 2:$part2) + 1:$part1, \n";
	$rounds = ($part4 * $part3 * $part2) + $part1;
  print "rounds:$rounds\n";
  #Now initialize our random number generator
  print "random: $primes[$index1], $primes[$index2], $rounds\n";
	$random = &StarsRandom($primes[$index1], $primes[$index2], $rounds);
  print "##################\n";
  print "init random: \n$random\n";
  print "##################\n";
}

sub StarsRandom {
  my ($seed1, $seed2, $initRounds) = @_;
  $seedA = $seed1;
  $seedB = $seed2;
  $rounds = $initRounds;
  print "seed1:$seedA, seed2:$seedB, rounds:$rounds\n";
  # Now initialize a few rounds
  # for _ in xrange(initRounds):
  for (my $i = 0; $i < $initRounds; $i++) { 
#    &nextRandom($seedA, $seedB);
    print "round: $i of $rounds\n";
#    &nextRandom($seedA, $seedB);
    &nextRandom();
  }
  my $s;
  $s = "Random Number Generator:\n";
  $s .= "Seed 1: $seedA\n";
  $s .= "Seed 2: " . $seedB . "\n";
  $s .= "Rounds: " . $rounds . "\n";
#  print "s: $s\n"; 
  return $s;
}
        
sub nextRandom {
#  my $seedA;
#  my $seedB;
  my $randomNumber;
#  ($seedA, $seedB) = @_;
  print "seedA: $seedA, seedB:$seedB\n";
  # First, calculate new seeds using some constants
  $seedApartA = ($seedA % 53668) * 40014;
  print "seedApartA: $seedApartA\n";
  $seedApartB = int(($seedA / 53668)) * 12211; # integer division OK
  print "seedApartB: $seedApartB\n";
  $newSeedA = $seedApartA - $seedApartB;
  #print "newSeedA: $newSeedA\n";
        
  $seedBpartA = ($seedB % 52774) * 40692;
  $seedBpartB = int(($seedB / 52774)) * 3791;
  $newSeedB = $seedBpartA - $seedBpartB;
  print "newSeedA:$newSeedA, newSeedB:$newSeedB\n";       
  # If negative add a whole bunch (there's probably some weird bit math
  # going on here that the disassembler didn't make obvious)
  if ($newSeedA < 0) { $newSeedA += 0x7fffffab; }
  if ($newSeedB < 0) { $newSeedB += 0x7fffff07; }
  # Set our new seeds
  $seedA = $newSeedA;
  $seedB = $newSeedB;
  # Generate "random" number.  This will fit into an unsigned 32-bit integer
  $randomNumber = $seedA - $seedB;
#  if ($seedA < $seedB) { $randomNumber += 0x100000000l; }  # 2^32
  if ($seedA < $seedB) { $randomNumber += 0x1000000001; }  # 2^32
  # Now return our random number
  print "rand: $randomNumber\n";
  return $randomNumber;
}

sub decryptBytes {
  ($byteArray) = @_;
  my @byteArray = @{ $byteArray }; 
  # Add padding to 4 bytes
  $size = @byteArray;
  $paddedSize = ($size + 3) & ~3;  # This trick only works on powers of 2
  $padding = $paddedSize - $size;
  for ($i = 0; $i < $padding; $i++) { 
#    byteArray.append(0x0)
  }
  $decryptedBytes = @bytearray;
  # Now decrypt, processing 4 bytes at a time
  for ($i = 0; $i <  $paddedSize; $i+4) { 
    # Swap bytes using indexes in this order:  4 3 2 1
    $chunk = (($byteArray[$i+3] << 24) | ($byteArray[$i+2] << 16) | ($byteArray[$i+1] << 8) | $byteArray[$i]);
    # XOR with a random number
    $decryptedChunk = $chunk ^ self.random.nextRandom();
    # Write out the decrypted data, swapped back
    decryptedBytes.append(decryptedChunk & 0xFF);
    decryptedBytes.append((decryptedChunk >> 8)  & 0xFF);
    decryptedBytes.append((decryptedChunk >> 16)  & 0xFF);
    decryptedBytes.append((decryptedChunk >> 24)  & 0xFF);
  }    
  # Strip off any padding
  for ($i = 0; $i <  $padding; $i++) {
      byteArray.pop();
      decryptedBytes.pop();
  }
  return $decryptedBytes;
}

sub decryptBlock {
    ($fileBytes, $offset, $size) = @_;
    my @fileBytes = @{ $fileBytes }; # Convert back to array
		# If it's a header block, it's unencrypted and will be used to 
		# initialize the decryption system.  We have to decode it first
		$bytes = @fileBytes[$offset] . @fileBytes[$offset+1];
    $Header = unpack ("S", $bytes);
		$encryptedData = &getData($block);
#		$decryptedData = $length;
		$decryptedData = $size;

		# Now decrypt, processing 4 bytes at a time
		for(my $i = 0; $i < $length; $i+=4) {
			# Swap bytes:  4 3 2 1
			$chunk = (&read8($encryptedData[$i+3]) << 24)
					| (&read8($encryptedData[$i+2]) << 16)
					| (&read8($encryptedData[$i+1]) << 8)
					| &read8($encryptedData[$i]);
			
#			System.out.println("chunk  : " + Integer.toHexString((int)chunk));
			
			# XOR with a random number
			$decryptedChunk = $chunk ^ random.nextRandom();
#			System.out.println("dechunk: " + Integer.toHexString((int)decryptedChunk));
			
			# Write out the decrypted data, swapped back
			$decryptedData[$i] =   ($decryptedChunk & 0xFF);
			$decryptedData[$i+1] = (($decryptedChunk >> 8)  & 0xFF);
			$decryptedData[$i+2] = (($decryptedChunk >> 16)  & 0xFF);
			$decryptedData[$i+3] = (($decryptedChunk >> 24)  & 0xFF);
		}
		
		&setDecryptedData($decryptedData, $size);
	}


##############
sub parseBlock {
  my $fileBytes;
  my $offset;
  ($fileBytes, $offset) = @_;
  my @fileBytes = @{ $fileBytes }; 
  # This returns the 3 relevant parts of a block: typeId, size, raw data
  @blockHeader = &read16(\@fileBytes, $offset);
  ($blocktype, $blocksize) = @blockHeader;
#  $blockdata = substr(\@fileBytes,$offset+2,$offset+2+$blocksize);
# This is wrong. SEe decryptor.pl
  return ($blocktype, $blocksize, $blockdata);
}
    
sub read16 {
   my $byteArray;
   my $byteIndex;
   ($byteArray, $byteIndex) = @_; 
   my @byteArray = @{ $byteArray };
   my $index1 = $byteIndex;
   my $index2 = $byteIndex + 1;
   my $FileValues = $byteArray[$index2] . $byteArray[$index1];
#    print "File Values: $FileValues\n";
#    print "index1:$index1, index2:$index2, ba2:$byteArray[$index2] ba1:$byteArray[$index1]\n";  
   my $unpack = "S";
   my @FileValues = unpack($unpack,$FileValues);
   my ($Header) =  @FileValues;
   my $binHeader = dec2bin($Header);
   my $blocktype = (substr($binHeader, 8,6));
   my $blocktype = bin2dec($blocktype);
   my $blocksize = (substr($binHeader, 14,2)) . (substr($binHeader, 0,8));
   my $blocksize = bin2dec($blocksize);
   return ($blocktype, $blocksize);
}

sub read8 {
    my $b = @_;
		return $b & 0xFF;
}

 
#############
sub dec2bin {
	# This doesn't match stuff online because I changed from 32- to 16-bit
	my $str = unpack("B16", pack("n", shift));
	return $str;
}
sub bin2dec {
	return unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
}

sub bytesToString  {
  my ($bytes, $offset, $size) = @_;
  @bytes = $bytes;
	$sb = "";
	for(my $i = $offset; $i < $offset + $size; $i++) {
    $sb .= &read8($bytes[$i]);
		$sb .= " ";
	}
	return $sb;
}

