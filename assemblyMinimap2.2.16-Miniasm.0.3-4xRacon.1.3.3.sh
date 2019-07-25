#!/bin/sh

#### BASE SUR LE SCRIPT DE VALENTIN KLEIN ####
# minimap2  2.16-r922
# miniasm 0.3-r179
#racon version v1.3.3
############      SGE CONFIGURATION      ###################
#$ -N Minimap2Miniasm_Mgra
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -pe ompi 8
#$ -S /bin/bash
#$ -o /home/orjuela/TEST-MinimapMiniasm/minimapMiniasm_$JOB_ID.log
#$ -j y
############################################################

REMOTE_FOLDER='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/minimap2MiniasmMg'
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
echo "exec minimap2 .. generating paf"
echo "/home/orjuela/tools/minimap2/minimap2 -t 8 -x ava-ont $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_trimmed_pass.fastq.gz > $TMP_FOLDER/VN18_minimap2.paf"
/home/orjuela/tools/minimap2/minimap2 -t 8 -x ava-ont $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_trimmed_pass.fastq.gz > $TMP_FOLDER/VN18_minimap2.paf


echo "exec miniasm .. generating assembly"
echo "/home/orjuela/tools/miniasm/miniasm -f $TMP_FOLDER/VN18_minimap2.paf > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa "
/home/orjuela/tools/miniasm/miniasm -f $TMP_FOLDER/VN18_trimmed_pass.fastq.gz  $TMP_FOLDER/VN18_minimap2.paf > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa

# Consensus
## GFA to fasta
awk '$1 ~/S/ {print ">"$2"\n"$3}' $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa > $TMP_FOLDER/VN18_minimap2_miniasm_draft.fasta

########### Correction 1
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/VN18_minimap2_miniasm_draft.fasta $TMP_FOLDER/VN18_trimmed_pass.fastq.gz >  $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa1.paf
#racon1
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa1.paf  $TMP_FOLDER/VN18_minimap2_miniasm_draft.fasta > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa1.racon1.fasta

########### Correction 2 (optional)
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa1.racon1.fasta $TMP_FOLDER/VN18_trimmed_pass.fastq.gz >$TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa2.paf
#racon2
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa2.paf $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa1.racon1.fasta > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa2.racon2.fasta

########### Correction 3 (optional)
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa2.racon2.fasta $TMP_FOLDER/VN18_trimmed_pass.fastq.gz >$TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa3.paf
#racon3
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa3.paf $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa2.racon2.fasta > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa3.racon3.fasta

########### Correction 4 (optional)
/home/orjuela/tools/minimap2/minimap2 -t 8 $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa3.racon3.fasta $TMP_FOLDER/VN18_trimmed_pass.fastq.gz >$TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa4.paf
#racon2
/home/orjuela/tools/racon/build/bin/racon -t 8 $TMP_FOLDER/VN18_trimmed_pass.fastq.gz $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa4.paf $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa3.racon3.fasta > $TMP_FOLDER/VN18_minimap2_miniasm_draft.gfa4.racon4.fasta


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



