#!/bin/bash

if [ $# -ne 1 ] ; then
	echo "Incorrect argument"
	echo "usage: sh $0 [Directory]"
	echo "finds all niftymic run.sh's in [Directory] and runs them within a Docker container"
	exit 1
fi

begin=`pwd`
DIR=`readlink -f $1`

runs="`find $DIR -mindepth 1 -maxdepth 3 -type f -name run-nm.sh`"

echo "Process cases"
for run_nm in $runs ; do
	mpath=`dirname $run_nm`
    id=`basename $mpath`
    run_sfb="${mpath}/run-sfb.sh"
    echo $id
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
	else
        # Path to mount inside container
        conpath="/home/data"
        # Random string
        dockname="NIFTYMIC-$RANDOM"
        echo "Container will be named $dockname"
        echo "Mount path within container: $conpath"
        echo "Initializing SVRTK Docker container"
        docker run -id --name $dockname --rm --mount type=bind,source=${mpath},target=${conpath} renbem/niftymic /bin/bash
        echo
        # If there were masks missing, run sfb first
        if [[ $sfb > 0 ]] ; then
            echo "Case $id : Running segment-fetal-brains (lo-res t2 stacks) within container"
            date
            docker exec -t -i -w /home/data $dockname sh -c "sh run-sfb.sh"
            echo
            echo "segment-fetal-brains complete"
        fi
        echo "Case $id : Run NiftyMIC reconstruction within container"
        docker exec -t -i -w /home/data $dockname sh -c "sh run-nm.sh"
        echo
        echo "NiftyMIC recon done"
        echo "Killing docker image"
        docker kill $dockname
        echo
	fi
    echo
done
