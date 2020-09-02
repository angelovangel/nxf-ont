# nxf-ont

A nextflow pipeline for processing raw Nanopore data. 

## About

nxf-ont is a bioinformatics pipeline that can be used to perform basecalling, demultiplexing and QC of Nanopore DNA/RNA raw sequencing data. It is built with [Nextflow](https://www.nextflow.io/) and runs in a docker container by default, so only Nextflow and docker are needed to run it.

## Usage

A typical command for running the pipeline is:

```bash
nextflow run angelovangel/nxf-ont \
--input /path/to/fast5/files \
--flowcell FLO-PRO001 \
--kit SQK-LSK109 \
--barcode_kit EXP-NBD104 \
-profile docker
```
