#!/usr/bin/python3.6
# -*- coding: utf-8 -*-
# @package formating_for_circos.py
# parsarg and relativeToAbsolutePath by Sebastien Ravel
# @author Julie Orjuela
# TODO: eliminer la sortie standard de samtools
# TODO: la palette de colors ne marche pas pour circos, ajouter les palettes generés par ce script dans les confs de circos.


"""
    The formating_for_circos script
    ==========================
    :author:  Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :date: 13/06/2018
    :version: 0.1
    Script description
    ------------------
    formating_for_circos creates circos input; it recoveries SNP position from SDpop
    output and extract reads from BAM1. Recovery position in BAM2 using Fastq read names.
    This script create input 'link.txt' and 'kariotype.txt' to circos.
    
    -------
    >>> formating_for_circos.py -d DE.csv -g GFF.gff -o OUT.bed
    
    Help Programm
    -------------
    optional arguments:
        - \-h, --help                       show this help message and exit
        - \-v, --version                    display formating_for_circos.py version number and exit
    Input mandatory infos for running:
        - \-s <filename>, --sdpop <filename>   sdpop version 3 output 
        - \-b1 <filename>, --bam1 <filename>  bam file 1
        - \-b2 <filename>, --bam2 <filename>  bam file 2
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

## BIO Python modules
#from Bio import SeqIO

##################################################
## Variables Globales
##################################################
version="0.1"
VERSION_DATE='13/06/2019'
debug="False"
#debug="True"

##################################################
## Functions
##################################################
def checkParameters (arg_list):
    # Check input related options
    if (not arg_list.sdpop_file and not arg_list.bam1_file and not arg_list.bam2_file and not arg_list.vcf1_file and not arg_list.vcf1_file):
        print ('Error: No input file defined via option -s/--sdpop or -b1/--bam1 or -b2/--bam2 or -v1/--vcf1 or -v2/--vcf2 !' + "\n")
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
    
def finding_correspondance(snp):
    name=snp[0]+'_'+snp[1]+'-'+snp[2]
    fq=f"{name}_R1.fastq"
    fq2=f"{name}_R2.fastq"
    commande = f"samtools view -h -b {bam1} {snp[0]}:{snp[1]}-{snp[2]} >{name}.bam"
    print(commande)
    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True)
    print('----------------', process.stdout)
    
    commande=f"bedtools bamtofastq -i {name}.bam -fq {fq} -fq2 {fq2}"
    print(commande)
    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True)
    print('----------------', process.stdout)
    extracted_bam_file=extract_positions_in_second_bam(fq,fq2,name)
    position_in_second_ref=colapsing_reads(extracted_bam_file) #liste des positions bam2
    return position_in_second_ref

    
def extract_positions_in_second_bam(fq,fq2,name):
    with open(fq, "r") as r1:
        motif="(\w+:\d+:\d+\-\w+:\d+:\w+:\d+:\d+)/1"
        for line in r1:
            if (line.strip().startswith('@')):
                #M03493:159:000000000-BRHMN:1:2113:27819:14138/1
                res=re.search(motif,line)
                print(res.group(1))
                if res.group(1) is not None:
                    commande=f"samtools view -h {bam2} | grep {res.group(1)} >{name}_extracted.bam"
                    print(commande)
                    process = subprocess.run(commande,stdout=subprocess.PIPE,shell=True,)
                    print('----------------', process.stdout)
                    return f"{name}_extracted.bam"


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
        

def extract_contig_size_from_vcf(vcf,mode,motif_from_liste,color):
    with open(vcf, "r") as vcf, open("kariotype.txt", mode) as kariotype:
        ##contig=<ID=dpKhlsCanu10Xmrg_226,length=144901>
        motif=f"##contig=<ID=({motif_from_liste}),length=(\d+)>"
        for line in vcf:    
                res=re.search(motif,line)
                if res is not None :
                    #print ('********************** res',res.group(1), res.group(2))
                    #chr	-	LGA1	LGA1	0	1790022	chr1
                    #chr - hs22 22 0 51304566 chr22
                    #kariotype.write(f"chr\t-\t{res.group(1)}\t{res.group(1)}\t0\t{res.group(2)}\t{color}\n")
                    kariotype.write(f"chr\t-\t{res.group(1)}\t{res.group(1)}\t0\t{res.group(2)}\tchr1\n")
                    return res.group(1), res.group(2)
                                            
##################################################
## Main code
##################################################
if __name__ == "__main__":
    # Initializations
    start_time = strftime("%d-%m-%Y_%H:%M:%S", localtime())
    # Parameters recovery
    parser = argparse.ArgumentParser(prog='formating_for_circos.py', description='''This Programme formating_for_circos creates \
                                     a tsv poutput containing correspondanted region from a SNP from a genome1  to a genome2''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display formating_for_circos.py version number and exit')
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-s', '--sdpop', metavar="<filename>", required=True, dest = 'sdpop_file', help = 'SDpop file')
    filesreq.add_argument('-b1', '--bam1', metavar="<filename>", required=True, dest = 'bam1_file', help = 'bam file 1')
    filesreq.add_argument('-b2', '--bam2', metavar="<filename>", required=True, dest = 'bam2_file', help = 'bam file 2')
    filesreq.add_argument('-v1', '--vcf1', metavar="<filename>", required=True, dest = 'vcf1_file', help = 'vcf file 1')
    filesreq.add_argument('-v2', '--vcf2', metavar="<filename>", required=True, dest = 'vcf2_file', help = 'vcf file 2')
    
    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in formating_for_circos (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Recupere le fichier de conf passer en argument
    s = relativeToAbsolutePath(args.sdpop_file)
    bam1 = relativeToAbsolutePath(args.bam1_file)
    bam2 = relativeToAbsolutePath(args.bam2_file)
    vcf1 = relativeToAbsolutePath(args.vcf1_file)
    vcf2 = relativeToAbsolutePath(args.vcf2_file)
    
    # parcourir sdpop file 
    with open(s, "r") as sdpop, open("link.txt", "w") as link:
        #header obligatoire
        en_tete_sd_pop = sdpop.readline().rstrip()
        liste_contigs_ref1=[]
        liste_contigs_ref2=[]
        for line in sdpop:
            if 'XY' in line:
                snp=[]
                colonnes=line.strip().split('\t')
                snp.append(colonnes[10].strip(">"))
                snp.append(colonnes[0])
                snp.append(colonnes[0])
                
                if colonnes[10].strip(">") not in liste_contigs_ref1:
                    liste_contigs_ref1.append(colonnes[10].strip(">"))
                corresp=finding_correspondance(snp)
                if corresp is not None:
                    if not 'any' in corresp:
                        link.write('\t'.join(snp)+'\t'+'\t'.join(corresp)+'\n')
                        if corresp[0] not in liste_contigs_ref2:
                            liste_contigs_ref2.append(corresp[0])
        #print(liste_contigs_ref1)
        #print(liste_contigs_ref2)
    
    #creation du fichier de kariotypes
    with open("kariotype.txt", "w") as kariotype:
        kariotype.write(f"#header\n")
    
    #colors_liste=[chr1,chr2,chr3,chr4,chr5,chr6,chr7,]
    
    palette1 = sns.color_palette("muted", len(liste_contigs_ref1))
    palette2 = sns.color_palette("RdBu", len(liste_contigs_ref2))

    #extraction des contigs et taille selon liste_contigs_refs
    count=0
    for element in liste_contigs_ref1:
        color=str(palette1[count]).strip('(').strip(')').strip(' ')
        extract_contig_size_from_vcf(vcf1,'a',element,color) 
        count=count+1
    
    count=0
    for element in liste_contigs_ref2:
        color=str(palette2[count]).strip('(').strip(')').strip(' ')
        extract_contig_size_from_vcf(vcf2,'a',element,color)
        count=count+1
                        

    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")


