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
params.outdir = "./results"
params.csv = false

// Options: guppy basecalling
params.skip_basecalling = false
params.skip_demultiplexing = false

//params.input_path = false
params.flowcell = false
params.kit = false
params.barcode_kits = false
params.guppy_config = false
//params.guppy_model = false

params.cpu_threads_per_caller = false
params.num_callers = false
params.config = false
params.trim_barcodes = false

ch_input_files = Channel.fromPath( params.input )
ch_input_csv = params.csv ? Channel.fromPath( params.csv, checkIfExists: true ) : Channel.empty()
//options: qc


/*
guppy basecalling
*/
if ( !params.skip_basecalling ) {
  
  process guppy_basecaller {
    publishDir path: params.barcode_kits ? "${params.outdir}/barcodes" : "${params.outdir}/basecalled", mode:'copy'

    input:
    file dir_fast5 from ch_input_files

    output:
    file "fastq/*.fastq.gz" into ch_fastq

    script:
    flowcell = params.flowcell ? "--flowcell $params.flowcell" : ""
    kit = params.kit ? "--kits $params.kit" : ""
    barcode_kits = params.barcode_kits ? "--barcode_kits $params.barcode_kits" : ""
    config = params.config ? "--config $params.config" : ""
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""

    cpu_threads_per_caller = params.cpu_threads_per_caller ? "--cpu_threads_per_caller $params.cpu_threads_per_caller" : "--cpu_threads_per_caller 2"
    num_callers = params.num_callers ? "--num_callers $params.num_callers" : "--num_callers 2"

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
      $num_callers \\
      --qscore_filtering \\
      $config \\
      --compress_fastq \\

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
    """
  }
} else if ( params.skip_basecalling && ! params.skip_demultiplexing && params.barcode_kits ) {
  
  process guppy_barcoder {
    publishDir path: "${params.outdir}/barcodes", mode:'copy'

    input:
    file basecalled_files from ch_input_files

    output:
    file "fastq/*.fastq.gz" into ch_fastq
    file csv_file from ch_input_csv

    script:
    //input_path = params.skip_basecalling ? params.input_path : basecalled_files
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""
    work_threads = params.cpus ? "--work_threads $params.cpus" : "--work_threads 4"

    """
    guppy_barcoder \\
      --input_path $basecalled_files \\
      --save_path ./results-guppy-barcoder \\
      --recursive \\
      --records_per_fastq 0 \\
      --compress_fastq \\
      --barcode_kits $params.barcode_kits \\
      $trim_barcodes \\
      $work_threads \\

    mkdir fastq1
    mkdir fastq
    cd results-guppy-barcoder
    if [ "\$(find . -type d -name "barcode*" )" != "" ]
    then
      for dir in barcode*/
      do
        dir=\${dir%*/}
        cat \$dir/*.fastq.gz > ../fastq1/\$dir.fastq.gz
      done
    else
      cat *.fastq.gz > ../fastq1/unclassified.fastq.gz
    fi

    #if [ ${params.csv} ] 
    #then
      while IFS=, read -r ob nb
      do
        mv ../fastq1/\$ob.fastq.gz ../fastq/\$nb.fastq.gz
      done < $csv_file
    #fi
    """
  }
}


/*
process rename_barcodes {
  publishDir path: "${params.outdir}/rename_barcodes", mode:'copy'

  input:
  file fastq_files from ch_fastq
  file csv_file from ch_input_csv

  output:
  file "test.txt" into ch_renamed_fastq
  
  when:
  params.csv

  script:
  """
  while IFS=, read -r ob nb
  do
    echo $fastq_files >> test.txt
    echo "\$ob and \$nb" >> test.txt
  done < $csv_file
  """
}
*/



/*
guppy barcoder
*/