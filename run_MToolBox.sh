#!/usr/bin/env bash

#=======================================================================================================================
#
#       FILE:  run_MToolBox.sh
#       SHORT DESCRIPTION: pipeline for working with MToolBox.sh. First, configuration file is generated and then passed
#       to MToolBox.sh. Results of MToolBox.sh are then analyzed with 'Analyze_MToolBox.py'.
#       
#       VERSION:  1.0.0
#       CREATED:  07/03/2023
#=======================================================================================================================

usage="""
usage: ${0##*/} generates configuration file and provides additional optional arguments for executing 'MToolBox.sh' script. Results generated by
MToolBox.sh are then analyzed with python script 'Analyze_MToolBox.py'.

Before running this script, MToolBox (v1.2) should be installed and added to your system PATH (see https://github.com/mitoNGS/MToolBox for more information).

${0##*/} options:

    -h      show this help message

    Options for configuration of config file:
    -i      input file format extension [ fasta | bam | sam | fastq ] (MANDATORY).
    -r      mitochondrial reference to be used for the mapping step with mapExome [ RSRS | RCRS; DEFAULT is 'RCRS' ]
    -p      the absolute or relative PATH of the input directory (MANDATORY).
    -o      the absolute or relative PATH of the output directory (MANDATORY).
    -g      specify the absolute or relative PATH to gsnap/gmap database executables (DEFAULT is '/home/kisld/MToolBox-master/gmapdb/').
    -d      specify if duplicate removal by MarkDuplicates should be set on. [ false | true; DEFAULT is 'true'].
    -c      config file. Use this option if arguments that are not specified above are to be used. Provide a file with needed arguments.
            See https://github.com/mitoNGS/MToolBox/blob/master/test_rCRS_config.sh for help.
    
    Options for running MToolBox.sh:
    -t      number of worker threads for running GSNAP [see mapExome.py -h for details]. DEFAULT is '50'.
    -a      options for the assembleMTgenome script [see assembleMTgenome.py -h for details]. DEFAULT is '-FCPN -t 3 -z 0.5'
"""

ref=RCRS
gsnapdb=/home/kisld/MToolBox-master/gmapdb/
UseMarkDuplicates=true
threads=50
mapExome="-t $threads"
assembleMTgenome="-FCPN -t 3 -z 0.5"

#Function 'generateFullPath [PATH]' accepts a relative path as argument and returns the absolute path (ending with '/').
#If an absolute path is provided, it stays the same. Conversion of relative path to absolute path is necessary for successful running of MToolBox.sh.
#Generation of absolute path can lead to the pressence of '/./' or '//', which are changed to '/'
generateFullPath () {
    local fullPath=$1
    if [[ $fullPath != /* ]]; then
        fullPath="$(pwd)"/"$fullPath"/
        fullPath=${fullPath//\/.\//\/}
        fullPath=${fullPath//\/\//\/}
    fi
    echo $fullPath
}

while getopts :hi:r:p:o:g:d:c:t:a: opt
do
    case $opt in
    h)
        echo "$usage"
        exit 1;;
    i)
        input_type=$OPTARG
        if [[ ! $input_type == bam ]] && [[ ! $input_type == sam ]] && [[ ! $input_type == fastq ]] && [[ ! $input_type == fasta ]]; then
            echo "Invalid argument: $OPTARG. Input_type (-i) can accept [ bam | sam | fastq | fasta ]." >&2
            exit 1 
        fi;;
    r)
        ref=$OPTARG
        if [[ ! $ref == RSRS ]] && [[ ! $ref == RCRS ]]; then
            echo "Invalid argument: $OPTARG. Reference (-r) can accept [ RSRS | RCRS ]." >&2
            exit 1 
        fi;;
    p)
        input_path=$OPTARG
        if [[ ! -d $input_path ]]; then
            echo "Invalid argument: $OPTARG. Input_path (-p) must be a directory." >&2
            exit 1
        fi
        input_path=$(generateFullPath "$input_path");;
    o)
        output_name=$OPTARG
        mkdir $output_name 2>/dev/null
        if [[ ! -d $output_name ]]; then
            echo "Invalid argument: $OPTARG. Output_name (-o) must be a directory." >&2
            exit 1        
        fi
        output_name=$(generateFullPath "$output_name");;        
    g)
        gsnapdb=$OPTARG
        if [[ ! -d $gsnapdb ]]; then
            echo "Invalid argument: $OPTARG. gnsapdb (-g) must be a directory." >&2
            exit 1
        fi
        gsnapdb=$(generateFullPath "$gsnapdb");;   
    d)
        UseMarkDuplicates=$OPTARG
        if [[ ! $UseMarkDuplicates == true ]] && [[ ! $UseMarkDuplicates == false ]]; then
            echo "Invalid argument: $OPTARG. UseMarkDuplicates (-d) can accept [ true | false ]." >&2
            exit 1
        fi;;
    c)
        conf_file=$OPTARG
        if [[ ! -f $conf_file ]]; then
            echo "Invalid argument: $OPTARG. conf_file (-c) must be a file." >&2
            exit 1
        else
            source $conf_file
            input_path=$(generateFullPath "$input_path")
            output_name=$(generateFullPath "$output_name")
        fi;;
    t) 
        threads=$OPTARG
        if (( ! $threads )); then
            echo "Invalid argumet: $OPTARG. Number of threads (-t) should be an intiger." >&2
            exit 1
        else
            mapExome="-t $threads"
        fi;;  
    a)
        assembleMTgenome=$OPTARG;;
    \?)
        echo "Invalid option: -$OPTARG. Try 'run_MToolBox.sh -h' for more information." >&2
        exit 1;;
    :)
        echo "Invalid option: -$OPTARG requires argument. Try 'run_MToolBox.sh -h' for more information." >&2
        exit 1;;
    esac
done

if [[ ! $input_type ]] || [[ ! $ref ]] || [[ ! $output_name ]] || [[ ! $input_path ]]; then
    echo "Arguments -i and -p and -o should be provided. If configuration file (-c) was provided instead, 'input_type', 'ref', 'input_path' and 'output_name' should be specified in it. Try 'run_MToolBox.sh -h' for more information." >&2
    exit 1
fi

#If fastq files are provided, the PAIRED-END couples are renamed from *_R{1,2}.fastq(.gz) to *.R{1,2}.fastq(.gz).
if [[ $input_type == fastq ]]; then
    #renames from R[1,2]_00*.fastq.gz to R[1,2].fastq.gz
    regex="Undetermined"
    #rename files, skip S number and lane
    for file in $input_path*.fastq.gz; do
        echo "${file}"
        # skip Unditermined samples
        if ! [[ "${file}" =~ $regex ]]; then
            FILENAME=$(basename "${file}" .fastq.gz)
            echo $FILENAME
            # takes as name everything before _
            NAME=$(echo "${FILENAME}" | sed 's/_.*//')
            # check if file name ends with R1_001 or R1, copy file
            if [ "${FILENAME: -6:-4}" == "R1" ] || [ "${FILENAME: -2}" == "R1" ] ; then
                mv -n "${file}" "$input_path"$NAME"_R1.fastq.gz"
            # check if file name ends with R2_001 or R2, copy file
            elif [ "${FILENAME: -6:-4}" == "R2" ] || [ "${FILENAME: -2}" == "R2" ] ; then
                mv -n "${file}" "$input_path"$NAME"_R2.fastq.gz"
            fi
        fi
    done

    new_input_path="$input_path"renamed_fastq_files_$(date +%s)
    mkdir $new_input_path
    export new_input_path
    find $input_path -type f -name "*_R[1,2]*.fastq*" -execdir bash -c 'cp -n $0 $new_input_path/${0//_R/.R}' {} \;
    input_path="$new_input_path"/
fi

#If config file (-c) is not already provided, the script creates new config file. If a file named 'conf.sh' already exists in current directory,
#it creates a file named 'conf#.sh'. Arguments that were provided as inputs of this script are put in the config file.
#When file is generated the message with the content of the file is shown in the terminal.
if [[ ! $conf_file ]]; then
    number=""
    while [[ -f "$output_name"conf$number.sh ]]; do
        ((number++))
    done
    conf_file="$output_name"conf$number.sh

    echo "#!/bin/bash
#This file was generated by ${0##*/}.
#Date of creation: $(date)

input_type=$input_type
ref=$ref
input_path=$input_path
output_name=$output_name
gsnapdb=$gsnapdb
UseMarkDuplicates=$UseMarkDuplicates

#The following arguments for running 'mapExome.py' and 'assemble_MTgenome.py' will also be provided to 'MToolBox.sh':
#mapExome=\"$mapExome\"
#assembleMTgenome=\"$assembleMTgenome\"" >> "$conf_file"

    echo
    echo "The input arguments were imported in a config file $conf_file."
    echo "------------------------------------------------------------------"
    cat $conf_file
    echo "------------------------------------------------------------------"
    echo
fi

echo MToolBox.sh -i "$conf_file" -m \"$mapExome\" -a \"$assembleMTgenome\"
echo
MToolBox.sh -i "$conf_file" -m \"$mapExome\" -a \"$assembleMTgenome\"

if (( $? != 0 )); then
    echo "Error: Execution of MToolBox.sh was not successful." >&2
    exit 1
fi

#MToolBox.sh saves results of individual sample in a folder 'output_name/OUT_sampleID', where sampleID is a name of input file without suffix.
#To access these folders the script generates sampleIDs of input files.
working_directory=$(pwd)
cd $input_path

if [[ $input_type = 'bam' ]]; then
	sampleIDs=$(ls *.bam | grep -v ".MT.bam" | grep -v ".sorted.bam" | awk 'BEGIN{FS="."}{print $1}')
elif [[ $input_type = 'sam' ]]; then
	sampleIDs=$(ls *.sam | awk 'BEGIN{FS="."}{print $1}')			
elif [[ $input_type = 'fastq' ]]; then			
	sampleIDs=$(ls *fastq* | awk 'BEGIN{FS="."}{count[$1]++}END{for (j in count) print j}')
else
    echo "The script \'${0##*/}\' does not support analysis of results with 'analyze_MToolBox.py' for input_type 'fasta'.
In this case try to run 'analyze_MToolBox.py' manually." >&2
    exit 1
fi

cd $working_directory

#Renamed (copied) fastq files that were generated at the beginning of the script are removed.
if [[ $input_type == fastq ]]; then
    find $input_path -type f -name "*.R[1,2].fastq*" -execdir bash -c 'rm $0' {} \;
    rmdir $input_path 
fi

# Fasta file generated by MToolBox.sh is then passed to script analyze_MToolBox.py which annotates variants using MitoMaster (https://www.mitomap.org/mitomaster/index.cgi).
for sample_name in $sampleIDs; do
    fasta_result="$output_name"OUT_$sample_name/$sample_name-contigs.fasta
    python3 analyze_MToolBox.py --fastaFile "$fasta_result" --resultsName "$sample_name-mitomaster_analysis.csv"
done