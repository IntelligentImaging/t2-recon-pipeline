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
mkdir -v tmp

if [[ ! -d tmp ]] ; then
    echo "couldn't create directory tmp, exiting"
    exit 1
fi

mv -v ${base}* tmp/
flirt=${best%%FLIRTto*}
rm -v ${flirt}*
mv -v tmp/${base}* .
rmdir -v tmp

full=`readlink -f $best`
sdir="${full%%/nii*}"
id=`basename $sdir`
cp $best -v atlas_t2final_${id}.nii.gz

if [[ -f run-reg.sh ]] ; then
    str=${best%%.*}
    if grep -q $str run-reg.sh ; then
        echo "Updating run-reg.sh"
        val=`grep $str run-reg.sh | tail -n1` 
        echo $val > run-reg.sh
    fi
fi
