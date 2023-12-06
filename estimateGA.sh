#!/bin/bash

if [[ $# -lt 1 || $# -gt 2 || ! -f $1 ]]; then	
	echo "Incorrect argument supplied!"
	echo "usage: sh $0 [input T2 recon] [opt: -m]"
    echo "Guesses fetal recon GA by comparing size to fetal STA"
	exit
	fi

input=`readlink -f $1`
# A text file with the atlas volumes in column 2
choose="${FETALREF}/STA_GEPZ/masks/choose.txt"
base=`basename $input`
# Binary threshold the recon to get a rough volume
if [[ $2 == "-m" ]] ; then
    mask=$1
    vol=`crlComputeVolume $mask 1`
else
    # No mask specified
    mask="TEMPestimateMASK_${base}"
    crlBinaryThreshold $input $mask 150 20000 1 0
    vol=`crlComputeVolume $mask 1`
    rm $mask
fi
# compare input mask volume to each STA mask volume and pick the smallest (absolute) difference
while read line ; do
    atlasGA=`echo $line | cut -d' ' -f1`
    avol=`echo $line | cut -d ' ' -f2`
    diff=`echo "($avol-$vol)/1" | bc`
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
done < $choose
echo $input $pick
