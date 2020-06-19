#!/bin/bash

if [[ $# -ne 1 && ! -d $1 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [RECON NII DIR]"
    echo
    echo "A fetal reconstruction pipeline script."
    echo "Crops all T2 input stacks with masks found"
    echo "in 2Ddensetnet/Result."
    echo
    echo "Looks for masks named 'DN2D-mask_stackname.nii.gz',"
    echo "dilates the mask to prevent clipping of the ROI,"
    echo "and crops each T2 stack in [RECON NII DIR]."
    echo
    echo "If there is an 'edit-DN2D-mask_stackname.nii.gz',"
    echo "it will use that mask instead."
	exit
	fi

NIIDIR=`readlink -f $1`
SCRIPT="${NIIDIR}/run-crop.sh"

if [[ -f $SCRIPT ]] ; then rm $SCRIPT ; fi
echo "Dilating masks and cropping T2's"
for FETUS in ${NIIDIR}/fetus*nii* ; do 
	echo $FETUS
	base=`basename $FETUS .gz`
	RESDIR="${NIIDIR}/2Ddensenet/Result"
	if [[ -f ${RESDIR}/edit-DN2D-mask_${base}.gz ]] ; then
		RESULT="${RESDIR}/edit-DN2D-mask_${base}.gz"
	else
		RESULT="${RESDIR}/DN2D-mask_${base}"
		fi
	DILATE="${RESDIR}/dDN2D-mask_${base}.gz"
	cmd1="crlBinaryMorphology $RESULT dilate 1 2 $DILATE"
	cmd2="crlMaskImage $FETUS $DILATE ${NIIDIR}/c${base}.nii.gz"
	echo "$cmd1" >> $SCRIPT
	echo "$cmd2" >> $SCRIPT
	$cmd1
	$cmd2
	done
