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
	echo "usage: sh $0 [-s || --singularity] -- [DATA MOUNT PATH]"
    echo "This script is used after running svrtk-gen.sh to generate 'run-svrtk.sh'"
    echo "Supply a recon directory (usually named 'nii' or 'svrtk') which has a run-svrtk.sh"
    echo "Runs docker/singularity container for SVRTK"
    echo "-s    Use Singularity instead of Docker (required for e2 server)"
	exit
	fi

# Server directory to be mounted
mpath=`readlink -f $1`

# Validate argument
if [[ ! -d $mpath ]] ; then
    die "error: $mpath is not a directory"
fi
if [[ ! -f ${mpath}/run-svrtk.sh ]] ; then
    die "error: ${mpath}/run-svrtk.sh not found"
fi

# Path to mount inside container
conpath="/home/data"
# random string
dockname="SVRTK-$RANDOM"

if [[ $SING = 1 ]] ; then
    echo Running singularity svrtk container
    singularity exec docker://fetalsvrtk/svrtk /bin/sh ${mpath}/run-svrtk.sh
else
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
    echo "Stopping docker image"
    docker stop $dockname
    echo
fi
