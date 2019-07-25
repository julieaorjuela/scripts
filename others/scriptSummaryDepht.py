#!/usr/bin/python3.5
# -*- coding: utf-8 -*-
# @package scriptSummaryDepth.py
# @author Julie Orjuela

"""
    The scriptSummaryDepth script
    ==========================
    :author:  Julie Orjuela
    :contact: julie.orjuela@ird.fr
    :date: 28/10/2018
    :version: 0.1
    Script description
    ------------------
    scriptSummaryDepth sums the depth of a intervale given 
    -------
    >>> scriptSummaryDepth.py -i intervals.txt -d detphSamtoolsOut.txt -o summary.txt
    
    Help Programm
    -------------
    optional arguments:
        - \-h, --help
                        show this help message and exit
        - \-v, --version
                        display extractSeqFasta.py version number and exit
    Input mandatory infos for running:
        - \-i <filename>, --intervals <filename>
                        intervals fasta
        - \-d <filename>, --depth <filename>
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
VERSION_DATE='28/10/2018'
debug="False"
#debug="True"


##################################################
## Functions
##################################################
def checkParameters (arg_list):
    # Check input related options
    if (not arg_list.intervalsFile and not arg_list.depthFile):
        print ('Error: No input file defined via option -i/--intervals or -d/--depth !' + "\n")
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
    parser = argparse.ArgumentParser(prog='scriptSummaryDepth.py', description='''This Programme simplifies fasta header and adds annotation from a trinonate report''')
    parser.add_argument('-v', '--version', action='version', version='You are using %(prog)s version: ' + version, help=\
                        'display scriptSummaryDepth.py version number and exit')
    filesreq = parser.add_argument_group('Input mandatory infos for running')
    filesreq.add_argument('-i', '--intervals', metavar="<filename>", required=True, dest = 'intervalsFile', help = 'fasta file')
    filesreq.add_argument('-d', '--depth', metavar="<filename>", required=True, dest = 'depthFile', help = 'trinonate report file with annotation')
    filesreq.add_argument('-o', '--out', metavar="<filename>", required=True, dest = 'paramoutfile', help = 'Name of output file')

    # Check parameters
    args = parser.parse_args()
    checkParameters(args)

    #Welcome message
    print("#################################################################")
    print("#        Welcome in scriptSummaryDepth (Version " + version + ")          #")
    print("#################################################################")
    print('Start time: ', start_time,'\n')

    # Recupere le fichier de conf passer en argument
    intervalsFile = relativeToAbsolutePath(args.intervalsFile)
    outputfilename = relativeToAbsolutePath(args.paramoutfile)
    depthFile = relativeToAbsolutePath(args.depthFile)
    
    print (intervalsFile, outputfilename, depthFile)
            
    # split depth by intervals
    intervalsHandle = open(intervalsFile, "r")
    for line in intervalsHandle:
        intLine=line.strip()
        lineFromIntFile=intLine.split("\t")
        otherName=lineFromIntFile[0]
        contigIdInt=lineFromIntFile[1]
        startInt=lineFromIntFile[2]
        stopInt=lineFromIntFile[3]
        print ("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++==")
        print ("                                 ",otherName,contigIdInt,startInt,stopInt, "                        ")
        print ("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++==")
        
        #extract rows on interval
        linesOnIntervale=[]
        depthHandle = open(depthFile, "r")
        for line in depthHandle:
            depthLine=line.strip()
            lineFromDepthFile=depthLine.split("\t")
            contigIdDepth=lineFromDepthFile[0]
            positionInContigDepth=int(lineFromDepthFile[1])
            #print ("contigname",contigIdInt,contigIdDepth,"startvspos", startInt, positionInContigDepth, "stopvspos",stopInt,positionInContigDepth)
            if contigIdInt==contigIdDepth and int(startInt)<=positionInContigDepth and int(stopInt)>=positionInContigDepth :
                #print ("contigname",contigIdInt,contigIdDepth,"startvspos", startInt, positionInContigDepth, "stopvspos",stopInt,positionInContigDepth)
                #lignes correspondants a lintervale, je les stock puis on les donne a un dataframe
                intName=str(otherName+'_'+contigIdInt+'_'+startInt+'_'+stopInt)
                fileName=str(contigIdInt+'_'+startInt+'_'+stopInt)
                nameOutput=fileName+"_out.csv"
                lineFromDepthFile.append(intName)
                linesOnIntervale.append(lineFromDepthFile)     
        #print (linesOnIntervale)
        
        df = pd.DataFrame(linesOnIntervale)
        #print (df)
        #print (df.dtypes)
        if len(linesOnIntervale)>0:
            #df.loc['sum'] = df.sum()
            #print (df)
            i=2
            while i<=59:       
                df[i] = pd.to_numeric(df[i])
                i=i+1
            nameRow=intName+"_sum"
            df.loc[nameRow] = df.sum()
            nameRow=intName+"_mean"
            df.loc[nameRow] = df.mean()
            nameRow=intName+"_min"
            df.loc[nameRow] = df.min()
            nameRow=intName+"_max"
            df.loc[nameRow] = df.max()
            df.to_csv(nameOutput)
            #outputhandle = open(outputfilename, "w")
            #print (df.dtypes)
            #print (df[9])
             
    #closing files
    depthHandle.close()
    intervalsHandle.close()      

            
   

    print("\nStop time: ", strftime("%d-%m-%Y_%H:%M:%S", localtime()))
    print("#################################################################")
    print("#                        End of execution                       #")
    print("#################################################################")

