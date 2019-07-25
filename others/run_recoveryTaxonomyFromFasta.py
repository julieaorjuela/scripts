#!usr/bin/env python3
# -*- coding: utf-8 -*-

# Julie ORJUELA julie.orjuela@ird.fr
import sys , re , os , pprint , gzip, vcf, pysam, subprocess
import argparse 
from Bio import SeqIO

parser = argparse.ArgumentParser(prog= 'run_recoveryTaxonomyFromFasta.py' , description = '''run recoveryTaxonomyFromFasta.pl in qsub mode''')
parser.add_argument('-f' , '--fasta_path' , metavar="<pathway>" , dest = 'fasta_path' , help = 'Chemin du dossier contenant les fasta a formater')
parser.add_argument('-q' , '--qsubOptions' , metavar="<value>" , dest = 'qsubOptions' , help = 'qsub -q name (bioinfo), None by default', default=None)
arguments = parser.parse_args()

################################################################## Main ##############################################################"""
# recuperation des arguments
pathfasta = arguments.fasta_path	# nom de dossier des fasta
qsub=arguments.qsubOptions # qsub options given by user
pwd=os.getcwd()

# verifier si le chemin des arguments existent
if not (os.path.isdir(pathfasta)) :
	print ("Verifiez les arguments. -f est bien un dossier?")

# recovery absolute path to fastafiles
pathfastaAbsPath=os.path.abspath(pathfasta)

#le home sera le dossier ou se trouve le dossiers avec les fasta
home=pathfastaAbsPath

# recovey names of fasta files
fastaliste=[]
for files in os.listdir(pathfasta):
	if files.endswith(".fasta"):
		fastaliste.append(files)
#print (bamliste)

#liste of fasta
i=0
for fastaFile in fastaliste:
	fastaName="fastaFile_"+str(i)
	#print ("#####################################")
	print (fastaName)
	
	#on cree le sh pour le lancer sur un noeud
	qsubLigne="#$ -q "+qsub
	crunksFasta="#$ -N "+fastaName
	qsubFileName="./"+fastaName+"_job.sh" #nom fichier sh
	qsubFile = open(qsubFileName , 'w')
	
	#writing into qsub file
	qsubFile.write("#!/bin/bash\n")
	qsubFile.write(crunksFasta)
	qsubFile.write("\n")
	qsubFile.write("#$ -cwd\n")
	qsubFile.write("#$ -V\n")
	qsubFile.write("#$ -b yes\n")
	qsubFile.write(qsubLigne)
	qsubFile.write("\n")
	#qsubFile.write("module load system/python/3.6.0a3\n")
	#qsubFile.write("module load bioinfo/samtools/1.3.1\n")
	#qsubFile.write("module load bioinfo/bedtools/2.26.0\n")
	#qsubFile.write("\n")
	
	#transfer des fichiers bam et vcf correspondants au noeud en cours
	dossierScratch=str("/scratch/"+fastaName+"-$JOB_ID/")
	mkdircommande="mkdir -p "+dossierScratch+"\n"
	qsubFile.write(mkdircommande)
	
	# Transfert des données du home vers scratch
	gotoNoeudCommande="rsync -av nas:"+pathfastaAbsPath+"/"+fastaFile+" "+dossierScratch+"/\n"
	fastaFileInScratch=str(dossierScratch+"/"+fastaFile)
	fastaFileOutScratch=str(dossierScratch+"/"+fastaFile+"_rfd")
	qsubFile.write(gotoNoeudCommande)
		
	#on se prepare a lancer la recoveryReads sur le noeud
	cheminScript="perl recoveryTaxonomyFromFasta.pl"	
	runrecoveryTaxonomyFromFasta=cheminScript+" -i "+fastaFileInScratch+" -o "+fastaFileOutScratch+"\n" 
	qsubFile.write(runrecoveryTaxonomyFromFasta)
	#on repatrie les resultats sur le home (prope au fichier vcf splite	
	ifcommande="rsync -avr "+dossierScratch+" nas:"+home+";\n"
	qsubFile.write(ifcommande)
	#on nettoie /scratch/
	rmcommande="rm -rf "+dossierScratch+"\n"
	qsubFile.write(rmcommande)
	#close files bash
	qsubFile.close()
	#changing chmod access
	accessCommande="chmod 755 "+qsubFileName
	print (accessCommande)
	os.system(accessCommande)
	#run bash file in qsub
	bashCommande="qsub ./"+qsubFileName
	print (bashCommande)
	os.system(bashCommande)
	i=i+1
