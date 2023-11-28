#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-m mask_00x.nii.gz] [SVRTK recon dir]
    Incorrect input supplied
    
    Creates run scripts for reconstruction
    [recon dir] should have T2 stacks named: fetus_02.nii.gz fetus_05.nii.gz ... fetus_k.nii.gz
    If using mask, place mask_x.nii.gz in recon dir, where x refers to the reference stack
    Optional [-m mask_00x.nii.gz] specifies which T2 stack mask to use as the reference ROI.
    Default behavior is to find the first file named "mask_*" and use that. 
EOF
}

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
        -m|--mask)
            if [[ -f "$2" ]] ; then
                mask=$2 # Specify mask
                shift
            else
                die 'error: Mask image not supplied'
            fi
            ;;
        -n|--nomask)
                let nomask=1 # Recon will run without mask
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
    show_help
    exit
fi 

# Set variables
t2dir=`readlink -f $1`
casepath="${t2dir%/svrtk*}"
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
t2s=`find ${t2dir} -maxdepth 1 -type f -name fetus\*z`
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

# If default, search for mask. If nomask is set, we skip this
if [[ ! -n $mask && $nomask -ne 1 ]] ; then
    echo "Searching for mask"
    mask=`find $t2dir -maxdepth 1 -type f -name mask_\*.nii\* | sort | head -n1`
fi

# Add mask to run script
if [[ -f $mask ]] ; then
    ref=`echo $mask | sed 's,mask_,fetus_,g'`
    #tmp="${mask##*_}"
    #refn="${tmp%%.*}"
    #ref=`find $t2dir -maxdepth 1 -type f -name fetus\*_${refn}.nii.gz`
    if [[ ! -n $ref ]] ; then
        echo ref not found, choosing an arbitrary image instead
        ref=`find $t2dir -maxdepth 1 -type f -name fetus\*z | sort | head -n1`
    fi
    refbase=`basename $ref`
    mbase=`basename $mask`
    echo "mask = $mask"
    echo "-mask $mbase \\" >> $run
    echo "-template ${refbase} \\" >> $run
else
    echo "No mask found. To reconstruct with mask, place mask named mask_x.nii.gz in recon directory"
    echo "If no mask is OK, you can proceed"
fi

# Other options
echo "-svr_only \\">> $run
echo "-resolution 0.75 \\" >> $run
echo "-iterations 3 \\" >> $run
# echo "-remote" >> $run

# Bash error log
# echo "2>${t2dir}/bash-reconstruct-error.txt" >> $run

echo "Wrote run script = $run"
chmod 777 $t2dir
echo "Setting permissions for $t2dir to open for Docker"
