#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_trinity.sh
# @author Sebastien Ravel. Adapted to tgicl by Julie Orjuela
# TODO: accepte fasta seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.


version=1.0
path=`pwd`

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run tgicl-par-sample on fasta directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fasta|fasta.gz|fa|fa.gz files
 Output:
	compressed directory with tgicl results
 Exemple Usage: ./tgicl-par-sample-JAv1.0.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./tgicl-par-sample-JAv1.0.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
	options:
		-f {path/to/fasta/} = path to Trinity.fasta transcrits
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
	printf "\033[36m #           Welcome to tgicl directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-tgicl/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"tgicl"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fastq files and Trinity.fasta transcrits were found in directory: \n"$fastqPath
	printf "\033[32m \n Output align-and-estimate-abundance will be write in directory: "$fastResultsPath"\n\n"
	
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
	
	#create tgicl repertory
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
		if [[ "$f" =~ ".fasta" ]] || [[ "$f" =~ ".fasta.gz"  ]] || [[ "$f" =~ ".fa"  ]] || [[ "$f" =~ "R1.fa.gz"  ]]; then
			name=$(basename ${f%%.fasta})
			name=$(basename ${f%%.fasta.gz})
			name=$(basename ${f%%.fa})
			name=$(basename ${f%%.fa.gz})
			shortName=$(echo $name | cut -d "." -f 1)
			shortName=$(echo $name | cut -d "_" -f 1)
			echo $shortName
			fasta="\$pathToScratch/"$shortName"_Trinity.fasta"
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "module load toggleDev" >> $SHPath"/"$count"_tgicl-par-sample.sh"
						
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "pathToScratch=\""$pathTMP"/tgicl-par-sample_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "# Copie du fichier Trinity.fasta vers la partition /scratch du noeud"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "scp "$fastqPath"/"$shortName"*.fasta \$pathToScratch/" >> $SHPath"/"$count"_tgicl-par-sample.sh" # on transfer le fasta
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
				
			echo ""tgicl "$fasta" -c 6 -p 90 -l 20 "" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			       
			#Printing command executed
			echo "cmd=\" tgicl "$fasta" -c 6 -p 90 -l 20 \"" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "scp -rp \$pathToScratch/* \$pathToDest/"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			
			# Suppression du repertoire tmp noeud
			#echo " " >> $SHPath"/"$count"_tgicl-par-sample.sh"	
			#echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_tgicl-par-sample.sh"
			#echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_tgicl-par-sample.sh"
			#echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_tgicl-par-sample.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N tgicl
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q highmem.q
#$ -t 1-'$count'
#$ -tc 400
#$ -pe ompi 6
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_tgicl-par-sample.sh
	'>> $pathAnalysis"/submitQsub.sge"
	chmod 755 $pathAnalysis"/submitQsub.sge"

	# Print final infos
	printf "\n\n You want run trinity-tgicl-par-samplefor "$count" fastq pairs,
 The script are created .sh for all fastq into "$pathAnalysis"sh,\n
 For run all sub-script in qsub, a submitQsub.sge was created, It lunch programm make:\n"

	printf "\033[35m \tqsub "$pathAnalysis"submitQsub.sge "$cmdMail"\n\n"
	# Print end
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #                        End of execution                          #\n";
	printf "\033[36m ####################################################################\n";

# if arguments empty
else
	echo "\033[31m you select fasta path = "$fastq
	echo "\033[31m you select mail = "$mail
	printf "\033[31m \n\n You must inform all the required options !!!!!!!!!!!! \n\n"
	help
fi
