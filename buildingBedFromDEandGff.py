#!/usr/bin/python3.6
# -*- coding: utf-8 -*-
# @package buildingBedFromDEandGff.py
# parsarg and relativeToAbsolutePath by Sebastien Ravel
# @author Julie Orjuela

"""
    The buildingBedFromDEandGff script
    ==========================
    :author:  Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :date: 28/10/2018
    :version: 0.1
    Script description
    ------------------
    buildingBedFromDEandGff create a bed containing UTRs regions from DE list genes using annotation gtf obtained by stringtie. 
    -------
    >>> buildingBedFromDEandGff.py -d DE.csv -g GFF.gff -o OUT.bed
    
    Help Programm
    -------------
    optional arguments:
        - \-h, --help
                        show this help message and exit
        - \-v, --version
                        display extractSeqFasta.py version number and exit
    Input mandatory infos for running:
        - \-d <filename>, --de <filename>
                        intervals fasta
        - \-g <filename>, --gff <filename>
                        depth summary obtained by samtools
        - \-o <filename>, --out <filename>
                        Name of output csv file
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

## BIO Python modules
#from Bio import SeqIO

##################################################
## Variables Globales
##################################################
version="0.1"
VERSION_DATE='27/05/2019'
debug="False"
#debug="True"


##################################################
## Functions
##################################################
def checkParameters (arg_list):
    # Check input related options
    if (not arg_list.de_file and not arg_list.gff_file):
        print ('Error: No input file defined via option -d/--de or -g/--gff !' + "\n")
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

##################################################
## Main code
##################################################
if __name__ == "__main__":
    # Initializations
    start_time = strftime("%d-%m-%Y_%H:%M:%S", localtime())
    # Parameters recovery
    parser = argparse.ArgumentParser(prog='buildingBedFromDEandGff.py', description='''This Programme buildingBedFromDEandGff create a bed containing UTRs regions from DE list genes using annotation gtf obtained by stringtie''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display buildingBedFromDEandGff.py version number and exit')
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-d', '--de', metavar="<filename>", required=True, dest = 'de_file', help = 'DE file')
    filesreq.add_argument('-g', '--gff', metavar="<filename>", required=True, dest = 'gff_file', help = 'gtf stringtie or gffcompare file')
    filesreq.add_argument('-o', '--out', metavar="<filename>", required=True, dest = 'bed_file', help = 'Name of output bed file')

    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in buildingBedFromDEandGff (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Recupere le fichier de conf passer en argument
    de = relativeToAbsolutePath(args.de_file)
    gff = relativeToAbsolutePath(args.gff_file)
    bed = relativeToAbsolutePath(args.bed_file)

    # parcourir de file et gff file au meme temps
    with open(de, "r") as de_file, open(bed, "w") as bed_out:
        linebed=["#contig","start","stop","name","score","strand"]
        bed_out.write("\t".join(linebed) + "\n")
        en_tete_de = de_file.readline().rstrip()
        # boucle sur le fichier de
        for lineD in de_file:
            dline=lineD.strip().split(",")
            # on parcour le gff
            count=0
            with open(gff, "r") as gff_file:
                for line in gff_file:
                    en_tete_gff = gff_file.readline().rstrip()
                    if not line.startswith('#'):
                        gline=line.strip().split("\t")
                        dline_cleaned=str(dline[0]).replace('\"','')
                        if ('transcript' in gline[2]) and (dline_cleaned in gline[8]) and (count <3):
                            print(dline[0],"-----------",gline[8], "------ count:", count)
                            count=count+1
                            start=int(gline[3])-1000
                            if start<=0:
                                start=1
                            else:
                                linebed=[gline[0],str(start),gline[3],gline[2],gline[5],gline[6]]
                                bed_out.write("\t".join(linebed) + "\n")
    
    #### faire un dico avec les sites trouvés apres avoir parcouri les csv d'un dossier donnée en paramettre.

    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")

