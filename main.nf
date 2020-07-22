/*
-------------------------
nextflow ont pipeline
-------------------------
A nextflow pipeline for processing raw Nanopore data 

Homepage: 
https://github.com/angelovangel/nxf-ont

Creator/Maintainer:
aangeloo@gmail.com
*/


/*
NXF ver 19.08+ needed because of the use of tuple instead of set
*/
if( !nextflow.version.matches('>=19.08') ) {
    println "This workflow requires Nextflow version 19.08 or greater and you are running version $nextflow.version"
    exit 1
}

/*
* ANSI escape codes to color output messages
*/
ANSI_GREEN = "\033[1;32m"
ANSI_RED = "\033[1;31m"
ANSI_RESET = "\033[0m"

/* 
 * pipeline input parameters 
 */

//Options: mandatory
params.input = false

// Options: guppy basecalling
params.input_path = false
params.flowcell = false
params.kit = false
params.barcode_kit = false
params.guppy_config = false
params.guppy_model = false

params.cpu_threads_per_caller = false
params.num_callers = false
params.config = false
//options: qc


/*
guppy basecalling
*/
if (!params.skip_basecalling && !params.skip_demultiplexing) {
  
  process guppy_basecaller {
    publisheDir path: "${params.outdir}", mode:'copy'

    input:
    file dir_fast5 from ch_fast5

    output:
    file "fastq/*.fastq" into ch_fastq

    script:
    flowcell = params.flowcell ? "--flowcell $params.flowcell" : ""
    kit = params.kit ? "--kits $params.kit" : ""
    barcode_kits = params.barcode_kits ? "--barcode_kits $params.barcode_kits" : ""
    config = params.config ? "--config $params.config" : ""
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""

    cpu_threads_per_caller = params.flowcell ? "--cpu_threads_per_caller $params.cpu_threads_per_caller" : "--cpu_threads_per_caller 2"
    num_callers = params.num_callers ? "--num_callers $params.num_callers" : "--num_callers 2"

    """
    guppy_basecaller 
      --input_path $input_path \\
      --save_path ./results-guppy_basecaller \\
      --recursive \\
      --records_per_fastq 0 \\
      $flowcell \\
      $kit \\
      $barcode_kits \\
      $trim_barcodes \\
      $cpu_threads_per_caller \\
      $num_callers \\
      --qscore_filtering \\
      $config \\
    """
  }
}

/*
guppy barcoder
*/
