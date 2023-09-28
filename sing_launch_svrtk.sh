#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [MOUNT PATH]"
	exit
	fi

# Server directory to be mounted
mpath=`readlink -f $1`
# Path to mount inside container
conpath="/home/data"

echo "Initializing SVRTK Docker container"
echo "Mount path within container: $conpath"
docker run -it --rm --mount type=bind,source=${mpath},target=${conpath} fetalsvrtk/svrtk /bin/bash
