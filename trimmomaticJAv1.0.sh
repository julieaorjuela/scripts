#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_trimmomatic.sh
# @author Sebastien Ravel. Adapted to trimmomatic by Julie Orjuela
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
	printf "#       Run trimmomatic on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files
 Output:
	compressed directory with trimmomatic results
 Exemple Usage: ./run_trimmomatic.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./run_trimmomatic.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
	printf "\033[36m #           Welcome to Run trimmomatic directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-trimmomatic/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"trimmomatic"
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
	printf "\033[32m \n Output Trimmomatic will be write in directory: "$fastResultsPath"\n\n"
	
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
	
	#create trimmomatic repertory
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
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_trimmomatic.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "module load system/java/jre-1.8.111" >> $SHPath"/"$count"_trimmomatic.sh" 
			echo "module load bioinfo/Trimmomatic/0.33" >> $SHPath"/"$count"_trimmomatic.sh" 
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_trimmomatic.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "pathToScratch=\""$pathTMP"/trimmomatic_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_trimmomatic.sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_trimmomatic.sh"
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_trimmomatic.sh"
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "scp "$fastqPath"/"$shortName"* \$pathToScratch/" >> $SHPath"/"$count"_trimmomatic.sh" # on transfer les deux fastq
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_trimmomatic.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_trimmomatic.sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_trimmomatic.sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_trimmomatic.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_trimmomatic.sh"
			
			echo "java -Xmx4G -jar $pathToTrimmomatic/trimmomatic-0.33.jar PE -phred33 -threads 16 -trimlog \$pathToScratch/results_"$shortName"/logfile_"$shortName"  \$pathToScratch/"$shortName"_R1.fastq.gz \$pathToScratch/"$shortName"_R2.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedTrimmed_R1.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedUntrimmed_R1.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedTrimmed_R2.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedUntrimmed_R2.fastq.gz ILLUMINACLIP:"$pathToTrimmomaticAdapters":2:30:10 ILLUMINACLIP:"$pathToTrimmomaticHomeAdapters":2:30:10 SLIDINGWINDOW:5:20 LEADING:5 TRAILING:5 MINLEN:25 HEADCROP:10 " >> $SHPath"/"$count"_trimmomatic.sh"
			
			#Printing command executed
			echo "cmd=\" java -Xmx4G -jar $pathToTrimmomatic/trimmomatic-0.33.jar PE -phred33 -threads 16 -trimlog \$pathToScratch/results_"$shortName"/logfile_"$shortName"  \$pathToScratch/"$shortName"_R1.fastq.gz \$pathToScratch/"$shortName"_R2.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedTrimmed_R1.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedUntrimmed_R1.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedTrimmed_R2.fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedUntrimmed_R2.fastq.gz ILLUMINACLIP:"$pathToTrimmomaticAdapters":2:30:10 ILLUMINACLIP:"$pathToTrimmomaticHomeAdapters":2:30:10 SLIDINGWINDOW:5:20 LEADING:5 TRAILING:5 MINLEN:25 HEADCROP:10  \"" >> $SHPath"/"$count"_trimmomatic.sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_trimmomatic.sh"
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_trimmomatic.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "scp -rp \$pathToScratch/results_"$shortName" \$pathToDest/"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_trimmomatic.sh"
			
			# Suppression du repertoire tmp noeud
			echo " " >> $SHPath"/"$count"_trimmomatic.sh"	
			echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_trimmomatic.sh"
			echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_trimmomatic.sh"
			echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_trimmomatic.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N trimmomatic
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_trimmomatic.sh
	'>> $pathAnalysis"/submitQsub.sge"


	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run Trimmomatic for "$count" fastq pairs,
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
