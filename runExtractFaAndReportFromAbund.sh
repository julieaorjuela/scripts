#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_Trinotate.sh
# @author jobarray structure by Sebastien Ravel. Adapted to run ExtractFaAndReportFromAbundance by Julie Orjuela

version=1.0
path=`pwd`
softName="extractFaAndReportFromAb"

##################################################
## Fonctions
##################################################
# module help
function help
{
	printf "\033[36m####################################################################\n";
	printf "#       Run "$softName" on fasta directory ( Version $version )       #\n";
	printf "####################################################################\n";
	printf "
 Input:
	directory with tsv files
 Output:
	compressed directory with extractionFaAndreportFromAb results
 Exemple Usage: ./"$softName"-JAv1.0.sh -a ./abondance.tsv -r ./report.xls -f ./ref.fasta -m julie.orjuela@ird.fr
 Usage: ./"$softName"-JAv1.0.sh -a {path/to/abondance.tsv} -r {path/to/report.xls} -f {path/to/reference.fasta}-m obiwankenobi@jedi.force
	options:
		-a {path/to/abondance/} = path to abondance.tsv
		-r {path/to/report/} = path to .xls
		-f {path/to/refFasta/} = path to .fasta
		-m {email} = email to add to qsub job end (not mandatory)
		-h = see help\n\n"
	exit 0
}


##################################################
## Parse command line options
##################################################.
while getopts a:r:f:m:h: OPT;
	do case $OPT in
		a)	fasta=$OPTARG;;
		r)  report=$OPTARG;;
		f)  refFasta=$OPTARG;;
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

#report="HNglobal-Trinity_annotation_report.xls"
#refFasta="HNglobal_Trinity.fasta" 

 

if [ $fasta != "" ] ; then
	#version
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #           Welcome to $softName ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fasta`"/jobArray-extractFaAndReportFromAb/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastaPath=`readlink -m $fasta`
	fastResultsPath=$pathAnalysis"extractFaAndReportFromAb/"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	
	printf "\033[32m \n report: "$report
	printf "\033[32m \n refFasta: "$refFasta
	
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Abondance files were found in directory: \n"$fastaPath
	printf "\033[32m \n Output extracted transcrits by tissu will be write in directory: "$fastResultsPath"\n\n"
	
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
	
	#create Trinotate repertory
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
	for f in $fastaPath/*
	do
		if [[ "$f" =~ ".tsv" ]] ; then
			name=$(basename ${f%%.tsv})
			shortName=$(echo $name | cut -d "." -f 1)
			shortName=$(echo $shortName | cut -d "_" -f 1)
			echo $shortName
			fasta="\$pathToScratch/"$shortName".tsv" # variable nomé fasta mais c'est le fichier d'abondance
			reportOK="\$pathToScratch/"$report
			refFastaOK="\$pathToScratch/"$refFasta
			out="\$pathToScratch/"$shortName".out"
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_"$softName".sh"
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_"$softName".sh"
			echo "pathToScratch=\""$pathTMP"/extractFaAndReportFromAb_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_"$softName".sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_"$softName".sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_"$softName".sh"
			
			# Copie du fichier fasta vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Copie du fichier tsv xls and fasta vers la partition /scratch du noeud"  >> $SHPath"/"$count"_"$softName".sh"
			echo "scp "$fastaPath"/"$shortName"*.tsv \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh" # on transfer le tsv
			echo "scp "$fastaPath"/*.xls \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh" # on transfer le xls
			echo "scp "$fastaPath"/*.fasta \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh" # on transfer le fasta
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_"$softName".sh"
			echo "mkdir \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh"
			echo "cd \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh"
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Running tool"  >> $SHPath"/"$count"_"$softName".sh"
			
			# running 
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Running extractFaAndReportFromAb.py" >> $SHPath"/"$count"_"$softName".sh"
			echo "" python /home/orjuela/scripts/extractFaAndTrinotateRepFromAbundance_v2.py  -f "$refFastaOK" -r "$reportOK" -l "$fasta" -o "$out" "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" python /home/orjuela/scripts/extractFaAndTrinotateRepFromAbundance_v2.py -f "$refFastaOK" -r "$reportOK" -l "$fasta" -o "$out"  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
							
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_"$softName".sh"
			echo "scp -rp \$pathToScratch/*fa \$pathToDest/"  >> $SHPath"/"$count"_"$softName".sh"
			echo "scp -rp \$pathToScratch/*report \$pathToDest/"  >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"Transfert des donnees node -> master\"" >> $SHPath"/"$count"_"$softName".sh"
			
			## Suppression du repertoire tmp noeud
			#echo " " >> $SHPath"/"$count"_"$softName".sh"	
			#echo "# Suppression du repertoire tmp noeud"  >> $SHPath"/"$count"_"$softName".sh"
			#echo "rm -rf \$pathToScratch" >> $SHPath"/"$count"_"$softName".sh"
			#echo "echo \"Suppression des donnees sur le noeud\"" >> $SHPath"/"$count"_"$softName".sh"	
			let count+=1
		fi
	done
((count = count - 1))

	echo '#!/bin/bash
#$ -N extractFaAndReportFromAb
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 20


#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_extractFaAndReportFromAb.sh
	'>> $pathAnalysis"/submitQsub.sge"
	chmod 755 $pathAnalysis"/submitQsub.sge"

	# Print final infos
	printf "\n\n You want run extractFaAndReportFromAb for "$count" tsv abundance files,
 The script are created .sh for all fasta into "$pathAnalysis"sh,\n
 For run all sub-script in qsub, a submitQsub.sge was created, It lunch programm make:\n"

	printf "\033[35m \tqsub "$pathAnalysis"submitQsub.sge "$cmdMail"\n\n"
	# Print end
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #                        End of execution                          #\n";
	printf "\033[36m ####################################################################\n";

# if arguments empty
else
	echo "\033[31m you select csv path = "$fasta
	echo "\033[31m you select mail = "$mail
	printf "\033[31m \n\n You must inform all the required options !!!!!!!!!!!! \n\n"
	help
fi
