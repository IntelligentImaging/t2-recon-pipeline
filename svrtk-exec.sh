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

# Path to mount inside container
conpath="/home/data"
# random string
dockname="SVRTK-$RANDOM"

echo "Container will be named $dockname"
echo "Mount path within container: $conpath"
echo "Initializing SVRTK Docker container"
docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} fetalsvrtk/svrtk /bin/bash
echo
echo "Executing SVRTK run script within container"
date
docker exec -t -i -w /home/data $dockname sh -c "sh run-svrtk.sh"
echo
echo "Recon done"
date
echo "Killing docker image"
docker kill $dockname
echo
