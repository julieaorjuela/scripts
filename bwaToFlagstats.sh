#!/bin/sh
#Autor: Julie Orjuela
#20190328

############      SGE CONFIGURATION      ###################
# Ecrit les erreur dans le fichier de sortie standard
#$ -j y
#$ -pe ompi 4
#$ -S /bin/bash
#$ -M julie.orjuela@ird.fr
# Type de massage que l'on reçoit par mail
#    -  (b) un message au demarrage
#    -  (e) a la fin
#    -  (a)  en cas d'abandon
#$ -m ea
#$ -q bioinfo.q 
#$ -N bamToFlagstats
#$ -o /home/orjuela/TEST-bwa/bwaToFlagstats_$JOB_ID.log
############################################################


align_reads () {
    ASSEMBLY="$1" # The assembly is the first parameter to this function. Must end in .fasta
    READ1="$2" # The first read pair is the second parameter to this function
    READ2="$3" # The second read pair is the third parameter to this function
    bwa index "$ASSEMBLY" # Index the assembly prior to alignment
    bwa mem -t "${CPUS:-4}" "$ASSEMBLY" "$READ1" "$READ2" | samtools sort -@ 4 -T "${ASSEMBLY/.fasta/}" -O BAM -o "${ASSEMBLY/.fasta/_bwa_alignment.bam}" -
    samtools index "${ASSEMBLY/.fasta/_bwa_alignment.bam}"
    # bwa mem : Align reads to the assembly
    # samtools sort : Sort the output by coordinate
    #    -O BAM : save the output as a BAM file
    #    -@ <int> : use <int> cores
    #    -T <temp> : Write temporary files to <temp>.nnnn.bam
    # samtools index : index the BAM file
    samtools flagstat "${ASSEMBLY/.fasta/_bwa_alignment.bam}" > "${ASSEMBLY/.fasta/_bwa_alignment.bam.stats}"
    # samtools flagstat : basic alignment statistics
}

ASS="$1"
echo "ASSEMBLY: $ASS"
HERE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/postassembly/'
REMOTE_FOLDER=$HERE"/bwa_"$ASS
TMP_FOLDER="/scratch/orjuela-$JOB_ID"
FASTA="$HERE/$ASS"
illumina_reads="/data3/projects/graminicola_analysis/Hiseq_Mg"

mkdir $TMP_FOLDER
cd $TMP_FOLDER
echo "copie d'une REF d'assemblage dans TMP_FOLDER"
scp $FASTA $TMP_FOLDER
echo "copie reads"
scp $illumina_reads/MgVN18_S1_*.fastq.gz $TMP_FOLDER

echo "loading modules ..."
module load system/java/jre-1.8.111
module load bioinfo/samtools/1.7
module load bioinfo/bwa/0.7.17

echo "running fonction : "
echo "align_reads $TMP_FOLDER/$ASS MgVN18_S1_1.fastq MgVN18_S1_2.fastq"
align_reads "$TMP_FOLDER/$ASS"  MgVN18_S1_1.fastq.gz MgVN18_S1_2.fastq.gz

echo "cleaning"
rm $TMP_FOLDER/*fastq.gz $TMP_FOLDER/$ASS

echo "transfering results"
rsync -av -e ssh $TMP_FOLDER $REMOTE_FOLDER
if [[ $? -ne 0 ]]; then
    echo "transfer failed on $HOSTNAME in $TMP_FOLDER"
else
    echo "Suppression des donnees sur le noeud";
    rm -rf $TMP_FOLDER;
fi

