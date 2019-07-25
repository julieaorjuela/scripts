#!/usr/bin/python3.5
# -*- coding: utf-8 -*-
# @package renameFastaFromAnnotation.py
# @author Julie Orjuela

"""
    The renameFastaFromAnnotation script
    ==========================
    :author: Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :date: 07/07/2018
    :version: 0.1
    Script description
    ------------------
    renameFastaFromAnnotation takes a Fasta and a trinonate report. It simplifies fasta header and adds annotation of genes if exists
    Example
    -------
    >>> # keep sequences in list
    >>> renameFastaFromAnnotation.py -f assamblies.fasta -r reportFromTrinonate.txt -o output.fasta
    
    Help Programm
    -------------
    optional arguments:
        - \-h, --help
                        show this help message and exit
        - \-v, --version
                        display extractSeqFasta.py version number and exit
    Input mandatory infos for running:
        - \-f <filename>, --fasta <filename>
                        fasta files
        - \-r <filename>, --report <filename>
                        report file previosusly obtained using sqlite trinonate database
        - \-o <filename>, --out <filename>
                        Name of output fasta file
"""

##################################################
## Modules
##################################################
import sys, os, subprocess, re
current_dir = os.path.dirname(os.path.abspath(__file__))+"/"

## Python modules
import argparse
from time import localtime, strftime

## BIO Python modules
#from Bio import SeqIO

##################################################
## Variables Globales
##################################################
version="0.1"
VERSION_DATE='07/07/2018'
debug="False"
#debug="True"


##################################################
## Functions
##################################################
def checkParameters (arg_list):
    # Check input related options
    if (not arg_list.fastaFile and not arg_list.reportFile):
        print ('Error: No input file defined via option -f/--fasta or -r/--report !' + "\n")
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
    parser = argparse.ArgumentParser(prog='renameFastaFromAnnotation.py', description='''This Programme simplifies fasta header and adds annotation from a trinonate report''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display renameFastaFromAnnotation.py version number and exit')
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-f', '--fasta', metavar="<filename>", required=True, dest = 'fastaFile', help = 'fasta file')
    filesreq.add_argument('-r', '--report', metavar="<filename>", required=True, dest = 'reportFile', help = 'trinonate report file with annotation')
    filesreq.add_argument('-o', '--out', metavar="<filename>", required=True, dest = 'paramoutfile', help = 'Name of output file')

    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in extractSeqFasta (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Récupère le fichier de conf passer en argument
    fastaFile = relativeToAbsolutePath(args.fastaFile)
    outputfilename = relativeToAbsolutePath(args.paramoutfile)
    reportFile = relativeToAbsolutePath(args.reportFile)
    
    print (fastaFile, outputfilename, reportFile)
    
    #le header des fichiers report de trinonate contienne :
    #gene_id	transcript_id	sprot_Top_BLASTX_hit	RNAMMER	prot_id	prot_coords	sprot_Top_BLASTP_hit	uniref90_BLASTX	uniref90_BLASTP	Pfam	SignalP	TmHMM	eggnog	Kegg	gene_ontology_blast	gene_ontology_pfam	transcript	peptide
    
    # extract simplified fonction from reportFile and putting it in a dico
    dicoReport={}
    reportHandle = open(reportFile, "r")
    for line in reportHandle:
        listFromLine=line.split("\t")
        transcriptId=listFromLine[1]
        sprotTopBLASTXhit=listFromLine[2]
        listsprotTopBLASTXhit=sprotTopBLASTXhit.split("Full=")
        if len(listsprotTopBLASTXhit)>=2:
            listTmp=listsprotTopBLASTXhit[1]
            annotation=listTmp.split(";")
            dicoReport[transcriptId]=annotation[0] #si la clé existe la nouvelle fonction n'est pas prise en compte
        else:
            dicoReport[transcriptId]='unknown' # on ajoute unknown si aucune fonction trouvée
    #print(dicoReport)
    
    #recupere le nom du transcrit et le comparer avec les clés du dico 
    fastaHandle = open(fastaFile, "r")
    outputhandle = open(outputfilename, "w")
    
    for fastaLine in fastaHandle:
        if '>' in fastaLine:
            listHeaderFasta=fastaLine.split(" ")
            chaine=listHeaderFasta[0]
            chaine=chaine.replace(">", "")
            if chaine in dicoReport:
                # on ajoute la valeur à l'entete du fichier fasta
                string=str('>'+chaine+"\t"+dicoReport[chaine]+"\n")
                outputhandle.write(string)
            else:
                #print ('>'+chaine,"transcrit absent!")
                string=str('>'+chaine+"\tabsent transcrit!\n")
                outputhandle.write(string)
        else:
            #print (fastaLine)
            string=str(fastaLine)
            outputhandle.write(string)
    
    
    #closing files
    reportHandle.close()
    fastaHandle.close()      
    outputhandle.close()
            
   

    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")

