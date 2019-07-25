#!/bin/sh
############      SGE CONFIGURATION      ###################
#$ -N CanuMgra
#$ -cwd
#$ -V
#$ -q bioinfo.q
#$ -S /bin/bash
#$ -pe ompi 10
#$ -o /home/orjuela/TEST-canu/canu_$JOB_ID.log
#$ -j y
############################################################

REMOTE_FOLDER='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/canu/'
READS_SAMPLE='nas3:/data3/projects/graminicola_analysis/SECOND-VN18/assembly/*fastq.gz'
TMP_FOLDER="/scratch/orjuela-$JOB_ID";
############# chargement du module
unset PYTHONUSERBASE
module load system/perl/5.24.0
module load bioinfo/canu/1.6
module load bioinfo/gnuplot/5.0.4

###### Creation du repertoire temporaire sur  la partition /scratch du noeud
mkdir $TMP_FOLDER

####### copie du repertoire de donnees  vers la partition /scratch du noeud
echo "tranfert donnees master -> noeud (copie du fichier de reads)";
scp $READS_SAMPLE $TMP_FOLDER
cd $TMP_FOLDER

###### Execution du programme
echo "exec canu1.6"
#echo "canu genomeSize=35M -nanopore-raw $TMP_FOLDER/*trim.fastq.gz -d $TMP_FOLDER -p Mgra useGrid=1 gridOptions="-q bioinfo.q -pe parallel_smp 10 -V " gnuplot="/usr/local/gnuplot-5.0.4/bin/gnuplot" gnuplotTested=true corOutCoverage=100 mhapSensitivity=normal corMhapSensitivity=normal correctedErrorRate=0.144"
echo "canu genomeSize=35M -nanopore-raw $TMP_FOLDER/*fastq.gz -d $TMP_FOLDER -p Mgra-canu35M useGrid=0 gnuplot="/usr/local/gnuplot-5.0.4/bin/gnuplot" gnuplotTested=true corOutCoverage=100 mhapSensitivity=normal corMhapSensitivity=normal correctedErrorRate=0.144"
#canu genomeSize=35M -nanopore-raw $TMP_FOLDER/VN18_nanopore_trim.fastq.gz -d $TMP_FOLDER -p VN18 useGrid=1 gridOptions="-q bioinfo.q -pe ompi 10 -V" gnuplot="/usr/local/gnuplot-5.0.4/bin/gnuplot" gnuplotTested=true corOutCoverage=100 mhapSensitivity=normal corMhapSensitivity=normal correctedErrorRate=0.144
canu genomeSize=35M -nanopore-raw $TMP_FOLDER/*.fastq.gz -d $TMP_FOLDER -p Mgra-canu35M useGrid=0 gnuplot="/usr/local/gnuplot-5.0.4/bin/gnuplot" gnuplotTested=true corOutCoverage=100 mhapSensitivity=normal corMhapSensitivity=normal correctedErrorRate=0.144

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



