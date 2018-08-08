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
	pathAnalysis=`readlink -m $fastq`"/jobArray-trinity-global/"
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
	count=1 # en global on lance un seul job
	for f in $fastqPath/*
	do
		if [[ "$f" =~ "R1.fastq" ]] || [[ "$f" =~ "R1.fastq.gz"  ]] || [[ "$f" =~ "R1.fq"  ]] || [[ "$f" =~ "R1.fq.gz"  ]]; then
			name=$(basename ${f%%.R1.fastq})
			name=$(basename ${f%%.R1.fastq.gz})
			name=$(basename ${f%%.R1.fq})
			name=$(basename ${f%%.R1.fq.gz})
			shortName=$(echo $name | cut -d "." -f 1)
			shortName=$(echo $name | cut -d "_" -f 1)
			R1=$shortName"_R1.fastq.gz"
			R2=$shortName"_R2.fastq.gz"
			echo $shortName;
			cmd="$shortName"\\t"$shortName"_rep1\\t"$R1"\\t"$R2"
			#creer le fichier samples.txt a partir des names of files (voir pour les repliques)
			echo -e "$cmd" >> $SHPath"/samples.txt"
			#let count+=1
		fi
	done
	
	#changing shortname
	shortName='global'
	
	#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
	#modules
	echo " " > $SHPath"/global-trinity.sh"
	echo "# Charging modules"  >> $SHPath"/global-trinity.sh"
	echo "module load toggleDev" >> $SHPath"/global-trinity.sh"
	echo "module load bioinfo/trinityrnaseq/2.5.1" >> $SHPath"/global-trinity.sh" 
	echo "module load bioinfo/Trimmomatic/0.33" >> $SHPath"/global-trinity.sh" 
	
	#defining scratch and destination			
	echo " " >> $SHPath"/global-trinity.sh"
	echo "# Defining scratch and destination repertories\n"  >> $SHPath"/global-trinity.sh"
	echo "pathToScratch=\""$pathTMP"/trinity_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/global-trinity.sh"
	echo "pathToDest=\""$pathDest"\"" >> $SHPath"/global-trinity.sh"
	
	# Creation du repertoire temporaire sur la partition /scratch du noeud
	echo "mkdir -p \$pathToScratch" >> $SHPath"/global-trinity.sh"
	
	# Copie du fichier fastq.gz vers la partition /scratch du noeud
	echo " " >> $SHPath"/global-trinity.sh"
	echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/global-trinity.sh"
	echo "scp "$fastqPath"/*.fastq.gz \$pathToScratch/" >> $SHPath"/global-trinity.sh" # on transfer les deux fastq 
	echo "scp "$SHPath"/samples.txt \$pathToScratch/" >> $SHPath"/global-trinity.sh" # on transfer le fichier samples.txt path a modifier	
		
	echo " " >> $SHPath"/global-trinity.sh"
	echo "cd \$pathToScratch/ " >> $SHPath"/global-trinity.sh"
	echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/global-trinity.sh"
	echo "cd \$pathToScratch/" >> $SHPath"/global-trinity.sh"
	
	#Running tool
	echo "# Running tool"  >> $SHPath"/global-trinity.sh"
	echo "Trinity --seqType fq --max_memory 80G --CPU 8 --normalize_by_read_set --samples_file \$pathToScratch"/"samples.txt --output \$pathToScratch/results_$shortName/trinity_OUT " >> $SHPath"/global-trinity.sh"
	#--full_cleanup --normalize_by_read_set
	
	#Printing command executed
	echo "cmd=\"  Trinity --seqType fq --max_memory 80G --CPU 8 --normalize_by_read_set --samples_file \$pathToScratch"/"samples.txt --output \$pathToScratch/results_$shortName/trinity_OUT  \"" >> $SHPath"/global-trinity.sh"
		
	#Running tool
	#echo "# Running tool"  >> $SHPath"/global-trinity.sh"
	#echo "Trinity --seqType fq --max_memory 80G --CPU 8 --trimmomatic --quality_trimming_params 'ILLUMINACLIP:/usr/local/Trimmomatic-0.33/adapters/TruSeq2-PE.fa:2:30:10 ILLUMINACLIP:/data3/projects/arapaima/adapt-125pbLib.txt:2:30:10 SLIDINGWINDOW:5:20 LEADING:5 TRAILING:5 MINLEN:25 HEADCROP:10' --normalize_by_read_set --samples_file \$pathToScratch"/"samples.txt --output \$pathToScratch/results_$shortName/trinity_OUT " >> $SHPath"/global-trinity.sh"
	##--full_cleanup --normalize_by_read_set
	#
	##Printing command executed
	#echo "cmd=\"  Trinity --seqType fq --max_memory 80G --CPU 8 --trimmomatic --quality_trimming_params 'ILLUMINACLIP:/usr/local/Trimmomatic-0.33/adapters/TruSeq2-PE.fa:2:30:10 ILLUMINACLIP:/data3/projects/arapaima/adapt-125pbLib.txt:2:30:10 SLIDINGWINDOW:5:20 LEADING:5 TRAILING:5 MINLEN:25 HEADCROP:10' --normalize_by_read_set --samples_file \$pathToScratch"/"samples.txt --output \$pathToScratch/results_$shortName/trinity_OUT  \"" >> $SHPath"/global-trinity.sh"
	#echo "echo \"commande executee: \$cmd\"" >> $SHPath"/global-trinity.sh"
	
	# Transfert des données du noeud vers master
	echo " " >> $SHPath"/global-trinity.sh"
	echo "# Transfert des données du noeud vers master"  >> $SHPath"/global-trinity.sh"
	echo "scp -rp \$pathToScratch/results_"$shortName" \$pathToDest/"  >> $SHPath"/global-trinity.sh"
	echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/global-trinity.sh"
	
	# Suppression du repertoire tmp noeud
	echo " " >> $SHPath"/global-trinity.sh"	
	#echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/global-trinity.sh"
	#echo "rm -rf \$pathToScratch" >> $SHPath"/global-trinity.sh"
	#echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/global-trinity.sh"
	
#((count = count - 1))

echo '#!/bin/bash
#$ -N Gtrinity
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q highmem.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
#$ -l mem_free=100G
/bin/bash '$pathAnalysis'/sh/global-trinity.sh
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
