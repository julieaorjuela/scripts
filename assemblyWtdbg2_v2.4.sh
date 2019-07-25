#!/bin/sh

#### BASE SUR LE SCRIPT DE VALENTIN KLEIN ####
# wtdbg2 v.2.4
############      SGE CONFIGURATION      ###################
#$ -N Wtdbg2_Mgra
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -pe ompi 8
#$ -S /bin/bash
#$ -o /home/orjuela/TEST-wtdbg2/wtdbg2_$JOB_ID.log
#$ -j y
############################################################

REMOTE_FOLDER='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/wtdbg2Mg'
READS_SAMPLE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/VN18_trimmed_pass.fastq.gz'
TMP_FOLDER="/scratch/orjuela-$JOB_ID"

############# chargement du module
unset PYTHONUSERBASE
#module load system/python/3.6.5

###### Creation du repertoire temporaire sur  la partition /scratch du noeud
mkdir $TMP_FOLDER

####### copie du repertoire de donnees  vers la partition /scratch du noeud
echo "tranfert donnees master -> noeud (copie du fichier de reads)";
scp $READS_SAMPLE $TMP_FOLDER
cd $TMP_FOLDER

###### Execution du programme
echo "exec wtdbg2 ... generating asm
echo "/home/orjuela/tools/wtdbg2/wtdbg2 -t 8 -g 75m -i $TMP_FOLDER/VN18_trimmed_pass.fastq.gz -fo vn18" #$TMP_FOLDER/VN18_minimap2.asm"
/home/orjuela/tools/wtdbg2/wtdbg2 -t 8 -g 75m -i $TMP_FOLDER/VN18_trimmed_pass.fastq.gz -fo vn18

echo "exec wtbdg2 .. generating consensus"
echo "/home/orjuela/tools/wtdbg2/wtpoa-cns -t 8 -i asm.ctg.lay.gz -fo asm.fasta"
/home/orjuela/tools/wtdbg2/wtpoa-cns -t 8 -i vn18.ctg.lay.gz -fo vn18-wtdbg2.fasta

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



