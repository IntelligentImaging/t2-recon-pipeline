#!/bin/bash

if [ $# -ne 1 ]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [best reg]"
    echo "copies [best reg] to atlas_t2final_CASEID.nii.gz"
    echo " and clears all other registration attempts"
    echo " WARNING: permanently deletes all un-selected registrations"
	exit
	fi

best="$1"
if [[ ! -f $best ]] ; then
    echo "$best doesn't exist"
    exit 1
fi

base=`basename $best .nii.gz`
dir=`dirname $best`
tmpdir="${dir}/tmp${RANDOM}"
mkdir -v $tmpdir

if [[ ! -d $tmpdir ]] ; then
    echo "couldn't create directory tmp, exiting"
    exit 1
fi

mv -v ${base}* ${tmpdir}/
flirt=${best%%FLIRTto*}
rm -v ${flirt}*
mv -v ${tmpdir}/${base}* ${dir}/
rmdir -v ${tmpdir}

full=`readlink -f $best`
sdir="${full%%/nii*}"
id=`basename $sdir`
cp $best -v ${dir}/atlas_t2final_${id}.nii.gz

run="${dir}/run-reg.sh"
if [[ -f $run ]] ; then
    str=${best%%.*}
    if grep -q $str $run ; then
        echo "Updating run-reg.sh"
        val=`grep $str ${run} | tail -n1` 
        echo $val > ${run}
    fi
fi
