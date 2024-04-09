#!/bin/bash


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-m mask] [-n iterations] -- [input image]
    Incorrect input supplied
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
        -n|--iter)
            if [[ $2 -gt 0 ]] ; then
                ITER=$2 # set number of n4 iterations to perform
                shift
            else
                die 'error: iteration number needed (1-2 are usually fine)'
            fi
            ;;
        -m|--mask)
            if [[ -f "$2" ]] ; then
                mask=$2 # Specify
                shift
            else
                die 'error: mask not found'
            fi
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

INPUT=$1
DIR=`dirname $INPUT`

if [[ ! -n $ITER ]] ; then
    let ITER=1
fi


if [[ -f $INPUT ]] ; then
    BASE=`basename $INPUT`

    let count=0
    OUT="${DIR}/BIASTEMP.nii.gz"
    CORR="${DIR}/b${BASE}"
    MAX="${DIR}/tmp_b${BASE}"
    NEG="${DIR}/tmp_b${BASE}"
    if [[ ! -f $CORR ]] ; then
        echo "n4 bias correct"
        while [[ $count -lt $ITER ]] ; do # the number here can be adjusted to set the number of bias correction iterations
            $FETALBIN/crlN4biasfieldcorrection $INPUT $OUT $mask
            INPUT="${OUT}"
            ((count++))
        done
        $FETALBIN/crlMatchMaxImageIntensity ${FETALREF}/STA_GEPZ/STA35.nii.gz $OUT $MAX
        $FETALBIN/crlNoNegativeValues ${MAX} ${NEG}
        mv -v ${NEG} ${CORR}
    else echo "bias corrected already there"
    fi
fi
