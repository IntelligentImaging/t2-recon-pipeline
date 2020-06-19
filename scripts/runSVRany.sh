#!/bin/bash

if [[ $# -ne 4 && $# -ne 2 ]] ; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [req: INPUT PREFIX] [req: OUTPUT RECON] [opt: REF VOLUME] [opt: REF MASK]"
    echo 
    echo "A fetal reconstruction pipeline script"
    echo "Runs segmentation with all files with [INPUT PREFIX] as inputs"
    echo "Optionally, supply a [REF VOLUME] and [REF MASK]"
    echo "This is uneccessary if the stacks have been cropped"
	echo "Do not include wildcard in prefix"
	exit
	fi

inputs=("$1"*)
output="$2"
outDIR=`dirname $output`
outBASE=`basename $output`
script="${outDIR}/run-${outBASE}.sh"
ref="$3"
mask="$4"

if [[ ! "$output" == *".nii"* ]] ; then
	echo "Bad output recon name. Output should be nifti (.nii or .nii.gz)"
	exit
fi

cmd="/home/ch191070/library/fetalReconstruction-master/source/bin/SVRreconstructionGPU -o $output -i ${inputs[@]}"

if [[ ! -z $ref && ! -z $mask ]] ; then
	cmd="$cmd -m $mask --referenceVolume $ref"
	fi

echo "$cmd" > ${script}
$cmd
mv -v GaussianReconstruction_GPU*.nii generatedMask.nii.gz image*_GPU.nii.gz log-evaluation.txt log-reconstruction.txt log-registration-error.txt log-registration.txt performance_GPU_* stack*.nii ${outDIR}/ 2>/dev/null 
if [[ -f $output ]] ; then
	echo "Output: $output"
else
	echo "Something went wrong- no output"
fi
