#!/bin/bash

# This script deobliques and reorients a fetal T2 reconstruction for further processing

if [[ $# -lt 1 || $# -gt 2 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [BEST RECON] [opt: REF STACK DIR]"
    echo "Second argument optional- specify from where to take reference fetus_*.nii* stacks,"
    echo "if they're not in the current directory"
	exit
	fi

recon=`readlink -f $1`
if [[ ! -f $recon ]] ; then
    echo $recon is not a file - check argument
    exit 1
fi
dir=`dirname $recon`
dir2=`echo $dir | sed s,/nii.*,/nii,`
script="${dir2}/run-reorient.sh"
drecon="${dir2}/drecon.nii"
if [[ -f $script ]] ; then rm -v ${script} ; fi
# Afni 3dWarp deoblique
echo "Deoblique..."
cmd="3dWarp -deoblique -prefix $drecon $recon"
echo "$cmd" >> $script
$cmd
echo
# Reorient to each T2 stack
echo "Reorienting..."
# Use argument two if entered
if [[ -n $2 ]] ; then
    REFDIR="$2"
else REFDIR="$dir2"
fi
    for file in ${REFDIR}/fetus*.nii* ; do
        echo $file
        base=`basename $file`
        cmd="crlReorientReconstructedImage $drecon $file ${dir2}/r3DreconO$base"
        echo "$cmd" >> $script
        $cmd
        echo
    done
echo "Note: TransformFileWriterTemplate itk::ERROR is OK - we don't output a transform text file"
