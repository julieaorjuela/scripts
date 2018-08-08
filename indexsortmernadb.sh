#!/bin/bash -a
# -*- coding: utf-8 -*-

#demander à un root de faire cette indexation si jamais elle n'est pas deja faite sur le dossier d'install de sortmerna
echo "indexing sortmerna" 
path_to_sortmerna="/usr/local/sortmerna-2.1/";
$path_to_sortmerna/indexdb_rna --ref \
$path_to_sortmerna/rRNA_databases/silva-bac-16s-id90.fasta,$path_to_sortmerna/index/silva-bac-16s-db:\
$path_to_sortmerna/rRNA_databases/silva-bac-23s-id98.fasta,$path_to_sortmerna/index/silva-bac-23s-db:\
$path_to_sortmerna/rRNA_databases/silva-arc-16s-id95.fasta,$path_to_sortmerna/index/silva-arc-16s-db:\
$path_to_sortmerna/rRNA_databases/silva-arc-23s-id98.fasta,$path_to_sortmerna/index/silva-arc-23s-db:\
$path_to_sortmerna/rRNA_databases/silva-euk-18s-id95.fasta,$path_to_sortmerna/index/silva-euk-18s-db:\
$path_to_sortmerna/rRNA_databases/silva-euk-28s-id98.fasta,$path_to_sortmerna/index/silva-euk-28s:\
$path_to_sortmerna/rRNA_databases/rfam-5s-database-id98.fasta,$path_to_sortmerna/index/rfam-5s-db:\
$path_to_sortmerna/rRNA_databases/rfam-5.8s-database-id98.fasta,$path_to_sortmerna/index/rfam-5.8s-db 
echo "done" 