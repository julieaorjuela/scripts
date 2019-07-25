#!/usr/bin/python3.6
# -*- coding: utf-8 -*-
# @package talvez_ref1_to_ref2_recovery_annotation.py
# parsarg and relativeToAbsolutePath by Sebastien Ravel
# @author Julie Orjuela


"""
    The talvez_ref1_to_ref2_recovery_annotation
    ==========================
    :author:  Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :institut: IRD
    :date: 15/07/2019
    :version: 0.2
    :last: 24/07/2019
    Script description
    ------------------
    talvez_ref1_to_ref2_recovery_annotation recoveries position from EBEs found by TALVEZ
    output and extract reads from BAM1. Recovery position in BAM2 using Fastq read names.
    This script create txt file with gene name annotation from VCF or ref2. It generates a
    bed file and a fasta file containig UTR and gene sequences for each TALVEz EBE.
    
    -------
    >>> talvez_ref1_to_ref2_recovery_annotation.py -t talvez.out -b1 bam2.bam -b2 bam2.bam -v2 vcf2.vcf -o outputname
    
    Help Programm
    -------------
    optional arguments:
        - \-h, --help                       show this help message and exit
        - \-v, --version                    display talvez_ref1_to_ref2_recovery_annotation.py version number and exit
    Input mandatory infos for running:
        - \-t <filename>, --talvez <filename>  talvez output 
        - \-b1 <filename>, --bam1 <filename>  bam file 1
        - \-b2 <filename>, --bam2 <filename>  bam file 2
        - \-v2 <filename>, --bam2 <filename>  vcf file 2
        - \-o <filename>, --output <prefixe>  output prefixe name
"""

##################################################
## Modules
##################################################
import sys, os, subprocess, re

current_dir = os.path.dirname(os.path.abspath(__file__))+"/"

## Python modules
import argparse
from time import localtime, strftime
import pandas as pd 
import numpy as np
from pprint import pprint
import os

import seaborn as sns

##################################################
## Variables Globales
##################################################
version="0.1"
VERSION_DATE='15/07/2019'
debug="False"

##################################################
## Functions
##################################################
def checkParameters (arg_list):
    # Check input related options
    if (not arg_list.talvez_file and not arg_list.bam1_file and not arg_list.bam2_file and not arg_list.vcf1_file and not arg_list.vcf1_file):
        print ('Error: No input file defined via option -t/--talvez or -b1/--bam1 or -b2/--bam2 or -v2/--vcf2 or -o/--output !' + "\n")
        parser.print_help()
        exit()
        
def relativeToAbsolutePath(relative): 
    from subprocess import check_output
    if relative[0] != "/":            # The relative path is a relative path, ie do not starts with /
        command = "readlink -m "+relative
        absolutePath = subprocess.check_output(command, shell=True).decode("utf-8").rstrip()
        return absolutePath
    else:                            # Relative is in fact an absolute path, send a warning
        absolutePath = relative;
        return absolutePath
    
def finding_correspondance(tal):
    name=tal[0]+'_'+str(tal[1])+'-'+str(tal[2])
    fq=f"{name}.fastq"
    #fq=f"{name}_R1.fastq"
    #fq2=f"{name}_R2.fastq"
    commande = f"samtools view -h -b {bam1} {tal[0]}:{tal[1]}-{tal[2]} >{name}.bam"
    print(commande)
    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,encoding="utf-8")
    print('----------------', process.stdout)
    
    #commande=f"bedtools bamtofastq -i {name}.bam -fq {fq} -fq2 {fq2}"
    #print(commande)
    #process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,encoding="utf-8")
    #print('----------------', process.stdout)
    
    # recuperer le premier read du bam
    commande=f"samtools view {name}.bam | head -n1 > {fq}"
    print(commande)
    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,encoding="utf-8")
    print('----------------', process.stdout)
     # recuperer le dernier read du bam
    commande=f"samtools view {name}.bam | tail -n1 >> {fq}"
    print(commande)
    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,encoding="utf-8")
    print('----------------', process.stdout)

    # pour chaque read (first and last), on cherche la correspondance dans le bam2
    extracted_bam_file=extract_positions_in_second_bam(fq,name)
    position_in_second_ref=colapsing_reads(extracted_bam_file) #liste des positions bam2
    
    return position_in_second_ref
        

def extract_positions_in_second_bam(fq,name):
    with open(fq, "r") as r1:
        #@M03493:159:000000000-BRHMN:1:2113:27819:14138/1
        #motif="(\w+:\d+:\d+\-\w+:\d+:\w+:\d+:\d+)/1"
        #@H3:C4UJUACXX:2:2207:21078:31753/1
        motif="(\w+:\w+:\d+:\d+:\d+:\d+)"
        for line in r1:
            res=re.search(motif,line)
            print(res.group(1))
            if res.group(1) is not None:
                commande=f"samtools view -h {bam2} | grep {res.group(1)} >{name}_extracted.sam"
                print(commande)
                process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,encoding="utf-8")
                print('----------------', process.stdout)
                return f"{name}_extracted.sam"


def colapsing_reads(extracted_bam_file):
    if extracted_bam_file is not None:
        liste=[]
        with open(extracted_bam_file, "r") as extracted:
            liste=['any','0','0']
            for line in extracted:
                line=line.split("\t")
                contig=str(line[2])
                mini=int(line[3])
                maxi=mini+int(line[8])
                if not contig=='any': # diff nom de LG
                    liste[0]=contig
                    liste[1]=str(mini)
                    liste[2]=str(maxi)
                elif contig==liste[0] and mini<liste[1]: #if contig equal and min diff
                    liste[1]=str(mini)
                elif contig==liste[0] and maxi>liste[2]: #if contig equal and max diff
                    liste[2]=str(maxi)
        return liste
        

# pour projet circos penser à merger les bams
# tester mummer pour recuperer la sequence dans la deuxieme ref
                                            
##################################################
## Main code
##################################################
if __name__ == "__main__":
    # Initializations
    start_time = strftime("%d-%m-%Y_%H:%M:%S", localtime())
    # Parameters recovery
    parser = argparse.ArgumentParser(prog='talvez_ref1_to_ref2_recovery_annotation.py', description='''This Programme talvez_ref1_to_ref2_recovery_annotation creates \
                                     a tsv poutput containing correspondanted region from a SNP from a genome1  to a genome2''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display talvez_ref1_to_ref2_recovery_annotation.py version number and exit')
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-t', '--talvez', metavar="<filename>", required=True, dest = 'talvez_file', help = 'TALVEz file')
    filesreq.add_argument('-b1', '--bam1', metavar="<filename>", required=True, dest = 'bam1_file', help = 'bam file 1')
    filesreq.add_argument('-b2', '--bam2', metavar="<filename>", required=True, dest = 'bam2_file', help = 'bam file 2')
    filesreq.add_argument('-v2', '--vcf2', metavar="<filename>", required=True, dest = 'vcf2_file', help = 'vcf file 2')
    filesreq.add_argument('-o', '--output', metavar="<string>", required=True, dest = 'output_name', help = 'output prefixe')
    
    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in talvez_ref1_to_ref2_recovery_annotation (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Recupere le fichier de conf passer en argument
    t = relativeToAbsolutePath(args.talvez_file)
    bam1 = relativeToAbsolutePath(args.bam1_file)
    bam2 = relativeToAbsolutePath(args.bam2_file)
    vcf2 = relativeToAbsolutePath(args.vcf2_file)
    outputF = relativeToAbsolutePath(args.output_name)
    
    # parcourir talvez file 
    with open(t, "r") as talvez, open(outputF, "w") as output:
        #header obligatoire
        en_tete_talvez = talvez.readline().rstrip()
        liste_contigs_ref1=[]
        liste_contigs_ref2=[]
        for line in talvez:
            if not 'TAL_ID' in line:
                tal=[]
                colonnes=line.strip().split('\t')
                talbs_start=int(colonnes[6])
                talbs_stop=int(colonnes[7])
                #recupere la colonne SEQ_ID
                motif="(\w+):(\d+)-(\d+)"
                print (colonnes[2])
                res=re.search(motif,colonnes[2])
                
                tal.append(res.group(1))
                tal.append(str(int(res.group(2))+1000))
                tal.append(str(int(res.group(3))+3000))
                #tal.append(str(int(res.group(2))+talbs_start))
                #tal.append(str(int(res.group(2))+talbs_stop))
                print (tal)
                if res.group(1) not in liste_contigs_ref1:
                    liste_contigs_ref1.append(res.group(1))
                corresp=finding_correspondance(tal)
                print (corresp)
                if corresp is not None:
                    if not 'any' in corresp:
                        output.write('\t'.join(tal)+'\t'+'\t'.join(corresp)+'\n')
                        if corresp[0] not in liste_contigs_ref2:
                            liste_contigs_ref2.append(corresp[0])
        print(liste_contigs_ref1)
        print(liste_contigs_ref2)
                    
#####bam indexation, check positions
    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")


