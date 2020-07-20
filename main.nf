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


/*
guppy basecalling
*/


/*
guppy barcoder
*/
