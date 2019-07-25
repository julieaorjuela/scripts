#!/bin/bash -a
# -*- coding: utf-8 -*-

## @package run_$softName.sh
# @author Julie Orjuela
# TODO: accepte fastq.gz seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.
# avant de lancer ce script verifier pathToTrimmomatic, selon la quantité des données il faut modifier la memoire java -Xmx1G

version=1.0
path=`pwd`
softName=trimmomatic-kallisto

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run $softName on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq.gzfiles
 Output:
	compressed directory with trimmomatic results
 Exemple Usage: ./run_$softName.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./run_$softName.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
	pathAnalysis=`readlink -m $fastq`"/jobArray-$softName/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"$softName"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	pathToTrimmomatic="/usr/local/Trimmomatic-0.33/"
	
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
	
	#create trimmomatic-kallisto repertory
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
		if [[ "$f" =~ ".fastq" ]] || [[ "$f" =~ ".fastq.gz"  ]] || [[ "$f" =~ ".fq"  ]] || [[ "$f" =~ ".fq.gz"  ]]; then
			name=$(basename ${f%%.fastq})
			name=$(basename ${f%%.fastq.gz})
			name=$(basename ${f%%.fq})
			name=$(basename ${f%%.fq.gz})
			shortName=$(echo $name | awk -F"." '{ print $1"."$2 }' )
			echo $shortName
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_$softName.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_$softName.sh"
			echo "module load system/java/jre-1.8.111" >> $SHPath"/"$count"_$softName.sh" 
			echo "module load bioinfo/Trimmomatic/0.33" >> $SHPath"/"$count"_$softName.sh"
			echo "module load bioinfo/kallisto/0.43.1" >> $SHPath"/"$count"_$softName.sh"
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_$softName.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_$softName.sh"
			echo "pathToScratch=\""$pathTMP"/trimmomatic_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_$softName.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_$softName.sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_$softName.sh"
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_$softName.sh"
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$count"_$softName.sh"
			echo "scp "$fastqPath"/"$shortName"* \$pathToScratch/" >> $SHPath"/"$count"_$softName.sh" # on transfer les deux fastq
			
			#Running trimmomatic	
			echo " " >> $SHPath"/"$count"_$softName.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_$softName.sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_$softName.sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_$softName.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_$softName.sh"
			
			echo "java -Xmx4G -jar $pathToTrimmomatic/trimmomatic-0.33.jar SE -phred33 -threads 4 -trimlog \$pathToScratch/results_"$shortName"/logfile_"$shortName"  \$pathToScratch/"$shortName".fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".Trimmed.fastq.gz SLIDINGWINDOW:4:20 LEADING:5 TRAILING:5 MINLEN:25" >> $SHPath"/"$count"_$softName.sh"
			
			#Printing trimmomatic command executed
			echo "cmd=\" java -Xmx4G -jar $pathToTrimmomatic/trimmomatic-0.33.jar SE -phred33 -threads 4 -trimlog \$pathToScratch/results_"$shortName"/logfile_"$shortName"  \$pathToScratch/"$shortName".fastq.gz \$pathToScratch/results_"$shortName"/"$shortName".PairedTrimmed.fastq.gz SLIDINGWINDOW:4:20 LEADING:5 TRAILING:5 MINLEN:25  \"" >> $SHPath"/"$count"_$softName.sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_$softName.sh"
			
			#running kallisto
			#kallisto quant -i index -o output --single -l 200 -s 20 file1.fastq.gz file2.fastq.gz file3.fastq.gz
			echo "kallisto quant -i /home/orjuela/TEST-trimmomatic-kallisto/all-cdna.index -l 200 -s 20 -t 4 -o $pathToScratch/results_$shortName/$shortName.kallisto --single \$pathToScratch/results_"$shortName"/"$shortName".Trimmed.fastq.gz" >> $SHPath"/"$count"_$softName.sh"
			
			#Printing kallisto command executed
			echo "cmd=\" kallisto quant -i /home/orjuela/TEST-trimmomatic-kallisto/all-cdna.index -l 200 -s 20 -t 4 -o \$pathToScratch/results_$shortName/$shortName.kallisto --single \$pathToScratch/results_"$shortName"/"$shortName".Trimmed.fastq.gz" >> $SHPath"/"$count"_$softName.sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_$softName.sh"
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_$softName.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_$softName.sh"
			echo "scp -rp \$pathToScratch/results_"$shortName" \$pathToDest/"  >> $SHPath"/"$count"_$softName.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_$softName.sh"
			
			# Suppression du repertoire tmp noeud
			echo " " >> $SHPath"/"$count"_$softName.sh"	
			echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_$softName.sh"
			echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_$softName.sh"
			echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_$softName.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N trimmomatic-kallisto
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_trimmomatic-kallisto.sh
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
