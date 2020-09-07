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

#AUX FUNCTIONS
#=======================================================================
# aux function needed for calc Q20% and Q30%
# phredDist from seqTools returns the phred score distribution, 
# so to get Q20% use get_q(qq, 21) --> zero-based vector
get_q <- function(qqobj, q) {
	sum( phredDist(qqobj)[q:length(phredDist(qqobj))] ) * 100
}

# aux function to get N50 or Nx from the qq object
# n is 0.5 for N50 etc...
get_nx <- function(qqobj, n) {
	slc <- seqLenCount(qqobj)
	
	# get a vector with read lengths from seq len counts
	v <- rep.int(1:length(slc), times = c(slc))
	
	# and the nice algo for N50
	v.sorted <- rev(sort(v))
	return(list(
		sum_len = sum(v),
		nx = v.sorted[cumsum(v.sorted) >= sum(v.sorted) * n][1]
	))
	
}
#=======================================================================

args <- commandArgs(trailingOnly = T)

qq <- fastqq(args, k = 2)

df <-	data.frame(
			file = basename(qq@filenames),
			num_seqs = qq@nReads,
			sum_len = sapply(1:qq@nFiles, function(x) { get_nx(qq[x], 0.5)$sum_len } ), # total nucleotides
			min_len = seqLen(qq)[1, ],
			max_len = seqLen(qq)[2, ], 
			n50 = sapply(1:qq@nFiles, function(x) { get_nx(qq[x], 0.5)$nx } ),
			q20_percent = sapply(1:qq@nFiles, function(x) { get_q(qq[x], 21) } ),
			q30_percent = sapply(1:qq@nFiles, function(x) { get_q(qq[x], 31) } ),
			row.names = NULL
			)
write.csv(df, file = "fastq-stats.csv", row.names = FALSE)
write_xlsx(df, "fastq-stats.xlsx", format_headers = TRUE, col_names = TRUE)

