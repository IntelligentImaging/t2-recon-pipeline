#!/bin/bash

if [[ $# -ne 1 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [SVRTK recon dir]"
    echo "Creates run scripts for reconstruction"
    echo "[recon dir] should have T2 stacks named: fetus_02.nii.gz fetus_05.nii.gz ... fetus_k.nii.gz"
    echo "If using mask, place mask_x.nii.gz in recon dir, where x refers to the reference stack"
    exit
	fi

# Set variables
t2dir=`readlink -f $1`
casepath="${t2dir%/nii*}"
id="${casepath##*/}"
if [ ! -d "${t2dir}" ]; then  
    echo "$t2dir directory not present"
    echo "Create this directory and copy T2 stacks there first"
    exit
fi
SVR="SVRTK_${id}.nii.gz"

# Run scripts
run="${t2dir}/run-svrtk.sh"
if [ -f $run ] ; then rm -v $run ; fi

# get list of stacks
t2s=`find ${t2dir} -maxdepth 1 -type f -name fetus_\*z`
n=`echo $t2s | wc -w`
# Error message if no stacks
if [[ $n -eq 0 ]] ; then
    echo "No stacks found. Did you input a directory with 'fetus_x.nii.gz' files?"
    echo "Exiting"
    exit 1
fi

# write reconstruct script
echo 'export PATH=$PATH:/home/MIRTK/build/bin/' >> $run
# reconstruct [output] [# stacks] [stack1.nii.gz ... stackn.nii.gz] -mask [mask.nii.gz]
echo "mirtk reconstruct $SVR $n \\" >> $run
for stack in $t2s ; do
    base=`basename $stack`
	echo "${base} \\" >> $run
done

echo stack dir = "$t2dir"
# Mask options
mask=`find $t2dir -maxdepth 1 -type f -name mask_\*.nii\* | head -n1`
if [[ -f $mask ]] ; then
    tmp="${mask##*_}"
    refn="${tmp%%.*}"
    ref="fetus_${refn}.nii.gz"
    mbase=`basename $mask`
    echo "mask = $mask"
    echo "-mask $mbase \\" >> $run
    echo "-template ${ref} \\" >> $run
else
    echo "No mask found. To reconstruct with mask, place mask named mask_x.nii.gz in recon directory"
fi

# Other options
echo "-svr_only \\">> $run
echo "-resolution 0.75 \\" >> $run
echo "-iterations 3 \\" >> $run
echo "-remote" >> $run

# Bash error log
# echo "2>${t2dir}/bash-reconstruct-error.txt" >> $run

echo "Wrote run script = $run"
chmod 777 $t2dir
echo "Setting permissions for $t2dir to open for Docker"
