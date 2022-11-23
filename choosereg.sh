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
if [[ $best == *FLIRT*FLIRT* ]] ; then
    echo does this transform need to be composed?
    exit
fi

base=`basename $best .nii.gz`
dir=`dirname $best`
tmpdir="${dir}/tmp${RANDOM}"
mkdir -v $tmpdir

if [[ ! -d $tmpdir ]] ; then
    echo "couldn't create directory tmp, exiting"
    exit 1
fi

check=`find ${dir} -name ${base}.\*`
checkwc=`echo $check | wc -w`
if [[ $checkwc -lt 2 ]] ; then
    echo "Didn't find at least two files to preserve, exiting (should find final reg and a transform"
    exit
fi

mv -v ${base}.* ${tmpdir}/
flirt=${best%%IRTto*}
rm -v ${flirt}*
mv -v ${tmpdir}/${base}.* ${dir}/
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
