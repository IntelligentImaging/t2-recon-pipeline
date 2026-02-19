#!/bin/bash

if [[ $# -lt 1 || $# -gt 2 || ! -f $1 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [input T2 recon] [opt: -m]"
    echo "Guesses fetal recon GA by comparing size to fetal STA"
	exit
	fi

input=`readlink -f $1`
# A text file with the atlas volumes in column 2
base=`basename $input`

# Binary threshold the recon to get a rough volume if no mask is supplied
if [[ $2 == "-m" ]] ; then
    mask=$1
else
    # No mask specified
    tmpmask="TEMPestimateMASK_${base}"
    mrthreshold -q -abs 2 $input $tmpmask -force # threshold everything above intensity=2 into a binary mask
    mask=$tmpmask
fi

# Calculate volume of mask using voxel count multiplied by image spacing 
maskvoxelcount=`mrstats -q -mask $mask $mask -output count`
maskimagespace=`mrinfo $mask -spacing | sed -e 's, ,*,g'`
invol=`echo "$maskvoxelcount * $maskimagespace / 1000" | bc`


# compare input mask volume to each STA mask volume and pick the smallest (absolute) difference
while IFS= read -r line ; do

    # Get atlas GAs and volumes from text file
    atlasGA=`echo $line | cut -d' ' -f1`
    avol=`echo $line | cut -d ' ' -f2`

    diff=`echo "($avol-$invol)/1" | bc` # Difference btw atlas volume and input image volume
    abs=${diff#-}
    # list all comparison results
    # echo AtlasGA $atlasGA Diff $abs
    # if no comparison values yet, set it using first line
    if [[ -z $pick ]] ; then
        pick="$atlasGA"
        pickvol="$abs"
        # if a line's diff is less than comparison, replace the saved values
        elif [[ $abs -lt $pickvol ]] ; then
            pick="$atlasGA"
            pickvol="$abs"
    fi
done < "${SHDIR}/GAvols.txt"

rm $tmpmask


echo $input $pick
