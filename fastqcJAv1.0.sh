#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_fastqc.sh
# @author Sebastien Ravel. Adapted to fastqc by Julie Orjuela

version=1.0
path=`pwd`

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run fastqc on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files
 Output:
	compressed directory with fastqc results
 Exemple Usage: ./run_fastqc.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./run_fastqc.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
	printf "\033[36m #           Welcome to Run fastqc directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-fastqc/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastQCPath=$pathAnalysis"fastqc"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	#pathDest="nas3:/data3/projects/arapaima/FASTQC/"
	pathDest=$fastQCPath
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fastq were found in directory: \n"$fastqPath
	printf "\033[32m \n Output FASTQC will be write in directory: "$fastQCPath"\n\n"
	
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
	
	#create fastqc repertory
	if [ -d $fastQCPath ]; then
		rm -r $fastQCPath
		mkdir $fastQCPath
	else
		mkdir $fastQCPath
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
		if [[ "$f" =~ ".fastq" ]] || [[ "$f" =~ ".fastq.gz"  ]] || [[ "$f" =~ ".fq"  ]] || [[ "$f" =~ ".fq.gz"  ]]; then
			name=$(basename ${f%%.fastq})
			name=$(basename ${f%%.fastq.gz})
			name=$(basename ${f%%.fq})
			name=$(basename ${f%%.fq.gz})
			
			echo ">>>>>>>>>>>" $name
			#writting in sh file (managing transfer)
			#modules
			echo " " > $SHPath"/"$count"_fastqc.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_fastqc.sh"
			echo "module load bioinfo/FastQC/0.11.5" >> $SHPath"/"$count"_fastqc.sh" #creation de fichier .sh avec les commandes de transfer vers scratch
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_fastqc.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_fastqc.sh"
			echo "pathToScratch=\""$pathTMP"/fastqc_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_fastqc.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_fastqc.sh"
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_fastqc.sh"
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_fastqc.sh"
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$count"_fastqc.sh"
			echo "scp "$fastqPath"/"$name" \$pathToScratch/" >> $SHPath"/"$count"_fastqc.sh"
			#Running tool
			echo " " >> $SHPath"/"$count"_fastqc.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_fastqc.sh"
			echo "mkdir \$pathToScratch/results_$name" >> $SHPath"/"$count"_fastqc.sh"
			echo "cd \$pathToScratch/results_$name/" >> $SHPath"/"$count"_fastqc.sh"
			echo " " >> $SHPath"/"$count"_fastqc.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_fastqc.sh"
			echo "fastqc -o \$pathToScratch/results_$name/ -t 8 --noextract \$pathToScratch/$name" >> $SHPath"/"$count"_fastqc.sh"
			echo "cmd=\"fastqc -o \$pathToScratch/results_$name/ --noextract \$pathToScratch/$name\"" >> $SHPath"/"$count"_fastqc.sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_fastqc.sh"
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_fastqc.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_fastqc.sh"
			echo "scp -rp \$pathToScratch/results_"$name"/ \$pathToDest/"  >> $SHPath"/"$count"_fastqc.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_fastqc.sh"
			# Suppression du repertoire tmp noeud
			echo " " >> $SHPath"/"$count"_fastqc.sh"	
			echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_fastqc.sh"
			echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_fastqc.sh"
			echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_fastqc.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N fastqc
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_fastqc.sh
	'>> $pathAnalysis"/submitQsub.sge"


	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run Fastqc for "$count" fastq,
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
