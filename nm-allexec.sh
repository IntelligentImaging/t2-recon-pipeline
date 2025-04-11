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
    echo "This script is used after using nm-gen.sh to generate multiple 'run-sfb.sh' and 'run-nm.sh'"
    echo "Supply a study folder which has cases organized like so:"
    echo "STUDY FOLDER"
    echo "    --CASE001/niftymic/t2"
    echo "    --CASE001/niftymic/mask"
    echo "    --CASE001/niftymic/run-sfb.sh --CASE001/niftymic/run-nm.sh"
    echo "For each run without a corresponding outputs, runs Docker/Singularity container for niftyic"
    echo "-s || --singularity   Use Singularity instead of Docker. Must use this option for e2 server"  
	exit
fi

begin=`pwd`
DIR=$1
if [[ ! -d $DIR ]] ; then
    die "error: $DIR is not a directory"
fi

runs="`find $DIR -mindepth 1 -maxdepth 3 -type f -name run-nm.sh`"

echo "Process cases"
for run_nm in $runs ; do
	mpath=`dirname $run_nm` # This folder will probably be called "niftymic"
	subjdir=`dirname $mpath` # One level up is the subject dir
	id=`basename $subjdir` # This should be the subject ID...
    run_sfb="${mpath}/run-sfb.sh"
    if [ ! -f $run_sfb ] ; then
        echo "${mpath}/run-sfb.sh not found"
        echo "Re-run script generator for this case and try again"
        continue
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

    # Check for the existence of the recon (in template space)
    # If not, we run the NiftyMIC recon after sfb
    odir="${mpath}/srr/recon_template_space"
	if [ -f "${odir}/srr_template.nii.gz" ] ; then
		echo $run_nm already ran

    elif [[ $SING = 1 ]] ; then
        cd $mpath
        echo "Running singularity $mpath"
        if [[ $sfb > 0 ]] ; then
            echo "segment fetal brains pipeline"
            singularity exec docker://arfentul/niftymic.sing:first /bin/sh run-sfb.sh
            date
        else echo brain masks found
        fi
        echo "reconstruction pipeline"
        singularity exec docker://arfentul/niftymic.sing:first /bin/sh run-nm.sh
        cd -
    else
        # Path to mount inside container
        conpath="/home/data"
        # Random string
        dockname="NIFTYMIC-$RANDOM"
        echo "Container will be named $dockname"
        echo "Mount path within container: $conpath"
        echo "Initializing Docker container"
        echo $mpath
        docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} renbem/niftymic /bin/bash
        echo
        # If there were masks missing, run sfb first
        if [[ $sfb > 0 ]] ; then
            echo "Case $id : Running segment-fetal-brains (lo-res t2 stacks) within container"
            date
            echo $mpath
            docker exec -t -i -w /home/data $dockname sh -c "sh run-sfb.sh"
            echo
            echo "segment-fetal-brains complete"
        else
            echo "Brain masks found"
        fi
	
        echo "Case $id : Run NiftyMIC reconstruction within container"
        echo $mpath
        docker exec -t -i -w /home/data $dockname sh -c "sh run-nm.sh"
        echo
        echo "NiftyMIC recon done, Case $id"
        echo "Killing docker image"
        docker kill $dockname
        echo
	fi
    echo
done

