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

//ch_input_files = params.input ? Channel.fromPath( params.input ) : Channel.empty()
//ch_input_csv = params.csv ? Channel.fromPath( params.csv, checkIfExists: true ) : Channel.empty()

/*
if ( params.csv ) { 
  ch_input_csv = Channel.fromPath( params.csv, checkIfExists: true )
} else { 
  ch_input_csv = Channel.empty()
}
*/
//ch_input_csv = Channel.fromPath( params.csv )
//options: qc

def helpMessage() {

  log.info"""
  
    Usage:

    The typical command for running the pipeline is as follows:

      nextflow run angelovangel/nxf-ont \\
          --input /path/to/fast5/files/ \\
          --flowcell FLO-PRO001 \\
          --kit SQK-LSK109 \\
          --barcode_kit EXP-NBD104 \\
          -profile docker
  
    Mandatory arguments
        --input [dir]                   The directory contains raw FAST5 files.
        --csv [file]                    Comma-separated file containing pairs of sample names and barcodes.
        --cpus [int]                    Number of threads used for pipeline (default: 4)
        -profile [str]                  Configuration profile to use. 
                                        Available: docker.
  
    Basecalling/Demultiplexing
        --flowcell [str]                Flowcell used to perform the sequencing e.g. FLO-MIN106. 
                                        Not required if '--config' is specified.
        --kit [str]                     Kit used to perform the sequencing e.g. SQK-LSK109. 
                                        Not required if '--config' is specified.
        --barcode_kit [str]             Barcode kit used to perform the sequencing e.g. SQK-PBK004. 
                                        Not required if '--skip_demultiplexing' is specified.
        --trim_barcodes [bool]          Trim the barcodes from the output sequencesin the FastQ files (default: false).
        --config [file/str]             Guppy config file used for basecalling e.g. dna_r9.4.1_450bps_fast.cfg. 
                                        Cannot be used in conjunction with '--flowcell' and '--kit'.
        --cpu_threads_per_caller [int]  Number of threads used for guppy_basecaller (default: 2, overwritten by '--cpus' if it is specified).
        --num_callers [int]             Number of callers used for guppy_basecaller (default: 1).
        --skip_basecalling [bool]       Skip basecalling with guppy_basecaller (default: false)
        --skip_demultiplexing [bool]    Skip demultiplexing with guppy_barcoder (default: false)

    Adapter trimming
        --skip_porechop [bool]          Skip adapter trimming with porechop 
                                        (default: false, if '--skip_demultiplexing' is specified, adapter trimming will also be skipped.)
  
    Other
        --help                          Show this help message and exit.
  
  """.stripIndent()
}


if ( params.help ) {
  helpMessage()
  exit 0
}

ch_input_files = params.input ? Channel.fromPath( params.input ) : Channel.empty()
ch_input_csv = params.csv ? Channel.fromPath( params.csv, checkIfExists: true ) : Channel.empty()

if ( params.flowcell && !params.kit ) { 
  exit 1, "Error: no valid kit found."  
}

if ( params.kit && !params.flowcell ) { 
  exit 1, "Error: no valid flowcell found."  
} 

/*
guppy basecalling
*/
if ( !params.skip_basecalling ) {
  
  process guppy_basecaller {
    publishDir path: params.barcode_kits ? "${params.outdir}/barcodes" : "${params.outdir}/basecalled", mode:'copy'
    
    input:
    file dir_fast5 from ch_input_files
    file csv_file from ch_input_csv.ifEmpty([])

    output:
    file "fastq/*.fastq.gz" into ch_fastq, ch_for_seqkit
    file "guppy_basecaller.log" into ch_log_guppy_basecaller
    file "rename.log" optional true into ch_log_rename
    file "results-guppy-basecaller/*.txt" into ch_summary_guppy

    script:
    flowcell = params.flowcell ? "--flowcell $params.flowcell" : ""
    kit = params.kit ? "--kits $params.kit" : ""
    barcode_kits = params.barcode_kits ? "--barcode_kits $params.barcode_kits" : ""
    config = params.config ? "--config $params.config" : ""
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""

    cpu_threads_per_caller = params.cpus ?  "--cpu_threads_per_caller $params.cpus" : "--cpu_threads_per_caller $params.cpu_threads_per_caller"
    //num_callers = "--num_callers $params.num_callers"

    """
    guppy_basecaller \\
      --input_path $dir_fast5 \\
      --save_path ./results-guppy-basecaller \\
      --recursive \\
      --records_per_fastq 0 \\
      $flowcell \\
      $kit \\
      $barcode_kits \\
      $trim_barcodes \\
      $cpu_threads_per_caller \\
      --num_callers $params.num_callers \\
      --qscore_filtering \\
      $config \\
      --compress_fastq \\
      &> guppy_basecaller.log 

    mkdir fastq
    cd results-guppy-basecaller/pass
    if [ "\$(find . -type d -name "barcode*" )" != "" ]
    then
      for dir in barcode*/
      do
        dir=\${dir%*/}
        cat \$dir/*.fastq.gz > ../../fastq/\$dir.fastq.gz
      done
    else
      cat *.fastq.gz > ../../fastq/unclassified.fastq.gz
    fi

    if [ ! -z "$params.csv" ] && [ ! -z "$barcode_kits" ]
    then
      while IFS=, read -r ob nb
      do
        echo rename \$ob.fastq.gz to \$nb.fastq.gz &>> ../../rename.log
        mv ../../fastq/\$ob.fastq.gz ../../fastq/\$nb.fastq.gz
      done < ../../$csv_file
    fi
    """
  }
} else if ( params.skip_basecalling && ! params.skip_demultiplexing && params.barcode_kits ) {
  
  process guppy_barcoder {
    publishDir path: "${params.outdir}/barcodes", mode:'copy'

    input:
    file basecalled_files from ch_input_files
    file csv_file from ch_input_csv.ifEmpty([])

    output:
    file "fastq/*.fastq.gz" into ch_fastq, ch_for_seqkit
    file "guppy_barcoder.log" into ch_log_guppy_barcoder
    file "rename.log" optional true into ch_log_rename
    file "results-guppy-barcoder/*.txt" into ch_summary_guppy

    script:
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""
    //worker_threads = params.cpus ? "--worker_threads $params.cpus" : "--worker_threads 4"

    """
    guppy_barcoder \\
      --input_path $basecalled_files \\
      --save_path ./results-guppy-barcoder \\
      --recursive \\
      --records_per_fastq 0 \\
      --compress_fastq \\
      --barcode_kits $params.barcode_kits \\
      $trim_barcodes \\
      --worker_threads $params.cpus \\
      &> guppy_barcoder.log

    mkdir fastq
    cd results-guppy-barcoder
    if [ "\$(find . -type d -name "barcode*" )" != "" ]
    then
      for dir in barcode*/
      do
        dir=\${dir%*/}
        cat \$dir/*.fastq.gz > ../fastq/\$dir.fastq.gz
      done
    else
      cat *.fastq.gz > ../fastq/unclassified.fastq.gz
    fi

    if [ ! -z "$params.csv" ]
    then
      while IFS=, read -r ob nb
      do
        echo rename \$ob.fastq.gz to \$nb.fastq.gz &>> ../../rename.log
        mv ../fastq/\$ob.fastq.gz ../fastq/\$nb.fastq.gz
      done < ../$csv_file
    fi
    """
  }
}

process porechop {
  publishDir path: "${params.outdir}/porechop", mode:'copy'

  input:
  file fastq_file from ch_fastq.collect()

  output:
  file "trimmed*.fastq.gz" into ch_porechop
  file "logs/trimmed*.log" into ch_log_porechop

  when:
  !params.skip_porechop && !params.skip_demultiplexing

  script:
  threads = params.cpus ? "--threads $params.cpus" : "--threads 4"
  """
  mkdir logs
  porechop \\
    --input $fastq_file \\
    --output trimmed_$fastq_file \\
    $threads \\
    --no_split \\
    &> logs/trimmed_"${fastq_file.simpleName}".log
  """
}

process pycoqc {
  publishDir path: "${params.outdir}/pycoqc", mode:'copy'
  
  input:
  file summary_file from ch_summary_guppy

  output:
  file "pycoQC.html"

  script:
  """
  pycoQC --summary_file $summary_file \\
    --html_outfile pycoQC.html
  """
}

process seqkit {
  publishDir path: "${params.outdir}/seqkit", mode:'copy'

  input:
  file fastq_file from !params.skip_porechop && !params.skip_demultiplexing ? ch_porechop.collect() : ch_for_seqkit.collect()

  output:
  file "seqkit.txt"

  script:
  """
  seqkit stats $fastq_file > seqkit.txt
  """
}
