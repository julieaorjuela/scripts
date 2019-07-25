#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_trinity.sh
# @author Sebastien Ravel. Adapted to trinity by Julie Orjuela
# TODO: accepte fastq.gz seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.
# avant de lancer ce script verifier pathToTrimmomatic, selon la quantité des données il faut modifier la memoire java -Xmx1G

version=1.0
path=`pwd`

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run trinity on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files
 Output:
	compressed directory with trinity results
 Exemple Usage: ./run_trinity.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./run_trinity.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
	options:
		-f {path/to/fastq} = path to fastq
		-m {email} = email to add to qsub job end (not mandatory)
		-h = see help\n\n"
	exit 0
}


##################################################
## Parse command line options
##################################################.
while getopts f:g:m:h: OPT;
	do case $OPT in
		f)	fastq=$OPTARG;;
		m)	mail=$OPTARG;;
		h)	help;;
		\?)	help;;
	esac
done

if [ $# -eq 0 ]; then
	help
fi


##################################################
## Main code
##################################################

if [ -z ${mail+x} ]; then
	cmdMail=""
else
	cmdMail="-M $mail -m beas"
fi

if [ $fastq != "" ] ; then
	#version
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #           Welcome to Run trinity directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-trinity/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"trinity"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	#pathDest="nas3:/data3/projects/arapaima/FASTQC/"
	pathDest=$fastResultsPath
	pathToTrimmomatic="/usr/local/Trimmomatic-0.33/"
	pathToTrimmomaticAdapters="$pathToTrimmomatic/adapters/TruSeq2-PE.fa"
	pathToTrimmomaticHomeAdapters="/data3/projects/arapaima/adapt-125pbLib.txt"
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fastq were found in directory: \n"$fastqPath
	printf "\033[32m \n Output trinity will be write in directory: "$fastResultsPath"\n\n"
	
	#create trash repertory
    if [ -d $trashPath ]; then
		rm -r $trashPath
		mkdir $trashPath
	else
		mkdir $trashPath
    fi
	
	#create sh repertory
	if [ -d $SHPath ]; then
		rm -r $SHPath
		mkdir $SHPath
	else
		mkdir $SHPath
	fi
	
	#create trinity repertory
	if [ -d $fastResultsPath ]; then
		rm -r $fastResultsPath
		mkdir $fastResultsPath
	else
		mkdir $fastResultsPath
	fi
    
	#create submitSGE script
	if [ ! -e $pathAnalysis"/submitQsub.sge" ]; then
		touch $pathAnalysis"/submitQsub.sge";
	else
		rm $pathAnalysis"/submitQsub.sge";
		touch $pathAnalysis"/submitQsub.sge";
	fi

	#parcourir le dossier input
	count=1
	for f in $fastqPath/*
	do
		if [[ "$f" =~ "R1.fastq" ]] || [[ "$f" =~ "R1.fastq.gz"  ]] || [[ "$f" =~ "R1.fq"  ]] || [[ "$f" =~ "R1.fq.gz"  ]]; then
			name=$(basename ${f%%.R1.fastq})
			name=$(basename ${f%%.R1.fastq.gz})
			name=$(basename ${f%%.R1.fq})
			name=$(basename ${f%%.R1.fq.gz})
			shortName=$(echo $name | cut -d "." -f 1)
			shortName=$(echo $name | cut -d "_" -f 1)
			echo $shortName
			R1="\$pathToScratch/"$shortName"_R1.fastq.gz"
			R2="\$pathToScratch/"$shortName"_R2.fastq.gz"
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_trinity.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_trinity.sh"
			echo "module load toggleDev" >> $SHPath"/"$count"_trinity.sh"
			echo "module load bioinfo/trinityrnaseq/2.5.1" >> $SHPath"/"$count"_trinity.sh" 
			echo "module load bioinfo/Trimmomatic/0.33" >> $SHPath"/"$count"_trinity.sh" 
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_trinity.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_trinity.sh"
			echo "pathToScratch=\""$pathTMP"/trinity_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_trinity.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_trinity.sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_trinity.sh"
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_trinity.sh"
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$count"_trinity.sh"
			echo "scp "$fastqPath"/"$shortName"* \$pathToScratch/" >> $SHPath"/"$count"_trinity.sh" # on transfer les deux fastq
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_trinity.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_trinity.sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_trinity.sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_trinity.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_trinity.sh"
			
			#Trinity is running in each pair of reads (one sample independiently of replicates) 
			echo "Trinity --seqType fq --left $R1 --right $R2 --max_memory 50G --CPU 8 --output \$pathToScratch/results_$shortName/trinity_OUT " >> $SHPath"/"$count"_trinity.sh"
			#Printing command executed
			echo "cmd=\"  Trinity --seqType fq --left $R1 --right $R2 --max_memory 50G --CPU 8 --output \$pathToScratch/results_$shortName/trinity_OUT  \"" >> $SHPath"/"$count"_trinity.sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_trinity.sh"
			echo " " >> $SHPath"/"$count"_trinity.sh"
			
			# lancer stats tranrate et busco apres avoir assamblé (codé mais jamais testé)
			#path to Trinity.fasta
			#echo "#define fasta path " >> $SHPath"/"$count"_trinity.sh"
			#echo "fasta=\$pathToScratch/results_$shortName/trinity_OUT/Trinity.fasta " >> $SHPath"/"$count"_trinity.sh"
			#echo "#running TrinityStats " >> $SHPath"/"$count"_trinity.sh"
			##run stats de l'assemblage
			#echo ""perl /usr/local/trinityrnaseq-2.5.1/util/TrinityStats.pl \$fasta""  >> $SHPath"/"$count"_trinity.sh"
			#echo "cmd=\"perl /usr/local/trinityrnaseq-2.5.1/util/TrinityStats.pl \$fasta\"" >> $SHPath"/"$count"_trinity.sh"
			#echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_trinity.sh"
			#echo " " >> $SHPath"/"$count"_trinity.sh"
			#
			##run transrate
			#echo "#running transrate " >> $SHPath"/"$count"_trinity.sh"
			#echo ""/usr/local/transrate-1.0.3/bin/transrate --assembly  \$fasta --left $R1 --right $R2 --output \$pathToScratch/results_$shortName/transrate_outdir"" >> $SHPath"/"$count"_trinity.sh"
			#echo "cmd=\" /usr/local/transrate-1.0.3/bin/transrate --assembly  \$fasta --left $R1 --right $R2 --output \$pathToScratch/results_$shortName/transrate_outdir   \"" >> $SHPath"/"$count"_trinity.sh"     
			#echo " " >> $SHPath"/"$count"_trinity.sh"
			#
			##run BUSCO
			#echo "#running busco " >> $SHPath"/"$count"_trinity.sh"
			#echo ""BUSCOPathDB=\"/home/orjuela/BUSCO_DB/actinopterygii_odb9\""" >> $SHPath"/"$count"_trinity.sh"
			#echo "# Running tool busco"   >> $SHPath"/"$count"_trinity.sh" 	
			#echo ""python /usr/local/BUSCO-3.0.2/scripts/run_BUSCO.py -i \$fasta -o \$pathToScratch/results_$shortName/BUSCO -l \$BUSCOPathDB -m transcriptome -c 8 ""  >> $SHPath"/"$count"_trinity.sh" 
			#echo "cmd= python3 /usr/local/BUSCO-3.0.2/scripts/run_BUSCO.py -i \$fasta -o \$pathToScratch/results_$shortName/BUSCO -l \$BUSCOPathDB -m transcriptome -c 8  \"" >> $SHPath"/"$count"_trinity.sh" 
			#echo "echo \"commande executee: \$cmd\""  >> $SHPath"/"$count"_trinity.sh" 
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_trinity.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_trinity.sh"
			echo "scp -rp \$pathToScratch/results_"$shortName" \$pathToDest/"  >> $SHPath"/"$count"_trinity.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_trinity.sh"
			
			# Suppression du repertoire tmp noeud
			#echo " " >> $SHPath"/"$count"_trinity.sh"	
			#echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_trinity.sh"
			#echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_trinity.sh"
			#echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_trinity.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N trinity
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q highmem.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
#$ -l mem_free=60G
#$ -pe ompi 8
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_trinity.sh
	'>> $pathAnalysis"/submitQsub.sge"


	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run Trinity for "$count" fastq pairs,
 The script are created .sh for all fastq into "$pathAnalysis"sh,\n
 For run all sub-script in qsub, a submitQsub.sge was created, It lunch programm make:\n"

	printf "\033[35m \tqsub "$pathAnalysis"submitQsub.sge "$cmdMail"\n\n"
	# Print end
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #                        End of execution                          #\n";
	printf "\033[36m ####################################################################\n";

# if arguments empty
else
	echo "\033[31m you select fastq = "$fastq
	echo "\033[31m you select mail = "$mail
	printf "\033[31m \n\n You must inform all the required options !!!!!!!!!!!! \n\n"
	help
fi
