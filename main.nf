/*
-------------------------
nextflow ont pipeline
-------------------------
A nextflow pipeline for processing raw Nanopore data 

Homepage: 
https://github.com/angelovangel/nxf-ont

Creator/Maintainer:
aangeloo@gmail.com
ifreicn@gmail.com
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

def helpMessage() {

  log.info"""
==================
  N X F - O N T
==================
A simple nextflow pipeline for processing raw Nanopore data
  
USAGE:

A typical command for running the pipeline is as follows:

nextflow run angelovangel/nxf-ont \
--input /path/to/fast5/files/ \
--flowcell FLO-PRO001 \
--kit SQK-LSK109 \
--barcode_kit EXP-NBD104 \
-profile docker
  
Mandatory arguments
  --input [dir]                   The directory contains raw FAST5 files.
  --csv [file]                    Comma-separated file containing pairs of sample names and barcodes. Only required for renaming.
  --cpus [int]                    Number of threads used for pipeline (default: 4)
  -profile [str]                  Configuration profile to use, available: docker.
  
Basecalling/Demultiplexing
  --flowcell [str]                Flowcell used to perform the sequencing e.g. FLO-MIN106. 
                                  Not required if '--config' is specified.
  --kit [str]                     Kit used to perform the sequencing e.g. SQK-LSK109. 
                                  Not required if '--config' is specified.
  --barcode_kits [str]            Space separated list of barcoding kit(s) or
                                  expansion kit(s) to detect against. Must be in double quotes. 
                                  Not required if '--skip_demultiplexing' is specified.
  --trim_barcodes [bool]          Trim the barcodes from the output sequencesin the FastQ files (default: false).
  --config [file/str]             Guppy config file used for basecalling e.g. dna_r9.4.1_450bps_fast.cfg. 
                                  Cannot be used in conjunction with '--flowcell' and '--kit'.
  --cpu_threads_per_caller [int]  Number of threads used for guppy_basecaller (default: 2, will overwrite '--cpus').
  --num_callers [int]             Number of callers used for guppy_basecaller (default: 1).
  --skip_basecalling [bool]       Skip basecalling with guppy_basecaller (default: false)
  --skip_demultiplexing [bool]    Skip demultiplexing with guppy_barcoder (default: false)

Adapter trimming
  --skip_porechop [bool]          Skip adapter trimming with porechop 
                                  (default: false, if '--skip_demultiplexing' is specified, adapter trimming will also be skipped.)
  
Other arguments
  --help                          Show this help message and exit.
  
""".stripIndent()
}

if ( params.help ) {
  helpMessage()
  exit 0
}

//ch_input_files = params.input ? Channel.fromPath( params.input ) : Channel.empty()
ch_input_csv = params.csv ? Channel.fromPath( params.csv, checkIfExists: true ) : Channel.empty()

if ( params.flowcell && !params.kit ) { 
  exit 1, "Error: no valid kit found."  
}

if ( params.kit && !params.flowcell ) { 
  exit 1, "Error: no valid flowcell found."  
} 

def summary = [:]
summary['input'] = params.input
summary['cpus'] = params.cpus
summary['basecalling'] = params.skip_basecalling ? 'No' : 'Yes'
if (!params.skip_basecalling) {
  if (params.flowcell) summary['flowcell'] = params.flowcell
  if (params.kit) summary['kit'] = params.kit
  if (params.config) summary['config'] = params.config
  summary['cpus per caller'] = params.cpu_threads_per_caller ? params.cpu_threads_per_caller : params.cpus
  summary['number of callers'] = params.num_callers
}
summary['demultiplexing'] = params.skip_demultiplexing ? 'No' : 'Yes'
if (!params.skip_demultiplexing) {
  if (params.barcode_kits) summary['barcode kits'] = params.barcode_kits
  summary['trim barcodes'] = params.trim_barcodes ? 'Yes' : 'No'
  if (params.csv) summary['csv'] = params.csv
}
summary['adapter trimming'] = params.skip_porechop ? 'No' : 'Yes'
summary['quality control'] = 'pycoQC & seqkit'
log.info summary.collect { k,v -> "${k.padRight(18)}: $v" }.join("\n")
log.info "-\033[2m--------------------------------------------------\033[0m-"

/*
Guppy basecalling & demultiplexing
*/

if ( !params.skip_basecalling ) {

  if (workflow.profile.contains('test')) {
    process get_test_data {
      
      publishDir path: "${params.outdir}/testdata", mode: 'copy'

      output:
      file "test-datasets" into ch_input_files

      script:
      """
      git clone https://github.com/ncct-mibi/test-datasets --branch nxf-ont
      """
    }
  } else {
    if (params.input) { 
      ch_input_files = Channel.fromPath(params.input, checkIfExists: true)
    } else { 
      exit 1, "Please specify a valid run directory to perform basecalling!" 
    }
  }
  
  process guppy_basecaller {
    publishDir path: params.barcode_kits ? "${params.outdir}/barcodes" : "${params.outdir}/basecalled", mode:'copy',
                        saveAs: { filename -> if (!filename.endsWith("v_guppy_basecaller.txt")) filename }
    publishDir path: "${params.outdir}/pipeline_info", mode:'copy', 
                        saveAs: { filename -> if (filename.endsWith("v_guppy_basecaller.txt")) filename }

    input:
    file dir_fast5 from ch_input_files
    file csv_file from ch_input_csv.ifEmpty([])

    output:
    file "fastq/*.fastq.gz" into ch_fastq, ch_for_seqkit
    file "guppy_basecaller.log" into ch_log_guppy_basecaller
    file "rename.log" optional true into ch_log_rename
    file "sequencing_summary*" into ch_summary_guppy
    file "v_guppy_basecaller.txt" into ch_version_guppy

    script:
    flowcell = params.flowcell ? "--flowcell $params.flowcell" : ""
    kit = params.kit ? "--kits $params.kit" : ""
    barcode_kits = params.barcode_kits ? "--barcode_kits $params.barcode_kits" : ""
    config = params.config ? "--config $params.config" : ""
    trim_barcodes = params.trim_barcodes ? "--trim_barcodes" : ""
    cpu_threads_per_caller = params.cpu_threads_per_caller ?  "--cpu_threads_per_caller $params.cpu_threads_per_caller" : "--cpu_threads_per_caller $params.cpus"
    //num_callers = "--num_callers $params.num_callers"

    """
    guppy_basecaller --version &> v_guppy_basecaller.txt

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
    cp results-guppy-basecaller/sequencing_summary* .

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

  if (params.input) { 
    ch_input_files = Channel.fromPath(params.input, checkIfExists: true)
  } else { 
    exit 1, "Please specify a valid run directory to perform demultiplexing process!" 
  }
  
  process guppy_barcoder {
    publishDir path: "${params.outdir}/barcodes", mode:'copy'

    input:
    file basecalled_files from ch_input_files
    file csv_file from ch_input_csv.ifEmpty([])

    output:
    file "fastq/*.fastq.gz" into ch_fastq, ch_for_seqkit
    file "guppy_barcoder.log" into ch_log_guppy_barcoder
    file "rename.log" optional true into ch_log_rename
    file "sequencing_summary*" into ch_summary_guppy
    file "v_guppy_barcoder.txt" into ch_version_guppy

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
    cp results-guppy-barcoder/sequencing_summary* .

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
} else if ( params.skip_basecalling && params.skip_demultiplexing ){

  if (params.input) { 
    ch_input_files = Channel.fromPath(params.input, checkIfExists: true)
  } else { 
    exit 1, "Please specify a valid run directory to perform rename process!" 
  }

  process rename_barcode {
    publishDir path: "${params.outdir}/renamed_barcodes", mode:'copy'

    input:
    file fastq_files from ch_input_files
    file csv_file from ch_input_csv.ifEmpty([])
      
    output:
    file "fastq/*.fastq.gz" into ch_fastq, ch_for_seqkit
    file "rename.log" into ch_log_rename

    script:
    """
    mkdir fastq
    fastqdir=\$PWD'/fastq'
    cd $fastq_files
    if [ "\$(find . -type d -name "barcode*" )" != "" ]
    then
      for dir in barcode*/
      do
        dir=\${dir%*/}
        cat \$dir/*.fastq.gz > $fastqdir/\$dir.fastq.gz
      done
    else
      cat *.fastq.gz > $fastqdir/unclassified.fastq.gz
    fi

    if [ ! -z "$params.csv" ] && [ ! -z "$params.barcode_kits" ]
    then
      while IFS=, read -r ob nb
      do
        echo rename $fastqdir/\$ob.fastq.gz to $fastqdir/\$nb.fastq.gz &>> $fastqdir/rename.log
        mv $fastqdir/fastq/\$ob.fastq.gz $fastqdir/fastq/\$nb.fastq.gz
      done < $fastqdir/$csv_file
    fi
    """
  }
}

/*
Adapter trimming with porechop
*/
process porechop { 
  publishDir path: "${params.outdir}/porechop", mode:'copy'

  input:
  file fastq_file from ch_fastq.flatten()

  output:
  file "trimmed*.fastq.gz" into ch_porechop
  file "logs/trimmed*.log" into ch_log_porechop

  when:
  !params.skip_porechop || !params.skip_demultiplexing

  script:
  //threads = params.cpus ? "--threads $params.cpus" : "--threads 4"
  """
  mkdir logs
  porechop \\
    --input $fastq_file \\
    --output trimmed_$fastq_file \\
    --threads $params.cpus \\
    --no_split \\
    &> logs/trimmed_"${fastq_file.simpleName}".log
  """
}

/*
Quality control with pycoQC
*/
/*
process pycoqc {
  publishDir path: "${params.outdir}/pycoqc", mode:'copy'
  
  input:
  file summary_file from ch_summary_guppy

  output:
  file "pycoQC.html"

  when:
  !params.skip_basecalling

  script:
  """
  pycoQC --summary_file $summary_file \\
    --html_outfile pycoQC.html
  """
}
*/

/*
Quality control with seqkit
*/
process seqkit {
  publishDir path: "${params.outdir}/seqkit", mode:'copy'

  input:
  file fastq_file from !params.skip_porechop && !params.skip_demultiplexing ? ch_porechop.collect() : ch_for_seqkit.collect()

  output:
  file "seqkit.txt"

  script:
  """
  seqkit stats --all $fastq_file > seqkit.txt
  """
}

/*
Get the software versions
*/
/*
process get_software_versions {
  publishDir path: "${params.outdir}/pipeline_info", mode:'copy'

  input:
  file "*.txt" from ch_version_guppy

  output:
  file "pipeline_info.txt"

  script:
  """
  echo porechop \$(porechop --version) &>> pipeline_info.txt
  echo pycoQC && pycoQC --version &>> pipeline_info.txt
  seqkit version &>> pipeline_info.txt
  """
}
*/