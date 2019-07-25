#! /usr/bin/perl -w
# fevrier 2018
use strict;
use Getopt::Long;
use Data::Dumper;
use Bio::DB::Taxonomy;
use Bio::SeqIO;
use Getopt::Long;

my $courriel='julie.orjuela@ird.fr';
my ($nomprog) = $0 =~/([^\/]+)$/;
my $MessAbruti ="\nUsage:
\t$nomprog -i  input.fas -o outfile.txt -dbase (Genbank by default) -gi (O or 1 (by default))
or
\t$nomprog -in input.vcf -out outfile.vcf -gi (O or 1 (by default))

DESCRIPTION

Takes fasta sequences extracted from Genebank, RFAM, UNITE or BOLD Databases and format them in stampa format.

	Take as input a fasta file such as:
	>GAXI01000525.151.1950 Tetrodontophora bielanensis mithocondrial, complete genome
	TCCGTAGGCGGACTCGTAAGTCAGTGGTGAAATCTCATAGCTTAACTATGAAACTGCCATTGATACTGCGGGTCTTGAGTAAAGTAGAAGTGGCT
	
	Output file has the format asked by stampa such as:
	>GAXI01005455.1.1233 Bacteria|Bacteroidetes|Flavobacteriia|Flavobacteriales|Flavobacteriaceae|Chryseobacterium|Tetrodontophora_bielanensis_(giant_springtail)
	TCCGTAGGCGGACTCGTAAGTCAGTGGTGAAATCTCATAGCTTAACTATGAAACTGCCATTGATACTGCGGGTCTTGAGTAAAGTAGAAGTGGCT

	1. Find taxonomic number from scientific name (SN) OR GI (SN par default)
	2. Find Linage from taxomonic number in ncbi taxonomy database using Bio::DB::Taxonomy library
	3. Reformat header from input file in order to allow stampa to use it to taxonomic assignation

	option -dbase :
	Genbank
	RFAM
	UNITE
	BOLD

	option -gi :
	0 = find Taxonomy From Scientific Name
	1 = find Taxonomy From Bank Number

Contact: $courriel\n\n";
	

####################################
###### Recovery parameters #######
####################################

unless (@ARGV) 
	{
	print "\nType --help for more informations\n\n";
	exit;
	}

my ($infile,$outfile,$dbase,$bool,$help);

$outfile="out.txt";
$dbase="Genbank";
$bool=1;

GetOptions("help|?|h" => \$help,	
		"i|in=s"=>\$infile,
		"o|out=s"=>\$outfile,
		"d|dbase=s"=>\$dbase,
		"gi|banknumber=i"=>\$bool,
		);

if ($help){print $MessAbruti; exit;}

#files gestion
open my $IN, $infile or die ("\nCannot open the input file $infile: $!\nExiting...\n"); #FASTA FILE
open my $OUT, ">$outfile" or die ("\nCannot create the outpute file $outfile:$!\nExiting...\n"); # OUTPUT FILE

#import database taxonomy from ncbi
my $db = Bio::DB::Taxonomy->new(-source => 'entrez');

######################################## MAIN #####################################

while (my $line = <$IN>) 
{
	chomp $line;
	if ($line =~ /^\>/) #header line traitement 
	{
		my $cleanedHeader=headerTraitement($line,$bool,$dbase);
		print $OUT "$cleanedHeader\n";
	}
	else # sequence
	{
		my $cleanedFasta=fastaTraitement($line); #fasta line traitement
		print $OUT "$cleanedFasta\n";
	}
}


######################################## SUB #####################################

#sub to change fasta header in stampa format (include taxonomy informations)
sub headerTraitement ()
{
	#print "BOOL $bool\n";
	my ($lineHeader, $bool, $dbase) = @_;
	my @splitedHeader=split / / ,$lineHeader;
	my $bankNumber= "$splitedHeader[0]"; #recovery banknumber
	my $scientificName=""; # recovery scientific name
	my $linage="";
	if ((length ($splitedHeader[2])) <= 2)
	{
		$scientificName=$splitedHeader[1];
	}
	else
	{
		$scientificName="$splitedHeader[1] $splitedHeader[2]";
	}
	#print "SN: $scientificName\n";
	
	#changing header 
	my $bankID=changeHeader($bankNumber,$dbase); 
	#print "$bankID\n";
	
	if ($bool eq "0") #Finding taxonomy from scientific name
	{
		$linage=findTaxonomyFromScientificName($scientificName);
		#print "$linage\n";
		system("rm efetch.*");
	}
	else #Finding taxonomy from taxon number
	{
		my $taxonNumber=recoveryTaxonNumberFromBankNumber($bankNumber);
		#print $taxonNumber;
		$linage=findTaxonomyFromTaxonNumber($taxonNumber);
		#print "$linage\n";
	}
	#return the formated header
	my $newHeader="$bankID\t$linage";
	return $newHeader;
}

sub fastaTraitement() # pour l'instant la sequence ne change pas
{
	my ($lineFasta) = @_;
	return $lineFasta;
}


sub changeHeader # selon la base de données utilisé pour telecharger les fasta le banknumer est assez different
{
	my ($bankNumber, $dbase)=@_;
	if ($dbase eq "Genbank")
		{
			$bankNumber =~ s/gi\|/gi./g;
			$bankNumber =~ s/\|ref\|/_ref./g;
			$bankNumber =~ s/\|//g;
		}
	if ($dbase eq "RFAM") 
		{
			$bankNumber =~ s/ /_/g;
		}
	if ($dbase eq "UNITE")
		{
			$bankNumber =~ s/ /_/g;
		}
	if ($dbase eq "BOLD")
		{
			$bankNumber =~ s/ /_/g;
		}
	return $bankNumber;
}

sub recoveryTaxonNumberFromBankNumber
{
	my ($bankNumber)=@_;
	#print "BN === $bankNumber";
	$bankNumber =~ s/^>//g;
	#TAX="$(curl "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&amp;id=HQ844023.1&amp;rettype=fasta&amp;retmode=xml" | grep TSeq_taxid | cut -d '>' -f 2 | cut -d '<' -f 1)"
	my $url= "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&amp;id=$bankNumber&amp;rettype=fasta&amp;retmode=xml";
	my $commande="curl \"$url\" | grep TSeq_taxid | cut -d '>' -f 2 | cut -d '<' -f 1" ;
	#print "COM1: $commande\n";
	my $taxonNumber=`$commande`;
	#print "TN ===  $taxonNumber";
	return $taxonNumber;
}

sub findTaxonomyFromTaxonNumber #find taxonomy from taxon number
{
	my ($taxonNumber)=@_;
	chomp $taxonNumber;
	### recuperer linage using taxonNumer from taxonomy ncbi site directly
	my $url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=$taxonNumber&amp;rettype=fasta&amp;retmode=xml";
	my $commande="curl \"$url\" | grep -m2 '\\(<ScientificName>\\|<Lineage>\\)' | cut -d '>' -f 2 | cut -d '<' -f 1";
	#print "$commande\n";
	my $lineage=`$commande`;
	#print "my lineage is $lineage\n";
	$lineage =~ s/\n/== /g;
	$lineage =~ s/'//g;
	my @splitedLineage=split /== / ,$lineage;
	my $scientificName= "$splitedLineage[0]";
	my $lineageIncompleted= "$splitedLineage[1]";
	$lineage="$lineageIncompleted; $scientificName";
	$lineage =~ s/; /|/g;
	$lineage =~ s/ /_/g;
	return $lineage;
}

sub findTaxonomyFromScientificName 
{
	#print "-----AT---------\n";
	my ($scientificName)=@_;
	####################################
	###### Taxonomic assignation #######
	####################################
	# use NCBI Entrez over HTTP
	my $taxonid = $db->get_taxonid($scientificName);
	#print  "taxonid  $taxonid";
	### # si on veut utiliser le site taxonomy du ncbi directement
	my $url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=$taxonid";
	my $commande="wget \"$url\"" ;
	 `$commande`;
	$commande= "grep -iw lineage efetch.*$taxonid";
	my $string = `$commande`;
	chomp $string;
	$string =~ s/^.*\<Lineage\>|\<\/Lineage\>//g;
	$string="$string; $scientificName";
	$string =~ s/; /|/g;
	$string =~ s/ /_/g;
	return $string;
	#curl -s "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=9606" | grep -iw lineage | perl -ne '{if(/.*?\>(.*?)\<\/Lineage\>/){print $1,"\n";}}'
#            "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/elink.fcgi?dbfrom=nucleotide&amp;db=taxonomy&amp;id=29850143"
}

close $IN;
close $OUT;
