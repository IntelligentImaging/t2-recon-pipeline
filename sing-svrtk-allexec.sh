#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input directory to search]
    Executes all SVRTK run scripts with singularity on e2
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

shdir=`dirname $0`

indir=$1
runs=`find $indir -name run-svrtk.sh`
echo Found run files: $runs

for run in $runs ; do
    echo $run
    dir=`dirname $run`
    nameline=`grep "mirtk reconstruct" $run`
    outname=`echo $nameline | sed -e 's,.*SVRTK_,SVRTK_,g' -e 's,.nii.gz.*,.nii.gz,g'`
    check=`find $dir -maxdepth 1 -name $outname`
    if [[ -n $check ]] ; then
        echo Completed recon found: $check
        echo
    else
        echo "No recon found for: $outname"
        echo process
        sh ${shdir}/sing-svrtk-exec.sh $dir
        echo
    fi
done
