#!/bin/bash
if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [DATA MOUNT PATH]"
    echo "This script is used after using svrtk-dock-gen.sh to generate multiple 'run-svrtk.sh'"
    echo "Supply a study folder which has cases organized like so:"
    echo "STUDY FOLDER"
    echo "    --CASE001/nii/run-svrtk.sh"
    echo "or  --CASE001/nii/group1/run-svrtk.sh"
    echo "For each run-svrtk without a corresponding SVRTK.nii.gz recon,"
    echo " creates a detached SVRTK docker image, and then uses it to execute the run script, then deletes the container"
	exit
fi

begin=`pwd`
DIR=$1
if [[ ! -d $DIR ]] ; then
    echo error: $DIR is not a directory
    exit 1
fi

echo "Searching for run-svrtk.sh scripts"
runs="`find $DIR -mindepth 2 -maxdepth 4 -type f -name run-svrtk.sh`"
echo found: $runs
echo 
echo "Process cases"
for f in $runs ; do
    dname=`dirname $f`
    # Get ID based on script path
    idtmp="${dname%/nii*}"
    id="${idtmp##*/}"
    # Get output file from script and check if output already exists
    output=`grep SVRTK $f | sed 's,.*\(SVRTK.*z\).*,\1,'`
    if [ -f "${dname}/${output}" ] ; then
        echo $f already ran
    else
        # # # RUN SVRTK IN DOCKER CONTAINER # # #
        echo "Run $f"
        mpath=`readlink -f $dname` # Server directory to be mounted
        conpath="/home/data" # Path to mount inside container
        dockname="SVRTK-$RANDOM" # random string
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
    fi
    echo next case
done
