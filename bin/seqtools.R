#!/usr/bin/env Rscript
#============
#
# use seqTools to get fastq files statistics, much faster than seqkit
#
#============
require(seqTools)
# require(writexl)
# require(rmarkdown)
# require(knitr)
# require(kableExtra)
# require(dplyr)
# args are individual fastq.gz files
# output is a csv and a xlxs with qc data per fastq file

# AUX FUNCTIONS
#=======================================================================
# aux function needed for calc Q20% and Q30%
# phredDist from seqTools returns the phred score distribution, 
# so to get Q20% use get_q(qq, 21) because the vector is zero-based
# get_q <- function(qqobj, q) {
# 	round( sum( phredDist(qqobj)[q:length(phredDist(qqobj))] ) * 100, digits = 2)
# }
# 
# # aux function to get N50 or Nx from the qq object
# # n is 0.5 for N50 etc...
# get_nx <- function(qqobj, n) {
# 	slc <- seqLenCount(qqobj)
# 	
# 	# get a vector with read lengths from seq len counts
# 	v <- rep.int(1:length(slc), times = c(slc))
# 	
# 	# and the nice algo for N50
# 	v.sorted <- rev(sort(v))
# 	return(list(
# 		sum_len = sum(v),
# 		nx = v.sorted[cumsum(v.sorted) >= sum(v.sorted) * n][1]
# 	))
# 	
# }
#=======================================================================

args <- commandArgs(trailingOnly = T)

# qq <- fastqq(args, k = 2)
# 
# df <-	data.frame(
# 			file = basename(qq@filenames),
# 			num_seqs = qq@nReads,
# 			sum_len = sapply(1:qq@nFiles, function(x) { get_nx(qq[x], 0.5)$sum_len } ), # total nucleotides
# 			min_len = seqLen(qq)[1, ],
# 			max_len = seqLen(qq)[2, ], 
# 			n50 = sapply(1:qq@nFiles, function(x) { get_nx(qq[x], 0.5)$nx } ),
# 			q20_percent = sapply(1:qq@nFiles, function(x) { get_q(qq[x], 21) } ),
# 			q30_percent = sapply(1:qq@nFiles, function(x) { get_q(qq[x], 31) } ),
# 			row.names = NULL
# 			)
# 
# write.csv(df, file = "fastq-stats.csv", row.names = FALSE)
# write_xlsx(df, "fastq-stats.xlsx", format_headers = TRUE, col_names = TRUE)
# # save the fastqq object to use in the rmarkdown
# saveRDS(qq, file = "qq.rds")

#==========================================================================
# render the rmarkdown, using fastq-report.Rmd as template
#==========================================================================

# then render
rmarkdown::render(input = "fastq-stats-report.Rmd", 
									output_file = "fastq-stats-report.html", 
									output_dir = getwd(), # important when knitting in docker 
									knit_root_dir = getwd(), # important when knitting in docker 
									params = list(fqfiles = args))
# this solved the seqfault error
# https://github.com/cgpu/gel-gwas/commit/2c5a4e5e216478c4a0cbe869c8b4e437b333b787#diff-3254677a7917c6c01f55212f86c57fbf
