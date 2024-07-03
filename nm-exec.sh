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
    echo "This script is used after running nm-gen.sh to generate 'run-sfb.sh' and run-nm.sh"
    echo "Supply a recon directory which has the run scripts plus a folder named 't2' with the fetus_*.nii.gz stacks"
    echo "Runs docker/singularity container for NiftyMIC"
    echo "-s    Use Singularity instead of Docker (required for e2 server)"
	exit
	fi

# Server directory to be mounted
mpath=`readlink -f $1`

# Validate argument
if [[ ! -d $mpath ]] ; then
    echo error: $mpath is not a directory
    exit 1
fi
if [[ ! -f ${mpath}/run-sfb.sh || ! -f ${mpath}/run-nm.sh ]] ; then
    echo error: ${mpath}/run-sfb.sh or run-nm.sh are missing
    echo Run nm-gen.sh first
    exit 1
fi

# Here we compare the stacks in t2/ to the masks in mask/ and check if they are present
# If any are missing, we will execute the segment fetal brains code
tdir="${mpath}/t2"
mdir="${mpath}/mask"
t2s=`find $tdir -type f -name fetus\*z`
let sfb=0
echo "Checking for masks"
for t2 in $t2s ; do
    base=`basename $t2`
    mask="${mdir}/${base}"
    if [ ! -f ${mask} ] ; then
        sfb=$(expr $sfb + 1)
        echo "mask for stack: ${mask} not found" 
    fi
done

# Path to mount inside container
conpath="/home/data"
# random string
dockname="NIFTYMIC-$RANDOM"

# Initialize Docker if using Docker mode
if [[ $SING -ne 1 ]] ; then
    echo "Container will be named $dockname"
    echo "Mount path within container: $conpath"
    echo "Initializing SVRTK Docker container"
    docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} renbem/niftymic /bin/bash
    echo
fi

# If there were masks missing, run sfb first
if [[ $sfb > 0 ]] ; then
    echo "Executing NiftyMIC segment fetal brains (run-sfb) script within container"
    date
    if [[ $SING -eq 1 ]] ; then
        singularity exec docker://arfentul/niftymic.sing:first /bin/sh ${mpath}/run-sfb.sh
    else docker exec -t -i -w /home/data $dockname sh -c "sh run-sfb.sh"
    fi
fi

echo
echo "Segment fetal brains done"
date
echo "Executing NiftyMIC recon (run-nm) script within container"

if [[ $SING -eq 1 ]] ; then
    singularity exec docker://arfentul/niftymic.sing:first /bin/sh ${mpath}/run-nm.sh
else docker exec -t -i -w /home/data $dockname sh -c "sh run-nm.sh"
    echo "Killing docker image"
    docker kill $dockname
fi

echo
echo "NiftyMIC recon done"
echo
