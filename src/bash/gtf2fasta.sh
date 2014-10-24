#!/bin/bash

<<authors
*****************************************************************************
	
	gtf2fasta.sh
	
	This file is part of the ChimPipe pipeline 

	Copyright (c) 2014 Bernardo Rodríguez-Martín 
					   Emilio Palumbo 
					   Sarah Djebali 
	
	Computational Biology of RNA Processing group
	Department of Bioinformatics and Genomics
	Centre for Genomic Regulation (CRG)
					   
	Github repository - https://github.com/Chimera-tools/ChimPipe
	
	Documentation - https://chimpipe.readthedocs.org/

	Contact - chimpipe.pipeline@gmail.com
	
	Licenced under the GNU General Public License 3.0 license.
******************************************************************************
authors

# Takes as input an annotation file in gtf format with gene id followed by transcript id in the 9th field
# as well as a genome index file in gem format, and outputs a fasta file with the nucleotide sequences
# of all the transcripts present in the annotation file

# Usage
# gtf2fasta.sh annot.gtf genome_index.gem

# Example
# cd /users/rg/projects/encode/scaling_up/whole_genome/Gencode/version10/seq
# annot=/users/rg/projects/encode/scaling_up/whole_genome/Gencode/version10/gen10.gtf
# genome=/users/rg/projects/references/Genome/gem2/Homo_sapiens.GRCh37.chromosomes.chr.M.fa.gem
# time gtf2fasta.sh $annot $genome 2> gtf2fasta.err > gtf2fasta.out
# real	3m18.403s 

function usage
{
cat <<help
	Usage:    gtf2fasta.sh annot.gtf genome_index.gem 
    
    Example:  gtf2fasta.sh gen10.long.exon.gtf hg19.gem
    
    Takes as input an annotation file in gtf format with gene id followed by transcript id in the 9th field
    as well as a genome index file in gem format, and outputs a fasta file with the nucleotide sequences
    of all the transcripts present in the annotation file
    exit 0
help
}

# GETTING INPUT ARGUMENTS 
#########################
annot=$1
genome=$2

# SETTING VARIABLES AND INPUT FILES
###################################
if [[ ! -e $annot ]]; then printf "\n\tERROR: Please specify a valid annotation file\n\n" >&2; usage; exit -1; fi
if [[ ! -e $genome ]]; then printf "\n\tERROR:Please specify a valid genome gem genome index file\n\n" >&2; usage; exit -1; fi

# Directories 
#############
# Environmental variables 
# rootDir - path to the root folder of ChimPipe pipeline. 
# TMPDIR  - temporary directory
# They are environmental variable defined and exported in the main script
 
binDir=$rootDir/bin
awkDir=$rootDir/src/awk
bashDir=$rootDir/src/bash

# Programs
##########
RETRIEVER=$binDir/gemtools-1.7.1-i3/gem-retriever 

# START
########

# Variable from input
#####################
b=`basename $annot`
b2tmp=${b%.gtf}
b2=${b2tmp%.gff}



# Make the list of distinct exon coordinates (fast)
###################################################
echo I am making the list of distinct exon coordinates >&2
awk 'BEGIN{OFS="\t"} $3=="exon"{print $1, $7, $4, $5}' $annot | sort | uniq > $b2\_distinct_exon_coord.tsv 
echo done >&2
# chr10	+	100003848	100004106
# 518897 (4 fields)


# Retrieve the exon sequences (less than 2 minutes)
###################################################
echo I am retrieving the exon sequences >&2
cat $b2\_distinct_exon_coord.tsv | $RETRIEVER $genome > $b2\_distinct_exon_coord.seq
echo done >&2
# AGAGAAAGCGGTTGGAAGCCAAGCAACGGGAAGACATCTGGGAAGGCAGAGACCAGTCTACAGTTTGAACATCACTCAATGAAAGGGATAATTCCATGAATCAGAAAATGTTTCCATAGCCTTCAGATAAGATGATCCTTCCAGAGCTCTATGTACATGCAGATGTGCATGTTAAAGAGATAAAGTGATCGAGACAAGGACTGACTGGGTATAGAAGGAAGACAGACTCCTGTCTTCACTCCTAAATGCAGTTCTTTGG
# 518897 (1 fields)

# Make a file that both has the exon coordinates and sequence (quite fast)
##########################################################################
echo I am making a file that both has the exon coordinates and sequence >&2
paste $b2\_distinct_exon_coord.tsv $b2\_distinct_exon_coord.seq | awk '{print $1"_"$3"_"$4"_"$2, $5}' > $b2\_distinct_exon_coord_seq.txt
echo done >&2
# chr10_100003848_100004106_+ AGAGAAAGCGGTTGGAAGCCAAGCAACGGGAAGACATCTGGGAAGGCAGAGACCAGTCTACAGTTTGAACATCACTCAATGAAAGGGATAATTCCATGAATCAGAAAATGTTTCCATAGCCTTCAGATAAGATGATCCTTCCAGAGCTCTATGTACATGCAGATGTGCATGTTAAAGAGATAAAGTGATCGAGACAAGGACTGACTGGGTATAGAAGGAAGACAGACTCCTGTCTTCACTCCTAAATGCAGTTCTTTGG
# 518897 (2 fields)


# For each transcript make a list of exon coordinates from 5' to 3' (a bit slow)
################################################################################
echo For each transcript I am making a list of exon coordinates from 5\' to 3\' >&2
awk '$3=="exon"' $annot | sort -k12,12 -k4,4n -k5,5n | awk '{nbex[$12]++; strand[$12]=$7; ex[$12,nbex[$12]]=$1"_"$4"_"$5"_"$7}END{for(t in nbex){s=""; split(t,a,"\""); if(strand[t]=="+"){for(i=1; i<=nbex[t]; i++){s=(s)(ex[t,i])(",")}} else{if(strand[t]=="-"){for(i=nbex[t]; i>=1; i--){s=(s)(ex[t,i])(",")}}} print a[2], s}}' > $b2\_trid_exonlist_5pto3p.txt
echo done >&2
# ENST00000556118.1 chr15_91573118_91573226_+,
# 173599 (2 fields)


# For each transcript make its sequence by concatenating the sequences of its exons from 5' to 3' (15 seconds)
##############################################################################################################
echo For each transcript I am making its sequence by concatenating the sequences of its exons from 5\' to 3\'  >&2
awk -v fileRef=$b2\_distinct_exon_coord_seq.txt 'BEGIN{while (getline < fileRef >0){seqex[$1]=$2}} {split($2,a,","); k=1; while(a[k]!=""){seqtr[$1]=(seqtr[$1])(seqex[a[k]]); k++}} END{for(t in seqtr){s=seqtr[t]; print ">"t; n=length(s); n2=int(n/60); for(i=0; i<=(n2-1); i++){print substr(s,i*60+1,60)} if(n>n2*60){print substr(s,n2*60+1,n-n2*60)}}}' $b2\_trid_exonlist_5pto3p.txt > $b2\_tr.fasta
echo done >&2


# Clean
#######
echo I am cleaning >&2
rm $b2\_distinct_exon_coord.tsv $b2\_distinct_exon_coord.seq 
rm $b2\_distinct_exon_coord_seq.txt $b2\_trid_exonlist_5pto3p.txt
echo done >&2