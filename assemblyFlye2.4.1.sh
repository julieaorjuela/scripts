#!/bin/sh

#### BASE SUR LE SCRIPT DE VALENTIN KLEIN ####

############      SGE CONFIGURATION      ###################
#$ -N FlyeMgra
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -pe ompi 10
#$ -S /bin/bash
#$ -o /home/orjuela/TEST-Flye/flye_$JOB_ID.log
#$ -j y
############################################################

REMOTE_FOLDER='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/FlyeMg'
#READS_SAMPLE='nas3:/data3/projects/graminicola_analysis/nanopore/*trim.fastq.gz'
READS_SAMPLE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/*trimmed_pass.fastq.gz'
TMP_FOLDER="/scratch/orjuela-$JOB_ID"
genome_size="75m"
treads=10

############# chargement du module
unset PYTHONUSERBASE
module load system/python/3.6.5
#module load bioinfo/Flye/2.3.3
#module load bioinfo/minimap2/2.10

###### Creation du repertoire temporaire sur  la partition /scratch du noeud
mkdir $TMP_FOLDER

####### copie du repertoire de donnees  vers la partition /scratch du noeud
echo "tranfert donnees master -> noeud (copie du fichier de reads)";
scp $READS_SAMPLE $TMP_FOLDER
cd $TMP_FOLDER

###### Execution du programme
echo "exec flye"
echo "/home/orjuela/tools/Flye2.4.1/bin/flye --nano-raw $TMP_FOLDER/*.fastq.gz --out-dir $TMP_FOLDER --genome-size $genome_size --threads $treads"
/home/orjuela/tools/Flye2.4.1/bin/flye --nano-raw $TMP_FOLDER/*.fastq.gz --out-dir $TMP_FOLDER --genome-size $genome_size --threads $treads

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



