#!/bin/sh
#Autor: Valentin Klein, modified by Julie Orjuela

# minimap2  2.16-r922

############      SGE CONFIGURATION      ###################
# Ecrit les erreur dans le fichier de sortie standard
#$ -j y
#$ -pe ompi 8
#$ -S /bin/bash
#$ -M julie.orjuela@ird.fr
# Type de massage que l'on reçoit par mail
#    -  (b) un message au demarrage
#    -  (e) a la fin
#    -  (a)  en cas d'abandon
#$ -m ea
#$ -q bioinfo.q 
#$ -N Pilon
#$ -o /home/orjuela/TEST-pilon/pilon_$JOB_ID.log
############################################################

HERE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/'
REMOTE_FOLDER=$HERE"/pilon"
READS_SAMPLE=$HERE"/VN18_trimmed_pass.fastq.gz"
MINIMAP2="/home/orjuela/tools/minimap2/minimap2"
TMP_FOLDER="/scratch/orjuela-$JOB_ID"
REF="$HERE/Mfloridensis/nMf.1.1.fasta"
#scaffolds="$HERE/FlyeMg/orjuela-1591871/vn18-flye.gfa4.racon4.fasta" #Flye35M
#scaffolds="$HERE/minimap2MiniasmMg/orjuela-1591919/VN18_minimap2_miniasm_draft.gfa4.racon4.fasta" 
#scaffolds="$HERE/wtdbg2Mg/orjuela-1591928/vn18-wtdbg2.gfa4.racon4.fasta" #Wtbdg2_35M
#scaffolds="$HERE/wtdbg2Mg/orjuela-1592108/vn18-wtdbg2.gfa4.racon4.fasta" ##Wtbdg2_75M
scaffolds="$HERE/FlyeMg/orjuela-1592107/vn18-flye.gfa4.racon4.fasta" ##Flye_75M

illumina_reads="/data3/projects/graminicola_analysis/Hiseq_Mg"

mkdir $TMP_FOLDER
cd $TMP_FOLDER
echo "copie scaffolds dans TMP_FOLDER"
scp $scaffolds scaffolds.fasta
echo "copie d'une REF dans TMP_FOLDER"
scp $REF ref.fasta
echo "copie reads"
scp $illumina_reads/MgVN18_S1_*.fastq.gz $TMP_FOLDER
echo "unpack"
#unpigz -p 8 *.fastq.gz
#echo "unpigz -p 8 *.fastq.gz"
echo "gunzip *.fastq.gz"
gunzip *.fastq.gz
echo "loading modules (java,samtools,MINIMAP2,MUMmer)"
module load system/java/jre-1.8.111
module load bioinfo/samtools/1.7
#module load bioinfo/minimap2/2.10
module load bioinfo/MUMmer/4.0.0beta2

echo "map illumina vs scaffolds obtained by Flye"
echo "$MINIMAP2 -t 8 -ax sr scaffolds.fasta MgVN18_S1_1.fastq MgVN18_S1_2.fastq | samtools sort -@ 2 -T mappings.sorted.tmp -o mappings.sorted.bam
samtools index mappings.sorted.bam"
$MINIMAP2 -t 8 -ax sr scaffolds.fasta MgVN18_S1_1.fastq MgVN18_S1_2.fastq | samtools sort -@ 2 -T mappings.sorted.tmp -o mappings.sorted.bam

echo "indexing bam"
echo "samtools index mappings.sorted.bam"
samtools index mappings.sorted.bam

echo "filter only correctly paired mapped reads"
echo "samtools view -f 2 -o mappings.proper-pairs.bam mappings.sorted.bam"
samtools view -f 2 -o mappings.proper-pairs.bam mappings.sorted.bam

echo "indexing bam"
echo "samtools index mappings.proper-pairs.bam"
samtools index mappings.proper-pairs.bam

echo "polish"
echo "java -Xmx100G -jar /home/orjuela/tools/pilon-1.23.jar --genome scaffolds.fasta --frags mappings.sorted.bam --output polish --threads 8"
java -Xmx100G -jar /home/orjuela/tools/pilon-1.23.jar --genome scaffolds.fasta --frags mappings.proper-pairs.bam --output polish --threads 8


echo "mapping polishvsref"
echo "mkdir mapref"
mkdir mapref
echo "nucmer -t 8 --delta mapref/polishvsref.delta ref.fasta polish.fasta"
nucmer -t 8 --delta mapref/polishvsref.delta ref.fasta polish.fasta
echo "dnadiff --prefix mapref/polishvsref -d mapref/polishvsref.delta"
dnadiff --prefix mapref/polishvsref -d mapref/polishvsref.delta


echo "mapping scaffoldssvspolish"
echo "mkdir map"
mkdir map
echo "nucmer -t 8 --delta map/scaffoldssvspolish.delta scaffolds.fasta polish.fasta"
nucmer -t 8 --delta map/scaffoldssvspolish.delta scaffolds.fasta polish.fasta
echo "dnadiff --prefix map/scaffoldssvspolish -d map/scaffoldssvspolish.delta"
dnadiff --prefix map/scaffoldssvspolish -d map/scaffoldssvspolish.delta

echo "cleaning"
rm *.fastq
#rm *.bam


echo "transfering results"
rsync -av -e ssh $TMP_FOLDER $REMOTE_FOLDER
if [[ $? -ne 0 ]]; then
    echo "transfer failed on $HOSTNAME in $TMP_FOLDER"
else
    echo "Suppression des donnees sur le noeud";
    rm -rf $TMP_FOLDER;
fi



