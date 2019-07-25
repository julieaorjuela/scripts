#!/bin/bash -a
# -*- coding: utf-8 -*-
## @package run_Trinotate.sh
# @author Sebastien Ravel. Adapted to Trinonate by Julie Orjuela

version=1.0
path=`pwd`
softName="Trinotate"

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
	directory with fasta|fasta.gz|fa|fa.gz files
 Output:
	compressed directory with Trinotate results
 Exemple Usage: ./"$softName"-JAv1.0.sh -f ./fasta -m julie.orjuela@ird.fr
 Usage: ./"$softName"-JAv1.0.sh -f {path/to/fasta} -m obiwankenobi@jedi.force
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
		f)	fasta=$OPTARG;;
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

if [ $fasta != "" ] ; then
	#version
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #           Welcome to Trinonate ( Version $version )            #\n";
	printf "\033[36m ####################################################################\n";

	##################################################
	## Global variables
    ##################################################
	
	#create pathAnalysis repertory
	pathAnalysis=`readlink -m $fasta`"/jobArray-Trinotate/"
	if [ -d $pathAnalysis ]; then
		rm -r $pathAnalysis
		mkdir $pathAnalysis
	else
		mkdir $pathAnalysis
    fi

	#declaring repertories to output scripts of job-array
	fastaPath=`readlink -m $fasta`
	fastResultsPath=$pathAnalysis"Trinotate"
	SHPath=$pathAnalysis"sh"
	trashPath=$pathAnalysis"trash"
	pathTMP="/scratch/orjuela"
	pathDest=$fastResultsPath
	
	#giving information about job-array to user
	printf "\033[32m \n Working in directory: "$pathAnalysis
	printf "\033[32m \n Fasta files and Trinity.fasta transcrits were found in directory: \n"$fastaPath
	printf "\033[32m \n Output longest isoforms will be write in directory: "$fastResultsPath"\n\n"
	
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
		if [[ "$f" =~ ".fasta" ]] || [[ "$f" =~ ".fasta.gz"  ]] || [[ "$f" =~ ".fa"  ]] || [[ "$f" =~ "R1.fa.gz"  ]]; then
			name=$(basename ${f%%.fasta})
			name=$(basename ${f%%.fasta.gz})
			name=$(basename ${f%%.fa})
			name=$(basename ${f%%.fa.gz})
			shortName=$(echo $name | cut -d "." -f 1)
			shortName=$(echo $shortName | cut -d "_" -f 1)
			echo $shortName
			fasta="\$pathToScratch/"$shortName".fasta"
			
			#banques
			BANK="/data/projects/banks/" ; #uniprot_sprot.* sont dans $BANK/Uniprot
			DB="/usr/local/Trinotate-3.0.1" #Pfam-A.hmm* is in DB #uniref90 is in DB
			
			#writting in sh file (managing transfer) #creation de fichier .sh avec les commandes de transfer vers scratch
			#modules
			echo " " > $SHPath"/"$count"_"$softName".sh"
			echo "# Charging modules"  >> $SHPath"/"$count"_"$softName".sh"
			echo "module purge" >> $SHPath"/"$count"_"$softName".sh"
			echo "module load toggleDev" >> $SHPath"/"$count"_"$softName".sh"
			echo "module load bioinfo/Trinotate/3.0.1" >> $SHPath"/"$count"_"$softName".sh"
			echo "module load bioinfo/TransDecoder/3.0.0" >> $SHPath"/"$count"_"$softName".sh"
			echo "module load bioinfo/hmmer/3.1b2" >> $SHPath"/"$count"_"$softName".sh"
			echo "module load bioinfo/diamond/0.7.11" >> $SHPath"/"$count"_"$softName".sh" #demander la version 0.8 dans les module load
			echo "module load system/perl/5.24.0" >> $SHPath"/"$count"_"$softName".sh"
			#echo "module unload system/python/2.7.10" >> $SHPath"/"$count"_"$softName".sh"
			#echo "module load system/python/3.6.5" >> $SHPath"/"$count"_"$softName".sh"
			
			#defining scratch and destination			
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Defining scratch and destination repertories\n"  >> $SHPath"/"$count"_"$softName".sh"
			echo "pathToScratch=\""$pathTMP"/Trinotate_\$JOB_ID.\$SGE_TASK_ID/\""  >> $SHPath"/"$count"_"$softName".sh"
			echo "pathToDest=\""$pathDest"\"" >> $SHPath"/"$count"_"$softName".sh"
			
			# Creation du repertoire temporaire sur la partition /scratch du noeud
			echo "mkdir -p \$pathToScratch" >> $SHPath"/"$count"_"$softName".sh"
			echo "mkdir -p \$pathToScratch/DB" >> $SHPath"/"$count"_"$softName".sh"
			
			# Copie du fichier fasta vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Copie du fichier Trinity.fasta vers la partition /scratch du noeud"  >> $SHPath"/"$count"_"$softName".sh"
			echo "scp "$fastaPath"/"$shortName"*.fasta \$pathToScratch/" >> $SHPath"/"$count"_"$softName".sh" # on transfer le fasta
			
			# Copie des bases des données vers la partition /scratch du noeud
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Copie des bases uniprot_sprot*, Pfam-A.hmm*, et uniref90.fasta.dmnd vers la partition /scratch du noeud"  >> $SHPath"/"$count"_"$softName".sh"
			echo ""scp $DB/uniprot_spro* \$pathToScratch/DB/"" >> $SHPath"/"$count"_"$softName".sh" # on transfer uniprot_sprot
			echo ""scp $BANK/uniref90.fasta.dmnd \$pathToScratch/DB/"" >> $SHPath"/"$count"_"$softName".sh" # on transfer PfamA
			echo ""scp $DB/Pfam-A.hmm* \$pathToScratch/DB/"" >> $SHPath"/"$count"_"$softName".sh" # on transfer PfamA
			DBS="\$pathToScratch/DB/"
			
			#Running tool	
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "cd \$pathToScratch/ " >> $SHPath"/"$count"_"$softName".sh"
			echo "mkdir \$pathToScratch/results_$shortName" >> $SHPath"/"$count"_"$softName".sh"
			echo "cd \$pathToScratch/results_$shortName/" >> $SHPath"/"$count"_"$softName".sh"
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Running tool"  >> $SHPath"/"$count"_"$softName".sh"
			
			# OK Calculing trinity_component_distribution
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Calculing trinity_component_distribution" >> $SHPath"/"$count"_"$softName".sh"
			echo ""perl /usr/local/trinityrnaseq-2.5.1/util/misc/trinity_component_distribution.pl "$fasta" "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" perl /usr/local/trinityrnaseq-2.5.1/util/misc/trinity_component_distribution.pl "$fasta" \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#Annotation
			# OK 1 getting gene to trans map
			geneTransMap="\$pathToScratch/results_"$shortName"/"$shortName".fasta_gene_trans_map"
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 1 getting gene to trans map" >> $SHPath"/"$count"_"$softName".sh"
			echo ""perl /usr/local/trinityrnaseq-2.5.1/util/support_scripts/get_Trinity_gene_to_trans_map.pl "$fasta" \> "$geneTransMap" "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" perl /usr/local/trinityrnaseq-2.5.1/util/support_scripts/get_Trinity_gene_to_trans_map.pl "$fasta" \> "$geneTransMap" \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			# 2 generation du fichier peptide
			#OK 2.1 génération des longestOrf #output base* longestgff,pep,cds
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 2 generation of peptide file" >> $SHPath"/"$count"_"$softName".sh"
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 2.1 generation of longestOrf" >> $SHPath"/"$count"_"$softName".sh"
			echo ""TransDecoder.LongOrfs -t $fasta --gene_trans_map $geneTransMap -m 50 "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" TransDecoder.LongOrfs -t $fasta --gene_trans_map $geneTransMap -m 50  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#2.2 recherche d’identité parmis les longorfs
			transDecoderRepertory="\$pathToScratch/results_"$shortName"/"$shortName".fasta.transdecoder_dir"
			#OK hmmscan
			# ATTENTION : la base pfam il faut la telecharger, la deziper et la compresser avec hmmpress au preleable avec /usr/local/hmmer-3.1b1/binaries/hmmpress Pfam-A.hmm
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 2.2a recherche d’identité parmis les longorfs hmmscan" >> $SHPath"/"$count"_"$softName".sh"
			echo ""hmmscan --cpu 10 --domtblout pfam_longorfs.domtblout $DBS/Pfam-A.hmm $transDecoderRepertory/longest_orfs.pep "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" hmmscan --cpu 10 --domtblout pfam_longorfs.domtblout $DBS/Pfam-A.hmm $transDecoderRepertory/longest_orfs.pep  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			#OK diamond
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 2.2b recherche d’identité parmis les longorfs diamond" >> $SHPath"/"$count"_"$softName".sh"
			# pbm de version ?  option does not exist in v0.7 
			#il faut prealablement indexer la base avec diamond ## /usr/local/diamond-0.8.29/diamond makedb --db uniprot_sprot --in uniprot_sprot.pep
			echo "" /usr/local/diamond-0.8.29/diamond blastp --query $transDecoderRepertory/longest_orfs.pep  --db $DBS/uniprot_sprot --out diamP_uniprot_longorfs.outfmt6 --outfmt 6 --max-target-seqs 1  "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" /usr/local/diamond-0.8.29/diamond blastp --query $transDecoderRepertory/longest_orfs.pep --threads 10 --db $DBS/uniprot_sprot.pep --out diamP_uniprot_longorfs.outfmt6 --outfmt 6 --max-target-seqs 1  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			##OK 2.3 Prediction peptides
			resultsDir=\$pathToScratch/results_$shortName
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# #2.3 Prediction peptides" >> $SHPath"/"$count"_"$softName".sh"
			echo "" TransDecoder.Predict --cpu 10 -t $fasta --retain_pfam_hits $resultsDir/pfam_longorfs.domtblout --retain_blastp_hits $resultsDir/diamP_uniprot_longorfs.outfmt6 "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" TransDecoder.Predict --cpu 10 -t $fasta --retain_pfam_hits pfam_longorfs.domtblout --retain_blastp_hits diamP_uniprot_longorfs.outfmt6  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
					
			## 3 recherche de similarité en utilisant Diamond
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 3 Recherche de similarité en utilisant Diamond" >> $SHPath"/"$count"_"$softName".sh"
				
			#OK blastp diamP_uniprot
			## en root index la base uniref90 avec diamond /usr/local/diamond-0.8.29/diamond makedb --db uniref90.fasta --in uniref90.fasta
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# blastp diamP_uniprott " >> $SHPath"/"$count"_"$softName".sh"
			echo "" /usr/local/diamond-0.8.29/diamond blastp --query $resultsDir/$shortName.fasta.transdecoder.pep --threads 10 --db $DBS/uniprot_sprot --out $resultsDir/diamP_uniprot.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive  "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" /usr/local/diamond-0.8.29/diamond blastp --query $resultsDir/$shortName.fasta.transdecoder.pep --threads 10 --db $DBS/uniprot_sprot --out $resultsDir/diamP_uniprot.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#OK blastp diamP_uniref90
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# blastp diamP_uniref90 " >> $SHPath"/"$count"_"$softName".sh"
			echo "" /usr/local/diamond-0.8.29/diamond blastp --query $resultsDir/$shortName.fasta.transdecoder.pep --threads 10  --db $DBS/uniref90.fasta --out $resultsDir/diamP_uniref90.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" /usr/local/diamond-0.8.29/diamond blastp --query $resultsDir/$shortName.fasta.transdecoder.pep --threads 10 --db $DBS/uniref90.fasta --out $resultsDir/diamP_uniref90.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#OK blastx diamX_uniprot
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# blastx diamX_uniprot " >> $SHPath"/"$count"_"$softName".sh"
			echo "" /usr/local/diamond-0.8.29/diamond blastx --query $fasta --threads 10 --db $DBS/uniprot_sprot --out diamX_uniprot.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive  "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\"  /usr/local/diamond-0.8.29/diamond blastx --query $fasta --threads 10 --db $DBS/uniprot_sprot --out diamX_uniprot.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#OK blastx diamX_uniref90
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# blastx diamX_uniref90 " >> $SHPath"/"$count"_"$softName".sh"
			echo "" /usr/local/diamond-0.8.29/diamond blastx --query $fasta --threads 10 --db $DBS/uniref90.fasta --out  diamX_uniref90.outfmt6 --outfmt 6 --max-target-seqs 1 --more-sensitive "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" /usr/local/diamond-0.8.29/diamond blastx --query $fasta --threads 10 --db $DBS/uniref90.fasta --out  diamX_uniref90.outfmt6 --outfmt 6 --max-target-seqs 1  --more-sensitive \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#3 OK recherche de dommaines
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 3 recherche de dommaines " >> $SHPath"/"$count"_"$softName".sh"
			echo "" hmmscan --cpu 10 --domtblout $resultsDir/$shortName"_PFAM.out" $DBS/Pfam-A.hmm $resultsDir/$shortName.fasta.transdecoder.pep \> $resultsDir/pfam.log "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" hmmscan --cpu 10 --domtblout $resultsDir/$shortName"_PFAM.out" $DBS/Pfam-A.hmm $resultsDir/$shortName.fasta.transdecoder.pep  \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			#4 OK recheche de peptides signaux
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 4 recheche de peptides signaux " >> $SHPath"/"$count"_"$softName".sh"
			#      perl /usr/local/signalp-4.1/signalp -f short -n longestAGE.signalp.out longestAGE-Trinity.fasta.transdecoder.pep
			echo ""perl /usr/local/signalp-4.1/signalp -f short -n $resultsDir/$shortName"_signalp.out "$resultsDir/$shortName.fasta.transdecoder.pep "" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\"perl /usr/local/signalp-4.1/signalp -f short -n $resultsDir/$shortName"_signalp.out "$resultsDir/$shortName.fasta.transdecoder.pep   \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			##5 PBM SOFTS recherche de domaines transmembranaires
			#echo " " >> $SHPath"/"$count"_"$softName".sh"
			#echo "# 5 recherche de domaines transmembranaires " >> $SHPath"/"$count"_"$softName".sh"
			#echo ""tmhmm --short \< $resultsDir/$shortName.fasta.transdecoder.pep \> $resultsDir/$shortName.tmhmm.out "" >> $SHPath"/"$count"_"$softName".sh"
			#echo "cmd=\"  tmhmm --short < $resultsDir/$shortName.fasta.transdecoder.pep > $resultsDir/$shortName.tmhmm.out  \"" >> $SHPath"/"$count"_"$softName".sh"
			#echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
			
			##6 OK recherche de rRNA
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# 6 recherche de rRNA " >> $SHPath"/"$count"_"$softName".sh"
			echo "" /usr/local/Trinotate-3.0.1/util/rnammer_support/RnammerTranscriptome.pl --transcriptome $fasta —org_type euk --path_to_rnammer /usr/local/rnammer-1.2/rnammer"" >> $SHPath"/"$count"_"$softName".sh"
			echo "cmd=\" /usr/local/Trinotate-3.0.1/util/rnammer_support/RnammerTranscriptome.pl --transcriptome $fasta —org_type euk --path_to_rnammer /usr/local/rnammer-1.2/rnammer   \"" >> $SHPath"/"$count"_"$softName".sh"
			echo "echo \"commande executee: \$cmd\"" >> $SHPath"/"$count"_"$softName".sh"
				
			# Transfert des données du noeud vers master
			echo " " >> $SHPath"/"$count"_"$softName".sh"
			echo "# Transfert des données du noeud vers master"  >> $SHPath"/"$count"_"$softName".sh"
			echo "scp -rp \$pathToScratch/results* \$pathToDest/"  >> $SHPath"/"$count"_"$softName".sh"
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
#$ -N Trinotate
#$ -cwd
#$ -V
#$ -e '$trashPath'
#$ -o '$trashPath'
#$ -q bioinfo.q
#$ -t 1-'$count'
#$ -tc 400
#$ -pe ompi 10

#$ -S /bin/bash
/bin/bash '$pathAnalysis'/sh/${SGE_TASK_ID}_Trinotate.sh
	'>> $pathAnalysis"/submitQsub.sge"
	chmod 755 $pathAnalysis"/submitQsub.sge"

	# Print final infos
	printf "\n\n You want run Trinotate for "$count" fasta pairs,
 The script are created .sh for all fasta into "$pathAnalysis"sh,\n
 For run all sub-script in qsub, a submitQsub.sge was created, It lunch programm make:\n"

	printf "\033[35m \tqsub "$pathAnalysis"submitQsub.sge "$cmdMail"\n\n"
	# Print end
	printf "\033[36m ####################################################################\n";
	printf "\033[36m #                        End of execution                          #\n";
	printf "\033[36m ####################################################################\n";

# if arguments empty
else
	echo "\033[31m you select fasta path = "$fasta
	echo "\033[31m you select mail = "$mail
	printf "\033[31m \n\n You must inform all the required options !!!!!!!!!!!! \n\n"
	help
fi
