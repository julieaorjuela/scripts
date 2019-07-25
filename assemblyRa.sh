#!/bin/sh

#### BASE SUR LE SCRIPT DE VALENTIN KLEIN ####
# Ra v0.2.1
############      SGE CONFIGURATION      ###################
#$ -N Ra_Mgra
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -pe ompi 8
#$ -S /bin/bash
#$ -o /home/orjuela/TEST-Ra/Ra_$JOB_ID.log
#$ -j y
############################################################

REMOTE_FOLDER='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/Ra'
READS_SAMPLE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/VN18_trimmed_pass.fastq.gz'
TMP_FOLDER="/scratch/orjuela-$JOB_ID"
illumina_reads="/data3/projects/graminicola_analysis/Hiseq_Mg"


############# chargement du module
unset PYTHONUSERBASE
#module load system/python/3.6.5

###### Creation du repertoire temporaire sur  la partition /scratch du noeud
mkdir $TMP_FOLDER

####### copie du repertoire de donnees  vers la partition /scratch du noeud
echo "copie illumina reads"
scp $illumina_reads/MgVN18_*.fastq.gz $TMP_FOLDER
echo "tranfert reads nanopore au master -> noeud (copie du fichier de reads)";
scp $READS_SAMPLE $TMP_FOLDER
cd $TMP_FOLDER
#concatener illumina reads
cat MgVN18_*.fastq.gz > illumina.fastq.gz

###### Execution du programme
echo "exec ra .. generating assembly"
echo "/home/orjuela/tools/ra/build/bin/ra -t 8 -x ont VN18_trimmed_pass.fastq.gz illumina.fastq.gz"
/home/orjuela/tools/ra/build/bin/ra -t 8 -x ont VN18_trimmed_pass.fastq.gz illumina.fastq.gz
#/home/orjuela/tools/ra/build/bin/ra -t 8 -x ont VN18_trimmed_pass.fastq.gz

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



