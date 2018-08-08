#!/bin/bash -a
# -*- coding: utf-8 -*-
# @author  Julie Orjuela
			
# Charging modules"
module load system/perl/5.24.0
module load bioinfo/Trinotate/3.0.1
module load bioinfo/TransDecoder/3.0.0
module load bioinfo/hmmer/3.1b2
module load bioinfo/diamond/0.7.11 #demander la version 0.8 dans les module load
#variables
geneTransMap="longestAGglobal-Trinity.fasta_gene_trans_map"
fasta="/data3/projects/arapaima/DATAONLYCLEANED/trinity-finalresults/LONGEST/annotation-global/longestAGglobal-Trinity.fasta"
resultsDir="/data3/projects/arapaima/DATAONLYCLEANED/trinity-finalresults/LONGEST/annotation-global/jobArray-Trinotate/Trinotate/results_longestAGglobal-Trinity"
shortName="longestAGglobal"
cd $resultsDir
transdecoderPep="longestAGglobal-Trinity.fasta.transdecoder.pep"

#7 recuperation de la base Trinotate >>> DEJA RECUPERE DANS TRINONATE DEPO
wget "https://data.broadinstitute.org/Trinity/Trinotate_v3_RESOURCES/Trinotate_v3.sqlite.gz" -O Trinotate.sqlite.gz
gunzip Trinotate.sqlite.gz

##8 chargement des analyses dans la base
##/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite init --gene_trans_map $geneTransMap --transcript_fasta $fasta --transdecoder_pep $transdecoderPep
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite init --gene_trans_map $geneTransMap --transcript_fasta $fasta --transdecoder_pep $transdecoderPep

#charging swissprot/uniprot P and X results
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_swissprot_blastp diamP_uniprot.outfmt6
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_swissprot_blastx diamX_uniprot.outfmt6
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_swissprot_blastp diamP_uniprot.outfmt6
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_swissprot_blastx diamX_uniprot.outfmt6

#charging uniref90 P and X results
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_custom_blast --outfmt6 diamP_uniref90.outfmt6 --prog blastp --dbtype uniref90
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_custom_blast --outfmt6 diamX_uniref90.outfmt6 --prog blastx --dbtype uniref90
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_custom_blast --outfmt6 diamP_uniref90.outfmt6 --prog blastp --dbtype uniref90
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_custom_blast --outfmt6 diamX_uniref90.outfmt6 --prog blastx --dbtype uniref90

#charging pfam, tmhmm, signalp and rnammer
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_pfam $shortName"_PFAM.out" 
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_tmhmm $shortName".tmhmm.out"
#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_rnammer $shortName".fasta.rnammer.gff"

#/usr/local/Trinotate-3.0.1/Trinotate /home/orjuela/tools/trinonatedb/Trinotate.sqlite LOAD_signalp $shortName"_signalp.out" 

/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_pfam $shortName"_PFAM.out" 
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_tmhmm $shortName".tmhmm.out"
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_rnammer $shortName".fasta.rnammer.gff"

/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite LOAD_signalp $shortName"_signalp.out" 


## 9 generation du report
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite report > $shortName"_annotation_report.xls"
#filtré sur les e-value des annotations
/usr/local/Trinotate-3.0.1/Trinotate $resultsDir/Trinotate.sqlite report -E 10e-10 > $shortName"_annotation_report_filtered.xls"
#10 generation de statistiques
/usr/local/Trinotate/util/count_table_fields.pl Trinotate.xls > table_fields.txt
#11 extract GO terms
/usr/local/Trinotate-3.0.1/util/extract_GO_assignments_from_Trinotate_xls.pl --Trinotate_xls annotation_report_rrna.xls -G --include_ancestral_terms >
go_annotations.txt

#site wego : http://wego.genomics.org.cn/cgi-bin/wego/index.pl