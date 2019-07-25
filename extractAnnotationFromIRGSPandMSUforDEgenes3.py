#!/usr/local/bioinfo/python/3.4.3_build2/bin/python
# -*- coding: utf-8 -*-
# @package extractAnnotationFromIRGSPandMSUforDEgenes.py
# @author Sebastien Ravel : parse args
# @author Julie Orjuela : parsing and extract fonctions

"""
The extractAnnotationFromIRGSPandMSUforDEgenes script
===========================
:author: Julie Orjuela
:contact: julie.orjuela@irf.fr
:date: 06/04/2019
:version: 0.3
Script description
------------------
This Programme takes a list of DE genes and search annotation from IRGSP.gff and MSU.gff annotation. 
    It needs a RAP-MSU correspondaces table contatining synomime name between IRGSP and MSU.
    This script returns a DE file contanig similar file in input wiht aditional columns contating annotation from IRGSP and MSU.
Example
-------
>>> extractAnnotationFromIRGSPandMSUforDEgenes.py -d list_genes_DE.csv -c RAP-MSU_table.txt\
    -i IRGSP.gff -m MSU.gff -o OUTPUT.csv
Help Programm
-------------
optional arguments:
	- \-h, --help
						show this help message and exit
		- \-v, --version
						display scriptName.py version number and exit
	Input mandatory infos for running:
		- \-d <path/to/file/list_genes_DE.csv>, --de <path/to/file/list_genes_DE.csv>
						file contains DE results from EdgeR or Deseq2
		- \-c <path/to/file/RAP-MSU_table.txt>, --rapmsu <path/to/file/RAP-MSU_table.txt>
						file of correspondances between IRGSP and MSU annotation
		- \-i <path/to/file/IRGSP.gff, --irgsp <path/to/file/IRGSP.gff>
						File with IGSP.gff annotation
		- \-m <path/to/file/MSU.gff, --msu <path/to/file/MSU.gff>
						File with MSU.gff annotation                        
"""


##################################################
## Modules
##################################################
#Import MODULES_SEB
import sys, os, csv
current_dir = os.path.dirname(os.path.abspath(__file__))+"/"
sys.path.insert(1,current_dir+'../modules/')
from MODULES_SEB import relativeToAbsolutePath, existant_file

## Python modules
import argparse
import re
from time import localtime, strftime


##################################################
## Variables Globales
version="0.3"
VERSION_DATE='11/04/2018'
LAST='23/04/2018'
    
#python3 ../../../script-extractAnnotation/extractAnnotationFromIRGSPandMSUforDEgenes.py -d condtime_crispT2_vs_crispT0_FDR0.1_pvalue0.01_deseq_results_subsampled.csv -m MSUv7.0.gff -i IRGSP-1.0_representative/locus.gff -c RAP-MSU_2019-03-22.txt -o test.txt
##################################################
    
## Functions    
def extractAnnotationFromFile(filePath, motif, typeF):
    """cherche l'annotation du gene dans le fichier donné en argument"""
    ann=""
    out=""
    file = open (filePath, "r")
    for line in file:
        if motif in line:
            ann = cleaningLine(line,'\t')
            #DBG:: print ("ANN:", ann)
            if str(ann) !='None' :
                if typeF=="I":
                    m=re.search('Name=(\w.*);Note=(\w.*);Transcript ', ann[8])
                    out=m.group(2)
                    return out
                if typeF == "M" :
                    #DBG:: print (ann[8])
                    m=re.search('Name=(\w.*);Note=(\w.*)$', ann[8])
                    if str(m) != 'None':
                        #DBG:: print(m)
                        out=m.group(2)
                        return out
                    else:
                        out="PROBLEME"
                        return out
            else:
                out='AUCUNE_ANNOTATION'
                return out   
    file.close()    
    

def searchInRapMsu(loc):
    """selon le LOC cherche la correspondance dans la base RAP"""
    fileRM = open (rapmsu, "r")
    rap=""
    for lineRM in fileRM:
        lineRM = cleaningLine(lineRM,"\t")
        for element in lineRM:
            if loc in element:
                rap=lineRM[0]
            if str(rap) == 'None':
                rap="ANYRAP"
    fileRM.close()
    return (rap)
            
def cleaningLine(line,sep):
    """nettoyage d'une line"""
    if not line.startswith('#') : # on vire les entetes 
        line = line.strip("'")#chomp
        line = line.strip("\n")#chomp
        line = line.replace('\"','')
        line = line.split(sep)
        return (line)
    
def traitmentDE(line):
    """traitement du fichiers DE pour recuperer les LOC"""
    if line.startswith("MSTRG"):
        MSTRG = line.split(".")
        MSTRG = MSTRG[0]+'.'+MSTRG[1]
        line = line.split(".")[2:]
    else:
        MSTRG = "ANYMSRG"
        line = line.split(".")
    #DBG:: print (MSTRG,line)
    return (MSTRG, line)

def recoveryHeader(file):
    """recuperer la premiere ligne du fichier"""
    f = open(file, 'r')
    line = f.readline()
    f.close()
    return line
    

##################################################
## Main code
##################################################
if __name__ == "__main__":
    # Initializations
    start_time = strftime("%d-%m-%Y_%H:%M:%S", localtime())
    # Parameters recovery
    parser = argparse.ArgumentParser(prog=__file__, description='''This Programme takes a list of DE genes and search annotation from IRGSP.gff and MSU.gff annotation''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display '+__file__+' version number and exit')
    parser.add_argument('-dd', '--debug', action='store_true', dest='debug', help='enter verbose/debug mode')
    
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-d', '--de', metavar="<filename>",type = existant_file, required=True, dest = 'deFile', help = 'file must contain DE results from Deseq2 or EdgeR')
    filesreq.add_argument('-c', '--rapmsu', metavar="<filename>",type = existant_file, required=True, dest = 'rapmsuFile', help = 'file of correspondance name between irgsp and msu annotation')
    filesreq.add_argument('-i', '--irgsp', metavar="<filename>",type=existant_file, required=True, dest = 'irgspFile', help = 'IRGSP gff annotation file')
    filesreq.add_argument('-m', '--msu', metavar="<filename>",type=existant_file, required=True, dest = 'msuFile', help = 'MSU gff annotation file')
    filesreq.add_argument('-o', '--output', metavar="<filename>", required=True, dest = 'outputFile', help = 'output name file')

    files = parser.add_argument_group('Input infos for running with default values')
    files.add_argument('-dp', '--drawparams', metavar="<filename>",type=existant_file, required=False, dest = 'drawparamsParam', help = 'Check your own drawparams file')
    files.add_argument('-co', '--color', metavar="<filename>",type=existant_file, required=False, dest = 'colorParam', help = 'File with colors (default 15 color max)')
    # Check parameters
    args = parser.parse_args()
    print (args)
    #Welcome message
    print("#################################################################")
    print("#           Welcome in %s (Version %s)            #" %(__file__, version))
    print("#################################################################")
    print('Start time: ', start_time,'\n')
    
    de = relativeToAbsolutePath(args.deFile)
    rapmsu = relativeToAbsolutePath(args.rapmsuFile)
    irgsp = relativeToAbsolutePath(args.irgspFile)
    msu = relativeToAbsolutePath(args.msuFile)
    outputName = relativeToAbsolutePath(args.outputFile)

    #parcours fichier DE
    fileDE = open (de, "r")
    with open(outputName, 'w', newline='') as csvfile:
        outwriter = csv.writer(csvfile, delimiter='\t', quoting=csv.QUOTE_MINIMAL)

        for line in fileDE:    
            #DBG::print ("---------------------------------------------------------------------------")
            cleanedline = cleaningLine(line,",")
            virginLine=cleanedline
            MSTRG,line = traitmentDE(cleanedline[0])
            #DBG:: print ("++++++++++++++++++++++++++++++", MSTRG, line, "LEN",len(line))       
            loc='ANYLOC'
            rap='ANYRAP'
            annotatI='ANYANNOTATION_IRGSP'
            annotatM='ANYANNOTATION_MSU'
            noduplic=[]
            
            #on ne traite pas les lines qui n'ont pas de LOC
            if len(line) != 0:
                #si on trouve des loc dans la line
                for loc in line:
                    results=[]
                    #et ils commencent pas LOC (probleme avec ChrSy.fgenesh.gene.22 par exemple)
                    if not loc.startswith("LOC"):
                        results.append('\t'.join(virginLine))
                        results.append(loc)
                        results.append(rap)
                        results.append(annotatI)
                        results.append(annotatM)
                        #verifier si pas de duplicats
                        if virginLine not in noduplic:
                            noduplic.append(virginLine)
                            #DBG:: print (loc,'\t',rap,'\t',annotatI,'\t',annotatM)
                            outwriter.writerow(results)
                    #si commencent par LOC on extrait l'annotation IRGSP et MSU
                    else:
                        loc = loc.strip("'").strip("[").strip("]")#chomp
                        rap = searchInRapMsu(loc)
                        annotatI=extractAnnotationFromFile(irgsp,rap,'I')
                        annotatM=extractAnnotationFromFile(msu,loc,'M')
                        results.append('\t'.join(virginLine))
                        results.append(loc)
                        results.append(rap)
                        results.append(annotatI)
                        results.append(annotatM)
                        #DBG:: print (loc,'\t',rap,'\t',annotatI,'\t',annotatM)
                        outwriter.writerow(results)
            #lignes sans loc MSTRG only
            else:
                results.append('\t'.join(virginLine))
                results.append(loc)
                results.append(rap)
                results.append(annotatI)
                results.append(annotatM)
                #DBG:: print (loc,'\t',rap,'\t',annotatI,'\t',annotatM)
                outwriter.writerow(results)
            results=[]
        results=[]
        
        #fermeture des fichiers    
    fileDE.close()
            
    print("\n\nExecution summary:")
    print("  - Outputting \n\- Files %s was created :" % outputName)

    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")