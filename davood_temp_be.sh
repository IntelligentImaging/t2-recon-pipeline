#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [input]
    Incorrect input supplied
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

im=$1
if [[ ! -f $im ]] ; then
    show_help
    exit
fi
reg=`dirname $im`
chmod 775 $reg
work="${reg}/BE"
mkdir -v ${work}
cp $im -v $work
chmod 777 $work
workf=`readlink -f $work`
docker run --mount src=$workf,target=/src/test_images/,type=bind davoodk/brain_extraction
seg=`find ${work}/segmentations -type f -name \*segmentation.nii.gz`
cp ${seg} -v ${reg}/mask.nii.gz 
