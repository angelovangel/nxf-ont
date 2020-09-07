#!/usr/bin/env Rscript
#============
#
# make a nice formatted table from the seqkit stats output
#
#============
require(DT)

args <- commandArgs()
file <- args[1]

