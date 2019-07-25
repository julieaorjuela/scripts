#Auteur: Julie Orjuela - IRD
#Date: 27 juin 2019
#script bash qui pour chaque bam dans le dossier $PWD ajoute le RG au fichier bam qui sort de CRAC.
#le RG devient ici le nom du fichier
# TODO : voir pourquoi ne marche pas la commande tr avec les \\t 

for bam in *.bam
	do
		#echo ${bam};
		#relative to absolute path
		absolute="$(cd "$(dirname $bam)"; pwd)/$(basename $bam)"
		#preparing names of files and RG name variables
		nameBam=$(basename ${bam})		
		header="${nameBam/.bam/.bam.header}"
		SM="${nameBam/.bam/}"
		fixed="${nameBam/.bam/.fixedheader.bam}"		
		
		# recovery header with samtools
		samtools view -H ${bam} > ${header}
		
		# modifying @RG line to correct it
		OLD_RG=$(grep ^'@RG' ${header})
		#echo "OLD_RG=${OLD_RG}"
		
		# decomposition en variables (tr "\t" "\\t" marche pas)
		one=$(echo ${OLD_RG} | cut -d$' ' -f1)
		two=$(echo ${OLD_RG} | cut -d$' ' -f2)
		tres=$(echo ${OLD_RG} |cut -d$' ' -f3)
		
		#reconstruction of OLD_RG line
		OLD_RG2=$one"\\t"$two"\\t"$tres
		#echo "OLD_RG2= ${OLD_RG2}"
		
		#reconstruction of NEW_RG line
		NEW_RG="${OLD_RG2}\tLB:L001\tPL:ILLUMINA\tPU:unit1\tSM:${SM}";
		#echo "NEW_RG= ${NEW_RG}";
		
		#remplacing old by nex RG in header
		sed -i s/${OLD_RG2}/${NEW_RG}/ ${header}
		
		# obtaining fixed headers bams
		samtools reheader ${header} ${bam} > ${fixed}
		
		# removing intermediate header
		rm ${header}
	done;



