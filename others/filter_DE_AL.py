#!/usr/local/bin/python3

## @author Anais Louis
## format from Sebastien Ravel
## modified by Julie Orjuela
## last : 23/07/2019
## IRD

##	Programme qui permet de filtrer des fichiers de DE en 
##	fonction d'une valeur de pvalue/padj de 0.01 et d'un
##	seuil de fold change (FC) de 2

"""
	-------------------------------------------------------------------

	Ce programme permet de filtrer des fichiers de DE en fonction d'une
	valeur de pvalue/padj de 0.01 et d'un seuil de fold change de 2
	par default si ces deux paramettres ne sont pas donées en entrée.

	-------------------------------------------------------------------

	Fonctionnement du programme :
		filter_DE.py -d directory_name -f log2FC -p padj

	-------------------------------------------------------------------

	Arguments :
		\-d     nom du dossier contenant les fichiers de DE
		\-f     nom du log2 foldchange dans les fichiers de DE
		\-p     colonne pvalue/padj/FDR/FWER dans les fichiers de DE
"""


##########################
######## Modules #########
##########################

import sys,re,pandas,os,csv
import numpy as np
import argparse
from time import localtime, strftime


##########################
## Fonction de filtrage ##
##########################

def filtrage(file,p,fc,out) :
	fc=float(fc)
	with open(file,"r") as f :
		df = pandas.read_csv(f, sep = ',')
		#print (df.padj)
		print(df.shape)
		
		#if (df.padj<=p) and ((df.log2FoldChange >=fc) or (df.log2FoldChange>=-fc))
		df2=df[df.padj<=0.01]
		print(df2.shape)
		
		## Filtre log2FC
		df3=df2.loc[(df.log2FoldChange>=fc) | (df.log2FoldChange<=-fc)]
		print(df3.shape)
		
		## Ecriture du nouveau fichier
		df3.to_csv(out, sep = ',', index=False)
		

##########################
########## MAIN ##########
##########################
start_time = strftime("%H:%M:%S", localtime())

## Arguments du programme
parser = argparse.ArgumentParser()
parser.add_argument("-d", metavar="<repertory>", dest = 'dir', required=True, help="directory name with DE files")
parser.add_argument("-f", metavar="<filename>", dest = 'foldC', help="log2fc name in the DE files")
parser.add_argument("-p", metavar="<filename>", dest = 'prob', help="padj/FWER/FDR/pvalue name in the DE files")
args = parser.parse_args()

dir = args.dir
fc = args.foldC
p = args.prob

if p is None:
	p=0.01
if fc is None:
	fc=2

print ("<<<<<<< padj and log2fc >>>>>", p, " ",fc)

## Changer de repertoire de travail pour le dossier contenant les fichiers de DE
wd=os.chdir(dir)

print("-------------------------------------")
print("Filtrage effectué pour les fichiers :")

## Liste les fichier de DE
list=os.popen("ls").readlines()
for file in list :
	## Suppression des \n à la fin de chaque fichiers
	file=file.strip()
	print(' -----> ',file)

	## Definition du nom de l'output
	#out=file.split('.')[0]+"_"+p+"0.01_FC2.csv"
	suffixe=f"_PADJ_{p}_FC_{fc}_FILTERED.csv"
	out = file.replace('.csv', suffixe)
	print (out)
	
	## Filtrage des fichiers
	filtrage(file,p,fc,out) 


## Message de fin d'exécution
print("-----------------------------------")
print('Start time : ',start_time)
print("Stop time  : ",strftime("%H:%M:%S", localtime()))
print("-----------------------------------")
