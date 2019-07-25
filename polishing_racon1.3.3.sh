#!/bin/sh

#### BASE SUR LE SCRIPT DE VALENTIN KLEIN ####
# minimap2  2.16-r922
# miniasm 0.3-r179
#racon version v1.3.3
############      SGE CONFIGURATION      ###################
#$ -N Racon
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -pe ompi 8
#$ -S /bin/bash
#$ -o /home/orjuela/TEST-racon/racon_$JOB_ID.log
#$ -j y
############################################################
HERE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/'
REMOTE_FOLDER=$HERE"/racon"
READS_SAMPLE=$HERE"/VN18_trimmed_pass.fastq.gz"
#DRAFT=$HERE"/wtdbg2Mg/orjuela-1591928/vn18-wtdbg2.fasta" #35M
#DRAFT=$HERE"/wtdbg2Mg/orjuela-1592108/vn18-wtdbg2.fasta" #75M
#DRAFT=$HERE"/FlyeMg/orjuela-1591871/vn18-flye.fasta"#35M
DRAFT=$HERE"/FlyeMg/orjuela-1592107/vn18-flye.fasta" #75M

TMP_FOLDER="/scratch/orjuela-$JOB_ID"

#recupere le nom du fichier fastq
for i in $(echo ${READS_SAMPLE} | tr "/" "\n")
do
  FASTQFILE=$i
done
FASTQFILENAME=`echo ${FASTQFILE} | cut -d \. -f 1` # VN18_trimmed_pass

#recupere le nom du draft fasta
for i in $(echo ${DRAFT} | tr "/" "\n")
do
  DRAFTFILE=$i
done
DRAFTFILENAME=`echo ${DRAFTFILE} | cut -d \. -f 1` #VN18_minimap2_miniasm_draft

echo "FASTQFILENAME $FASTQFILENAME"
echo "DRAFTFILENAME $DRAFTFILENAME"

############# chargement du module
unset PYTHONUSERBASE
#module load system/python/3.6.5

###### Creation du repertoire temporaire sur  la partition /scratch du noeud
mkdir $TMP_FOLDER

####### copie du repertoire de donnees  vers la partition /scratch du noeud
echo "tranfert donnees master -> noeud (copie du fichier de reads)";
scp $READS_SAMPLE $TMP_FOLDER
scp $DRAFT $TMP_FOLDER
cd $TMP_FOLDER

########### Correction 1
echo "/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILE $TMP_FOLDER/$FASTQFILE >  $TMP_FOLDER/$DRAFTFILENAME.gfa1.paf"
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILE $TMP_FOLDER/$FASTQFILE >  $TMP_FOLDER/$DRAFTFILENAME.gfa1.paf
#racon1
echo "/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa1.paf  $TMP_FOLDER/$DRAFTFILENAME.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta"
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa1.paf  $TMP_FOLDER/$DRAFTFILENAME.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta

########### Correction 2 (optional)
echo "/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa2.paf"
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa2.paf
#racon2
echo "/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa2.paf $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta"
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa2.paf $TMP_FOLDER/$DRAFTFILENAME.gfa1.racon1.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta

########### Correction 3 (optional)

echo "/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa3.paf"
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa3.paf
#racon3
echo "/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa3.paf $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta"
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa3.paf $TMP_FOLDER/$DRAFTFILENAME.gfa2.racon2.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta

########### Correction 4 (optional)
echo "/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa4.paf"
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta $TMP_FOLDER/$FASTQFILE >$TMP_FOLDER/$DRAFTFILENAME.gfa4.paf
#racon2
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa4.paf $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa4.racon4.fasta
echo "/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/$FASTQFILE $TMP_FOLDER/$DRAFTFILENAME.gfa4.paf $TMP_FOLDER/$DRAFTFILENAME.gfa3.racon3.fasta > $TMP_FOLDER/$DRAFTFILENAME.gfa4.racon4.fasta"

echo "supression du fichier reads"
rm *.fastq.gz

##### Transfert des donnees du noeud vers master
echo "Transfert donnees node -> master";
scp -r $TMP_FOLDER $REMOTE_FOLDER

if [[ $? -ne 0 ]]; then
    echo "transfer failed on $HOSTNAME in $TMP_FOLDER"
else
    echo "Suppression des donnees sur le noeud";
    rm -rf $TMP_FOLDER;
fi
