#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [DATA MOUNT PATH]"
    echo "This script is used after running svrtk-dock-gen.sh to generate 'run-svrtk.sh'"
    echo "Supply a recon directory (usually named 'nii') which has a run-svrtk.sh"
    echo "Creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container"
	exit
	fi

# Server directory to be mounted
mpath=`readlink -f $1`

# Validate argument
if [[ ! -d $mpath ]] ; then
    echo error: $mpath is not a directory
    exit 1
fi
if [[ ! -f ${mpath}/run-svrtk.sh ]] ; then
    echo error: ${mpath}/run-svrtk.sh not found
    exit 1
fi

cd $mpath
echo "Running SVRTK container"
singularity exec docker://fetalsvrtk/svrtk /bin/sh run-svrtk.sh
echo
echo "Recon done"
cd -
date
