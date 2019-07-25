#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_trinity.sh
# @author Sebastien Ravel. Adapted to trinity by Julie Orjuela
# TODO: accepte fastq.gz seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.

version=1.0
path=`pwd`

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run align-and-estimate-abundance-global on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files and a Trinity.fasta assambly
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
	printf "\033[36m #           Welcome to Run align-and-estimate-abundance-global directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-align-and-estimate-abundance-global/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"align-and-estimate-abundance-global"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fastq files and Trinity.fasta transcrits were found in directory: \n"$fastqPath
	printf "\033[32m \n Output align-and-estimate-abundance-global will be write in directory: "$fastResultsPath"\n\n"
	
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
	#shortName='AGglobal'
	shortName='HNglobal'
	fasta="\$pathToScratch/"$shortName"_Trinity.fasta" 
	
	#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
	#modules
	echo " " > $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "# Charging modules"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "module load toggleDev" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "module load bioinfo/trinityrnaseq/2.5.1" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh" 
	echo "module load bioinfo/express/1.5.1" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "module load bioinfo/kallisto/0.43.1" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	#defining scratch and destination			
	echo " " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "# Defining scratch and destination repertories\n"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "pathToScratch=\""$pathTMP"/trinity_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "pathToDest=\""$pathDest"\"" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	# Creation du repertoire temporaire sur la partition /scratch du noeud
	echo "mkdir -p \$pathToScratch" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	# Copie du fichier fastq.gz vers la partition /scratch du noeud
	echo " " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "scp "$fastqPath"/*.fastq.gz \$pathToScratch/" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh" # on transfer les  fastq
	echo "scp "$fastqPath"/*.fasta \$pathToScratch/" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh" # on transfer le fasta de trinity 
	echo "scp "$SHPath"/samples.txt \$pathToScratch/" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh" # on transfer le fichier samples.txt path a
	
	echo " " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "cd \$pathToScratch/ " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "cd \$pathToScratch/" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	#Running tool
	echo "# Running tool"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo ""perl /usr/local/trinityrnaseq-2.5.1/util/align_and_estimate_abundance.pl --transcripts "$fasta" --samples_file \$pathToScratch"/"samples.txt --seqType fq --est_method kallisto --trinity_mode --prep_reference --output_dir "$shortName"_kallisto_outdir"" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	#Printing command executed
	echo "cmd=\"  perl /usr/local/trinityrnaseq-2.5.1/util/align_and_estimate_abundance.pl --transcripts "$fasta" --seqType fq --samples_file \$pathToScratch"/"samples.txt --est_method kallisto --trinity_mode --prep_reference --output_dir "$shortName"_kallisto_outdir  \"" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
		
	# Transfert des données du noeud vers master
	echo " " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "# Transfert des données du noeud vers master"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "rm \$pathToScratch/*.fastq.gz \$pathToScratch/*.fasta"  >> $SHPath
	echo "scp -rp \$pathToScratch/ \$pathToDest/"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
	# Suppression du repertoire tmp noeud
	echo " " >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"	
	echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "rm -rf \$pathToScratch" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/trinity-align-and-estimate-abundance-global.sh"
	
#((count = count - 1))

echo '#!/bin/bash
#$ -N GalignAndAbondance
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/trinity-align-and-estimate-abundance-global.sh
	'>> $pathAnalysis"/submitQsub.sge"

	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run trinity-align-and-estimate-abundance-global for "$count" fastq pairs,
 The script are created .sh for all fastq into "$pathAnalysis"sh,\n
 For run all sub-script in qsub, a submitQsub.sge was created, It lunch programm make:\n"

	printf "\033[35m \tqsub "$pathAnalysis"submitQsub.sge "$cmdMail"\n\n"
	# Print end
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #                        End of execution                          #\n";
	printf "\033[36m ####################################################################\n";

# if arguments empty
else
	echo "\033[31m you select fastq and fasta path = "$fastq
	echo "\033[31m you select mail = "$mail
	printf "\033[31m \n\n You must inform all the required options !!!!!!!!!!!! \n\n"
	help
fi
