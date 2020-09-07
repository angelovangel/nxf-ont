#!/usr/bin/env Rscript
#============
#
# use seqTools to get fastq files statistics, much faster than seqkit
#
#============
require(seqTools)
require(writexl)
# args are individual fastq.gz files
# output is a csv and a xlxs with qc data per fastq file

args <- commandArgs(trailingOnly = T)

qq <- fastqq(args, k = 2)

df <-	data.frame(
			file = basename(qq@filenames),
			num_seqs = qq@nReads,
			min_len = seqLen(qq)[1, ],
			max_len = seqLen(qq)[2, ], 
			row.names = NULL
			)
write.csv(df, file = "fastq-stats.csv", row.names = FALSE)
write_xlsx(df, "fastq-stats.xlsx", format_headers = TRUE, col_names = TRUE)

