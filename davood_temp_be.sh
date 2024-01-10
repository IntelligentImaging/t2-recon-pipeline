#!/bin/bash

show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-s | --singularity] -- [input]
    Incorrect input supplied
    optional -s runs the docker with singularity instead, must be used while on e2  
EOF
}

while :; do
    case $1 in
        -h|-\?|--help)
            show_help # help message
            exit
            ;;
        -s|--singularity)
            let SING=1
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

if [[ $SING -eq 1 ]] ; then
    singularity run --bind ${workf}/BE:/src/test_images/ docker://arfentul/maskrecon:first
else
    docker run --mount src=$workf,target=/src/test_images/,type=bind davoodk/brain_extraction
fi

seg=`find ${work}/segmentations -type f -name \*segmentation.nii.gz`
cp ${seg} -v ${reg}/mask.nii.gz 
