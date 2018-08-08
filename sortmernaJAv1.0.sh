#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_sortmerna.sh
# @author Sebastien Ravel. Adapted to sortmerna by Julie Orjuela
# TODO: accepte fastq.gz seulement avec nom de fichier sample_R1.fastq.gz et sample_R2.fastq.gz, et en mode PE.
# TODO : Pour le interleave appeler script "$sortmernaPath/scripts/merge-paired-reads.sh"  pour des donnees non gzippé ou ajouter une condition

version=1.0
path=`pwd`

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run sortmerna on fastq directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with fastq|fastq.gz|fq|fq.gz files
 Output:
	compressed directory with sortmerna results
 Exemple Usage: ./run_sortmerna.sh -f ./fastq -m julie.orjuela@ird.fr
 Usage: ./run_sortmerna.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
	printf "\033[36m #           Welcome to Run sortmerna directory ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fastq`"/jobArray-sortmerna/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastqPath=`readlink -m $fastq`
	fastResultsPath=$pathAnalysis"sortmerna"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	sortmernaPath="/usr/local/sortmerna-2.1/"
	mergePairedReadsScript="$sortmernaPath/scripts/merge-paired-reads.sh"
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fastq were found in directory: \n"$fastqPath
	printf "\033[32m \n Output Sortmerna will be write in directory: "$fastResultsPath"\n\n"
	
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
	
	#create sortmerna repertory
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
			echo " " > $SHPath"/"$count"_sortmerna.sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_sortmerna.sh" 
			echo "module load bioinfo/sortmerna/2.1" >> $SHPath"/"$count"_sortmerna.sh" 
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "pathToScratch=\""$pathTMP"/sortmerna_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_sortmerna.sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_sortmerna.sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_sortmerna.sh"
			
			# Copie du fichier fastq.gz vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "# Copie du fichier fastq.gz vers la partition /scratch du noeud"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "scp "$fastqPath"/"$shortName"* \$pathToScratch/" >> $SHPath"/"$count"_sortmerna.sh" # on transfer les deux fastq
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_sortmerna.sh"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_sortmerna.sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_sortmerna.sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_sortmerna.sh"
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "# Running tool"  >> $SHPath"/"$count"_sortmerna.sh"
			R1="\$pathToScratch/"$shortName"_R1.fastq.gz"
			R2="\$pathToScratch/"$shortName"_R2.fastq.gz"
			
			#Interweaving step FASTQ
			#echo "$sortmernaPath/scripts/merge-paired-reads.sh $R1 $R2 $shortName-interweaved.fq " >> $SHPath"/"$count"_sortmerna.sh"
												
			#Printing command executed
			#echo "cmd=\"$sortmernaPath/scripts/merge-paired-reads.sh $R1 $R2 $shortName-interleaved.fq \"" >> $SHPath"/"$count"_sortmerna.sh"
			#echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_sortmerna.sh"
			
			#Interleaving the files if FASTQ.GZ
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"=> Starting interleave ..\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Processing $R1 .. \""  >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "zcat $R1 | perl -pe 's/\n/\t/ if $. %4' - > TMP_"$shortName"_R1.fastq" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Processing $R2 ..\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "zcat $R2 | perl -pe 's/\n/\t/ if $. %4' - > TMP_"$shortName"_R2.fastq" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Interleaving $R1 and $R2 ..\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "paste -d '\n' TMP_"$shortName"_R1.fastq TMP_"$shortName"_R2.fastq | tr \"\\t\" \"\\n\" > "$shortName".interleaved.fastq" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Removing temp files  ..\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "rm TMP_"$shortName"_R1.fastq TMP_"$shortName"_R2.fastq " >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Interleaving was done.\"" >> $SHPath"/"$count"_sortmerna.sh"

			#Running sortmerna to eliminate ribosomal RNA from reads
			echo "echo \"=> Starting sortmerna ..\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "$sortmernaPath/sortmerna --fastx -a 8 --log --paired_out -e 0.1 --id 0.97 --coverage 0.97 --otu_map --ref $sortmernaPath/rRNA_databases/silva-bac-16s-id90.fasta,$sortmernaPath/index/silva-bac-16s-db:$sortmernaPath/rRNA_databases/silva-bac-23s-id98.fasta,$sortmernaPath/index/silva-bac-23s-db:$sortmernaPath/rRNA_databases/silva-arc-16s-id95.fasta,$sortmernaPath/index/silva-arc-16s-db:$sortmernaPath/rRNA_databases/silva-arc-23s-id98.fasta,$sortmernaPath/index/silva-arc-23s-db:$sortmernaPath/rRNA_databases/silva-euk-18s-id95.fasta,$sortmernaPath/index/silva-euk-18s-db:$sortmernaPath/rRNA_databases/silva-euk-28s-id98.fasta,$sortmernaPath/index/silva-euk-28s:$sortmernaPath/rRNA_databases/rfam-5s-database-id98.fasta,$sortmernaPath/index/rfam-5s-db:$sortmernaPath/rRNA_databases/rfam-5.8s-database-id98.fasta,$sortmernaPath/index/rfam-5.8s-db --reads \$pathToScratch/results_"$shortName"/"$shortName".interleaved.fastq  --other \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA --aligned \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.aligned -v " >> $SHPath"/"$count"_sortmerna.sh" 			
			
			echo "cmd=\" $sortmernaPath/sortmerna --fastx -a 8 --log --paired_out -e 0.1 --id 0.97 --coverage 0.97 --otu_map --ref $sortmernaPath/rRNA_databases/silva-bac-16s-id90.fasta,$sortmernaPath/index/silva-bac-16s-db:$sortmernaPath/rRNA_databases/silva-bac-23s-id98.fasta,$sortmernaPath/index/silva-bac-23s-db:$sortmernaPath/rRNA_databases/silva-arc-16s-id95.fasta,$sortmernaPath/index/silva-arc-16s-db:$sortmernaPath/rRNA_databases/silva-arc-23s-id98.fasta,$sortmernaPath/index/silva-arc-23s-db:$sortmernaPath/rRNA_databases/silva-euk-18s-id95.fasta,$sortmernaPath/index/silva-euk-18s-db:$sortmernaPath/rRNA_databases/silva-euk-28s-id98.fasta,$sortmernaPath/index/silva-euk-28s:$sortmernaPath/rRNA_databases/rfam-5s-database-id98.fasta,$sortmernaPath/index/rfam-5s-db:$sortmernaPath/rRNA_databases/rfam-5.8s-database-id98.fasta,$sortmernaPath/index/rfam-5.8s-db --reads \$pathToScratch/results_"$shortName"/"$shortName".interleaved.fastq  --other \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA --aligned \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.aligned -v  \"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Commande executee: \$cmd\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Sortmerna was finished.\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			
			# reorder to paired reads
			echo "echo \"=> Starting un-interleave ..\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Processing $R1 .. \""  >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "perl -pe 's/\n/\t/ if $. %4' \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA.fastq | awk 'NR%2 {print}' | tr \"\\t\" \"\\n\" >| "$shortName"_R1.sortmerna.mRNA.fastq"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Processing $R2 ..\"" >> $SHPath"/"$count"_sortmerna.sh" >> $SHPath"/"$count"_sortmerna.sh"
			echo "perl -pe 's/\n/\t/ if $. %4' \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA.fastq | awk '(NR+1)%2 {print}'| tr \"\\t\" \"\\n\" >| "$shortName"_R2.sortmerna.mRNA.fastq"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"   Un-interleaving was done.\"" >> $SHPath"/"$count"_sortmerna.sh"
			
			#counting reads number
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"=>   Counting reads ..\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA.fastq ; grep -c ^'+' \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.mRNA.fastq" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.aligned.fastq ; grep -c ^'+' \$pathToScratch/results_"$shortName"/"$shortName".sortmerna.aligned.fastq" >> $SHPath"/"$count"_sortmerna.sh"
			
			#gzipping reads mRNA
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"=>   Gzipping reads ..\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "gzip "$shortName"_R1.sortmerna.mRNA.fastq"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "gzip "$shortName"_R2.sortmerna.mRNA.fastq"  >> $SHPath"/"$count"_sortmerna.sh"
			
			#removing temporal files
			echo "rm \$pathToScratch/results_"$shortName"/*.fastq  \$pathToScratch/results_"$shortName"/*.txt "   >> $SHPath"/"$count"_sortmerna.sh"
			
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_sortmerna.sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "scp -rp \$pathToScratch/results_"$shortName"/ \$pathToDest/"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "scp -rp \$pathToScratch/results_"$shortName"/*log \$pathToDest/results_"$shortName""  >> $SHPath"/"$count"_sortmerna.sh"
			
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_sortmerna.sh"
			
			# Suppression du repertoire tmp noeud
			echo " " >> $SHPath"/"$count"_sortmerna.sh"	
			echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_sortmerna.sh"
			echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_sortmerna.sh"
			echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_sortmerna.sh"	
			let count+=1
		fi
	done
	
((count = count - 1))

	echo '#!/bin/bash
#$ -N sortmerna
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_sortmerna.sh
	'>> $pathAnalysis"/submitQsub.sge"


	chmod 755 $pathAnalysis"/submitQsub.sge"


	# Print final infos
	printf "\n\n You want run Sortmerna for "$count" fastq pairs,
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
