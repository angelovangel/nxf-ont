#!/usr/bin/env Rscript
#============
#
# use seqTools to get fastq files statistics, much faster than seqkit
#
#============
require(seqTools)

args <- commandArgs()
file <- args[1]