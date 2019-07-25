#!/usr/bin/env perl

# Copyright 2017-2018
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see <http://www.gnu.org/licenses/> or
# write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# You should have received a copy of the CeCILL-C license with this program.
#If not see <http://www.cecill.info/licences/Licence_CeCILL-C_V1-en.txt>
#
# Intellectual property belongs to ADNid
# Version 1 and latter written by Julie ORJUELA
# julieaorjuela@gmail.com
#
####################################################################################################################################

#use strict;
use List::Compare;
use Getopt::Long;
use Data::Dumper;
use LWP::Simple;

my ($fileIn, $fileOut ,$query, $help);

my $courriel="julie.orjuela_at_qualtech-groupe.com";
my ($nomprog) = $0 =~/([^\/]+)$/;
my $MessAbruti ="\nUsage:
\t$nomprog -q stringQuery -o outFile


From a string query $nomprog recovery sequences in fasta format.

#exemple '\$query = '\"12S ribosomal RNA\"[All Fields] AND (animals[filter])';

The outFile will be a fasta file.

        contact: $courriel\n\n";

unless (@ARGV) 
        {
        print "\nType --help for more informations\n\n";
        exit;
        }

GetOptions("prout|help|?|h" => \$help,   
            "o|out=s"=>\$fileOut,
            "q|query=s"=>\$query);

if ($help)
	{
	print $MessAbruti,"\n";
	exit;
	}

#assemble the esearch URL
$base='https://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
$url=$base . "esearch.fcgi?db=nucleotide&term=$query&usehistory=y";
print "$query\n";
print "$fileOut\n";

#post the esearch URL
$output = get($url);

#parse WebEnv, QueryKey and Count (# records retrieved)
$web = $1 if ($output =~ /<WebEnv>(\S+)<\/WebEnv>/);
$key = $1 if ($output =~ /<QueryKey>(\d+)<\/QueryKey>/);
$count = $1 if ($output =~ /<Count>(\d+)<\/Count>/);

#open output file for writing
open(OUT, ">$fileOut.fasta") || die "Can't open file!\n";

#retrieve data in batches of 500
$retmax = 500;
for ($retstart = 0; $retstart < $count; $retstart += $retmax) {
        $efetch_url = $base ."efetch.fcgi?db=nucleotide&WebEnv=$web";
        $efetch_url .= "&query_key=$key&retstart=$retstart";
        $efetch_url .= "&retmax=$retmax&rettype=fasta&retmode=text";
        $efetch_out = get($efetch_url);
        print OUT "$efetch_out";
}
#compresser le fichier fasta

close OUT;
print "compressing $fileOut.fasta";
`gzip $fileOut.fasta`;
`chmod 550 $fileOut.fasta.gz`;
