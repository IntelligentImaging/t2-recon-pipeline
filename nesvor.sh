#!/bin/bash


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
        -p|--prefix)
            if [[ -n "$2" ]] ; then
                PREF="$2" # Specify prefix for input images
                shift
            else die 'error: no prefix supplied'
            fi
            ;;
        -b|--bids)
            BIDS=1 # assume bids folder structure
            ;;
        -i|--iter)
            if [[ -n $2 ]] ; then
                ITER=$2 # specify training iterations
                shift
            else die 'error: provide number of training iterations'
            fi
            ;;
        -r|--resolution)
            if [[ -n "$2" ]] ; then
                RESO=$2 # Specify resolution
                shift
            else
                die 'error: no resolution supplied'
            fi
            ;;
        -s|--smooth)
            SMOOTH="--image-regularization edge --weight-image 2.5 --delta 0.02"
            ;;
        -e|--bet)
            let FETALBET=1 # activate fetal-bet mode
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


show_help () {
cat << EOF
    USAGE: sh ${0##*/} [-p PREFIX] [-r 0.x] [-e|--bet] -- [input directory]
    Incorrect input supplied

    -p      Set input stack file prefix (default=fetus)
    -b      BIDS mode (assume folders are organized subj/ses/nesvor/)
    -r      Set output resolution (default=0.5)
    -i      Set number of training iterations (default=6000)
    -e      Fetal-BET (brain extraction tool) mode. Can use if NeSVoR stack --segmentation is failing.
            Runs Razieh Fetal-BET on all input masks, dilates result, crops stacks, and uses cropped stacks instead.
            Omits --segmentation argument from NeSVoR command.
    -s	    Smooth mode: Edge regularization (which is default), weight-image and delta adjusted
EOF
}

if [ $# -ne 1 ]; then
    show_help
    exit
fi

if [[ ! -n $PREF ]] ; then
    PREF="fetus"
fi

if [[ ! -n $RESO ]] ; then
    RESO="0.5"
fi

if [[ ! -n $ITER ]] ; then
    ITER="6000"
fi

indir=`readlink -f $1`
if [[ ! -d $indir ]] ; then die "input dir doesnt exist" ; fi


sesdir=`dirname $indir`
ses=`basename $sesdir`
if [[ $BIDS = 1 ]] ; then
    subjdir=`dirname $sesdir`
    subj=`basename $subjdir`
    id="${subj}_${ses}"
else
    id="${ses}"    
fi


output=${indir}/nesvor_${id}.nii.gz

echo Reconstruction: $indir
cmd="nesvor reconstruct --output-volume ${output} --bias-field-correction --output-resolution ${RESO} --n-iter ${ITER}"
if [[ -n $SMOOTH ]] ; then cmd="${cmd} ${SMOOTH}" ; fi

if [[ -f $output ]] ; then

    echo $output already exists
elif [[ $FETALBET = 1 ]] ; then
    echo FETAL-BET mode
    echo Masking stacks
    sh ${FETALSH}/fetal-bet.sh -d ${indir}
    

    echo Running NeSVoR reconstruction
    singularity exec --nv docker://junshenxu/nesvor ${cmd} --input-stacks ${indir}/${PREF}*z --stack-masks ${indir}/mask_${PREF}*z
    echo recon done!

else
    echo Running NeSVoR segmentation and reconstruction
    echo command is ${cmd} --input-stacks ${indir}/${PREF}*z --segmentation
    echo "${cmd} --input-stacks ${indir}/${PREF}*z --segmentation" > ${indir}/cmd_nesvor.sh
    singularity exec --nv docker://junshenxu/nesvor ${cmd} --input-stacks ${indir}/${PREF}*z --segmentation 
    echo recon done!
fi

echo Bias correction
singularity exec --nv docker://junshenxu/nesvor python3 ${FETALSH}/n4biascorrect.py -i ${output} -o ${indir}/bnesvor_${id}.nii.gz
