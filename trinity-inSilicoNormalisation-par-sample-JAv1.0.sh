#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package insilicoNormalisation
# @author Sebastien Ravel. Adapted to trinity by Julie Orjuela
# TODO: accepte fastq.gz seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.
# avant de lancer ce script verifier pathToTrimmomatic, selon la quantité des données il faut modifier la memoire java -Xmx1G

version=1.0
path=`pwd`
softName="insilicoNormalisation"

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run softName on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files
 Output:
	compressed directory with softName results
 Exemple Usage: ./"$softName".sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./"$softName".sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
	printf "\033[36m #           Welcome to Run $softName directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-"$softName"/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis/$softName
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath

	
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
		scriptName=$count"_"$softName".sh"
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
			echo " " > $SHPath"/"$scriptName
			echo "# Charging modules"  >> $SHPath"/"$scriptName
			echo "module load toggleDev" >> $SHPath"/"$scriptName
			echo "module load bioinfo/trinityrnaseq/2.5.1" >> $SHPath"/"$scriptName 
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$scriptName
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$scriptName
			echo "pathToScratch=\""$pathTMP"/trinity_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$scriptName
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$scriptName
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$scriptName
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$scriptName
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$scriptName
			echo "scp "$fastqPath"/"$shortName"* \$pathToScratch/" >> $SHPath"/"$scriptName # on transfer les deux fastq
			
			#Running tool	
			echo " " >> $SHPath"/"$scriptName
			echo "cd \$pathToScratch/ " >> $SHPath"/"$scriptName
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$scriptName
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$scriptName
			echo "# Running tool"  >> $SHPath"/"$scriptName
			
			#Trinity insilico normalisaton of reads is running in each pair of reads (one sample independiently of replicates) 
			#echo "Trinity --seqType fq --left $R1 --right $R2 --max_memory 50G --CPU 8 --output \$pathToScratch/results_$shortName/trinity_OUT " >> $SHPath"/"$scriptName
			echo "perl /usr/local/trinityrnaseq-2.5.1/util/insilico_read_normalization.pl --seqType fq --JM 4G --max_cov 50 --left $R1 --right $R2 --pairs_together --output \$pathToScratch/results_$shortName/insil_norm" >> $SHPath"/"$scriptName     
			#Printing command executed
			#echo "cmd=\"  Trinity --seqType fq --left $R1 --right $R2 --max_memory 50G --CPU 8 --output \$pathToScratch/results_$shortName/trinity_OUT  \"" >> $SHPath"/"$scriptName
			echo "cmd=\"  perl /usr/local/trinityrnaseq-2.5.1/util/insilico_read_normalization.pl --seqType fq --JM 4G --max_cov 50 --left $R1 --right $R2 --pairs_together --PARALLEL_STATS --CPU 4 --output \$pathToScratch/results_$shortName/insil_norm  \"" >> $SHPath"/"$scriptName					
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$scriptName
			
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$scriptName
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$scriptName
			echo "scp -rp \$pathToScratch/results_"$shortName" \$pathToDest/"  >> $SHPath"/"$scriptName
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$scriptName
			
			# Suppression du repertoire tmp noeud
			echo " " >> $SHPath"/"$scriptName	
			echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$scriptName
			echo "rm -rf \$pathToScratch" >> $SHPath"/"$scriptName
			echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$scriptName	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N insilicoNormalisation
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
#$ -l mem_free=6G
#$ -pe ompi 4
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_insilicoNormalisation.sh
	'>> $pathAnalysis"/submitQsub.sge"

	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run Trinity _insilicoNormalisation for "$count" fastq pairs,
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
