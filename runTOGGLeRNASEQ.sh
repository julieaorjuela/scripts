#!/bin/bash
#$ -N TOGGLeRNAseq
#$ -b yes
#$ -q bioinfo.q
#$ cwd
#$ -V

dir="/data/projects/TALseq/RNASEQ/CLEANED-DATA/IR64"
out="/data/projects/TALseq/RNASEQ/TOGGLe/OUTPUT"
config="/data/projects/TALseq/RNASEQ/TOGGLe/RNASeqHisat2Stringtie.config.txt"
ref="/data/projects/TALseq/RNASEQ/REF/IR64-201810.fasta"
#gff="/data/projects/TALseq/RNASEQ/REF/ir64.gff"
## Software-specific settings exported to user environment
module load toggleDev

#running tooglegenerator 
toggleGenerator.pl -d $dir -c $config -o $out -r $ref --report --nocheck;

echo "FIN"

