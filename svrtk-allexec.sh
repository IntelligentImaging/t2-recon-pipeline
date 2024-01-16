#!/bin/bash

die() {
    printf '%s\n' "$1" >&2
    exit 1
}
while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -s|--singularity)
            let SING=1 
            ;;
        --) # end of optionals
            shift
            break
            ;;
        -)?*
            printf 'warning: unknown option (ignored: %s\m' "$1" >&2
            ;;
        *) # default case, no optionals
            break
    esac
    shift
done

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [-s||--singularity] -- [DATA MOUNT PATH]"
    echo "This script is used after using svrtk-dock-gen.sh to generate multiple 'run-svrtk.sh'"
    echo "Supply a study folder which has cases organized like so:"
    echo "STUDY FOLDER"
    echo "    --CASE001/nii/run-svrtk.sh"
    echo "or  --CASE001/nii/group1/run-svrtk.sh"
    echo "For each run-svrtk without a corresponding SVRTK.nii.gz recon, runs Docker/Singularity container SVRTK"
    echo "-s || --singularity   Use Singularity instead of Docker. Must use this option for e2 server"  
	exit
fi

begin=`pwd`
DIR=$1
if [[ ! -d $DIR ]] ; then
    die "error: $DIR is not a directory"
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
    output=`grep SVRTK $f | sed 's,.* \([a-zA-Z]*SVRTK.*z\).*,\1,'`
    if [ -f "${dname}/${output}" ] ; then
        echo $f already ran
    else
        # # # RUN SVRTK IN CONTAINER # # #
        echo "Run $f"
        mpath=`readlink -f $dname` # Server directory to be mounted

        if [[ $SING = 1 ]] ; then
            echo "Running singularity SVRTK"
            singularity exec docker://fetalsvrtk/svrtk /bin/sh ${mpath}/run-svrtk.sh
        else
            conpath="/home/data" # Path to mount inside container
            dockname="SVRTK-$RANDOM" # random string
            echo "Container will be named $dockname"
            echo "Mount path within container: $conpath"
            echo "Initializing SVRTK Docker container"
            docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} fetalsvrtk/svrtk /bin/bash
            echo
            echo "Executing SVRTK run script within container"
            docker exec -t -i -w /home/data $dockname sh -c "sh run-svrtk.sh"
            echo
            echo "Recon done"
            echo "Stopping docker image"
            docker stop $dockname
        fi
        echo
    fi
done
