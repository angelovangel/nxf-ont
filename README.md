# nxf-ont
A nextflow pipeline for processing raw Nanopore data 

## working scheme

- input - folder with fast5 or basecalled ONT fastq files - also check extensions of files found
- optional input - csv file for matching barcode names to sample names
- guppy_barcode to demultiplex - option to provide barcoding kit. Output - one fastq file per barcode
- optional rename fastq files to sample names, e.g. barcode01.fastq to sample1.fastq
- porechop to trim adapters --> publish log
- seqkit to filter reads with qscore > 7 (if not done already by basecaller) --> output fastq files are published
- pycoQC or/and other QCs --> publish html report
- seqkit stats + seqkit fx2tab to get read length and read qual for each read --> publish statistics as csv
- R script to make some nice plots from the previous step --> publish plots
