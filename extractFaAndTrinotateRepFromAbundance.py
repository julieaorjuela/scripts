#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# @package renameFastaFromAnnotation.py
# @author Julie Orjuela

"""
    The extractFaAndTrinotateRepFromAbundance.py script
    ==========================
    :author: Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :date: 11/09/2018
    :version: 0.1
    Script description
    ------------------
    extractFaAndTrinotateRepFromAbundance takes a Fasta, a trinonate report and a abondance File obtained by kalisto.
    It simplifies fasta and annotation report using trinity transcrit name from file containing list transcrits.
    Example
    -------
    >>> # keep sequences in list
    >>> extractFaAndTrinotateRepFromAbundance.py -f assamblies.fasta -r reportFromTrinonate.txt -l listoftranscrits.txt -o output.fasta
    
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
        - \-l <filename>, --list <filename>
                        list of transcrits                        
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
from Bio import SeqIO


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
def checkParameters (arg_list): # sravel fonction
    # Check input related options
    if (not arg_list.fastaFile and not arg_list.reportFile and not not arg_list.list):
        print ('Error: No input file defined via option -f/--fasta or -r/--report or -l/--list !' + "\n")
        parser.print_help()
        exit()
        
def relativeToAbsolutePath(relative): #from moduleseb sravel
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
    filesreq.add_argument('-l', '--list', metavar="<filename>", required=True, dest = 'listFile', help = 'transcrits list file')
    filesreq.add_argument('-o', '--out', metavar="<filename>", required=True, dest = 'output', help = 'Name of output file')

    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in extractFaAndTrinotateRepFromAbundance (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Récupère le fichier de conf passer en argument
    fastaFile = relativeToAbsolutePath(args.fastaFile)
    listFile = relativeToAbsolutePath(args.listFile)
    reportFile = relativeToAbsolutePath(args.reportFile)

    outputfileFa = str(args.output)+".fa"
    outputfileReport = str(args.output)+".report"
    
    #on efface les données si deja lance avant
    outputhandleFa = open(outputfileFa, "w+")
    outputhandleFa.write("hello")
    outputhandleFa.close()
    #print (fastaFile, outputfileFa, outputfileReport, listFile, reportFile)
    
    #pour chaque list des transcrits extraer les annotations du report trinonate
    with open(listFile, "rU") as listHandle: 
        for lineList in listHandle:
            #ouverture des fichiers d'ecriture
            i=0
            j=0
            #print ("DBG::=============================>",lineList)
            transcriptIdList=lineList.rstrip()
            colLigne=lineList.split("\t")
            transcriptIdList=colLigne[0]
            #print ("DBG::=============================>",lineList, transcriptIdList )
            #extraer la sequence fasta
            with open(fastaFile, "rU") as handle: # automatiquement ferme le fichier quand il sot du block
                for record in SeqIO.parse(handle, "fasta"):
                    headerFasta=str(record.description)
                    tmp=headerFasta.split(' ')
                    transcriptIdFasta=tmp[0]
                    #print ("DBG::  -----------------------------------", transcriptIdFasta)
                    if ((transcriptIdFasta==transcriptIdList) and (i<=1)): #on compare le nom du transcrit mais next si vu plus de 50 fois
                        string=str('>'+record.description+"\n"+record.seq+"\n")
                        outputhandleFa = open(outputfileFa, "a+")
                        outputhandleFa.write(string)
                        outputhandleFa.close()
                        #print ("DBG:: ",transcriptIdFasta,transcriptIdList)
                        #extraer les infos du rapport d'annotation
                        i=i+1
                        with open(reportFile, "rU") as reportHandle:
                            for lineReport in reportHandle:
                                colFromLineReport=lineReport.split("\t")
                                transcriptIdReport=colFromLineReport[1]
                                if ((transcriptIdReport==transcriptIdList) and (j<=30)): #on compare le nom du transcrit mais next si vu plus de 50 fois
                                    outputhandleReport = open(outputfileReport, "a+")
                                    outputhandleReport.write(lineReport)
                                    outputhandleReport.close()
                                    #print ("DBG:**** :",transcriptIdList, transcriptIdReport)
                                    j=j+1 
                                else:
                                    next
                                #print ("i:", i,"j:", j)
                    else:
                        next
                    #closing files
                #print ("DBG:: i:", i,"j:", j)
            
            
            
   
    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")

